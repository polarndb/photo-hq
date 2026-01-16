#!/bin/bash

# Verification script for comprehensive GitHub Actions deployment fixes
# This script validates all changes made to fix deployment workflow issues

set -e

echo "========================================"
echo "Deployment Fixes Verification Script"
echo "========================================"
echo ""

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SUCCESS=0
WARNINGS=0
FAILURES=0

check_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((SUCCESS++))
}

check_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAILURES++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
    ((WARNINGS++))
}

echo "1. Checking workflow file modifications..."
if [ -f ".github/workflows/deploy.yml" ]; then
    check_pass "Workflow file exists"
    
    # Check for --use-container removal
    if ! grep -q "sam build --use-container" .github/workflows/deploy.yml; then
        check_pass "--use-container flag removed from SAM build"
    else
        check_fail "--use-container flag still present (should be removed)"
    fi
    
    # Check for error handling step
    if grep -q "Handle deployment failure" .github/workflows/deploy.yml; then
        check_pass "Deployment failure handling added"
    else
        check_fail "Deployment failure handling missing"
    fi
    
    # Check for stack status check
    if grep -q "Check for existing stack" .github/workflows/deploy.yml; then
        check_pass "Stack status validation added"
    else
        check_fail "Stack status validation missing"
    fi
    
    # Check for Lambda verification
    if grep -q "Verify Lambda Functions" .github/workflows/deploy.yml; then
        check_pass "Lambda function verification added"
    else
        check_fail "Lambda function verification missing"
    fi
    
    # Check for deployment summaries
    if grep -q "Generate deployment summary" .github/workflows/deploy.yml; then
        check_pass "Deployment summary generation added"
    else
        check_fail "Deployment summary generation missing"
    fi
    
    # Check for --disable-rollback
    if grep -q "\-\-disable-rollback" .github/workflows/deploy.yml; then
        check_pass "--disable-rollback flag added"
    else
        check_warn "--disable-rollback flag not found"
    fi
    
    # Check for tags
    if grep -q "\-\-tags" .github/workflows/deploy.yml; then
        check_pass "Resource tagging added to deployment"
    else
        check_fail "Resource tagging missing from deployment"
    fi
else
    check_fail "Workflow file not found"
fi

echo ""
echo "2. Checking SAM template modifications..."
if [ -f "template.yaml" ]; then
    check_pass "SAM template exists"
    
    # Check for Architecture specification
    if grep -q "Architectures:" template.yaml; then
        check_pass "Lambda architecture specified"
    else
        check_fail "Lambda architecture not specified"
    fi
    
    # Check for LOG_LEVEL
    if grep -q "LOG_LEVEL:" template.yaml; then
        check_pass "LOG_LEVEL environment variable added"
    else
        check_fail "LOG_LEVEL environment variable missing"
    fi
    
    # Check for CloudWatch Logs permissions
    if grep -q "logs:CreateLogGroup" template.yaml; then
        check_pass "CloudWatch Logs permissions added to Lambda functions"
    else
        check_fail "CloudWatch Logs permissions missing"
    fi
    
    # Check for DeletionPolicy
    if grep -q "DeletionPolicy: Retain" template.yaml; then
        check_pass "S3 bucket deletion policy added"
    else
        check_fail "S3 bucket deletion policy missing"
    fi
    
    # Check for resource tags in Globals
    if grep -A 5 "Globals:" template.yaml | grep -q "Tags:"; then
        check_pass "Resource tags added to Lambda Globals"
    else
        check_fail "Resource tags missing from Lambda Globals"
    fi
    
    # Check for UpdateReplacePolicy
    if grep -q "UpdateReplacePolicy: Retain" template.yaml; then
        check_pass "S3 bucket update replace policy added"
    else
        check_warn "S3 bucket update replace policy not found"
    fi
else
    check_fail "SAM template not found"
fi

echo ""
echo "3. Checking samconfig.toml modifications..."
if [ -f "samconfig.toml" ]; then
    check_pass "SAM config file exists"
    
    # Check for build parameters
    if grep -q "\[default.build.parameters\]" samconfig.toml; then
        check_pass "Build parameters section added"
    else
        check_fail "Build parameters section missing"
    fi
    
    # Check for caching
    if grep -q "cached = true" samconfig.toml; then
        check_pass "Build caching enabled"
    else
        check_warn "Build caching not enabled"
    fi
    
    # Check for disable_rollback
    if grep -q "disable_rollback = true" samconfig.toml; then
        check_pass "Disable rollback configured"
    else
        check_warn "Disable rollback not configured"
    fi
    
    # Check for tags
    if grep -q "tags =" samconfig.toml; then
        check_pass "Resource tags configured"
    else
        check_fail "Resource tags not configured"
    fi
    
    # Check for lint configuration
    if grep -q "lint = true" samconfig.toml; then
        check_pass "Template linting enabled"
    else
        check_warn "Template linting not enabled"
    fi
else
    check_fail "SAM config file not found"
fi

