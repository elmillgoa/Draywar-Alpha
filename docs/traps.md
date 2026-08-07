# Traps

Lessons that burned time once. When a new trap is found, add it here **and**
encode it in `scripts/checkin.py` when possible.

---

## From prior Draywar work (still apply)

1. **A test that has only ever been green has not been shown to work.** Break what it guards; confirm red; restore; confirm green.
2. **Never trust a fixture that starts at zero** (zero distance, origin, empty standing, default-only). It cannot tell a working mechanism from a dead one.
3. **Godot non-console binary prints nothing** — use `Godot_v4.6.1-stable_win64_console.exe` for headless/scripts.
4. **`project.godot` rewrites strip comments and default-matching keys.** Typing enforcement lives in docs + re-proof after plugin toggles.
5. **Misspelled warning keys are silently ignored** — dump real ProjectSettings names; never type from memory.
6. **A stand-in that omits the announcement the real service makes is not a stand-in.** For standing: the write is not the contract; the EventBus announcement is.
7. **Content may come up silently empty in an exported build** — defend ContentLibrary; prove with a real export eventually.
8. **Do not raise a gate threshold to make code fit.** Split the file or fix the code.

## Alpha-specific

9. **Content ceilings are `Balance.CONTENT_BUDGET`**, enforced at load by
   `ContentLibrary`. The old Alpha Scope caps (3–4 systems / 12–18 people / …)
   are dead — do not treat them as the brake.
10. **Do not rebuild the older Desktop\Draywar tree into this repo.** Steal patterns; do not merge histories as if this were a continuation.

## UI / EventBus (E1+)

11. **Never `free()` a Control that is still inside its own `pressed` (or any) signal.** Job accept rebuilt the jobs box and freed the Accept button mid-click → crash `Object is locked and can't be freed`. Use `remove_child` + `queue_free()`, and `call_deferred` for full rebuilds triggered from that button.
12. **Free-fire aim must live on the camera ray under the reticle.** Ship-forward planes fail with a chase camera (offset behind/above). Unlocked: `ray_origin + ray_dir * range`. Locked: lead intercept plane. Bolts still fire ship→aim_point (convergence at that depth).
13. **Bounty prey is not free ambient pirates.** Ambient hostiles spawn once at world build near the primary station; they do not respawn after death and may be far from secondary docks. Active bounty for this system must **ensure** a live hostile within lock range of the player on accept / undock / system enter.

## Tooling / tests (S2+)

14. **A new `class_name` file is invisible until the editor rescans.** Godot's
    global class cache does not refresh under `--headless --quit-after`, so a
    brand-new `class_name` errors "not declared in current scope" and the run
    goes red for a reason that has nothing to do with the code. Run
    `Godot_v4.6.1-stable_win64_console.exe --path <root> --headless --editor --quit`
    once after adding one. Costs an agent 20 minutes of debugging a correct file.
15. **`add_child_autofree` frees *after* `after_each()`, not before.** Any node
    holding an open `FileAccess` handle therefore still owns the file while the
    next test's fixture cleanup tries to delete it — a Windows file-lock race
    that fails intermittently. Tear such nodes down by hand
    (`flush()` → `remove_child()` → `free()`) inside the test.
16. **Reflection on a `Resource` typed as `Resource` silently drops typed
    dictionary values.** `res.set("stock_targets", {...})` through a generic
    handle writes an empty dictionary and says nothing; the same assignment
    through the real `class_name` type works. Typed `Dictionary[StringName,
    float]` `@export`s *do* round-trip through `.tres` in 4.6.1 — proven, not
    assumed. If a data field comes back empty, suspect the handle, not the
    serializer.
17. **A `Dictionary` value cannot go straight into a GUT assert.**
    `assert_eq(quote[KEY], 12)` fails to *parse* under this project's warning
    settings — "requires the subtype Variant but the supertype Variant was
    provided", treated as an error. The value has to land in a typed local
    first (`var units: int = quote[KEY]`), or the dictionary has to be typed
    (`Dictionary[String, float]`). Same for `raw as Array`. The message names
    Variant twice and reads like a compiler bug; it is not, and the fix is
    always one extra typed line.
