#!/bin/bash

# generate-pr-bucket-name.sh
# Generates a unique S3 bucket name for PR deployments

set -e

# Get PR number from environment or parameter
PR_NUMBER=${1:-${GITHUB_EVENT_NUMBER}}

if [ -z "$PR_NUMBER" ]; then
    echo "Error: PR number is required"
    echo "Usage: $0 <pr-number>"
    exit 1
fi

# Get base bucket name from environment
BASE_BUCKET_NAME=${S3_BUCKET_NAME:-"your-project-bucket"}

# Generate PR-specific bucket name
PR_BUCKET_NAME="${BASE_BUCKET_NAME}-pr-${PR_NUMBER}"

echo "PR Number: $PR_NUMBER"
echo "Base Bucket: $BASE_BUCKET_NAME"
echo "PR Bucket: $PR_BUCKET_NAME"

# Validate bucket name (S3 bucket naming rules)
if [[ ! "$PR_BUCKET_NAME" =~ ^[a-z0-9.-]+$ ]]; then
    echo "Error: Invalid bucket name format"
    exit 1
fi

if [ ${#PR_BUCKET_NAME} -gt 63 ]; then
    echo "Error: Bucket name too long (max 63 characters)"
    exit 1
fi

# Output the bucket name for use in workflows
echo "::set-output name=bucket-name::$PR_BUCKET_NAME"
echo "::set-output name=pr-folder::pr-$PR_NUMBER"

echo "✅ Generated PR bucket name: $PR_BUCKET_NAME"
