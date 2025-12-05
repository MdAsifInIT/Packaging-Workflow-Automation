# Fixes Implemented

## 1. Installer Path Quoting in `run-candidate-tests.ps1`
**Issue:** When constructing the installation command, the script replaced `<installer>` with the full path to `source_installer.exe` without quotes. If the artifact directory (or parent directories) contained spaces (e.g., `products/Test App/Files`), the resulting command passed to `powershell.exe` would be malformed (PowerShell would interpret the path up to the first space as the command).

**Fix:** Modified the script to explicitly quote the installer path before replacement.
```powershell
$installerPath = Join-Path $ArtifactDir 'source_installer.exe'
$cmd = $c.command -replace '<installer>', "`"$installerPath`""
```

## 2. Smoke Test Command Parsing in `run-candidate-tests.ps1`
**Issue:** The "smoke test" (Layer 4 verification) naively split the verification hint command by spaces to separate the executable from arguments.
```powershell
$parts = $cmd -split ' '
```
This failed for executable paths containing spaces (e.g., `"C:\Program Files\App\App.exe" /check`), as it would treat `C:\Program` as the executable.

**Fix:** Added regex matching to handle quoted paths correctly.
```powershell
if ($cmd -match '^"([^"]+)"\s*(.*)$') {
  $exe = $matches[1]
  $args = $matches[2]
} else {
  ...
}
```

## 3. Environment Dependency (`$env:ProgramData`)
**Issue:** The script accessed `$env:ProgramData` directly to check the Start Menu. On non-Windows environments (like Linux CI containers) or contexts where this variable is not set, `Join-Path` would fail with a "path is null" error, causing the script to crash.

**Fix:** Added a check `if ($env:ProgramData)` before attempting to access the Start Menu.

## Verification
- Created a dummy package in `products/Test App` (with spaces).
- Created a test harness `tests/verify-automation.ps1` that mocks Windows-specific cmdlets (`Start-Process`, `Get-ChildItem` for Registry/StartMenu, `Test-Path`).
- Verified that the installer path is now correctly quoted in the mocked `Start-Process` call.
- Verified that verification hints with quoted paths and spaces are correctly parsed.
- Verified that the script no longer crashes on Linux when `$env:ProgramData` is missing.
