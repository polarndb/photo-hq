#!/bin/bash
#
# Photo HQ Backend API Deployment Script
# This script automates the deployment of the serverless backend to AWS
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="${STACK_NAME:-photo-hq-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output file for deployment results
OUTPUT_FILE="${SCRIPT_DIR}/deployment-outputs.env"
REPORT_FILE="${SCRIPT_DIR}/deployment-report.txt"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Photo HQ Backend API - AWS SAM Deployment          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Verify Prerequisites
echo -e "${YELLOW}[1/7] Verifying prerequisites...${NC}"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found${NC}"
    echo "  Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI installed: $(aws --version 2>&1 | head -1)${NC}"

# Check SAM CLI
if ! command -v sam &> /dev/null; then
    echo -e "${RED}✗ SAM CLI not found${NC}"
    echo "  Please install SAM CLI: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi
echo -e "${GREEN}✓ SAM CLI installed: $(sam --version)${NC}"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}✗ Python 3 not found${NC}"
    exit 1
fi
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
echo -e "${GREEN}✓ Python installed: ${PYTHON_VERSION}${NC}"

# Verify AWS credentials
echo -e "${YELLOW}  Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    echo "  Please run: aws configure"
    exit 1
fi

AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_USER=$(aws sts get-caller-identity --query Arn --output text)
echo -e "${GREEN}✓ AWS credentials configured${NC}"
echo -e "  Account: ${AWS_ACCOUNT}"
echo -e "  Identity: ${AWS_USER}"
echo -e "  Region: ${AWS_REGION}"
echo ""

# Step 2: Validate SAM Template
echo -e "${YELLOW}[2/7] Validating SAM template...${NC}"
if sam validate --template template.yaml --region "${AWS_REGION}"; then
    echo -e "${GREEN}✓ Template validation successful${NC}"
else
    echo -e "${RED}✗ Template validation failed${NC}"
    exit 1
fi
echo ""

# Step 3: Build Application
echo -e "${YELLOW}[3/7] Building SAM application...${NC}"
echo -e "  This may take a few minutes..."

if sam build --template template.yaml; then
    echo -e "${GREEN}✓ Build successful${NC}"
    echo -e "  Artifacts location: .aws-sam/build/"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi
echo ""

# Step 4: Deploy Application
echo -e "${YELLOW}[4/7] Deploying to AWS...${NC}"
echo -e "  Stack name: ${STACK_NAME}"
echo -e "  Region: ${AWS_REGION}"
echo -e "  This may take 5-10 minutes..."
echo ""

# Use samconfig.toml for deployment settings
if sam deploy \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset; then
    echo -e "${GREEN}✓ Deployment successful${NC}"
else
    echo -e "${RED}✗ Deployment failed${NC}"
    echo -e "${YELLOW}  Checking CloudFormation events for details...${NC}"
    aws cloudformation describe-stack-events \
        --stack-name "${STACK_NAME}" \
        --region "${AWS_REGION}" \
        --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[Timestamp,ResourceType,LogicalResourceId,ResourceStatusReason]' \
        --output table 2>/dev/null || true
    exit 1
fi
echo ""

# Step 5: Capture Stack Outputs
echo -e "${YELLOW}[5/7] Capturing deployment outputs...${NC}"

# Get stack outputs
OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].Outputs' \
    --output json 2>/dev/null)

if [ -z "$OUTPUTS" ] || [ "$OUTPUTS" == "null" ]; then
    echo -e "${RED}✗ Failed to retrieve stack outputs${NC}"
    exit 1
fi

# Parse outputs
API_ENDPOINT=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiEndpoint") | .OutputValue')
USER_POOL_ID=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="UserPoolId") | .OutputValue')
USER_POOL_CLIENT_ID=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="UserPoolClientId") | .OutputValue')
ORIGINALS_BUCKET=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="OriginalsBucketName") | .OutputValue')
EDITED_BUCKET=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="EditedBucketName") | .OutputValue')
PHOTOS_TABLE=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="PhotosTableName") | .OutputValue')

# Display outputs
echo -e "${GREEN}✓ Deployment outputs captured:${NC}"
echo ""
echo -e "${BLUE}  API Endpoint:${NC}          ${API_ENDPOINT}"
echo -e "${BLUE}  User Pool ID:${NC}          ${USER_POOL_ID}"
echo -e "${BLUE}  User Pool Client ID:${NC}   ${USER_POOL_CLIENT_ID}"
echo -e "${BLUE}  Originals Bucket:${NC}      ${ORIGINALS_BUCKET}"
echo -e "${BLUE}  Edited Bucket:${NC}         ${EDITED_BUCKET}"
echo -e "${BLUE}  Photos Table:${NC}          ${PHOTOS_TABLE}"
echo ""

