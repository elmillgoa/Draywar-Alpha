# Draywar Alpha  -  headless import + smoke + GUT suite.
# This is the LOCAL equivalent of .github/workflows/tests.yml  -  same three
# checks, same reasoning, same traps. If you change the checks in one file,
# change them in the other too, or this script stops being "CI you can run
# on your own machine" and starts being a script that lies about that.
#
# ---------------------------------------------------------------------------
# WHY THIS SCRIPT LOOKS PARANOID  -  read before "simplifying" it
# ---------------------------------------------------------------------------
# Until 2026-08-06 this script printed "PASS" while three independent faults
# made that meaningless. All three are fixed below. Do not remove any of them
# without re-deriving why they exist first  -  re-read this block.
#
#   1. NO IMPORT STEP. A fresh checkout has no `.godot/` directory, so Godot
#      has no global script class cache and every `class_name` reference
#      ("ContentItem", "BalanceSettings", ...) fails to parse. CI already ran
#      `--headless --import` before anything else; this script did not, so a
#      clean-clone run here could fail for a reason that has nothing to do
#      with the code under test. See docs/traps.md #14 and #23.
#
#   2. GODOT EXITS 0 ANYWAY. `--import` and `--quit-after` both return exit
#      status 0 even when hundreds of ERROR/SCRIPT ERROR lines were printed
#      and every autoload failed to instantiate. This script used to decide
#      the smoke boot passed from $LASTEXITCODE alone (old line 15)  -  which
#      means it would print "PASS smoke boot" on a boot that failed every
#      autoload. The exit code is not evidence by itself; count the error
#      lines in the captured log instead.
#
#   3. GUT SILENTLY DROPS A SCRIPT IT CANNOT PARSE. A `.gd` test file with a
#      parse error (an untyped var is enough to trigger one under this
#      project's strict warning settings  -  see docs/tooling.md "Strict
#      typing") is dropped from the run with NO warning and NO failure. GUT
#      still prints "---- All tests passed! ----" and exits 0, just with a
#      smaller `Scripts` count than it should have. docs/traps.md #18 says
#      the Scripts count is the ONLY tell. Proven 2026-08-06: appending one
#      bad line to tests/test_attribution.gd turned a clean
#      93 Scripts / 820 Tests run into 92 Scripts / 806 Tests  -  still
#      reported as "All tests passed!", exit code 0. Nothing before this fix
#      checked the Scripts count anywhere, locally or in CI. This script now
#      counts the test_*.gd files on disk itself (does not hardcode the
#      number) and fails loudly if GUT collected fewer than that.
#
# docs/tooling.md and .github/workflows/tests.yml both describe this script
# as "the local equivalent of CI". Keep that true.
# ---------------------------------------------------------------------------

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$godot = "C:\Godot\Godot_v4.6.1-stable_win64_console.exe"
if (-not (Test-Path $godot)) {
    Write-Host "FAIL  Godot not found at $godot" -ForegroundColor Red
    exit 2
}

# Floor for "did GUT actually collect the whole suite", not an exact expected
# count. Mirrors MIN_TESTS in .github/workflows/tests.yml  -  keep both in
# sync, and raise both deliberately as the suite grows. Its job is to turn a
# run that silently stopped collecting tests red instead of green.
$MinTests = 800

# ---------------------------------------------------------------------------
# Step 1  -  Import: build .godot/ and the global class_name cache.
# Without this, every class_name reference fails to parse and every check
# below would be reacting to a broken boot, not to the code actually under
# test. Must run before smoke and GUT. See docs/traps.md #14 and #23.
# ---------------------------------------------------------------------------
Write-Host "=== Import (build .godot/ class cache) ===" -ForegroundColor Cyan
$importOutput = & $godot --path $root --headless --import 2>&1 | ForEach-Object { "$_" }
$importExit = $LASTEXITCODE
$importOutput | ForEach-Object { Write-Host $_ }
$importErrorCount = ($importOutput | Where-Object { $_ -match '^(ERROR|SCRIPT ERROR):' } | Measure-Object).Count
Write-Host "Import error lines: $importErrorCount"
if ($importExit -ne 0) {
    Write-Host "FAIL  import exited $importExit" -ForegroundColor Red
    exit 1
}
if ($importErrorCount -ne 0) {
    Write-Host "FAIL  import produced $importErrorCount error line(s); expected 0. A clean/changed project does not import clean  -  fix the referenced script(s) before trusting anything below." -ForegroundColor Red
    exit 1
}
Write-Host "PASS  import clean, 0 errors" -ForegroundColor Green
Write-Host ""

