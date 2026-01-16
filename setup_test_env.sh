#!/bin/bash

# Setup Test Environment Script
# Automatically extracts deployment information and creates .env file

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STACK_NAME="${STACK_NAME:-photo-hq-dev}"
REGION="${AWS_REGION:-us-east-1}"

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Photo HQ - Test Environment Setup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Please run: aws configure"
    exit 1
fi
echo -e "${GREEN}✓ AWS credentials valid${NC}"

# Check if stack exists
echo -e "${YELLOW}Checking CloudFormation stack: ${STACK_NAME}...${NC}"
if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &> /dev/null; then
    echo -e "${RED}Error: Stack '${STACK_NAME}' not found in region '${REGION}'${NC}"
    echo ""
    echo "Available stacks:"
    aws cloudformation list-stacks --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
        --region "$REGION" --query 'StackSummaries[].StackName' --output text
    echo ""
    echo "Set the correct stack name:"
    echo "  export STACK_NAME=your-stack-name"
    exit 1
fi
echo -e "${GREEN}✓ Stack found${NC}"

# Get stack outputs
echo -e "${YELLOW}Retrieving stack outputs...${NC}"

API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
    --output text)

USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
    --output text)

USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
    --output text)

# Validate outputs
if [ -z "$API_ENDPOINT" ] || [ -z "$USER_POOL_ID" ] || [ -z "$USER_POOL_CLIENT_ID" ]; then
    echo -e "${RED}Error: Could not retrieve all required outputs${NC}"
    echo ""
    echo "Available outputs:"
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[].[OutputKey,OutputValue]' \
        --output table
    exit 1
fi

echo -e "${GREEN}✓ All outputs retrieved${NC}"
echo ""

# Create .env file
echo -e "${YELLOW}Creating .env file...${NC}"

cat > .env << ENVFILE
# Photo HQ Backend Configuration
# Auto-generated on $(date)

# API Gateway endpoint URL
API_ENDPOINT=${API_ENDPOINT}

# Cognito User Pool ID
USER_POOL_ID=${USER_POOL_ID}

# Cognito User Pool Client ID
USER_POOL_CLIENT_ID=${USER_POOL_CLIENT_ID}

# AWS Region
AWS_REGION=${REGION}
ENVFILE

echo -e "${GREEN}✓ .env file created${NC}"
echo ""

# Display configuration
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
echo -e "${BLUE}Configuration Summary:${NC}"
echo -e "${BLUE}────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${CYAN}API Endpoint:${NC} ${API_ENDPOINT}"
echo -e "${CYAN}User Pool ID:${NC} ${USER_POOL_ID}"
echo -e "${CYAN}Client ID:${NC} ${USER_POOL_CLIENT_ID}"
echo -e "${CYAN}Region:${NC} ${REGION}"
echo ""

echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Test environment setup complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo "You can now run the test suite:"
echo -e "  ${YELLOW}./run_comprehensive_tests.sh${NC}"
echo ""
