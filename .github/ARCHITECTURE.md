# GitHub Actions CI/CD Architecture

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GITHUB REPOSITORY                            │
│                                                                       │
│  ┌─────────────────┐                                                │
│  │   Developer      │                                                │
│  │   Push to main   │                                                │
│  └────────┬─────────┘                                                │
│           │                                                           │
│           ▼                                                           │
│  ┌─────────────────────────────────────────────────┐                │
│  │          GitHub Actions Workflow                 │                │
│  │         (.github/workflows/deploy.yml)          │                │
│  └────────┬──────────────────────────────┬─────────┘                │
└───────────┼──────────────────────────────┼──────────────────────────┘
            │                              │
            │                              │
    ┌───────▼──────────┐        ┌─────────▼───────────┐
    │   JOB 1: DEPLOY  │        │   JOB 2: TEST       │
    │   (ubuntu-latest)│        │   (ubuntu-latest)   │
    │                  │        │   depends_on: deploy│
    └───────┬──────────┘        └─────────┬───────────┘
            │                              │
            │                              │
┌───────────▼──────────────────┐  ┌────────▼────────────────────┐
│     AWS DEPLOYMENT           │  │   API TESTING               │
│                              │  │                             │
│  1. Setup Python 3.11        │  │  1. Setup Python 3.11       │
│  2. Install SAM CLI          │  │  2. Install test deps       │
│  3. Configure AWS creds      │  │  3. Configure AWS creds     │
│     ├─ AWS_ACCESS_KEY_ID     │  │  4. Create test user        │
│     ├─ AWS_SECRET_ACCESS_KEY │  │     ├─ Cognito SignUp       │
│     └─ AWS_REGION            │  │     ├─ Admin Confirm        │
│  4. Validate SAM template    │  │     └─ Get JWT token        │
│  5. Build (--use-container)  │  │  5. Run test suite          │
│  6. Deploy to AWS            │  │     ├─ Auth tests           │
│     ├─ CloudFormation Stack  │  │     ├─ Upload test          │
│     ├─ Lambda Functions      │  │     ├─ List test            │
│     ├─ API Gateway           │  │     ├─ Retrieval test       │
│     ├─ S3 Buckets            │  │     ├─ Metadata test        │
│     ├─ DynamoDB Table        │  │     ├─ Update test          │
│     └─ Cognito User Pool     │  │     └─ Delete test          │
│  7. Get stack outputs        │  │  6. Verify all endpoints    │
│     ├─ API Endpoint    ──────┼──┼──────────┐                  │
│     ├─ User Pool ID    ──────┼──┼──────────┼──┐               │
│     └─ Client ID       ──────┼──┼──────────┼──┼──┐            │
│  8. Upload artifacts         │  │          │  │  │            │
└──────────────────────────────┘  │          │  │  │            │
                                   │          │  │  │            │
                                   └──────────┘  │  │            │
                                                 │  │            │
                                   ┌─────────────┘  │            │
                                   │                │            │
                                   │  ┌─────────────┘            │
                                   │  │                          │
                                   │  │  7. Cleanup test user    │
                                   │  │  8. Generate report      │
                                   │  │                          │
                                   ▼  ▼                          │
                          ┌─────────────────────┐               │
                          │  AWS Resources      │               │
                          │  ├─ API Endpoint    │◄──────────────┘
                          │  ├─ User Pool       │
                          │  └─ Deployed App    │
                          └─────────────────────┘
                                   │
                                   ▼
                          ┌─────────────────────┐
                          │   Test Results      │
                          │  ✅ All tests passed │
                          │  📊 Summary report   │
                          │  🔔 Update badge     │
                          └─────────────────────┘
```

## Security Flow

```
┌──────────────────────────────────────────────────────────────┐
│                     GitHub Secrets                            │
│  🔒 AWS_ACCESS_KEY_ID                                        │
│  🔒 AWS_SECRET_ACCESS_KEY                                    │
│  🔒 AWS_REGION                                               │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Injected at runtime
                         ▼
