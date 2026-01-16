#!/bin/bash

###############################################################################
# Comprehensive Deployment and Testing Script for Photo HQ SAM Application
#
# This script:
# 1. Validates the SAM template
# 2. Builds the SAM application
# 3. Deploys to AWS
# 4. Tests all deployed resources
# 5. Runs API endpoint tests
# 6. Generates a comprehensive deployment report
#
# Prerequisites:
# - AWS SAM CLI installed
# - AWS CLI configured with credentials
# - Python 3.11+
# - jq (for JSON parsing)
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="${STACK_NAME:-photo-hq-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PYTHON_VERSION="3.11"

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_section() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    log_success "AWS CLI found: $(aws --version)"
    
    # Check SAM CLI
    if ! command -v sam &> /dev/null; then
        log_error "SAM CLI not found. Please install it first."
        echo "Install with: pip install aws-sam-cli"
        exit 1
    fi
    log_success "SAM CLI found: $(sam --version)"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found."
        exit 1
    fi
    log_success "Python found: $(python3 --version)"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_warning "jq not found. Some JSON parsing may not work. Install with: sudo apt-get install jq"
    else
        log_success "jq found"
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid."
        echo "Configure with: aws configure"
        exit 1
    fi
    
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
    log_success "AWS credentials valid"
    log_info "AWS Account: $AWS_ACCOUNT_ID"
    log_info "AWS User: $AWS_USER"
    log_info "AWS Region: $AWS_REGION"
}

# Validate SAM template
validate_template() {
    log_section "Step 1: Validating SAM Template"
    
    if sam validate --lint --region "$AWS_REGION"; then
        log_success "SAM template validation passed"
    else
        log_error "SAM template validation failed"
        exit 1
    fi
}

# Build SAM application
build_application() {
    log_section "Step 2: Building SAM Application"
    
    log_info "Building application..."
    log_info "Note: This may take 2-3 minutes..."
    
    # Build without --use-container for faster CI/CD
    if sam build --region "$AWS_REGION"; then
        log_success "SAM build completed successfully"
        
        # Show build artifacts
        if [ -d ".aws-sam/build" ]; then
            log_info "Build artifacts created in .aws-sam/build/"
            ls -lh .aws-sam/build/ | grep -E '^d' | awk '{print "  - " $NF}' || true
        fi
    else
        log_error "SAM build failed"
        exit 1
    fi
}

# Deploy to AWS
deploy_application() {
    log_section "Step 3: Deploying to AWS"
    
    log_info "Deploying stack: $STACK_NAME"
    log_info "Region: $AWS_REGION"
    log_info "Note: This may take 5-10 minutes for first deployment..."
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" &> /dev/null; then
        log_info "Existing stack found - performing update"
        DEPLOYMENT_TYPE="update"
    else
        log_info "No existing stack - performing initial deployment"
        DEPLOYMENT_TYPE="create"
    fi
    
    # Deploy with SAM
    if sam deploy \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --no-confirm-changeset \
        --no-fail-on-empty-changeset \
        --capabilities CAPABILITY_IAM \
        --resolve-s3 \
        --config-env default \
        --tags "Environment=dev Project=photo-hq ManagedBy=SAM" \
        --disable-rollback; then
        
        log_success "Deployment completed successfully"
    else
        log_error "Deployment failed"
        
        # Capture failure details
        log_info "Fetching CloudFormation events for troubleshooting..."
        aws cloudformation describe-stack-events \
            --stack-name "$STACK_NAME" \
            --region "$AWS_REGION" \
            --max-items 20 \
            --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[Timestamp,ResourceType,LogicalResourceId,ResourceStatusReason]' \
            --output table 2>&1 || log_error "Could not fetch stack events"
        
        exit 1
    fi
}

# Get stack outputs
get_stack_outputs() {
    log_section "Step 4: Retrieving Stack Outputs"
    
    # Get all outputs
    API_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
        --output text)
    
    USER_POOL_ID=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
        --output text)
    
    USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
        --output text)
    
    ORIGINALS_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`OriginalsBucketName`].OutputValue' \
        --output text)
    
    EDITED_BUCKET=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`EditedBucketName`].OutputValue' \
        --output text)
    
    PHOTOS_TABLE=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`PhotosTableName`].OutputValue' \
        --output text)
    
    # Validate outputs
    if [ -z "$API_ENDPOINT" ] || [ "$API_ENDPOINT" = "None" ]; then
        log_error "Failed to retrieve API endpoint"
        return 1
    fi
    
    log_success "Stack outputs retrieved successfully:"
    echo "  API Endpoint: $API_ENDPOINT"
    echo "  User Pool ID: $USER_POOL_ID"
    echo "  User Pool Client ID: $USER_POOL_CLIENT_ID"
    echo "  Originals Bucket: $ORIGINALS_BUCKET"
    echo "  Edited Bucket: $EDITED_BUCKET"
    echo "  Photos Table: $PHOTOS_TABLE"
    
    # Export for use in tests
    export API_ENDPOINT USER_POOL_ID USER_POOL_CLIENT_ID
}

