# Deployment Guide

This guide walks through deploying the Photo HQ serverless backend API from scratch.

## Prerequisites Checklist

Before you begin, ensure you have:

- [ ] AWS Account with appropriate permissions
- [ ] AWS CLI installed and configured
- [ ] AWS SAM CLI installed
- [ ] Python 3.11 installed
- [ ] Git installed
- [ ] Basic understanding of AWS services

### Verify Prerequisites

```bash
# Check AWS CLI
aws --version
# Expected: aws-cli/2.x.x or higher

# Check AWS credentials
aws sts get-caller-identity
# Should return your account details

# Check SAM CLI
sam --version
# Expected: SAM CLI, version 1.x.x or higher

# Check Python
python3 --version
# Expected: Python 3.11.x
```

## Step-by-Step Deployment

### Step 1: Clone/Setup Repository

```bash
# If starting fresh
cd /path/to/your/workspace
mkdir photo-hq
cd photo-hq

# Copy all project files to this directory
```

### Step 2: Review Configuration

Edit `samconfig.toml` to customize deployment settings:

```toml
[default.deploy.parameters]
stack_name = "photo-hq-dev"  # Change to your preferred stack name
region = "us-east-1"         # Change to your preferred region
```

**Supported Regions**: Any AWS region with Lambda, API Gateway, DynamoDB, S3, and Cognito support.

**Recommended Regions**:
- `us-east-1` (Virginia) - Largest service availability, lowest cost
- `us-west-2` (Oregon) - West coast, good pricing
- `eu-west-1` (Ireland) - Europe
- `ap-southeast-1` (Singapore) - Asia Pacific

### Step 3: Build Application

```bash
# Build the SAM application
sam build

# Output should show:
# Build Succeeded
# 
# Built Artifacts  : .aws-sam/build
# Built Template   : .aws-sam/build/template.yaml
```

This command:
- Validates template.yaml syntax
- Downloads Python dependencies
- Packages Lambda functions
- Prepares deployment artifacts

### Step 4: Deploy Application

#### First Time Deployment (Guided)

```bash
sam deploy --guided
```

You'll be prompted for:

```
Stack Name [photo-hq-dev]: <press Enter or type custom name>
AWS Region [us-east-1]: <press Enter or type region>
Confirm changes before deploy [Y/n]: Y
Allow SAM CLI IAM role creation [Y/n]: Y
Disable rollback [y/N]: N
Save arguments to configuration file [Y/n]: Y
SAM configuration file [samconfig.toml]: <press Enter>
SAM configuration environment [default]: <press Enter>
```

**Important Prompts**:

1. **IAM role creation**: Choose `Y` - Required for Lambda execution roles
2. **Confirm changes**: Review the changeset before deploying
3. **Disable rollback**: Choose `N` - Allows automatic rollback on failure

#### Subsequent Deployments

After initial setup:

```bash
sam build && sam deploy
```

No prompts needed - uses saved configuration.

### Step 5: Capture Outputs

After successful deployment, note these outputs:

```bash
# View CloudFormation outputs
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --query 'Stacks[0].Outputs' \
  --output table
```

**Critical Outputs**:
1. **ApiEndpoint**: Your API base URL
2. **UserPoolId**: Cognito User Pool ID
3. **UserPoolClientId**: Client ID for authentication
4. **OriginalsBucketName**: S3 bucket for originals
5. **EditedBucketName**: S3 bucket for edited photos
6. **PhotosTableName**: DynamoDB table name

**Save these values** - you'll need them for testing and frontend integration.

Example:
```bash
# Save to environment file
cat > .env.local << EOF
API_ENDPOINT=https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod
USER_POOL_ID=us-east-1_AbCdEfGhI
USER_POOL_CLIENT_ID=1a2b3c4d5e6f7g8h9i0j1k2l3m
ORIGINALS_BUCKET=photo-hq-dev-originals-123456789012
EDITED_BUCKET=photo-hq-dev-edited-123456789012
PHOTOS_TABLE=photo-hq-dev-photos
EOF
```

### Step 6: Create Test User