┌──────────────────────────────────────────────────────────────┐
│               GitHub Actions Runner                           │
│  Environment variables (temporary, never logged)             │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ AWS SDK/CLI
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                    AWS Services                               │
│  ✅ Authenticated via IAM                                    │
│  ✅ All API calls signed with credentials                    │
│  ✅ CloudTrail logs all actions                              │
└──────────────────────────────────────────────────────────────┘
```

## Test Execution Flow

```
┌──────────────────────┐
│  Deploy Job Complete │
│  ✅ API Endpoint      │
│  ✅ User Pool ID      │
│  ✅ Client ID         │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  Create Test User                    │
│  1. Generate random email            │
│  2. Sign up with Cognito             │
│  3. Admin confirm user               │
│  4. Authenticate (USER_PASSWORD_AUTH)│
│  5. Extract access token             │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  Test Suite Execution                │
│                                      │
│  Test 1: Unauthorized Access         │
│    curl GET /photos (no auth)        │
│    ✅ Expect 401                     │
│                                      │
│  Test 2: Photo Upload                │
│    POST /photos/upload               │
│    ✅ Get presigned URL + photo_id   │
│                                      │
│  Test 3: Photo Listing               │
│    GET /photos                       │
│    ✅ Get list of photos             │
│                                      │
│  Test 4: Photo Metadata              │
│    GET /photos/{id}/metadata         │
│    ✅ Verify metadata structure      │
│                                      │
│  Test 5: Photo Retrieval             │
│    GET /photos/{id}                  │
│    ✅ Get download URL               │
│                                      │
│  Test 6: Photo Update                │
│    PUT /photos/{id}/edit             │
│    ✅ Get presigned URL for edit     │
│                                      │
│  Test 7: Photo Deletion              │
│    DELETE /photos/{id}               │
│    ✅ Verify deletion message        │
│                                      │
│  Comprehensive Test (Python)         │
│    Run tests/comprehensive_api_test.py│
│    ✅ All endpoint tests             │
│    ✅ CORS validation                │
│    ✅ Error handling                 │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  Cleanup                             │
│  1. Delete test user from Cognito    │
│  2. Test photos auto-deleted         │
│  3. Generate test report             │
│  4. Update workflow status           │
└──────────┬───────────────────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│  Results                             │
│  ✅ Success: Update badge to green   │
│  ❌ Failure: Update badge to red     │
│  📊 Job summary with details         │
│  📧 Notify on failures (optional)    │
└──────────────────────────────────────┘
```

## AWS Resource Creation Flow

```
GitHub Actions (Deploy Job)
    │
    ├─► sam build
    │     └─► Build Lambda functions
    │           └─► Install Python dependencies
    │
    └─► sam deploy
          │
          └─► CloudFormation Stack
                │
                ├─► Create Cognito User Pool
                │     ├─► User Pool
                │     └─► User Pool Client
                │
                ├─► Create S3 Buckets
                │     ├─► Originals Bucket (encrypted)
                │     └─► Edited Bucket (encrypted)
                │
                ├─► Create DynamoDB Table
                │     ├─► Photos Table
                │     ├─► UserIdIndex (GSI)
                │     └─► UserVersionIndex (GSI)
                │
                ├─► Create API Gateway
                │     ├─► REST API
                │     ├─► Cognito Authorizer
                │     └─► CORS Configuration
                │
                ├─► Create Lambda Functions
                │     ├─► upload_photo
                │     ├─► get_photo
                │     ├─► list_photos
                │     ├─► update_photo
                │     ├─► delete_photo
                │     └─► get_metadata
                │
                ├─► Create IAM Roles
                │     └─► Lambda execution roles
                │
                └─► Enable X-Ray Tracing
```

## Dependency Management

```
Deploy Job                  Test Job
    │                         │
    │                         │ (waits for deploy)
    │                         │
    ▼                         │
Deployment Success           │
    │                         │
    │ Outputs:               │
    ├─ api_endpoint ─────────┼───► Used in tests
    ├─ user_pool_id ─────────┼───► Create test user
    └─ user_pool_client_id ──┼───► Authenticate
                              │
                              ▼
                        Test Execution
```

## Error Handling Flow

```
┌─────────────────┐
│  Step Execution │
└────────┬────────┘
         │
         ▼
    ┌─────────┐
    │ Success?│
    └────┬────┘
         │
    ┌────┼────┐
    │         │
   Yes       No
    │         │
    │         ▼
    │    ┌────────────────┐
    │    │ Log error      │
    │    │ Mark job failed│
    │    │ Stop workflow  │
    │    └────────────────┘
    │
    ▼
┌──────────────────┐
│ Continue to next │
│ step or job      │
└──────────────────┘
         │
         ▼
    ┌─────────┐
    │ Cleanup │◄───── Always runs
    │ (if any)│       (if: always())
    └─────────┘
```

## Monitoring Points

```
┌──────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                           │
│                                                               │
│  GitHub Actions                                              │
│  ├─ Workflow status (success/failure)                       │
│  ├─ Job execution time                                       │
│  ├─ Step-by-step logs                                        │
│  └─ Artifact uploads                                         │
│                                                               │
│  AWS CloudFormation                                          │
│  ├─ Stack creation events                                    │
│  ├─ Resource status                                          │
│  └─ Rollback on failure                                      │
│                                                               │
│  AWS CloudWatch                                              │
│  ├─ Lambda function logs                                     │
│  ├─ API Gateway access logs                                  │
│  ├─ Custom metrics                                           │
│  └─ Alarms (optional)                                        │
│                                                               │
│  AWS X-Ray                                                   │
│  ├─ Request traces                                           │
│  ├─ Service map                                              │
│  └─ Performance analysis                                     │
│                                                               │
│  Test Reports                                                │
│  ├─ Pass/fail status                                         │
│  ├─ Individual test results                                  │
│  ├─ Coverage summary                                         │
│  └─ Execution time                                           │
└──────────────────────────────────────────────────────────────┘
```

## Cost Considerations

```
GitHub Actions (Free Tier)
  ├─ 2,000 minutes/month for public repos
  └─ ~8 minutes per workflow run
      └─ ~250 deployments/month free

AWS Costs (per deployment)
  ├─ CloudFormation: Free
  ├─ Lambda invocations: ~$0.000001 per test
  ├─ API Gateway: ~$0.00001 per test request
  ├─ Cognito: Free (test user creation/deletion)
  ├─ DynamoDB: ~$0.000001 per test operation
  └─ S3: ~$0.000001 per test operation
      
Total per deployment: < $0.01
Monthly (10 deployments): < $0.10
```

## Best Practices Applied

✅ **Separation of Concerns**
   - Deploy job handles infrastructure
   - Test job validates functionality

✅ **Fail Fast**
   - Validate template before build
   - Build before deploy
   - Deploy before test

✅ **Proper Dependencies**
   - Tests wait for deployment
   - Stack outputs passed to tests

✅ **Security**
   - Secrets never logged
   - Test user auto-deleted
   - Credentials rotated regularly

✅ **Observability**
   - Detailed logs at each step
   - Test reports generated
   - Status badges updated

✅ **Idempotency**
   - `--no-fail-on-empty-changeset`
   - CloudFormation handles updates
   - Cleanup always runs

✅ **Resource Efficiency**
   - Container builds cached
   - Python dependencies cached
   - Artifacts retained 7 days
