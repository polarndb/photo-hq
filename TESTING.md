# Photo HQ Backend - API Testing Guide

This guide explains how to test all API endpoints of the deployed Photo HQ backend.

## Overview

The test suite validates:
- ✅ User authentication with Cognito (sign up and sign in)
- ✅ Photo upload endpoint with presigned URL generation and S3 upload
- ✅ Photo retrieval endpoint with presigned URL generation and S3 download
- ✅ List photos endpoint with filtering by photo type (original vs edited)
- ✅ Photo metadata retrieval endpoint
- ✅ Photo update endpoint for uploading edited versions
- ✅ Photo deletion endpoint with S3 and DynamoDB cleanup
- ✅ CORS headers properly configured
- ✅ API responses match expected format and status codes
- ✅ Metadata tracking in DynamoDB for original and edited photo relationships

## Quick Start

### 1. Setup Test Environment

Automatically configure the test environment from your deployment:

```bash
./setup_test_env.sh
```

This will:
- Check AWS credentials
- Retrieve deployment information from CloudFormation
- Create `.env` file with configuration

### 2. Run Comprehensive Tests

```bash
./run_comprehensive_tests.sh
```

## Manual Setup

If you prefer manual setup or the automatic setup doesn't work:

### 1. Get Deployment Information

```bash
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --query 'Stacks[0].Outputs' \
  --output table
```

### 2. Create .env File

Copy the template and fill in your values:

```bash
cp .env.template .env
# Edit .env with your deployment information
```

Required variables:
- `API_ENDPOINT`: Your API Gateway endpoint URL
- `USER_POOL_ID`: Cognito User Pool ID
- `USER_POOL_CLIENT_ID`: Cognito User Pool Client ID
- `AWS_REGION`: AWS region (default: us-east-1)

### 3. (Optional) Get Access Token

If you already have a test user:

```bash
aws cognito-idp initiate-auth \
  --client-id YOUR_CLIENT_ID \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME=test@example.com,PASSWORD=YourPassword123!
```

Add the AccessToken to your `.env` file:
```bash
ACCESS_TOKEN=your-jwt-token-here
```

## Test Suites

### 1. Authorization Tests
- Verifies endpoints require authentication
- Tests 401 responses for unauthorized requests

### 2. Photo Upload Tests
- Requests presigned upload URLs
- Validates response format
- Tests S3 upload capability

### 3. Photo Listing Tests
- Lists all photos
- Filters by photo type (original/edited)
- Tests pagination support

### 4. Photo Retrieval Tests
- Gets presigned download URLs
- Tests version-specific retrieval (original vs edited)

### 5. Photo Update Tests
- Requests presigned URLs for edited versions
- Tests edited file upload

### 6. Photo Metadata Tests
- Retrieves photo metadata
- Validates original-edited relationship tracking

### 7. Photo Deletion Tests
- Deletes photos
- Verifies S3 cleanup
- Confirms DynamoDB cleanup

### 8. CORS Validation Tests
- Checks CORS headers on all endpoints
- Tests preflight (OPTIONS) requests

### 9. Error Handling Tests
- Tests invalid file size rejection
- Tests invalid content type rejection
- Tests 404 for non-existent resources
- Tests parameter validation

## Understanding Test Output

### Color Coding
- 🟢 **Green (✅)**: Test passed successfully
- 🔴 **Red (❌)**: Test failed
- 🟡 **Yellow**: Warning or additional information
- 🔵 **Blue**: Test suite header

### Sample Output

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

... (more tests) ...

════════════════════════════════════════════════════════
Test Results Summary
════════════════════════════════════════════════════════

Total: 25
Passed: 25
Failed: 0
Pass Rate: 100.0%

🎉 All tests passed!
```

## Test Coverage

| Category | Tests | Description |
|----------|-------|-------------|
| **Authentication** | 1 | Authorization requirement |
| **Upload** | 1 | Presigned URL generation |
| **Listing** | 2 | List all, filter by type |
| **Retrieval** | 1 | Download URL generation |
| **Update** | 1 | Edited version upload |
| **Metadata** | 1 | Metadata retrieval |
| **Deletion** | 2 | Delete + verify cleanup |
| **CORS** | 1 | CORS header validation |
| **Errors** | 3 | Invalid inputs, 404s |
| **Total** | **13+** | Comprehensive coverage |

## Troubleshooting

### "API_ENDPOINT not set"
Create or update your `.env` file with the required variables.

### "AWS credentials not configured"
Run `aws configure` to set up your AWS credentials.

### "Stack not found"
Check your stack name:
```bash
export STACK_NAME=your-actual-stack-name
./setup_test_env.sh
```

### "Connection refused" or timeout errors
- Verify the API endpoint is correct
- Check your network connection
- Ensure the backend is deployed and running

### Tests fail with 401 errors
- Ensure you have a valid ACCESS_TOKEN in `.env`
- Or let the test create a new user (requires AWS CLI with Cognito permissions)

### "Module not found" errors
Install required Python packages:
```bash
cd tests
pip install -r requirements.txt
```

## Advanced Usage

### Run Tests Directly

```bash
cd tests
python3 comprehensive_api_test.py
```

### Run with Custom Environment

```bash
export API_ENDPOINT=https://your-api.execute-api.us-east-1.amazonaws.com/prod
export ACCESS_TOKEN=your-token
cd tests
python3 comprehensive_api_test.py
```

### Integration with CI/CD

Example GitHub Actions workflow:

```yaml
- name: Test API
  env:
    API_ENDPOINT: ${{ secrets.API_ENDPOINT }}
    USER_POOL_ID: ${{ secrets.USER_POOL_ID }}
    USER_POOL_CLIENT_ID: ${{ secrets.USER_POOL_CLIENT_ID }}
    ACCESS_TOKEN: ${{ secrets.ACCESS_TOKEN }}
  run: |
    cd tests
    pip install -r requirements.txt
    python3 comprehensive_api_test.py
```

## Test Data Cleanup

The test suite creates:
- Temporary test photos in S3
- Metadata entries in DynamoDB
- (Optional) Test users in Cognito

Most test data is automatically cleaned up. For manual cleanup:

```bash
# List and delete test photos via API
# Or use the AWS Console/CLI to remove test data
```

## Extending the Tests

To add new tests:

1. Edit `tests/comprehensive_api_test.py`
2. Add methods to the `SimpleAPITester` class
3. Call your test method from `run_tests()`
4. Use `self.test_pass()` and `self.test_fail()` for results

Example:
```python
def test_my_feature(self):
    self.log("\nTest Suite: My Feature", Colors.BLUE)
    
    test_name = "Test Something"
    try:
        # Your test logic
        if success:
            self.test_pass(test_name, "Details")
        else:
            self.test_fail(test_name, "Error details")
    except Exception as e:
        self.test_fail(test_name, str(e))
```

## Getting Help

- Check the API documentation: `API_DOCUMENTATION.md`
- Review the architecture: `ARCHITECTURE.md`
- See deployment guide: `DEPLOYMENT.md`
- Check CloudWatch logs for API errors

## Security Notes

- Never commit `.env` files to version control
- Use IAM roles with minimal required permissions
- Rotate test user credentials regularly
- Delete test data after testing in production-like environments
