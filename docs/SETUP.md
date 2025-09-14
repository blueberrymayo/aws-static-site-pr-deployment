# Complete Setup Guide

This guide will walk you through setting up AWS Static Site PR Deployment for your project from start to finish.

## 🎯 Overview

By the end of this setup, you'll have:
- ✅ Automated PR preview deployments
- ✅ Production deployment on merge
- ✅ E2E testing with Cypress
- ✅ AWS S3 + CloudFront infrastructure
- ✅ GitHub Actions workflows

## 📋 Prerequisites

Before you begin, ensure you have:

- [ ] **AWS Account** with appropriate permissions
- [ ] **Domain name** with SSL certificate capability
- [ ] **GitHub repository** with Actions enabled
- [ ] **Node.js project** with build command
- [ ] **AWS CLI** installed and configured (optional but helpful)

## 🚀 Step 1: Install Deployment Infrastructure

### Option A: Use the Setup Script (Recommended)

```bash
# Clone or download this template repository
git clone https://github.com/artificer-innovations/aws-static-site-pr-deployment.git template
cd template

# Run the installer on your project
./setup-scripts/install-deployment.sh /path/to/your/project
```

### Option B: Manual Installation

```bash
# Copy files to your project
cp -r .github /path/to/your/project/
cp -r .cloudfront /path/to/your/project/
cp setup-scripts/install-deployment.sh /path/to/your/project/

# Customize the files manually
```

## 🏗️ Step 2: AWS Infrastructure Setup

### 2.1 Create S3 Bucket

```bash
# Create the bucket
aws s3 mb s3://your-project-bucket

# Enable static website hosting
aws s3 website s3://your-project-bucket \
  --index-document index.html \
  --error-document error.html
```

### 2.2 Configure Bucket Policy

Create a bucket policy to allow public read access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::your-project-bucket/*"
    }
  ]
}
```

### 2.3 Request SSL Certificate

```bash
# Request certificate for your domain and wildcard
aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names "*.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1
```

**Important**: The certificate must be in `us-east-1` region for CloudFront.

### 2.4 Create CloudFront Distribution

1. **Go to CloudFront Console**
2. **Create Distribution**
3. **Configure Origin**:
   - Origin Domain: `your-project-bucket.s3-website-us-east-1.amazonaws.com`
   - Origin Path: (leave empty)
   - Origin Access: Public

4. **Configure Default Cache Behavior**:
   - Viewer Protocol Policy: Redirect HTTP to HTTPS
   - Cache Policy: Managed-CachingOptimized
   - Origin Request Policy: Managed-CORS-S3Origin

5. **Configure Settings**:
   - Alternate Domain Names: `yourdomain.com`, `*.yourdomain.com`
   - SSL Certificate: Select your ACM certificate
   - Default Root Object: `index.html`

### 2.5 Create CloudFront Function

1. **Go to CloudFront Functions**
2. **Create Function**:
   - Name: `SubdomainFolders`
   - Description: `Routes subdomains to S3 folders`

3. **Copy function code** from `.cloudfront/functions/SubdomainFolders.js`

4. **Publish** the function

### 2.6 Associate Function with Distribution

1. **Go to your CloudFront Distribution**
2. **Behaviors tab** → **Edit** default behavior
3. **Function Associations**:
   - Event Type: Viewer Request
   - Function Type: CloudFront Function
   - Function ARN: Select your `SubdomainFolders` function

### 2.7 Configure Custom Error Pages

1. **Error Pages tab** in CloudFront Distribution
2. **Create Custom Error Response**:
   - HTTP Error Code: 403
   - Error Caching Minimum TTL: 0
   - Customize Error Response: Yes
   - Response Page Path: `/error.html`
   - HTTP Response Code: 200

### 2.8 Upload Error Handler

```bash
# Upload error.html to S3 bucket root
aws s3 cp .cloudfront/error.html s3://your-project-bucket/error.html
```

## 🔐 Step 3: GitHub Configuration

### 3.1 Create IAM User for GitHub Actions

```bash
# Create IAM user
aws iam create-user --user-name github-actions-deploy

# Create policy for deployment
cat > github-actions-policy.json << EOF
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
        "arn:aws:s3:::your-project-bucket",
        "arn:aws:s3:::your-project-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudfront:CreateInvalidation",
        "cloudfront:GetInvalidation",
        "cloudfront:ListInvalidations"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy to user
aws iam put-user-policy \
  --user-name github-actions-deploy \
  --policy-name DeployPolicy \
  --policy-document file://github-actions-policy.json

# Create access keys
aws iam create-access-key --user-name github-actions-deploy
```

### 3.2 Configure GitHub Secrets

Go to your repository **Settings** → **Secrets and variables** → **Actions**

**Add these secrets**:
- `AWS_ACCESS_KEY_ID` - From the access key created above
- `AWS_SECRET_ACCESS_KEY` - From the access key created above

**Add these variables**:
- `AWS_REGION=us-east-1`
- `S3_BUCKET_NAME=your-project-bucket`
- `CLOUDFRONT_DISTRIBUTION_ID=E1234567890ABC` (from CloudFront console)
- `DOMAIN=yourdomain.com`
- `BUILD_COMMAND=npm run build`
- `BUILD_DIR=./build`

## 🧪 Step 4: Configure Testing

### 4.1 Install Cypress (if not already done)

```bash
npm install --save-dev cypress
```

### 4.2 Create Cypress Configuration

The setup script creates a basic `cypress.config.js`. Customize it for your needs:

```javascript
import { defineConfig } from 'cypress'

export default defineConfig({
  e2e: {
    baseUrl: 'http://localhost:4173',
    supportFile: 'tests/support/e2e.js',
    specPattern: 'tests/e2e/**/*.cy.js',
    // Add your custom configuration
  }
})
```

### 4.3 Customize Test Files

Edit the test files in `tests/e2e/` to match your site:

```javascript
// tests/e2e/homepage.cy.js
describe('Homepage', () => {
  it('should load successfully', () => {
    cy.visit('/')
    cy.contains('Your Site Title') // Update for your site
  })
})
```

## 🚀 Step 5: Test Your Setup

### 5.1 Create a Test PR

```bash
# Create a test branch
git checkout -b test-pr-deployment

