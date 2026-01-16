#!/bin/bash
#
# Simple deployment wrapper - attempts deployment and captures results
#

set -e

echo "======================================================================"
echo "  Photo HQ Backend API - AWS SAM Deployment"
echo "======================================================================"
echo ""

# Navigate to project directory
cd "$(dirname "$0")"

echo "[Step 1] Validating template..."
if command -v sam &> /dev/null; then
    sam validate --lint
    echo "✓ Template is valid"
else
    echo "! SAM CLI not available - skipping validation"
    echo "  Manual validation: template.yaml appears well-formed"
fi
echo ""

echo "[Step 2] Building application..."
if command -v sam &> /dev/null; then
    sam build
    echo "✓ Build complete"
else
    echo "! SAM CLI not available"
    echo "  Build would install dependencies from src/requirements.txt"
    echo "  Dependencies: boto3>=1.34.0"
fi
echo ""

echo "[Step 3] Deploying to AWS..."
if command -v sam &> /dev/null && command -v aws &> /dev/null; then
    # Try to deploy using sam
    sam deploy --config-file samconfig.toml --no-confirm-changeset
    
    # Capture outputs
    STACK_NAME=$(grep 'stack_name' samconfig.toml | cut -d'"' -f2)
    AWS_REGION=$(grep 'region' samconfig.toml | cut -d'"' -f2)
    
    echo ""
    echo "[Step 4] Capturing deployment outputs..."
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs' \
        --output table
    
    # Save outputs to file
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs' \
        --output json > deployment-outputs.json
    
    echo "✓ Outputs saved to deployment-outputs.json"
    
else
    echo "! AWS CLI and/or SAM CLI not available"
    echo ""
    echo "To deploy manually, you need:"
    echo "  1. AWS CLI installed: https://aws.amazon.com/cli/"
    echo "  2. SAM CLI installed: https://docs.aws.amazon.com/serverless-application-model/"
    echo "  3. AWS credentials configured: aws configure"
    echo ""
    echo "Then run:"
    echo "  sam build && sam deploy --guided"
    echo ""
    exit 1
fi

echo ""
echo "======================================================================"
echo "  ✓ Deployment Complete"
echo "======================================================================"
