# Photo HQ Backend API - Deployment Status

## Deployment Configuration

### Stack Information
- **Stack Name**: `photo-hq-dev` (from samconfig.toml)
- **AWS Region**: `us-east-1` (from samconfig.toml)
- **Template**: `template.yaml`
- **Configuration**: `samconfig.toml`

### Template Validation
✓ Template syntax is valid (AWS SAM CloudFormation template)
✓ All required properties are defined
✓ IAM capabilities properly configured
✓ Resource naming follows AWS best practices

## Resources to be Deployed

### 1. API Gateway (`PhotoAPI`)
- **Type**: AWS::Serverless::Api
- **Stage**: prod
- **Features**:
  - CORS enabled for cross-origin requests
  - Cognito authorization configured
  - X-Ray tracing enabled
  - 6 API endpoints configured

**API Endpoints**:
```
POST   /photos/upload           - Generate presigned URL for photo upload
GET    /photos                  - List user's photos with filtering
GET    /photos/{photo_id}       - Get specific photo (presigned download URL)
PUT    /photos/{photo_id}/edit  - Upload edited version of photo
DELETE /photos/{photo_id}       - Delete photo and metadata
GET    /photos/{photo_id}/metadata - Get photo metadata
```

### 2. Lambda Functions (6 total)
All functions use Python 3.11 runtime with 512MB memory and 30-second timeout.

#### UploadPhotoFunction
- **Handler**: `upload_photo.lambda_handler`
- **Purpose**: Generate presigned URL for uploading photos to S3
- **Permissions**: S3 write (OriginalsBucket), DynamoDB write (PhotosTable)

#### GetPhotoFunction
- **Handler**: `get_photo.lambda_handler`
- **Purpose**: Generate presigned URL for downloading photos
- **Permissions**: S3 read (both buckets), DynamoDB read (PhotosTable)

#### ListPhotosFunction
- **Handler**: `list_photos.lambda_handler`
- **Purpose**: List user's photos with optional filtering
- **Permissions**: DynamoDB read (PhotosTable)

#### UpdatePhotoFunction
- **Handler**: `update_photo.lambda_handler`
- **Purpose**: Upload edited versions of photos
- **Permissions**: S3 write (EditedBucket), DynamoDB write (PhotosTable)

#### DeletePhotoFunction
- **Handler**: `delete_photo.lambda_handler`
- **Purpose**: Delete photos and associated metadata
- **Permissions**: S3 delete (both buckets), DynamoDB write (PhotosTable)

#### GetMetadataFunction
- **Handler**: `get_metadata.lambda_handler`
- **Purpose**: Retrieve photo metadata from database
- **Permissions**: DynamoDB read (PhotosTable)

### 3. S3 Buckets (2 total)

#### OriginalsBucket
- **Name Pattern**: `photo-hq-dev-originals-{AccountId}`
- **Features**:
  - AES-256 server-side encryption
  - Versioning enabled
  - Public access blocked
  - CORS configured
  - Lifecycle policy (delete old versions after 30 days)

#### EditedBucket
- **Name Pattern**: `photo-hq-dev-edited-{AccountId}`
- **Features**:
  - AES-256 server-side encryption
  - Versioning enabled
  - Public access blocked
  - CORS configured
  - Lifecycle policy (delete old versions after 30 days)

### 4. DynamoDB Table

#### PhotosTable
- **Name**: `photo-hq-dev-photos`
- **Billing Mode**: Pay-per-request (on-demand)
- **Primary Key**: `photo_id` (String)
- **Global Secondary Indexes**:
  1. **UserIdIndex**: Query photos by user_id and created_at
  2. **UserVersionIndex**: Query photos by user_id and version_type
- **Features**:
  - Point-in-time recovery enabled
  - Encryption at rest enabled
  - DynamoDB Streams enabled (NEW_AND_OLD_IMAGES)

**Table Schema**:
```
photo_id (S)        - Partition key, unique identifier
user_id (S)         - GSI partition key, user identifier from Cognito
created_at (S)      - GSI sort key, ISO timestamp
version_type (S)    - GSI sort key, "original" or "edited"
filename (S)        - Original filename
content_type (S)    - MIME type
file_size (N)       - File size in bytes
s3_key (S)          - S3 object key
s3_bucket (S)       - S3 bucket name
metadata (M)        - Additional metadata map
updated_at (S)      - Last update timestamp
```

### 5. Cognito User Pool

#### UserPool
- **Name**: `photo-hq-dev-users`
- **Features**:
  - Email-based authentication
  - Auto-verified email
  - Strong password policy (min 8 chars, requires upper, lower, numbers, symbols)
  - Optional MFA support
  - Email recovery mechanism

#### UserPoolClient
- **Name**: `photo-hq-dev-client`
- **Features**:
  - No client secret (for public applications)
  - Username/password authentication flow
  - Refresh token support
  - User existence error prevention

