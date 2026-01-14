# Photo HQ - Architecture Design Document

## Overview

Photo HQ is a serverless photo editing backend API designed to handle photo storage, version management, and metadata tracking for photo editing applications. The system supports 10-200 photos per batch with 1-few concurrent users.

## Architecture Principles

1. **Serverless-First**: No server management, automatic scaling
2. **Security by Default**: Encryption, least privilege, authentication required
3. **Cost-Optimized**: Pay-per-use pricing model
4. **Extensible**: Designed for future feature additions
5. **Best Practices**: Following AWS Well-Architected Framework

## System Architecture

### High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                          Client Layer                              │
│  (Web App / Mobile App / Desktop App)                             │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 │ HTTPS + JWT Token
                 │
┌────────────────▼───────────────────────────────────────────────────┐
│                    API Gateway (REST API)                          │
│  - CORS Configuration                                              │
│  - Request/Response Transformation                                 │
│  - Throttling & Rate Limiting                                      │
│  - CloudWatch Logging                                              │
└────────────────┬───────────────────────────────────────────────────┘
                 │
                 │ Validates JWT
                 │
┌────────────────▼───────────────────────────────────────────────────┐
│                    Cognito User Pool                               │
│  - User Authentication                                             │
│  - Password Policies                                               │
│  - MFA (Optional)                                                  │
│  - JWT Token Generation                                            │
└────────────────────────────────────────────────────────────────────┘
                 │
                 │ Authorization Passed
                 │
┌────────────────▼───────────────────────────────────────────────────┐
│                    Lambda Functions Layer                          │
│                                                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │upload_photo  │  │  get_photo   │  │ list_photos  │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │update_photo  │  │delete_photo  │  │get_metadata  │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                    │
│  Runtime: Python 3.11                                             │
│  Memory: 512MB                                                    │
│  Timeout: 30s                                                     │
│  Tracing: AWS X-Ray                                               │
└──────┬─────────────────────────────────────┬──────────────────────┘
       │                                     │
       │ Read/Write                          │ Read/Write
       │ (Presigned URLs)                    │ (Metadata)
       │                                     │
┌──────▼─────────────────────┐      ┌───────▼──────────────────────┐
│    Amazon S3 Buckets       │      │    Amazon DynamoDB           │
│                            │      │                              │
│  ┌──────────────────────┐ │      │  Table: Photos               │
│  │  Originals Bucket    │ │      │                              │
│  │  - AES-256 Encrypted │ │      │  Primary Key:                │
│  │  - Versioning ON     │ │      │  - photo_id (Hash)           │
│  │  - Block Public      │ │      │                              │
│  │  - Lifecycle Rules   │ │      │  GSI: UserIdIndex            │
│  └──────────────────────┘ │      │  - user_id (Hash)            │
│                            │      │  - created_at (Range)        │
│  ┌──────────────────────┐ │      │                              │
│  │  Edited Bucket       │ │      │  GSI: UserVersionIndex       │
│  │  - AES-256 Encrypted │ │      │  - user_id (Hash)            │
│  │  - Versioning ON     │ │      │  - version_type (Range)      │
│  │  - Block Public      │ │      │                              │
│  │  - Lifecycle Rules   │ │      │  Billing: Pay-per-request    │
│  └──────────────────────┘ │      │  Encryption: At Rest         │
│                            │      │  Backup: Point-in-Time       │
│  Structure:                │      │  Stream: Enabled             │
│  {user_id}/                │      └──────────────────────────────┘
│    originals/{photo_id}/   │
│    edited/{photo_id}/      │
└────────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│                    Monitoring & Logging                            │
│                                                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │ CloudWatch   │  │  AWS X-Ray   │  │ CloudWatch   │           │
│  │    Logs      │  │   Tracing    │  │   Metrics    │           │
│  └──────────────┘  └──────────────┘  └──────────────┘           │
└────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. API Gateway

**Purpose**: Entry point for all API requests

**Configuration**:
- Type: REST API (not HTTP API for better Cognito integration)
- Stage: prod
- CORS: Enabled for cross-origin requests
- Authorization: Cognito User Pool Authorizer (default)
- Throttling: Default AWS limits
- Logging: Full request/response logging to CloudWatch

**Endpoints**:
- `POST /photos/upload` → UploadPhotoFunction
- `GET /photos/{photo_id}` → GetPhotoFunction
- `GET /photos` → ListPhotosFunction
- `PUT /photos/{photo_id}/edit` → UpdatePhotoFunction
- `DELETE /photos/{photo_id}` → DeletePhotoFunction
- `GET /photos/{photo_id}/metadata` → GetMetadataFunction

