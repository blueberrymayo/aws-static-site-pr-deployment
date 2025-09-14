# Troubleshooting Guide

This guide helps you resolve common issues with AWS Static Site PR Deployment.

## 🚨 Common Issues

### PR Deployment Issues

#### Issue: PR site not accessible after deployment

**Symptoms:**
- PR deploy workflow completes successfully
- PR comment shows preview URL
- Preview URL returns 404 or error

**Solutions:**
1. **Check CloudFront invalidation status**:
   ```bash
   aws cloudfront list-invalidations --distribution-id YOUR_DISTRIBUTION_ID
   ```

2. **Verify S3 folder exists**:
   ```bash
   aws s3 ls s3://YOUR_BUCKET_NAME/pr-123/
   ```

3. **Wait for propagation**:
   - CloudFront cache invalidation can take 5-15 minutes
   - Global CDN propagation may take longer

4. **Check CloudFront function**:
   - Verify `SubdomainFolders.js` function is associated
   - Test function in CloudFront console

#### Issue: Build failures in PR deployment

**Symptoms:**
- GitHub Actions workflow fails at build step
- Error messages about missing dependencies or build commands

**Solutions:**
1. **Check build command**:
   ```yaml
   # Verify in GitHub repository variables
   BUILD_COMMAND=npm run build
   ```

2. **Verify package.json scripts**:
   ```json
   {
     "scripts": {
       "build": "your-build-command"
     }
   }
   ```

3. **Check Node.js version compatibility**:
   ```yaml
   # In workflow files
   - name: Set up Node.js
     uses: actions/setup-node@v4
     with:
       node-version: '18'  # Match your project's version
   ```

4. **Add missing dependencies**:
   ```bash
   npm install --save-dev missing-package
   ```

#### Issue: AWS permission errors

**Symptoms:**
- Workflow fails with "Access Denied" errors
- S3 upload or CloudFront invalidation fails

**Solutions:**
1. **Check IAM user permissions**:
   ```bash
   aws iam get-user-policy --user-name github-actions-deploy --policy-name DeployPolicy
   ```

2. **Verify AWS credentials**:
   - Check repository secrets are correct
   - Ensure access keys are not expired

3. **Update IAM policy**:
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
           "arn:aws:s3:::YOUR_BUCKET_NAME",
           "arn:aws:s3:::YOUR_BUCKET_NAME/*"
         ]
       }
     ]
   }
   ```

### Production Deployment Issues

#### Issue: Production site not updating after merge

**Symptoms:**
- PR merge completes successfully
- Production deploy workflow runs
- Main site still shows old content

**Solutions:**
1. **Check CloudFront invalidation**:
   ```bash
   aws cloudfront list-invalidations --distribution-id YOUR_DISTRIBUTION_ID
   ```

2. **Verify S3 production folder**:
   ```bash
   aws s3 ls s3://YOUR_BUCKET_NAME/production/
   ```

3. **Check deployment workflow logs**:
   - Go to Actions tab
   - Check for any error messages
   - Verify all steps completed successfully

4. **Manual invalidation**:
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id YOUR_DISTRIBUTION_ID \
     --paths "/production/*"
   ```

#### Issue: Production deployment workflow fails

**Symptoms:**
- Merge to main triggers deployment
- Workflow fails with various errors

**Solutions:**
1. **Check branch protection rules**:
   - Verify `prevent-push-main.yml` isn't blocking deployment
   - Check if required status checks are passing

2. **Verify workflow triggers**:
   ```yaml
   # In .github/workflows/deploy.yml
   on:
     push:
       branches:
         - main  # Ensure this matches your default branch
   ```

3. **Check for workflow conflicts**:
   - Ensure only one deployment workflow runs at a time
   - Check for overlapping triggers

### Testing Issues

#### Issue: E2E tests failing on PR

**Symptoms:**
- Comment "please test" triggers workflow
- Tests fail with various errors
- PR shows test failure status

**Solutions:**
1. **Check test files exist**:
   ```bash
   ls -la tests/e2e/
   ```

2. **Verify Cypress configuration**:
   ```javascript
   // cypress.config.js
   export default defineConfig({
     e2e: {
       baseUrl: 'http://localhost:4173',
       // ... other config
     }
   })
   ```

3. **Check base URL for deployed tests**:
   ```yaml
   # In pr-test-on-comment.yml
   - name: Run E2E tests against deployed PR
     uses: ./.github/actions/cypress-test
     with:
       base-url: 'https://pr-${{ fromJson(steps.pr.outputs.result).number }}.${{ vars.DOMAIN }}'
   ```

4. **Update test commands**:
   ```json
   {
     "scripts": {
       "test:e2e": "cypress run",
       "test:e2e:dev": "cypress open"
     }
   }
   ```

#### Issue: Tests not triggering on PR comment

**Symptoms:**
- Comment "please test" on PR
- No workflow triggered
- No response from bot

**Solutions:**
1. **Check comment trigger conditions**:
   ```yaml
   # In pr-test-on-comment.yml
   if: >
     github.event.issue.pull_request &&
     (
       contains(github.event.comment.body, 'please test') ||
       contains(github.event.comment.body, 'run tests')
     )
   ```

2. **Verify repository permissions**:
   - Go to repository Settings → Actions → General
   - Ensure "Read and write permissions" is enabled

3. **Check workflow file syntax**:
   - Validate YAML syntax
   - Ensure proper indentation

### CloudFront Issues

#### Issue: Subdomain routing not working

**Symptoms:**
- `pr-123.yourdomain.com` doesn't work
- All subdomains redirect to production
- Error pages not showing correctly

