# CI/CD Setup Guide

This guide provides detailed instructions for setting up automated deployment and testing with GitHub Actions.

## Overview

The GitHub Actions workflow (`deploy.yml`) automates:
- **Building** the SAM application
- **Deploying** to AWS
- **Testing** all API endpoints
- **Reporting** results via badges and summaries

## Quick Setup (5 minutes)

### Step 1: Configure GitHub Secrets

1. Navigate to your repository on GitHub
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add these three secrets:

| Secret Name | Value | How to Get |
|------------|-------|------------|
| `AWS_ACCESS_KEY_ID` | Your IAM access key | AWS Console → IAM → Users → Security credentials |
| `AWS_SECRET_ACCESS_KEY` | Your IAM secret key | Same as above (shown only once when created) |
| `AWS_REGION` | `us-east-1` (or your region) | Optional, defaults to us-east-1 |

### Step 2: Push to Main Branch

```bash
git add .
git commit -m "Add CI/CD workflow"
git push origin main
```

The workflow will automatically start! 🚀

### Step 3: Monitor Progress

1. Go to **Actions** tab in your repository
2. Click on the running workflow
3. Watch the deployment and tests in real-time

## Creating IAM User for GitHub Actions

### Using AWS Console

1. **Sign in** to AWS Console
2. Navigate to **IAM** → **Users** → **Add users**
3. User name: `github-actions-photo-hq`
4. Select **Programmatic access**
5. Click **Next: Permissions**

### Attach Policies

Choose one of these options:

#### Option 1: Use AWS Managed Policies (Quick)
Attach these policies:
- `AWSCloudFormationFullAccess`
- `AWSLambda_FullAccess`
- `AmazonAPIGatewayAdministrator`
- `AmazonS3FullAccess`
- `AmazonDynamoDBFullAccess`
- `AmazonCognitoPowerUser`
- `IAMFullAccess` (or create custom policy for limited role creation)
- `CloudWatchLogsFullAccess`