# ---------------------------------------------------------------------------
# Step 2  -  Smoke boot: the project must start with ZERO ERROR/SCRIPT ERROR
# lines. $LASTEXITCODE is NOT trusted alone here  -  see reason 2 above. Both
# the exit code and the error-line count are checked.
# ---------------------------------------------------------------------------
Write-Host "=== Smoke boot ===" -ForegroundColor Cyan
$smokeOutput = & $godot --path $root --headless --quit-after 2 2>&1 | ForEach-Object { "$_" }
$smokeExit = $LASTEXITCODE
$smokeOutput | ForEach-Object { Write-Host $_ }
$smokeErrorCount = ($smokeOutput | Where-Object { $_ -match '^(ERROR|SCRIPT ERROR):' } | Measure-Object).Count
Write-Host "Smoke boot error lines: $smokeErrorCount"
if ($smokeExit -ne 0) {
    Write-Host "FAIL  smoke boot exited $smokeExit" -ForegroundColor Red
    exit 1
}
if ($smokeErrorCount -ne 0) {
    Write-Host "FAIL  smoke boot produced $smokeErrorCount error line(s); expected 0. A clean checkout of this tree does not boot clean." -ForegroundColor Red
    exit 1
}
Write-Host "PASS  smoke boot, 0 errors" -ForegroundColor Green
Write-Host ""

# ---------------------------------------------------------------------------
# Step 3  -  GUT. Note: some tests deliberately push engine errors
# (assert_push_error / assert_engine_error_count), so error lines are NOT
# counted in this step  -  only in import and smoke boot above, where none are
# expected. What IS checked here is the totals block GUT prints at the end
# of a run, because:
#   - GUT's own exit code is only honest when GUT actually reaches the end
#     of a real run (verified: a failing assert does exit 1)  -  but if the
#     class cache were missing, gut_cmdln could exit 0 having never reached
#     a test, and the step would still look green.
#   - A script GUT could not parse is silently dropped (reason 3 above /
#     docs/traps.md #18) and the totals block is the only place that shows.
# ---------------------------------------------------------------------------
Write-Host "=== GUT ===" -ForegroundColor Cyan
$gutOutput = & $godot --path $root --headless -s "res://addons/gut/gut_cmdln.gd" -gdir=res://tests -gexit 2>&1 | ForEach-Object { "$_" }
$gutExit = $LASTEXITCODE
$gutOutput | ForEach-Object { Write-Host $_ }
Write-Host ""

# Strip ANSI colour escapes before matching. Verified 2026-08-06 against a
# real captured run that the Totals block itself (Scripts / Tests / Passing
# Tests lines) is already free of them  -  strip anyway, as cheap insurance
# against a future GUT version colouring these lines too. Never assume a
# regex matches real tool output without having checked it against some.
$ansiPattern = [char]27 + '\[[0-9;]*[A-Za-z]'
$gutClean = $gutOutput | ForEach-Object { $_ -replace $ansiPattern, '' }

