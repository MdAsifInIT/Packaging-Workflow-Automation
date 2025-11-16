<#
.SYNOPSIS
  PSADT template - Edit before production.
#>

# Load App Deploy Toolkit
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Try { . "$scriptDir\PSAppDeployToolkit\AppDeployToolkitMain.ps1" } Catch { Write-Error 'PSAppDeployToolkit not found'; Throw }

$manifest = Get-Content -Raw -Path "$PSScriptRoot\manifest.json" | ConvertFrom-Json
$installer = Join-Path $PSScriptRoot 'Files\source_installer.exe'
$candidates = @()
if (Test-Path "$PSScriptRoot\candidates.json") {
    $candidates = Get-Content "$PSScriptRoot\candidates.json" -Raw | ConvertFrom-Json
}

Try {
    Write-Log -Message "Installing $($manifest.product) $($manifest.version)" -Severity 'INFO'
    if ($candidates.Count -gt 0) {
        $cmd = $candidates[0].command -replace '<installer>', $installer
        Execute-Process -Path "powershell.exe" -Parameters "-NoProfile -ExecutionPolicy Bypass -Command `"& { $cmd }`"" -WindowStyle Hidden -Wait -ErrorAction Stop
    } else {
        Throw "No candidate install command found"
    }

    # Basic verification (override as needed)
    $installedPath = "C:\Program Files\$($manifest.product)\$($manifest.product).exe"
    If (Test-Path $installedPath) {
        Write-Log -Message "Install verified: $installedPath" -Severity 'INFO'
    } else {
        Throw "Install verification failed: $installedPath not found"
    }
} Catch {
    Write-Log -Message "Install failed: $($_.Exception.Message)" -Severity 'ERROR'
    Exit 1
}