# Make a small change
echo "Test PR deployment" > test-file.txt
git add test-file.txt
git commit -m "Test PR deployment setup"
git push origin test-pr-deployment

# Create PR on GitHub
```

### 5.2 Verify PR Deployment

1. **Check GitHub Actions**: Go to Actions tab and verify PR deploy workflow runs
2. **Check PR Comment**: Look for the deployment comment with preview URL
3. **Visit Preview URL**: Test the PR preview site
4. **Test E2E Testing**: Comment "please test" on the PR

### 5.3 Test Production Deployment

1. **Merge the PR**: This should trigger production deployment
2. **Check Production Site**: Verify your main site works
3. **Check E2E Tests**: Verify production tests run automatically

## 🔧 Step 6: Customization

### 6.1 Update Build Process

If your project has specific build requirements:

```yaml
# In .github/workflows/pr-deploy.yml
- name: Build the app
  run: |
    npm install
    npm run build:production  # Custom build command
    npm run optimize-assets   # Custom optimization
```

### 6.2 Add Environment Variables

```yaml
# In workflow files
- name: Build with environment
  run: npm run build
  env:
    NODE_ENV: production
    API_URL: ${{ secrets.API_URL }}
```

### 6.3 Customize E2E Tests

Add more comprehensive tests:

```javascript
// tests/e2e/navigation.cy.js
describe('Navigation', () => {
  it('should navigate between pages', () => {
    cy.visit('/')
    cy.get('[data-testid="nav-about"]').click()
    cy.url().should('include', '/about')
  })
})
```

## 🚨 Troubleshooting

### Common Issues

**PR site not accessible:**
- Check CloudFront invalidation status
- Verify S3 folder exists
- Wait 5-15 minutes for global propagation

**Tests failing:**
- Ensure CloudFront invalidation completed
- Check if test files exist and are valid
- Verify base URL configuration

**Build failures:**
- Check build command in GitHub variables
- Verify build directory exists
- Check Node.js version compatibility

### Getting Help

1. **Check the logs** in GitHub Actions
2. **Review documentation** in this repository
3. **Open an issue** if you encounter problems

## ✅ Verification Checklist

Before considering setup complete:

- [ ] PR deployments work (create test PR)
- [ ] Production deployments work (merge PR)
- [ ] E2E tests run successfully
- [ ] CloudFront subdomain routing works
- [ ] SSL certificates are valid
- [ ] Error handling works for invalid subdomains
- [ ] GitHub secrets and variables are configured
- [ ] S3 bucket permissions are correct

## 🎉 You're Done!

Your AWS Static Site PR Deployment setup is complete! You now have:

- 🔀 Automated PR preview environments
- 🏗️ Production deployment pipeline
- 🧪 Comprehensive E2E testing
- ☁️ AWS infrastructure with global CDN
- 📊 Monitoring and error handling

Happy deploying! 🚀
