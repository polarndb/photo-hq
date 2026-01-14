# Photo HQ - Serverless Photo Editing Backend API

A serverless photo editing backend API built with AWS SAM, providing secure photo storage, version management, and CRUD operations for photo editing applications.

## Architecture Overview

### Components

- **API Gateway**: REST API with CORS support and Cognito authentication
- **AWS Lambda**: Python 3.11 functions for API endpoints
- **Amazon Cognito**: User authentication with username/password
- **Amazon S3**: Encrypted buckets for original and edited photo storage
- **Amazon DynamoDB**: Photo metadata with GSI for efficient querying
- **AWS X-Ray**: Distributed tracing for monitoring and debugging

### Architecture Diagram

```
┌─────────────┐
│   Client    │
│ Application │
└──────┬──────┘
       │
       │ HTTPS + JWT
       ▼
┌─────────────────────────────────────┐
│      API Gateway (REST API)         │
│   - CORS enabled                    │
│   - Cognito Authorizer              │
└──────────┬──────────────────────────┘
           │
           │ Invokes
           ▼
┌─────────────────────────────────────┐
│      Lambda Functions (Python)      │
│  - upload_photo                     │
│  - get_photo                        │
│  - list_photos                      │
│  - update_photo                     │
│  - delete_photo                     │
│  - get_metadata                     │
└──┬──────────────────────────────┬───┘
   │                              │
   │ Read/Write                   │ Read/Write
   ▼                              ▼
┌──────────────┐            ┌─────────────┐
│  DynamoDB    │            │     S3      │
│   Photos     │            │  - Originals│
│  Metadata    │            │  - Edited   │
│  - GSIs      │            │  - Encrypted│
└──────────────┘            └─────────────┘
       │
       │ Authentication
       ▼
┌──────────────┐
│   Cognito    │
│  User Pool   │
└──────────────┘
```

### Data Flow

1. **Upload Original Photo**:
   - Client requests presigned URL from `/photos/upload`
   - Lambda generates presigned URL and stores metadata in DynamoDB
   - Client uploads photo directly to S3 using presigned URL
   
2. **Upload Edited Version**:
   - Client requests presigned URL from `/photos/{photo_id}/edit`
   - Lambda validates ownership and generates presigned URL
   - Client uploads edited photo to S3, replacing previous edited version
   - Metadata updated with new version info

3. **Download Photo**:
   - Client requests download URL from `/photos/{photo_id}?version=original|edited`
   - Lambda validates ownership and generates presigned URL
   - Client downloads directly from S3

## Security Features

### Authentication & Authorization
- Cognito User Pool with secure password policies
- JWT-based API authentication
- User ownership validation on all operations
- MFA support (optional)

### Data Security
- S3 bucket encryption (AES-256)
- All buckets block public access
- S3 versioning enabled for data recovery
- Presigned URLs expire after 15 minutes
- DynamoDB encryption at rest
- DynamoDB Point-in-Time Recovery enabled

### IAM Best Practices
- Least privilege IAM roles for Lambda functions
- Separate roles per function
- No hardcoded credentials
- Resource-based policies

### Network Security
- HTTPS only (enforced by API Gateway)
- CORS configured for frontend integration
- API Gateway throttling and request validation

## Prerequisites

- AWS Account
- AWS CLI configured with appropriate credentials
- AWS SAM CLI installed
- Python 3.11
- Git

## Installation

### 1. Install AWS SAM CLI

```bash
# macOS
brew install aws-sam-cli

# Windows
choco install aws-sam-cli

# Linux
pip install aws-sam-cli
```

### 2. Clone Repository

```bash
git clone <repository-url>
cd photo-hq
```

## Deployment

### Quick Deploy

```bash
# Build the application
sam build

# Deploy with guided setup (first time)
sam deploy --guided

# Follow the prompts:
# - Stack Name: photo-hq-dev
# - AWS Region: us-east-1 (or your preferred region)
# - Confirm changes before deploy: Y
# - Allow SAM CLI IAM role creation: Y
# - Save arguments to configuration file: Y
```

