#!/bin/bash
#
# Photo HQ Backend - Deployment Verification Script
# Verifies all resources were deployed correctly
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
STACK_NAME="${STACK_NAME:-photo-hq-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Photo HQ Backend - Deployment Verification          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Stack:  ${YELLOW}${STACK_NAME}${NC}"
echo -e "Region: ${YELLOW}${AWS_REGION}${NC}"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI not found. Please install AWS CLI.${NC}"
    exit 1
fi

# Verification counter
PASSED=0
FAILED=0
WARNINGS=0

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}VERIFYING CLOUDFORMATION STACK${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check stack status
echo -n "Checking stack status... "
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$STACK_STATUS" == "CREATE_COMPLETE" ] || [ "$STACK_STATUS" == "UPDATE_COMPLETE" ]; then
    echo -e "${GREEN}✓ ${STACK_STATUS}${NC}"
    ((PASSED++))
elif [ "$STACK_STATUS" == "NOT_FOUND" ]; then
    echo -e "${RED}✗ Stack not found${NC}"
    ((FAILED++))
    exit 1
else
    echo -e "${YELLOW}⚠ ${STACK_STATUS}${NC}"
    ((WARNINGS++))
fi

# Count resources
echo -n "Checking deployed resources... "
RESOURCE_COUNT=$(aws cloudformation list-stack-resources \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'length(StackResourceSummaries[?ResourceStatus==`CREATE_COMPLETE` || ResourceStatus==`UPDATE_COMPLETE`])' \
    --output text 2>/dev/null || echo "0")

if [ "$RESOURCE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ ${RESOURCE_COUNT} resources deployed${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ No resources found${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}VERIFYING LAMBDA FUNCTIONS${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Expected Lambda functions
EXPECTED_FUNCTIONS=(
    "upload-photo"
    "get-photo"
    "list-photos"
    "update-photo"
    "delete-photo"
    "get-metadata"
)

LAMBDA_FUNCTIONS=$(aws lambda list-functions \
    --region "${AWS_REGION}" \
    --query "Functions[?starts_with(FunctionName, '${STACK_NAME}')].FunctionName" \
    --output json 2>/dev/null || echo "[]")

LAMBDA_COUNT=$(echo "$LAMBDA_FUNCTIONS" | jq 'length')

echo "Found ${LAMBDA_COUNT} Lambda functions"
echo ""

for func_suffix in "${EXPECTED_FUNCTIONS[@]}"; do
    FUNC_NAME="${STACK_NAME}-${func_suffix}"
    echo -n "  ${func_suffix}... "
    
    if echo "$LAMBDA_FUNCTIONS" | jq -r '.[]' | grep -q "^${FUNC_NAME}$"; then
        # Check function state
        FUNC_STATE=$(aws lambda get-function \
            --function-name "${FUNC_NAME}" \
            --region "${AWS_REGION}" \
            --query 'Configuration.State' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        if [ "$FUNC_STATE" == "Active" ]; then
            echo -e "${GREEN}✓ Active${NC}"
            ((PASSED++))
        else
            echo -e "${YELLOW}⚠ ${FUNC_STATE}${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗ Not found${NC}"
        ((FAILED++))
    fi
done

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}VERIFYING S3 BUCKETS${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Get bucket names from stack outputs
ORIGINALS_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`OriginalsBucketName`].OutputValue' \
    --output text 2>/dev/null || echo "")

EDITED_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`EditedBucketName`].OutputValue' \
    --output text 2>/dev/null || echo "")

# Check Originals bucket
echo -n "  Originals bucket... "
if [ ! -z "$ORIGINALS_BUCKET" ]; then
    if aws s3 ls "s3://${ORIGINALS_BUCKET}" --region "${AWS_REGION}" &>/dev/null; then
        echo -e "${GREEN}✓ ${ORIGINALS_BUCKET}${NC}"
        ((PASSED++))
        
        # Check encryption
        ENCRYPTION=$(aws s3api get-bucket-encryption \
            --bucket "${ORIGINALS_BUCKET}" \
            --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
            --output text 2>/dev/null || echo "NONE")
        echo "    Encryption: ${ENCRYPTION}"
        
        # Check versioning
        VERSIONING=$(aws s3api get-bucket-versioning \
            --bucket "${ORIGINALS_BUCKET}" \
            --query 'Status' \
            --output text 2>/dev/null || echo "Disabled")
        echo "    Versioning: ${VERSIONING}"
    else
        echo -e "${RED}✗ Not accessible${NC}"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗ Not found in outputs${NC}"
    ((FAILED++))
fi

# Check Edited bucket
echo -n "  Edited bucket... "
if [ ! -z "$EDITED_BUCKET" ]; then
    if aws s3 ls "s3://${EDITED_BUCKET}" --region "${AWS_REGION}" &>/dev/null; then
        echo -e "${GREEN}✓ ${EDITED_BUCKET}${NC}"
        ((PASSED++))
        
        # Check encryption
        ENCRYPTION=$(aws s3api get-bucket-encryption \
            --bucket "${EDITED_BUCKET}" \
            --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' \
            --output text 2>/dev/null || echo "NONE")
        echo "    Encryption: ${ENCRYPTION}"
        
        # Check versioning
        VERSIONING=$(aws s3api get-bucket-versioning \
            --bucket "${EDITED_BUCKET}" \
            --query 'Status' \
            --output text 2>/dev/null || echo "Disabled")
        echo "    Versioning: ${VERSIONING}"
    else
        echo -e "${RED}✗ Not accessible${NC}"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗ Not found in outputs${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}VERIFYING DYNAMODB TABLE${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

TABLE_NAME="${STACK_NAME}-photos"
echo -n "  Photos table... "

TABLE_STATUS=$(aws dynamodb describe-table \
    --table-name "${TABLE_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Table.TableStatus' \
    --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TABLE_STATUS" == "ACTIVE" ]; then
    echo -e "${GREEN}✓ ${TABLE_NAME} (${TABLE_STATUS})${NC}"
    ((PASSED++))
    
    # Check GSIs
    GSI_COUNT=$(aws dynamodb describe-table \
        --table-name "${TABLE_NAME}" \
        --region "${AWS_REGION}" \
        --query 'length(Table.GlobalSecondaryIndexes)' \
        --output text 2>/dev/null || echo "0")
    echo "    Global Secondary Indexes: ${GSI_COUNT}"
    
    # Check encryption
    ENCRYPTION=$(aws dynamodb describe-table \
        --table-name "${TABLE_NAME}" \
        --region "${AWS_REGION}" \
        --query 'Table.SSEDescription.Status' \
        --output text 2>/dev/null || echo "DISABLED")
    echo "    Encryption: ${ENCRYPTION}"
    
    # Check streams
    STREAMS=$(aws dynamodb describe-table \
        --table-name "${TABLE_NAME}" \
        --region "${AWS_REGION}" \
        --query 'Table.StreamSpecification.StreamEnabled' \
        --output text 2>/dev/null || echo "false")
    echo "    Streams: ${STREAMS}"
else
    echo -e "${RED}✗ ${TABLE_STATUS}${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}VERIFYING COGNITO USER POOL${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
    --output text 2>/dev/null || echo "")

echo -n "  User Pool... "
if [ ! -z "$USER_POOL_ID" ]; then
    USER_POOL_STATUS=$(aws cognito-idp describe-user-pool \
        --user-pool-id "${USER_POOL_ID}" \
        --region "${AWS_REGION}" \
        --query 'UserPool.Status' \
        --output text 2>/dev/null || echo "NOT_FOUND")
    
    if [ "$USER_POOL_STATUS" == "Enabled" ] || [ ! -z "$USER_POOL_STATUS" ]; then
        echo -e "${GREEN}✓ ${USER_POOL_ID}${NC}"
        ((PASSED++))
        
        # Check MFA config
        MFA=$(aws cognito-idp describe-user-pool \
            --user-pool-id "${USER_POOL_ID}" \
            --region "${AWS_REGION}" \
            --query 'UserPool.MfaConfiguration' \
            --output text 2>/dev/null || echo "OFF")
        echo "    MFA: ${MFA}"
    else
        echo -e "${RED}✗ ${USER_POOL_STATUS}${NC}"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗ Not found in outputs${NC}"
    ((FAILED++))
fi

USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
    --output text 2>/dev/null || echo "")

echo -n "  User Pool Client... "
if [ ! -z "$USER_POOL_CLIENT_ID" ]; then
    echo -e "${GREEN}✓ ${USER_POOL_CLIENT_ID}${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ Not found in outputs${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}VERIFYING API GATEWAY${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
    --output text 2>/dev/null || echo "")