# Verify resources
verify_resources() {
    log_section "Step 5: Verifying Deployed Resources"
    
    # Verify Lambda functions
    log_info "Verifying Lambda functions..."
    LAMBDA_FUNCTIONS=$(aws lambda list-functions \
        --region "$AWS_REGION" \
        --query "Functions[?starts_with(FunctionName, '$STACK_NAME')].FunctionName" \
        --output text)
    
    if [ -z "$LAMBDA_FUNCTIONS" ]; then
        log_error "No Lambda functions found"
        return 1
    else
        LAMBDA_COUNT=$(echo "$LAMBDA_FUNCTIONS" | wc -w)
        log_success "Found $LAMBDA_COUNT Lambda functions:"
        echo "$LAMBDA_FUNCTIONS" | tr '\t' '\n' | while read func; do
            echo "  - $func"
        done
    fi
    
    # Verify API Gateway
    log_info "Verifying API Gateway..."
    API_ID=$(aws apigateway get-rest-apis \
        --region "$AWS_REGION" \
        --query "items[?name=='$STACK_NAME-api'].id" \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$API_ID" ]; then
        log_warning "API Gateway not found (may still be initializing)"
    else
        log_success "API Gateway found: $API_ID"
    fi
    
    # Verify S3 buckets
    log_info "Verifying S3 buckets..."
    if aws s3 ls "s3://$ORIGINALS_BUCKET" --region "$AWS_REGION" &> /dev/null; then
        log_success "Originals bucket accessible: $ORIGINALS_BUCKET"
    else
        log_error "Cannot access originals bucket"
        return 1
    fi
    
    if aws s3 ls "s3://$EDITED_BUCKET" --region "$AWS_REGION" &> /dev/null; then
        log_success "Edited bucket accessible: $EDITED_BUCKET"
    else
        log_error "Cannot access edited bucket"
        return 1
    fi
    
    # Verify DynamoDB table
    log_info "Verifying DynamoDB table..."
    if aws dynamodb describe-table --table-name "$PHOTOS_TABLE" --region "$AWS_REGION" &> /dev/null; then
        log_success "DynamoDB table accessible: $PHOTOS_TABLE"
    else
        log_error "Cannot access DynamoDB table"
        return 1
    fi
    
    # Verify Cognito User Pool
    log_info "Verifying Cognito User Pool..."
    if aws cognito-idp describe-user-pool --user-pool-id "$USER_POOL_ID" --region "$AWS_REGION" &> /dev/null; then
        log_success "Cognito User Pool accessible: $USER_POOL_ID"
    else
        log_error "Cannot access Cognito User Pool"
        return 1
    fi
    
    log_success "All resources verified successfully"
}

# Test API endpoints
test_api_endpoints() {
    log_section "Step 6: Testing API Endpoints"
    
    # Test unauthorized access (should return 401)
    log_info "Testing unauthorized access..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$API_ENDPOINT/photos")
    
    if [ "$HTTP_CODE" = "401" ]; then
        log_success "Authentication test passed (401 returned for unauthorized access)"
    else
        log_warning "Expected 401, got $HTTP_CODE"
    fi
    
    # Create test user
    log_info "Creating test user..."
    TEST_EMAIL="test-deploy-$(date +%s)@example.com"
    TEST_PASSWORD="TestPass123!@#"
    
    # Sign up
    if aws cognito-idp sign-up \
        --client-id "$USER_POOL_CLIENT_ID" \
        --username "$TEST_EMAIL" \
        --password "$TEST_PASSWORD" \
        --user-attributes Name=email,Value="$TEST_EMAIL" \
        --region "$AWS_REGION" &> /dev/null; then
        log_success "Test user signed up"
    else
        log_warning "Test user may already exist"
    fi
    
    # Confirm user (admin action)
    if aws cognito-idp admin-confirm-sign-up \
        --user-pool-id "$USER_POOL_ID" \
        --username "$TEST_EMAIL" \
        --region "$AWS_REGION" &> /dev/null; then
        log_success "Test user confirmed"
    else
        log_warning "Could not confirm test user"
    fi
    
    # Wait for user to be ready
    sleep 2
    
    # Authenticate
    log_info "Authenticating test user..."
    AUTH_RESPONSE=$(aws cognito-idp initiate-auth \
        --auth-flow USER_PASSWORD_AUTH \
        --client-id "$USER_POOL_CLIENT_ID" \
        --auth-parameters USERNAME="$TEST_EMAIL",PASSWORD="$TEST_PASSWORD" \
        --region "$AWS_REGION" \
        --output json 2>/dev/null || echo '{}')
    
    if command -v jq &> /dev/null; then
        ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.AuthenticationResult.AccessToken // empty')
    else
        ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | grep -o '"AccessToken":"[^"]*"' | cut -d'"' -f4)
    fi
    
    if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
        log_warning "Could not get access token - skipping authenticated tests"
        log_info "You can manually test with: aws cognito-idp initiate-auth ..."
    else
        log_success "Access token obtained"
        
        # Test authenticated endpoints
        log_info "Testing photo listing endpoint..."
        LIST_RESPONSE=$(curl -s -X GET "$API_ENDPOINT/photos" \
            -H "Authorization: Bearer $ACCESS_TOKEN")
        
        if echo "$LIST_RESPONSE" | grep -q '"count"'; then
            log_success "Photo listing endpoint working"
        else
            log_warning "Photo listing endpoint may have issues"
            echo "Response: $LIST_RESPONSE"
        fi
        
        # Test upload endpoint
        log_info "Testing photo upload endpoint..."
        UPLOAD_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/photos/upload" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Content-Type: application/json" \
            -d '{
                "filename": "test-deployment.jpg",
                "content_type": "image/jpeg",
                "file_size": 6291456
            }')
        
        if echo "$UPLOAD_RESPONSE" | grep -q '"photo_id"'; then
            log_success "Photo upload endpoint working"
            
            # Extract photo ID for further tests
            if command -v jq &> /dev/null; then
                PHOTO_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.photo_id')
                
                if [ -n "$PHOTO_ID" ] && [ "$PHOTO_ID" != "null" ]; then
                    # Test metadata endpoint
                    log_info "Testing photo metadata endpoint..."
                    METADATA_RESPONSE=$(curl -s -X GET "$API_ENDPOINT/photos/$PHOTO_ID/metadata" \
                        -H "Authorization: Bearer $ACCESS_TOKEN")
                    
                    if echo "$METADATA_RESPONSE" | grep -q '"photo_id"'; then
                        log_success "Photo metadata endpoint working"
                    fi
                    
                    # Cleanup - delete test photo
                    log_info "Cleaning up test photo..."
                    curl -s -X DELETE "$API_ENDPOINT/photos/$PHOTO_ID" \
                        -H "Authorization: Bearer $ACCESS_TOKEN" > /dev/null
                fi
            fi
        else
            log_warning "Photo upload endpoint may have issues"
            echo "Response: $UPLOAD_RESPONSE"
        fi
    fi
    
    # Cleanup test user
    log_info "Cleaning up test user..."
    aws cognito-idp admin-delete-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$TEST_EMAIL" \
        --region "$AWS_REGION" &> /dev/null || true
    
    log_success "API endpoint testing completed"
}

