#!/bin/bash
#
# GitHub Actions Workflow Verification Script
# Verifies that the CI/CD workflow is properly configured
#

echo "=========================================="
echo "GitHub Actions Workflow Verification"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check counter
CHECKS_PASSED=0
CHECKS_FAILED=0

check_file() {
    local file="$1"
    local description="$2"
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $description"
        echo "   Found: $file"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $description"
        echo "   Missing: $file"
        ((CHECKS_FAILED++))
    fi
}

check_content() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        echo -e "${GREEN}✅ PASS${NC}: $description"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $description"
        echo "   Pattern not found: $pattern"
        ((CHECKS_FAILED++))
    fi
}

echo "1. Checking Workflow Files"
echo "─────────────────────────────────────────"
check_file ".github/workflows/deploy.yml" "Workflow configuration file"
check_file "CI_CD_SETUP.md" "CI/CD setup documentation"
check_file ".github/WORKFLOW_REFERENCE.md" "Quick reference guide"
check_file ".github/ARCHITECTURE.md" "Architecture diagrams"
check_file ".github/IMPLEMENTATION_SUMMARY.md" "Implementation summary"
echo ""

echo "2. Checking Workflow Configuration"
echo "─────────────────────────────────────────"
check_content ".github/workflows/deploy.yml" "name: Deploy and Test Photo HQ API" "Workflow name configured"
check_content ".github/workflows/deploy.yml" "on:" "Workflow triggers configured"
check_content ".github/workflows/deploy.yml" "push:" "Push trigger configured"
check_content ".github/workflows/deploy.yml" "branches:" "Branch filter configured"
check_content ".github/workflows/deploy.yml" "main" "Main branch trigger"
check_content ".github/workflows/deploy.yml" "workflow_dispatch:" "Manual trigger configured"
echo ""

echo "3. Checking Deploy Job"
echo "─────────────────────────────────────────"
check_content ".github/workflows/deploy.yml" "jobs:" "Jobs defined"
check_content ".github/workflows/deploy.yml" "deploy:" "Deploy job configured"
check_content ".github/workflows/deploy.yml" "aws-actions/configure-aws-credentials" "AWS credentials action"
check_content ".github/workflows/deploy.yml" "AWS_ACCESS_KEY_ID" "AWS access key secret reference"
check_content ".github/workflows/deploy.yml" "AWS_SECRET_ACCESS_KEY" "AWS secret key secret reference"
check_content ".github/workflows/deploy.yml" "sam build" "SAM build command"
check_content ".github/workflows/deploy.yml" "sam deploy" "SAM deploy command"
check_content ".github/workflows/deploy.yml" "no-confirm-changeset" "No confirmation flag"
check_content ".github/workflows/deploy.yml" "no-fail-on-empty-changeset" "No fail on empty flag"
echo ""

echo "4. Checking Test Job"
echo "─────────────────────────────────────────"
check_content ".github/workflows/deploy.yml" "test:" "Test job configured"
check_content ".github/workflows/deploy.yml" "needs: deploy" "Test depends on deploy"
check_content ".github/workflows/deploy.yml" "Create test user" "Test user creation step"
check_content ".github/workflows/deploy.yml" "cognito-idp sign-up" "Cognito signup command"
check_content ".github/workflows/deploy.yml" "cognito-idp initiate-auth" "Cognito auth command"
check_content ".github/workflows/deploy.yml" "comprehensive_api_test.py" "Comprehensive test suite"
echo ""

echo "5. Checking Test Coverage"
echo "─────────────────────────────────────────"
check_content ".github/workflows/deploy.yml" "Test authentication endpoint" "Auth test"
check_content ".github/workflows/deploy.yml" "Test photo upload endpoint" "Upload test"
check_content ".github/workflows/deploy.yml" "Test photo listing endpoint" "Listing test"
check_content ".github/workflows/deploy.yml" "Test photo metadata endpoint" "Metadata test"
check_content ".github/workflows/deploy.yml" "Test photo retrieval endpoint" "Retrieval test"
check_content ".github/workflows/deploy.yml" "Test photo update endpoint" "Update test"
check_content ".github/workflows/deploy.yml" "Test photo deletion endpoint" "Deletion test"
echo ""

echo "6. Checking Cleanup and Reporting"
echo "─────────────────────────────────────────"
check_content ".github/workflows/deploy.yml" "Cleanup test user" "Test user cleanup"
check_content ".github/workflows/deploy.yml" "if: always()" "Always cleanup condition"
check_content ".github/workflows/deploy.yml" "Generate test report" "Test report generation"
check_content ".github/workflows/deploy.yml" "GITHUB_STEP_SUMMARY" "Workflow summary output"
echo ""

echo "7. Checking README Updates"
echo "─────────────────────────────────────────"
check_content "README.md" "Deploy and Test" "Deployment badge"
check_content "README.md" "actions/workflows/deploy.yml" "Badge URL"
check_content "README.md" "CI/CD with GitHub Actions" "CI/CD section"
check_content "README.md" "AWS_ACCESS_KEY_ID" "Secret documentation"
check_content "README.md" "AWS_SECRET_ACCESS_KEY" "Secret documentation"
check_content "README.md" "GitHub Secrets" "Secrets setup instructions"
echo ""

echo "8. Checking Documentation"
echo "─────────────────────────────────────────"
check_content "CI_CD_SETUP.md" "Quick Setup" "Setup instructions"
check_content "CI_CD_SETUP.md" "IAM" "IAM documentation"
check_content "CI_CD_SETUP.md" "Troubleshooting" "Troubleshooting section"
check_content "CI_CD_SETUP.md" "GitHub OIDC" "OIDC documentation"
check_content ".github/WORKFLOW_REFERENCE.md" "Quick Reference" "Quick reference content"
check_content ".github/ARCHITECTURE.md" "Workflow Diagram" "Architecture diagrams"
echo ""

echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo -e "Checks Passed: ${GREEN}${CHECKS_PASSED}${NC}"
echo -e "Checks Failed: ${RED}${CHECKS_FAILED}${NC}"
echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "Next Steps:"
    echo "1. Configure GitHub Secrets (see CI_CD_SETUP.md)"
    echo "2. Push to main branch"
    echo "3. Monitor workflow in GitHub Actions tab"
    echo ""
    exit 0
else
    echo -e "${RED}❌ Some checks failed. Please review the errors above.${NC}"
    echo ""
    exit 1
fi