# Totals block shape (verified 2026-08-06 against a real 93-script /
# 820-test clean run):
#   Totals
#   ------
#   Scripts              93
#   Tests               820
#   Passing Tests       820
#   Asserts           28116
#   Time              108.182s
#   Failing Tests         1   <- line is ABSENT entirely when zero, never "0"
# Regexes are anchored with ^...$ so "Scripts" / "Tests" can't accidentally
# match "Passing Tests" / "Failing Tests" (those start with "Passing"/
# "Failing", not "Tests", so ^Tests never touches them)  -  checked against a
# real capture, not assumed.
$scriptsLine = $gutClean | Where-Object { $_ -match '^Scripts\s+(\d+)\s*$' } | Select-Object -Last 1
$testsLine   = $gutClean | Where-Object { $_ -match '^Tests\s+(\d+)\s*$' } | Select-Object -Last 1
$failingLine = $gutClean | Where-Object { $_ -match '^Failing Tests\s+(\d+)\s*$' } | Select-Object -Last 1

$haveTotals = ($null -ne $scriptsLine) -and ($null -ne $testsLine)
if (-not $haveTotals) {
    Write-Host "FAIL  GUT reported no totals block  -  the suite never ran. This is the exact failure that let a broken build report green for 22 consecutive CI runs before 2026-08-06: the exit code looked fine and nothing else was checked." -ForegroundColor Red
    exit 1
}

$scriptsRun = [int]([regex]::Match($scriptsLine, '(\d+)').Value)
$testsRun   = [int]([regex]::Match($testsLine, '(\d+)').Value)
if ($null -ne $failingLine) {
    $failingCount = [int]([regex]::Match($failingLine, '(\d+)').Value)
} else {
    # GUT omits the "Failing Tests" line entirely when the count is zero.
    # Absent means 0, not a parse failure  -  do not treat this branch as an
    # error.
    $failingCount = 0
}

# THE NEW GATE (this is the whole point of this rewrite). Scripts must equal
# the number of test_*.gd files that actually exist on disk right now  -  not
# a hardcoded number, counted fresh every run, because the only way to catch
# "a script silently vanished from the collection" is to compare against
# ground truth every time. See reason 3 above and docs/traps.md #18.
#
# Recursive search, matching how scripts/run_tests.ps1 always counted this:
# verified 2026-08-06 that tests/**/test_*.gd and tests/test_*.gd currently
# return the same 93  -  the only nested directory (tests/support/) holds a
# helper file and a README, neither named test_*.gd  -  but the search stays
# recursive so a future test_*.gd placed in a subfolder is still counted.
$expectedScripts = (Get-ChildItem -Path (Join-Path $root "tests") -Filter "test_*.gd" -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count

Write-Host "----------------------------------------"
Write-Host "GUT exit status : $gutExit"
Write-Host "Scripts run     : $scriptsRun (expected: $expectedScripts test_*.gd file(s) on disk)"
Write-Host "Tests run       : $testsRun (floor: $MinTests  -  a floor, not an exact count)"
Write-Host "Failing tests   : $failingCount"
Write-Host "----------------------------------------"

$failed = $false

if ($scriptsRun -ne $expectedScripts) {
    Write-Host "FAIL  GUT collected $scriptsRun script(s) but $expectedScripts test_*.gd file(s) exist on disk. A script that fails to parse is silently dropped from the run with no warning and no failure  -  GUT still prints 'All tests passed!' and exits 0 (docs/traps.md #18). Find the file that no longer parses (a syntax error, an untyped var under this project's strict warnings, ...) and fix it. Do not lower this check to make it pass." -ForegroundColor Red
    $failed = $true
}

if ($testsRun -lt $MinTests) {
    Write-Host "FAIL  Only $testsRun tests ran, below the floor of $MinTests. Either tests stopped being collected, or the floor needs raising deliberately  -  in both this script and .github/workflows/tests.yml." -ForegroundColor Red
    $failed = $true
}

if ($failingCount -ne 0) {
    Write-Host "FAIL  $failingCount GUT test(s) failed." -ForegroundColor Red
    $failed = $true
}

if ($gutExit -ne 0) {
    Write-Host "FAIL  GUT exited $gutExit." -ForegroundColor Red
    $failed = $true
}

if ($failed) {
    exit 1
}

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Green
Write-Host "PASS  import clean * smoke boot clean * GUT $scriptsRun/$expectedScripts scripts, $testsRun tests (floor $MinTests), 0 failing" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Green
exit 0