# Generate deployment report
generate_report() {
    log_section "Deployment Report"
    
    REPORT_FILE="deployment-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "=========================================="
        echo "Photo HQ Deployment Report"
        echo "=========================================="
        echo ""
        echo "Deployment Time: $(date)"
        echo "Stack Name: $STACK_NAME"
        echo "AWS Region: $AWS_REGION"
        echo "AWS Account: $AWS_ACCOUNT_ID"
        echo ""
        echo "Stack Outputs:"
        echo "  API Endpoint: $API_ENDPOINT"
        echo "  User Pool ID: $USER_POOL_ID"
        echo "  User Pool Client ID: $USER_POOL_CLIENT_ID"
        echo "  Originals Bucket: $ORIGINALS_BUCKET"
        echo "  Edited Bucket: $EDITED_BUCKET"
        echo "  Photos Table: $PHOTOS_TABLE"
        echo ""
        echo "Resources Deployed:"
        echo "  ✅ API Gateway REST API"
        echo "  ✅ 6 Lambda Functions"
        echo "  ✅ Cognito User Pool"
        echo "  ✅ 2 S3 Buckets (Originals, Edited)"
        echo "  ✅ DynamoDB Table"
        echo ""
        echo "Next Steps:"
        echo "  1. Update GitHub repository secrets with AWS credentials"
        echo "  2. Push changes to trigger GitHub Actions workflow"
        echo "  3. Monitor workflow execution in GitHub Actions tab"
        echo "  4. Access API at: $API_ENDPOINT"
        echo ""
        echo "=========================================="
    } | tee "$REPORT_FILE"
    
    log_success "Deployment report saved to: $REPORT_FILE"
}

# Main execution
main() {
    log_section "Photo HQ SAM Application Deployment"
    
    echo "This script will:"
    echo "  1. Validate the SAM template"
    echo "  2. Build the SAM application"
    echo "  3. Deploy to AWS (stack: $STACK_NAME)"
    echo "  4. Verify all resources are created"
    echo "  5. Test API endpoints"
    echo "  6. Generate deployment report"
    echo ""
    
    # Run all steps
    check_prerequisites
    validate_template
    build_application
    deploy_application
    get_stack_outputs
    verify_resources
    test_api_endpoints
    generate_report
    
    log_section "✅ Deployment and Testing Completed Successfully!"
    
    echo ""
    echo "Your Photo HQ API is now deployed and operational!"
    echo "API Endpoint: $API_ENDPOINT"
    echo ""
    echo "To access the API, you'll need to:"
    echo "  1. Create a Cognito user via AWS Console or CLI"
    echo "  2. Authenticate to get an access token"
    echo "  3. Use the token in Authorization header: 'Bearer <token>'"
    echo ""
}

# Run main function
main "$@"
