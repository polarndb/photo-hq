# Quick Start - Testing Photo HQ API

## 🚀 3-Step Quick Start

### Step 1: Setup Environment
```bash
./setup_test_env.sh
```
This automatically retrieves your deployment info from AWS CloudFormation.

### Step 2: Run Tests
```bash
./run_comprehensive_tests.sh
```
This runs all API tests and shows results.

### Step 3: Review Results
Look for:
- ✅ Green checkmarks = tests passed
- ❌ Red X's = tests failed
- Final summary with pass/fail count

## 📋 What Gets Tested

✅ User authentication (Cognito)  
✅ Photo upload with S3  
✅ Photo download from S3  
✅ List photos with filtering  
✅ Photo metadata retrieval  
✅ Edited version upload  
✅ Photo deletion with cleanup  
✅ CORS headers validation  
✅ Error handling (400, 401, 404)  
✅ DynamoDB metadata tracking  

## ⚙️ Manual Setup (if automatic fails)

1. **Get your deployment info:**
```bash
aws cloudformation describe-stacks \
  --stack-name photo-hq-dev \
  --query 'Stacks[0].Outputs' \
  --output table
```

2. **Create .env file:**
```bash
cp .env.template .env
# Edit .env and add your values:
# - API_ENDPOINT
# - USER_POOL_ID
# - USER_POOL_CLIENT_ID
```

3. **Run tests:**
```bash
./run_comprehensive_tests.sh
```

## 🔍 Understanding Results

### Success:
```
✅ PASS: Request Upload Presigned URL
   Photo ID: a1b2c3d4-e5f6...

Total: 15
Passed: 15
Failed: 0
Pass Rate: 100.0%

🎉 All tests passed!
```

### Failure:
```
❌ FAIL: Request Upload Presigned URL
   Status 500

Total: 15
Passed: 14
Failed: 1
Pass Rate: 93.3%

❌ 1 test(s) failed
```

## 🛠️ Troubleshooting

| Problem | Solution |
|---------|----------|
| "AWS CLI not installed" | Install: https://aws.amazon.com/cli/ |
| "AWS credentials not configured" | Run: `aws configure` |
| "Stack not found" | Check stack name with `aws cloudformation list-stacks` |
| "API_ENDPOINT not set" | Create .env file with deployment info |
| "Connection refused" | Verify API endpoint URL is correct |

## 📁 Files Created

```
photo-hq/
├── setup_test_env.sh          # Auto-setup script
├── run_comprehensive_tests.sh # Test runner
├── .env.template              # Config template
├── TESTING.md                 # Full testing guide
└── tests/
    ├── comprehensive_api_test.py  # Test suite
    ├── requirements.txt           # Python deps
    └── README.md                  # Test docs
```

## 🎯 Next Steps

1. ✅ Run tests once: `./run_comprehensive_tests.sh`
2. 📊 Check all tests pass
3. 🔄 Add to CI/CD pipeline (optional)
4. 📖 Read `TESTING.md` for advanced usage

## 💡 Pro Tips

- **Run before deploying**: Catch issues early
- **Run after changes**: Verify nothing broke
- **Save output**: `./run_comprehensive_tests.sh > test-results.txt`
- **CI/CD friendly**: Exit code 0 = success, 1 = failure

## 📚 More Information

- **Full Guide**: `TESTING.md`
- **API Docs**: `API_DOCUMENTATION.md`
- **Architecture**: `ARCHITECTURE.md`
- **Test Summary**: `TEST_SUITE_SUMMARY.md`

---

**Ready to test?**
```bash
./setup_test_env.sh && ./run_comprehensive_tests.sh
```
