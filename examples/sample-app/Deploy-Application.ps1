# Sample PSADT deploy script for SampleApp
$manifest = Get-Content -Raw -Path ".\manifest.json" | ConvertFrom-Json
Write-Host "Installing $($manifest.product)"
# Use the first candidate command
$candidates = Get-Content -Raw -Path ".\candidates.json" | ConvertFrom-Json
$cmd = $candidates[0].command -replace '<installer>', '.\Files\source_installer.exe'
Write-Host "Running: $cmd"
Start-Process -FilePath 'powershell' -ArgumentList "-NoProfile -Command & {Start-Process -FilePath $cmd -Wait}" -NoNewWindow -Wait