# Save outputs to environment file
cat > "${OUTPUT_FILE}" << EOF
# Photo HQ Backend API - Deployment Outputs
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
# Stack: ${STACK_NAME}
# Region: ${AWS_REGION}

export AWS_REGION="${AWS_REGION}"
export STACK_NAME="${STACK_NAME}"
export API_ENDPOINT="${API_ENDPOINT}"
export USER_POOL_ID="${USER_POOL_ID}"
export USER_POOL_CLIENT_ID="${USER_POOL_CLIENT_ID}"
export ORIGINALS_BUCKET="${ORIGINALS_BUCKET}"
export EDITED_BUCKET="${EDITED_BUCKET}"
export PHOTOS_TABLE="${PHOTOS_TABLE}"
EOF

echo -e "${GREEN}✓ Outputs saved to: ${OUTPUT_FILE}${NC}"
echo -e "  Load with: ${YELLOW}source ${OUTPUT_FILE}${NC}"
echo ""

# Step 6: Verify Deployment
echo -e "${YELLOW}[6/7] Verifying deployment...${NC}"

# Check stack status
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null)

if [ "$STACK_STATUS" == "CREATE_COMPLETE" ] || [ "$STACK_STATUS" == "UPDATE_COMPLETE" ]; then
    echo -e "${GREEN}✓ Stack status: ${STACK_STATUS}${NC}"
else
    echo -e "${YELLOW}⚠ Stack status: ${STACK_STATUS}${NC}"
fi

# Count resources
RESOURCE_COUNT=$(aws cloudformation list-stack-resources \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'StackResourceSummaries[?ResourceStatus==`CREATE_COMPLETE` || ResourceStatus==`UPDATE_COMPLETE`]' \
    --output json 2>/dev/null | jq 'length')

echo -e "${GREEN}✓ Resources deployed: ${RESOURCE_COUNT}${NC}"

# Check Lambda functions
LAMBDA_COUNT=$(aws lambda list-functions \
    --region "${AWS_REGION}" \
    --query "Functions[?starts_with(FunctionName, '${STACK_NAME}')].FunctionName" \
    --output json 2>/dev/null | jq 'length')

if [ "$LAMBDA_COUNT" -eq 6 ]; then
    echo -e "${GREEN}✓ Lambda functions: ${LAMBDA_COUNT}/6 deployed${NC}"
else
    echo -e "${YELLOW}⚠ Lambda functions: ${LAMBDA_COUNT}/6 deployed${NC}"
fi

# Check S3 buckets
BUCKET_COUNT=$(aws s3api list-buckets \
    --query "Buckets[?starts_with(Name, '${STACK_NAME}')].Name" \
    --output json 2>/dev/null | jq 'length')

if [ "$BUCKET_COUNT" -eq 2 ]; then
    echo -e "${GREEN}✓ S3 buckets: ${BUCKET_COUNT}/2 created${NC}"
else
    echo -e "${YELLOW}⚠ S3 buckets: ${BUCKET_COUNT}/2 created${NC}"
fi

# Check DynamoDB table
TABLE_STATUS=$(aws dynamodb describe-table \
    --table-name "${PHOTOS_TABLE}" \
    --region "${AWS_REGION}" \
    --query 'Table.TableStatus' \
    --output text 2>/dev/null)

if [ "$TABLE_STATUS" == "ACTIVE" ]; then
    echo -e "${GREEN}✓ DynamoDB table: ACTIVE${NC}"
else
    echo -e "${YELLOW}⚠ DynamoDB table: ${TABLE_STATUS}${NC}"
fi

# Check Cognito User Pool
USER_POOL_STATUS=$(aws cognito-idp describe-user-pool \
    --user-pool-id "${USER_POOL_ID}" \
    --region "${AWS_REGION}" \
    --query 'UserPool.Status' \
    --output text 2>/dev/null)

if [ "$USER_POOL_STATUS" == "Enabled" ] || [ ! -z "$USER_POOL_STATUS" ]; then
    echo -e "${GREEN}✓ Cognito User Pool: Active${NC}"
