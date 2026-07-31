# Draywar Alpha — headless smoke + GUT suite.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = "C:\Godot\Godot_v4.6.1-stable_win64_console.exe"
if (-not (Test-Path $godot)) {
    Write-Host "FAIL  Godot not found at $godot" -ForegroundColor Red
    exit 2
}

# Smoke: project boots
Write-Host "=== Smoke boot ==="
& $godot --path $root --headless --quit-after 2
if ($LASTEXITCODE -ne 0) {
    Write-Host "FAIL  smoke boot" -ForegroundColor Red
    exit 1
}
Write-Host "PASS  smoke boot" -ForegroundColor Green

# GUT if tests exist
$testFiles = Get-ChildItem -Path (Join-Path $root "tests") -Filter "test_*.gd" -Recurse -ErrorAction SilentlyContinue
if (-not $testFiles -or $testFiles.Count -eq 0) {
    Write-Host "SKIP  no test_*.gd files yet" -ForegroundColor Yellow
    exit 0
}

Write-Host "=== GUT ==="
# GUT CLI: Godot prints expected ERROR: lines for assert_push_error /
# assert_engine_error_count tests. Those go to stderr; capture exit code
# before PowerShell confuses $? with stream noise.
& $godot --path $root --headless -s "res://addons/gut/gut_cmdln.gd" -gdir=res://tests -gexit 2>&1 | ForEach-Object { "$_" }
$code = $LASTEXITCODE
if ($code -eq 0) {
    Write-Host "PASS  GUT" -ForegroundColor Green
} else {
    Write-Host "FAIL  GUT exit $code" -ForegroundColor Red
}
exit $code