```bash
# Set variables
USER_EMAIL="test@example.com"
USER_PASSWORD="TestPass123!"
USER_POOL_CLIENT_ID="<from deployment outputs>"
USER_POOL_ID="<from deployment outputs>"

# Sign up user
aws cognito-idp sign-up \
  --client-id $USER_POOL_CLIENT_ID \
  --username $USER_EMAIL \
  --password $USER_PASSWORD \
  --user-attributes Name=email,Value=$USER_EMAIL

# Admin confirm user (skip email verification for testing)
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id $USER_POOL_ID \
  --username $USER_EMAIL

echo "✅ User created and confirmed"
```

### Step 7: Test Authentication

```bash
# Authenticate and get JWT token
TOKEN_RESPONSE=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $USER_POOL_CLIENT_ID \
  --auth-parameters USERNAME=$USER_EMAIL,PASSWORD=$USER_PASSWORD)

# Extract access token
ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.AuthenticationResult.AccessToken')

# Verify token
if [ "$ACCESS_TOKEN" != "null" ]; then
  echo "✅ Authentication successful"
  echo "Access Token: ${ACCESS_TOKEN:0:50}..."
else
  echo "❌ Authentication failed"
  exit 1
fi
```

### Step 8: Test API Endpoints

#### Test Upload Endpoint

```bash
# Set API endpoint
API_ENDPOINT="<from deployment outputs>"

# Test upload photo endpoint
curl -X POST "${API_ENDPOINT}/photos/upload" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test.jpg",
    "content_type": "image/jpeg",
    "file_size": 10485760
  }'

# Expected response:
# {
#   "photo_id": "uuid",
#   "upload_url": "https://s3...",
#   "upload_method": "PUT",
#   "expires_in": 900,
#   ...
# }
```

#### Test List Endpoint

```bash
curl -X GET "${API_ENDPOINT}/photos" \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Expected response:
# {
#   "photos": [],
#   "count": 0,
#   "has_more": false
# }
```

### Step 9: Verify Resources

```bash
# Check Lambda functions
aws lambda list-functions \
  --query "Functions[?starts_with(FunctionName, 'photo-hq-dev')].FunctionName"

# Check S3 buckets
aws s3 ls | grep photo-hq-dev

# Check DynamoDB table
aws dynamodb describe-table \
  --table-name photo-hq-dev-photos \
  --query 'Table.[TableName,TableStatus,ItemCount]'

# Check API Gateway
aws apigateway get-rest-apis \
  --query "items[?name=='photo-hq-dev-api'].id"
```

## Deployment Troubleshooting

### Common Issues

#### Issue 1: "Bucket already exists"

**Error**:
```
CREATE_FAILED: OriginalsBucket (AWS::S3::Bucket)
Resource already exists
```

**Solution**:
S3 bucket names must be globally unique. Either:
1. Change stack name: `--stack-name photo-hq-dev-yourname`
2. Delete existing buckets
3. Use different AWS account

#### Issue 2: "Insufficient IAM permissions"

**Error**:
```
User is not authorized to perform: cloudformation:CreateStack
```

**Solution**:
Ensure your AWS credentials have these permissions:
- CloudFormation: Full access
- Lambda: Create functions
- API Gateway: Create APIs
- S3: Create buckets
- DynamoDB: Create tables
- Cognito: Create user pools
- IAM: Create roles and policies

**Required Policies**:
- `AWSCloudFormationFullAccess`
- `AWSLambda_FullAccess`
- `AmazonAPIGatewayAdministrator`
- `AmazonS3FullAccess`
- `AmazonDynamoDBFullAccess`
- `AmazonCognitoPowerUser`
- `IAMFullAccess` (or scoped role creation permissions)

#### Issue 3: "Stack rollback"

**Error**:
```
CREATE_FAILED and Rollback Complete
```

**Solution**:
1. Check CloudFormation events:
```bash
aws cloudformation describe-stack-events \
  --stack-name photo-hq-dev \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
```

2. Review specific failure reason
3. Fix issue in template or configuration
4. Delete failed stack:
```bash
aws cloudformation delete-stack --stack-name photo-hq-dev
```
5. Redeploy

