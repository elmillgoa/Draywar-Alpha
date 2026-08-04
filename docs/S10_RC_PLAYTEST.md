# S10 release-candidate playtest brief

**Phase:** S10 — Production polish + launch prep  
**Status:** **Gate closed** 2026-08-04 — Elliot signed **release candidate** (“Pass”).

---

## What landed (S10 floor)

| Track | What you get |
|-------|----------------|
| **Options** | Main + Pause → Options: FOV, turn sensitivity, master/UI/SFX volume, fullscreen |
| **Rebinds** | Click a bind row, press a key (Escape cancels listen). Saved under `user://settings.cfg` |
| **Controller** | **Keyboard + mouse only for 1.0** (documented). No gamepad. |
| **Standing a11y** | Status line + captain sheet: **color + glyph + tier name** (not color alone) |
| **Presentation** | Ships / stations / gates use **lit** materials + engine glow (still primitives) |
| **Audio** | Thin procedural beeps: UI click, weapon, dock/undock. Volume sliders work. |
| **Packaging** | Product name **Draywar** (not Alpha). SteamService stub (no SDK dep yet). |
| **Ship budget** | Still **20** — not raised. |

---

## What you are judging

Plan gate:

> **release candidate**

### Measure

1. **Options work** — change FOV and sensitivity; feel the ship and camera. Rebind Dock; confirm F or your key still docks after restart.
2. **Standing readable** — fly/dock; status line shows glyph + tier word + color. Captain sheet standings colored.
3. **Looks** — undock at Alpha Port: ship and station should not be pure flat unshaded gray blobs. Engines glow.
4. **Sound** — fire weapon, dock, click menu: short beeps present; volumes mute when zero.
5. **No new pillars** — game still the same career (campaign → Holding → sandbox). Polish only.
6. **Bugs** — note crashes, broken options, missing status, audio spam.

### Pass looks like

- You would ship a **public RC / demo build** for outside eyes without embarrassment on options/readability.
- Nothing feels like “still called Alpha prove-it” in the window title / menu.
- You are willing to call **release candidate** (or name specific polish holes for another S10 pass).

### Fail looks like

- Options do nothing or wipe on relaunch.
- Standing is unreadable / color-only disaster.
- Lit materials make the world black or unreadable.
- Gameplay systems broken that were fine after S9.

---

## Suggested first session (1–2h)

1. Cold boot → **Options** from main menu: set FOV 75, sensitivity 1.2, lower master volume.
2. New Game → docked start; check status line color/glyph.
3. Undock; fire; re-dock; listen for beeps.
4. Pause → Options → rebind throttle or dock; verify.
5. Captain sheet standing list colors.
6. Jump once; note station/ship presentation.

Write **pass / fail** in one line when ready. Optional: external RC with same brief.

---

## Out of scope for this gate

- Full GodotSteam SDK / live achievements (stub only until you approve the dependency)
- AAA art packs / music OST
- Gamepad
- Content budget expansion (that was S9)
- Raising the 20-ship budget
