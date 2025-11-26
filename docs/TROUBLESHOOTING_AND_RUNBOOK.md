# AI-Assisted Application Packaging Workflow: Troubleshooting and Operational Runbook

**Author:** Manus AI  
**Version:** 1.0  
**Last Updated:** November 2025

## Table of Contents

1. [Operational Runbook](#operational-runbook)
2. [Troubleshooting Guide](#troubleshooting-guide)
3. [Common Issues and Solutions](#common-issues-and-solutions)
4. [Log Analysis and Debugging](#log-analysis-and-debugging)
5. [Performance Optimization](#performance-optimization)
6. [Maintenance and Updates](#maintenance-and-updates)

---

## Operational Runbook

### Daily Operations

#### Morning Checklist

Start each day by verifying the health of all workflow components:

```bash
#!/bin/bash
# daily-health-check.sh

echo "=== Daily Workflow Health Check ==="

# Check n8n status
echo "Checking n8n..."
curl -s https://your-n8n-instance.com/api/v1/health | jq '.status'

# Check Jenkins status
echo "Checking Jenkins..."
curl -s http://your-jenkins:8080/api/json | jq '.nodeDescription'

# Check GitHub API
echo "Checking GitHub..."
gh api rate_limit | jq '.rate.remaining'

# Check OpenAI API
echo "Checking OpenAI..."
curl -s https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY" | jq '.data | length'

echo "=== Health Check Complete ==="
```

Run this script each morning and verify all services are operational.

#### Submitting a Packaging Request

The standard process for requesting a new application package:

1. **Create GitHub Issue:** Open a new issue in the packaging repository with the following information:
   - Application name and vendor
   - Version number (if known)
   - Download URL for the installer
   - Any special requirements or notes

2. **Trigger the Workflow:** Comment on the issue with the trigger command:
   ```
   @packaging-bot package-this
   ```

3. **Monitor Progress:** The workflow will execute in the following order:
   - n8n receives the request and downloads the installer
   - OpenAI analyzes the installer and generates candidates
   - GitHub creates a PR with the generated files
   - Jenkins runs tests on the generated scripts

4. **Review the PR:** Examine the generated manifest, candidates, and PSADT script:
   - Check that the product information is accurate
   - Review the candidate commands for correctness
   - Verify the confidence scores are appropriate
   - Look for the `human_review` flag if set to true

5. **Merge or Request Changes:** If the PR looks good, merge it. If changes are needed, request them in the PR comments.

#### Monitoring Workflow Executions

Monitor active workflows throughout the day:

**In n8n:**

1. Navigate to **Executions**
2. Sort by most recent first
3. Check for any failed executions (red status)
4. Click on failed executions to see error details
5. Note any patterns in failures

**In Jenkins:**

1. Go to the **packaging-pipeline** job
2. Review the **Build History**
3. Click on recent builds to see console output
4. Check for any failed stages
5. Review test results

**In GitHub:**

1. Go to **Pull Requests**
2. Filter by label `ai-generated`
3. Check for any PRs with `needs-review` label
4. Review PR comments for any issues
5. Monitor merge activity

#### End-of-Day Report

At the end of each day, generate a summary:

```bash
#!/bin/bash
# daily-summary.sh

echo "=== Daily Summary Report ==="
echo "Date: $(date)"
echo ""

# Count successful executions
echo "Successful Executions:"
curl -s https://your-n8n-instance.com/api/v1/executions \
  -H "Authorization: Bearer $N8N_API_KEY" | jq '.data[] | select(.finished==true) | .id' | wc -l

# Count failed executions
echo "Failed Executions:"
curl -s https://your-n8n-instance.com/api/v1/executions \
  -H "Authorization: Bearer $N8N_API_KEY" | jq '.data[] | select(.finished==false) | .id' | wc -l

# Count merged PRs
echo "Merged PRs:"
gh pr list --state merged --limit 100 | wc -l

# Count pending PRs
echo "Pending PRs:"
gh pr list --state open | wc -l

echo ""
echo "=== End of Report ==="
```

### Weekly Operations

#### Weekly Review Meeting

Conduct a weekly review of the workflow performance:

1. **Metrics Review:** Analyze key metrics:
   - Average time from request to merged PR
   - Success rate of generated packages
   - Number of packages requiring human review
   - Test failure rate and common failure reasons

2. **Issue Review:** Discuss any recurring issues:
   - Patterns in failed executions
   - Common installer types that cause problems
   - Feedback from packaging engineers

3. **Improvement Planning:** Identify opportunities for improvement:
   - Refine LLM prompts based on feedback
   - Improve test coverage
   - Enhance documentation

4. **Capacity Planning:** Assess current capacity:
   - Number of requests per week
   - Average processing time
   - Resource utilization
   - Need for additional agents or capacity

#### Backup and Archival

Perform weekly backups of critical data:

```bash
#!/bin/bash
# weekly-backup.sh

BACKUP_DIR="/backups/packaging-workflow"
DATE=$(date +%Y%m%d)

# Backup GitHub repository
echo "Backing up GitHub repository..."
git clone --mirror https://github.com/your-org/packaging-repo.git \
  $BACKUP_DIR/packaging-repo-$DATE.git

# Backup n8n workflows
echo "Backing up n8n workflows..."
curl -s https://your-n8n-instance.com/api/v1/workflows \
  -H "Authorization: Bearer $N8N_API_KEY" > $BACKUP_DIR/n8n-workflows-$DATE.json

# Backup Jenkins configuration
echo "Backing up Jenkins configuration..."
tar -czf $BACKUP_DIR/jenkins-config-$DATE.tar.gz /var/lib/jenkins/jobs/

# Compress backups
tar -czf $BACKUP_DIR/backup-$DATE.tar.gz $BACKUP_DIR/
rm -rf $BACKUP_DIR/packaging-repo-$DATE.git $BACKUP_DIR/n8n-workflows-$DATE.json

echo "Backup complete: $BACKUP_DIR/backup-$DATE.tar.gz"
```

### Monthly Operations

#### Performance Analysis

Conduct a detailed analysis of workflow performance:

1. **Execution Metrics:**
   - Total requests processed
   - Success rate (percentage of successful executions)
   - Average execution time
   - Peak load periods

2. **Quality Metrics:**
   - Percentage of packages requiring human review
   - Test failure rate
   - Candidate accuracy (percentage of first candidate succeeding)
   - Confidence score distribution

3. **Cost Analysis:**
   - OpenAI API costs
   - Jenkins agent utilization
   - Storage usage
   - n8n execution costs

4. **Trend Analysis:**
   - Compare metrics to previous months
   - Identify improving or declining trends
   - Correlate changes to workflow updates

#### Dependency Updates

Update software dependencies and security patches:

```bash
#!/bin/bash
# monthly-updates.sh

echo "=== Monthly Dependency Updates ==="

# Update Jenkins plugins
echo "Updating Jenkins plugins..."
java -jar jenkins-cli.jar -s http://localhost:8080 list-plugins | \
  awk '{print $1}' | \
  xargs -I {} java -jar jenkins-cli.jar -s http://localhost:8080 install-plugin {}

# Update n8n (if self-hosted)
echo "Updating n8n..."
docker pull n8nio/n8n:latest
docker-compose up -d

# Update PowerShell modules
echo "Updating PowerShell modules..."
pwsh -Command "Update-Module -Force"

# Update GitHub CLI
echo "Updating GitHub CLI..."
brew upgrade gh  # or apt-get upgrade gh / choco upgrade gh

echo "=== Updates Complete ==="
```

---

## Troubleshooting Guide

### Workflow Execution Failures

#### Symptom: n8n Webhook Not Receiving Requests

**Diagnosis:**

1. Verify webhook URL is correct:
   ```bash
   gh api repos/your-org/packaging-repo/hooks | jq '.[] | select(.name=="web") | .config.url'
   ```

2. Check webhook delivery history in GitHub:
   - Go to Repository Settings → Webhooks
   - Click on the webhook
   - Review "Recent Deliveries" tab

3. Verify n8n webhook is active:
   ```bash
   curl -X GET https://your-n8n-instance.com/api/v1/webhooks \
     -H "Authorization: Bearer $N8N_API_KEY"
   ```

**Solutions:**

- **Webhook URL is incorrect:** Update the webhook URL in GitHub settings to match the active n8n webhook
- **n8n webhook is inactive:** Activate the workflow in n8n
- **Firewall blocking requests:** Verify GitHub IP addresses are whitelisted
- **Authentication failing:** Check webhook authentication credentials in n8n

#### Symptom: OpenAI API Returns Invalid JSON

**Diagnosis:**

1. Check the raw API response in n8n execution logs:
   ```
   n8n → Executions → [Failed Execution] → OpenAI Node
   ```

2. Verify the prompt is being constructed correctly:
   - Check that all variables are properly substituted
   - Verify the schema is included in the prompt
   - Look for truncation or encoding issues

3. Check OpenAI API status:
   ```bash
   curl -s https://status.openai.com/api/v2/status.json | jq '.status.indicator'
   ```

**Solutions:**

- **Temperature too high:** Reduce temperature to 0.1 for more deterministic output
- **Prompt too long:** Truncate strings_snippet or other large fields
- **API quota exceeded:** Check usage in OpenAI dashboard
- **Model unavailable:** Verify the model name is correct and available in your account
- **Invalid JSON in response:** Add validation node to catch and log raw response

#### Symptom: GitHub PR Creation Fails

**Diagnosis:**

1. Check GitHub credentials in n8n:
   ```bash
   curl -s https://api.github.com/user \
     -H "Authorization: token $GITHUB_TOKEN" | jq '.login'
   ```

2. Verify repository permissions:
   ```bash
   gh repo view your-org/packaging-repo --json permission
   ```

3. Check GitHub API rate limits:
   ```bash
   gh api rate_limit | jq '.rate'
   ```

**Solutions:**

- **Invalid credentials:** Regenerate GitHub token and update n8n credentials
- **Insufficient permissions:** Ensure token has `repo` and `workflow` scopes
- **Rate limit exceeded:** Wait for rate limit reset or upgrade GitHub account
- **Repository not found:** Verify repository URL and owner name

#### Symptom: Jenkins Build Fails

**Diagnosis:**

1. Check Jenkins build console output:
   - Go to Jenkins job → Recent build → Console Output
   - Look for error messages in the output

2. Verify Windows agent is online:
   ```bash
   curl -s http://your-jenkins:8080/api/json | jq '.computer[] | select(.displayName=="windows-agent")'
   ```

3. Check agent logs:
   ```powershell
   Get-Content "C:\jenkins\logs\agent.log" -Tail 50
   ```

**Solutions:**

- **Agent offline:** Restart the agent process
- **PowerShell script error:** Review the script syntax and test locally
- **Missing dependencies:** Install required tools on the Windows agent
- **Insufficient disk space:** Clean up old builds and artifacts

### Component-Specific Issues

#### n8n Issues

**Issue: Workflow Timeout**

- **Cause:** Large file download or slow API response
- **Solution:** Increase timeout settings in n8n node configuration
- **Prevention:** Implement retry logic with exponential backoff

**Issue: Memory Leak in n8n**

- **Cause:** Long-running workflow execution
- **Solution:** Restart n8n container or service
- **Prevention:** Monitor memory usage and implement execution limits

**Issue: Webhook Authentication Fails**

- **Cause:** Incorrect credentials or expired tokens
- **Solution:** Verify credentials in n8n and GitHub
- **Prevention:** Implement credential rotation policy

#### OpenAI API Issues

**Issue: Rate Limit Exceeded**

- **Cause:** Too many API requests in short time
- **Solution:** Implement request queuing and rate limiting
- **Prevention:** Monitor API usage and set quotas

**Issue: Timeout on Large Installers**

- **Cause:** Slow analysis of large binary files
- **Solution:** Reduce strings_snippet size or use smaller sample
- **Prevention:** Implement file size limits

**Issue: Inconsistent Output Format**

- **Cause:** Model generating non-JSON responses
- **Solution:** Reduce temperature and add stricter prompts
- **Prevention:** Implement validation and retry logic

#### Jenkins Issues

**Issue: Agent Connection Drops**

- **Cause:** Network connectivity or firewall issues
- **Solution:** Restart agent and check network connectivity
- **Prevention:** Implement health checks and auto-restart

**Issue: PowerShell Script Execution Fails**

- **Cause:** Execution policy or script syntax errors
- **Solution:** Review script and test locally on agent
- **Prevention:** Implement linting and validation

**Issue: Test Verification Fails**

- **Cause:** Installation path or registry key doesn't exist
- **Solution:** Update verification hints in manifest
- **Prevention:** Implement more robust verification logic

#### GitHub Issues

**Issue: PR Merge Conflicts**

- **Cause:** Multiple PRs modifying same files
- **Solution:** Resolve conflicts manually or rebase branch
- **Prevention:** Implement branch protection and sequential processing

**Issue: Webhook Delivery Failures**

- **Cause:** Timeout or network issues
- **Solution:** Check webhook URL and retry delivery
- **Prevention:** Implement robust error handling

---

## Common Issues and Solutions

### Issue 1: "No Candidate Commands Generated"

**Symptoms:**
- PR is created but candidates.json is empty
- human_review flag is set to true
- Error message in n8n logs

**Root Causes:**
1. Installer is encrypted or obfuscated
2. Unknown installer framework
3. LLM failed to analyze the binary

**Solutions:**

```bash
# Step 1: Manually inspect the installer
file /path/to/installer.exe
strings /path/to/installer.exe | head -100

# Step 2: Check if it's a known framework
# Look for: NSIS, Inno, InstallShield, MSI, WiX, Burn

# Step 3: If unknown, manually create candidates
cat > candidates.json << 'EOF'
[
  {
    "id": "1",
    "command": "<installer> /quiet",
    "framework": "Custom",
    "confidence": 0.5,
    "rationale": "Generic quiet flag - requires manual testing"
  }
]
EOF

# Step 4: Update manifest with human_review: true
# Step 5: Merge PR and proceed with manual testing
```

### Issue 2: "Installation Verification Failed"

**Symptoms:**
- Jenkins test stage fails
- Verification path not found
- Exit code 1 from test script

**Root Causes:**
1. Installation path is incorrect
2. Application installs to non-standard location
3. Installation failed silently

**Solutions:**

```powershell
# Step 1: Run installation manually
& "C:\path\to\installer.exe" /S

# Step 2: Check common installation paths
Get-ChildItem "C:\Program Files\" | Select-Object Name
Get-ChildItem "C:\Program Files (x86)\" | Select-Object Name

# Step 3: Check registry for installation location
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | 
  Select-Object DisplayName, InstallLocation

# Step 4: Update verification hints in manifest
# Example:
# "verification_hints": [
#   "C:\Program Files\AppName\app.exe",
#   "HKLM:\Software\AppName\Version"
# ]

# Step 5: Re-run test
```

### Issue 3: "OpenAI API Quota Exceeded"

**Symptoms:**
- n8n workflow fails at OpenAI node
- Error message: "Rate limit exceeded"
- Workflow hangs or times out

**Root Causes:**
1. Too many concurrent requests
2. Large batch of requests submitted
3. Quota limit reached

**Solutions:**

```bash
# Step 1: Check current usage
curl -s https://api.openai.com/v1/dashboard/billing/usage \
  -H "Authorization: Bearer $OPENAI_API_KEY" | jq '.total_usage'

# Step 2: Implement request queuing in n8n
# Add a delay node between webhook and OpenAI:
# - Type: Wait
# - Time: 1 second
# - This prevents burst requests

# Step 3: Reduce batch size
# Process one request at a time instead of batch

# Step 4: Upgrade OpenAI account or request higher quota
# Visit https://platform.openai.com/account/billing/overview

# Step 5: Implement retry logic with exponential backoff
# In n8n, add error handler:
# - On error, wait 5 seconds
# - Retry up to 3 times
```

### Issue 4: "Jenkins Agent Offline"

**Symptoms:**
- Jenkins build hangs in queue
- Agent shows "offline" in Jenkins UI
- Build never starts

**Root Causes:**
1. Agent process crashed
2. Network connectivity lost
3. Agent machine powered off

**Solutions:**

```bash
# Step 1: Check agent status
curl -s http://your-jenkins:8080/api/json | jq '.computer[] | {name: .displayName, offline: .offline}'

# Step 2: Restart agent
# On Windows:
# - Stop the Java process running the agent
# - Restart the agent service

# Step 3: Check network connectivity
ping your-windows-agent
ssh your-windows-agent  # or RDP

# Step 4: Check agent logs
# On Windows: C:\jenkins\logs\agent.log
# On Linux: /var/log/jenkins/agent.log

# Step 5: Restart Jenkins if agent won't reconnect
systemctl restart jenkins

# Step 6: Verify agent is online
curl -s http://your-jenkins:8080/api/json | jq '.computer[] | select(.displayName=="windows-agent")'
```

### Issue 5: "GitHub Webhook Not Triggering"

**Symptoms:**
- Comment on issue doesn't trigger workflow
- No PR is created
- n8n webhook not receiving requests

**Root Causes:**
1. Webhook URL is incorrect
2. Webhook is inactive
3. GitHub can't reach n8n endpoint

**Solutions:**

```bash
# Step 1: Verify webhook URL
gh api repos/your-org/packaging-repo/hooks | jq '.[] | {url: .config.url, active: .active}'

# Step 2: Check webhook delivery history
gh api repos/your-org/packaging-repo/hooks/[HOOK_ID]/deliveries | jq '.[] | {status: .status, conclusion: .conclusion}'

# Step 3: Test webhook manually
curl -X POST https://your-n8n-instance.com/webhook/packaging-intake \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Step 4: Verify n8n webhook is active
# In n8n UI: Workflows → [Workflow Name] → Check "Activate" button

# Step 5: Check firewall rules
# Ensure GitHub IP addresses can reach your n8n instance
# GitHub IP ranges: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/about-githubs-ip-addresses

# Step 6: Update webhook if URL changed
gh api repos/your-org/packaging-repo/hooks/[HOOK_ID] \
  -X PATCH \
  -f url='https://your-new-n8n-url.com/webhook/packaging-intake'
```

---

## Log Analysis and Debugging

### Accessing Logs

#### n8n Logs

```bash
# View n8n execution logs
curl -s https://your-n8n-instance.com/api/v1/executions \
  -H "Authorization: Bearer $N8N_API_KEY" | jq '.data[] | {id, status, startTime, stopTime}'

# View specific execution details
curl -s https://your-n8n-instance.com/api/v1/executions/[EXECUTION_ID] \
  -H "Authorization: Bearer $N8N_API_KEY" | jq '.'

# Export execution logs
curl -s https://your-n8n-instance.com/api/v1/executions \
  -H "Authorization: Bearer $N8N_API_KEY" > n8n-executions.json
```

#### Jenkins Logs

```bash
# View Jenkins build console
curl -s http://your-jenkins:8080/job/packaging-pipeline/[BUILD_NUMBER]/consoleText

# View Jenkins system log
curl -s http://your-jenkins:8080/log/all | tail -100

# View agent logs
ssh your-windows-agent
Get-Content "C:\jenkins\logs\agent.log" -Tail 100
```

#### GitHub Logs

```bash
# View webhook deliveries
gh api repos/your-org/packaging-repo/hooks/[HOOK_ID]/deliveries | jq '.[] | {id, status, request, response}'

# View PR comments and activity
gh pr view [PR_NUMBER] --json comments,commits,reviews
```

### Debugging Techniques

#### Enable Verbose Logging

In n8n, enable debug mode for detailed logs:

```javascript
// In n8n Function node
console.log('DEBUG: Input data:', JSON.stringify(items, null, 2));
console.log('DEBUG: Variable value:', someVariable);
```

In Jenkins, enable debug output:

```groovy
// In Jenkinsfile
pipeline {
  options {
    timestamps()
    timeout(time: 1, unit: 'HOURS')
  }
  
  stages {
    stage('Debug') {
      steps {
        powershell '''
          $DebugPreference = "Continue"
          Write-Debug "Debug message"
        '''
      }
    }
  }
}
```

#### Trace Execution Flow

Create a trace log to track execution through all components:

```bash
#!/bin/bash
# trace-execution.sh

TICKET_ID=$1

echo "Tracing execution for ticket: $TICKET_ID"
echo ""

# Check n8n execution
echo "=== n8n Execution ==="
curl -s https://your-n8n-instance.com/api/v1/executions \
  -H "Authorization: Bearer $N8N_API_KEY" | \
  jq ".data[] | select(.data.ticket_id==\"$TICKET_ID\")"

# Check GitHub PR
echo ""
echo "=== GitHub PR ==="
gh pr list --search "PKG-$TICKET_ID" --json number,title,state

# Check Jenkins build
echo ""
echo "=== Jenkins Build ==="
curl -s http://your-jenkins:8080/api/json | \
  jq ".jobs[] | select(.name==\"packaging-pipeline\")"
```

---

## Performance Optimization

### Optimizing Workflow Speed

#### Reduce OpenAI Processing Time

```javascript
// In n8n, reduce strings_snippet size
const stringsSnippet = binaryContent.substring(0, 500);  // Reduce from 1000 to 500

// Reduce max_tokens
const maxTokens = 1500;  // Reduce from 2000 to 1500
```

#### Parallelize Processing

```groovy
// In Jenkinsfile, run tests in parallel
parallel(
  'Test Candidate 1': {
    // Test candidate 1
  },
  'Test Candidate 2': {
    // Test candidate 2
  },
  'Test Candidate 3': {
    // Test candidate 3
  }
)
```

#### Cache Dependencies

```groovy
// In Jenkinsfile, cache PSADT
stage('Setup') {
  steps {
    powershell '''
      if (-not (Test-Path "C:\\Program Files\\PSAppDeployToolkit")) {
        # Download and install PSADT
      }
    '''
  }
}
```

### Monitoring Performance

#### Create Performance Dashboard

```bash
#!/bin/bash
# performance-dashboard.sh

echo "=== Workflow Performance Dashboard ==="
echo "Generated: $(date)"
echo ""

# Average execution time
echo "Average Execution Time:"
curl -s https://your-n8n-instance.com/api/v1/executions \
  -H "Authorization: Bearer $N8N_API_KEY" | \
  jq '[.data[] | (.stopTime - .startTime)] | add / length / 1000' | \
  xargs printf "%.2f seconds\n"

# Success rate
echo ""
echo "Success Rate:"
curl -s https://your-n8n-instance.com/api/v1/executions \
  -H "Authorization: Bearer $N8N_API_KEY" | \
  jq 'length as $total | [.data[] | select(.finished==true)] | length / $total * 100' | \
  xargs printf "%.1f%%\n"

# Requests per hour
echo ""
echo "Requests per Hour:"
curl -s https://your-n8n-instance.com/api/v1/executions \
  -H "Authorization: Bearer $N8N_API_KEY" | \
  jq '[.data[] | select(.startTime > (now - 3600000))] | length'
```

---

## Maintenance and Updates

### Regular Maintenance Tasks

#### Weekly

- Review failed executions and fix issues
- Check API quota usage
- Verify all agents are online
- Review PR queue

#### Monthly

- Update dependencies and security patches
- Analyze performance metrics
- Review and optimize costs
- Conduct team training

#### Quarterly

- Major version updates
- Architecture review
- Capacity planning
- Security audit

### Backup and Recovery

#### Backup Strategy

```bash
#!/bin/bash
# backup-strategy.sh

# Daily: Backup GitHub repository
git clone --mirror https://github.com/your-org/packaging-repo.git \
  /backups/daily/packaging-repo-$(date +%Y%m%d).git

# Weekly: Backup n8n workflows
curl -s https://your-n8n-instance.com/api/v1/workflows \
  -H "Authorization: Bearer $N8N_API_KEY" > \
  /backups/weekly/n8n-workflows-$(date +%Y%m%d).json

# Monthly: Full system backup
tar -czf /backups/monthly/full-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/jenkins /var/lib/n8n /backups/
```

#### Recovery Procedures

```bash
# Restore from backup
tar -xzf /backups/monthly/full-backup-20231201.tar.gz -C /

# Restore GitHub repository
git clone /backups/daily/packaging-repo-20231201.git your-repo

# Restore n8n workflows
curl -X POST https://your-n8n-instance.com/api/v1/workflows/import \
  -H "Authorization: Bearer $N8N_API_KEY" \
  -d @/backups/weekly/n8n-workflows-20231201.json
```

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Author:** Manus AI