#### Issue 4: "sam build fails"

**Error**:
```
Build Failed
Error: PythonPipBuilder:Validation - Binary validation failed
```

**Solution**:
- Ensure Python 3.11 is installed
- Check `src/requirements.txt` exists
- Verify no syntax errors in Python files
- Try: `sam build --use-container` (uses Docker, no local Python needed)

#### Issue 5: "User pool client secret not supported"

**Error**: Frontend can't authenticate

**Solution**: 
The template is correctly configured with `GenerateSecret: false`. If you modified it, ensure client doesn't have a secret for public clients (web/mobile apps).

### Validation Commands

After deployment, run these to verify everything works:

```bash
#!/bin/bash
# verify-deployment.sh

set -e

echo "🔍 Verifying Photo HQ Deployment..."

# Load configuration
STACK_NAME="photo-hq-dev"
REGION="us-east-1"

# Check stack status
echo "1️⃣ Checking CloudFormation stack..."
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].StackStatus' \
  --output text)

if [ "$STACK_STATUS" == "CREATE_COMPLETE" ] || [ "$STACK_STATUS" == "UPDATE_COMPLETE" ]; then
  echo "   ✅ Stack status: $STACK_STATUS"
else
  echo "   ❌ Stack status: $STACK_STATUS"
  exit 1
fi

# Check Lambda functions
echo "2️⃣ Checking Lambda functions..."
FUNCTION_COUNT=$(aws lambda list-functions \
  --region $REGION \
  --query "Functions[?starts_with(FunctionName, '$STACK_NAME')].FunctionName" \
  --output json | jq '. | length')

if [ "$FUNCTION_COUNT" -eq 6 ]; then
  echo "   ✅ All 6 Lambda functions deployed"
else
  echo "   ⚠️  Expected 6 functions, found $FUNCTION_COUNT"
fi

# Check S3 buckets
echo "3️⃣ Checking S3 buckets..."
BUCKET_COUNT=$(aws s3 ls --region $REGION | grep -c "$STACK_NAME" || true)

if [ "$BUCKET_COUNT" -eq 2 ]; then
  echo "   ✅ Both S3 buckets created"
else
  echo "   ⚠️  Expected 2 buckets, found $BUCKET_COUNT"
fi

# Check DynamoDB table
echo "4️⃣ Checking DynamoDB table..."
TABLE_STATUS=$(aws dynamodb describe-table \
  --table-name "${STACK_NAME}-photos" \
  --region $REGION \
  --query 'Table.TableStatus' \
  --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$TABLE_STATUS" == "ACTIVE" ]; then
  echo "   ✅ DynamoDB table active"
else
  echo "   ❌ DynamoDB table status: $TABLE_STATUS"
fi

# Check Cognito User Pool
echo "5️⃣ Checking Cognito User Pool..."
USER_POOL_COUNT=$(aws cognito-idp list-user-pools \
  --max-results 60 \
  --region $REGION \
  --query "UserPools[?contains(Name, '$STACK_NAME')].Name" \
  --output json | jq '. | length')

if [ "$USER_POOL_COUNT" -ge 1 ]; then
  echo "   ✅ Cognito User Pool created"
else
  echo "   ❌ Cognito User Pool not found"
fi

# Check API Gateway
echo "6️⃣ Checking API Gateway..."
API_ID=$(aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text | grep -oP 'https://\K[^.]+')

if [ ! -z "$API_ID" ]; then
  echo "   ✅ API Gateway deployed"
  echo "   API ID: $API_ID"
else
  echo "   ❌ API Gateway not found"
fi

echo ""
echo "🎉 Deployment verification complete!"
```

Save as `verify-deployment.sh`, make executable, and run:
```bash
chmod +x verify-deployment.sh
./verify-deployment.sh
```

## Multi-Environment Deployment

### Development Environment

```bash
sam deploy \
  --stack-name photo-hq-dev \
  --parameter-overrides Environment=dev \
  --config-env dev
```

### Staging Environment

