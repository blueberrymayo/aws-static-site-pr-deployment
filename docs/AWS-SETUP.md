# AWS Infrastructure Setup Guide

This guide provides detailed instructions for setting up the AWS infrastructure required for PR deployment.

## 🏗️ Architecture Overview

```
GitHub Actions → S3 Bucket → CloudFront → Users
                    ↓
              Subdomain Routing
              (pr-123.domain.com)
```

## 📋 Prerequisites

- AWS Account with appropriate permissions
- Domain name with DNS control
- AWS CLI installed (optional but recommended)

## 🪣 Step 1: S3 Bucket Setup

### 1.1 Create S3 Bucket

```bash
# Replace 'your-project-bucket' with your desired bucket name
BUCKET_NAME="your-project-bucket"

# Create the bucket
aws s3 mb s3://$BUCKET_NAME

# Enable versioning (optional but recommended)
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled
```

### 1.2 Configure Static Website Hosting

```bash
# Enable static website hosting
aws s3 website s3://$BUCKET_NAME \
  --index-document index.html \
  --error-document error.html
```

### 1.3 Set Bucket Policy for Public Access

Create a bucket policy file:

```bash
cat > bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF

# Apply the policy
aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file://bucket-policy.json
```

### 1.4 Disable Block Public Access

```bash
# Remove public access block
aws s3api delete-public-access-block --bucket $BUCKET_NAME
```

## 🔒 Step 2: SSL Certificate Setup

### 2.1 Request Certificate

```bash
# Request certificate for your domain and wildcard
aws acm request-certificate \
  --domain-name yourdomain.com \
  --subject-alternative-names "*.yourdomain.com" \
  --validation-method DNS \
  --region us-east-1
```

**Important**: The certificate must be in the `us-east-1` region for CloudFront.

### 2.2 Validate Certificate

1. **Check certificate status**:
   ```bash
   aws acm list-certificates --region us-east-1
   ```

2. **Get validation records**:
   ```bash
   CERT_ARN="arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
   aws acm describe-certificate \
     --certificate-arn $CERT_ARN \
     --region us-east-1
   ```

3. **Add DNS records** to your domain's DNS settings as shown in the certificate validation output.

4. **Wait for validation** (can take up to 30 minutes).

## ☁️ Step 3: CloudFront Distribution Setup

### 3.1 Create CloudFront Distribution

Create a distribution configuration file:

```bash
cat > cloudfront-config.json << EOF
{
  "CallerReference": "your-project-$(date +%s)",
  "Comment": "PR deployment distribution for yourdomain.com",
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-$BUCKET_NAME",
        "DomainName": "$BUCKET_NAME.s3-website-us-east-1.amazonaws.com",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 1,
            "Items": ["TLSv1.2"]
          }
        }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-$BUCKET_NAME",
    "ViewerProtocolPolicy": "redirect-to-https",
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000
  },
  "Aliases": {
    "Quantity": 2,
    "Items": [
      "yourdomain.com",
      "*.yourdomain.com"
    ]
  },
  "DefaultRootObject": "index.html",
  "PriceClass": "PriceClass_100",
  "Enabled": true,
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 403,
        "ResponsePagePath": "/error.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 0
      }
    ]
  }
}
EOF
```

### 3.2 Create the Distribution

```bash
# Create the distribution
aws cloudfront create-distribution \
  --distribution-config file://cloudfront-config.json
```

**Note**: This will return a distribution ID. Save this for later use.

### 3.3 Update Distribution with SSL Certificate

After the certificate is validated, update the distribution:

```bash
DISTRIBUTION_ID="E1234567890ABC"  # From the previous step
CERT_ARN="arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"

# Get current distribution config
aws cloudfront get-distribution-config --id $DISTRIBUTION_ID > current-config.json

# Update with certificate ARN (you'll need to edit the JSON manually)
# Add the certificate ARN to the ViewerCertificate section
```

## 🔧 Step 4: CloudFront Function Setup

### 4.1 Create the Function

```bash
# Create the function
aws cloudfront create-function \
  --name SubdomainFolders \
  --function-config Comment="Routes subdomains to S3 folders",Runtime=cloudfront-js-1.0 \
  --function-code file://.cloudfront/functions/SubdomainFolders.js
```

### 4.2 Associate Function with Distribution

```bash
# Get function ARN
FUNCTION_ARN=$(aws cloudfront get-function --name SubdomainFolders --query 'ETag' --output text)

# Update distribution behavior to include function
# This requires updating the distribution configuration
```

