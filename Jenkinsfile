pipeline {
  agent { label 'windows' }   // use a label that points to a clean Windows worker or plugin to start ephemeral VM
  options { timestamps() }
  parameters {
    string(name: 'PRODUCT', defaultValue: '', description: 'Product name (from PR or n8n)')
    string(name: 'PR_ID', defaultValue: '', description: 'PR number')
  }
  environment {
    ARTIFACT_DIR = "artifacts"
    OUTPUT_DIR = "test-output"
  }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }
    stage('Lint PS') {
      steps {
        powershell script: 'Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser', returnStatus: true
        powershell script: "Invoke-ScriptAnalyzer -Path .\\products\\${params.PRODUCT}\\Deploy-Application.ps1 || true", returnStatus: true
      }
    }
    stage('Download Installer') {
      steps {
        powershell script: '''
          $m = Get-Content ".\\products\\$env:PRODUCT\\manifest.json" -Raw | ConvertFrom-Json
          $dest = ".\\products\\$env:PRODUCT\\Files\\source_installer.exe"
          Invoke-WebRequest -Uri $m.source_url -OutFile $dest -UseBasicParsing
        '''
      }
    }
    stage('Run candidate tests') {
      steps {
        powershell script: """
          .\\scripts\\run-candidate-tests.ps1 -ManifestPath .\\products\\${params.PRODUCT}\\manifest.json -CandidatesJson .\\products\\${params.PRODUCT}\\candidates.json -ArtifactDir .\\products\\${params.PRODUCT}\\Files -OutputDir .\\${env.OUTPUT_DIR}
        """, returnStatus: false
      }
    }
    stage('Upload Logs') {
      steps {
        archiveArtifacts artifacts: 'test-output/**', allowEmptyArchive: true
      }
    }
  }
  post {
    success { echo 'Verification success' }
    failure { mail to: 'packaging-team@company.com', subject: "Packaging CI failed: ${env.JOB_NAME}", body: "See Jenkins logs" }
  }
}
