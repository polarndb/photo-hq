#!/bin/bash

# Photo HQ - Quick Start Script
# This script helps you deploy and test the Photo HQ API quickly

set -e

echo "🚀 Photo HQ - Quick Start"
echo "=========================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="${STACK_NAME:-photo-hq-dev}"
REGION="${AWS_REGION:-us-east-1}"
TEST_EMAIL="${TEST_EMAIL:-test@example.com}"
TEST_PASSWORD="${TEST_PASSWORD:-TestPass123!}"

echo "Configuration:"
echo "  Stack Name: $STACK_NAME"
echo "  Region: $REGION"
echo "  Test Email: $TEST_EMAIL"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."

command -v aws >/dev/null 2>&1 || { echo -e "${RED}❌ AWS CLI not found. Please install it first.${NC}"; exit 1; }
command -v sam >/dev/null 2>&1 || { echo -e "${RED}❌ SAM CLI not found. Please install it first.${NC}"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo -e "${RED}❌ Python 3 not found. Please install it first.${NC}"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo -e "${YELLOW}⚠️  jq not found. Install for better output formatting.${NC}"; }

echo -e "${GREEN}✅ All prerequisites found${NC}"
echo ""

# Check AWS credentials
echo "🔐 Checking AWS credentials..."
if aws sts get-caller-identity --region $REGION >/dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "${GREEN}✅ AWS credentials valid (Account: $ACCOUNT_ID)${NC}"
else
    echo -e "${RED}❌ AWS credentials not configured. Run 'aws configure' first.${NC}"
    exit 1
fi
echo ""

# Build application
echo "🔨 Building application..."
if sam build; then
    echo -e "${GREEN}✅ Build successful${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi
echo ""

# Deploy application
echo "☁️  Deploying to AWS..."
echo "This may take 5-10 minutes..."
echo ""

if sam deploy --stack-name $STACK_NAME --region $REGION --no-confirm-changeset; then
    echo -e "${GREEN}✅ Deployment successful${NC}"
else
    echo -e "${RED}❌ Deployment failed${NC}"
    echo "Check CloudFormation console for details"
    exit 1
fi
echo ""

# Get outputs
echo "📝 Retrieving deployment outputs..."
API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
    --output text)

USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
    --output text)

USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
    --output text)

ORIGINALS_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`OriginalsBucketName`].OutputValue' \
    --output text)

EDITED_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`EditedBucketName`].OutputValue' \
    --output text)

echo ""
echo "📌 Deployment Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "API Endpoint:        $API_ENDPOINT"
echo "User Pool ID:        $USER_POOL_ID"
echo "User Pool Client ID: $USER_POOL_CLIENT_ID"
echo "Originals Bucket:    $ORIGINALS_BUCKET"
echo "Edited Bucket:       $EDITED_BUCKET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Save to .env file
cat > .env << EOF
API_ENDPOINT=$API_ENDPOINT
USER_POOL_ID=$USER_POOL_ID
USER_POOL_CLIENT_ID=$USER_POOL_CLIENT_ID
ORIGINALS_BUCKET=$ORIGINALS_BUCKET
EDITED_BUCKET=$EDITED_BUCKET
REGION=$REGION
EOF

echo -e "${GREEN}✅ Configuration saved to .env file${NC}"
echo ""

# Create test user
echo "👤 Creating test user..."
echo "Email: $TEST_EMAIL"

if aws cognito-idp sign-up \
    --client-id $USER_POOL_CLIENT_ID \
    --username $TEST_EMAIL \
    --password $TEST_PASSWORD \
    --user-attributes Name=email,Value=$TEST_EMAIL \
    --region $REGION >/dev/null 2>&1; then
    echo -e "${GREEN}✅ User created${NC}"
    
    # Auto-confirm user
    if aws cognito-idp admin-confirm-sign-up \
        --user-pool-id $USER_POOL_ID \
        --username $TEST_EMAIL \
        --region $REGION >/dev/null 2>&1; then
        echo -e "${GREEN}✅ User confirmed${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  User might already exist${NC}"
fi
echo ""

# Test authentication
echo "🔑 Testing authentication..."
TOKEN_RESPONSE=$(aws cognito-idp initiate-auth \
    --auth-flow USER_PASSWORD_AUTH \
    --client-id $USER_POOL_CLIENT_ID \
    --auth-parameters USERNAME=$TEST_EMAIL,PASSWORD=$TEST_PASSWORD \
    --region $REGION 2>/dev/null || echo "{}")

if command -v jq >/dev/null 2>&1; then
    ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.AuthenticationResult.AccessToken // empty')
else
    ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | grep -o '"AccessToken":"[^"]*' | cut -d'"' -f4)
fi

if [ ! -z "$ACCESS_TOKEN" ] && [ "$ACCESS_TOKEN" != "null" ]; then
    echo -e "${GREEN}✅ Authentication successful${NC}"
    echo "Access Token: ${ACCESS_TOKEN:0:50}..."
    
    # Save token
    echo "ACCESS_TOKEN=$ACCESS_TOKEN" >> .env
    
    echo ""
    
    # Test API
    echo "🧪 Testing API endpoints..."
    
    # Test list photos
    echo "Testing GET /photos..."
    LIST_RESPONSE=$(curl -s -X GET "${API_ENDPOINT}/photos" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    if echo $LIST_RESPONSE | grep -q "photos"; then
        echo -e "${GREEN}✅ List photos endpoint working${NC}"
    else
        echo -e "${RED}❌ List photos endpoint failed${NC}"
        echo "Response: $LIST_RESPONSE"
    fi
    
    # Test upload endpoint
    echo "Testing POST /photos/upload..."
    UPLOAD_RESPONSE=$(curl -s -X POST "${API_ENDPOINT}/photos/upload" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "filename": "test.jpg",
            "content_type": "image/jpeg",
            "file_size": 10485760
        }')
    
    if echo $UPLOAD_RESPONSE | grep -q "upload_url"; then
        echo -e "${GREEN}✅ Upload endpoint working${NC}"
        
        if command -v jq >/dev/null 2>&1; then
            PHOTO_ID=$(echo $UPLOAD_RESPONSE | jq -r '.photo_id')
            echo "Created photo ID: $PHOTO_ID"
        fi
    else
        echo -e "${RED}❌ Upload endpoint failed${NC}"
        echo "Response: $UPLOAD_RESPONSE"
    fi
    
else
    echo -e "${RED}❌ Authentication failed${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Next Steps:"
echo ""
echo "1. Review the API documentation:"
echo "   cat API_DOCUMENTATION.md"
echo ""
echo "2. Test with curl commands:"
echo "   export API_ENDPOINT=\"$API_ENDPOINT\""
echo "   export ACCESS_TOKEN=\"$ACCESS_TOKEN\""
echo "   curl \$API_ENDPOINT/photos -H \"Authorization: Bearer \$ACCESS_TOKEN\""
echo ""
echo "3. View logs:"
echo "   sam logs -n UploadPhotoFunction --stack-name $STACK_NAME --tail"
echo ""
echo "4. Monitor in AWS Console:"
echo "   https://console.aws.amazon.com/cloudformation/home?region=$REGION#/stacks"
echo ""
echo "5. Clean up when done:"
echo "   ./scripts/cleanup.sh"
echo ""