### Subsequent Deployments

```bash
sam build && sam deploy
```

### Custom Stack Name

```bash
sam deploy --stack-name photo-hq-prod --parameter-overrides ParameterKey=Environment,ParameterValue=prod
```

## Configuration

After deployment, note the outputs:

```bash
aws cloudformation describe-stacks --stack-name photo-hq-dev --query 'Stacks[0].Outputs'
```

Key outputs:
- **ApiEndpoint**: Base URL for API calls
- **UserPoolId**: Cognito User Pool ID
- **UserPoolClientId**: Cognito Client ID for authentication

## API Documentation

Base URL: `https://{api-id}.execute-api.{region}.amazonaws.com/prod`

### Authentication

All endpoints (except public authentication) require JWT token in Authorization header:

```
Authorization: Bearer <jwt-token>
```

### Get JWT Token

Use AWS Cognito to authenticate:

```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <UserPoolClientId> \
  --auth-parameters USERNAME=<email>,PASSWORD=<password>
```

### Endpoints

#### 1. Upload Photo (Generate Upload URL)

**Endpoint**: `POST /photos/upload`

**Description**: Generate presigned URL for uploading original photo to S3.

**Request Body**:
```json
{
  "filename": "vacation.jpg",
  "content_type": "image/jpeg",
  "file_size": 8388608
}
```

**Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "upload_url": "https://s3.amazonaws.com/...",
  "upload_method": "PUT",
  "expires_in": 900,
  "s3_key": "user-id/originals/photo-id/vacation.jpg",
  "message": "Upload the file using the provided presigned URL"
}
```

**Usage**:
```bash
# 1. Get presigned URL
curl -X POST https://api-endpoint/prod/photos/upload \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "photo.jpg",
    "content_type": "image/jpeg",
    "file_size": 10485760
  }'

# 2. Upload file to S3
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: image/jpeg" \
  --upload-file photo.jpg
```

**Validations**:
- File size: 5-20MB
- Content type: image/jpeg only
- Filename required

---

#### 2. Get Photo (Generate Download URL)

**Endpoint**: `GET /photos/{photo_id}`

**Description**: Generate presigned URL for downloading photo from S3.

**Query Parameters**:
- `version` (optional): `original` or `edited` (default: `original`)

**Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "version_type": "original",
  "download_url": "https://s3.amazonaws.com/...",
  "expires_in": 900,
  "metadata": {
    "filename": "vacation.jpg",
    "content_type": "image/jpeg",
    "file_size": 8388608,
    "created_at": "2024-01-14T10:30:00Z",
    "updated_at": "2024-01-14T10:30:00Z"
  }
}
```

**Usage**:
```bash
# Get original version
curl -X GET https://api-endpoint/prod/photos/123e4567-e89b-12d3-a456-426614174000 \
  -H "Authorization: Bearer $JWT_TOKEN"

# Get edited version
curl -X GET "https://api-endpoint/prod/photos/123e4567-e89b-12d3-a456-426614174000?version=edited" \
  -H "Authorization: Bearer $JWT_TOKEN"

# Download photo
curl -o photo.jpg "$DOWNLOAD_URL"
```

---

#### 3. List Photos

**Endpoint**: `GET /photos`

**Description**: List user's photos with optional filtering and pagination.

**Query Parameters**:
- `version_type` (optional): Filter by `original` or `edited`
- `limit` (optional): Number of items (default: 50, max: 100)
- `last_evaluated_key` (optional): Pagination token from previous response

**Response** (200 OK):
```json
{
  "photos": [
    {
      "photo_id": "123e4567-e89b-12d3-a456-426614174000",
      "filename": "vacation.jpg",
      "version_type": "original",
      "content_type": "image/jpeg",
      "file_size": 8388608,
      "created_at": "2024-01-14T10:30:00Z",
      "updated_at": "2024-01-14T10:30:00Z",
      "has_edited_version": true,
      "status": "uploaded"
    }
  ],
  "count": 1,
  "scanned_count": 1,
  "has_more": false
}
```

