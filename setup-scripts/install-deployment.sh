#!/bin/bash

# install-deployment.sh
# Adds PR deployment infrastructure to an existing project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Get target project directory
TARGET_PROJECT=${1:-"."}

echo "🚀 AWS Static Site PR Deployment Installer"
echo "==========================================="
echo ""

# Check if target directory exists
if [ ! -d "$TARGET_PROJECT" ]; then
    print_error "Target directory $TARGET_PROJECT does not exist"
    exit 1
fi

# Check if it's a git repository
if [ ! -d "$TARGET_PROJECT/.git" ]; then
    print_error "Target directory is not a git repository"
    exit 1
fi

# Check if package.json exists
if [ ! -f "$TARGET_PROJECT/package.json" ]; then
    print_error "No package.json found in target directory"
    exit 1
fi

print_status "Target project validation passed"

# Get project details from user
echo ""
echo "📝 Please provide your project details:"
echo ""

read -p "What's your domain name? (e.g., myapp.com): " DOMAIN
if [ -z "$DOMAIN" ]; then
    print_error "Domain name is required"
    exit 1
fi

read -p "What's your build command? (e.g., npm run build): " BUILD_CMD
BUILD_CMD=${BUILD_CMD:-"npm run build"}

read -p "What's your build output directory? (e.g., ./build): " BUILD_DIR
BUILD_DIR=${BUILD_DIR:-"./build"}

read -p "What Node.js version do you use? (default: 18): " NODE_VERSION
NODE_VERSION=${NODE_VERSION:-18}

echo ""
echo "📁 Copying deployment files..."

# Copy GitHub Actions from templates
cp -r templates/github "$TARGET_PROJECT/.github"

# Copy CloudFront setup
cp -r .cloudfront "$TARGET_PROJECT/"

print_status "Deployment files copied"

# Customize the workflow files
echo ""
echo "⚙️  Customizing for your project..."

# Update domain names
find "$TARGET_PROJECT/.github/workflows" -name "*.yml" -exec sed -i.bak "s/artificerinnovations\.com/$DOMAIN/g" {} \;
find "$TARGET_PROJECT/.github/workflows" -name "*.yml" -exec sed -i.bak "s/yourdomain\.com/$DOMAIN/g" {} \;

# Update build commands
find "$TARGET_PROJECT/.github/workflows" -name "*.yml" -exec sed -i.bak "s/npm run build/$BUILD_CMD/g" {} \;

# Update build directory
find "$TARGET_PROJECT/.github/workflows" -name "*.yml" -exec sed -i.bak "s|\./build|$BUILD_DIR|g" {} \;

# Update Node.js version
find "$TARGET_PROJECT/.github/workflows" -name "*.yml" -exec sed -i.bak "s/node-version: '18'/node-version: '$NODE_VERSION'/g" {} \;

# Clean up backup files
find "$TARGET_PROJECT/.github/workflows" -name "*.bak" -delete

print_status "Workflow files customized"

# Update error.html with project name
sed -i.bak "s/Site Error/$DOMAIN - Error/g" "$TARGET_PROJECT/.cloudfront/error.html"
rm "$TARGET_PROJECT/.cloudfront/error.html.bak"

print_status "Error page customized"

# Install Cypress if not already present
echo ""
echo "🧪 Setting up testing..."

cd "$TARGET_PROJECT"

if ! npm list cypress >/dev/null 2>&1; then
    echo "Installing Cypress..."
    npm install --save-dev cypress
    print_status "Cypress installed"
else
    print_status "Cypress already installed"
fi

# Create Cypress config if it doesn't exist
if [ ! -f "cypress.config.js" ]; then
    cat > cypress.config.js << 'EOF'
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
EOF
    print_status "Cypress config created"
fi

# Create test directories and files if they don't exist
mkdir -p tests/e2e tests/support tests/fixtures

# Create basic test files
if [ ! -f "tests/support/e2e.js" ]; then
    cat > tests/support/e2e.js << 'EOF'
import './commands'

// Custom commands and global configuration
EOF
fi

if [ ! -f "tests/support/commands.js" ]; then
    cat > tests/support/commands.js << 'EOF'
// Custom commands for E2E testing

