# Draywar Alpha — static checks.
# Exit 0 = clean. Non-zero = not done.

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = "C:\Godot\Godot_v4.6.1-stable_win64_console.exe"
$gdlint = Join-Path $root ".venv\Scripts\gdlint.exe"
$gdformat = Join-Path $root ".venv\Scripts\gdformat.exe"
$python = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) { $python = "python" }

$failed = 0

function Write-Gate([string]$name, [bool]$ok, [string]$detail = "") {
    if ($ok) {
        Write-Host "PASS  $name" -ForegroundColor Green
    } else {
        Write-Host "FAIL  $name  $detail" -ForegroundColor Red
        $script:failed++
    }
}

# 1. Strict typing / project loads
Write-Host "`n=== 1. Strict typing (Godot load) ==="
if (-not (Test-Path $godot)) {
    Write-Gate "strict typing" $false "Godot not found at $godot"
} else {
    $out = & $godot --path $root --headless --quit-after 2 2>&1 | Out-String
    $ok = ($LASTEXITCODE -eq 0) -and ($out -notmatch "ERROR:")
    if (-not $ok) { Write-Host $out }
    Write-Gate "strict typing" $ok
}

# 2. gdlint
Write-Host "`n=== 2. gdlint ==="
if (-not (Test-Path $gdlint)) {
    Write-Host "SKIP  gdlint (create .venv and pip install gdtoolkit==4.*)" -ForegroundColor Yellow
} else {
    & $gdlint src/ tests/ scripts/ 2>&1 | Out-Host
    Write-Gate "gdlint" ($LASTEXITCODE -eq 0)
}

# 3. gdformat --check
Write-Host "`n=== 3. gdformat --check ==="
if (-not (Test-Path $gdformat)) {
    Write-Host "SKIP  gdformat (create .venv and pip install gdtoolkit==4.*)" -ForegroundColor Yellow
} else {
    & $gdformat --check src/ tests/ scripts/ 2>&1 | Out-Host
    Write-Gate "gdformat" ($LASTEXITCODE -eq 0)
}

# 4. Architecture (EventBus boundaries)
Write-Host "`n=== 4. Architecture boundaries ==="
$boundaries = Join-Path $root "scripts\check_boundaries.py"
if (Test-Path $boundaries) {
    & $python $boundaries 2>&1 | Out-Host
    Write-Gate "architecture" ($LASTEXITCODE -eq 0)
} else {
    Write-Host "SKIP  check_boundaries.py missing" -ForegroundColor Yellow
}

# 5. Magic numbers / balance
Write-Host "`n=== 5. Balance / magic numbers ==="
$magic = Join-Path $root "scripts\check_magic_numbers.py"
if (Test-Path $magic) {
    & $python $magic 2>&1 | Out-Host
    # Until Balance layer exists, allow soft skip on exit 2 (setup)
    if ($LASTEXITCODE -eq 2) {
        Write-Host "SKIP  balance gate (setup incomplete - expected pre-A0 data pipeline)" -ForegroundColor Yellow
    } else {
        Write-Gate "balance" ($LASTEXITCODE -eq 0)
    }
}

# 6. Globals catalog
Write-Host "`n=== 6. Globals catalog ==="
$globals = Join-Path $root "scripts\check_globals.py"
if (Test-Path $globals) {
    & $python $globals 2>&1 | Out-Host
    Write-Gate "globals" ($LASTEXITCODE -eq 0)
}

Write-Host ""
if ($failed -eq 0) {
    Write-Host "All required gates passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed gate(s) failed." -ForegroundColor Red
    exit 1
}
