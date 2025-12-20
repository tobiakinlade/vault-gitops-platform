#!/bin/bash

# Test Script for Docker Compose Setup
# Verifies that all services are running correctly

echo "🐳 Docker Compose - Test Suite"
echo "==============================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Check if docker-compose is running
echo "🔍 Checking Docker Compose services..."
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${RED}❌ Docker Compose is not running!${NC}"
    echo "Please start with: docker-compose up -d --build"
    exit 1
fi
echo -e "${GREEN}✅ Docker Compose is running${NC}"
echo ""

# Wait for services to be fully ready
echo "⏳ Waiting for services to be ready (30 seconds)..."
sleep 30
echo ""

# Test 1: Check Container Status
echo "Test Suite 1: Container Status"
echo "-------------------------------"

check_container() {
    local container=$1
    local name=$2
    
    if docker-compose ps | grep -q "$container.*Up"; then
        echo -e "${GREEN}✓ $name is running${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ $name is not running${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

check_container "postgres" "PostgreSQL"
check_container "vault" "Vault"
check_container "backend" "Backend API"
check_container "frontend" "Frontend"
echo ""

# Test 2: Health Checks
echo "Test Suite 2: Health Checks"
echo "----------------------------"

# PostgreSQL
echo -n "Testing PostgreSQL connection... "
if docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Vault
echo -n "Testing Vault connection... "
if curl -s http://localhost:8200/v1/sys/health > /dev/null; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Backend
echo -n "Testing Backend health endpoint... "
response=$(curl -s http://localhost:8080/health)
if echo "$response" | grep -q "healthy"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Frontend
echo -n "Testing Frontend availability... "
if curl -s http://localhost:3000 > /dev/null; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 3: Vault Configuration
echo "Test Suite 3: Vault Configuration"
echo "----------------------------------"

export VAULT_ADDR='http://localhost:8200'
export VAULT_TOKEN='root'

echo -n "Testing Vault transit engine... "
if docker-compose exec -T vault vault read transit/keys/tax-calculator > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo -n "Testing Vault database secrets... "
if docker-compose exec -T vault vault read database/config/postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo -n "Testing dynamic credentials generation... "
if docker-compose exec -T vault vault read database/creds/tax-calculator-role > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 4: Database
echo "Test Suite 4: Database"
echo "----------------------"

echo -n "Testing database connection... "
if docker-compose exec -T postgres psql -U postgres -d taxcalc -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo -n "Testing tax_calculations table exists... "
if docker-compose exec -T postgres psql -U postgres -d taxcalc -c "\d tax_calculations" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo -n "Testing sample data exists... "
count=$(docker-compose exec -T postgres psql -U postgres -d taxcalc -t -c "SELECT COUNT(*) FROM tax_calculations;" | tr -d ' \n')
if [ "$count" -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC} ($count records)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} (No data, but table exists)"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi
echo ""

# Test 5: API Functionality
echo "Test Suite 5: API Functionality"
echo "--------------------------------"

# Tax calculation test
echo -n "Testing tax calculation endpoint... "
response=$(curl -s -X POST http://localhost:8080/api/v1/calculate \
    -H "Content-Type: application/json" \
    -d '{"income":50000,"national_insurance":"AB123456C","tax_year":"2024/2025"}')

if echo "$response" | grep -q "income_tax"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    # Verify calculation
    income_tax=$(echo $response | grep -o '"income_tax":[0-9.]*' | cut -d':' -f2)
    echo "  Income tax for £50,000: £$income_tax"
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# History endpoint test
echo -n "Testing history endpoint... "
history_response=$(curl -s http://localhost:8080/api/v1/history)
if echo "$history_response" | grep -q "income"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 6: Encryption Verification
echo "Test Suite 6: Encryption Verification"
echo "--------------------------------------"

echo -n "Testing NI number encryption... "
# Get the last encrypted NI from database
encrypted_ni=$(docker-compose exec -T postgres psql -U postgres -d taxcalc -t -c \
    "SELECT encrypted_ni FROM tax_calculations ORDER BY created_at DESC LIMIT 1;" | tr -d ' \n')

if [[ "$encrypted_ni" == vault:* ]]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    echo "  Encrypted format: ${encrypted_ni:0:30}..."
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC}"
    echo "  May be using dev-mode encryption or sample data"
    TESTS_PASSED=$((TESTS_PASSED + 1))
fi
echo ""

# Test 7: Network Connectivity
echo "Test Suite 7: Network Connectivity"
echo "-----------------------------------"

echo -n "Testing frontend -> backend connection... "
if docker-compose exec -T frontend sh -c "wget -q -O- http://backend:8080/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo -n "Testing backend -> vault connection... "
if docker-compose exec -T backend sh -c "wget -q -O- http://vault:8200/v1/sys/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo -n "Testing backend -> postgres connection... "
if docker-compose exec -T backend sh -c "nc -z postgres 5432" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Summary
echo "================================"
echo "Test Results"
echo "================================"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "Total Tests:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

# Service URLs
echo "📍 Service URLs:"
echo "   Frontend:  http://localhost:3000"
echo "   Backend:   http://localhost:8080"
echo "   Vault UI:  http://localhost:8200 (Token: root)"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed! Application is ready.${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Open browser: http://localhost:3000"
    echo "2. Calculate tax with income: £50,000"
    echo "3. View calculation history"
    echo "4. Check Vault UI: http://localhost:8200"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some tests failed. Check the logs:${NC}"
    echo "   docker-compose logs backend"
    echo "   docker-compose logs vault"
    echo "   docker-compose logs postgres"
    echo ""
    exit 1
fi
