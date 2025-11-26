# AI-Assisted Application Packaging Workflow: Implementation Guide

**Author:** Manus AI  
**Version:** 1.0  
**Last Updated:** November 2025

## Table of Contents

1. [Overview](#overview)
2. [Architecture and Components](#architecture-and-components)
3. [Prerequisites and Environment Setup](#prerequisites-and-environment-setup)
4. [Component Configuration](#component-configuration)
5. [Data Structures and Schemas](#data-structures-and-schemas)
6. [Code Examples and Implementation Details](#code-examples-and-implementation-details)
7. [Integration and Deployment](#integration-and-deployment)
8. [References](#references)

---

## Overview

The AI-Assisted Application Packaging Workflow is a modern, end-to-end automation system that leverages Large Language Models (LLMs) to dramatically reduce the time and effort required to create enterprise application packages. The workflow combines four core technologies—**n8n**, **OpenAI API**, **GitHub**, and **Jenkins**—to create a fully automated, auditable, and human-validated packaging pipeline.

### Key Objectives

The workflow addresses a critical pain point in IT operations: **discovering silent installation switches** for third-party applications. Traditionally, packaging engineers spend hours researching installer frameworks, testing command-line switches, and documenting installation procedures. This workflow automates that discovery process using AI while maintaining human oversight through pull request reviews and automated testing.

### Core Value Proposition

- **Speed:** Package candidates are generated and tested in minutes, not hours
- **Consistency:** Structured JSON output ensures uniform, auditable artifacts
- **Reliability:** Automated testing validates AI-generated commands before deployment
- **Auditability:** Every step from initial request to final test is logged and traceable
- **Human-in-the-Loop:** Expert review gates ensure quality before production deployment

---

## Architecture and Components

### System Architecture Overview

The workflow follows a linear, event-driven architecture with clear separation of concerns:

```
┌─────────────┐      ┌──────────┐      ┌─────────┐      ┌────────┐      ┌─────────┐      ┌────────┐
│   Webhook   │─────▶│   n8n    │─────▶│ OpenAI  │─────▶│ GitHub │─────▶│ Jenkins │─────▶│ Result │
│   Intake    │      │  Engine  │      │   API   │      │   PR   │      │  Tests  │      │ Feedback│
└─────────────┘      └──────────┘      └─────────┘      └────────┘      └─────────┘      └────────┘
```

### Component Responsibilities

| Component | Primary Role | Key Responsibilities |
| :--- | :--- | :--- |
| **Webhook (n8n)** | Request Entry Point | Receive packaging requests, validate input, initiate workflow |
| **n8n Orchestration** | Data Pipeline | Download installers, extract metadata, construct LLM prompts, manage state |
| **OpenAI API** | AI Analysis | Analyze installer metadata, propose silent commands, generate PSADT scripts |
| **GitHub** | Version Control & Collaboration | Store artifacts, open PRs, trigger CI/CD, enable human review |
| **Jenkins** | Continuous Integration | Lint code, build packages, execute tests, report results |

### Data Flow

The workflow processes data through several transformation stages:

1. **Intake Stage:** Raw request data (URL, ticket ID, release notes) enters via webhook
2. **Metadata Extraction:** n8n downloads the installer and extracts technical metadata (file type, size, SHA256, strings)
3. **AI Analysis:** OpenAI processes metadata and generates structured JSON output (manifest, candidates, PSADT skeleton)
4. **Artifact Storage:** Generated files are committed to GitHub and organized in a branch
5. **Testing:** Jenkins executes the generated scripts in an isolated Windows environment
6. **Feedback:** Test results are reported back to the GitHub PR for human review

---

## Prerequisites and Environment Setup

### Required Software and Services

Before implementing the workflow, ensure you have access to the following:

**Development and Version Control:**
- Git (version 2.30 or later)
- GitHub account with repository creation and webhook management permissions
- GitHub CLI (`gh`) for command-line repository operations

**CI/CD Infrastructure:**
- Jenkins controller (version 2.300 or later) with administrative access
- Windows agent or ephemeral VM capability (Azure, AWS, GCP)
- PowerShell 7 or later on Windows agents
- PSAppDeployToolkit (PSADT) pre-installed on Windows agents

**Workflow Orchestration:**
- n8n Cloud account (free tier sufficient for initial setup)
- n8n credentials management for storing API keys securely
- HTTP request capability and webhook support

**AI and Language Model:**
- OpenAI API account with GPT-4 or GPT-4o-mini access
- Valid API key with sufficient quota for development and testing
- Understanding of prompt engineering and JSON schema validation

**Storage and Artifacts:**
- Cloud storage solution (S3, Azure Blob Storage, or equivalent) for installer binaries
- Sufficient storage quota for build artifacts and test logs

### Environment Variables and Secrets Management

Store the following secrets securely in your n8n vault or Jenkins credentials store:

```bash
# OpenAI API Configuration
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxx
OPENAI_MODEL=gpt-4o-mini
OPENAI_TEMPERATURE=0.1

# GitHub Configuration
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
GITHUB_REPO_OWNER=your-org
GITHUB_REPO_NAME=packaging-repo

# n8n Configuration
N8N_WEBHOOK_URL=https://your-n8n-instance.com/webhook/packaging-intake
N8N_EXECUTION_LOG_PATH=/var/log/n8n/executions

# Jenkins Configuration
JENKINS_WINDOWS_AGENT_LABEL=windows
JENKINS_WORKSPACE_PATH=C:\jenkins\workspace
PSADT_INSTALL_PATH=C:\Program Files\PSAppDeployToolkit

# Storage Configuration
STORAGE_PROVIDER=s3  # or azure-blob
STORAGE_BUCKET=packaging-artifacts
STORAGE_REGION=us-east-1
```

### Windows Agent Prerequisites

The Jenkins Windows agent must have the following pre-installed:

```powershell
# PowerShell 7+
pwsh --version

# PSAppDeployToolkit
Test-Path "C:\Program Files\PSAppDeployToolkit\AppDeployToolkitMain.ps1"

# PSScriptAnalyzer (for linting)
Get-Module -ListAvailable PSScriptAnalyzer

# Additional tools for binary analysis
# - sigcheck (Sysinternals)
# - lessmsi (for MSI inspection)
# - 7-Zip (for archive extraction)
```

---

## Component Configuration

### n8n Workflow Configuration

The n8n workflow orchestrates the entire packaging pipeline. Below is a detailed breakdown of the workflow structure and configuration.

#### Webhook Node Configuration

The webhook serves as the entry point for packaging requests. Configure it with the following settings:

**Webhook Path:** `/webhook/packaging-intake`

**Authentication:** Basic authentication or API key (configure in n8n security settings)

**Expected Payload Structure:**

```json
{
  "ticket_id": "PKG-123",
  "installer_url": "https://vendor.example/MyAppSetup.exe",
  "release_notes": "MyApp v3.2.1 - requires .NET 6",
  "requested_by": "packager@company.com",
  "metadata": {
    "vendor": "MyCompany",
    "product_name": "MyApp",
    "expected_version": "3.2.1"
  }
}
```

**Response Configuration:**

```json
{
  "status": "accepted",
  "ticket_id": "{{ $json.ticket_id }}",
  "pr_url": "{{ $json.pr_url }}",
  "message": "Packaging request received. Check PR for status."
}
```

#### HTTP Request Node: Installer Download

This node downloads the installer binary and computes its SHA256 checksum.

**Configuration:**

```
Method: GET
URL: {{ $json.installer_url }}
Headers:
  - User-Agent: n8n-packaging-workflow/1.0
Response Format: File
Save to Storage: true
Storage Path: artifacts/{{ $json.ticket_id }}/{{ $json.installer_url | split('/') | last }}
```

**Post-Processing:**

After download, compute the SHA256 checksum using a Function node:

```javascript
// Function Node: Compute Checksum
const crypto = require('crypto');
const fs = require('fs');

const filePath = items[0].binary.data.path;
const fileBuffer = fs.readFileSync(filePath);
const hash = crypto.createHash('sha256').update(fileBuffer).digest('hex');

return [
  {
    ...items[0],
    json: {
      ...items[0].json,
      checksum: `sha256:${hash}`,
      file_size: fileBuffer.length,
      file_path: filePath
    }
  }
];
```

#### Function Node: Metadata Extraction

Extract technical metadata from the installer binary to inform the LLM's analysis.

```javascript
// Function Node: Extract Metadata
const fs = require('fs');
const path = require('path');

const filePath = items[0].json.file_path;
const fileName = path.basename(filePath);
const fileExt = path.extname(fileName).toLowerCase();

// Determine file type
let fileType = 'unknown';
if (fileExt === '.exe') fileType = 'exe';
if (fileExt === '.msi') fileType = 'msi';
if (fileExt === '.zip') fileType = 'zip';

// Read first 4KB for strings analysis
const buffer = Buffer.alloc(4096);
const fd = fs.openSync(filePath, 'r');
fs.readSync(fd, buffer, 0, 4096);
fs.closeSync(fd);

// Search for installer framework markers
const stringsSnippet = buffer.toString('utf8', 0, 4096).replace(/\0/g, '');
const frameworks = {
  inno: /Inno Setup/.test(stringsSnippet),
  nsis: /NSIS/.test(stringsSnippet),
  installshield: /InstallShield/.test(stringsSnippet),
  wix: /WiX/.test(stringsSnippet),
  burn: /Burn/.test(stringsSnippet)
};

return [
  {
    ...items[0],
    json: {
      ...items[0].json,
      file_type: fileType,
      strings_snippet: stringsSnippet.substring(0, 1000),
      detected_frameworks: Object.keys(frameworks).filter(k => frameworks[k])
    }
  }
];
```

#### OpenAI Node: LLM Analysis

Configure the OpenAI node to generate structured JSON output for the packaging manifest and candidate commands.

**Model Configuration:**

```
Model: gpt-4o-mini
Temperature: 0.1  (for deterministic output)
Max Tokens: 2000
```

**System Message:**

```text
You are a packaging assistant specializing in Windows application deployment. 
Your task is to analyze installer metadata and generate a JSON response that 
strictly conforms to the provided schema. Output ONLY valid JSON—no comments, 
explanations, or additional text. If uncertain about a field, set it to "TODO" 
and set human_review to true. Use confidence values between 0.0 and 1.0.
```

**User Message Template:**

```text
Analyze the following installer and generate packaging metadata:

SCHEMA:
{
  "manifest": {
    "product": "string",
    "vendor": "string",
    "version": "string",
    "source_url": "string",
    "checksum": "string",
    "install_context": "System|User",
    "prereqs": ["string"],
    "human_review": boolean,
    "notes": "string",
    "product_code": "string",
    "uninstall_command": "string",
    "verification_hints": ["string"],
    "confidence_overall": 0.0-1.0
  },
  "candidates": [
    {
      "id": "string",
      "command": "string",
      "framework": "MSI|Inno|NSIS|InstallShield|Burn|Custom|Unknown",
      "confidence": 0.0-1.0,
      "rationale": "string"
    }
  ],
  "psadt_skeleton": "string",
  "extraction": {
    "file_type": "exe|msi|zip|unknown",
    "strings_matches": ["string"],
    "detected_frameworks": ["string"]
  }
}

INSTALLER METADATA:
- Filename: {{ $json.installer_filename }}
- File Type: {{ $json.file_type }}
- File Size: {{ $json.file_size }} bytes
- SHA256: {{ $json.checksum }}
- MIME Type: {{ $json.mime_type }}
- Detected Frameworks: {{ $json.detected_frameworks | join(', ') }}
- Strings Snippet: {{ $json.strings_snippet }}
- Release Notes: {{ $json.release_notes }}

TASK:
1. Propose 2-3 candidate silent install commands, ordered by confidence (highest first)
2. Fill out the manifest with product details; set human_review=true if confidence < 0.80
3. Generate a PSADT Deploy-Application.ps1 skeleton that uses the primary candidate
4. Return ONLY valid JSON matching the schema above
```

#### GitHub Node: Create Branch and Commit

Configure the GitHub node to automatically create a branch and commit the AI-generated artifacts.

**Branch Naming Convention:**

```
ai/PKG-{{ $json.ticket_id }}-{{ $json.checksum | substring(0, 8) }}
```

**Files to Commit:**

```
products/{{ $json.manifest.product }}/manifest.json
products/{{ $json.manifest.product }}/candidates.json
products/{{ $json.manifest.product }}/Deploy-Application.ps1
products/{{ $json.manifest.product }}/README_AI.md
```

**Commit Message:**

```
[AI-Generated] Package {{ $json.manifest.product }} v{{ $json.manifest.version }}

Ticket: {{ $json.ticket_id }}
Confidence: {{ $json.manifest.confidence_overall }}
Human Review Required: {{ $json.manifest.human_review }}

Generated by AI-Assisted Packaging Workflow
```

#### GitHub Node: Create Pull Request

Open a pull request with appropriate labels and description.

**PR Title:**

```
[AI] {{ $json.manifest.product }} v{{ $json.manifest.version }} - {{ $json.ticket_id }}
```

**PR Description:**

```markdown
## Packaging Request

**Ticket:** {{ $json.ticket_id }}  
**Product:** {{ $json.manifest.product }}  
**Vendor:** {{ $json.manifest.vendor }}  
**Version:** {{ $json.manifest.version }}  

### AI Analysis Results

- **Overall Confidence:** {{ $json.manifest.confidence_overall }}
- **Human Review Required:** {{ $json.manifest.human_review }}
- **Detected Frameworks:** {{ $json.extraction.detected_frameworks | join(', ') }}

### Candidate Commands

{{ $json.candidates | map(c => `- [${c.confidence}] ${c.command} (${c.framework})`).join('\n') }}

### Next Steps

1. Review the generated manifest and candidates
2. Verify the PSADT script logic
3. Merge to trigger Jenkins testing
4. Check test results in the build artifacts

### Files Modified

- `products/{{ $json.manifest.product }}/manifest.json`
- `products/{{ $json.manifest.product }}/candidates.json`
- `products/{{ $json.manifest.product }}/Deploy-Application.ps1`
```

**Labels:**

```
- ai-generated
- {{ $json.manifest.human_review ? 'needs-review' : 'ready-to-test' }}
```

---

### OpenAI API Configuration Details

#### Model Selection and Parameters

The workflow uses **GPT-4o-mini** as the primary model due to its balance of capability and cost-efficiency. The following parameters are critical for reliable output:

| Parameter | Value | Rationale |
| :--- | :--- | :--- |
| Model | gpt-4o-mini | Cost-effective, sufficient for structured analysis |
| Temperature | 0.1 | Low temperature ensures deterministic, consistent output |
| Max Tokens | 2000 | Sufficient for manifest + candidates + PSADT skeleton |
| Top P | 1.0 | Default; ensures diversity within low-temperature constraint |
| Frequency Penalty | 0.0 | No penalty; allows repetition of technical terms |
| Presence Penalty | 0.0 | No penalty; allows discussion of relevant concepts |

#### Prompt Engineering Best Practices

The system and user messages are carefully crafted to maximize the LLM's ability to generate valid, structured output:

**System Message Principles:**

- **Strict Output Format:** Explicitly state "Output ONLY valid JSON—no comments, explanations, or additional text"
- **Schema Reference:** Include the exact JSON schema the model must conform to
- **Fallback Behavior:** Define how to handle uncertainty (set to "TODO", set human_review=true)
- **Confidence Scoring:** Provide clear guidance on confidence values (0.0–1.0 range)

**User Message Principles:**

- **Structured Input:** Present installer metadata in a clear, labeled format
- **Task Decomposition:** Break the analysis into numbered steps (propose candidates, fill manifest, generate skeleton, output JSON)
- **Context Provision:** Include release notes, detected frameworks, and strings snippets to inform analysis
- **Schema Reminder:** Repeat the schema in the user message to reinforce output format requirements

#### Handling Model Failures and Validation

Implement the following validation logic after receiving the OpenAI response:

```javascript
// Function Node: Validate LLM Output
try {
  const response = items[0].json.choices[0].message.content;
  const parsed = JSON.parse(response);
  
  // Validate against schema
  if (!parsed.manifest || !parsed.candidates || !parsed.psadt_skeleton) {
    throw new Error('Missing required fields in LLM output');
  }
  
  // Validate manifest structure
  const requiredFields = ['product', 'vendor', 'version', 'source_url', 'checksum', 'install_context'];
  for (const field of requiredFields) {
    if (!parsed.manifest[field]) {
      throw new Error(`Missing required manifest field: ${field}`);
    }
  }
  
  // Validate candidates
  if (!Array.isArray(parsed.candidates) || parsed.candidates.length === 0) {
    throw new Error('No candidate commands generated');
  }
  
  for (const candidate of parsed.candidates) {
    if (!candidate.command || typeof candidate.confidence !== 'number') {
      throw new Error('Invalid candidate structure');
    }
  }
  
  return [{ json: { ...items[0].json, validation_passed: true, parsed_output: parsed } }];
} catch (error) {
  // Mark for human review on validation failure
  return [{ 
    json: { 
      ...items[0].json, 
      validation_passed: false, 
      validation_error: error.message,
      human_review: true,
      raw_ai_output: items[0].json.choices[0].message.content
    } 
  }];
}
```

---

### Jenkins Pipeline Configuration

The Jenkins pipeline automates code quality checks and installation testing. Below is a detailed Jenkinsfile configuration:

```groovy
pipeline {
  agent { label 'windows' }
  
  parameters {
    string(name: 'PRODUCT_NAME', description: 'Product name from manifest')
    string(name: 'BRANCH_NAME', description: 'Git branch to test')
  }
  
  environment {
    PSADT_PATH = 'C:\\Program Files\\PSAppDeployToolkit'
    WORKSPACE_PATH = "${WORKSPACE}\\${PRODUCT_NAME}"
    TEST_OUTPUT_PATH = "${WORKSPACE}\\test-output"
  }
  
  stages {
    stage('Checkout') {
      steps {
        checkout([
          $class: 'GitSCM',
          branches: [[name: "origin/${BRANCH_NAME}"]],
          userRemoteConfigs: [[url: 'https://github.com/your-org/packaging-repo.git']]
        ])
      }
    }
    
    stage('Validate Manifest') {
      steps {
        powershell '''
          $manifestPath = "products\\${env:PRODUCT_NAME}\\manifest.json"
          if (-not (Test-Path $manifestPath)) {
            throw "Manifest not found: $manifestPath"
          }
          
          $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
          Write-Host "Product: $($manifest.product)"
          Write-Host "Version: $($manifest.version)"
          Write-Host "Human Review: $($manifest.human_review)"
        '''
      }
    }
    
    stage('Lint PowerShell') {
      steps {
        powershell '''
          Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser -ErrorAction Stop
          
          $scriptPath = "products\\${env:PRODUCT_NAME}\\Deploy-Application.ps1"
          $results = Invoke-ScriptAnalyzer -Path $scriptPath -Severity Warning
          
          if ($results.Count -gt 0) {
            Write-Host "Linting warnings found:"
            $results | Format-Table -AutoSize
          }
        '''
      }
    }
    
    stage('Build Package') {
      steps {
        powershell '''
          New-Item -Path "${env:WORKSPACE_PATH}" -ItemType Directory -Force | Out-Null
          Copy-Item -Path "products\\${env:PRODUCT_NAME}\\*" -Destination "${env:WORKSPACE_PATH}\\" -Recurse
          
          Compress-Archive -Path "${env:WORKSPACE_PATH}\\*" `
            -DestinationPath "${env:WORKSPACE}\\${env:PRODUCT_NAME}.zip" `
            -Force
          
          Write-Host "Package created: ${env:WORKSPACE}\\${env:PRODUCT_NAME}.zip"
        '''
      }
    }
    
    stage('Test Installation') {
      steps {
        powershell '''
          New-Item -Path "${env:TEST_OUTPUT_PATH}" -ItemType Directory -Force | Out-Null
          
          # Run the candidate test script
          & ".\\scripts\\run-candidate-tests.ps1" `
            -ManifestPath "products\\${env:PRODUCT_NAME}\\manifest.json" `
            -CandidatesJson "products\\${env:PRODUCT_NAME}\\candidates.json" `
            -ArtifactDir "products\\${env:PRODUCT_NAME}\\Files"
        '''
      }
    }
    
    stage('Report Results') {
      steps {
        powershell '''
          $resultsPath = "${env:TEST_OUTPUT_PATH}\\candidate-results.json"
          if (Test-Path $resultsPath) {
            $results = Get-Content $resultsPath -Raw | ConvertFrom-Json
            Write-Host "Test Results:"
            $results | ConvertTo-Json -Depth 5 | Write-Host
            
            $successCount = ($results | Where-Object { $_.verified -eq $true }).Count
            if ($successCount -gt 0) {
              Write-Host "SUCCESS: At least one candidate succeeded"
              exit 0
            } else {
              Write-Host "FAILURE: No candidates succeeded"
              exit 1
            }
          }
        '''
      }
    }
  }
  
  post {
    always {
      archiveArtifacts artifacts: 'test-output/**/*', allowEmptyArchive: true
      archiveArtifacts artifacts: '*.zip', allowEmptyArchive: true
    }
    
    failure {
      script {
        currentBuild.result = 'FAILURE'
        // Notify PR with failure status
      }
    }
    
    success {
      script {
        currentBuild.result = 'SUCCESS'
        // Notify PR with success status
      }
    }
  }
}
```

---

## Data Structures and Schemas

### Manifest Schema

The manifest is the authoritative record of an application package. It contains all metadata required for deployment and verification.

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "product": {
      "type": "string",
      "description": "Application name (e.g., 'Microsoft Office', 'Adobe Reader')"
    },
    "vendor": {
      "type": "string",
      "description": "Software vendor or publisher"
    },
    "version": {
      "type": "string",
      "description": "Application version (e.g., '2023.1.0')"
    },
    "source_url": {
      "type": "string",
      "format": "uri",
      "description": "URL where the installer can be downloaded"
    },
    "checksum": {
      "type": "string",
      "pattern": "^sha256:[a-f0-9]{64}$",
      "description": "SHA256 hash of the installer for integrity verification"
    },
    "install_context": {
      "type": "string",
      "enum": ["System", "User"],
      "description": "Installation scope: System-wide or User-specific"
    },
    "prereqs": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Prerequisites (e.g., '.NET Framework 4.8', 'Visual C++ Redistributable')"
    },
    "human_review": {
      "type": "boolean",
      "description": "Flag indicating whether human review is required before deployment"
    },
    "notes": {
      "type": "string",
      "description": "Additional notes or observations from AI analysis"
    },
    "product_code": {
      "type": "string",
      "description": "Windows product code (GUID) for MSI-based applications"
    },
    "uninstall_command": {
      "type": "string",
      "description": "Silent uninstall command for removal"
    },
    "verification_hints": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Paths or registry keys to verify successful installation"
    },
    "confidence_overall": {
      "type": "number",
      "minimum": 0,
      "maximum": 1,
      "description": "Overall confidence score (0.0–1.0) for the packaging accuracy"
    }
  },
  "required": [
    "product",
    "vendor",
    "version",
    "source_url",
    "checksum",
    "install_context",
    "human_review"
  ]
}
```

### Candidates Schema

Candidates represent alternative silent installation commands, each with a confidence score and rationale.

```json
{
  "type": "array",
  "items": {
    "type": "object",
    "properties": {
      "id": {
        "type": "string",
        "description": "Unique identifier for this candidate (e.g., '1', '2')"
      },
      "command": {
        "type": "string",
        "description": "Silent installation command with <installer> placeholder"
      },
      "framework": {
        "type": "string",
        "enum": ["MSI", "Inno", "NSIS", "InstallShield", "Burn", "Custom", "Unknown"],
        "description": "Detected installer framework"
      },
      "confidence": {
        "type": "number",
        "minimum": 0,
        "maximum": 1,
        "description": "Confidence score (0.0–1.0) for this candidate's success"
      },
      "rationale": {
        "type": "string",
        "description": "Explanation for the proposed command and confidence score"
      }
    },
    "required": ["id", "command", "framework", "confidence", "rationale"]
  }
}
```

### PSADT Script Template

The PSADT script is the deployment vehicle for the application. It uses the candidates to attempt installation and verify success.

```powershell
<#
.SYNOPSIS
  PSADT-based deployment script generated by AI-Assisted Packaging Workflow
  
.DESCRIPTION
  This script handles installation, uninstallation, and verification of the application.
  It uses the candidates.json file to attempt installation with multiple command variants.
  
.PARAMETER DeployMode
  Install or Uninstall mode
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)]
  [ValidateSet('Install', 'Uninstall')]
  [string]$DeployMode = 'Install'
)

# Load App Deploy Toolkit
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Try {
  . "$scriptDir\PSAppDeployToolkit\AppDeployToolkitMain.ps1"
} Catch {
  Write-Error 'PSAppDeployToolkit not found'
  Throw
}

# Load configuration
$manifest = Get-Content -Raw -Path "$PSScriptRoot\manifest.json" | ConvertFrom-Json
$installer = Join-Path $PSScriptRoot 'Files\source_installer.exe'
$candidates = @()

if (Test-Path "$PSScriptRoot\candidates.json") {
  $candidates = Get-Content "$PSScriptRoot\candidates.json" -Raw | ConvertFrom-Json
}

Function Install-Application {
  Write-Log -Message "Installing $($manifest.product) $($manifest.version)" -Severity 'INFO'
  
  if ($candidates.Count -eq 0) {
    Throw "No candidate install commands found"
  }
  
  # Sort candidates by confidence (highest first)
  $sortedCandidates = $candidates | Sort-Object -Property @{Expression={[double]$_.confidence}} -Descending
  
  $installSuccess = $false
  
  foreach ($candidate in $sortedCandidates) {
    Write-Log -Message "Attempting candidate $($candidate.id): $($candidate.framework)" -Severity 'INFO'
    
    Try {
      $cmd = $candidate.command -replace '<installer>', $installer
      Write-Log -Message "Command: $cmd" -Severity 'DEBUG'
      
      # Execute the installation command
      Execute-Process -Path "powershell.exe" `
        -Parameters "-NoProfile -ExecutionPolicy Bypass -Command `"& { $cmd }`"" `
        -WindowStyle Hidden `
        -Wait `
        -ErrorAction Stop
      
      # Wait for installation to complete
      Start-Sleep -Seconds 5
      
      # Verify installation
      if (Verify-Installation) {
        Write-Log -Message "Installation verified successfully" -Severity 'INFO'
        $installSuccess = $true
        break
      } else {
        Write-Log -Message "Installation verification failed for candidate $($candidate.id)" -Severity 'WARN'
      }
    } Catch {
      Write-Log -Message "Candidate $($candidate.id) failed: $($_.Exception.Message)" -Severity 'WARN'
      Continue
    }
  }
  
  if (-not $installSuccess) {
    Throw "Installation failed: no candidate succeeded"
  }
  
  return $true
}

Function Uninstall-Application {
  Write-Log -Message "Uninstalling $($manifest.product)" -Severity 'INFO'
  
  if ($manifest.uninstall_command) {
    Try {
      Execute-Process -Path "powershell.exe" `
        -Parameters "-NoProfile -ExecutionPolicy Bypass -Command `"$($manifest.uninstall_command)`"" `
        -WindowStyle Hidden `
        -Wait `
        -ErrorAction Stop
      
      Write-Log -Message "Uninstallation completed" -Severity 'INFO'
    } Catch {
      Write-Log -Message "Uninstallation error: $($_.Exception.Message)" -Severity 'ERROR'
      Throw
    }
  } else {
    Write-Log -Message "No uninstall command provided in manifest" -Severity 'WARN'
  }
}

Function Verify-Installation {
  Write-Log -Message "Verifying installation..." -Severity 'INFO'
  
  # Check verification hints from manifest
  if ($manifest.verification_hints -and $manifest.verification_hints.Count -gt 0) {
    foreach ($hint in $manifest.verification_hints) {
      if (Test-Path $hint) {
        Write-Log -Message "Verification OK: $hint" -Severity 'INFO'
        return $true
      }
    }
    return $false
  }
  
  # Fallback: check default installation path
  $defaultPath = "C:\Program Files\$($manifest.product)\$($manifest.product).exe"
  if (Test-Path $defaultPath) {
    Write-Log -Message "Verification OK: $defaultPath" -Severity 'INFO'
    return $true
  }
  
  return $false
}

# Main execution
Try {
  Switch ($DeployMode) {
    'Install' {
      if (-not (Install-Application)) {
        Throw 'Installation failed'
      }
    }
    'Uninstall' {
      Uninstall-Application
    }
  }
  
  Write-Log -Message "$DeployMode completed successfully" -Severity 'INFO'
  Exit-Script -ExitCode 0
} Catch {
  Write-Log -Message "Error: $($_.Exception.Message)" -Severity 'ERROR'
  Exit-Script -ExitCode 70000
}
```

---

## Code Examples and Implementation Details

### Example 1: Complete Workflow Request

This example demonstrates a complete packaging request from intake to PR creation.

**Webhook Request:**

```bash
curl -X POST https://your-n8n-instance.com/webhook/packaging-intake \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "ticket_id": "PKG-2025-001",
    "installer_url": "https://download.mozilla.org/firefox/releases/latest/win64/en-US/Firefox%20Setup%20Latest.exe",
    "release_notes": "Firefox 123.0 - Security and stability updates",
    "requested_by": "packaging-team@company.com",
    "metadata": {
      "vendor": "Mozilla",
      "product_name": "Firefox",
      "expected_version": "123.0"
    }
  }'
```

**Expected n8n Workflow Execution:**

1. Webhook receives request and validates payload
2. HTTP Request node downloads Firefox installer (approximately 50 MB)
3. Function node computes SHA256 checksum and extracts metadata
4. Metadata extraction identifies NSIS framework markers in binary
5. OpenAI node receives prompt with metadata and generates JSON response
6. Validation node confirms JSON structure and required fields
7. GitHub node creates branch `ai/PKG-2025-001-a1b2c3d4` and commits files
8. GitHub node opens PR with labels `ai-generated` and `ready-to-test`
9. Webhook responds with PR URL to caller

**Generated Manifest (excerpt):**

```json
{
  "product": "Firefox",
  "vendor": "Mozilla",
  "version": "123.0",
  "source_url": "https://download.mozilla.org/firefox/releases/latest/win64/en-US/Firefox%20Setup%20Latest.exe",
  "checksum": "sha256:a1b2c3d4e5f6...",
  "install_context": "System",
  "prereqs": [],
  "human_review": false,
  "confidence_overall": 0.95
}
```

**Generated Candidates (excerpt):**

```json
[
  {
    "id": "1",
    "command": "<installer> /S",
    "framework": "NSIS",
    "confidence": 0.95,
    "rationale": "NSIS framework detected in binary strings. Standard /S flag for silent installation."
  },
  {
    "id": "2",
    "command": "<installer> -ms",
    "framework": "NSIS",
    "confidence": 0.70,
    "rationale": "Alternative NSIS silent flag. Less common but supported."
  }
]
```

### Example 2: Handling Low-Confidence Output

When the LLM is uncertain about installation methods, it marks the package for human review.

**Scenario:** Proprietary installer with no recognized framework markers

**Generated Manifest (excerpt):**

```json
{
  "product": "ProprietaryApp",
  "vendor": "UnknownVendor",
  "version": "1.0.0",
  "source_url": "https://example.com/ProprietaryApp.exe",
  "checksum": "sha256:...",
  "install_context": "System",
  "human_review": true,
  "notes": "Unknown installer framework. No standard silent switches detected. Manual testing required.",
  "confidence_overall": 0.35
}
```

**Generated Candidates (excerpt):**

```json
[
  {
    "id": "1",
    "command": "<installer> /quiet",
    "framework": "Custom",
    "confidence": 0.40,
    "rationale": "Generic /quiet flag. Common across many installers but not verified for this application."
  },
  {
    "id": "2",
    "command": "<installer> -silent",
    "framework": "Custom",
    "confidence": 0.30,
    "rationale": "Alternative generic flag. Lower confidence due to lack of framework identification."
  }
]
```

**PR Label:** `needs-review` (automatically applied due to human_review=true)

**Packaging Engineer Action:** Review the candidates, test manually if needed, and update the manifest with verified commands before merging.

### Example 3: Jenkins Test Execution and Reporting

This example shows how Jenkins executes the test script and reports results.

**Test Execution Log:**

```
[Pipeline] stage('Test Installation')
[Pipeline] {
[Pipeline] powershell
  Trying candidate 1 - <installer> /S
  Exit code: 0
  Verification: Checking C:\Program Files\Firefox\firefox.exe
  Verification: SUCCESS
  
  Test Results Summary:
  - Candidate 1: SUCCESS (exit=0, verified=true)
  
  Overall Result: SUCCESS
  
  Candidate Results saved to: test-output/candidate-results.json
```

**Candidate Results JSON:**

```json
[
  {
    "id": "1",
    "command": "C:\\jenkins\\workspace\\Firefox\\Files\\source_installer.exe /S",
    "exit": 0,
    "out": "[Installation output log content]",
    "verified": true,
    "duration_seconds": 45
  }
]
```

**GitHub PR Status Update:**

```
✓ All checks passed
  - Lint: PASSED
  - Build: PASSED
  - Test Installation: PASSED (Candidate 1 succeeded)
```

---

## Integration and Deployment

### Deploying to Production

Once the workflow is configured and tested, follow these steps to deploy to production:

#### Step 1: Repository Setup

Create a dedicated GitHub repository for packaging artifacts:

```bash
gh repo create packaging-repo \
  --public \
  --description "AI-Assisted Application Packaging Repository" \
  --gitignore PowerShell \
  --license MIT

cd packaging-repo

# Create directory structure
mkdir -p templates/psadt-template
mkdir -p templates/n8n-workflows
mkdir -p scripts
mkdir -p docs
mkdir -p products

# Copy templates from the automation repository
cp -r ../Packaging-Workflow-Automation/templates/* templates/
cp -r ../Packaging-Workflow-Automation/scripts/* scripts/
cp ../Packaging-Workflow-Automation/Jenkinsfile .

# Commit initial structure
git add .
git commit -m "Initial packaging repository structure"
git push origin main
```

#### Step 2: n8n Workflow Deployment

Import and configure the n8n workflow:

1. Log in to n8n Cloud
2. Click **Workflows** → **Import**
3. Upload `templates/n8n-workflows/intake-openai.json`
4. Configure credentials:
   - **OpenAI:** Paste your API key
   - **GitHub:** Create a personal access token with `repo` and `workflow` scopes
   - **Storage:** Configure S3 or Azure Blob credentials
5. Update webhook URL in the Webhook node (copy the URL from n8n)
6. Test the workflow with a sample request
7. Activate the workflow

#### Step 3: Jenkins Configuration

Set up Jenkins to run the packaging pipeline:

1. **Install Plugins:**
   - GitHub Integration
   - GitHub Branch Source
   - PowerShell
   - Pipeline

2. **Create Windows Agent:**
   ```bash
   # On Windows agent machine
   java -jar agent.jar -jnlpUrl https://your-jenkins/computer/windows-agent/slave-agent.jnlp -secret YOUR_SECRET
   ```

3. **Create Pipeline Job:**
   - Job name: `packaging-pipeline`
   - Pipeline script from SCM: GitHub
   - Repository URL: `https://github.com/your-org/packaging-repo.git`
   - Script path: `Jenkinsfile`
   - Build triggers: GitHub push event

4. **Configure GitHub Webhook:**
   - Repository Settings → Webhooks
   - Payload URL: `https://your-jenkins/github-webhook/`
   - Content type: `application/json`
   - Events: Push, Pull request

#### Step 4: GitHub Webhook Configuration

Configure GitHub to trigger n8n on packaging requests:

1. Repository Settings → Webhooks
2. Add webhook:
   - Payload URL: `https://your-n8n-instance.com/webhook/packaging-intake`
   - Content type: `application/json`
   - Events: Custom (select `Issue comments`)
   - Active: ✓

#### Step 5: Security and Access Control

Implement security best practices:

**n8n:**
- Enable authentication on the webhook
- Store API keys in n8n's secure vault
- Restrict webhook access to GitHub IPs

**Jenkins:**
- Enable authentication and authorization
- Use Jenkins credentials store for sensitive data
- Restrict pipeline execution to authorized users

**GitHub:**
- Require pull request reviews before merge
- Enforce branch protection rules
- Enable status checks (Jenkins, linting)

---

## References

1. [PSAppDeployToolkit Documentation](https://psappdeploytoolkit.com/) — Official documentation for the PowerShell App Deployment Toolkit
2. [n8n Workflow Automation](https://n8n.io/) — n8n platform for workflow automation and integration
3. [OpenAI API Documentation](https://platform.openai.com/docs/) — Official OpenAI API reference and guides
4. [GitHub REST API](https://docs.github.com/en/rest) — GitHub API for repository and pull request management
5. [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/) — Jenkins pipeline as code reference
6. [PowerShell Script Analyzer](https://github.com/PowerShell/PSScriptAnalyzer) — PowerShell linting and best practices tool
7. [JSON Schema Specification](https://json-schema.org/) — JSON Schema validation standard

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Author:** Manus AI