**Usage**:
```bash
# List all photos
curl -X GET https://api-endpoint/prod/photos \
  -H "Authorization: Bearer $JWT_TOKEN"

# Filter by version type
curl -X GET "https://api-endpoint/prod/photos?version_type=original&limit=20" \
  -H "Authorization: Bearer $JWT_TOKEN"

# Pagination
curl -X GET "https://api-endpoint/prod/photos?last_evaluated_key=$TOKEN" \
  -H "Authorization: Bearer $JWT_TOKEN"
```

---

#### 4. Update Photo (Upload Edited Version)

**Endpoint**: `PUT /photos/{photo_id}/edit`

**Description**: Generate presigned URL for uploading edited version. Replaces previous edited version.

**Request Body**:
```json
{
  "filename": "vacation_edited.jpg",
  "content_type": "image/jpeg",
  "file_size": 7340032
}
```

**Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "upload_url": "https://s3.amazonaws.com/...",
  "upload_method": "PUT",
  "expires_in": 900,
  "s3_key": "user-id/edited/photo-id/vacation_edited.jpg",
  "message": "Upload the edited file using the provided presigned URL",
  "note": "This will replace the previous edited version",
  "previous_version": "user-id/edited/photo-id/previous.jpg"
}
```

**Usage**:
```bash
# 1. Get presigned URL for edited version
curl -X PUT https://api-endpoint/prod/photos/123e4567/edit \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filename": "photo_edited.jpg",
    "content_type": "image/jpeg",
    "file_size": 9437184
  }'

# 2. Upload edited file
curl -X PUT "$UPLOAD_URL" \
  -H "Content-Type: image/jpeg" \
  --upload-file photo_edited.jpg
```

---

#### 5. Delete Photo

**Endpoint**: `DELETE /photos/{photo_id}`

**Description**: Delete photo and all versions (original and edited) from S3 and metadata from DynamoDB.

**Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "message": "Photo and all versions deleted successfully",
  "deleted_items": [
    {
      "type": "original",
      "bucket": "stack-originals-123456",
      "key": "user-id/originals/photo-id/vacation.jpg"
    },
    {
      "type": "edited",
      "bucket": "stack-edited-123456",
      "key": "user-id/edited/photo-id/vacation_edited.jpg"
    }
  ]
}
```

**Usage**:
```bash
curl -X DELETE https://api-endpoint/prod/photos/123e4567-e89b-12d3-a456-426614174000 \
  -H "Authorization: Bearer $JWT_TOKEN"
```

---

#### 6. Get Photo Metadata

**Endpoint**: `GET /photos/{photo_id}/metadata`

**Description**: Get complete metadata for a photo including both original and edited version information.

**Response** (200 OK):
```json
{
  "photo_id": "123e4567-e89b-12d3-a456-426614174000",
  "user_id": "user-cognito-sub",
  "created_at": "2024-01-14T10:30:00Z",
  "updated_at": "2024-01-14T11:45:00Z",
  "status": "uploaded",
  "original": {
    "filename": "vacation.jpg",
    "content_type": "image/jpeg",
    "file_size": 8388608,
    "s3_key": "user-id/originals/photo-id/vacation.jpg",
    "bucket": "stack-originals-123456"
  },
  "edited": {
    "filename": "vacation_edited.jpg",
    "content_type": "image/jpeg",
    "file_size": 7340032,
    "s3_key": "user-id/edited/photo-id/vacation_edited.jpg",
    "bucket": "stack-edited-123456",
    "edit_count": 2
  },
  "tags": ["vacation", "beach"],
  "geolocation": {
    "latitude": 40.7128,
    "longitude": -74.0060
  }
}
```

**Usage**:
```bash
curl -X GET https://api-endpoint/prod/photos/123e4567/metadata \
  -H "Authorization: Bearer $JWT_TOKEN"
```

---

### Error Responses

All endpoints return standard error responses:

**400 Bad Request**:
```json
{
  "error": "File size must be between 5MB and 20MB"
}
```

**401 Unauthorized**:
```json
{
  "error": "Authentication required"
}
```

**403 Forbidden**:
```json
{
  "error": "Access denied"
}
```