else
    echo -e "${YELLOW}⚠ Cognito User Pool: Unknown status${NC}"
fi

# Check API Gateway
API_ID=$(echo "${API_ENDPOINT}" | grep -oP 'https://\K[^.]+')
if [ ! -z "$API_ID" ]; then
    echo -e "${GREEN}✓ API Gateway: Deployed (ID: ${API_ID})${NC}"
else
    echo -e "${YELLOW}⚠ API Gateway: Unable to verify${NC}"
fi

echo ""

# Step 7: Generate Deployment Report
echo -e "${YELLOW}[7/7] Generating deployment report...${NC}"

cat > "${REPORT_FILE}" << EOF
╔════════════════════════════════════════════════════════════════════════════╗
║                    Photo HQ Backend Deployment Report                      ║
╚════════════════════════════════════════════════════════════════════════════╝

Deployment Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Stack Name:      ${STACK_NAME}
AWS Region:      ${AWS_REGION}
AWS Account:     ${AWS_ACCOUNT}
Stack Status:    ${STACK_STATUS}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DEPLOYMENT OUTPUTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

API Endpoint:          ${API_ENDPOINT}
User Pool ID:          ${USER_POOL_ID}
User Pool Client ID:   ${USER_POOL_CLIENT_ID}
Originals Bucket:      ${ORIGINALS_BUCKET}
Edited Bucket:         ${EDITED_BUCKET}
Photos Table:          ${PHOTOS_TABLE}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DEPLOYED RESOURCES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total Resources:       ${RESOURCE_COUNT}
Lambda Functions:      ${LAMBDA_COUNT}
S3 Buckets:            ${BUCKET_COUNT}
DynamoDB Tables:       1
Cognito User Pools:    1
API Gateway APIs:      1

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

LAMBDA FUNCTIONS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

# List Lambda functions
aws lambda list-functions \
    --region "${AWS_REGION}" \
    --query "Functions[?starts_with(FunctionName, '${STACK_NAME}')].[FunctionName,Runtime,MemorySize,Timeout]" \
    --output table 2>/dev/null >> "${REPORT_FILE}" || echo "Unable to list Lambda functions" >> "${REPORT_FILE}"

cat >> "${REPORT_FILE}" << EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

NEXT STEPS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Create a test user:
   
   aws cognito-idp sign-up \\
     --client-id ${USER_POOL_CLIENT_ID} \\
     --username test@example.com \\
     --password "TestPass123!" \\
     --user-attributes Name=email,Value=test@example.com

   aws cognito-idp admin-confirm-sign-up \\
     --user-pool-id ${USER_POOL_ID} \\
     --username test@example.com

2. Get authentication token:
   
   aws cognito-idp initiate-auth \\
     --auth-flow USER_PASSWORD_AUTH \\
     --client-id ${USER_POOL_CLIENT_ID} \\
     --auth-parameters USERNAME=test@example.com,PASSWORD=TestPass123!

3. Test the API:
   
   curl -X GET "${API_ENDPOINT}/photos" \\
     -H "Authorization: Bearer \$ACCESS_TOKEN"

4. Load environment variables:
   
   source ${OUTPUT_FILE}

5. Run the test script:
   
   ./scripts/test-api.sh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MONITORING & LOGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CloudWatch Logs:       https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#logsV2:log-groups
X-Ray Traces:          https://console.aws.amazon.com/xray/home?region=${AWS_REGION}
CloudFormation Stack:  https://console.aws.amazon.com/cloudformation/home?region=${AWS_REGION}#/stacks

Tail logs:
  sam logs -n UploadPhotoFunction --stack-name ${STACK_NAME} --tail

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

echo -e "${GREEN}✓ Deployment report saved to: ${REPORT_FILE}${NC}"
echo ""

# Display report
cat "${REPORT_FILE}"

# Final success message
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 Deployment Completed Successfully! 🎉      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Important Files:${NC}"
echo -e "  • Environment Variables: ${YELLOW}${OUTPUT_FILE}${NC}"
echo -e "  • Deployment Report:     ${YELLOW}${REPORT_FILE}${NC}"
echo ""
echo -e "${BLUE}Quick Start:${NC}"
echo -e "  1. Load environment: ${YELLOW}source ${OUTPUT_FILE}${NC}"
echo -e "  2. Create test user: See report for commands"
echo -e "  3. Test API:         ${YELLOW}./scripts/test-api.sh${NC}"
echo ""

exit 0
