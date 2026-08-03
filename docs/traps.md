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

9. **Full-plan population counts (8–12 Entities) are not Alpha caps.** Alpha Scope wins (4–6 / 12–18).
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
