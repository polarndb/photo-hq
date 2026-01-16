#!/bin/bash

echo "====================================="
echo "Quick Deployment Fixes Verification"
echo "====================================="
echo ""

SUCCESS=0
TOTAL=0

check() {
    ((TOTAL++))
    if [ $1 -eq 0 ]; then
        echo "✅ $2"
        ((SUCCESS++))
    else
        echo "❌ $2"
    fi
}

# Check workflow modifications
! grep -q "sam build --use-container" .github/workflows/deploy.yml
check $? "Removed --use-container from SAM build"

grep -q "Handle deployment failure" .github/workflows/deploy.yml
check $? "Added deployment failure handling"

grep -q "Check for existing stack" .github/workflows/deploy.yml
check $? "Added stack status validation"

grep -q "Verify Lambda Functions" .github/workflows/deploy.yml
check $? "Added Lambda function verification"

grep -q "Generate deployment summary" .github/workflows/deploy.yml
check $? "Added deployment summaries"

grep -q "\-\-disable-rollback" .github/workflows/deploy.yml
check $? "Added --disable-rollback flag"

grep -q "\-\-tags" .github/workflows/deploy.yml
check $? "Added resource tagging"

# Check template modifications
grep -q "Architectures:" template.yaml
check $? "Added Lambda architecture specification"

grep -q "LOG_LEVEL:" template.yaml
check $? "Added LOG_LEVEL environment variable"

grep -q "logs:CreateLogGroup" template.yaml
check $? "Added CloudWatch Logs permissions"

grep -q "DeletionPolicy: Retain" template.yaml
check $? "Added S3 deletion policy"

grep -A 5 "Globals:" template.yaml | grep -q "Tags:"
check $? "Added tags to Lambda Globals"

# Check samconfig modifications
grep -q "\[default.build.parameters\]" samconfig.toml
check $? "Added build parameters section"

grep -q "cached = true" samconfig.toml
check $? "Enabled build caching"

grep -q "disable_rollback = true" samconfig.toml
check $? "Configured disable rollback"

grep -q "tags =" samconfig.toml
check $? "Configured resource tags"

# Check documentation
test -f "DEPLOYMENT_FIXES.md"
check $? "Created DEPLOYMENT_FIXES.md"

test -f "PR_DESCRIPTION.md"
check $? "Created PR_DESCRIPTION.md"

# Check Lambda handlers
test -f "src/upload_photo.py"
check $? "upload_photo.py exists"

test -f "src/get_photo.py"
check $? "get_photo.py exists"

test -f "src/list_photos.py"
check $? "list_photos.py exists"

test -f "src/update_photo.py"
check $? "update_photo.py exists"

test -f "src/delete_photo.py"
check $? "delete_photo.py exists"

test -f "src/get_metadata.py"
check $? "get_metadata.py exists"

# Resource counts
LAMBDA_COUNT=$(grep -c "Type: AWS::Serverless::Function" template.yaml)
test "$LAMBDA_COUNT" -eq 6
check $? "Correct number of Lambda functions (6)"

S3_COUNT=$(grep -c "Type: AWS::S3::Bucket" template.yaml)
test "$S3_COUNT" -eq 2
check $? "Correct number of S3 buckets (2)"

echo ""
echo "====================================="
echo "Result: $SUCCESS/$TOTAL checks passed"
echo "====================================="

if [ "$SUCCESS" -eq "$TOTAL" ]; then
    echo ""
    echo "🎉 All checks passed! Ready to deploy."
    echo ""
    echo "Next steps:"
    echo "  1. git push origin $(git branch --show-current)"
    echo "  2. Create pull request on GitHub"
    echo "  3. Merge to main to trigger deployment"
    exit 0
else
    echo ""
    echo "⚠️  Some checks did not pass. Review above."
    exit 1
fi
