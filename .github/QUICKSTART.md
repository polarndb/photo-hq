# Quick Start - GitHub Actions CI/CD

Get your automated deployment running in 5 minutes!

## Step 1: Add GitHub Secrets (2 minutes)

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add these secrets:

| Name | Value |
|------|-------|
| `AWS_ACCESS_KEY_ID` | Your IAM access key (from AWS Console) |
| `AWS_SECRET_ACCESS_KEY` | Your IAM secret key (from AWS Console) |
| `AWS_REGION` | `us-east-1` (or your preferred region) |

**Need to create IAM credentials?** See [CI_CD_SETUP.md](../CI_CD_SETUP.md) for detailed instructions.

## Step 2: Push to Main Branch (1 minute)

```bash
git add .
git commit -m "Add GitHub Actions CI/CD workflow"
git push origin main
```

## Step 3: Watch It Deploy! (5-8 minutes)

1. Go to **Actions** tab in your GitHub repository
2. Click on the running workflow
3. Watch the deployment and tests in real-time
4. ✅ Green checkmark = Success!

## Step 4: Verify Deployment

- Check the badge in README.md (should be green)
- View API endpoint in workflow logs
- Test API manually (optional)

## That's It! 🎉

Your API is now:
- ✅ Automatically deployed on every push to main
- ✅ Comprehensively tested (8+ test scenarios)
- ✅ Ready for production use

## What Just Happened?

The workflow:
1. Built your SAM application
2. Deployed to AWS (Lambda, API Gateway, S3, DynamoDB, Cognito)
3. Created a test user
4. Tested all 7 API endpoints
5. Cleaned up test data
6. Generated a test report

## Need Help?

- **Setup Guide**: [CI_CD_SETUP.md](../CI_CD_SETUP.md)
- **Quick Reference**: [WORKFLOW_REFERENCE.md](WORKFLOW_REFERENCE.md)
- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Troubleshooting**: [CI_CD_SETUP.md](../CI_CD_SETUP.md#troubleshooting)

## Manual Trigger

To deploy without pushing code:
1. Go to **Actions** tab
2. Select **Deploy and Test Photo HQ API**
3. Click **Run workflow**
4. Select branch and click **Run workflow**

---

**Next**: Review [CI_CD_SETUP.md](../CI_CD_SETUP.md) for advanced configuration and troubleshooting.
