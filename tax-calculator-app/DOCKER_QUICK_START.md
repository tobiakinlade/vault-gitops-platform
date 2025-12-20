# 🐳 Tax Calculator - Docker Compose Quick Start

**Run the entire application with ONE command!**

---

## ⚡ Super Quick Start

```bash
# 1. Make sure Docker Desktop is running

# 2. Start everything
docker-compose up --build

# 3. Open browser
open http://localhost:3000

# That's it! 🎉
```

---

## 📦 What You Get

Running `docker-compose up` starts:

- ✅ **PostgreSQL** - Database with sample data
- ✅ **Vault** - Secret management (auto-configured)
- ✅ **Backend API** - Go service with tax logic
- ✅ **Frontend UI** - React application

**Everything works together automatically!**

---

## 🎯 Quick Test

### In Browser (http://localhost:3000)

1. Income: `50000`
2. NI Number: `AB123456C`
3. Click "Calculate Tax"

**Result:**
```
Income Tax:        £7,486.00
National Insurance: £4,504.80
Take Home:         £38,009.20
```

### Via Command Line

```bash
# Health check
curl http://localhost:8080/health

# Calculate tax
curl -X POST http://localhost:8080/api/v1/calculate \
  -H "Content-Type: application/json" \
  -d '{"income":50000,"national_insurance":"AB123456C","tax_year":"2024/2025"}'
```

---

## 🔧 Common Commands

```bash
# Start (with logs)
docker-compose up --build

# Start in background
docker-compose up -d --build

# View logs
docker-compose logs -f

# Check status
docker-compose ps

# Stop everything
docker-compose down

# Clean restart
docker-compose down -v && docker-compose up --build
```

---

## 🧪 Run Tests

```bash
# Make script executable
chmod +x scripts/test-docker.sh

# Run full test suite
./scripts/test-docker.sh
```

**Tests verify:**
- All containers running
- Services healthy
- Vault configured
- Database initialized
- API working
- Encryption active

---

## 🔍 Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Frontend | http://localhost:3000 | - |
| Backend | http://localhost:8080 | - |
| Vault UI | http://localhost:8200 | Token: `root` |
| PostgreSQL | localhost:5432 | user: `postgres`, pass: `postgres123` |

---

## 🐛 Troubleshooting

### Services won't start?

```bash
# Check logs
docker-compose logs

# Restart fresh
docker-compose down -v
docker-compose up --build
```

### Port already in use?

```bash
# Find what's using the port
lsof -i :3000   # Frontend
lsof -i :8080   # Backend
lsof -i :5432   # PostgreSQL

# Kill it
kill -9 <PID>
```

### Backend can't connect?

```bash
# Wait 30 seconds after startup
# Services need time to initialize

# Check backend logs
docker-compose logs backend
```

---

## 📊 View Data

### Database

```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U postgres -d taxcalc

# View calculations
SELECT * FROM tax_calculations ORDER BY created_at DESC LIMIT 5;

# Exit
\q
```

### Vault

```bash
# Get dynamic credentials
docker-compose exec vault vault read database/creds/tax-calculator-role

# Check encryption key
docker-compose exec vault vault read transit/keys/tax-calculator
```

---

## 🎓 For Interview Demo

```bash
# 1. Start in background
docker-compose up -d --build

# 2. Wait 30 seconds
sleep 30

# 3. Test everything
./scripts/test-docker.sh

# 4. Open browser tabs:
# - http://localhost:3000 (Frontend)
# - http://localhost:8200 (Vault)

# 5. Demo ready! 🚀
```

---

## ✅ Success Checklist

After running `docker-compose up`:

- [ ] 4 containers running: `docker-compose ps`
- [ ] Frontend loads: http://localhost:3000
- [ ] Backend healthy: `curl http://localhost:8080/health`
- [ ] Can calculate tax
- [ ] History shows results
- [ ] Vault UI accessible: http://localhost:8200

---

## 📚 More Info

- **Complete guide:** See `DOCKER_COMPOSE_GUIDE.md`
- **Local dev:** See `LOCAL_DEVELOPMENT.md`
- **Interview prep:** See `DEMO_SCRIPT.md`

---

## 💡 Pro Tips

1. **First run takes longer** - Docker downloads images
2. **Wait 30 seconds** - Services need time to initialize
3. **Use `-d` flag** - Run in background
4. **Check logs often** - `docker-compose logs -f`
5. **Clean restart** - `docker-compose down -v && docker-compose up`

---

## 🎉 That's It!

**One command starts everything:**

```bash
docker-compose up --build
```

**Open browser:** http://localhost:3000

**You're ready to demo!** 🚀
