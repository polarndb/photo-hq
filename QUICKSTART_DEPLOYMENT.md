# Quick Start: Deploy and Test Photo HQ

## TL;DR - One Command Deployment

```bash
./deploy-and-test.sh
```

This will automatically:
1. ✅ Check prerequisites
2. ✅ Validate SAM template
3. ✅ Build application
4. ✅ Deploy to AWS
5. ✅ Verify all resources
6. ✅ Test all API endpoints
7. ✅ Generate deployment report

**Duration:** ~10-15 minutes

---

## Prerequisites

Install these first:

```bash
# Install AWS SAM CLI
pip install aws-sam-cli

# Install AWS CLI  
pip install awscli

# Configure AWS credentials
aws configure
```

---

## What Gets Deployed

### AWS Resources (19 total)
- 🔐 **Cognito User Pool** - User authentication
- 🌐 **API Gateway** - REST API with Cognito auth
- 🪣 **2 S3 Buckets** - Original and edited photos
- 🗄️ **DynamoDB Table** - Photo metadata
- ⚡ **6 Lambda Functions** - API handlers

### API Endpoints
```
POST   /photos/upload          - Generate upload URL
GET    /photos                 - List user's photos
GET    /photos/{id}            - Get download URL
GET    /photos/{id}/metadata   - Get photo metadata
PUT    /photos/{id}/edit       - Generate edit upload URL
DELETE /photos/{id}            - Delete photo
```

---

## Validation Results

✅ **No Critical Issues Found**

The deployment configuration is production-ready:
- SAM template: Valid structure, 19 resources
- Workflow: Optimized for CI/CD
- Lambda code: Proper error handling, CORS, validation
- IAM policies: Comprehensive permissions
- Security: Encryption, authentication, HTTPS

---

## Documentation

### For Quick Deployment
- **This file** - Quick start instructions
- `deploy-and-test.sh` - Automated deployment script

### For Manual Deployment
- `DEPLOYMENT_TESTING_GUIDE.md` - Step-by-step manual instructions

### For Understanding What Was Done
- `DEPLOYMENT_VALIDATION_SUMMARY.md` - Complete overview
- `ROOT_CAUSE_ANALYSIS.md` - Detailed technical analysis
- `PR_DEPLOYMENT_VALIDATION.md` - Pull request description

---

## After Successful Deployment

1. **Save the outputs** from the deployment report:
   ```
   API Endpoint: https://xxxxx.execute-api.us-east-1.amazonaws.com/prod
   User Pool ID: us-east-1_xxxxx
   User Pool Client ID: xxxxx
   ```

2. **Configure GitHub Actions**:
   - Add AWS credentials as repository secrets
   - Push to main branch or manually trigger workflow

3. **Start using the API**:
   - Create Cognito users
   - Authenticate to get access tokens
   - Make API requests with `Authorization: Bearer <token>` header

---

## Troubleshooting

### Deployment Failed?

1. **Check CloudFormation events:**
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name photo-hq-dev \
     --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
   ```

2. **Check Lambda logs:**
   ```bash
   aws logs tail /aws/lambda/photo-hq-dev-upload-photo --follow
   ```

3. **Review detailed troubleshooting:**
   - See `DEPLOYMENT_TESTING_GUIDE.md` section "Troubleshooting"
   - See `ROOT_CAUSE_ANALYSIS.md` section "Potential Failure Scenarios"

### Common Issues

**"Command not found: sam"**
→ Install SAM CLI: `pip install aws-sam-cli`

**"Unable to locate credentials"**
→ Run: `aws configure`

**"Access Denied"**
→ Check IAM permissions (see `DEPLOYMENT_TESTING_GUIDE.md`)

**"Stack already exists"**
→ Script handles this automatically (performs update instead)

---

## Cleanup

To delete all resources:

```bash
aws cloudformation delete-stack --stack-name photo-hq-dev --region us-east-1
```

**Note:** S3 buckets have retention policy and must be manually deleted:
```bash
aws s3 rb s3://photo-hq-dev-originals-{AccountId} --force
aws s3 rb s3://photo-hq-dev-edited-{AccountId} --force
```

---

## Cost Estimate

**Development (minimal usage):** < $1/month  
**Production (moderate usage):** ~$320/month

Most components covered by AWS Free Tier for development.

---

## Success Criteria

✅ Deployment is successful when:
1. CloudFormation stack status: CREATE_COMPLETE
2. All 19 resources created
3. All 6 Lambda functions working
4. API endpoint returns responses
5. Authentication working (401 for unauthorized)
6. All CRUD operations tested successfully

---

## Next Steps

1. Run `./deploy-and-test.sh`
2. Review deployment report
3. Configure GitHub Actions secrets
4. Push to enable automated deployments

---

## Support

**Full Documentation:**
- `DEPLOYMENT_VALIDATION_SUMMARY.md` - Complete overview
- `DEPLOYMENT_TESTING_GUIDE.md` - Detailed manual testing
- `ROOT_CAUSE_ANALYSIS.md` - Technical deep dive

**Questions?** Review the troubleshooting sections in the documentation above.

---

**Status:** ✅ Ready for deployment testing  
**Last Updated:** January 16, 2026
