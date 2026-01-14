#!/bin/bash

# Photo HQ - API Integration Test Script
# Tests all API endpoints with a complete workflow

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}❌ .env file not found. Run quickstart.sh first.${NC}"
    exit 1
fi

# Check required variables
if [ -z "$API_ENDPOINT" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}❌ Required environment variables not set${NC}"
    echo "Make sure .env contains API_ENDPOINT and ACCESS_TOKEN"
    exit 1
fi

echo "🧪 Photo HQ - API Integration Tests"
echo "===================================="
echo ""
echo "API Endpoint: $API_ENDPOINT"
echo "Token: ${ACCESS_TOKEN:0:30}..."
echo ""

TESTS_PASSED=0
TESTS_FAILED=0
PHOTO_ID=""

# Helper function to check response
check_response() {
    local test_name=$1
    local response=$2
    local expected_field=$3
    
    if echo "$response" | grep -q "$expected_field"; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name"
        echo "   Response: $response"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Suite: Photo Upload Workflow"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: List photos (should be empty or contain existing photos)
echo "Test 1: List photos (initial state)"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_ENDPOINT}/photos" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "200" ] && echo "$BODY" | grep -q "photos"; then
    echo -e "${GREEN}✅ PASS${NC}: List photos endpoint"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    if command -v jq >/dev/null 2>&1; then
        COUNT=$(echo "$BODY" | jq -r '.count')
        echo "   Current photo count: $COUNT"
    fi
else
    echo -e "${RED}❌ FAIL${NC}: List photos endpoint"
    echo "   HTTP Status: $HTTP_STATUS"
    echo "   Body: $BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 2: Upload photo (get presigned URL)
echo "Test 2: Request upload presigned URL"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${API_ENDPOINT}/photos/upload" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "filename": "test-photo.jpg",
        "content_type": "image/jpeg",
        "file_size": 10485760
    }')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "200" ] && echo "$BODY" | grep -q "upload_url"; then
    echo -e "${GREEN}✅ PASS${NC}: Upload endpoint"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    if command -v jq >/dev/null 2>&1; then
        PHOTO_ID=$(echo "$BODY" | jq -r '.photo_id')
        UPLOAD_URL=$(echo "$BODY" | jq -r '.upload_url')
        echo "   Photo ID: $PHOTO_ID"
        echo "   Upload URL: ${UPLOAD_URL:0:50}..."
    fi
else
    echo -e "${RED}❌ FAIL${NC}: Upload endpoint"
    echo "   HTTP Status: $HTTP_STATUS"
    echo "   Body: $BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 3: Get photo metadata (should exist but no upload yet)
if [ ! -z "$PHOTO_ID" ] && [ "$PHOTO_ID" != "null" ]; then
    echo "Test 3: Get photo metadata"
    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_ENDPOINT}/photos/${PHOTO_ID}/metadata" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')
    
    if [ "$HTTP_STATUS" == "200" ] && echo "$BODY" | grep -q "photo_id"; then
        echo -e "${GREEN}✅ PASS${NC}: Get metadata endpoint"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        if command -v jq >/dev/null 2>&1; then
            STATUS=$(echo "$BODY" | jq -r '.status')
            echo "   Photo status: $STATUS"
        fi
    else
        echo -e "${RED}❌ FAIL${NC}: Get metadata endpoint"
        echo "   HTTP Status: $HTTP_STATUS"
        echo "   Body: $BODY"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
fi

# Test 4: Get photo download URL
if [ ! -z "$PHOTO_ID" ] && [ "$PHOTO_ID" != "null" ]; then
    echo "Test 4: Get photo download URL"
    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_ENDPOINT}/photos/${PHOTO_ID}?version=original" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')
    
    if [ "$HTTP_STATUS" == "200" ] && echo "$BODY" | grep -q "download_url"; then
        echo -e "${GREEN}✅ PASS${NC}: Get photo endpoint"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        if command -v jq >/dev/null 2>&1; then
            DOWNLOAD_URL=$(echo "$BODY" | jq -r '.download_url')
            echo "   Download URL: ${DOWNLOAD_URL:0:50}..."
        fi
    else
        echo -e "${RED}❌ FAIL${NC}: Get photo endpoint"
        echo "   HTTP Status: $HTTP_STATUS"
        echo "   Body: $BODY"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
fi