```bash
sam deploy \
  --stack-name photo-hq-staging \
  --parameter-overrides Environment=staging \
  --config-env staging
```

### Production Environment

```bash
sam deploy \
  --stack-name photo-hq-prod \
  --parameter-overrides Environment=prod \
  --config-env prod \
  --no-confirm-changeset  # Remove for safety
```

## Update Deployment

When you make changes to code or template:

```bash
# 1. Make changes to code or template.yaml

# 2. Build
sam build

# 3. Deploy
sam deploy

# 4. CloudFormation will create a changeset
# Review changes and confirm

# 5. Deployment updates only changed resources
```

## Rollback

If deployment has issues:

```bash
# Automatic rollback
# CloudFormation automatically rolls back on failure (if rollback not disabled)

# Manual rollback to previous version
aws cloudformation rollback-stack --stack-name photo-hq-dev

# Check rollback status
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --query 'Stacks[0].StackStatus'
```

## Complete Teardown

To delete all resources:

```bash
# 1. Empty S3 buckets (required before deletion)
ORIGINALS_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`OriginalsBucketName`].OutputValue' \
  --output text)

EDITED_BUCKET=$(aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --query 'Stacks[0].Outputs[?OutputKey==`EditedBucketName`].OutputValue' \
  --output text)

aws s3 rm s3://$ORIGINALS_BUCKET --recursive
aws s3 rm s3://$EDITED_BUCKET --recursive

# 2. Delete stack
aws cloudformation delete-stack --stack-name photo-hq-dev

# 3. Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name photo-hq-dev

echo "✅ Stack deleted successfully"
```

## Monitoring Post-Deployment

### CloudWatch Dashboard

Access via AWS Console:
1. Navigate to CloudWatch
2. Create Dashboard
3. Add widgets for:
   - Lambda invocations, errors, duration
   - API Gateway requests, 4xx/5xx errors
   - DynamoDB read/write capacity
   - S3 request metrics

### View Logs

```bash
# List log groups
aws logs describe-log-groups \
  --log-group-name-prefix /aws/lambda/photo-hq-dev

# Tail Lambda logs
sam logs -n UploadPhotoFunction --stack-name photo-hq-dev --tail

# View API Gateway logs
sam logs -n PhotoAPI --stack-name photo-hq-dev --tail
```

### X-Ray Tracing

1. AWS Console → X-Ray → Service Map
2. View request traces
3. Analyze performance bottlenecks
4. Debug errors with trace details

### Set Up Alarms

```bash
# Create alarm for Lambda errors
aws cloudwatch put-metric-alarm \
  --alarm-name photo-hq-dev-lambda-errors \
  --alarm-description "Alert on Lambda errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=photo-hq-dev-upload-photo
```

## Next Steps

After successful deployment:

1. ✅ **Test all API endpoints** (see README.md)
2. ✅ **Create additional test users**
3. ✅ **Integrate with frontend application**
4. ✅ **Set up monitoring and alarms**
5. ✅ **Configure CloudWatch log retention**
6. ✅ **Review IAM roles and permissions**
7. ✅ **Plan backup and disaster recovery**
8. ✅ **Document custom configurations**

## Getting Help

If you encounter issues:

1. **Check CloudFormation Events**:
   ```bash
   aws cloudformation describe-stack-events --stack-name photo-hq-dev
   ```

2. **Review Lambda Logs**:
   ```bash
   sam logs -n <FunctionName> --stack-name photo-hq-dev
   ```

3. **Validate Template**:
   ```bash
   sam validate
   ```

4. **Check AWS Service Health**:
   https://status.aws.amazon.com/

5. **AWS Support**:
   - Create support case in AWS Console
   - Check AWS forums and documentation

## Summary

You've successfully deployed:
- ✅ 6 Lambda functions
- ✅ API Gateway with Cognito authorization
- ✅ 2 S3 buckets (encrypted)
- ✅ DynamoDB table with GSIs
- ✅ Cognito User Pool
- ✅ IAM roles with least privilege
- ✅ CloudWatch logging and X-Ray tracing

Your serverless photo backend is ready for use! 🎉
