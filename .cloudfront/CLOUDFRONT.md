# CloudFront Configuration for PR Test Deployments

This document explains how CloudFront is configured to support **dynamic PR test deployments** where each PR gets its own subdomain (e.g., `pr-123.yourdomain.com`) while maintaining the production site at the root domain.

## Overview

Our CloudFront setup enables:
- 🌐 **Production site**: `yourdomain.com` → `/production/` folder
- 🧪 **PR test sites**: `pr-{number}.yourdomain.com` → `/pr-{number}/` folder
- 🔄 **Automatic subdomain routing** via CloudFront function
- 🚨 **Graceful error handling** for missing subdomains/files

## Architecture Components

### 1. S3 Bucket Structure
```
s3://bucket-name/
├── production/          # Main website (yourdomain.com)
│   ├── index.html
│   ├── _app/
│   └── ...
├── pr-123/             # PR #123 test deployment
│   ├── index.html
│   ├── _app/
│   └── ...
├── pr-456/             # PR #456 test deployment
└── error.html          # Global error handler (root level)
```

### 2. CloudFront Distribution
- **SSL Certificate**: `yourdomain.com` and `*.yourdomain.com`
- **Origin**: S3 bucket configured for static website hosting
- **Viewer Request Function**: `functions/SubdomainFolders.js` (subdomain → folder mapping)
- **Custom Error Pages**: 403 → `/error.html` (returns HTTP 200)

### 3. Static Site Configuration
- **Adapter**: Static site generation with fallback to `index.html`
- **Routing**: Client-side routing handles all paths within each deployment
- **Error Handling**: 404s handled by the application within each subdomain

## Request Flow

### Successful Request Flow
```
1. Client: https://pr-123.yourdomain.com/blog
2. CloudFront Viewer Request Function:
   - Detects subdomain: "pr-123"
   - Maps to S3 path: /pr-123/blog
3. S3:
   - File doesn't exist → return 403
4. Static Site Logic:
   - CloudFront serves /pr-123/index.html instead
   - Application handles /blog route client-side
5. Client: Receives rendered blog page
```

### Error Handling Flow
```
1. Client: https://invalid-subdomain.yourdomain.com/
2. CloudFront Viewer Request Function:
   - Maps to: /invalid-subdomain/index.html
3. S3:
   - Path doesn't exist → return 403
4. CloudFront Error Handling:
   - Serves /error.html from root (returns HTTP 200)
5. error.html JavaScript:
   - Analyzes original URL and subdomain
   - Redirects to appropriate error page
```

## CloudFront Function Logic

The Viewer Request Function (`functions/SubdomainFolders.js`) performs:

1. **Subdomain Detection**: Extracts subdomain from request
2. **Path Mapping**: Routes requests to appropriate S3 folder
3. **SPA Support**: Ensures directory requests serve `index.html`

### Subdomain Mapping Examples
- `yourdomain.com/about` → `/production/about`
- `www.yourdomain.com/blog` → `/production/blog`
- `pr-123.yourdomain.com/blog` → `/pr-123/blog`
- `test.yourdomain.com/` → `/test/index.html`

## Setup Instructions

### 1. Create CloudFront Distribution

1. **Go to CloudFront Console**
2. **Create Distribution**
3. **Configure Origin**:
   - Origin Domain: Your S3 bucket static website endpoint
   - Origin Path: (leave empty)
   - Origin Access: Public

4. **Configure Default Cache Behavior**:
   - Viewer Protocol Policy: Redirect HTTP to HTTPS
   - Cache Policy: Managed-CachingOptimized
   - Origin Request Policy: Managed-CORS-S3Origin

5. **Configure Function Associations**:
   - Event Type: Viewer Request
   - Function Type: CloudFront Function
   - Function ARN: (create function first)

### 2. Create CloudFront Function

1. **Go to CloudFront Functions**
2. **Create Function**:
   - Name: `SubdomainFolders`
   - Description: `Routes subdomains to S3 folders`
3. **Copy the function code** from `functions/SubdomainFolders.js`
4. **Publish** the function

### 3. Configure Custom Error Pages

1. **In CloudFront Distribution**:
   - Go to Error Pages tab
   - Create Custom Error Response
   - HTTP Error Code: 403
   - Error Caching Minimum TTL: 0
   - Customize Error Response: Yes
   - Response Page Path: `/error.html`
   - HTTP Response Code: 200

### 4. Upload Error Handler

1. **Upload `error.html`** to your S3 bucket root
2. **Ensure it's publicly accessible**

## Testing Your Setup

### 1. Test Production Site
```bash
curl -I https://yourdomain.com/
# Should return 200 OK
```

### 2. Test PR Subdomain
```bash
curl -I https://pr-123.yourdomain.com/
# Should return 200 OK (if PR-123 exists)
```

### 3. Test Invalid Subdomain
```bash
curl -I https://invalid.yourdomain.com/
# Should return 200 OK with error.html content
```

## Troubleshooting

### Common Issues

**PR site not accessible after deployment:**
- Check CloudFront invalidation status: `aws cloudfront list-invalidations`
- Verify S3 folder exists: `aws s3 ls s3://bucket/pr-{number}/`
- Wait 5-15 minutes for global CDN propagation

**Tests failing on deployed PR:**
- Ensure CloudFront invalidation completed before testing
- Check if subdomain function is working: test direct S3 URLs
- Verify SSL certificate covers `*.yourdomain.com`

**Error page redirects:**
- Check `error.html` JavaScript logic in browser dev tools
- Verify original URL detection is working correctly
- Test both file and directory error scenarios

### Debugging Commands
```bash
# Check CloudFront invalidations
aws cloudfront list-invalidations --distribution-id DISTRIBUTION_ID

# Test S3 direct access
curl -I https://s3.region.amazonaws.com/bucket/pr-123/index.html

# Test CloudFront function
curl -I https://pr-123.yourdomain.com/
```

## Security Considerations

- **SSL Certificate**: Must cover both root domain and wildcard subdomain
- **S3 Permissions**: Bucket should be publicly readable for static website hosting
- **CloudFront Function**: Runs at edge locations, has access limitations
- **Error Handling**: Graceful degradation for invalid requests

## Performance Optimization

- **Edge Caching**: CloudFront caches responses globally
- **Function Execution**: CloudFront Functions run at edge locations
- **Invalidation**: Strategic cache invalidation for deployments
- **Compression**: Enable gzip compression in CloudFront

## Future Improvements

- **Automatic PR cleanup**: Delete old PR folders after PR merge/close
- **Health checks**: Monitor subdomain availability
- **Analytics**: Track PR site usage
- **Staging environment**: Dedicated staging subdomain for integration testing