**Security**:
- HTTPS only (enforced)
- JWT validation via Cognito
- Request validation enabled
- WAF integration ready (optional)

### 2. AWS Lambda Functions

**Common Configuration**:
```yaml
Runtime: python3.11
Memory: 512MB
Timeout: 30 seconds
Environment Variables:
  - PHOTOS_TABLE: DynamoDB table name
  - ORIGINALS_BUCKET: S3 bucket for originals
  - EDITED_BUCKET: S3 bucket for edited photos
  - USER_POOL_ID: Cognito User Pool ID
Tracing: AWS X-Ray enabled
```

#### 2.1 Upload Photo Function

**Purpose**: Generate presigned URL for uploading original photos

**Inputs**:
- filename, content_type, file_size

**Process**:
1. Validate user authentication
2. Validate file parameters (size 5-20MB, type JPEG)
3. Generate unique photo_id (UUID)
4. Create S3 presigned PUT URL (15min expiry)
5. Store metadata in DynamoDB (status: pending_upload)
6. Return presigned URL to client

**IAM Permissions**:
- s3:PutObject on originals bucket
- dynamodb:PutItem on photos table

#### 2.2 Get Photo Function

**Purpose**: Generate presigned URL for downloading photos

**Inputs**:
- photo_id, version (original/edited)

**Process**:
1. Validate user authentication
2. Query DynamoDB for photo metadata
3. Verify user ownership
4. Check if requested version exists
5. Generate S3 presigned GET URL (15min expiry)
6. Return download URL with metadata

**IAM Permissions**:
- s3:GetObject on both buckets
- dynamodb:GetItem on photos table

#### 2.3 List Photos Function

**Purpose**: List user's photos with filtering and pagination

**Inputs**:
- version_type (optional), limit, last_evaluated_key

**Process**:
1. Validate user authentication
2. Query DynamoDB using appropriate GSI
3. Apply filters and pagination
4. Return photo list with metadata

**IAM Permissions**:
- dynamodb:Query on photos table and GSIs

#### 2.4 Update Photo Function

**Purpose**: Generate presigned URL for uploading edited version

**Inputs**:
- photo_id, filename, content_type, file_size

**Process**:
1. Validate user authentication
2. Verify photo exists and user owns it
3. Generate S3 presigned PUT URL for edited bucket
4. Update DynamoDB metadata (has_edited_version=true)
5. Return presigned URL

**Notes**:
- Replaces previous edited version (same S3 key)
- Increments edit_count in metadata
- Original version preserved

**IAM Permissions**:
- s3:PutObject on edited bucket
- dynamodb:UpdateItem on photos table

#### 2.5 Delete Photo Function

**Purpose**: Delete photo and all versions

**Process**:
1. Validate user authentication
2. Verify photo exists and user owns it
3. Delete original from S3
4. Delete edited version from S3 (if exists)
5. Delete metadata from DynamoDB
6. Return deletion confirmation

**IAM Permissions**:
- s3:DeleteObject on both buckets
- dynamodb:DeleteItem on photos table

#### 2.6 Get Metadata Function

**Purpose**: Retrieve complete photo metadata

**Process**:
1. Validate user authentication
2. Query DynamoDB for photo metadata
3. Verify user ownership
4. Return complete metadata including extensible fields

**IAM Permissions**:
- dynamodb:GetItem on photos table

### 3. Amazon Cognito

**Purpose**: User authentication and authorization

**User Pool Configuration**:
- Username attribute: email
- Password policy:
  - Minimum length: 8
  - Requires: uppercase, lowercase, numbers, symbols
- Auto-verified attributes: email
- MFA: Optional (TOTP)
- Account recovery: Email-based

**User Pool Client**:
- No client secret (for public clients)
- Auth flows:
  - USER_PASSWORD_AUTH
  - REFRESH_TOKEN_AUTH
- Prevent user existence errors: Enabled

**Token Configuration**:
- Access token: 1 hour expiry
- ID token: 1 hour expiry
- Refresh token: 30 days expiry

### 4. Amazon S3

**Purpose**: Object storage for photos

#### Originals Bucket

**Naming**: `{stack-name}-originals-{account-id}`

**Configuration**:
- Encryption: SSE-S3 (AES-256)
- Versioning: Enabled
- Public access: Blocked (all 4 settings)
- Lifecycle rules:
  - Delete non-current versions after 30 days
- CORS: Enabled for presigned URL uploads