18. **GUT reports "All tests passed" for a test script it could not parse.** A
    script with a syntax error is silently dropped from the run — no warning,
    no failure, green summary. The **only** tell is the `Scripts` count in the
    run summary. Check it against `ls tests/test_*.gd | wc -l` before believing
    a green run, especially after a concurrent edit. Caught during S2 when a
    broken file turned 71 scripts / 659 tests into 70 / 647 and still reported
    everything passing. A GUT `for` iterator named after one of GutTest's own
    methods (`_pass`) is the same failure with a different cause.
    **Encoded 2026-08-06 — it is no longer only advice.** `scripts/run_tests.ps1`
    and the CI GUT step both count `test_*.gd` on disk and fail when GUT's
    `Scripts` number disagrees. It was re-proved the day it was written: an
    untyped `var` appended to `tests/test_attribution.gd` produced
    `Scripts 92 / Tests 806`, *"All tests passed!"* and exit 0, against 93 files
    and 818 real tests. **Note the count floor would not have saved you** — CI
    asserted `Tests >= 800` and 806 clears it, so the run was green on both
    machines. A floor catches a suite that stops collecting; only the script
    count catches one file going missing.
19. **"Buy then sell loses" is only half the money-pump invariant, and the
    other half was open.** The plan and `economy_sim.md` both wrote the rule as
    *buy-then-sell at one station is always a net loss*, and the tests proved
    exactly that sentence. **Sell-then-buy was never tested and was a working
    infinite money pump.** A trade is priced from the quote taken *before* it
    records its own shock, so a dump raises a glut and the buy-back that follows
    is charged at the glutted price. Measured on shipped content: Alpha Port
    medical +150 credits a cycle, Beta Hub fuel cells +89 a cycle, fifteen
    (station, commodity) markets exploitable, the shelf back at its opening
    stock every time. Two lessons. **Test the invariant, not the sentence
    somebody wrote down** — a round trip has two orders and the doc named one.
    And **a bound whose job is to stop an exploit has to be derived from the
    thing it is bounding**: the flat `SHOCK_MAGNITUDE_MAX` looked like a safety
    cap and was only a magnitude cap. It is now capped per commodity against
    that commodity's own buy/sell spread, which holds for any content instead of
    for one set of ten numbers.
20. **A test that reads the constant it is guarding cannot fail.**
    `assert_almost_eq(left, target * STOCK_FLOOR_FRACTION)` passed cleanly with
    `STOCK_FLOOR_FRACTION` set to `0.0` — the floor was gone and the assertion
    agreed with it, because both sides moved together. Assert the real quantity
    first (`left > 0.0`), then the constant.
21. **Never round-trip a source file through PowerShell 5.1 `Get-Content` /
    `Set-Content`.** Every `.gd` and `.md` in this repo is UTF-8 without a BOM
    and full of `—`, `×` and `§`. `Get-Content -Raw` finds no BOM, falls back to
    Windows-1252, and `Set-Content -Encoding utf8` then writes a **BOM plus
    double-encoded** text: `—` becomes `â€"` in 46 places, silently, exit code 0.
    Used during S2 to flip two constants for a deliberate-break check and it
    corrupted `BalanceMarket.gd`, which is **untracked** — git could not have
    restored it. Recovery is `bytes[3:].decode('utf-8').encode('cp1252')`, but
    the fix is not to do it: edit source files with the editing tool, or with
    Python reading and writing explicit UTF-8.
22. **The whole S2 tree is uncommitted.** `git status` at the time of writing
    shows 34 modified and ~40 untracked files, including every
    `src/systems/market/*.gd`, `BalanceMarket.gd` and `docs/economy_sim.md`.
    There is no safety net behind any edit in this phase — check what is tracked
    before assuming a mistake is revertible.
23. **A fresh clone could not boot, and CI reported "success" 22 times while it
    couldn't.** Two separate faults, both fixed 2026-08-06 in
    `.github/workflows/tests.yml`. **(a) There was no import step.** A clean
    checkout has no `.godot/` directory and therefore no global script class
    cache, so every `class_name` reference fails to parse — a fresh clone booted
    with **1,454 errors**. `--headless --import` before anything else takes that
    to **0**. This is trap #14 at repository scale: the class cache is *build
    output*, and CI was never building it. **(b) `--quit-after` exits 0 no matter
    what.** Godot returned status 0 having printed 1,454 errors and failed every
    autoload, so the smoke step passed. GUT's own exit code is honest *when GUT
    runs* (a failing assert does exit 1) — but with the class cache missing
    `gut_cmdln` never reached a test and the step still exited 0, in 9–21 seconds.
    **The rule: for a Godot headless run, the process exit code is not evidence.
    Count the error lines in the log, and assert the test totals block exists.**