## 🔐 Step 5: IAM Setup for GitHub Actions

### 5.1 Create IAM User

```bash
# Create user for GitHub Actions
aws iam create-user --user-name github-actions-deploy

# Create access keys
aws iam create-access-key --user-name github-actions-deploy
```

### 5.2 Create IAM Policy

```bash
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
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
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
```

## 🌐 Step 6: DNS Configuration

### 6.1 Configure Domain DNS

Add these DNS records to your domain:

```
# A record for root domain
yourdomain.com.    A    <CloudFront-IP>
yourdomain.com.    AAAA <CloudFront-IPv6>

# CNAME for wildcard subdomain
*.yourdomain.com.  CNAME <CloudFront-Domain>
```

### 6.2 Get CloudFront Domain

```bash
# Get CloudFront distribution domain
aws cloudfront get-distribution --id $DISTRIBUTION_ID \
  --query 'Distribution.DomainName' --output text
```

## 📊 Step 7: Monitoring and Logging

### 7.1 Enable CloudFront Logging (Optional)

```bash
# Create S3 bucket for logs
aws s3 mb s3://your-project-logs

# Enable logging in CloudFront distribution
# This needs to be done via the console or by updating the distribution config
```

### 7.2 Set up CloudWatch Alarms (Optional)

```bash
# Create alarm for high error rates
aws cloudwatch put-metric-alarm \
  --alarm-name "CloudFront-High-Error-Rate" \
  --alarm-description "Alert when CloudFront error rate is high" \
  --metric-name 4xxErrorRate \
  --namespace AWS/CloudFront \
  --statistic Average \
  --period 300 \
  --threshold 5.0 \
  --comparison-operator GreaterThanThreshold
```

## 🧪 Step 8: Testing Your Setup

### 8.1 Test S3 Access

```bash
# Upload a test file
echo "Hello World" > test.html
aws s3 cp test.html s3://$BUCKET_NAME/test.html

# Test direct S3 access
curl http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com/test.html
```

### 8.2 Test CloudFront

```bash
# Test CloudFront access
curl -I https://yourdomain.com/test.html

# Test subdomain routing (after PR deployment)
curl -I https://pr-123.yourdomain.com/test.html
```

### 8.3 Test SSL Certificate

```bash
# Test SSL certificate
openssl s_client -connect yourdomain.com:443 -servername yourdomain.com

# Test wildcard certificate
openssl s_client -connect pr-123.yourdomain.com:443 -servername pr-123.yourdomain.com
```

## 🚨 Troubleshooting

### Common Issues

**Certificate validation fails:**
- Check DNS records are correctly added
- Wait up to 30 minutes for propagation
- Verify domain ownership

**CloudFront not serving content:**
- Check origin configuration
- Verify S3 bucket policy
- Check custom error pages configuration

**Subdomain routing not working:**
- Verify CloudFront function is associated
- Check function code is correct
- Test function in CloudFront console

**Access denied errors:**
- Check S3 bucket permissions
- Verify IAM user permissions
- Check CloudFront origin access

### Debugging Commands

```bash
# Check S3 bucket status
aws s3api head-bucket --bucket $BUCKET_NAME

# Check CloudFront distribution status
aws cloudfront get-distribution --id $DISTRIBUTION_ID

# Check certificate status
aws acm describe-certificate --certificate-arn $CERT_ARN --region us-east-1

# List CloudFront invalidations
aws cloudfront list-invalidations --distribution-id $DISTRIBUTION_ID
```

## ✅ Verification Checklist

Before proceeding to GitHub setup:

- [ ] S3 bucket created and configured
- [ ] SSL certificate requested and validated
- [ ] CloudFront distribution created
- [ ] CloudFront function created and associated
- [ ] DNS records configured
- [ ] IAM user and policy created
- [ ] Test files accessible via CloudFront
- [ ] SSL certificate working
- [ ] Error pages configured

## 📚 Next Steps

After completing AWS setup:

1. **Configure GitHub Actions** (see [GITHUB-SETUP.md](GITHUB-SETUP.md))
2. **Test PR deployment** workflow
3. **Set up monitoring** and alerting
4. **Configure custom domains** if needed

## 💰 Cost Considerations

**S3 Storage**: ~$0.023 per GB per month
**CloudFront**: ~$0.085 per GB transfer + $0.0075 per 10,000 requests
**SSL Certificate**: Free with AWS Certificate Manager
**CloudFront Function**: Free (first 2M requests per month)

Estimated monthly cost for small to medium sites: $1-10
