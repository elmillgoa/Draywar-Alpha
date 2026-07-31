# Global names

Every name that is reachable from anywhere in the game just by typing it, what
it points at, and why it earned the slot.

**This document is checked against the configuration.**
`scripts/check_globals.py` compares the `[autoload]` section of `project.godot`
with the entries below and fails the build if they disagree in either direction.

Autoloads under `addons/` are ignored (editor tools, not architecture).

---

## The four tests

A thing may occupy a global name slot only if **all four** hold:

1. **Genuinely everything needs it** — not merely several things.
2. **It holds no game state owned by a particular system.**
3. **Having two of them would be nonsense.**
4. **It is declared here with a one-line justification, and a check fails the
   build when the real set and this list disagree.**

## Adding a global

1. Argue it against all four tests.
2. Register the autoload in `project.godot`.
3. Add an entry below with the justification against the four tests.
4. Run `python scripts/check_globals.py`.

**Entry format (load-bearing):**

```
### `SomeGlobal` -> `res://src/systems/SomeGlobal.gd`
```

---

# Catalog

### `EventBus` -> `res://src/systems/EventBus.gd`

Cross-system signal bus. The sanctioned channel for cross-domain communication.
Everything that crosses a boundary needs it; two buses would split the game into
two conversations; it holds no game state of its own.

### `ContentLibrary` -> `res://src/systems/ContentLibrary.gd`

Content scan and lookup for every `.tres` under `src/data/content/`. Every
system that resolves an id needs one library; two would disagree about what
exists; it holds content references, not career state.

### `TimeScale` -> `res://src/systems/time/TimeScale.gd`

How fast game time runs. Every clock must ask the same number; two authorities
would run two games; it holds only the rate and combat lock, not world state.