24. **Never commit the Godot MCP Pro autoloads.** `addons/godot_mcp/` is
    gitignored — the addon is proprietary and purchased, and its licence forbids
    redistribution — so three `MCP*` autoloads and an `[editor_plugins]` entry in
    `project.godot` pointed at files no clone would ever have. That was the nine
    remaining autoload errors on a fresh checkout (Blocker B2). **The addon
    manages those entries itself**: `plugin.gd` injects the three autoloads in
    `_enter_tree()` and removes them in `_exit_tree()` — but only the ones *it*
    injected that session. Anything already in `project.godot` is treated as
    project-owned and never cleaned up, which is precisely how they got welded in
    permanently. With the committed file clean, the plugin injects on editor open
    and tidies up on close, and nothing leaks into git. After a fresh clone,
    enable the plugin once via Project > Project Settings > Plugins. CI now fails
    the build if `addons/godot_mcp` reappears in `project.godot`.
25. **What the boundary gate scans, and what it still cannot see.** *(Verdict on
    audit finding #82, decided 2026-08-06.)* `scripts/check_boundaries.py` used to
    read only `.gd`, `.tscn` and `.tres`, so a cross-layer reference carried by a
    `.cfg` or `.json` was invisible. Checked before deciding: **no `.cfg` or
    `.json` in this repo contains a `res://src/` reference**, so extending the
    scan cost nothing and closed the hole before it opened. `.cfg` and `.json`
    are now scanned. **What is still not seen, deliberately:** the scan is
    confined to the four deciding-layer directories under `src/`
    (`systems`, `entities`, `ui`, `world`), so a data file living anywhere else
    is not read, and no file type outside that list is either. If content ever
    starts carrying `res://src/` paths from outside `src/`, this gate will not
    tell you. That is the known edge — it is written here rather than left in the
    script's header, because a hole recorded only in the code that has it is a
    hole nobody reads.
26. **Before 2026-08-06, a green `lint.ps1` run proved almost nothing.** Three
    faults, each of which turned a gate that never ran into a reported PASS.
    **(a) The strict-typing gate never checked types.** It booted the project for
    two frames and searched the output for `ERROR:`. A script the boot does not
    load is never parsed — an untyped `var` appended to a test file gave a clean
    boot, exit 0 and no error lines. Meanwhile `scripts/check_types.gd`, a
    working project-wide re-parser whose own docstring said *"Run it via
    scripts/lint.ps1"*, was called by nothing in the repository. It now runs, and
    it covers all 219 scripts, not the handful the boot happens to touch.
    **(b) A missing linter was a silent pass** — gdlint and gdformat ran only if
    `.venv\Scripts\*.exe` existed, and `.venv` is gitignored, so on any fresh
    machine both printed a yellow SKIP, never counted as failures, and the run
    still ended *"All required gates passed."* **There is no SKIP path left in
    `lint.ps1`** — a missing tool, a missing checker script, or a checker
    reporting setup-incomplete is now a failure. **(c) The `ERROR:` test was a
    substring search** over the whole output blob, matching the word anywhere,
    including inside a path or a quoted message. Error detection is now anchored
    to the start of a line and matches both `ERROR:` and `SCRIPT ERROR:`.
    **The rule this leaves behind: a gate that can quietly not run is not a
    gate.** If you add one, make its absence loud.
27. **A `.ps1` file in this repo must be pure ASCII — PowerShell 5.1 misdecodes
    it when it *runs* it, not just when `Get-Content` reads it.** Trap #21 covers
    the round-trip; this is the other half and it is nastier. A `.ps1` saved as
    UTF-8 **without a BOM** is correct on disk and verifiably correct — and
    Windows PowerShell 5.1 still reads the bytes as CP-1252 when executing, so an
    em dash inside a `Write-Host` string becomes garbage and throws a *parser*
    error pointing at a line that looks fine. Hit twice on 2026-08-06, once while
    rewriting `run_tests.ps1` and once in `lint.ps1`, whose header comments were
    full of em dashes. The docs and `.gd` files use em dashes freely and should
    keep doing so — this applies **only** to `.ps1`. Check before trusting a
    file: `python -c "import sys;b=open(sys.argv[1],'rb').read();print(sum(1 for x in b if x>127))" scripts/lint.ps1`
    must print `0`. Note `grep -P '[^\x00-\x7F]'` is **not** a reliable check
    here: under this environment's locale it can report zero matches on a file
    that genuinely holds non-ASCII bytes, which is how the second one slipped
    through the first check.
