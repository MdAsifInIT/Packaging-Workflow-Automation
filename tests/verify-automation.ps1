# Mocking Get-ChildItem to handle Registry and Filesystem
function Get-ChildItem {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true, Position=0)]
        [string]$Path,
        [switch]$Recurse
    )

    # Write-Host "DEBUG: Mock Get-ChildItem called with Path: '$Path'"

    if ($Path -like 'HKLM:*') {
        $mockItem = [PSCustomObject]@{
            Name = "TestAppKey"
        }
        $mockItem | Add-Member -MemberType ScriptMethod -Name "GetValue" -Value {
            param($name, $default)
            # Fail Layer 1 to force downstream checks if needed, or succeed if testing Layer 1
            # For general smoke test, we can let it fail or succeed.
            # If we want to test smoke test, we usually need previous layers to fail or script continues?
            # The script returns on first success.
            # To test smoke test, we should fail earlier layers.
            return $null
        }
        return $mockItem
    }
    elseif ($Path -like "*Start Menu*") {
         return @()
    }
    else {
        if ($Path) {
             return Microsoft.PowerShell.Management\Get-ChildItem -Path $Path
        } else {
             return Microsoft.PowerShell.Management\Get-ChildItem
        }
    }
}

function Test-Path {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]$Path
    )
    # Fail Layer 2
    return $false
}

function Start-Process {
    [CmdletBinding()]
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [switch]$NoNewWindow,
        [switch]$Wait,
        [string]$RedirectStandardOutput,
        [string]$RedirectStandardError,
        [switch]$PassThru
    )

    # Log what we received to verify quoting
    Write-Host "DEBUG: Mock Start-Process called: $FilePath Args: $($ArgumentList -join ', ')"

    if ($RedirectStandardOutput) {
        "Mock install log" | Out-File $RedirectStandardOutput
    }

    if ($PassThru) {
        return [PSCustomObject]@{
            HasExited = $true
            ExitCode = 0
        }
    }
}

function Start-Sleep {
    [CmdletBinding()]
    param([int]$Seconds)
}

$ErrorActionPreference = 'Stop'

# Ensure output directory exists
New-Item -Path "test-output" -ItemType Directory -Force | Out-Null

Write-Host "Starting verification test..."

try {
    & ./scripts/run-candidate-tests.ps1 -ManifestPath "products/DummyPackage/manifest.json" -CandidatesJson "products/DummyPackage/candidates.json" -ArtifactDir "products/DummyPackage/Files" -OutputDir "test-output"
} catch {
    Write-Host "Stack Trace: $($_.ScriptStackTrace)"
    Write-Error "Script execution failed: $_"
    exit 1
}
