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
