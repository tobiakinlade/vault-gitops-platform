# 🐳 DOCKER COMPOSE GUIDE

**Run the Entire Tax Calculator with One Command!**

---

## 🚀 Quick Start (2 Minutes!)

```bash
# 1. Navigate to project directory
cd tax-calculator-demo

# 2. Start everything
docker-compose up --build

# That's it! 🎉
```

**Open in browser:** http://localhost:3000

---

## ✨ What Gets Started

When you run `docker-compose up`, it starts **5 services**:

| Service | Port | Description |
|---------|------|-------------|
| **PostgreSQL** | 5432 | Database for storing calculations |
| **Vault** | 8200 | Secret management (dev mode) |
| **Vault-Init** | - | One-time configuration of Vault |
| **Backend** | 8080 | Go API with tax calculation logic |
| **Frontend** | 3000 | React UI for user interaction |

**Startup order:**
1. PostgreSQL starts first
2. Vault starts in dev mode
3. Vault-Init configures Vault (transit, database secrets)
4. Backend connects to Vault and PostgreSQL
5. Frontend connects to Backend

---

## 📋 Prerequisites

```bash
# Install Docker Desktop
# macOS: https://www.docker.com/products/docker-desktop
# Or via Homebrew:
brew install --cask docker

# Verify installation
docker --version
docker-compose --version
```

---

## 🎯 Complete Usage Guide

### Start Everything (Detached Mode)

```bash
# Build and start all services in background
docker-compose up -d --build

# View logs
docker-compose logs -f

# Or view specific service logs
docker-compose logs -f backend
docker-compose logs -f frontend
```

### Check Status

```bash
# View running containers
docker-compose ps

# Expected output:
# NAME                  STATUS          PORTS
# tax-calc-postgres     Up (healthy)    0.0.0.0:5432->5432/tcp
# tax-calc-vault        Up (healthy)    0.0.0.0:8200->8200/tcp
# tax-calc-backend      Up (healthy)    0.0.0.0:8080->8080/tcp
# tax-calc-frontend     Up              0.0.0.0:3000->3000/tcp
```

### Access the Application

```bash
# Frontend
open http://localhost:3000

# Backend API
curl http://localhost:8080/health

# Vault UI
open http://localhost:8200
# Token: root
```

### Stop Everything

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (clean slate)
docker-compose down -v
```

---

## 🧪 Testing the Application

### Test in Browser

1. Open http://localhost:3000
2. Enter income: `50000`
3. Enter NI: `AB123456C`
4. Click "Calculate Tax"
5. See results instantly!

### Test via API

```bash
# Health check
curl http://localhost:8080/health

# Calculate tax
curl -X POST http://localhost:8080/api/v1/calculate \
  -H "Content-Type: application/json" \
  -d '{
    "income": 50000,
    "national_insurance": "AB123456C",
    "tax_year": "2024/2025"
  }'

# Get history
curl http://localhost:8080/api/v1/history
```

### Automated Test Script

```bash
# Run comprehensive tests
./scripts/test-docker.sh
```

---

## 🔍 Verify Vault Integration

### Check Vault Configuration

```bash
# Access Vault container
docker-compose exec vault sh

# Inside container
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'

# Check transit encryption
vault read transit/keys/tax-calculator

# Get dynamic database credentials
vault read database/creds/tax-calculator-role

# Exit
exit
```

### Check Database

```bash
# Access PostgreSQL
docker-compose exec postgres psql -U postgres -d taxcalc

# View calculations
SELECT id, income, income_tax, take_home, created_at 
FROM tax_calculations 
ORDER BY created_at DESC 
LIMIT 10;

# View encrypted data
SELECT encrypted_ni FROM tax_calculations LIMIT 5;

# Exit
\q
```

---

## 📊 Service Details

### PostgreSQL

```yaml
Container: tax-calc-postgres
Port: 5432
Database: taxcalc
User: postgres
Password: postgres123
```

**Connect:**
```bash
docker-compose exec postgres psql -U postgres -d taxcalc
```

### Vault

```yaml
Container: tax-calc-vault
Port: 8200
Token: root
Mode: Development (NOT for production!)
```

**Features Configured:**
- ✅ Transit encryption engine
- ✅ Database secrets engine
- ✅ Dynamic PostgreSQL credentials
- ✅ KV secrets store (v2)

**Access UI:**
```bash
open http://localhost:8200
# Token: root
```

### Backend

```yaml
Container: tax-calc-backend
Port: 8080
Language: Go
Health: http://localhost:8080/health
```

**View logs:**
```bash
docker-compose logs -f backend
```

### Frontend

```yaml
Container: tax-calc-frontend
Port: 3000
Framework: React
URL: http://localhost:3000
```

**Hot reload enabled** - changes to `src/` directory auto-reload!

---

## 🛠️ Development Workflow

### Make Changes to Code

**Backend (Go):**
```bash
# Edit backend/main.go or backend/vault.go
nano backend/main.go

# Restart backend only
docker-compose restart backend

# View logs
docker-compose logs -f backend
```

**Frontend (React):**
```bash
# Edit frontend/src/App.js
nano frontend/src/App.js

# Changes auto-reload (no restart needed!)
# Just refresh browser
```

### Rebuild After Major Changes

```bash
# Rebuild specific service
docker-compose up -d --build backend

# Or rebuild everything
docker-compose up -d --build
```

---

## 🐛 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose logs

# Check specific service
docker-compose logs backend
docker-compose logs vault

# Restart everything
docker-compose down
docker-compose up --build
```

### Port Already in Use

