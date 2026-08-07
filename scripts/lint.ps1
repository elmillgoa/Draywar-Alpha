# Draywar - static checks.
# Exit 0 = clean. Non-zero = not done.
#
# ---------------------------------------------------------------------------
# WHY THIS FILE LOOKS PARANOID - read before "simplifying" it
# ---------------------------------------------------------------------------
# Until 2026-08-06 a green run from this script proved almost nothing. Three
# separate faults each turned a gate that never ran into a reported PASS:
#
#   1. THE STRICT-TYPING GATE NEVER CHECKED TYPES. It booted the project for two
#      frames and grepped the output for "ERROR:". A script the boot does not
#      load is never parsed, so a typing violation in it was invisible. Proved:
#      an untyped `var` appended to tests/test_attribution.gd produced a clean
#      two-frame boot, exit 0, no error lines - a full false green. Meanwhile
#      scripts/check_types.gd, a working project-wide re-parser written for
#      exactly this job, sat unreferenced by anything in the repository. Its own
#      docstring said "Run it via scripts/lint.ps1"; this script did not.
#      (Findings #76 and #81.)
#
#   2. A MISSING LINTER WAS A SILENT PASS. gdlint and gdformat only ran if
#      .venv\Scripts\*.exe existed. .venv is gitignored, so on any fresh machine
#      both gates printed SKIP in yellow, never incremented the failure count,
#      and the script still ended with "All required gates passed." The one
#      machine that had .venv is the reason nobody noticed. (Finding RA-7.)
#      The same shape applied to every missing checker script and to the balance
#      gate's "soft skip on exit 2".
#
#   3. GODOT EXITS 0 ANYWAY. --quit-after returns 0 with a thousand errors
#      printed and the main script failed to compile - verified, it still prints
#      "Draywar - boot OK". The exit code is not evidence. Error lines are.
#
# So: every gate either runs or fails. There is no SKIP path left in this file,
# and that is deliberate - a gate that can quietly not run is not a gate. If a
# tool is missing the message says exactly how to install it.

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = "C:\Godot\Godot_v4.6.1-stable_win64_console.exe"
$gdlint = Join-Path $root ".venv\Scripts\gdlint.exe"
$gdformat = Join-Path $root ".venv\Scripts\gdformat.exe"
$python = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    $resolved = Get-Command python -ErrorAction SilentlyContinue
    if ($resolved) { $python = $resolved.Source } else { $python = $null }
}

$failed = 0

function Write-Gate([string]$name, [bool]$ok, [string]$detail = "") {
    if ($ok) {
        Write-Host "PASS  $name" -ForegroundColor Green
    } else {
        Write-Host "FAIL  $name  $detail" -ForegroundColor Red
        $script:failed++
    }
}

# Counts real engine error lines. Anchored to the start of the line and matching
# both prefixes Godot uses, because the old `-notmatch "ERROR:"` test was a
# substring search over the whole blob: it matched the word anywhere, including
# inside a path or a quoted message, and missed nothing only by luck.
function Count-EngineErrors([string]$text) {
    if (-not $text) { return 0 }
    return @($text -split "`r?`n" | Where-Object { $_ -match '^(ERROR|SCRIPT ERROR):' }).Count
}

if (-not (Test-Path $godot)) {
    Write-Host "FAIL  Godot not found at $godot" -ForegroundColor Red
    Write-Host "      Every gate below needs the engine. See docs/tooling.md." -ForegroundColor Red
    exit 2
}

# ---------------------------------------------------------------------------
# 0. Import - build .godot/ and the global script class cache
# ---------------------------------------------------------------------------
# A fresh checkout has no class cache, so every script naming a class_name type
# fails to parse and the type check below would report the whole tree broken for
# a reason that is not a typing fault at all. docs/traps.md #14.
Write-Host "`n=== 0. Import (global class cache) ==="
$importOut = & $godot --path $root --headless --import 2>&1 | Out-String
$importCode = $LASTEXITCODE
$importErrors = Count-EngineErrors $importOut
if ($importCode -ne 0 -or $importErrors -ne 0) { Write-Host $importOut }
Write-Gate "import" (($importCode -eq 0) -and ($importErrors -eq 0)) "exit=$importCode errorLines=$importErrors"

# ---------------------------------------------------------------------------
# 1. Strict typing - every script in the tree re-parsed
# ---------------------------------------------------------------------------
# This is the real gate. scripts/check_types.gd walks res://src, res://tests and
# res://scripts and re-parses each .gd file, so a violation is caught wherever it
# lives rather than only where the boot happens to look. Under the error-level
# warning settings in project.godot an untyped declaration IS a parse error, so a
# parse failure is a typing failure.
Write-Host "`n=== 1. Strict typing (every script re-parsed) ==="
$typesOut = & $godot --headless --path $root --script res://scripts/check_types.gd 2>&1 | Out-String
$typesCode = $LASTEXITCODE
Write-Host ($typesOut -split "`r?`n" | Where-Object { $_ -match '^Type check:' } | Select-Object -Last 1)
if ($typesCode -ne 0) { Write-Host $typesOut }
Write-Gate "strict typing" ($typesCode -eq 0) "check_types.gd exit=$typesCode"