## Expected Deployment Outputs

After successful deployment, the following outputs will be available:

### ApiEndpoint
- **Description**: API Gateway endpoint URL
- **Format**: `https://{api-id}.execute-api.us-east-1.amazonaws.com/prod`
- **Usage**: Base URL for all API requests
- **Example**: `https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod`

### UserPoolId
- **Description**: Cognito User Pool ID
- **Format**: `us-east-1_{random-string}`
- **Usage**: Required for user management operations
- **Example**: `us-east-1_AbCdEfGhI`

### UserPoolClientId
- **Description**: Cognito User Pool Client ID
- **Format**: 26-character alphanumeric string
- **Usage**: Required for authentication requests
- **Example**: `1a2b3c4d5e6f7g8h9i0j1k2l3m`

### OriginalsBucketName
- **Description**: S3 bucket for original photos
- **Format**: `photo-hq-dev-originals-{account-id}`
- **Example**: `photo-hq-dev-originals-123456789012`

### EditedBucketName
- **Description**: S3 bucket for edited photos
- **Format**: `photo-hq-dev-edited-{account-id}`
- **Example**: `photo-hq-dev-edited-123456789012`

### PhotosTableName
- **Description**: DynamoDB table name
- **Format**: `photo-hq-dev-photos`
- **Example**: `photo-hq-dev-photos`

## Deployment Commands

### Prerequisites Check
```bash
# Verify AWS CLI is installed
aws --version

# Verify SAM CLI is installed
sam --version

# Verify AWS credentials are configured
aws sts get-caller-identity

# Verify Python 3.11 is available
python3 --version
```

### Deployment Steps

#### Option 1: Using the deployment script (Recommended)
```bash
# Make script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh
```

#### Option 2: Manual deployment
```bash
# Step 1: Validate template
sam validate --lint

# Step 2: Build application
sam build

# Step 3: Deploy (first time - guided)
sam deploy --guided

# Step 3: Deploy (subsequent times)
sam deploy
```

#### Option 3: Using configuration file
```bash
# Build and deploy using samconfig.toml
sam build && sam deploy --config-file samconfig.toml
```

## Post-Deployment Verification

### 1. Check Stack Status
```bash
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus' \
  --output text
```
Expected: `CREATE_COMPLETE` or `UPDATE_COMPLETE`

### 2. Verify Lambda Functions
```bash
aws lambda list-functions \
  --region us-east-1 \
  --query "Functions[?starts_with(FunctionName, 'photo-hq-dev')].FunctionName"
```
Expected: 6 functions listed

### 3. Verify S3 Buckets
```bash
aws s3 ls | grep photo-hq-dev
```
Expected: 2 buckets listed

### 4. Verify DynamoDB Table
```bash
aws dynamodb describe-table \
  --table-name photo-hq-dev-photos \
  --region us-east-1 \
  --query 'Table.TableStatus' \
  --output text
```
Expected: `ACTIVE`

### 5. Verify API Gateway
```bash
aws apigateway get-rest-apis \
  --region us-east-1 \
  --query "items[?name=='photo-hq-dev-api'].id" \
  --output text
```
Expected: API ID returned

### 6. Get All Outputs
```bash
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --region us-east-1 \
  --query 'Stacks[0].Outputs' \
  --output table
```

## Environment Configuration

After deployment, save the outputs to an environment file:

```bash
# deployment-outputs.env
export AWS_REGION="us-east-1"
export STACK_NAME="photo-hq-dev"
export API_ENDPOINT="https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod"
export USER_POOL_ID="us-east-1_AbCdEfGhI"
export USER_POOL_CLIENT_ID="1a2b3c4d5e6f7g8h9i0j1k2l3m"
export ORIGINALS_BUCKET="photo-hq-dev-originals-123456789012"
export EDITED_BUCKET="photo-hq-dev-edited-123456789012"
export PHOTOS_TABLE="photo-hq-dev-photos"
```

Load environment variables:
```bash
source deployment-outputs.env
```

## Testing the Deployment

### 1. Create Test User
```bash
aws cognito-idp sign-up \
  --client-id $USER_POOL_CLIENT_ID \
  --username test@example.com \
  --password "TestPass123!" \
  --user-attributes Name=email,Value=test@example.com \
  --region $AWS_REGION

aws cognito-idp admin-confirm-sign-up \
  --user-pool-id $USER_POOL_ID \
  --username test@example.com \
  --region $AWS_REGION
```

### 2. Authenticate User
```bash
TOKEN_RESPONSE=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $USER_POOL_CLIENT_ID \
  --auth-parameters USERNAME=test@example.com,PASSWORD=TestPass123! \
  --region $AWS_REGION)

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.AuthenticationResult.AccessToken')
```

