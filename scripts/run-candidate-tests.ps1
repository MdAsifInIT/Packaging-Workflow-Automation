param(
  [Parameter(Mandatory=$true)][string]$ManifestPath,
  [Parameter(Mandatory=$true)][string]$CandidatesJson,
  [Parameter(Mandatory=$true)][string]$ArtifactDir,
  [string]$OutputDir = ".\test-output"
)

$ErrorActionPreference = 'Stop'
New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null

$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$candidates = Get-Content $CandidatesJson -Raw | ConvertFrom-Json

# helper: layered verification
function Verify-Installed {
  param($manifest, $verification_hints)
  # Layer 1: MSI product code / registry
  if ($manifest.product_code -and (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' -Recurse | Where-Object {
      $_.GetValue('ProductCode','') -eq $manifest.product_code
    })) { return @{passed=$true;method='msi-productcode'} }

  # Layer 2: expected exe path
  foreach ($hint in $verification_hints) {
    if ($hint -like '*:\*') { if (Test-Path $hint) { return @{passed=$true;method='exe-path';hint=$hint} } }
    # allow registry hint or shortcut patterns as strings
  }

  # Layer 3: Start Menu/Shortcut checks (look for product in start menu)
  $startmenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
  if (Get-ChildItem -Path $startmenu -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$($manifest.product)*" }) { return @{passed=$true;method='shortcut'} }

  # Layer 4: smoke test (non-interactive)
  if ($manifest.verification_hints) {
    foreach ($cmd in $manifest.verification_hints) {
      try {
        $parts = $cmd -split ' '
        $exe = $parts[0]
        $args = ($parts | Select-Object -Skip 1) -join ' '
        $proc = Start-Process -FilePath $exe -ArgumentList $args -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        if ($proc -and $proc.HasExited) { return @{passed=$true;method='smoke';cmd=$cmd} }
      } catch {}
    }
  }
  return @{passed=$false}
}

foreach ($c in $candidates | Sort-Object -Property @{Expression={[double]$_.confidence}} -Descending) {
  Write-Host "Trying candidate $($c.id) (confidence $($c.confidence)): $($c.command)"
  $cmd = $c.command -replace '<installer>', (Join-Path $ArtifactDir 'source_installer.exe')
  $logPath = Join-Path $OutputDir "candidate-$($c.id).log"
  try {
    # Run installer as a background process; capture output
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`"" -NoNewWindow -Wait -RedirectStandardOutput $logPath -RedirectStandardError $logPath
  } catch {
    "Execution failed: $($_.Exception.Message)" | Out-File $logPath -Append
  }

  Start-Sleep -Seconds 5

  $verify = Verify-Installed -manifest $manifest -verification_hints $manifest.verification_hints
  $result = @{
    id = $c.id
    command = $cmd
    confidence = $c.confidence
    verified = $verify.passed
    verify_method = $verify.method
    log = Get-Content $logPath -Raw
  }
  $result | ConvertTo-Json -Depth 4 | Out-File -FilePath (Join-Path $OutputDir ("result-$($c.id).json")) -Encoding utf8

  if ($verify.passed) {
    Write-Host "Candidate $($c.id) verified via $($verify.method)"
    exit 0
  } else {
    Write-Host "Candidate $($c.id) did not verify."
  }
}

Write-Host "No candidate verified. Exiting with failure."
exit 2