**Structure**:
```
{user_id}/originals/{photo_id}/{filename}
```

**Example**:
```
user-abc123/
  originals/
    photo-uuid-1/
      vacation.jpg
    photo-uuid-2/
      sunset.jpg
```

#### Edited Bucket

**Naming**: `{stack-name}-edited-{account-id}`

**Configuration**: Same as originals bucket

**Structure**:
```
{user_id}/edited/{photo_id}/{filename}
```

**Note**: Same photo_id as original, allows version replacement

### 5. Amazon DynamoDB

**Purpose**: Photo metadata storage

**Table Name**: `{stack-name}-photos`

**Billing Mode**: PAY_PER_REQUEST (on-demand)
- Auto-scales with traffic
- No capacity planning needed
- Cost-effective for variable workloads

**Primary Key**:
- Partition Key: `photo_id` (String, UUID)

**Attributes**:

Core attributes:
```
photo_id: String (PK)
user_id: String
filename: String
original_s3_key: String
original_bucket: String
version_type: String ("original" | "edited")
content_type: String
file_size: Number
created_at: String (ISO 8601)
updated_at: String (ISO 8601)
has_edited_version: Boolean
status: String
```

Edited version attributes:
```
edited_s3_key: String
edited_bucket: String
edited_filename: String
edited_content_type: String
edited_file_size: Number
edit_count: Number
```

Extensible attributes:
```
tags: List<String>
geolocation: Map {latitude: Number, longitude: Number}
description: String
camera_info: Map
```

**Global Secondary Indexes**:

1. **UserIdIndex**:
   - Partition Key: `user_id`
   - Sort Key: `created_at`
   - Projection: ALL
   - Use case: List all user's photos chronologically

2. **UserVersionIndex**:
   - Partition Key: `user_id`
   - Sort Key: `version_type`
   - Projection: ALL
   - Use case: Filter photos by original/edited

**Additional Features**:
- Point-in-Time Recovery: Enabled
- Encryption at rest: Enabled
- DynamoDB Streams: Enabled (for future processing)

## Data Flow Diagrams

### Upload Original Photo Flow

```
Client                API Gateway         Lambda              DynamoDB         S3
  │                        │                 │                    │             │
  │  POST /photos/upload   │                 │                    │             │
  ├───────────────────────>│                 │                    │             │
  │                        │                 │                    │             │
  │                        │ Validate JWT    │                    │             │
  │                        ├────────────────>│                    │             │
  │                        │                 │                    │             │
  │                        │   Invoke        │                    │             │
  │                        ├────────────────>│                    │             │
  │                        │                 │                    │             │
  │                        │                 │  Generate UUID     │             │
  │                        │                 │  Create presigned  │             │
  │                        │                 │       URL          │             │
  │                        │                 │                    │             │
  │                        │                 │  Store metadata    │             │
  │                        │                 ├───────────────────>│             │
  │                        │                 │                    │             │
  │    Return presigned    │    Response     │                    │             │
  │         URL            │<────────────────│                    │             │
  │<───────────────────────│                 │                    │             │
  │                        │                 │                    │             │
  │  PUT {presigned_url}                                                        │
  │  (Direct S3 upload)                                                         │
  ├────────────────────────────────────────────────────────────────────────────>│
  │                                                                              │
  │                                           200 OK                             │
  │<─────────────────────────────────────────────────────────────────────────────│
```

### Download Photo Flow

```
Client                API Gateway         Lambda              DynamoDB         S3
  │                        │                 │                    │             │
  │  GET /photos/{id}      │                 │                    │             │
  ├───────────────────────>│                 │                    │             │
  │                        │                 │                    │             │
  │                        │ Validate JWT    │                    │             │
  │                        ├────────────────>│                    │             │
  │                        │                 │                    │             │
  │                        │   Invoke        │                    │             │
  │                        ├────────────────>│                    │             │
  │                        │                 │                    │             │
  │                        │                 │  Get metadata      │             │
  │                        │                 ├───────────────────>│             │
  │                        │                 │                    │             │
  │                        │                 │  Verify ownership  │             │
  │                        │                 │  Generate presigned│             │
  │                        │                 │       GET URL      │             │
  │                        │                 │                    │             │
  │    Return download     │    Response     │                    │             │
  │         URL            │<────────────────│                    │             │
  │<───────────────────────│                 │                    │             │
  │                        │                 │                    │             │
  │  GET {presigned_url}                                                        │
  │  (Direct S3 download)                                                       │
  ├────────────────────────────────────────────────────────────────────────────>│
  │                                                                              │
  │                                    Photo Data                                │
  │<─────────────────────────────────────────────────────────────────────────────│
```