# Test 5: Update photo (upload edited version)
if [ ! -z "$PHOTO_ID" ] && [ "$PHOTO_ID" != "null" ]; then
    echo "Test 5: Request edit upload presigned URL"
    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X PUT "${API_ENDPOINT}/photos/${PHOTO_ID}/edit" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "filename": "test-photo-edited.jpg",
            "content_type": "image/jpeg",
            "file_size": 9437184
        }')
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')
    
    if [ "$HTTP_STATUS" == "200" ] && echo "$BODY" | grep -q "upload_url"; then
        echo -e "${GREEN}✅ PASS${NC}: Update photo endpoint"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        if command -v jq >/dev/null 2>&1; then
            EDIT_UPLOAD_URL=$(echo "$BODY" | jq -r '.upload_url')
            echo "   Edit upload URL: ${EDIT_UPLOAD_URL:0:50}..."
        fi
    else
        echo -e "${RED}❌ FAIL${NC}: Update photo endpoint"
        echo "   HTTP Status: $HTTP_STATUS"
        echo "   Body: $BODY"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
fi

# Test 6: List photos with filter
echo "Test 6: List photos with filter (original)"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_ENDPOINT}/photos?version_type=original&limit=10" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "200" ] && echo "$BODY" | grep -q "photos"; then
    echo -e "${GREEN}✅ PASS${NC}: List photos with filter"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    
    if command -v jq >/dev/null 2>&1; then
        COUNT=$(echo "$BODY" | jq -r '.count')
        echo "   Filtered photo count: $COUNT"
    fi
else
    echo -e "${RED}❌ FAIL${NC}: List photos with filter"
    echo "   HTTP Status: $HTTP_STATUS"
    echo "   Body: $BODY"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 7: Delete photo
if [ ! -z "$PHOTO_ID" ] && [ "$PHOTO_ID" != "null" ]; then
    echo "Test 7: Delete photo"
    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X DELETE "${API_ENDPOINT}/photos/${PHOTO_ID}" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')
    
    if [ "$HTTP_STATUS" == "200" ] && echo "$BODY" | grep -q "deleted successfully"; then
        echo -e "${GREEN}✅ PASS${NC}: Delete photo endpoint"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        if command -v jq >/dev/null 2>&1; then
            DELETED_COUNT=$(echo "$BODY" | jq -r '.deleted_items | length')
            echo "   Deleted items: $DELETED_COUNT"
        fi
    else
        echo -e "${RED}❌ FAIL${NC}: Delete photo endpoint"
        echo "   HTTP Status: $HTTP_STATUS"
        echo "   Body: $BODY"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
fi

# Test 8: Verify deletion
if [ ! -z "$PHOTO_ID" ] && [ "$PHOTO_ID" != "null" ]; then
    echo "Test 8: Verify photo deleted (should 404)"
    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_ENDPOINT}/photos/${PHOTO_ID}/metadata" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')
    
    if [ "$HTTP_STATUS" == "404" ]; then
        echo -e "${GREEN}✅ PASS${NC}: Photo successfully deleted"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC}: Photo should not exist"
        echo "   HTTP Status: $HTTP_STATUS"
        echo "   Body: $BODY"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Suite: Error Handling"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 9: Invalid file size
echo "Test 9: Upload with invalid file size (too small)"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${API_ENDPOINT}/photos/upload" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "filename": "tiny.jpg",
        "content_type": "image/jpeg",
        "file_size": 1024
    }')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "400" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Correctly rejects invalid file size"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL${NC}: Should reject invalid file size"
    echo "   HTTP Status: $HTTP_STATUS"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 10: Invalid content type
echo "Test 10: Upload with invalid content type"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "${API_ENDPOINT}/photos/upload" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "filename": "document.pdf",
        "content_type": "application/pdf",
        "file_size": 10485760
    }')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS:/d')

if [ "$HTTP_STATUS" == "400" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Correctly rejects invalid content type"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL${NC}: Should reject invalid content type"
    echo "   HTTP Status: $HTTP_STATUS"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 11: Non-existent photo
echo "Test 11: Get non-existent photo"
FAKE_ID="00000000-0000-0000-0000-000000000000"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_ENDPOINT}/photos/${FAKE_ID}" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)

if [ "$HTTP_STATUS" == "404" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Correctly returns 404 for non-existent photo"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL${NC}: Should return 404"
    echo "   HTTP Status: $HTTP_STATUS"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Test 12: Missing authorization
echo "Test 12: Request without authorization"
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "${API_ENDPOINT}/photos")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)

if [ "$HTTP_STATUS" == "401" ]; then
    echo -e "${GREEN}✅ PASS${NC}: Correctly requires authorization"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}❌ FAIL${NC}: Should return 401"
    echo "   HTTP Status: $HTTP_STATUS"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo "Total:  $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
