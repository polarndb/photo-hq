# Photo HQ Deployment Testing Guide

## Overview

This guide provides comprehensive instructions for deploying and testing the Photo HQ SAM application in your AWS environment before using GitHub Actions.

## Prerequisites

### Required Tools

1. **AWS SAM CLI**
   ```bash
   pip install aws-sam-cli
   sam --version  # Should be 1.100.0 or higher
   ```

2. **AWS CLI**
   ```bash
   pip install awscli
   aws --version  # Should be 2.x or higher
   ```

3. **Python 3.11+**
   ```bash
   python3 --version
   ```

4. **jq (optional but recommended)**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install jq
   
   # macOS
   brew install jq
   ```

### AWS Configuration

1. **Configure AWS Credentials**
   ```bash
   aws configure
   ```
   
   You'll need:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (e.g., us-east-1)
   - Output format (json recommended)

2. **Verify AWS Access**
   ```bash
   aws sts get-caller-identity
   ```

### Required IAM Permissions

Your AWS user/role needs permissions for:
- CloudFormation (create/update/delete stacks)
- Lambda (create/update functions)
- API Gateway (create/update APIs)
- S3 (create/manage buckets)
- DynamoDB (create/manage tables)
- Cognito (create/manage user pools)
- IAM (create/attach roles and policies)
- CloudWatch Logs (create log groups)

## Deployment Process

### Option 1: Automated Deployment (Recommended)

Use the provided deployment script:

```bash
cd /path/to/photo-hq
./deploy-and-test.sh
```

This script will:
1. ✅ Check all prerequisites
2. ✅ Validate SAM template
3. ✅ Build application
4. ✅ Deploy to AWS
5. ✅ Verify all resources
6. ✅ Test API endpoints
7. ✅ Generate deployment report

### Option 2: Manual Deployment

#### Step 1: Validate Template

```bash
sam validate --lint --region us-east-1
```

**Expected Output:**
```
/path/to/template.yaml is a valid SAM Template
```

**Common Issues:**
- Invalid YAML syntax → Check indentation (use spaces, not tabs)
- Missing required properties → Review CloudFormation/SAM documentation
- Invalid resource references → Verify !Ref and !GetAtt references

#### Step 2: Build Application

```bash
sam build --region us-east-1
```

**Expected Output:**
```
Build Succeeded

Built Artifacts  : .aws-sam/build
Built Template   : .aws-sam/build/template.yaml
```

**Build Time:** 2-3 minutes (first build)

**Common Issues:**
- Missing dependencies → Check src/requirements.txt
- Python version mismatch → Use Python 3.11
- Syntax errors in Lambda code → Review Lambda function files

#### Step 3: Deploy to AWS

```bash
sam deploy \
  --stack-name photo-hq-dev \
  --region us-east-1 \
  --no-confirm-changeset \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_IAM \
  --resolve-s3 \
  --tags "Environment=dev Project=photo-hq ManagedBy=SAM" \
  --disable-rollback
```

**Expected Duration:**
- First deployment: 5-10 minutes
- Subsequent updates: 2-5 minutes

**Deployment Progress:**
```
Deploying with following values
===============================
Stack name                   : photo-hq-dev
Region                       : us-east-1
Confirm changeset            : False
Disable rollback             : True
Deployment s3 bucket         : aws-sam-cli-managed-default-samclisourcebucket-*
Capabilities                 : ["CAPABILITY_IAM"]
Parameter overrides          : {}
Signing Profiles             : {}

Initiating deployment
=====================
...
CloudFormation stack changeset
...
Status: CREATE_COMPLETE (or UPDATE_COMPLETE)
```

**Common Issues:**

1. **S3 Bucket Name Conflict**
   - Error: "Bucket name already exists"
   - Cause: S3 bucket names must be globally unique
   - Fix: SAM auto-generates unique names using AWS Account ID
   - Verification: Bucket names include `${AWS::AccountId}` in template

2. **IAM Permission Errors**
   - Error: "User is not authorized to perform..."
   - Cause: Insufficient IAM permissions
   - Fix: Add required permissions to your IAM user/role
   - Required actions: See "Required IAM Permissions" section above

3. **CloudFormation Resource Limits**
   - Error: "Resource limit exceeded"
   - Cause: AWS account limits reached
   - Fix: Request limit increase or clean up old resources

4. **DynamoDB Index Creation Timeout**
   - Error: "Resource creation timeout"
   - Cause: Global Secondary Indexes take time to create
   - Fix: Usually resolves on retry; stack will continue creating

5. **Lambda Execution Role Creation**
   - Error: "Role already exists"
   - Cause: Previous failed deployment left orphaned resources
   - Fix: Either delete manually or use `--force-upload` flag

#### Step 4: Get Stack Outputs

```bash
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --region us-east-1 \
  --query 'Stacks[0].Outputs' \
  --output table