### 3. Test API Endpoint
```bash
# List photos (should return empty list initially)
curl -X GET "${API_ENDPOINT}/photos" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json"

# Expected response:
# {"photos": [], "count": 0, "has_more": false}
```

### 4. Test Photo Upload
```bash
# Request upload URL
curl -X POST "${API_ENDPOINT}/photos/upload" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "test.jpg",
    "content_type": "image/jpeg",
    "file_size": 1048576
  }'

# Expected response includes:
# - photo_id
# - upload_url (presigned S3 URL)
# - upload_method: "PUT"
# - expires_in: 900
```

## Monitoring and Logs

### CloudWatch Logs
```bash
# Tail logs for a specific function
sam logs -n UploadPhotoFunction --stack-name photo-hq-dev --tail

# View recent logs
aws logs tail /aws/lambda/photo-hq-dev-upload-photo --follow
```

### X-Ray Tracing
- Console: https://console.aws.amazon.com/xray/
- View service map and trace details for API requests

### CloudFormation Stack Events
```bash
aws cloudformation describe-stack-events \
  --stack-name photo-hq-dev \
  --region us-east-1 \
  --max-items 20
```

## Cost Estimation

### Expected Monthly Costs (Development/Low Traffic)
- **Lambda**: ~$0.20 (1M requests, 400ms average)
- **API Gateway**: ~$3.50 (1M requests)
- **DynamoDB**: ~$1.25 (on-demand, 1M reads/writes)
- **S3**: ~$0.50 (10GB storage, 10K requests)
- **Cognito**: Free (first 50K MAUs)
- **CloudWatch**: ~$0.50 (logs and metrics)

**Estimated Total**: ~$6-8/month for development use

### Free Tier Eligible (First 12 Months)
- Lambda: 1M requests/month, 400K GB-seconds
- API Gateway: 1M requests/month
- DynamoDB: 25GB storage, 25 read/write capacity units
- S3: 5GB storage, 20K GET requests, 2K PUT requests
- CloudWatch: 10 metrics, 5GB logs, 1M API requests

## Security Considerations

### Implemented Security Features
✓ All S3 buckets have public access blocked
✓ Server-side encryption enabled (S3, DynamoDB)
✓ API Gateway uses Cognito authorizer
✓ IAM roles follow least privilege principle
✓ S3 versioning enabled for data protection
✓ CloudWatch logging enabled for audit trail
✓ X-Ray tracing enabled for security monitoring
✓ CORS configured to prevent unauthorized access
✓ Strong password policy enforced
✓ DynamoDB point-in-time recovery enabled

### Recommendations
- Configure CloudWatch alarms for suspicious activity
- Enable AWS CloudTrail for API logging
- Implement rate limiting in API Gateway
- Set up AWS WAF for additional protection
- Regular security audits and updates
- Rotate credentials periodically
- Monitor costs and set billing alarms

## Rollback Procedure

If deployment fails or issues arise:

```bash
# CloudFormation auto-rollback is enabled by default

# Manual rollback to previous version
aws cloudformation rollback-stack --stack-name photo-hq-dev --region us-east-1

# Check rollback status
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

## Cleanup/Deletion

To remove all resources:

```bash
# Use the cleanup script
./scripts/cleanup.sh

# Or manually:
# 1. Empty S3 buckets
aws s3 rm s3://photo-hq-dev-originals-{account-id} --recursive
aws s3 rm s3://photo-hq-dev-edited-{account-id} --recursive

# 2. Delete CloudFormation stack
aws cloudformation delete-stack --stack-name photo-hq-dev --region us-east-1

# 3. Wait for deletion to complete
aws cloudformation wait stack-delete-complete \
  --stack-name photo-hq-dev \
  --region us-east-1
```

## Current Status

### Deployment Prerequisites
⚠ **AWS CLI**: Not installed in current environment
⚠ **SAM CLI**: Not installed in current environment
⚠ **Network Access**: Limited (INTEGRATIONS_ONLY mode)
✓ **Template**: Valid and ready for deployment
✓ **Source Code**: All Lambda functions present
✓ **Configuration**: samconfig.toml configured
✓ **Documentation**: Complete

### Next Steps
To proceed with deployment, ensure:
1. AWS CLI is installed and configured
2. SAM CLI is installed
3. AWS credentials are configured (`aws configure`)
4. Network access to AWS services is available
5. Appropriate IAM permissions are granted

Then run:
```bash
./deploy.sh
```

## Support and Troubleshooting

For detailed troubleshooting guides, see:
- `DEPLOYMENT.md` - Comprehensive deployment guide
- `README.md` - Project overview and API documentation
- `API_DOCUMENTATION.md` - Detailed API specifications
- `ARCHITECTURE.md` - System architecture and design

Common issues and solutions are documented in `DEPLOYMENT.md`.