**404 Not Found**:
```json
{
  "error": "Photo not found"
}
```

**500 Internal Server Error**:
```json
{
  "error": "Internal server error"
}
```

## User Management

### Create User

```bash
aws cognito-idp sign-up \
  --client-id <UserPoolClientId> \
  --username user@example.com \
  --password 'SecurePass123!' \
  --user-attributes Name=email,Value=user@example.com
```

### Confirm User (Admin)

```bash
aws cognito-idp admin-confirm-sign-up \
  --user-pool-id <UserPoolId> \
  --username user@example.com
```

### Authenticate User

```bash
aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <UserPoolClientId> \
  --auth-parameters USERNAME=user@example.com,PASSWORD='SecurePass123!'
```

## Database Schema

### DynamoDB Table: Photos

**Primary Key**:
- `photo_id` (String, Hash Key)

**Attributes**:
- `user_id` (String) - Owner's Cognito sub
- `filename` (String) - Original filename
- `original_s3_key` (String) - S3 key for original
- `original_bucket` (String) - S3 bucket name
- `version_type` (String) - "original" or "edited"
- `content_type` (String) - MIME type
- `file_size` (Number) - Size in bytes
- `created_at` (String) - ISO timestamp
- `updated_at` (String) - ISO timestamp
- `has_edited_version` (Boolean)
- `edited_s3_key` (String) - S3 key for edited version
- `edited_bucket` (String)
- `edited_filename` (String)
- `edited_content_type` (String)
- `edited_file_size` (Number)
- `edit_count` (Number) - Number of edits
- `status` (String) - pending_upload, uploaded, etc.

**Extensible Fields** (optional):
- `tags` (List) - Photo tags
- `geolocation` (Map) - GPS coordinates
- `description` (String)
- `camera_info` (Map) - EXIF data

**Global Secondary Indexes**:

1. **UserIdIndex**:
   - Hash Key: `user_id`
   - Range Key: `created_at`
   - Use: List user's photos chronologically

2. **UserVersionIndex**:
   - Hash Key: `user_id`
   - Range Key: `version_type`
   - Use: Filter photos by original/edited

## S3 Bucket Structure

### Originals Bucket

```
photo-hq-originals-{account-id}/
└── {user_id}/
    └── originals/
        └── {photo_id}/
            └── {filename}
```

### Edited Bucket

```
photo-hq-edited-{account-id}/
└── {user_id}/
    └── edited/
        └── {photo_id}/
            └── {filename}
```

## Performance & Scalability

### Current Capacity

- **Workload**: 10-200 photos per batch
- **Concurrent Users**: 1-few users
- **Photo Size**: 5-20MB JPEG
- **Response Time**: <1s for API calls, <15s for S3 uploads/downloads

### DynamoDB

- **Billing Mode**: PAY_PER_REQUEST (on-demand)
- Automatically scales to handle workload
- No capacity planning required

### Lambda

- **Memory**: 512MB per function
- **Timeout**: 30 seconds
- **Concurrent Executions**: Auto-scales

### S3

- Unlimited storage capacity
- Automatic scaling for throughput
- S3 versioning for data recovery

### Cost Optimization

For the specified workload (10-200 photos, few users):
- DynamoDB on-demand pricing is cost-effective
- Lambda charges only for actual usage
- S3 lifecycle rules clean up old versions after 30 days

## Future Extensibility

### Planned Features

The architecture is designed to support:

1. **Backend Image Processing**:
   - Add S3 event trigger on upload
   - Lambda function with image processing (PIL/Pillow)
   - Auto-generate thumbnails, apply filters
   - Store results in edited bucket

2. **Role-Based Access Control (RBAC)**:
   - Add `role` attribute to Cognito users
   - Implement Lambda authorizer for fine-grained permissions
   - Support sharing photos between users

3. **Advanced Metadata**:
   - EXIF data extraction
   - AI-based tagging (Rekognition)
   - Content moderation
   - Face detection

4. **Batch Operations**:
   - Bulk upload endpoint
   - Batch processing jobs
   - SQS queue for async processing