echo ""
echo "4. Checking documentation..."
if [ -f "DEPLOYMENT_FIXES.md" ]; then
    check_pass "DEPLOYMENT_FIXES.md documentation created"
    
    # Check documentation completeness
    if grep -q "Root Cause Analysis" DEPLOYMENT_FIXES.md; then
        check_pass "Root cause analysis documented"
    else
        check_warn "Root cause analysis not found in documentation"
    fi
    
    if grep -q "Best Practices" DEPLOYMENT_FIXES.md; then
        check_pass "Best practices documented"
    else
        check_warn "Best practices not documented"
    fi
else
    check_fail "DEPLOYMENT_FIXES.md documentation not found"
fi

if [ -f "PR_DESCRIPTION.md" ]; then
    check_pass "PR_DESCRIPTION.md created"
else
    check_warn "PR_DESCRIPTION.md not found (optional)"
fi

echo ""
echo "5. Checking Python source files..."
if [ -f "src/requirements.txt" ]; then
    check_pass "Lambda requirements.txt exists"
    
    if grep -q "boto3" src/requirements.txt; then
        check_pass "boto3 dependency specified"
    else
        check_warn "boto3 not explicitly in requirements.txt (available in Lambda runtime)"
    fi
else
    check_fail "Lambda requirements.txt not found"
fi

# Check for Python source files
PYTHON_FILES=$(find src -name "*.py" -type f 2>/dev/null | wc -l)
if [ "$PYTHON_FILES" -gt 0 ]; then
    check_pass "Found $PYTHON_FILES Python Lambda function files"
else
    check_fail "No Python Lambda function files found"
fi

echo ""
echo "6. Checking Lambda function handlers..."
EXPECTED_HANDLERS=("upload_photo.py" "get_photo.py" "list_photos.py" "update_photo.py" "delete_photo.py" "get_metadata.py")
for handler in "${EXPECTED_HANDLERS[@]}"; do
    if [ -f "src/$handler" ]; then
        check_pass "Handler $handler exists"
    else
        check_fail "Handler $handler not found"
    fi
done

echo ""
echo "7. Validating YAML syntax..."
# Try to validate YAML if tools are available
if command -v python3 &> /dev/null; then
    if python3 -c "import yaml" 2>/dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('template.yaml'))" 2>/dev/null; then
            check_pass "template.yaml has valid YAML syntax"
        else
            check_fail "template.yaml has invalid YAML syntax"
        fi
        
        if python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy.yml'))" 2>/dev/null; then
            check_pass "deploy.yml has valid YAML syntax"
        else
            check_fail "deploy.yml has invalid YAML syntax"
        fi
    else
        check_warn "PyYAML not available for validation"
    fi
else
    check_warn "Python3 not available for validation"
fi

echo ""
echo "8. Summary of resource definitions in template..."
if [ -f "template.yaml" ]; then
    LAMBDA_COUNT=$(grep -c "Type: AWS::Serverless::Function" template.yaml)
    S3_COUNT=$(grep -c "Type: AWS::S3::Bucket" template.yaml)
    DYNAMO_COUNT=$(grep -c "Type: AWS::DynamoDB::Table" template.yaml)
    API_COUNT=$(grep -c "Type: AWS::Serverless::Api" template.yaml)
    COGNITO_POOL_COUNT=$(grep -c "Type: AWS::Cognito::UserPool" template.yaml)
    COGNITO_CLIENT_COUNT=$(grep -c "Type: AWS::Cognito::UserPoolClient" template.yaml)
    
    echo "  Lambda Functions: $LAMBDA_COUNT (expected: 6)"
    echo "  S3 Buckets: $S3_COUNT (expected: 2)"
    echo "  DynamoDB Tables: $DYNAMO_COUNT (expected: 1)"
    echo "  API Gateways: $API_COUNT (expected: 1)"
    echo "  Cognito User Pools: $COGNITO_POOL_COUNT (expected: 1)"
    echo "  Cognito User Pool Clients: $COGNITO_CLIENT_COUNT (expected: 1)"
    
    if [ "$LAMBDA_COUNT" -eq 6 ]; then check_pass "Correct number of Lambda functions"; else check_fail "Incorrect Lambda function count"; fi
    if [ "$S3_COUNT" -eq 2 ]; then check_pass "Correct number of S3 buckets"; else check_fail "Incorrect S3 bucket count"; fi
    if [ "$DYNAMO_COUNT" -eq 1 ]; then check_pass "Correct number of DynamoDB tables"; else check_fail "Incorrect DynamoDB table count"; fi
    if [ "$API_COUNT" -eq 1 ]; then check_pass "Correct number of API Gateways"; else check_fail "Incorrect API Gateway count"; fi
fi

echo ""
echo "========================================"
echo "Verification Summary"
echo "========================================"
echo -e "${GREEN}Successful Checks: $SUCCESS${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Failed Checks: $FAILURES${NC}"
echo ""

if [ "$FAILURES" -eq 0 ]; then
    echo -e "${GREEN}🎉 All critical checks passed!${NC}"
    echo ""
    echo "The deployment workflow fixes are complete and validated."
    echo "You can now push this branch and create a pull request."
    echo ""
    echo "Next steps:"
    echo "  1. git push origin $(git branch --show-current)"
    echo "  2. Create pull request on GitHub"
    echo "  3. Merge to main to trigger deployment"
    exit 0
else
    echo -e "${RED}❌ Some checks failed. Please review the failures above.${NC}"
    exit 1
fi
