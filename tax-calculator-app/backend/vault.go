package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"

	vault "github.com/hashicorp/vault/api"
)

type VaultClient struct {
	client *vault.Client
}

type DatabaseCredentials struct {
	Username string
	Password string
	Host     string
	Port     string
	Database string
}

func NewVaultClient() (*VaultClient, error) {
	config := vault.DefaultConfig()
	config.Address = getEnv("VAULT_ADDR", "http://vault:8200")

	client, err := vault.NewClient(config)
	if err != nil {
		return nil, fmt.Errorf("failed to create Vault client: %w", err)
	}

	// Authenticate using Kubernetes auth
	if err := authenticateKubernetes(client); err != nil {
		return nil, fmt.Errorf("failed to authenticate with Vault: %w", err)
	}

	return &VaultClient{client: client}, nil
}

func authenticateKubernetes(client *vault.Client) error {
	// Read Kubernetes service account token
	jwtPath := getEnv("JWT_PATH", "/var/run/secrets/kubernetes.io/serviceaccount/token")
	jwt, err := ioutil.ReadFile(jwtPath)
	if err != nil {
		// Fallback to token from environment (for local development)
		if token := os.Getenv("VAULT_TOKEN"); token != "" {
			client.SetToken(token)
			return nil
		}
		return fmt.Errorf("failed to read JWT token: %w", err)
	}

	// Login with Kubernetes auth
	role := getEnv("VAULT_ROLE", "tax-calculator")
	data := map[string]interface{}{
		"jwt":  string(jwt),
		"role": role,
	}

	secret, err := client.Logical().Write("auth/kubernetes/login", data)
	if err != nil {
		return fmt.Errorf("kubernetes auth login failed: %w", err)
	}

	if secret == nil || secret.Auth == nil {
		return fmt.Errorf("kubernetes auth returned no authentication info")
	}

	// Set the token
	client.SetToken(secret.Auth.ClientToken)
	return nil
}

func (v *VaultClient) GetDatabaseCredentials() (*DatabaseCredentials, error) {
	// Get dynamic database credentials from Vault
	secret, err := v.client.Logical().Read("database/creds/tax-calculator-role")
	if err != nil {
		return nil, fmt.Errorf("failed to read database credentials: %w", err)
	}

	if secret == nil || secret.Data == nil {
		return nil, fmt.Errorf("no database credentials found")
	}

	// Get connection details from environment or config
	host := getEnv("DB_HOST", "postgres")
	port := getEnv("DB_PORT", "5432")
	database := getEnv("DB_NAME", "taxcalc")

	return &DatabaseCredentials{
		Username: secret.Data["username"].(string),
		Password: secret.Data["password"].(string),
		Host:     host,
		Port:     port,
		Database: database,
	}, nil
}

func (v *VaultClient) EncryptData(plaintext string) (string, error) {
	// Encrypt data using Vault Transit engine
	data := map[string]interface{}{
		"plaintext": base64.StdEncoding.EncodeToString([]byte(plaintext)),
	}

	secret, err := v.client.Logical().Write("transit/encrypt/tax-calculator", data)
	if err != nil {
		return "", fmt.Errorf("failed to encrypt data: %w", err)
	}

	if secret == nil || secret.Data == nil {
		return "", fmt.Errorf("no encryption response")
	}

	ciphertext := secret.Data["ciphertext"].(string)
	return ciphertext, nil
}

func (v *VaultClient) DecryptData(ciphertext string) (string, error) {
	// Decrypt data using Vault Transit engine
	data := map[string]interface{}{
		"ciphertext": ciphertext,
	}

	secret, err := v.client.Logical().Write("transit/decrypt/tax-calculator", data)
	if err != nil {
		return "", fmt.Errorf("failed to decrypt data: %w", err)
	}

	if secret == nil || secret.Data == nil {
		return "", fmt.Errorf("no decryption response")
	}

	plaintextB64 := secret.Data["plaintext"].(string)
	plaintext, err := base64.StdEncoding.DecodeString(plaintextB64)
	if err != nil {
		return "", fmt.Errorf("failed to decode plaintext: %w", err)
	}

	return string(plaintext), nil
}

func (v *VaultClient) GetAPIKey(service string) (string, error) {
	// Get API keys from KV store
	path := fmt.Sprintf("secret/data/api-keys/%s", service)
	secret, err := v.client.Logical().Read(path)
	if err != nil {
		return "", fmt.Errorf("failed to read API key: %w", err)
	}

	if secret == nil || secret.Data == nil {
		return "", fmt.Errorf("no API key found for service: %s", service)
	}

	data := secret.Data["data"].(map[string]interface{})
	apiKey := data["api_key"].(string)
	return apiKey, nil
}

func (v *VaultClient) StoreAPIKey(service, apiKey string) error {
	// Store API key in KV store
	path := fmt.Sprintf("secret/data/api-keys/%s", service)
	data := map[string]interface{}{
		"data": map[string]interface{}{
			"api_key": apiKey,
		},
	}

	_, err := v.client.Logical().Write(path, data)
	if err != nil {
		return fmt.Errorf("failed to store API key: %w", err)
	}

	return nil
}

func (v *VaultClient) GetConfig(key string) (string, error) {
	// Get configuration from KV store
	secret, err := v.client.Logical().Read("secret/data/config/tax-calculator")
	if err != nil {
		return "", fmt.Errorf("failed to read config: %w", err)
	}

	if secret == nil || secret.Data == nil {
		return "", fmt.Errorf("no config found")
	}

	data := secret.Data["data"].(map[string]interface{})
	if value, ok := data[key]; ok {
		return value.(string), nil
	}

	return "", fmt.Errorf("config key not found: %s", key)
}

func (v *VaultClient) RenewToken() error {
	// Renew the Vault token
	secret, err := v.client.Auth().Token().RenewSelf(0)
	if err != nil {
		return fmt.Errorf("failed to renew token: %w", err)
	}

	if secret == nil {
		return fmt.Errorf("no secret returned from token renewal")
	}

	return nil
}

// Helper function for pretty printing
func prettyPrint(v interface{}) {
	b, _ := json.MarshalIndent(v, "", "  ")
	fmt.Println(string(b))
}