#### Option 2: Create Custom Policy (Recommended)
Create a custom policy with minimal required permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:DescribeStackResources",
        "cloudformation:GetTemplateSummary",
        "cloudformation:ValidateTemplate",
        "lambda:CreateFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:DeleteFunction",
        "lambda:GetFunction",
        "lambda:AddPermission",
        "lambda:RemovePermission",
        "apigateway:*",
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:PutBucketEncryption",
        "s3:PutBucketVersioning",
        "s3:PutBucketPublicAccessBlock",
        "s3:PutLifecycleConfiguration",
        "s3:PutBucketCORS",
        "s3:GetObject",
        "s3:PutObject",
        "dynamodb:CreateTable",
        "dynamodb:UpdateTable",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTable",
        "cognito-idp:CreateUserPool",
        "cognito-idp:CreateUserPoolClient",
        "cognito-idp:DeleteUserPool",
        "cognito-idp:DeleteUserPoolClient",
        "cognito-idp:DescribeUserPool",
        "cognito-idp:SignUp",
        "cognito-idp:AdminConfirmSignUp",
        "cognito-idp:AdminDeleteUser",
        "cognito-idp:InitiateAuth",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy",
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ],
      "Resource": "*"
    }
  ]
}
```

### Get Access Keys

1. After user creation, click **Download .csv**
2. Save this file securely (secret key shown only once!)
3. Copy `Access key ID` and `Secret access key` to GitHub Secrets

### Security Best Practices

✅ **Enable MFA** on the IAM user
✅ **Rotate keys** every 90 days
✅ **Delete unused keys** immediately
✅ **Use separate users** for different environments
✅ **Monitor usage** with CloudTrail

## Workflow Details

### Workflow Triggers

The workflow runs when:
- Code is pushed to `main` branch
- Manual trigger from GitHub Actions UI (workflow_dispatch)

### Job 1: Deploy

**Duration:** ~3-5 minutes

Steps:
1. ✅ Checkout code
2. ✅ Set up Python 3.11
3. ✅ Install SAM CLI
4. ✅ Configure AWS credentials
5. ✅ Validate SAM template
6. ✅ Build application in container
7. ✅ Deploy to AWS (no confirmation required)
8. ✅ Extract stack outputs
9. ✅ Upload artifacts

**Outputs:**
- API Endpoint URL
- Cognito User Pool ID
- Cognito Client ID

### Job 2: Test

**Duration:** ~2-3 minutes

**Dependencies:** Runs only after successful deployment

Steps:
1. ✅ Checkout code
2. ✅ Set up Python
3. ✅ Install test dependencies
4. ✅ Configure AWS credentials
5. ✅ Create temporary test user in Cognito
6. ✅ Authenticate and get JWT token
7. ✅ Run comprehensive API test suite
8. ✅ Test individual endpoints:
   - Authentication (unauthorized)
   - Photo upload
   - Photo listing
   - Photo metadata
   - Photo retrieval
   - Photo update
   - Photo deletion
9. ✅ Cleanup test user
10. ✅ Generate test report

**Test Coverage:**
- Authentication and authorization
- All CRUD operations
- Presigned URL generation
- Error handling
- CORS headers
- Input validation

## Viewing Results

### GitHub Actions UI

1. Go to **Actions** tab
2. Click on latest workflow run
3. View:
   - Overall status (✅ success / ❌ failure)
   - Individual job logs
   - Test summary
   - Deployment artifacts

### README Badge

The deployment status badge in README.md shows:
- 🟢 Green: All tests passing
- 🔴 Red: Deployment or tests failed
- 🟡 Yellow: Workflow running

### Test Report

After each run, check the workflow summary for:
- API endpoint URL
- Test coverage details
- Individual test results
- Execution time

## Manual Workflow Trigger

To deploy without pushing code:

1. Go to **Actions** tab
2. Click **Deploy and Test Photo HQ API** workflow
3. Click **Run workflow** button
4. Select branch (usually `main`)
5. Click **Run workflow**

Use cases:
- Re-deploy after AWS console changes
- Test workflow changes
- Deploy specific branch

## Troubleshooting

### ❌ Authentication Failed

**Error:** `Unable to locate credentials`

**Solution:**
1. Verify AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set in GitHub Secrets
2. Check for typos in secret names
3. Ensure IAM user still exists and keys are active

### ❌ Insufficient Permissions

**Error:** `User: ... is not authorized to perform: ...`

**Solution:**
1. Review IAM permissions for the user
2. Add missing permissions from the policy above
3. Wait 1-2 minutes for IAM changes to propagate

### ❌ Stack Already Exists

**Error:** `Stack [...] already exists`

**Solution:**
1. Change `STACK_NAME` in workflow env variables
2. Or delete existing stack in AWS CloudFormation console
3. Re-run workflow

### ❌ S3 Bucket Name Conflict

**Error:** `Bucket name already exists`

**Solution:**
S3 buckets have globally unique names. The workflow uses `--resolve-s3` which should auto-generate unique names. If this fails:
1. Delete old S3 buckets from previous deployments
2. Change the stack name to generate new bucket names

### ❌ Tests Failing

**Error:** API tests return 4xx/5xx errors

**Solution:**
1. Check API Gateway logs in CloudWatch
2. Verify Lambda functions deployed correctly
3. Check Cognito user pool configuration
4. Review test user creation logs

### ⚠️ Slow Deployment

**Normal:** SAM deployment takes 3-5 minutes

If longer:
1. Check AWS region health status
2. Review CloudFormation events for stuck resources
3. Verify no manual changes in AWS console conflict with stack

## Advanced Configuration

### Multiple Environments

Deploy to dev, staging, and prod:

1. Create separate workflows or use matrix strategy:
```yaml
strategy:
  matrix:
    environment: [dev, staging, prod]
```

2. Use environment-specific secrets:
```yaml
env:
  STACK_NAME: photo-hq-${{ matrix.environment }}
```

### Custom Stack Parameters

Modify workflow to pass parameters:
```yaml
- name: Deploy to AWS
  run: |
    sam deploy \
      --stack-name ${{ env.STACK_NAME }} \
      --parameter-overrides \
        Environment=${{ matrix.environment }} \
        AlertEmail=${{ secrets.ALERT_EMAIL }}
```

### Notifications

Add Slack/Email notifications:
```yaml
- name: Notify on failure
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## GitHub OIDC (Keyless Authentication)

For enhanced security, replace access keys with OIDC:

### 1. Create IAM OIDC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role

Create role with this trust policy:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

### 3. Update Workflow

Replace credentials step:
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::YOUR_ACCOUNT_ID:role/GitHubActionsRole
    aws-region: ${{ env.AWS_REGION }}
```

### 4. Remove Secrets

Delete AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY from GitHub Secrets.

## Best Practices

✅ **Test locally first** with `sam build && sam deploy`
✅ **Use separate AWS accounts** for dev/prod
✅ **Enable branch protection** on main branch
✅ **Review logs** after each deployment
✅ **Set up CloudWatch alarms** for production
✅ **Tag deployments** with version numbers
✅ **Keep workflow file updated** with new dependencies
✅ **Document infrastructure changes** in commits

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS SAM CLI Reference](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-command-reference.html)
- [GitHub OIDC Guide](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

## Support

For issues:
1. Check workflow logs in GitHub Actions
2. Review CloudWatch logs for Lambda errors
3. Verify AWS credentials and permissions
4. Check this documentation for solutions
5. Open GitHub issue with error details