## Security Architecture

### Authentication Flow

```
1. User signs up → Cognito creates user
2. User confirms email → Account activated
3. User logs in → Cognito returns JWT tokens
   - AccessToken (for API)
   - IdToken (user info)
   - RefreshToken (get new tokens)
4. Client includes AccessToken in API requests
5. API Gateway validates token with Cognito
6. If valid, request proceeds to Lambda
```

### Authorization Layers

**Layer 1: API Gateway**
- Validates JWT signature
- Checks token expiration
- Verifies token issuer (Cognito)

**Layer 2: Lambda Function**
- Extracts user_id from JWT claims
- Verifies resource ownership
- Applies business logic authorization

**Layer 3: IAM Roles**
- Lambda execution roles with least privilege
- No cross-user data access
- Explicit deny on public access

### Data Encryption

**At Rest**:
- S3: SSE-S3 (AES-256)
- DynamoDB: AWS managed keys
- CloudWatch Logs: Encrypted

**In Transit**:
- API Gateway: HTTPS only
- S3 presigned URLs: HTTPS enforced
- Internal AWS: TLS 1.2+

### Network Security

- All S3 buckets block public access
- API Gateway endpoint: Regional (not edge-optimized for security)
- VPC not required (serverless, no network exposure)
- Optional: VPC endpoints for Lambda to S3/DynamoDB

## Scalability & Performance

### Current Capacity

**Expected Load**:
- Users: 1-few concurrent
- Photos per batch: 10-200
- Photo size: 5-20MB JPEG
- Operations: CRUD + version management

**Response Times**:
- API calls: <500ms (metadata operations)
- Presigned URL generation: <200ms
- S3 upload/download: Depends on network (typically 5-15s for 10MB)

### Auto-Scaling

All services auto-scale:

**Lambda**:
- Concurrent executions: Up to account limit (1000 default)
- Each function instance handles 1 request
- Cold start: ~500ms (Python 3.11)
- Warm invocations: <50ms

**DynamoDB**:
- On-demand mode: Auto-scales to handle load
- No throttling with proper data modeling
- Read/write capacity: Unlimited

**S3**:
- Automatic scaling for request rate
- 3,500 PUT/s, 5,500 GET/s per prefix
- Our structure (user_id/originals/photo_id) provides natural partitioning

**API Gateway**:
- Default throttle: 10,000 rps steady-state
- Burst: 5,000 requests
- More than sufficient for our workload

### Performance Optimizations

1. **Presigned URLs**: Direct S3 access (no Lambda bottleneck)
2. **GSIs**: Efficient querying by user and version type
3. **Pagination**: Cursor-based (performant for large datasets)
4. **Lambda memory**: 512MB balances performance and cost
5. **S3 structure**: User-based prefixes for parallelism

## Disaster Recovery

### Backup Strategy

**DynamoDB**:
- Point-in-Time Recovery: Last 35 days
- Can restore to any second within retention period
- Recovery time: Minutes to hours

**S3**:
- Versioning enabled: Protects against accidental deletion
- Old versions retained for 30 days (lifecycle rule)
- Cross-region replication ready (if needed)

**Recovery Time Objective (RTO)**: 1-4 hours
**Recovery Point Objective (RPO)**: Near-zero (continuous backups)

### Failure Scenarios

