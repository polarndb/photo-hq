#!/bin/bash

# Photo HQ - Cleanup Script
# Safely removes all AWS resources created by the Photo HQ deployment

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

STACK_NAME="${STACK_NAME:-photo-hq-dev}"
REGION="${AWS_REGION:-us-east-1}"

echo "🗑️  Photo HQ - Cleanup Script"
echo "=============================="
echo ""
echo -e "${YELLOW}WARNING: This will delete all resources and data!${NC}"
echo ""
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "🔍 Checking if stack exists..."

if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Stack '$STACK_NAME' not found in region '$REGION'${NC}"
    exit 0
fi

# Get bucket names
echo "📦 Getting S3 bucket names..."
ORIGINALS_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`OriginalsBucketName`].OutputValue' \
    --output text 2>/dev/null || echo "")

EDITED_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`EditedBucketName`].OutputValue' \
    --output text 2>/dev/null || echo "")

# Empty S3 buckets
if [ ! -z "$ORIGINALS_BUCKET" ] && [ "$ORIGINALS_BUCKET" != "None" ]; then
    echo "🗑️  Emptying originals bucket: $ORIGINALS_BUCKET"
    
    OBJECT_COUNT=$(aws s3 ls s3://$ORIGINALS_BUCKET --recursive --region $REGION | wc -l)
    if [ $OBJECT_COUNT -gt 0 ]; then
        echo "   Found $OBJECT_COUNT objects to delete..."
        aws s3 rm s3://$ORIGINALS_BUCKET --recursive --region $REGION
        echo -e "${GREEN}   ✅ Bucket emptied${NC}"
    else
        echo "   Bucket is already empty"
    fi
else
    echo "⚠️  Originals bucket not found or already deleted"
fi

if [ ! -z "$EDITED_BUCKET" ] && [ "$EDITED_BUCKET" != "None" ]; then
    echo "🗑️  Emptying edited bucket: $EDITED_BUCKET"
    
    OBJECT_COUNT=$(aws s3 ls s3://$EDITED_BUCKET --recursive --region $REGION | wc -l)
    if [ $OBJECT_COUNT -gt 0 ]; then
        echo "   Found $OBJECT_COUNT objects to delete..."
        aws s3 rm s3://$EDITED_BUCKET --recursive --region $REGION
        echo -e "${GREEN}   ✅ Bucket emptied${NC}"
    else
        echo "   Bucket is already empty"
    fi
else
    echo "⚠️  Edited bucket not found or already deleted"
fi

# Delete CloudFormation stack
echo ""
echo "☁️  Deleting CloudFormation stack..."
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

echo "⏳ Waiting for stack deletion to complete..."
echo "   This may take 5-10 minutes..."

# Wait for deletion with timeout
TIMEOUT=600  # 10 minutes
ELAPSED=0
INTERVAL=10

while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(aws cloudformation describe-stacks \
        --stack-name $STACK_NAME \
        --region $REGION \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DELETE_COMPLETE")
    
    if [ "$STATUS" == "DELETE_COMPLETE" ]; then
        echo -e "${GREEN}✅ Stack deleted successfully${NC}"
        break
    elif [ "$STATUS" == "DELETE_FAILED" ]; then
        echo -e "${RED}❌ Stack deletion failed${NC}"
        echo "Check CloudFormation console for details"
        exit 1
    else
        echo "   Status: $STATUS (${ELAPSED}s elapsed)"
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    fi
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${RED}❌ Timeout waiting for stack deletion${NC}"
    echo "Check CloudFormation console for current status"
    exit 1
fi

# Clean up local files
echo ""
echo "🧹 Cleaning up local files..."
if [ -f .env ]; then
    rm .env
    echo "   Removed .env"
fi

if [ -d .aws-sam ]; then
    rm -rf .aws-sam
    echo "   Removed .aws-sam/"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🎉 Cleanup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "All AWS resources have been deleted:"
echo "  ✅ Lambda functions"
echo "  ✅ API Gateway"
echo "  ✅ S3 buckets"
echo "  ✅ DynamoDB table"
echo "  ✅ Cognito User Pool"
echo "  ✅ IAM roles"
echo "  ✅ CloudWatch logs"
echo ""