**Solutions:**
1. **Check CloudFront function**:
   ```bash
   aws cloudfront get-function --name SubdomainFolders
   ```

2. **Verify function association**:
   - Go to CloudFront console
   - Check Behaviors tab
   - Ensure function is associated with Viewer Request

3. **Test function logic**:
   ```javascript
   // Test in CloudFront console
   function handler(event) {
     var request = event.request;
     var host = request.headers.host.value;
     console.log("Host:", host);
     // ... rest of function
   }
   ```

4. **Check error page configuration**:
   - Verify 403 → /error.html mapping
   - Ensure error.html is uploaded to S3 root

#### Issue: SSL certificate errors

**Symptoms:**
- "Not Secure" warning in browser
- SSL certificate errors
- Subdomains not working with HTTPS

**Solutions:**
1. **Check certificate status**:
   ```bash
   aws acm describe-certificate --certificate-arn YOUR_CERT_ARN --region us-east-1
   ```

2. **Verify DNS validation**:
   - Check DNS records are correctly added
   - Wait for DNS propagation (up to 48 hours)

3. **Check certificate coverage**:
   - Ensure certificate covers `yourdomain.com` and `*.yourdomain.com`
   - Verify certificate is in `us-east-1` region

4. **Update CloudFront distribution**:
   - Ensure certificate ARN is correctly configured
   - Check alternate domain names are set

### General Issues

#### Issue: Workflow not triggering

**Symptoms:**
- Push to main doesn't trigger deployment
- PR creation doesn't trigger preview
- No workflows running

**Solutions:**
1. **Check workflow file location**:
   - Ensure files are in `.github/workflows/`
   - Verify file extensions are `.yml` or `.yaml`

2. **Check workflow syntax**:
   ```yaml
   # Basic workflow structure
   name: Workflow Name
   on:
     push:
       branches: [main]
   jobs:
     job-name:
       runs-on: ubuntu-latest
       steps:
         - name: Step name
           run: command
   ```

3. **Verify repository settings**:
   - Go to Settings → Actions → General
   - Ensure Actions are enabled
   - Check workflow permissions

4. **Check branch names**:
   - Ensure workflow triggers match your branch names
   - Default branch might be `master` instead of `main`

#### Issue: Slow deployments

**Symptoms:**
- Deployments take a long time
- CloudFront invalidations are slow
- Overall workflow duration is high

**Solutions:**
1. **Optimize build process**:
   ```yaml
   - name: Cache dependencies
     uses: actions/cache@v3
     with:
       path: ~/.npm
       key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
   ```

2. **Use faster runners**:
   ```yaml
   jobs:
     deploy:
       runs-on: ubuntu-latest  # Consider ubuntu-20.04 or ubuntu-22.04
   ```

3. **Optimize CloudFront settings**:
   - Adjust cache behaviors
   - Use appropriate TTL values
   - Consider using CloudFront functions instead of Lambda@Edge

4. **Parallelize jobs**:
   ```yaml
   jobs:
     build:
       runs-on: ubuntu-latest
     test:
       runs-on: ubuntu-latest
     deploy:
       needs: [build, test]
       runs-on: ubuntu-latest
   ```

## 🔍 Debugging Tools

### GitHub Actions Debugging

```yaml
# Add debug steps to workflows
- name: Debug information
  run: |
    echo "Repository: ${{ github.repository }}"
    echo "Ref: ${{ github.ref }}"
    echo "Event: ${{ github.event_name }}"
    echo "Actor: ${{ github.actor }}"
```

### AWS CLI Debugging

```bash
# Check S3 bucket contents
aws s3 ls s3://YOUR_BUCKET_NAME --recursive

# Check CloudFront distribution
aws cloudfront get-distribution --id YOUR_DISTRIBUTION_ID

# Check recent invalidations
aws cloudfront list-invalidations --distribution-id YOUR_DISTRIBUTION_ID --max-items 5

# Test S3 website endpoint
curl -I http://YOUR_BUCKET_NAME.s3-website-us-east-1.amazonaws.com/
```

### CloudFront Function Debugging

```javascript
// Add logging to function
function handler(event) {
    var request = event.request;
    console.log("Request URI:", request.uri);
    console.log("Host header:", request.headers.host.value);

    // ... rest of function

    console.log("Modified URI:", request.uri);
    return request;
}
```

## 📞 Getting Help

### Before Asking for Help

1. **Check the logs**: Look at GitHub Actions logs for error messages
2. **Verify configuration**: Double-check all settings and variables
3. **Test locally**: Try to reproduce issues locally
4. **Search existing issues**: Check if others have encountered the same problem

### When Reporting Issues

Include the following information:

1. **Error messages**: Copy the exact error text
2. **Workflow logs**: Link to failed workflow run
3. **Configuration**: Your setup (domain, framework, etc.)
4. **Steps to reproduce**: What you did before the error
5. **Expected behavior**: What should have happened
6. **Actual behavior**: What actually happened

### Resources

- **GitHub Actions Documentation**: https://docs.github.com/en/actions
- **AWS CloudFront Documentation**: https://docs.aws.amazon.com/cloudfront/
- **Cypress Documentation**: https://docs.cypress.io/
- **Template Repository Issues**: Open an issue in this repository

## ✅ Quick Health Check

Run this checklist to verify your setup:

```bash
# Check GitHub Actions
gh workflow list

# Check AWS resources
aws s3 ls s3://YOUR_BUCKET_NAME
aws cloudfront list-distributions
aws acm list-certificates --region us-east-1

# Check local setup
npm run build
npm run test:e2e:dev
```

If all checks pass, your setup should be working correctly! 🎉