```

**Expected Outputs:**
- ApiEndpoint
- UserPoolId
- UserPoolClientId
- OriginalsBucketName
- EditedBucketName
- PhotosTableName

**Save these values** - you'll need them for testing!

## Resource Verification

### Verify Lambda Functions

```bash
aws lambda list-functions \
  --region us-east-1 \
  --query "Functions[?starts_with(FunctionName, 'photo-hq-dev')].FunctionName" \
  --output table
```

**Expected:** 6 Lambda functions
- photo-hq-dev-upload-photo
- photo-hq-dev-get-photo
- photo-hq-dev-list-photos
- photo-hq-dev-update-photo
- photo-hq-dev-delete-photo
- photo-hq-dev-get-metadata

### Verify API Gateway

```bash
aws apigateway get-rest-apis \
  --region us-east-1 \
  --query "items[?name=='photo-hq-dev-api'].[name,id]" \
  --output table
```

**Expected:** One API with ID

### Verify S3 Buckets

```bash
aws s3 ls | grep photo-hq-dev
```

**Expected:** 2 buckets
- photo-hq-dev-originals-{AccountId}
- photo-hq-dev-edited-{AccountId}

### Verify DynamoDB Table

```bash
aws dynamodb describe-table \
  --table-name photo-hq-dev-photos \
  --region us-east-1 \
  --query 'Table.[TableName,TableStatus]' \
  --output table
```

**Expected:** Table status = ACTIVE

### Verify Cognito User Pool

```bash
aws cognito-idp describe-user-pool \
  --user-pool-id <YOUR_USER_POOL_ID> \
  --region us-east-1 \
  --query 'UserPool.[Id,Name,Status]' \
  --output table
```

**Expected:** Status = Active

## API Testing

### Test 1: Unauthorized Access

```bash
API_ENDPOINT="https://xxxxx.execute-api.us-east-1.amazonaws.com/prod"

curl -X GET "$API_ENDPOINT/photos"
```

**Expected Response:**
```json
{"message":"Unauthorized"}
```

**Expected HTTP Code:** 401

✅ **Pass Criteria:** Returns 401 Unauthorized

### Test 2: Create Test User

```bash
# Get outputs
USER_POOL_ID="<from stack outputs>"
USER_POOL_CLIENT_ID="<from stack outputs>"

# Create user
TEST_EMAIL="test-user-$(date +%s)@example.com"
TEST_PASSWORD="TestPass123!@#"

aws cognito-idp sign-up \
  --client-id "$USER_POOL_CLIENT_ID" \
  --username "$TEST_EMAIL" \
  --password "$TEST_PASSWORD" \
  --user-attributes Name=email,Value="$TEST_EMAIL" \
  --region us-east-1

# Confirm user (admin action)
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id "$USER_POOL_ID" \
  --username "$TEST_EMAIL" \
  --region us-east-1
```

**Expected:** User created and confirmed

### Test 3: Authenticate User

```bash
# Get access token
AUTH_RESPONSE=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id "$USER_POOL_CLIENT_ID" \
  --auth-parameters USERNAME="$TEST_EMAIL",PASSWORD="$TEST_PASSWORD" \
  --region us-east-1 \
  --output json)

ACCESS_TOKEN=$(echo "$AUTH_RESPONSE" | jq -r '.AuthenticationResult.AccessToken')

echo "Access Token: $ACCESS_TOKEN"
```

**Expected:** Valid JWT access token returned

### Test 4: List Photos (Empty)

```bash
curl -X GET "$API_ENDPOINT/photos" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Expected Response:**
```json
{
  "photos": [],
  "count": 0
}
```

✅ **Pass Criteria:** Returns 200 with empty photos array

### Test 5: Upload Photo

```bash
UPLOAD_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/photos/upload" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test-photo.jpg",
    "content_type": "image/jpeg",
    "file_size": 6291456
  }')

echo "$UPLOAD_RESPONSE" | jq .

PHOTO_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.photo_id')
echo "Photo ID: $PHOTO_ID"
```

**Expected Response:**
```json
{
  "photo_id": "uuid-here",
  "upload_url": "https://s3.amazonaws.com/...",
  "upload_method": "PUT",
  "expires_in": 900,
  "s3_key": "user-id/originals/photo-id/test-photo.jpg",
  "message": "Upload the file using the provided presigned URL"
}
```

✅ **Pass Criteria:** Returns 200 with photo_id and upload_url

### Test 6: Get Photo Metadata

```bash
curl -X GET "$API_ENDPOINT/photos/$PHOTO_ID/metadata" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq .
```

**Expected Response:**
```json
{
  "photo_id": "uuid",
  "user_id": "cognito-sub",
  "filename": "test-photo.jpg",
  "content_type": "image/jpeg",
  "file_size": 6291456,
  "status": "pending_upload",
  "created_at": "2026-01-16T...",
  "has_edited_version": false
}
```

✅ **Pass Criteria:** Returns 200 with photo metadata

### Test 7: Get Photo Download URL

```bash
curl -X GET "$API_ENDPOINT/photos/$PHOTO_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq .
```

