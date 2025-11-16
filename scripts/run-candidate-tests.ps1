param(
  [Parameter(Mandatory)][string]$ManifestPath,
  [Parameter(Mandatory)][string]$CandidatesJson,
  [Parameter(Mandatory)][string]$ArtifactDir
)

$ErrorActionPreference = 'Stop'
$manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
$candidates = Get-Content $CandidatesJson -Raw | ConvertFrom-Json
New-Item -Path test-output -ItemType Directory -Force | Out-Null

function Run-ProcessCapture {
  param($exe, $args, $timeoutSec=600)
  $outfile = "test-output/$(Get-Random)-out.txt"
  $start = Get-Date
  try {
    Start-Process -FilePath $exe -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outfile -RedirectStandardError $outfile
    $exit=0
  } catch {
    $exit=1
  }
  return @{ exit=$exit; out=$outfile; duration=(Get-Date)-$start }
}

function VerifyInstalled {
  param($manifest)
  $path = "C:\Program Files\$($manifest.product)\$($manifest.product).exe"
  return Test-Path $path
}

$results = @()
foreach ($c in $candidates | Sort-Object -Property { -$_.confidence }) {
  Write-Host "Trying candidate $($c.id) - $($c.command)"
  $cmd = $c.command -replace '<installer>', (Join-Path $ArtifactDir 'source_installer.exe')
  $parts = $cmd -split ' '
  $exe = $parts[0]
  $args = ($parts[1..($parts.Count-1)] -join ' ')
  $r = Run-ProcessCapture -exe $exe -args $args
  Start-Sleep -Seconds 3
  $verified = $false
  try { $verified = VerifyInstalled -manifest $manifest } catch {}
  $results += [PSCustomObject]@{ id=$c.id; command=$cmd; exit=$r.exit; out=(Get-Content $r.out -Raw); verified=$verified }
  if ($verified) { break }
}

$results | ConvertTo-Json -Depth 5 | Out-File -FilePath test-output/candidate-results.json -Encoding utf8
if (($results | Where-Object verified).Count -gt 0) { exit 0 } else { exit 2 }