### Extension Points

- **DynamoDB Streams**: React to metadata changes
- **EventBridge**: Cross-service integration
- **Step Functions**: Complex workflows
- **CloudFront**: CDN for photo delivery
- **ElastiCache**: Metadata caching

## Monitoring & Logging

### CloudWatch Logs

View Lambda logs:
```bash
sam logs -n UploadPhotoFunction --stack-name photo-hq-dev --tail
```

### X-Ray Tracing

All Lambda functions have X-Ray tracing enabled. View traces in AWS Console:
1. Navigate to X-Ray
2. Select Service Map or Traces
3. Filter by service name

### CloudWatch Metrics

Key metrics to monitor:
- API Gateway: 4xx/5xx errors, latency
- Lambda: Invocations, errors, duration
- DynamoDB: Consumed capacity, throttles
- S3: Request metrics, error rates

### Alarms

Set up CloudWatch alarms for:
- Lambda error rate > 5%
- API Gateway 5xx errors > 1%
- DynamoDB throttling events
- Lambda duration > 25s

## Testing

### Local Testing (SAM Local)

```bash
# Start API locally
sam local start-api

# Invoke specific function
sam local invoke UploadPhotoFunction -e events/upload.json
```

### Create Test Events

`events/upload.json`:
```json
{
  "body": "{\"filename\": \"test.jpg\", \"content_type\": \"image/jpeg\", \"file_size\": 10485760}",
  "requestContext": {
    "authorizer": {
      "claims": {
        "sub": "test-user-123"
      }
    }
  },
  "pathParameters": {},
  "queryStringParameters": {}
}
```

### Integration Testing

Use the provided test scripts:

```bash
# Run full API test suite
python tests/integration_test.py --api-url $API_ENDPOINT --token $JWT_TOKEN
```

## Troubleshooting

### Common Issues

1. **"User is not authorized to access this resource"**
   - Ensure JWT token is valid and not expired
   - Check Authorization header format: `Bearer <token>`

2. **"File size must be between 5MB and 20MB"**
   - Verify file size is within limits
   - Check file_size parameter in bytes

3. **"Photo not found"**
   - Verify photo_id is correct
   - Check user owns the photo

4. **Deployment fails with "Bucket already exists"**
   - S3 bucket names must be globally unique
   - Delete existing buckets or change stack name

5. **Presigned URL expired**
   - URLs expire after 15 minutes
   - Request new URL if expired

### Debug Mode

Enable detailed logging:

```bash
export SAM_CLI_TELEMETRY=0
export AWS_SAM_LOCAL_VERBOSE=1
sam local start-api --debug
```

## Cleanup

### Delete Stack

```bash
# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name photo-hq-dev

# Empty S3 buckets first (required)
aws s3 rm s3://photo-hq-dev-originals-123456 --recursive
aws s3 rm s3://photo-hq-dev-edited-123456 --recursive

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name photo-hq-dev
```

### Manual Cleanup

If stack deletion fails:

1. Empty all S3 buckets
2. Delete DynamoDB table
3. Delete CloudWatch log groups
4. Delete stack again

## Cost Estimation

For 200 photos/month, few users:

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| API Gateway | ~1000 requests | $0.01 |
| Lambda | ~5000 invocations, 256MB avg | $0.10 |
| DynamoDB | ~10 GB storage, 1000 RU | $2.50 |
| S3 | ~3 GB storage, 1000 requests | $0.10 |
| Cognito | 5 users | Free Tier |
| X-Ray | 1000 traces | Free Tier |
| **Total** | | **~$3/month** |

## License

This project is provided as-is for educational and commercial use.

## Support

For issues and questions:
- Open GitHub issue
- Check AWS SAM documentation
- Review CloudWatch logs

## Contributing

Contributions welcome! Please:
1. Fork repository
2. Create feature branch
3. Submit pull request with tests
4. Follow existing code style

## Version History

- **1.0.0** (2024-01-14): Initial release
  - Complete CRUD operations
  - Cognito authentication
  - Version management
  - Presigned URLs
  - Extensible metadata schema