Cypress.Commands.add('waitForPageLoad', () => {
  cy.get('body').should('be.visible')
  cy.window().should('have.property', 'document')
})

Cypress.Commands.add('checkCommonElements', () => {
  cy.get('body').should('be.visible')
  cy.get('html').should('have.attr', 'lang')
})

Cypress.Commands.add('checkBranding', () => {
  // Add your site-specific branding checks here
  cy.get('title').should('not.be.empty')
})
EOF
fi

if [ ! -f "tests/e2e/homepage.cy.js" ]; then
    cat > tests/e2e/homepage.cy.js << 'EOF'
describe('Homepage', () => {
  beforeEach(() => {
    cy.visit('/')
  })

  it('should load the homepage successfully', () => {
    cy.waitForPageLoad()
    cy.checkCommonElements()
    cy.checkBranding()
  })

  it('should have proper meta tags', () => {
    cy.get('meta[name="description"]').should('exist')
    cy.get('title').should('not.be.empty')
  })
})
EOF
fi

print_status "Test files created"

# Update package.json scripts
echo ""
echo "📝 Updating package.json scripts..."

# Add test scripts if they don't exist
npm pkg set scripts."test:e2e"="${npm pkg get scripts.test:e2e || 'cypress run'}"
npm pkg set scripts."test:e2e:dev"="${npm pkg get scripts.test:e2e:dev || 'cypress open'}"
npm pkg set scripts."test:e2e:prod"="${npm pkg get scripts.test:e2e:prod || "cypress run --config baseUrl=https://$DOMAIN"}"

print_status "Package.json scripts updated"

# Create configuration file
cat > deployment-config.json << EOF
{
  "project": {
    "name": "$(basename "$TARGET_PROJECT")",
    "domain": "$DOMAIN",
    "buildCommand": "$BUILD_CMD",
    "buildDir": "$BUILD_DIR",
    "testCommand": "npm run test:e2e"
  },
  "aws": {
    "region": "us-east-1",
    "bucketName": "your-project-bucket",
    "cloudfrontDistributionId": "YOUR_DISTRIBUTION_ID"
  },
  "testing": {
    "framework": "cypress",
    "testFiles": ["tests/e2e/**/*.cy.js"]
  }
}
EOF

print_status "Configuration file created: deployment-config.json"

echo ""
echo "🎉 Installation complete!"
echo ""
echo "📋 Next steps:"
echo ""
echo "1. 🏗️  Set up AWS infrastructure:"
echo "   - Create S3 bucket: aws s3 mb s3://your-project-bucket"
echo "   - Enable static website hosting on the bucket"
echo "   - Create CloudFront distribution"
echo "   - Upload CloudFront function from .cloudfront/functions/SubdomainFolders.js"
echo "   - Configure custom error pages (403 → /error.html)"
echo ""
echo "2. 🔐 Configure GitHub secrets and variables:"
echo "   - Go to your repository Settings → Secrets and variables → Actions"
echo "   - Add these secrets:"
echo "     • AWS_ACCESS_KEY_ID"
echo "     • AWS_SECRET_ACCESS_KEY"
echo "   - Add these variables:"
echo "     • AWS_REGION=us-east-1"
echo "     • S3_BUCKET_NAME=your-project-bucket"
echo "     • CLOUDFRONT_DISTRIBUTION_ID=YOUR_DISTRIBUTION_ID"
echo "     • DOMAIN=$DOMAIN"
echo "     • BUILD_COMMAND=$BUILD_CMD"
echo "     • BUILD_DIR=$BUILD_DIR"
echo ""
echo "3. 🧪 Customize your E2E tests in tests/e2e/"
echo "4. 🚀 Create a test PR to verify everything works!"
echo ""
print_warning "Don't forget to update deployment-config.json with your AWS details!"
echo ""
echo "📚 For detailed setup instructions, see the documentation:"
echo "   - docs/SETUP.md - Complete setup guide"
echo "   - docs/AWS-SETUP.md - AWS infrastructure setup"
echo "   - docs/GITHUB-SETUP.md - GitHub configuration"
echo "   - .cloudfront/CLOUDFRONT.md - CloudFront setup details"
echo ""
print_info "Happy deploying! 🚀"
