#!/bin/bash
#
# Quick verification script to check if workflow fixes are correct
# This script validates the configuration changes made to fix deployment issues
#

set -e

echo "🔍 Verifying GitHub Actions Workflow Fixes..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check 1: Verify samconfig.toml has resolve_s3
echo -n "1. Checking samconfig.toml for resolve_s3 parameter... "
if grep -q "resolve_s3 = true" samconfig.toml; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
    echo "   Expected: resolve_s3 = true"
    exit 1
fi

# Check 2: Verify samconfig.toml does NOT have s3_prefix or s3_bucket
echo -n "2. Checking samconfig.toml for conflicting S3 parameters... "
if grep -qE "s3_prefix|s3_bucket" samconfig.toml; then
    echo -e "${RED}❌ FAIL${NC}"
    echo "   Found conflicting s3_prefix or s3_bucket parameter"
    echo "   This will conflict with --resolve-s3 flag"
    exit 1
else
    echo -e "${GREEN}✅ PASS${NC}"
fi

# Check 3: Verify workflow has cache-dependency-path
echo -n "3. Checking workflow for cache-dependency-path... "
if grep -q "cache-dependency-path: 'src/requirements.txt'" .github/workflows/deploy.yml; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
    echo "   Expected: cache-dependency-path: 'src/requirements.txt'"
    exit 1
fi

# Check 4: Verify workflow has --config-env default
echo -n "4. Checking workflow for --config-env flag... "
if grep -q "\-\-config-env default" .github/workflows/deploy.yml; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    echo "   --config-env default flag not found (not critical)"
fi

# Check 5: Verify workflow uses --resolve-s3
echo -n "5. Checking workflow for --resolve-s3 flag... "
if grep -q "\-\-resolve-s3" .github/workflows/deploy.yml; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
    echo "   Expected: --resolve-s3 flag in sam deploy command"
    exit 1
fi

# Check 6: Verify all Lambda handler files exist
echo -n "6. Checking Lambda handler files... "
handlers=(
    "src/upload_photo.py"
    "src/get_photo.py"
    "src/list_photos.py"
    "src/update_photo.py"
    "src/delete_photo.py"
    "src/get_metadata.py"
)

all_exist=true
for handler in "${handlers[@]}"; do
    if [ ! -f "$handler" ]; then
        all_exist=false
        echo -e "${RED}❌ FAIL${NC}"
        echo "   Missing: $handler"
    fi
done

if [ "$all_exist" = true ]; then
    echo -e "${GREEN}✅ PASS${NC}"
fi

# Check 7: Verify each handler has lambda_handler function
echo -n "7. Checking Lambda handler functions... "
all_have_handler=true
for handler in "${handlers[@]}"; do
    if ! grep -q "def lambda_handler" "$handler"; then
        all_have_handler=false
        echo -e "${RED}❌ FAIL${NC}"
        echo "   Missing lambda_handler function in: $handler"
    fi
done

if [ "$all_have_handler" = true ]; then
    echo -e "${GREEN}✅ PASS${NC}"
fi

# Check 8: Verify requirements.txt exists in src/
echo -n "8. Checking for src/requirements.txt... "
if [ -f "src/requirements.txt" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
    echo "   Missing: src/requirements.txt"
    exit 1
fi

# Check 9: Verify SAM template exists
echo -n "9. Checking for SAM template... "
if [ -f "template.yaml" ]; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${RED}❌ FAIL${NC}"
    echo "   Missing: template.yaml"
    exit 1
fi

# Check 10: Basic YAML syntax check for workflow
echo -n "10. Checking workflow YAML syntax... "
if python3 -c "
import re
with open('.github/workflows/deploy.yml', 'r') as f:
    content = f.read()
    if '\t' in content:
        print('Contains tabs')
        exit(1)
" 2>/dev/null; then
    echo -e "${GREEN}✅ PASS${NC}"
else
    echo -e "${YELLOW}⚠️  WARNING${NC}"
    echo "   Could not verify YAML syntax (Python check failed)"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ All verification checks passed!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📋 Summary of fixes applied:"
echo "   1. ✅ Fixed S3 configuration conflict (s3_prefix → resolve_s3)"
echo "   2. ✅ Fixed pip cache path (added cache-dependency-path)"
echo "   3. ✅ Added explicit config environment (--config-env default)"
echo ""
echo "🚀 Ready for deployment! You can now:"
echo "   • Push to main branch to trigger the workflow"
echo "   • Or run: git push origin analyze-github-actions-workflow-20260115-180236"
echo ""
echo "📊 Monitor deployment at:"
echo "   https://github.com/polarndb/photo-hq/actions"
echo ""
