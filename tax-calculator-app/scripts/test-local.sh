#!/bin/bash

# Test Script for Tax Calculator
# Verifies that everything is working correctly

echo "🧪 Tax Calculator - Test Suite"
echo "==============================="
echo ""

BASE_URL="http://localhost:8080"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_api() {
    local name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    local expected_status=$5

    echo -n "Testing: $name... "
    
    if [ "$method" == "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" == "$expected_status" ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC} (Expected $expected_status, got $http_code)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Check if backend is running
echo "🔍 Checking if backend is running..."
if ! curl -s "$BASE_URL/health" > /dev/null; then
    echo -e "${RED}❌ Backend is not running!${NC}"
    echo "Please start the backend first:"
    echo "  cd backend"
    echo "  go run main.go vault.go"
    exit 1
fi
echo -e "${GREEN}✅ Backend is running${NC}"
echo ""

# Test 1: Health Check
echo "Test Suite 1: Health Check"
echo "--------------------------"
test_api "Health endpoint" "GET" "/health" "" "200"
echo ""

# Test 2: Tax Calculations
echo "Test Suite 2: Tax Calculations"
echo "-------------------------------"

# Low income (below personal allowance)
test_api "Low income calculation" "POST" "/api/v1/calculate" \
    '{"income": 10000, "national_insurance": "AB123456C", "tax_year": "2024/2025"}' \
    "200"

# Basic rate taxpayer
test_api "Basic rate calculation" "POST" "/api/v1/calculate" \
    '{"income": 30000, "national_insurance": "AB123456C", "tax_year": "2024/2025"}' \
    "200"

# Higher rate taxpayer
test_api "Higher rate calculation" "POST" "/api/v1/calculate" \
    '{"income": 75000, "national_insurance": "AB123456C", "tax_year": "2024/2025"}' \
    "200"

# Additional rate taxpayer
test_api "Additional rate calculation" "POST" "/api/v1/calculate" \
    '{"income": 150000, "national_insurance": "AB123456C", "tax_year": "2024/2025"}' \
    "200"

# Edge case: exactly at personal allowance
test_api "Personal allowance edge case" "POST" "/api/v1/calculate" \
    '{"income": 12570, "national_insurance": "AB123456C", "tax_year": "2024/2025"}' \
    "200"

echo ""

# Test 3: Input Validation
echo "Test Suite 3: Input Validation"
echo "-------------------------------"

# Negative income
test_api "Negative income (should fail)" "POST" "/api/v1/calculate" \
    '{"income": -1000, "national_insurance": "AB123456C", "tax_year": "2024/2025"}' \
    "400"

# Zero income
test_api "Zero income (should fail)" "POST" "/api/v1/calculate" \
    '{"income": 0, "national_insurance": "AB123456C", "tax_year": "2024/2025"}' \
    "400"

# Missing NI number
test_api "Missing NI number (should fail)" "POST" "/api/v1/calculate" \
    '{"income": 50000, "tax_year": "2024/2025"}' \
    "400"

echo ""

# Test 4: History
echo "Test Suite 4: History"
echo "---------------------"
test_api "Get calculation history" "GET" "/api/v1/history" "" "200"
echo ""

# Test 5: Detailed Calculation Verification
echo "Test Suite 5: Detailed Verification"
echo "------------------------------------"
echo "Calculating tax for £50,000..."

response=$(curl -s -X POST "$BASE_URL/api/v1/calculate" \
    -H "Content-Type: application/json" \
    -d '{"income": 50000, "national_insurance": "AB123456C", "tax_year": "2024/2025"}')

income=$(echo $response | grep -o '"income":[0-9.]*' | cut -d':' -f2)
income_tax=$(echo $response | grep -o '"income_tax":[0-9.]*' | cut -d':' -f2)
ni_contribution=$(echo $response | grep -o '"national_insurance_contribution":[0-9.]*' | cut -d':' -f2)
take_home=$(echo $response | grep -o '"take_home":[0-9.]*' | cut -d':' -f2)

echo "Income:         £$income"
echo "Income Tax:     £$income_tax"
echo "NI Contribution: £$ni_contribution"
echo "Take Home:      £$take_home"

# Verify calculations (approximate)
expected_tax=7486
expected_ni=4504
actual_tax=$(printf "%.0f" $income_tax)
actual_ni=$(printf "%.0f" $ni_contribution)

if [ "$actual_tax" -ge 7480 ] && [ "$actual_tax" -le 7490 ]; then
    echo -e "${GREEN}✓ Income tax calculation correct${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ Income tax calculation incorrect (expected ~$expected_tax, got $actual_tax)${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if [ "$actual_ni" -ge 4500 ] && [ "$actual_ni" -le 4510 ]; then
    echo -e "${GREEN}✓ NI calculation correct${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗ NI calculation incorrect (expected ~$expected_ni, got $actual_ni)${NC}"
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

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
