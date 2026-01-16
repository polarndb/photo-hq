# Photo HQ Backend - Test Suite Summary

## What Was Created

A comprehensive API testing suite for the Photo HQ backend that validates all endpoints, authentication, file operations, and data relationships.

## Files Created

### Test Scripts
1. **`tests/comprehensive_api_test.py`** - Main test suite (Python)
   - Tests all API endpoints
   - Validates responses and CORS headers
   - Confirms proper error handling

2. **`run_comprehensive_tests.sh`** - Test runner script
   - Checks environment configuration
   - Installs dependencies
   - Runs tests and reports results

3. **`setup_test_env.sh`** - Environment setup script
   - Retrieves deployment information from AWS
   - Automatically creates .env file
   - Validates AWS credentials

### Configuration
4. **`.env.template`** - Environment variable template
   - Shows required configuration
   - Includes instructions for getting values

5. **`tests/requirements.txt`** - Python dependencies
   - requests (HTTP client)
   - boto3 (AWS SDK, optional)
   - Pillow (Image handling, optional)

### Documentation
6. **`TESTING.md`** - Complete testing guide
   - Setup instructions
   - Usage examples
   - Troubleshooting tips

7. **`tests/README.md`** - Test suite documentation
   - Feature list
   - Configuration details
   - Extension guide

## Test Coverage

### ✅ Endpoints Tested

1. **Authentication** (Cognito)
   - Unauthorized access rejection (401 responses)
   - Token-based authorization
   - User sign-up and sign-in (with AWS CLI)

2. **Photo Upload** (`POST /photos/upload`)
   - Presigned URL generation
   - Request validation (file size, content type)
   - Response format validation
   - S3 upload capability

3. **Photo Retrieval** (`GET /photos/{photo_id}`)
   - Presigned download URL generation
   - Version-specific retrieval (original vs edited)
   - Response format validation
   - S3 download capability

4. **List Photos** (`GET /photos`)
   - List all user photos
   - Filter by version type (original/edited)
   - Pagination support
   - Response format validation

5. **Photo Metadata** (`GET /photos/{photo_id}/metadata`)
   - Metadata retrieval
   - Original-edited relationship tracking
   - DynamoDB data validation

6. **Photo Update** (`PUT /photos/{photo_id}/edit`)
   - Edited version upload URL generation
   - Request validation
   - S3 edited bucket operations

7. **Photo Deletion** (`DELETE /photos/{photo_id}`)
   - Photo deletion
   - S3 cleanup verification
   - DynamoDB cleanup verification
   - Proper response format

### ✅ Additional Validations

8. **CORS Configuration**
   - Access-Control-Allow-Origin headers
   - Access-Control-Allow-Methods headers
   - Preflight OPTIONS requests

9. **Error Handling**
   - Invalid file size rejection (400)
   - Invalid content type rejection (400)
   - Non-existent resource handling (404)
   - Missing authorization (401)
   - Invalid query parameters (400)

10. **Response Format Validation**
    - JSON structure validation
    - Required field presence
    - Data type correctness
    - Status code appropriateness

11. **Metadata Tracking**
    - Original photo metadata in DynamoDB
    - Edited photo metadata in DynamoDB
    - Relationship between original and edited versions
    - S3 bucket and key tracking

## Usage

### Quick Start
```bash
# 1. Setup environment (automatic)
./setup_test_env.sh

# 2. Run tests
./run_comprehensive_tests.sh
```

### Manual Setup
```bash
# 1. Create .env file
cp .env.template .env
# Edit .env with your values

# 2. Run tests
./run_comprehensive_tests.sh
```

### Get Deployment Info
```bash
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --query 'Stacks[0].Outputs' \
  --output table
```

## Test Statistics

- **Total Test Categories**: 11
- **Minimum Tests Per Run**: 13+
- **Test Duration**: ~30-60 seconds (depending on API response times)
- **Success Criteria**: All tests must pass (100% pass rate)

## Prerequisites

### Required
- Python 3.7 or higher
- Internet connection to API endpoint
- Deployed Photo HQ backend on AWS

### Optional (for full testing)
- AWS CLI configured
- Access to Cognito User Pool (for user creation)
- Valid JWT access token (or will be created)

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `API_ENDPOINT` | Yes | API Gateway endpoint URL |
| `USER_POOL_ID` | Yes* | Cognito User Pool ID |
| `USER_POOL_CLIENT_ID` | Yes* | Cognito App Client ID |
| `AWS_REGION` | No | AWS region (default: us-east-1) |
| `ACCESS_TOKEN` | No | Pre-existing JWT token |

\* Required for user authentication tests. Can skip if providing ACCESS_TOKEN.

## Test Output Example

```
════════════════════════════════════════════════════════
Photo HQ Backend - API Test Suite
════════════════════════════════════════════════════════

──────────────────────────────────────────────────────
Test Suite: Authorization
──────────────────────────────────────────────────────

✅ PASS: Require Authorization for List Photos
   Correctly rejected unauthorized request

──────────────────────────────────────────────────────
Test Suite: Photo Upload
──────────────────────────────────────────────────────

✅ PASS: Request Upload Presigned URL
   Photo ID: a1b2c3d4-e5f6...

... (13+ more tests) ...

════════════════════════════════════════════════════════
Test Results Summary
════════════════════════════════════════════════════════

Total: 15
Passed: 15
Failed: 0
Pass Rate: 100.0%

🎉 All tests passed!
```

## Key Features

### 1. Comprehensive Coverage
Tests all critical functionality including edge cases and error conditions.

### 2. Automated Setup
The `setup_test_env.sh` script automatically retrieves configuration from AWS.

### 3. Clear Output
Color-coded results with detailed pass/fail information.

### 4. Flexible Configuration
Works with environment variables or .env file.

### 5. No Manual Intervention
Tests run autonomously once configured.

### 6. Realistic Testing
Tests actual HTTP requests to deployed API (not mocks).

### 7. Relationship Validation
Confirms DynamoDB properly tracks original-edited photo relationships.

### 8. Cleanup Verification
Tests that deletion properly removes data from both S3 and DynamoDB.

## Integration

### CI/CD Pipeline
```yaml
# GitHub Actions Example
- name: Run API Tests
  env:
    API_ENDPOINT: ${{ secrets.API_ENDPOINT }}
    ACCESS_TOKEN: ${{ secrets.ACCESS_TOKEN }}
  run: ./run_comprehensive_tests.sh
```

### Local Development
```bash
# Test after making changes
./run_comprehensive_tests.sh

# Test specific endpoint manually
curl -H "Authorization: Bearer $ACCESS_TOKEN" \
  $API_ENDPOINT/photos
```

## Troubleshooting

See `TESTING.md` for detailed troubleshooting guide including:
- Environment setup issues
- AWS credential problems
- Network connectivity errors
- Test failures and debugging

## Next Steps

1. **Run the tests**: `./run_comprehensive_tests.sh`
2. **Review results**: Check which tests pass/fail
3. **Fix issues**: Address any failing tests
4. **Repeat**: Run tests after fixes
5. **Integrate**: Add to CI/CD pipeline

## Support

- **Documentation**: See `TESTING.md` for complete guide
- **API Reference**: See `API_DOCUMENTATION.md`
- **Architecture**: See `ARCHITECTURE.md`
- **Deployment**: See `DEPLOYMENT.md`
