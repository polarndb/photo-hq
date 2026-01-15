# GitHub Actions Workflow - Quick Reference

## 🚀 Quick Start

1. **Add GitHub Secrets:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION` (optional)

2. **Push to main branch:**
   ```bash
   git push origin main
   ```

3. **Watch deployment:**
   GitHub → Actions tab

## 📊 Workflow Overview

```
┌─────────────────────────────────────────────┐
│           TRIGGER (push to main)            │
└────────────────┬────────────────────────────┘
                 │
    ┌────────────▼────────────┐
    │     JOB 1: DEPLOY       │
    │  ✅ Validate template    │
    │  ✅ Build with SAM       │
    │  ✅ Deploy to AWS        │
    │  ✅ Get stack outputs    │
    └────────────┬────────────┘
                 │
    ┌────────────▼────────────┐
    │      JOB 2: TEST        │
    │  ✅ Create test user     │
    │  ✅ Get JWT token        │
    │  ✅ Test all endpoints   │
    │  ✅ Verify CRUD ops      │
    │  ✅ Cleanup resources    │
    └────────────┬────────────┘
                 │
    ┌────────────▼────────────┐
    │    ✅ SUCCESS / ❌ FAIL   │
    │  📊 Generate report      │
    │  🔔 Update badge         │
    └─────────────────────────┘
```

## 🧪 Test Coverage

| Endpoint | Method | Test |
|----------|--------|------|
| `/photos` | GET | ✅ Unauthorized access (401) |
| `/photos/upload` | POST | ✅ Upload presigned URL |
| `/photos` | GET | ✅ List with auth |
| `/photos/{id}` | GET | ✅ Get download URL |
| `/photos/{id}/metadata` | GET | ✅ Get metadata |
| `/photos/{id}/edit` | PUT | ✅ Update presigned URL |
| `/photos/{id}` | DELETE | ✅ Delete and verify |

## ⏱️ Typical Execution Time

| Job | Duration | Description |
|-----|----------|-------------|
| Deploy | 3-5 min | Build + Deploy SAM stack |
| Test | 2-3 min | Run comprehensive tests |
| **Total** | **5-8 min** | End-to-end workflow |

## 🔑 Required Secrets

| Secret | Purpose | Example |
|--------|---------|---------|
| `AWS_ACCESS_KEY_ID` | AWS IAM user key | `AKIAIOSFODNN7...` |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret | `wJalrXUtnFEMI...` |
| `AWS_REGION` | Deployment region | `us-east-1` |

## 📋 Required IAM Permissions

Minimal policy for GitHub Actions user:
- CloudFormation (create/update/delete stacks)
- Lambda (manage functions)
- API Gateway (manage APIs)
- S3 (manage buckets)
- DynamoDB (manage tables)
- Cognito (manage user pools)
- IAM (create/manage Lambda roles)
- CloudWatch Logs (create log groups)
- X-Ray (tracing)

See [CI_CD_SETUP.md](CI_CD_SETUP.md) for complete policy.

## 🎯 Manual Trigger

```
GitHub → Actions → Deploy and Test Photo HQ API → Run workflow
```

Use when:
- Testing workflow changes
- Re-deploying without code changes
- Deploying specific branch

## 📈 Monitoring

### During Deployment
- GitHub Actions → Running workflow → Live logs

### After Deployment
- README badge (status indicator)
- Workflow summary (test report)
- CloudWatch Logs (Lambda execution)
- X-Ray traces (performance analysis)

## ⚡ Quick Fixes

### Workflow Fails
1. Check job logs in GitHub Actions
2. Verify AWS credentials in Secrets
3. Check IAM permissions
4. Review CloudFormation events

### Tests Fail
1. Check API Gateway is deployed
2. Verify Cognito user pool exists
3. Review Lambda function logs
4. Check DynamoDB table access

### Deployment Timeout
- Check AWS region status
- Review CloudFormation for stuck resources
- Verify no conflicting manual changes

## 🔒 Security Best Practices

✅ Never commit AWS credentials
✅ Rotate access keys every 90 days
✅ Use least privilege IAM permissions
✅ Enable MFA on IAM user
✅ Consider GitHub OIDC for keyless auth
✅ Review workflow logs for sensitive data

## 🛠️ Workflow Configuration

File: `.github/workflows/deploy.yml`

Key settings:
```yaml
env:
  AWS_REGION: us-east-1    # Change for different region
  STACK_NAME: photo-hq-dev # Change for different environment
  PYTHON_VERSION: '3.11'   # Must match Lambda runtime
```

## 📚 Related Documentation

- [CI_CD_SETUP.md](CI_CD_SETUP.md) - Complete setup guide
- [README.md](README.md) - Project documentation
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - API reference

## 🆘 Support

For help:
1. Check [CI_CD_SETUP.md](CI_CD_SETUP.md) troubleshooting section
2. Review workflow logs
3. Check CloudWatch Logs
4. Open GitHub issue with error details

## ✨ Workflow Features

- ✅ Automatic deployment on push to main
- ✅ Manual trigger option (workflow_dispatch)
- ✅ Container-based builds for consistency
- ✅ Comprehensive test suite (8 endpoint tests)
- ✅ Automatic test user creation and cleanup
- ✅ Stack output extraction
- ✅ Artifact upload for debugging
- ✅ Test report generation
- ✅ Status badges in README
- ✅ Job dependency management
- ✅ Proper error handling
- ✅ Security best practices (no hardcoded secrets)

## 🎓 Learn More

- GitHub Actions: https://docs.github.com/actions
- AWS SAM: https://docs.aws.amazon.com/serverless-application-model/
- GitHub OIDC: https://docs.github.com/actions/deployment/security-hardening-your-deployments