# ---------------------------------------------------------------------------
# 2. Boot health - the project actually starts, with zero error lines
# ---------------------------------------------------------------------------
# Kept as its own gate rather than as the typing check it used to pretend to be.
# It catches what a re-parse cannot: an autoload that fails to instantiate, a
# missing resource, a scene that will not build. The exit code is ignored on
# purpose - see fault 3 in the header.
Write-Host "`n=== 2. Boot health (zero error lines) ==="
$bootOut = & $godot --path $root --headless --quit-after 2 2>&1 | Out-String
$bootCode = $LASTEXITCODE
$bootErrors = Count-EngineErrors $bootOut
if ($bootCode -ne 0 -or $bootErrors -ne 0) { Write-Host $bootOut }
Write-Gate "boot health" (($bootCode -eq 0) -and ($bootErrors -eq 0)) "exit=$bootCode errorLines=$bootErrors"

# ---------------------------------------------------------------------------
# 3. gdlint
# ---------------------------------------------------------------------------
Write-Host "`n=== 3. gdlint ==="
if (-not (Test-Path $gdlint)) {
    Write-Gate "gdlint" $false "not installed at $gdlint - run: python -m venv .venv; .venv\Scripts\pip install gdtoolkit==4.*"
} else {
    & $gdlint src/ tests/ scripts/ 2>&1 | Out-Host
    Write-Gate "gdlint" ($LASTEXITCODE -eq 0)
}

# ---------------------------------------------------------------------------
# 4. gdformat --check
# ---------------------------------------------------------------------------
Write-Host "`n=== 4. gdformat --check ==="
if (-not (Test-Path $gdformat)) {
    Write-Gate "gdformat" $false "not installed at $gdformat - run: python -m venv .venv; .venv\Scripts\pip install gdtoolkit==4.*"
} else {
    & $gdformat --check src/ tests/ scripts/ 2>&1 | Out-Host
    Write-Gate "gdformat" ($LASTEXITCODE -eq 0)
}

# ---------------------------------------------------------------------------
# 5-7. The Python static gates
# ---------------------------------------------------------------------------
# Each returns 0 clean / 1 violation / 2 setup incomplete. Exit 2 is a FAILURE
# here. It used to be a soft skip for the balance gate, dating from before the
# balance layer existed; the layer has existed since P0.3 and a gate reporting
# "setup incomplete" now means something is genuinely wrong with the tree.
function Invoke-PythonGate([string]$name, [string]$scriptRelative) {
    $path = Join-Path $root $scriptRelative
    if (-not (Test-Path $path)) {
        Write-Gate $name $false "$scriptRelative is missing"
        return
    }
    if (-not $python) {
        Write-Gate $name $false "no Python interpreter found (.venv\Scripts\python.exe or python on PATH)"
        return
    }
    & $python $path 2>&1 | Out-Host
    $code = $LASTEXITCODE
    $detail = ""
    if ($code -eq 2) { $detail = "setup incomplete (exit 2)" }
    Write-Gate $name ($code -eq 0) $detail
}

Write-Host "`n=== 5. Architecture boundaries ==="
Invoke-PythonGate "architecture" "scripts\check_boundaries.py"

Write-Host "`n=== 6. Balance / magic numbers ==="
Invoke-PythonGate "balance" "scripts\check_magic_numbers.py"

Write-Host "`n=== 7. Globals catalog ==="
Invoke-PythonGate "globals" "scripts\check_globals.py"

# ---------------------------------------------------------------------------
# 8. Group registry
# ---------------------------------------------------------------------------
# The second cross-boundary channel. check_boundaries.py polices static
# references, which carry a res:// path or a class_name; a group lookup carries
# neither, so that gate was blind to the whole mechanism (audit finding #79).
# 85 lookup sites across src/ reach across layers and between systems this way.
# The pattern is sanctioned and declared - docs/groups.md - and this gate fails
# on a group nobody declared, a lookup from a layer the registry does not permit,
# or an undocumented dynamic call site. See DRAYWAR_CONVENTIONS.md section 2.3.
Write-Host "`n=== 8. Group registry ==="
Invoke-PythonGate "groups" "scripts\check_groups.py"

Write-Host ""
if ($failed -eq 0) {
    Write-Host "All required gates passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed gate(s) failed." -ForegroundColor Red
    exit 1
}
