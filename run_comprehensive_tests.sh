#!/bin/bash

# Comprehensive API Test Runner for Photo HQ Backend
# This script runs all API endpoint tests including authentication, CORS, and file operations

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Photo HQ Backend - Comprehensive API Test Suite${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Check for .env file
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found${NC}"
    echo ""
    echo "Please create a .env file with the following variables:"
    echo "  API_ENDPOINT=https://your-api-id.execute-api.us-east-1.amazonaws.com/prod"
    echo "  USER_POOL_ID=us-east-1_XXXXXXXXX"
    echo "  USER_POOL_CLIENT_ID=your-client-id"
    echo "  AWS_REGION=us-east-1"
    echo ""
    echo "You can get these values from:"
    echo "  aws cloudformation describe-stacks --stack-name photo-hq-dev --query 'Stacks[0].Outputs'"
    echo ""
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Verify required variables
REQUIRED_VARS=("API_ENDPOINT" "USER_POOL_ID" "USER_POOL_CLIENT_ID")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

if [ ${#MISSING_VARS[@]} -ne 0 ]; then
    echo -e "${RED}Error: Missing required environment variables:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    exit 1
fi

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

# Check and install dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"
cd tests

if [ -f requirements.txt ]; then
    pip3 install -q -r requirements.txt 2>&1 | grep -v "already satisfied" || true
fi

echo -e "${GREEN}✓ Dependencies ready${NC}"
echo ""

# Run the comprehensive test suite
echo -e "${BLUE}Running comprehensive API tests...${NC}"
echo ""

python3 comprehensive_api_test.py

TEST_EXIT_CODE=$?

echo ""
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ✓ All tests passed successfully!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  ✗ Some tests failed${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════${NC}"
fi

exit $TEST_EXIT_CODE
