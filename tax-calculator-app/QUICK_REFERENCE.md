# 📋 QUICK REFERENCE CARD

**Tax Calculator Local Development - Keep This Handy!**

---

## 🚀 Quick Start (3 Commands)

```bash
# 1. Start services (one time)
./scripts/start-local.sh

# 2. Run backend (Terminal 1)
cd backend && go run main.go vault.go

# 3. Run frontend (Terminal 2)
cd frontend && npm start
```

**Open:** http://localhost:3000

---

## 🔗 URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Frontend | http://localhost:3000 | - |
| Backend API | http://localhost:8080 | - |
| Vault UI | http://localhost:8200 | Token: `root` |
| PostgreSQL | localhost:5432 | user: `postgres`, pass: `postgres123` |

---

## 🧪 Quick Tests

```bash
# Health check
curl http://localhost:8080/health

# Calculate tax
curl -X POST http://localhost:8080/api/v1/calculate \
  -H "Content-Type: application/json" \
  -d '{"income":50000,"national_insurance":"AB123456C","tax_year":"2024/2025"}'

# Get history
curl http://localhost:8080/api/v1/history

# Run full test suite
./scripts/test-local.sh
```

---

## 💰 UK Tax Rates (2024/2025)

| Band | Income Range | Tax Rate |
|------|--------------|----------|
| Personal Allowance | £0 - £12,570 | 0% |
| Basic Rate | £12,571 - £50,270 | 20% |
| Higher Rate | £50,271 - £125,140 | 40% |
| Additional Rate | Over £125,140 | 45% |

**National Insurance:**
- 12% on £12,571 - £50,270
- 2% on over £50,270

---

## 🔍 Example Calculations

| Income | Tax | NI | Take Home |
|--------|-----|-----|-----------|
| £20,000 | £1,486 | £892 | £17,622 |
| £30,000 | £3,486 | £2,092 | £24,422 |
| £50,000 | £7,486 | £4,504 | £38,010 |
| £75,000 | £17,432 | £5,004 | £52,564 |
| £100,000 | £27,432 | £6,004 | £66,564 |

---

## 🐛 Troubleshooting

### Backend won't start
```bash
# Check port
lsof -i :8080

# Check database
docker ps | grep postgres
docker logs postgres-local

# Restart database
docker restart postgres-local
```

### Frontend won't start
```bash
# Check port
lsof -i :3000

# Clear cache
rm -rf node_modules
npm install
```

### Database connection fails
```bash
# Test connection
psql -h localhost -U postgres -d taxcalc

# Recreate database
docker exec -it postgres-local psql -U postgres -c "DROP DATABASE IF EXISTS taxcalc;"
docker exec -it postgres-local psql -U postgres -c "CREATE DATABASE taxcalc;"
```

### Vault connection fails
```bash
# Check Vault
docker ps | grep vault
docker logs vault-local

# Test Vault
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'
vault status
```

---

## 📊 Database Queries

```bash
# View all calculations
docker exec -it postgres-local psql -U postgres -d taxcalc -c \
  "SELECT id, income, income_tax, take_home FROM tax_calculations ORDER BY created_at DESC LIMIT 10;"

# Count calculations
docker exec -it postgres-local psql -U postgres -d taxcalc -c \
  "SELECT COUNT(*) FROM tax_calculations;"

# Clear all data
docker exec -it postgres-local psql -U postgres -d taxcalc -c \
  "TRUNCATE TABLE tax_calculations;"

# View encrypted NI numbers
docker exec -it postgres-local psql -U postgres -d taxcalc -c \
  "SELECT encrypted_ni FROM tax_calculations LIMIT 5;"
```

---

## 🔐 Vault Commands

```bash
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'

# Get dynamic database credentials
vault read database/creds/tax-calculator-role

# Encrypt data
echo -n "AB123456C" | base64 | vault write transit/encrypt/tax-calculator plaintext=-

# Decrypt data
vault write transit/decrypt/tax-calculator ciphertext="vault:v1:..."

# View policies
vault policy read tax-calculator

# Check transit key
vault read transit/keys/tax-calculator
```

---

## 🔄 Docker Commands

```bash
# Start all services
docker start postgres-local vault-local

# Stop all services
docker stop postgres-local vault-local

# Remove all services
docker rm -f postgres-local vault-local

# View logs
docker logs postgres-local
docker logs vault-local

# Restart services
docker restart postgres-local vault-local
```

---

## 📝 Development Workflow

```bash
# Morning startup
docker start postgres-local vault-local
cd backend && go run main.go vault.go &
cd frontend && npm start &

# Make changes
# - Edit files
# - Backend: Ctrl+C and restart
# - Frontend: auto-reloads

# Test changes
curl http://localhost:8080/api/v1/calculate ...
# Or use browser at http://localhost:3000

# Evening shutdown
# Ctrl+C in terminals
docker stop postgres-local vault-local
```

---

## 🎯 Interview Demo Commands

```bash
# Terminal 1: Show backend logs
cd backend
go run main.go vault.go

# Terminal 2: Show Vault integration
export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'
vault read database/creds/tax-calculator-role

# Terminal 3: Show encrypted data
docker exec -it postgres-local psql -U postgres -d taxcalc -c \
  "SELECT encrypted_ni FROM tax_calculations LIMIT 1;"

# Browser: http://localhost:3000
# Calculate tax live!
```

---

## 🐳 Full Reset

```bash
# Nuclear option - start completely fresh
docker rm -f postgres-local vault-local
./scripts/start-local.sh
cd backend && go run main.go vault.go &
cd frontend && npm start &
```

---

## 📞 Quick Help

**Backend not responding?**
- Check logs in terminal
- Verify database connection
- Restart backend

**Frontend shows errors?**
- Check browser console (F12)
- Verify backend is running
- Check CORS headers

**Database issues?**
- Restart PostgreSQL container
- Check connection string
- Verify credentials

**Vault issues?**
- Check Vault is running
- Verify token is set
- Check Vault configuration

---

## ✅ Pre-Demo Checklist

- [ ] Both containers running: `docker ps`
- [ ] Backend healthy: `curl localhost:8080/health`
- [ ] Frontend loads: Open http://localhost:3000
- [ ] Can calculate tax: Test with £50,000
- [ ] History shows results
- [ ] Terminal commands ready
- [ ] Browser tabs open
- [ ] Calm and confident! 🚀

---

## 💡 Pro Tips

1. **Keep terminals visible** - Show logs during demo
2. **Pre-load calculations** - Have some history data
3. **Practice the flow** - From input to encrypted storage
4. **Know the numbers** - £50k → £7,486 tax, £4,504 NI
5. **Have backup** - Can demo without Vault in simple mode
6. **Stay calm** - You know this inside out!

---

**Print this card and keep it by your computer!** 📄

**Quick start:** `./scripts/start-local.sh`
**Test everything:** `./scripts/test-local.sh`
**Open app:** http://localhost:3000

**You've got this!** 💪
