# Photo HQ Backend - Comprehensive API Test Suite

This test suite provides comprehensive testing of all Photo HQ backend API endpoints, including authentication, file operations, CORS validation, and error handling.

## Features

The test suite validates:

✅ **Authentication**
- Cognito user sign-up
- Cognito user sign-in
- JWT token validation

✅ **Photo Upload**
- Presigned URL generation
- Actual S3 file upload
- Response format validation
- CORS headers validation

✅ **Photo Retrieval**
- Presigned download URL generation
- Actual S3 file download
- Version-specific retrieval (original vs edited)
- Response format validation

✅ **Photo Listing**
- List all photos
- Filter by photo type (original/edited)
- Pagination support
- Response format validation

✅ **Photo Update**
- Edited version upload
- Presigned URL generation for edits
- Actual edited file upload to S3

✅ **Photo Metadata**
- Metadata retrieval
- Original-edited relationship tracking
- DynamoDB metadata validation

✅ **Photo Deletion**
- Photo deletion endpoint
- S3 cleanup verification
- DynamoDB cleanup verification
- Response format validation

✅ **CORS Configuration**
- CORS headers on all endpoints
- Preflight (OPTIONS) request handling
- Cross-origin compatibility

✅ **Error Handling**
- Invalid file size rejection
- Invalid content type rejection
- Non-existent resource handling
- Authorization requirement
- Parameter validation

## Prerequisites

1. **Deployed Backend**: The Photo HQ backend must be deployed to AWS
2. **Python 3.7+**: Required to run the test suite
3. **AWS Credentials**: Configured for Cognito operations (optional, for user management)

## Installation

1. Install Python dependencies:
```bash
cd tests
pip install -r requirements.txt
```

## Configuration

Create a `.env` file in the project root with your deployment information:

```bash
# Get values from CloudFormation stack outputs
API_ENDPOINT=https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/prod
USER_POOL_ID=us-east-1_XXXXXXXXX
USER_POOL_CLIENT_ID=xxxxxxxxxxxxxxxxxxxxxxxxxx
AWS_REGION=us-east-1
```

### Getting Configuration Values

If you deployed with CloudFormation/SAM:

```bash
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --query 'Stacks[0].Outputs' \
  --output table
```

## Running Tests

### Option 1: Run All Tests (Recommended)

Use the provided runner script:

```bash
./run_comprehensive_tests.sh
```

This script will:
- Check for required environment variables
- Install dependencies if needed
- Run the complete test suite
- Provide a detailed test report

### Option 2: Run Tests Directly

```bash
cd tests
python3 comprehensive_api_test.py
```

### Option 3: Run with Custom Python

```bash
cd tests
/path/to/python comprehensive_api_test.py
```

## Test Output

The test suite provides color-coded output:

- 🟢 **Green**: Test passed
- 🔴 **Red**: Test failed
- 🟡 **Yellow**: Warning or informational message
- 🔵 **Blue**: Test suite header

Example output:
```
════════════════════════════════════════════════════════
Photo HQ Backend - Comprehensive API Test Suite
════════════════════════════════════════════════════════

API Endpoint: https://abc123.execute-api.us-east-1.amazonaws.com/prod
Region: us-east-1

──────────────────────────────────────────────────────
Test Suite: Authentication (Cognito)
──────────────────────────────────────────────────────
✅ PASS: Cognito User Sign Up
   User created: test-abc123@example.com
✅ PASS: Cognito User Sign In
   Token obtained (expires in 3600s)
✅ PASS: JWT Token Validation
   Token length: 1234 chars

... (more tests) ...

════════════════════════════════════════════════════════
Test Results Summary
════════════════════════════════════════════════════════

Total Tests: 45
Passed: 45
Failed: 0
Pass Rate: 100.0%

🎉 All tests passed!
```

## Test Suites

### 1. Authentication Tests
Tests Cognito user management and JWT token generation.

### 2. Photo Upload Tests
Tests the complete upload workflow including presigned URL generation and actual S3 upload.

### 3. Photo Retrieval Tests
Tests download functionality with presigned URLs and actual S3 download.

### 4. Photo Listing Tests
Tests photo listing with filtering by type (original vs edited).

### 5. Photo Update Tests
Tests uploading edited versions of photos.

### 6. Photo Metadata Tests
Tests metadata retrieval and relationship tracking between original and edited photos.

### 7. Photo Deletion Tests
Tests deletion with S3 and DynamoDB cleanup verification.

### 8. CORS Validation Tests
Tests CORS headers on all endpoints and preflight requests.

### 9. Error Handling Tests
Tests proper error responses for invalid inputs and edge cases.

## Test Data

The test suite automatically creates:
- Test users in Cognito (with random emails)
- Test JPEG images (using PIL or mock data)
- Test photos in S3 (cleaned up after tests)
- Test metadata in DynamoDB (cleaned up after tests)

## Troubleshooting

### "Missing required environment variables"
Ensure your `.env` file exists and contains all required variables.

### "Authentication required" errors
Make sure AWS credentials are configured if running tests that require Cognito operations:
```bash
aws configure
```

### "Connection error" or timeouts
- Verify the API endpoint is correct and accessible
- Check your network connection
- Ensure the backend is deployed and running

### "PIL/Pillow not installed" warning
The test suite can run without PIL, but it's recommended to install it:
```bash
pip install Pillow
```

### Tests failing due to missing photos
Some tests depend on previous tests. Run the complete suite rather than individual tests.

## Continuous Integration

To integrate with CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run API Tests
  env:
    API_ENDPOINT: ${{ secrets.API_ENDPOINT }}
    USER_POOL_ID: ${{ secrets.USER_POOL_ID }}
    USER_POOL_CLIENT_ID: ${{ secrets.USER_POOL_CLIENT_ID }}
  run: |
    cd tests
    pip install -r requirements.txt
    python3 comprehensive_api_test.py
```

## Contributing

To add new tests:

1. Add test methods to the `PhotoHQAPITester` class
2. Follow the naming convention: `test_suite_*` for test suites
3. Use `self.test_pass()` and `self.test_fail()` for results
4. Add the suite to `run_all_tests()` method

## License

This test suite is part of the Photo HQ project.