```bash
# Find what's using the port
lsof -i :8080  # Backend
lsof -i :3000  # Frontend
lsof -i :5432  # PostgreSQL

# Kill the process
kill -9 <PID>

# Or change ports in docker-compose.yml
```

### Backend Can't Connect to Vault

```bash
# Check Vault is healthy
docker-compose ps vault

# Check Vault logs
docker-compose logs vault

# Restart vault and vault-init
docker-compose restart vault vault-init
docker-compose restart backend
```

### Database Connection Issues

```bash
# Check PostgreSQL is healthy
docker-compose ps postgres

# Check database logs
docker-compose logs postgres

# Restart PostgreSQL
docker-compose restart postgres

# Reinitialize database
docker-compose down -v
docker-compose up --build
```

### Frontend Shows "Cannot connect to backend"

```bash
# Check backend is running
curl http://localhost:8080/health

# Check backend logs
docker-compose logs backend

# Restart backend
docker-compose restart backend
```

---

## 🔄 Common Commands

### Start Services

```bash
# Start all services
docker-compose up

# Start in background
docker-compose up -d

# Rebuild and start
docker-compose up --build

# Start specific service
docker-compose up backend
```

### Stop Services

```bash
# Stop all
docker-compose down

# Stop and remove volumes
docker-compose down -v

# Stop specific service
docker-compose stop backend
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend

# Last 100 lines
docker-compose logs --tail=100 backend
```

### Execute Commands

```bash
# Access backend shell
docker-compose exec backend sh

# Access PostgreSQL
docker-compose exec postgres psql -U postgres -d taxcalc

# Access Vault
docker-compose exec vault sh
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart backend
```

### Clean Up

```bash
# Remove stopped containers
docker-compose rm

# Remove everything (containers, networks, volumes)
docker-compose down -v

# Remove images too
docker-compose down -v --rmi all
```

---

## 📈 Resource Usage

### View Resource Consumption

```bash
# Real-time stats
docker stats

# Container sizes
docker-compose ps --size
```

### Expected Resources

```
PostgreSQL: ~50MB RAM, 100MB disk
Vault:      ~30MB RAM, 50MB disk
Backend:    ~20MB RAM, 50MB disk
Frontend:   ~200MB RAM, 100MB disk (dev mode)
Total:      ~300MB RAM, 300MB disk
```

---

## 🎯 Test Different Scenarios

### Test Various Income Levels

```bash
# Low income (£20,000)
curl -X POST http://localhost:8080/api/v1/calculate \
  -H "Content-Type: application/json" \
  -d '{"income":20000,"national_insurance":"AB123456C","tax_year":"2024/2025"}'

# Medium income (£50,000)
curl -X POST http://localhost:8080/api/v1/calculate \
  -H "Content-Type: application/json" \
  -d '{"income":50000,"national_insurance":"AB123456C","tax_year":"2024/2025"}'

# High income (£100,000)
curl -X POST http://localhost:8080/api/v1/calculate \
  -H "Content-Type: application/json" \
  -d '{"income":100000,"national_insurance":"AB123456C","tax_year":"2024/2025"}'
```

### Test Vault Features

```bash
# Get dynamic credentials
docker-compose exec vault vault read database/creds/tax-calculator-role

# Encrypt data manually
echo -n "AB123456C" | base64 | \
  docker-compose exec -T vault vault write transit/encrypt/tax-calculator plaintext=-

# Check encryption key
docker-compose exec vault vault read transit/keys/tax-calculator
```

---

## 🎓 Learning & Demo Tips

### For Development

```bash
# Keep logs visible while developing
docker-compose up

# In separate terminal, make changes
# Watch logs update automatically
```

### For Demo/Interview

```bash
# Start in background
docker-compose up -d --build

# Open browser tabs:
# - Frontend: http://localhost:3000
# - Vault UI: http://localhost:8200

# Keep terminal ready with logs:
docker-compose logs -f backend
```

---

## 🔒 Security Notes

**Important:** This setup is for **development only**!

⚠️ **NOT production-ready:**
- Vault runs in dev mode (no persistence)
- Simple passwords used
- No TLS/SSL encryption
- All ports exposed

**For production:**
- Use Vault in production mode
- Strong passwords and secrets
- TLS everywhere
- Restrict network access
- Use secrets management
- Enable authentication
- Set up monitoring

---

## ✅ Success Checklist

After running `docker-compose up`, verify:

- [ ] All 4 containers running: `docker-compose ps`
- [ ] Backend healthy: `curl http://localhost:8080/health`
- [ ] Frontend loads: Open http://localhost:3000
- [ ] Can calculate tax: Try £50,000 in UI
- [ ] Vault working: Check http://localhost:8200 (Token: root)
- [ ] Database has data: `docker-compose exec postgres psql -U postgres -d taxcalc -c "SELECT COUNT(*) FROM tax_calculations;"`

---

## 🎉 You're Ready!

With Docker Compose, you can:

✅ **Start entire app with one command**
✅ **No manual configuration needed**
✅ **Clean environment every time**
✅ **Easy to reset and retry**
✅ **Perfect for testing**
✅ **Great for demo practice**

**Main command:** `docker-compose up --build`

**Stop command:** `docker-compose down`

**That's it!** 🚀

---

## 📝 Quick Reference

```bash
# Start
docker-compose up -d --build

# Status
docker-compose ps

# Logs
docker-compose logs -f

# Test
curl http://localhost:8080/health
open http://localhost:3000

# Stop
docker-compose down

# Clean
docker-compose down -v
```

**Keep this guide handy!** 📌
