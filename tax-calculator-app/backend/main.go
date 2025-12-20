package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
)

type Server struct {
	db          *sql.DB
	vaultClient *VaultClient
	router      *mux.Router
}

type TaxCalculationRequest struct {
	Income            float64 `json:"income"`
	NationalInsurance string  `json:"national_insurance"`
	TaxYear           string  `json:"tax_year"`
}

type TaxCalculationResponse struct {
	ID                string    `json:"id"`
	Income            float64   `json:"income"`
	IncomeTax         float64   `json:"income_tax"`
	NationalInsurance float64   `json:"national_insurance_contribution"`
	TakeHome          float64   `json:"take_home"`
	EffectiveRate     float64   `json:"effective_rate"`
	Timestamp         time.Time `json:"timestamp"`
	EncryptedNI       string    `json:"encrypted_ni,omitempty"`
}

type HealthResponse struct {
	Status    string `json:"status"`
	Database  string `json:"database"`
	Vault     string `json:"vault"`
	Timestamp string `json:"timestamp"`
}

func main() {
	log.Println("🚀 Starting Tax Calculator API...")

	// Initialize Vault client
	vaultClient, err := NewVaultClient()
	if err != nil {
		log.Fatalf("Failed to initialize Vault client: %v", err)
	}
	log.Println("✅ Vault client initialized")

	// Get database credentials from Vault
	dbCreds, err := vaultClient.GetDatabaseCredentials()
	if err != nil {
		log.Fatalf("Failed to get database credentials: %v", err)
	}
	log.Println("✅ Database credentials retrieved from Vault")

	// Connect to database
	db, err := connectDatabase(dbCreds)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer db.Close()
	log.Println("✅ Database connected")

	// Initialize database schema
	if err := initDatabase(db); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	log.Println("✅ Database schema initialized")

	// Create server
	server := &Server{
		db:          db,
		vaultClient: vaultClient,
		router:      mux.NewRouter(),
	}

	// Setup routes
	server.setupRoutes()

	// Start credential rotation goroutine
	go server.rotateCredentials()

	// Start server
	port := getEnv("PORT", "8080")
	log.Printf("🎯 Server listening on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, server.router))
}

func (s *Server) setupRoutes() {
	// CORS middleware
	s.router.Use(corsMiddleware)

	// Health check
	s.router.HandleFunc("/health", s.healthCheck).Methods("GET", "OPTIONS")

	// API routes
	api := s.router.PathPrefix("/api/v1").Subrouter()
	api.HandleFunc("/calculate", s.calculateTax).Methods("POST", "OPTIONS")
	api.HandleFunc("/history", s.getTaxHistory).Methods("GET", "OPTIONS")
	api.HandleFunc("/history/{id}", s.getTaxCalculation).Methods("GET", "OPTIONS")
}

func (s *Server) healthCheck(w http.ResponseWriter, r *http.Request) {
	// Check database
	dbStatus := "healthy"
	if err := s.db.Ping(); err != nil {
		dbStatus = "unhealthy: " + err.Error()
	}

	// Check Vault
	vaultStatus := "healthy"
	if _, err := s.vaultClient.client.Sys().Health(); err != nil {
		vaultStatus = "unhealthy: " + err.Error()
	}

	response := HealthResponse{
		Status:    "healthy",
		Database:  dbStatus,
		Vault:     vaultStatus,
		Timestamp: time.Now().Format(time.RFC3339),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (s *Server) calculateTax(w http.ResponseWriter, r *http.Request) {
	var req TaxCalculationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Validate input
	if req.Income <= 0 {
		http.Error(w, "Income must be positive", http.StatusBadRequest)
		return
	}

	if req.NationalInsurance == "" {
		http.Error(w, "National Insurance number is required", http.StatusBadRequest)
		return
	}

	if req.TaxYear == "" {
		req.TaxYear = "2024/2025"
	}

	// Calculate tax (UK 2024/2025 rates)
	incomeTax := calculateIncomeTax(req.Income)
	niContribution := calculateNationalInsurance(req.Income)
	takeHome := req.Income - incomeTax - niContribution
	effectiveRate := ((incomeTax + niContribution) / req.Income) * 100

	// Encrypt National Insurance number using Vault Transit
	encryptedNI, err := s.vaultClient.EncryptData(req.NationalInsurance)
	if err != nil {
		log.Printf("Failed to encrypt NI number: %v", err)
		http.Error(w, "Failed to encrypt sensitive data", http.StatusInternalServerError)
		return
	}

	// Store calculation in database
	id, err := s.storeCalculation(req.Income, incomeTax, niContribution, takeHome, encryptedNI, req.TaxYear)
	if err != nil {
		log.Printf("Failed to store calculation: %v", err)
		http.Error(w, "Failed to store calculation", http.StatusInternalServerError)
		return
	}

	// Log audit event to Vault
	s.auditLog("tax_calculation", map[string]interface{}{
		"calculation_id": id,
		"income":         req.Income,
		"tax_year":       req.TaxYear,
	})

	response := TaxCalculationResponse{
		ID:                id,
		Income:            req.Income,
		IncomeTax:         incomeTax,
		NationalInsurance: niContribution,
		TakeHome:          takeHome,
		EffectiveRate:     effectiveRate,
		Timestamp:         time.Now(),
		EncryptedNI:       encryptedNI,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func (s *Server) getTaxHistory(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.Query(`
		SELECT id, income, income_tax, ni_contribution, take_home, 
		       encrypted_ni, tax_year, created_at
		FROM tax_calculations
		ORDER BY created_at DESC
		LIMIT 50
	`)
	if err != nil {
		http.Error(w, "Failed to fetch history", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var calculations []TaxCalculationResponse
	for rows.Next() {
		var calc TaxCalculationResponse
		var encryptedNI string
		var taxYear string
		if err := rows.Scan(&calc.ID, &calc.Income, &calc.IncomeTax, 
			&calc.NationalInsurance, &calc.TakeHome, &encryptedNI, 
			&taxYear, &calc.Timestamp); err != nil {
			continue
		}
		calc.EffectiveRate = ((calc.IncomeTax + calc.NationalInsurance) / calc.Income) * 100
		calc.EncryptedNI = encryptedNI[:20] + "..." // Show partial for demo
		calculations = append(calculations, calc)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(calculations)
}

func (s *Server) getTaxCalculation(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	id := vars["id"]

	var calc TaxCalculationResponse
	var encryptedNI string
	var taxYear string

	err := s.db.QueryRow(`
		SELECT id, income, income_tax, ni_contribution, take_home, 
		       encrypted_ni, tax_year, created_at
		FROM tax_calculations
		WHERE id = $1
	`, id).Scan(&calc.ID, &calc.Income, &calc.IncomeTax, 
		&calc.NationalInsurance, &calc.TakeHome, &encryptedNI, 
		&taxYear, &calc.Timestamp)

	if err == sql.ErrNoRows {
		http.Error(w, "Calculation not found", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, "Failed to fetch calculation", http.StatusInternalServerError)
		return
	}

	calc.EffectiveRate = ((calc.IncomeTax + calc.NationalInsurance) / calc.Income) * 100
	calc.EncryptedNI = encryptedNI

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(calc)
}

// Calculate UK income tax (2024/2025 tax year)
func calculateIncomeTax(income float64) float64 {
	personalAllowance := 12570.0
	basicRateThreshold := 50270.0
	higherRateThreshold := 125140.0

	if income <= personalAllowance {
		return 0
	}

	taxableIncome := income - personalAllowance
	var tax float64

	// Basic rate: 20% on income up to £50,270
	if taxableIncome <= basicRateThreshold-personalAllowance {
		tax = taxableIncome * 0.20
	} else if taxableIncome <= higherRateThreshold-personalAllowance {
		// Higher rate: 40% on income between £50,270 and £125,140
		basicRateAmount := basicRateThreshold - personalAllowance
		higherRateAmount := taxableIncome - basicRateAmount
		tax = (basicRateAmount * 0.20) + (higherRateAmount * 0.40)
	} else {
		// Additional rate: 45% on income over £125,140
		basicRateAmount := basicRateThreshold - personalAllowance
		higherRateAmount := higherRateThreshold - basicRateThreshold
		additionalRateAmount := taxableIncome - (higherRateThreshold - personalAllowance)
		tax = (basicRateAmount * 0.20) + (higherRateAmount * 0.40) + (additionalRateAmount * 0.45)
	}

	return tax
}

// Calculate UK National Insurance (2024/2025)
func calculateNationalInsurance(income float64) float64 {
	lowerEarningsLimit := 12570.0
	upperEarningsLimit := 50270.0

	if income <= lowerEarningsLimit {
		return 0
	}

	var ni float64
	if income <= upperEarningsLimit {
		ni = (income - lowerEarningsLimit) * 0.12
	} else {
		ni = ((upperEarningsLimit - lowerEarningsLimit) * 0.12) + 
		     ((income - upperEarningsLimit) * 0.02)
	}

	return ni
}

func (s *Server) storeCalculation(income, tax, ni, takeHome float64, encryptedNI, taxYear string) (string, error) {
	var id string
	err := s.db.QueryRow(`
		INSERT INTO tax_calculations (income, income_tax, ni_contribution, take_home, encrypted_ni, tax_year)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id
	`, income, tax, ni, takeHome, encryptedNI, taxYear).Scan(&id)
	return id, err
}

func (s *Server) auditLog(action string, metadata map[string]interface{}) {
	// In a production system, this would write to Vault audit log
	log.Printf("[AUDIT] Action: %s, Metadata: %v", action, metadata)
}

func (s *Server) rotateCredentials() {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()

	for range ticker.C {
		log.Println("🔄 Rotating database credentials...")
		dbCreds, err := s.vaultClient.GetDatabaseCredentials()
		if err != nil {
			log.Printf("Failed to rotate credentials: %v", err)
			continue
		}

		newDB, err := connectDatabase(dbCreds)
		if err != nil {
			log.Printf("Failed to connect with new credentials: %v", err)
			continue
		}

		oldDB := s.db
		s.db = newDB
		oldDB.Close()
		log.Println("✅ Credentials rotated successfully")
	}
}

func connectDatabase(creds *DatabaseCredentials) (*sql.DB, error) {
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		creds.Host, creds.Port, creds.Username, creds.Password, creds.Database)

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, err
	}

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		return nil, err
	}

	return db, nil
}

func initDatabase(db *sql.DB) error {
	// Check if table already exists
	var exists bool
	err := db.QueryRow(`
		SELECT EXISTS (
			SELECT FROM information_schema.tables 
			WHERE table_schema = 'public' 
			AND table_name = 'tax_calculations'
		);
	`).Scan(&exists)
	
	if err != nil {
		return fmt.Errorf("failed to check table existence: %w", err)
	}
	
	// If table exists, assume schema is already initialized
	if exists {
		log.Println("✅ Database schema already exists, skipping initialization")
		return nil
	}
	
	// Create schema only if it doesn't exist
	log.Println("📝 Creating database schema...")
	schema := `
	CREATE TABLE IF NOT EXISTS tax_calculations (
		id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
		income DECIMAL(12,2) NOT NULL,
		income_tax DECIMAL(12,2) NOT NULL,
		ni_contribution DECIMAL(12,2) NOT NULL,
		take_home DECIMAL(12,2) NOT NULL,
		encrypted_ni TEXT NOT NULL,
		tax_year VARCHAR(20) NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE INDEX IF NOT EXISTS idx_tax_calculations_created_at 
		ON tax_calculations(created_at DESC);
	`

	_, err = db.Exec(schema)
	if err != nil {
		return fmt.Errorf("failed to initialize schema: %w", err)
	}
	
	log.Println("✅ Database schema created successfully")
	return nil
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
