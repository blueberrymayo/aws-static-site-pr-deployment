# GitHub Actions Configuration Guide

This guide covers setting up GitHub Actions, secrets, and variables for your PR deployment workflow.

## 🔐 Step 1: Repository Secrets Configuration

### 1.1 Access Repository Settings

1. Go to your GitHub repository
2. Click **Settings** tab
3. Navigate to **Secrets and variables** → **Actions**

### 1.2 Add Required Secrets

Click **New repository secret** for each of the following:

#### AWS Credentials
- **Name**: `AWS_ACCESS_KEY_ID`
  - **Value**: Access key from your IAM user
  - **Description**: AWS access key for deployment

- **Name**: `AWS_SECRET_ACCESS_KEY`
  - **Value**: Secret key from your IAM user
  - **Description**: AWS secret key for deployment

## 📊 Step 2: Repository Variables Configuration

### 2.1 Add Required Variables

Click **New repository variable** for each of the following:

#### AWS Configuration
- **Name**: `AWS_REGION`
  - **Value**: `us-east-1`
  - **Description**: AWS region for resources

- **Name**: `S3_BUCKET_NAME`
  - **Value**: `your-project-bucket`
  - **Description**: S3 bucket name for hosting

- **Name**: `CLOUDFRONT_DISTRIBUTION_ID`
  - **Value**: `E1234567890ABC`
  - **Description**: CloudFront distribution ID

#### Project Configuration
- **Name**: `DOMAIN`
  - **Value**: `yourdomain.com`
  - **Description**: Your project domain name

- **Name**: `BUILD_COMMAND`
  - **Value**: `npm run build`
  - **Description**: Command to build your project

- **Name**: `BUILD_DIR`
  - **Value**: `./build`
  - **Description**: Directory containing built files

## 🔧 Step 3: Workflow Configuration

### 3.1 Verify Workflow Files

Ensure these files exist in your repository:

```
.github/
├── workflows/
│   ├── pr-deploy.yml              # PR deployment
│   ├── deploy.yml                 # Production deployment
│   ├── pr-test-on-comment.yml     # E2E testing
│   ├── pr-cleanup.yml            # Cleanup old PRs
│   └── prevent-push-main.yml     # Enforce PR workflow
└── actions/
    └── cypress-test/
        └── action.yml             # Reusable test action
```

### 3.2 Customize Workflow Files

Update workflow files with your project-specific settings:

#### PR Deploy Workflow
```yaml
# .github/workflows/pr-deploy.yml
- name: Build the app
  run: ${{ vars.BUILD_COMMAND || 'npm run build' }}

- name: Deploy PR to S3 and invalidate CloudFront
  run: |
    BUILD_DIR="${{ vars.BUILD_DIR || './build' }}"
    aws s3 sync ${BUILD_DIR} s3://${{ vars.S3_BUCKET_NAME }}/${PR_FOLDER_NAME} --delete
```

#### Production Deploy Workflow
```yaml
# .github/workflows/deploy.yml
- name: Deploy to S3 production folder
  run: |
    BUILD_DIR="${{ vars.BUILD_DIR || './build' }}"
    aws s3 sync ${BUILD_DIR} s3://${{ vars.S3_BUCKET_NAME }}/production --delete
```

## 🧪 Step 4: Testing Configuration

### 4.1 Install Cypress

```bash
npm install --save-dev cypress
```

### 4.2 Create Cypress Configuration

```javascript
// cypress.config.js
import { defineConfig } from 'cypress'

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:4173',
    supportFile: 'tests/support/e2e.js',
    specPattern: 'tests/e2e/**/*.cy.js',
    videosFolder: 'tests/videos',
    screenshotsFolder: 'tests/screenshots',
    video: true,
    screenshotOnRunFailure: true,
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    responseTimeout: 10000
  }
})
```

### 4.3 Create Test Files

```
tests/
├── e2e/
│   ├── homepage.cy.js
│   ├── navigation.cy.js
│   └── blog.cy.js
├── support/
│   ├── commands.js
│   └── e2e.js
└── fixtures/
    └── test-data.json
```

### 4.4 Update Package.json Scripts