**S3 Failure**:
- AWS handles redundancy (11 9's durability)
- Cross-region replication for critical data (optional)

**DynamoDB Failure**:
- Multi-AZ by default
- Point-in-time restore available
- Manual export to S3 (optional)

**Lambda Failure**:
- Automatic retries on failures
- Dead letter queue (can be added)
- Stateless design allows instant recovery

**Complete Region Failure**:
- Requires multi-region deployment (future enhancement)
- CloudFormation template can redeploy in new region
- Data recovery from backups

## Cost Analysis

### Monthly Cost Estimate

For typical usage (200 photos/month, 5 users):

| Service | Usage | Cost |
|---------|-------|------|
| API Gateway | 1,000 requests | $0.01 |
| Lambda | 5,000 invocations × 1s × 512MB | $0.10 |
| DynamoDB | 10GB storage + 1,000 requests | $2.50 |
| S3 Storage | 3GB (originals + edited) | $0.07 |
| S3 Requests | 1,000 PUT/GET | $0.01 |
| Cognito | 5 MAU | Free Tier |
| X-Ray | 1,000 traces | Free Tier |
| CloudWatch Logs | 1GB | $0.50 |
| **Total** | | **~$3.20/month** |

### Cost Optimization Tips

1. Delete old photo versions (lifecycle rules configured)
2. Use S3 Intelligent-Tiering for infrequently accessed photos
3. DynamoDB on-demand is optimal for this workload
4. CloudWatch Logs retention: 7-30 days (reduce if needed)

## Future Enhancements

### Phase 2: Image Processing

```
S3 Upload → EventBridge → Lambda (Image Processor)
                              │
                              ├─> Generate thumbnails
                              ├─> Apply watermarks
                              ├─> Extract EXIF data
                              ├─> Auto-rotate
                              └─> Store in edited bucket
```

**Implementation**:
- S3 event notifications
- Processing Lambda with Pillow library
- SQS queue for batch processing
- Step Functions for complex workflows

### Phase 3: Role-Based Access Control

```
DynamoDB Schema Addition:
- photo_permissions table
- user_roles attribute
- shared_with: List<user_id>

Lambda Authorizer:
- Check user role
- Verify permission level
- Allow/deny based on rules
```

### Phase 4: Advanced Features

- **AI Tagging**: AWS Rekognition integration
- **CDN**: CloudFront for faster global delivery
- **Search**: Elasticsearch for advanced photo search
- **Batch Processing**: Bulk operations API
- **Webhooks**: Event notifications to client
- **Analytics**: Usage metrics and insights

## Compliance & Standards

### AWS Well-Architected Framework

**Operational Excellence**:
- Infrastructure as Code (SAM)
- CloudWatch monitoring
- X-Ray tracing

**Security**:
- Encryption at rest and in transit
- Least privilege IAM
- Authentication required
- No hardcoded secrets

**Reliability**:
- Multi-AZ by default
- Automatic retries
- Point-in-time recovery

**Performance Efficiency**:
- Serverless auto-scaling
- Presigned URLs for direct S3 access
- Efficient database indexes

**Cost Optimization**:
- Pay-per-use pricing
- Lifecycle rules
- On-demand billing

**Sustainability**:
- Serverless minimizes idle resources
- Efficient data structures
- Automatic resource management

### Security Standards

- HTTPS only
- JWT authentication
- Encrypted storage
- Audit logging
- No public access
- Regular security patches (Lambda runtime)

## Deployment Architecture

### Environment Strategy

**Development**:
- Stack: photo-hq-dev
- Separate resources
- Lower costs (smaller usage)

**Staging**:
- Stack: photo-hq-staging
- Production-like configuration
- Testing ground

**Production**:
- Stack: photo-hq-prod
- Full monitoring
- Alarms configured

### CI/CD Pipeline (Future)

```
Git Push → GitHub Actions / CodePipeline
             │
             ├─> Run tests
             ├─> Build SAM application
             ├─> Deploy to dev
             ├─> Integration tests
             ├─> Deploy to staging
             ├─> Deploy to prod (manual approval)
             └─> Smoke tests
```

## Monitoring Strategy

### Key Metrics

**API Gateway**:
- Request count
- 4xx/5xx error rates
- Latency (p50, p95, p99)
- Integration latency

**Lambda**:
- Invocations
- Errors
- Duration
- Throttles
- Concurrent executions

**DynamoDB**:
- Consumed read/write capacity
- Throttled requests
- System errors
- Query latency

**S3**:
- Total requests
- Error rates
- Bytes uploaded/downloaded

### Alarms

Recommended CloudWatch alarms:

```yaml
1. Lambda Error Rate > 5%
   Action: SNS notification

2. API Gateway 5xx Errors > 1%
   Action: SNS notification

3. DynamoDB Throttling
   Action: SNS notification

4. Lambda Duration > 25s
   Action: SNS notification (approaching timeout)
```

### Logging

**Log Retention**:
- Development: 7 days
- Production: 30 days

**Log Groups**:
- /aws/lambda/{function-name}
- /aws/apigateway/{api-name}

**Log Insights Queries**:
- Error tracking
- Performance analysis
- User activity monitoring

## Conclusion

This architecture provides:
- ✅ Secure photo storage and management
- ✅ Automatic scaling from 0 to 1000s of users
- ✅ Cost-effective for current workload (~$3/month)
- ✅ Production-ready security practices
- ✅ Extensible for future features
- ✅ Complete observability
- ✅ Infrastructure as Code
- ✅ Fast deployment (<15 minutes)

The serverless approach eliminates operational overhead while providing enterprise-grade reliability and security.