**Expected Response:**
```json
{
  "photo_id": "uuid",
  "download_url": "https://s3.amazonaws.com/...",
  "expires_in": 900
}
```

✅ **Pass Criteria:** Returns 200 with download_url

### Test 8: Update Photo (Upload Edited Version)

```bash
curl -X PUT "$API_ENDPOINT/photos/$PHOTO_ID/edit" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test-photo-edited.jpg",
    "content_type": "image/jpeg",
    "file_size": 7340032
  }' | jq .
```

**Expected Response:**
```json
{
  "photo_id": "uuid",
  "upload_url": "https://s3.amazonaws.com/...",
  "upload_method": "PUT",
  "expires_in": 900,
  "message": "Upload edited photo using the provided presigned URL"
}
```

✅ **Pass Criteria:** Returns 200 with upload_url for edited version

### Test 9: Delete Photo

```bash
curl -X DELETE "$API_ENDPOINT/photos/$PHOTO_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq .
```

**Expected Response:**
```json
{
  "message": "Photo deleted successfully",
  "photo_id": "uuid"
}
```

✅ **Pass Criteria:** Returns 200 with success message

### Test 10: Cleanup

```bash
# Delete test user
aws cognito-idp admin-delete-user \
  --user-pool-id "$USER_POOL_ID" \
  --username "$TEST_EMAIL" \
  --region us-east-1
```

## Troubleshooting

### CloudFormation Events

If deployment fails, check CloudFormation events:

```bash
aws cloudformation describe-stack-events \
  --stack-name photo-hq-dev \
  --region us-east-1 \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED` || ResourceStatus==`UPDATE_FAILED`].[Timestamp,ResourceType,LogicalResourceId,ResourceStatusReason]' \
  --output table
```

### Lambda Function Logs

Check Lambda execution logs:

```bash
aws logs tail /aws/lambda/photo-hq-dev-upload-photo \
  --region us-east-1 \
  --follow
```

### API Gateway Logs

Enable API Gateway CloudWatch logs in AWS Console:
1. Go to API Gateway console
2. Select your API
3. Go to Stages → prod → Logs/Tracing
4. Enable CloudWatch Logs

### DynamoDB Table Status

Check if table is still being created:

```bash
aws dynamodb describe-table \
  --table-name photo-hq-dev-photos \
  --region us-east-1 \
  --query 'Table.[TableStatus,GlobalSecondaryIndexes[].IndexStatus]' \
  --output table
```

## GitHub Actions Setup

Once local deployment is successful, configure GitHub Actions:

### 1. Set Repository Secrets

In your GitHub repository:
- Go to Settings → Secrets and variables → Actions
- Add the following secrets:
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REGION` (optional, defaults to us-east-1)

### 2. Verify Workflow File

The workflow file `.github/workflows/deploy.yml` should already be configured correctly.

### 3. Trigger Workflow

**Option 1: Push to main branch**
```bash
git add .
git commit -m "Ready for deployment"
git push origin main
```

**Option 2: Manual trigger**
- Go to Actions tab in GitHub
- Select "Deploy and Test Photo HQ API"
- Click "Run workflow"

### 4. Monitor Workflow

- Go to Actions tab
- Click on the running workflow
- Monitor each step's progress
- Check for any failures

## Success Criteria

✅ **Deployment Successful When:**

1. All CloudFormation resources created (CREATE_COMPLETE or UPDATE_COMPLETE)
2. All 6 Lambda functions deployed and accessible
3. API Gateway endpoint returns responses
4. S3 buckets created and accessible
5. DynamoDB table active with correct schema
6. Cognito User Pool created and users can authenticate
7. All API endpoints return expected responses
8. Authentication properly rejects unauthorized requests
9. CORS headers present in responses
10. No errors in CloudWatch Logs

## Cleanup (Optional)

To delete all deployed resources:

```bash
# Delete CloudFormation stack
aws cloudformation delete-stack \
  --stack-name photo-hq-dev \
  --region us-east-1

# Monitor deletion
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

**Note:** S3 buckets have `DeletionPolicy: Retain` and won't be automatically deleted. Delete manually if needed:

```bash
# Empty and delete buckets
aws s3 rm s3://photo-hq-dev-originals-{AccountId} --recursive
aws s3 rb s3://photo-hq-dev-originals-{AccountId}

aws s3 rm s3://photo-hq-dev-edited-{AccountId} --recursive
aws s3 rb s3://photo-hq-dev-edited-{AccountId}
```

## Support

For issues or questions:
1. Check CloudFormation events for detailed error messages
2. Review CloudWatch Logs for Lambda execution errors
3. Verify IAM permissions are correctly configured
4. Ensure all prerequisites are installed and up-to-date
5. Check AWS service quotas and limits

## Next Steps

After successful deployment:
1. ✅ Document your deployment in PR description
2. ✅ Share deployment report with team
3. ✅ Configure GitHub Actions for automated deployments
4. ✅ Set up monitoring and alerts
5. ✅ Plan for production deployment with proper environment separation
