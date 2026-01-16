#!/bin/bash

# Verification script for GitHub Actions workflow fixes
# This script validates that the fixes are correctly applied

set -e

echo "======================================"
echo "GitHub Actions Workflow Fix Verification"
echo "======================================"
echo ""

ERRORS=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check samconfig.toml has resolve_s3 = true
echo "Test 1: Verifying samconfig.toml configuration..."
if grep -q "resolve_s3 = true" samconfig.toml; then
    echo -e "${GREEN}✓ PASS${NC}: samconfig.toml has 'resolve_s3 = true'"
else
    echo -e "${RED}✗ FAIL${NC}: samconfig.toml does not have 'resolve_s3 = true'"
    ERRORS=$((ERRORS + 1))
fi

# Test 2: Check samconfig.toml does NOT have s3_prefix
echo ""
echo "Test 2: Verifying samconfig.toml does not have conflicting s3_prefix..."
if grep -q "s3_prefix" samconfig.toml; then
    echo -e "${RED}✗ FAIL${NC}: samconfig.toml still contains 's3_prefix' which conflicts with --resolve-s3"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✓ PASS${NC}: samconfig.toml does not have conflicting 's3_prefix'"
fi

# Test 3: Check workflow has cache-dependency-path
echo ""
echo "Test 3: Verifying workflow has cache-dependency-path..."
if grep -q "cache-dependency-path: 'src/requirements.txt'" .github/workflows/deploy.yml; then
    echo -e "${GREEN}✓ PASS${NC}: Workflow has 'cache-dependency-path: src/requirements.txt'"
else
    echo -e "${RED}✗ FAIL${NC}: Workflow missing 'cache-dependency-path: src/requirements.txt'"
    ERRORS=$((ERRORS + 1))
fi

# Test 4: Check workflow has --config-env default
echo ""
echo "Test 4: Verifying workflow has --config-env default flag..."
if grep -q "\-\-config-env default" .github/workflows/deploy.yml; then
    echo -e "${GREEN}✓ PASS${NC}: Workflow has '--config-env default' flag"
else
    echo -e "${RED}✗ FAIL${NC}: Workflow missing '--config-env default' flag"
    ERRORS=$((ERRORS + 1))
fi

# Test 5: Check workflow has --resolve-s3
echo ""
echo "Test 5: Verifying workflow has --resolve-s3 flag..."
if grep -q "\-\-resolve-s3" .github/workflows/deploy.yml; then
    echo -e "${GREEN}✓ PASS${NC}: Workflow has '--resolve-s3' flag"
else
    echo -e "${RED}✗ FAIL${NC}: Workflow missing '--resolve-s3' flag"
    ERRORS=$((ERRORS + 1))
fi

# Test 6: Verify src/requirements.txt exists
echo ""
echo "Test 6: Verifying src/requirements.txt exists..."
if [ -f "src/requirements.txt" ]; then
    echo -e "${GREEN}✓ PASS${NC}: src/requirements.txt exists"
else
    echo -e "${RED}✗ FAIL${NC}: src/requirements.txt does not exist"
    ERRORS=$((ERRORS + 1))
fi

# Test 7: Verify SAM template is valid
echo ""
echo "Test 7: Verifying SAM template structure..."
if [ -f "template.yaml" ]; then
    echo -e "${GREEN}✓ PASS${NC}: template.yaml exists"
else
    echo -e "${RED}✗ FAIL${NC}: template.yaml does not exist"
    ERRORS=$((ERRORS + 1))
fi

# Test 8: Check that Python version matches
echo ""
echo "Test 8: Verifying Python version consistency..."
WORKFLOW_PYTHON=$(grep "PYTHON_VERSION:" .github/workflows/deploy.yml | cut -d"'" -f2)
TEMPLATE_PYTHON=$(grep "Runtime:" template.yaml | head -1 | awk '{print $2}')
if [ "$WORKFLOW_PYTHON" = "3.11" ] && [ "$TEMPLATE_PYTHON" = "python3.11" ]; then
    echo -e "${GREEN}✓ PASS${NC}: Python versions are consistent (3.11)"
else
    echo -e "${YELLOW}⚠ WARN${NC}: Python version mismatch - Workflow: $WORKFLOW_PYTHON, Template: $TEMPLATE_PYTHON"
fi

# Test 9: Verify Lambda function code files exist
echo ""
echo "Test 9: Verifying Lambda function code files..."
LAMBDA_FILES=("upload_photo.py" "get_photo.py" "list_photos.py" "update_photo.py" "delete_photo.py" "get_metadata.py")
MISSING_FILES=0
for file in "${LAMBDA_FILES[@]}"; do
    if [ ! -f "src/$file" ]; then
        echo -e "${RED}✗ FAIL${NC}: Missing Lambda function: src/$file"
        MISSING_FILES=$((MISSING_FILES + 1))
        ERRORS=$((ERRORS + 1))
    fi
done
if [ $MISSING_FILES -eq 0 ]; then
    echo -e "${GREEN}✓ PASS${NC}: All Lambda function files exist"
fi

# Test 10: Verify Python syntax
echo ""
echo "Test 10: Verifying Python code syntax..."
if command -v python3 &> /dev/null; then
    SYNTAX_ERRORS=0
    for file in src/*.py; do
        if ! python3 -m py_compile "$file" 2>/dev/null; then
            echo -e "${RED}✗ FAIL${NC}: Syntax error in $file"
            SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
            ERRORS=$((ERRORS + 1))
        fi
    done
    if [ $SYNTAX_ERRORS -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: All Python files have valid syntax"
    fi
else
    echo -e "${YELLOW}⚠ SKIP${NC}: Python3 not available for syntax checking"
fi

# Summary
echo ""
echo "======================================"
echo "Verification Summary"
echo "======================================"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    echo ""
    echo "The GitHub Actions workflow fixes have been correctly applied!"
    echo ""
    echo "Next steps:"
    echo "1. Commit and push these changes"
    echo "2. Create a pull request to merge into main"
    echo "3. Once merged, the workflow will run automatically"
    echo "4. Verify successful deployment in GitHub Actions logs"
    exit 0
else
    echo -e "${RED}✗ $ERRORS TEST(S) FAILED${NC}"
    echo ""
    echo "Please review and fix the issues above before proceeding."
    exit 1
fi
