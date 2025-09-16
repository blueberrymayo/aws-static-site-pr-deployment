# AWS Static Site PR Deployment Template

> Complete AWS-based CI/CD setup for static sites with PR preview environments using S3 + CloudFront

[![GitHub](https://img.shields.io/badge/GitHub-Template-blue?style=flat-square&logo=github)](https://github.com)
[![AWS](https://img.shields.io/badge/AWS-S3%20%2B%20CloudFront-orange?style=flat-square&logo=amazon-aws)](https://aws.amazon.com)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Workflows-blue?style=flat-square&logo=github-actions)](https://github.com/features/actions)

## 🚀 What This Template Provides

This template repository provides a complete deployment infrastructure for static websites with the following features:

- **🔀 PR Preview Environments**: Every PR gets its own subdomain (e.g., `pr-123.yourdomain.com`)
- **☁️ AWS Infrastructure**: Uses S3 for hosting and CloudFront for global CDN
- **🧪 E2E Testing**: Integrated Cypress testing with PR comment triggers
- **⚡ Fast Deployments**: Optimized for static sites with caching
- **🔒 Security**: Proper AWS IAM roles and secure credential management
- **📊 Monitoring**: Comprehensive logging and deployment status reporting

## 🏗️ Architecture

```
GitHub PR → GitHub Actions → AWS S3 → CloudFront → PR Subdomain
    ↓
  E2E Tests → Cypress → Test Results → PR Comment
```

### Infrastructure Components

- **S3 Bucket**: Stores static files in folder structure (`/production/`, `/pr-123/`, etc.)
- **CloudFront Distribution**: Global CDN with subdomain routing
- **CloudFront Function**: Routes subdomains to correct S3 folders
- **GitHub Actions**: Automated deployment and testing workflows

## 📋 Prerequisites

- AWS Account with appropriate permissions
- Domain with SSL certificate for `yourdomain.com` and `*.yourdomain.com`
- GitHub repository with Actions enabled
- Node.js project with build command

## 🚀 Quick Start

### Option 1: Use This Template (Recommended)

1. **Create repository from template:**
   ```bash
   # Use GitHub's template feature or:
   gh repo create your-project --template artificer-innovations/aws-static-site-pr-deployment
   ```

2. **Run the setup script:**
   ```bash
   cd your-project
   ./setup-scripts/install-deployment.sh .
   ```

3. **Follow the guided setup process**

### Option 2: Manual Installation

1. **Copy files to existing project:**
   ```bash
   cp -r templates/github your-existing-project/.github
   cp -r .cloudfront your-existing-project/
   cp setup-scripts/install-deployment.sh your-existing-project/
   ```

2. **Customize configuration files**

3. **Set up AWS infrastructure**

## 📁 Template Contents

```
aws-static-site-pr-deployment/
├── templates/
│   └── github/
│       ├── workflows/
│       │   ├── pr-deploy.yml              # Deploys PR previews
│       │   ├── deploy.yml                 # Production deployment
│       │   ├── pr-test-on-comment.yml     # E2E testing on PR comment
│       │   ├── pr-cleanup.yml            # Cleanup old PR deployments
│       │   └── prevent-push-main.yml     # Enforce PR-only workflow
│       ├── actions/
│       │   └── cypress-test/             # Reusable Cypress testing action
│       └── scripts/
│           └── generate-pr-bucket-name.sh
├── .cloudfront/
│   ├── functions/
│   │   └── SubdomainFolders.js       # CloudFront routing function
│   ├── error.html                    # Global error handler
│   └── CLOUDFRONT.md                 # CloudFront setup documentation
├── setup-scripts/
│   └── install-deployment.sh         # Automated setup script
├── docs/
│   ├── SETUP.md                      # Detailed setup guide
│   ├── AWS-SETUP.md                  # AWS infrastructure setup
│   ├── GITHUB-SETUP.md               # GitHub configuration
│   └── TROUBLESHOOTING.md            # Common issues and solutions
├── templates/
│   ├── cypress.config.js             # Cypress configuration template
│   ├── package.json-scripts          # Package.json scripts to add
│   └── svelte.config.js              # SvelteKit configuration example
└── README.md                         # This file
```

## 🎯 Supported Frameworks

This template works with any static site generator or framework:

- **React** (Create React App, Vite)
- **Vue** (Vue CLI, Vite, Nuxt.js static)
- **SvelteKit** (static adapter)
- **Next.js** (static export)
- **Gatsby**
- **Jekyll**
- **Hugo**
- **Astro**
- **And more...**

## ⚙️ Configuration

The setup script will create a `deployment-config.json` file:

```json
{
  "project": {
    "name": "your-project",
    "domain": "yourdomain.com",
    "buildCommand": "npm run build",
    "buildDir": "./build"
  },
  "aws": {
    "region": "us-east-1",
    "bucketName": "your-project-bucket",
    "cloudfrontDistributionId": "E1234567890ABC"
  }
}
```

## 🔐 Required Secrets and Variables

### GitHub Secrets
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### GitHub Variables
- `AWS_REGION=us-east-1`
- `S3_BUCKET_NAME=your-bucket-name`
- `CLOUDFRONT_DISTRIBUTION_ID=E1234567890ABC`
- `DOMAIN=yourdomain.com`
- `BUILD_COMMAND=npm run build`
- `BUILD_DIR=./build`

## 🧪 Testing

The template includes comprehensive E2E testing with Cypress:

- **Homepage tests**: Basic functionality and meta tags
- **Navigation tests**: Routing and user interactions
- **Performance tests**: Load times and optimization
- **Blog/content tests**: Content rendering and navigation

Trigger tests by commenting on a PR:
- `please test`
- `run tests`
- `test this`
- `/test`

## 📚 Documentation

- [**Setup Guide**](docs/SETUP.md) - Complete setup instructions
- [**AWS Setup**](docs/AWS-SETUP.md) - AWS infrastructure configuration
- [**GitHub Setup**](docs/GITHUB-SETUP.md) - GitHub Actions configuration
- [**Troubleshooting**](docs/TROUBLESHOOTING.md) - Common issues and solutions
- [**CloudFront Details**](.cloudfront/CLOUDFRONT.md) - Subdomain routing explanation

## 🤝 Contributing

Contributions are welcome! Please see our contributing guidelines and feel free to submit issues or pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Created by**: Artificer Innovations, LLC
- **Built for**: Modern static site deployment workflows
- **Inspired by**: The need for better PR preview environments
- **Powered by**: AWS and GitHub Actions

---

**Need help?** Check the [troubleshooting guide](docs/TROUBLESHOOTING.md) or open an issue!
