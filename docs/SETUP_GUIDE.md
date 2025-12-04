# AI-Assisted Application Packaging Workflow: Step-by-Step Setup Guide

**Author:** Manus AI  
**Version:** 1.0  
**Last Updated:** November 2025

## Table of Contents

1. [Prerequisites Checklist](#prerequisites-checklist)
2. [Phase 1: Environment Preparation (Day 1)](#phase-1-environment-preparation-day-1)
3. [Phase 2: GitHub Repository Setup (Day 1)](#phase-2-github-repository-setup-day-1)
4. [Phase 3: n8n Workflow Configuration (Day 2)](#phase-3-n8n-workflow-configuration-day-2)
5. [Phase 4: Jenkins Setup and Configuration (Day 2-3)](#phase-4-jenkins-setup-and-configuration-day-2-3)
6. [Phase 5: Integration Testing (Day 3)](#phase-5-integration-testing-day-3)
7. [Phase 6: Production Deployment (Day 4)](#phase-6-production-deployment-day-4)
8. [Verification and Validation](#verification-and-validation)

---

## Prerequisites Checklist

Before beginning the setup process, verify that you have access to all required services and tools. Check off each item as you confirm availability.

### External Services and Accounts

- **GitHub:** Organization account with repository creation permissions
- **n8n Cloud:** Active account with webhook and HTTP request capabilities
- **OpenAI API:** Account with GPT-4 or GPT-4o-mini access and sufficient quota
- **Cloud Storage:** S3 bucket or Azure Blob Storage container for artifact storage
- **Jenkins:** Self-hosted or cloud-based Jenkins instance with admin access

### Local Development Environment

- **Git:** Version 2.30 or later (`git --version`)
- **GitHub CLI:** Latest version (`gh --version`)
- **PowerShell:** Version 7 or later (`pwsh --version`)
- **Node.js:** Version 16 or later (for n8n CLI, if using self-hosted)
- **Docker:** (Optional, for running Jenkins and n8n locally)

### API Keys and Credentials

Gather the following credentials before starting. Store them securely in a password manager:

- **OpenAI API Key:** Start with `sk-` prefix
- **GitHub Personal Access Token:** With `repo`, `workflow`, and `admin:repo_hook` scopes
- **AWS Access Key ID and Secret Key:** (if using S3)
- **Azure Storage Account Name and Key:** (if using Azure Blob)

### Network and Firewall

Verify network connectivity:

- Jenkins can reach GitHub (for cloning repositories)
- n8n can reach OpenAI API (`api.openai.com`)
- GitHub can reach n8n webhook URL (for triggering workflows)
- Windows agents can access cloud storage (for artifact uploads)

---

## Phase 1: Environment Preparation (Day 1)

### Step 1.1: Create GitHub Organization and Repository

Create a dedicated GitHub organization to house your packaging infrastructure:

```bash
# Log in to GitHub CLI
gh auth login

# Create organization (if not already exists)
# Navigate to https://github.com/organizations/new and create your organization

# Create packaging repository
gh repo create your-org/packaging-repo \
  --public \
  --description "AI-Assisted Application Packaging Repository" \
  --gitignore PowerShell \
  --license MIT

# Clone the repository
git clone https://github.com/your-org/packaging-repo.git
cd packaging-repo
```

### Step 1.2: Initialize Repository Structure

Create the directory structure that will organize packaging artifacts:

```bash
# Create core directories
mkdir -p templates/psadt-template
mkdir -p templates/n8n-workflows
mkdir -p scripts
mkdir -p docs
mkdir -p products
mkdir -p .github/workflows

# Create initial documentation files
touch README.md
touch CONTRIBUTING.md
touch docs/ARCHITECTURE.md
touch docs/TROUBLESHOOTING.md

# Create .gitignore to exclude sensitive files
cat > .gitignore << 'EOF'
# Sensitive files
*.key
*.pem
.env
.env.local
credentials.json
secrets/

# Build and test artifacts
build/
test-output/
*.zip
*.log

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF

git add .
git commit -m "Initial repository structure"
git push origin main
```

### Step 1.3: Copy Templates from Automation Repository

Clone the automation repository and copy templates:

```bash
# Clone the automation repository
cd /tmp
git clone https://github.com/MdAsifInIT/Packaging-Workflow-Automation.git
cd Packaging-Workflow-Automation

# Copy templates to your packaging repository
cp -r templates/psadt-template/* ~/packaging-repo/templates/psadt-template/
cp -r templates/n8n-workflows/* ~/packaging-repo/templates/n8n-workflows/
cp -r scripts/* ~/packaging-repo/scripts/
cp Jenkinsfile ~/packaging-repo/

# Copy documentation
cp docs/runbook.md ~/packaging-repo/docs/
cp docs/onboarding.md ~/packaging-repo/docs/

# Return to packaging repository
cd ~/packaging-repo
git add .
git commit -m "Add templates and scripts from automation repository"
git push origin main
```

### Step 1.4: Set Up Local Development Environment

Install required tools on your development machine:

**On macOS:**

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install git gh node@18 pwsh

# Verify installations
git --version
gh --version
node --version
pwsh --version
```

**On Windows (using Chocolatey):**

```powershell
# Install Chocolatey if not already installed
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install required tools
choco install git github-cli nodejs powershell -y

# Verify installations
git --version
gh --version
node --version
pwsh --version
```

### Step 1.5: Configure Git and GitHub CLI

Set up Git with your credentials:

```bash
# Configure Git user
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"

# Authenticate with GitHub CLI
gh auth login
# Follow the prompts to authenticate

# Verify authentication
gh auth status
```

---

## Phase 2: GitHub Repository Setup (Day 1)

### Step 2.1: Configure Branch Protection Rules

Protect the main branch from accidental commits:

```bash
# Using GitHub CLI to set branch protection
gh api repos/your-org/packaging-repo/branches/main/protection \
  -X PUT \
  -f required_status_checks='{"strict":true,"contexts":["Jenkins CI"]}' \
  -f enforce_admins=true \
  -f required_pull_request_reviews='{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":1}' \
  -f restrictions=null
```

### Step 2.2: Create GitHub Secrets for CI/CD

Store sensitive credentials in GitHub Secrets:

```bash
# OpenAI API Key
gh secret set OPENAI_API_KEY --body "sk-your-actual-key"

# GitHub Token (for internal use)
gh secret set GITHUB_TOKEN --body "ghp_your-actual-token"

# Jenkins credentials (if using GitHub Actions)
gh secret set JENKINS_USER --body "your-jenkins-username"
gh secret set JENKINS_TOKEN --body "your-jenkins-api-token"

# Verify secrets are set
gh secret list
```

### Step 2.3: Set Up GitHub Webhooks

Configure webhooks to trigger n8n and Jenkins:

**Webhook 1: Trigger n8n on Issue Comments**

```bash
gh api repos/your-org/packaging-repo/hooks \
  -X POST \
  -f url='https://your-n8n-instance.com/webhook/packaging-intake' \
  -f events='["issue_comment"]' \
  -f active=true \
  -f content_type='json'
```

**Webhook 2: Trigger Jenkins on Push**

```bash
gh api repos/your-org/packaging-repo/hooks \
  -X POST \
  -f url='https://your-jenkins-instance.com/github-webhook/' \
  -f events='["push","pull_request"]' \
  -f active=true \
  -f content_type='json'
```

### Step 2.4: Create Documentation Files

Create comprehensive documentation for your team:

**README.md:**

```markdown
# Packaging Repository

This repository contains AI-generated application packaging artifacts and configuration.

## Quick Start

1. Clone this repository
2. Review the [Architecture](docs/ARCHITECTURE.md)
3. Follow the [Runbook](docs/runbook.md) for operational procedures

## Submitting a Packaging Request

To request a new application package:

1. Create an issue with the following information:
   - Application name and vendor
   - Download URL for the installer
   - Release notes or version information

2. Comment on the issue with: `@packaging-bot package-this`

3. The AI workflow will analyze the installer and create a PR

4. Review the PR, run tests, and merge when ready

## Support

For questions or issues, see [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
```

**docs/ARCHITECTURE.md:**

```markdown
# Architecture Overview

## System Components

- **n8n:** Orchestration and intake
- **OpenAI API:** AI analysis
- **GitHub:** Version control and collaboration
- **Jenkins:** CI/CD and testing

## Data Flow

Request → n8n → OpenAI → GitHub PR → Jenkins Tests → Results

## Security Considerations

- API keys stored in n8n vault
- GitHub tokens restricted to necessary scopes
- Jenkins credentials encrypted
- All logs retained for audit purposes
```

---

## Phase 3: n8n Workflow Configuration (Day 2)

### Step 3.1: Set Up n8n Cloud Account

Create and configure your n8n Cloud account:

1. Navigate to https://n8n.cloud/
2. Sign up for a free account
3. Verify your email address
4. Create a new workspace named "Packaging Automation"

### Step 3.2: Import the Workflow Template

Import the n8n workflow:

1. In n8n, click **Workflows** → **Import**
2. Upload `templates/n8n-workflows/intake-openai.json` from your repository
3. Click **Import** to create the workflow

### Step 3.3: Configure Credentials

Set up credentials for all external services:

**OpenAI Credentials:**

1. In n8n, click **Credentials** → **New**
2. Select **OpenAI**
3. Paste your OpenAI API key
4. Click **Save**

**GitHub Credentials:**

1. Click **Credentials** → **New**
2. Select **GitHub**
3. Generate a personal access token in GitHub settings with `repo` and `workflow` scopes
4. Paste the token in n8n
5. Click **Save**

**Storage Credentials (S3 or Azure):**

1. Click **Credentials** → **New**
2. Select your storage provider (AWS S3 or Azure Blob)
3. Enter your access credentials
4. Click **Save**

### Step 3.4: Configure Workflow Nodes

Update each node in the workflow with the correct credentials and settings:

**Webhook Node:**

1. Open the workflow
2. Click the Webhook node
3. Copy the webhook URL (you'll need this for GitHub)
4. Set authentication method to "Basic Auth" or "API Key"
5. Save the node

**HTTP Request Node (Download):**

1. Click the HTTP Request node
2. Set URL to `{{ $json.installer_url }}`
3. Set method to GET
4. Configure response handling to save file to storage
5. Save the node

**OpenAI Node:**

1. Click the OpenAI node
2. Select your OpenAI credentials
3. Set model to `gpt-4o-mini`
4. Set temperature to `0.1`
5. Update system and user messages with your organization's details
6. Save the node

**GitHub Nodes:**

1. Click each GitHub node (Create Branch, Commit, Create PR)
2. Select your GitHub credentials
3. Update repository owner and name
4. Update branch naming and commit messages
5. Save each node

### Step 3.5: Test the Workflow

Test the workflow with a sample request:

```bash
# Get the webhook URL from n8n
WEBHOOK_URL="https://your-n8n-instance.com/webhook/packaging-intake"

# Send a test request
curl -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{
    "ticket_id": "TEST-001",
    "installer_url": "https://download.mozilla.org/firefox/releases/latest/win64/en-US/Firefox%20Setup%20Latest.exe",
    "release_notes": "Firefox latest - test request",
    "requested_by": "test@company.com"
  }'
```

Monitor the workflow execution in n8n and verify that:

1. The installer is downloaded successfully
2. Metadata is extracted
3. OpenAI generates valid JSON output
4. A GitHub PR is created with the generated files

### Step 3.6: Activate the Workflow

Once testing is successful, activate the workflow:

1. In n8n, open the workflow
2. Click the **Activate** button (top right)
3. Verify the webhook is active and listening

---

## Phase 4: Jenkins Setup and Configuration (Day 2-3)

### Step 4.1: Install Jenkins

**Using Docker (Recommended for Testing):**

```bash
# Create Jenkins data directory
mkdir -p ~/jenkins-data

# Run Jenkins in Docker
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v ~/jenkins-data:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:latest
```

**Using Traditional Installation (Windows):**

1. Download Jenkins from https://www.jenkins.io/download/
2. Run the installer and follow the setup wizard
3. Install suggested plugins
4. Create an admin user
5. Configure Jenkins URL

### Step 4.2: Install Required Plugins

Install plugins for GitHub integration and PowerShell support:

```bash
# Using Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080 install-plugin \
  github \
  github-branch-source \
  pipeline-github \
  powershell \
  pipeline-stage-view
```

Or through the Jenkins UI:

1. Go to **Manage Jenkins** → **Manage Plugins**
2. Search for and install:
   - GitHub Integration
   - GitHub Branch Source
   - Pipeline
   - PowerShell
   - Pipeline Stage View

### Step 4.3: Create Windows Build Agent

Set up a Windows agent for running PowerShell scripts:

**On Windows Agent Machine:**

```powershell
# Create agent directory
New-Item -Path "C:\jenkins" -ItemType Directory -Force

# Download agent.jar from Jenkins master
# http://your-jenkins:8080/manage/computer/new

# Start the agent
java -jar agent.jar -jnlpUrl http://your-jenkins:8080/computer/windows-agent/slave-agent.jnlp -secret YOUR_SECRET
```

**In Jenkins UI:**

1. Go to **Manage Jenkins** → **Manage Nodes and Clouds**
2. Click **New Node**
3. Name: `windows-agent`
4. Type: Permanent Agent
5. Configure:
   - Remote root directory: `C:\jenkins\workspace`
   - Labels: `windows`
   - Launch method: JNLP
6. Save and launch the agent

### Step 4.4: Install Windows Agent Prerequisites

On the Windows agent, install required software:

```powershell
# Install PowerShell 7
winget install Microsoft.PowerShell

# Install PSAppDeployToolkit
New-Item -Path "C:\Program Files\PSAppDeployToolkit" -ItemType Directory -Force
# Download and extract PSADT from https://psappdeploytoolkit.com/

# Install PSScriptAnalyzer
Install-Module -Name PSScriptAnalyzer -Force -Scope AllUsers

# Install additional tools
choco install 7zip sysinternals -y
```

### Step 4.5: Create Jenkins Pipeline Job

Create a pipeline job for packaging:

```bash
# Create job using Jenkins CLI
java -jar jenkins-cli.jar -s http://localhost:8080 create-job packaging-pipeline < Jenkinsfile
```

Or through the Jenkins UI:

1. Click **New Item**
2. Name: `packaging-pipeline`
3. Type: Pipeline
4. Configure:
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: `https://github.com/your-org/packaging-repo.git`
   - Script path: `Jenkinsfile`
   - Build triggers: GitHub push event
5. Save

### Step 4.6: Configure Jenkins Credentials

Store credentials securely in Jenkins:

```bash
# Create GitHub credentials
java -jar jenkins-cli.jar -s http://localhost:8080 create-credentials-by-xml system::system default << 'EOF'
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
  <scope>GLOBAL</scope>
  <id>github-credentials</id>
  <description>GitHub API Token</description>
  <username>your-username</username>
  <password>ghp_your-token</password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF
```

---

## Phase 5: Integration Testing (Day 3)

### Step 5.1: End-to-End Workflow Test

Test the complete workflow with a real application:

```bash
# Create a test issue in GitHub
gh issue create \
  --title "Test: Package Firefox" \
  --body "Please package Firefox latest version"

# Get the issue number
ISSUE_NUM=$(gh issue list --limit 1 --json number -q '.[0].number')

# Comment to trigger the workflow
gh issue comment $ISSUE_NUM --body "@packaging-bot package-this"
```

### Step 5.2: Monitor Workflow Execution

Monitor each stage of the workflow:

**In n8n:**

1. Go to **Executions**
2. Watch the workflow run in real-time
3. Check for any errors or warnings
4. Verify that all nodes complete successfully

**In GitHub:**

1. Go to the **Pull Requests** tab
2. Find the newly created PR
3. Review the generated files
4. Check that the PR has the correct labels

**In Jenkins:**

1. Go to the **packaging-pipeline** job
2. Watch the build progress
3. Check the console output for any errors
4. Verify that all stages complete

### Step 5.3: Verify Generated Artifacts

Check that the generated files are correct:

```bash
# Clone the PR branch
git fetch origin ai/TEST-001-*
git checkout ai/TEST-001-*

# Verify manifest structure
cat products/Firefox/manifest.json | jq '.'

# Verify candidates structure
cat products/Firefox/candidates.json | jq '.'

# Check PSADT script syntax
pwsh -Command "Test-Path 'products/Firefox/Deploy-Application.ps1'"
```

### Step 5.4: Review and Merge

Review the PR and merge if everything looks correct:

```bash
# Approve the PR
gh pr review --approve

# Merge the PR
gh pr merge --merge
```

### Step 5.5: Verify Test Results

Check the Jenkins test results:

1. Go to the Jenkins build
2. Look for the **Test Installation** stage
3. Verify that at least one candidate succeeded
4. Check the test artifacts in the build output

---

## Phase 6: Production Deployment (Day 4)

### Step 6.1: Production Readiness Checklist

Before deploying to production, verify:

- **n8n:** Workflow is active and responding to webhooks
- **Jenkins:** All agents are online and healthy
- **GitHub:** Branch protection rules are enforced
- **Credentials:** All API keys are stored securely
- **Monitoring:** Logging is configured for all components
- **Documentation:** Team is trained on the workflow

### Step 6.2: Enable Production Webhooks

Activate webhooks for production:

```bash
# Enable n8n webhook in production
gh api repos/your-org/packaging-repo/hooks \
  -X PATCH \
  -f active=true

# Enable Jenkins webhook in production
gh api repos/your-org/packaging-repo/hooks \
  -X PATCH \
  -f active=true
```

### Step 6.3: Set Up Monitoring and Alerts

Configure monitoring for the workflow:

**n8n Monitoring:**

1. In n8n, go to **Settings** → **Monitoring**
2. Enable execution logging
3. Set up alerts for failed executions
4. Configure log retention policy

**Jenkins Monitoring:**

1. In Jenkins, go to **Manage Jenkins** → **Configure System**
2. Enable email notifications
3. Configure build failure alerts
4. Set up log archival

**GitHub Monitoring:**

1. Enable branch protection notifications
2. Set up PR review reminders
3. Configure status check notifications

### Step 6.4: Create Runbooks and Documentation

Document operational procedures:

**docs/RUNBOOK.md:**

```markdown
# Operational Runbook

## Daily Operations

### Submitting a Packaging Request

1. Create a GitHub issue with application details
2. Comment with `@packaging-bot package-this`
3. Monitor the workflow in n8n
4. Review the generated PR
5. Merge when ready

### Monitoring Workflow Health

1. Check n8n execution logs daily
2. Review Jenkins build history
3. Monitor GitHub PR queue
4. Check for any failed executions

## Troubleshooting

### Workflow Fails at OpenAI Step

- Check OpenAI API quota
- Verify API key is valid
- Check n8n logs for error details

### Jenkins Test Fails

- Review test output in Jenkins
- Check Windows agent logs
- Verify PSADT is installed correctly

### GitHub PR Not Created

- Check GitHub credentials in n8n
- Verify repository permissions
- Check n8n logs for GitHub API errors

## Escalation Procedures

For critical issues:

1. Contact the packaging team lead
2. Check the #packaging-automation Slack channel
3. Review the troubleshooting guide
```

### Step 6.5: Train Your Team

Conduct training sessions for your team:

1. **Overview Session:** Explain the workflow and benefits
2. **Hands-On Session:** Walk through submitting a packaging request
3. **Troubleshooting Session:** Cover common issues and solutions
4. **Q&A Session:** Address team questions and concerns

### Step 6.6: Go Live

Launch the workflow to production:

1. Announce the new workflow to the team
2. Start accepting packaging requests
3. Monitor the first week closely
4. Gather feedback and iterate

---

## Verification and Validation

### Verification Checklist

After completing all phases, verify the following:

| Item | Status | Notes |
| :--- | :--- | :--- |
| GitHub repository created and configured | ☐ | |
| n8n workflow imported and active | ☐ | |
| OpenAI credentials configured | ☐ | |
| GitHub credentials configured | ☐ | |
| Jenkins installed and agents online | ☐ | |
| Windows agent has prerequisites installed | ☐ | |
| Pipeline job created and tested | ☐ | |
| End-to-end test successful | ☐ | |
| Monitoring and alerts configured | ☐ | |
| Team trained on procedures | ☐ | |

### Validation Tests

Run the following tests to validate the setup:

**Test 1: Webhook Connectivity**

```bash
curl -X POST https://your-n8n-instance.com/webhook/packaging-intake \
  -H "Content-Type: application/json" \
  -d '{"ticket_id":"VALIDATE-001","installer_url":"https://example.com/app.exe","release_notes":"Test","requested_by":"test@example.com"}'
```

**Test 2: OpenAI Integration**

Verify that OpenAI returns valid JSON by checking n8n execution logs.

**Test 3: GitHub Integration**

Verify that a PR is created with the correct structure and labels.

**Test 4: Jenkins Integration**

Verify that Jenkins receives the webhook and starts a build.

**Test 5: End-to-End Test**

Submit a real packaging request and verify all stages complete successfully.

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Author:** Manus AI