echo -n "  API Gateway... "
if [ ! -z "$API_ENDPOINT" ]; then
    API_ID=$(echo "${API_ENDPOINT}" | grep -oP 'https://\K[^.]+' || echo "")
    if [ ! -z "$API_ID" ]; then
        echo -e "${GREEN}✓ ${API_ID}${NC}"
        echo "    Endpoint: ${API_ENDPOINT}"
        ((PASSED++))
        
        # Check if API is accessible (basic connectivity test)
        echo -n "    Testing connectivity... "
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${API_ENDPOINT}/photos" -m 5 || echo "000")
        if [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "403" ]; then
            # 401/403 is expected without auth token
            echo -e "${GREEN}✓ API is reachable (HTTP ${HTTP_CODE})${NC}"
        elif [ "$HTTP_CODE" == "000" ]; then
            echo -e "${YELLOW}⚠ Connection timeout${NC}"
            ((WARNINGS++))
        else
            echo -e "${YELLOW}⚠ HTTP ${HTTP_CODE}${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${YELLOW}⚠ Could not extract API ID${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗ Not found in outputs${NC}"
    ((FAILED++))
fi

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}DEPLOYMENT OUTPUTS${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${AWS_REGION}" \
    --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' \
    --output table 2>/dev/null || echo "Unable to retrieve outputs"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}VERIFICATION SUMMARY${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${GREEN}Passed:   ${PASSED}${NC}"
echo -e "  ${YELLOW}Warnings: ${WARNINGS}${NC}"
echo -e "  ${RED}Failed:   ${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║    ✓ All verification checks passed successfully!     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    exit 0
elif [ $FAILED -eq 0 ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠ Verification completed with warnings               ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║    ✗ Verification failed - please review errors       ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