```json
{
  "scripts": {
    "test:e2e": "cypress run",
    "test:e2e:dev": "cypress open",
    "test:e2e:prod": "cypress run --config baseUrl=https://yourdomain.com"
  }
}
```

## 🚀 Step 5: Test Your Setup

### 5.1 Create Test PR

```bash
# Create test branch
git checkout -b test-pr-deployment

# Make a small change
echo "Test PR deployment" > test-file.txt
git add test-file.txt
git commit -m "Test PR deployment setup"
git push origin test-pr-deployment

# Create PR on GitHub
```

### 5.2 Verify PR Deployment

1. **Check Actions Tab**: Verify PR deploy workflow runs successfully
2. **Check PR Comment**: Look for deployment comment with preview URL
3. **Test Preview URL**: Visit the PR preview site
4. **Test E2E**: Comment "please test" on the PR

### 5.3 Verify Production Deployment

1. **Merge PR**: This should trigger production deployment
2. **Check Production Site**: Verify your main site works
3. **Check E2E Tests**: Verify production tests run automatically

## 🔍 Step 6: Monitoring and Debugging

### 6.1 Check Workflow Logs

1. Go to **Actions** tab in your repository
2. Click on a workflow run
3. Click on individual job steps to see logs
4. Look for any error messages or warnings

### 6.2 Common Issues and Solutions

#### Build Failures
```yaml
# Check if build command is correct
- name: Build the app
  run: ${{ vars.BUILD_COMMAND || 'npm run build' }}
```

#### AWS Permission Errors
- Verify IAM user has correct permissions
- Check AWS credentials in repository secrets
- Ensure S3 bucket name and CloudFront distribution ID are correct

#### Test Failures
- Check if Cypress is installed
- Verify test files exist and are valid
- Check base URL configuration

#### CloudFront Invalidation Issues
- Verify CloudFront distribution ID is correct
- Check AWS permissions for CloudFront operations
- Wait for invalidation to complete (can take 5-15 minutes)

### 6.3 Debug Commands

Add debug steps to workflows:

```yaml
- name: Debug information
  run: |
    echo "Build command: ${{ vars.BUILD_COMMAND }}"
    echo "Build directory: ${{ vars.BUILD_DIR }}"
    echo "S3 bucket: ${{ vars.S3_BUCKET_NAME }}"
    echo "CloudFront ID: ${{ vars.CLOUDFRONT_DISTRIBUTION_ID }}"
```

## 🔒 Step 7: Security Best Practices

### 7.1 IAM Permissions

Use least privilege principle:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-specific-bucket",
        "arn:aws:s3:::your-specific-bucket/*"
      ]
    }
  ]
}
```

### 7.2 Secret Rotation

- Rotate AWS access keys regularly
- Use temporary credentials when possible
- Monitor access logs for suspicious activity

### 7.3 Branch Protection

Set up branch protection rules:

1. Go to **Settings** → **Branches**
2. Add rule for `main` branch
3. Enable:
   - Require pull request reviews
   - Require status checks to pass
   - Require branches to be up to date

## 📊 Step 8: Workflow Optimization

### 8.1 Caching Dependencies

```yaml
- name: Cache node modules
  uses: actions/cache@v3
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

### 8.2 Parallel Jobs

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Build
        run: npm run build

  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test
        run: npm test
```

### 8.3 Conditional Steps

```yaml
- name: Deploy only on main branch
  if: github.ref == 'refs/heads/main'
  run: npm run deploy
```

## ✅ Verification Checklist

Before considering setup complete:

- [ ] All repository secrets configured
- [ ] All repository variables configured
- [ ] Workflow files present and customized
- [ ] Cypress installed and configured
- [ ] Test files created and working
- [ ] PR deployment workflow successful
- [ ] Production deployment workflow successful
- [ ] E2E testing workflow successful
- [ ] Branch protection rules enabled
- [ ] Monitoring and alerting configured

## 🎉 You're Ready!

Your GitHub Actions setup is complete! You now have:

- 🔀 Automated PR preview deployments
- 🏗️ Production deployment pipeline
- 🧪 E2E testing with comment triggers
- 🔒 Secure credential management
- 📊 Comprehensive monitoring

Your PR deployment system is ready to use! 🚀
