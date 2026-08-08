# Draywar Graphics Pass — Design (signed scope)

Date: 2026-08-08
Status: Design approved by Elliot section-by-section in planning session. Awaiting
final spec review, then implementation planning.
Owner sign-off model: same as the Steam phases — agents never declare "looks good";
Elliot signs every style gate on real screenshots.

This pass starts **only after the current fix pass closes**. Nothing here touches
the fix-pass queue.

---

## 1. Purpose and bar

Replace every placeholder visual in Draywar with production art. The bar is **full
production look**: the whole game — ships, space, stations, menus, sounds, store
identity — reads as finished art, not a demo. This also ends the stated playtest
pain: "shapes that look like nothing."

## 2. Art direction — "WWII bomber in space"

Set by Elliot's reference images (8 images provided 2026-08-08; see Open Items —
they need to be copied into `docs/art_direction/` so builders can use them).

The look: patchwork armor plates with visible rivets; chipped olive/khaki/tan paint
over bare metal; stencilled hull numbers; hazard-yellow chevrons; exposed truss
framework; landing skids; analog-era instrument styling (gauges, toggles, cracked
amber screens, handwritten notes). Lighting is warm and practical — hangar lamps,
dust, oil stains. Nothing chrome, nothing sleek, nothing neon.

The cockpit reference image is **mood only** — it styles the HUD and key art. No
in-cockpit camera in this pass. The hangar reference image drives both the Steam
key art and the dock-screen backdrops.

## 3. Scope

**In:**
1. Real 3D models for: both player hulls (hauler, fighter), both hostile profiles
   (skirmisher, gunboat), both traffic roles (civilian, patrol), escort freighter,
   station body, jump gate. Projectiles keep simple geometry and are upgraded with
   materials, glow, and trails — no model files (they're fast-moving bolts; models
   would be invisible).
2. Livery system: paint is data, separate from models. Every government/organization
   (8 entities) gets its own paint scheme. Ships are told apart by silhouette first,
   scheme second.
3. Hardpoints and visible weapons: every ship model carries named attachment
   points; weapon models mount there and **swap visibly when the equipped weapon
   changes**. All 12 weapons are covered by a small set of weapon-model families
   (cannon, twin cannon, launcher/pod, heavy) with size/barrel/material variants.
   Hostiles show their profile loadouts; traffic keeps fixed simple mounts.
4. **Paint shop — full player feature in this pass:** a station screen to browse
   skins, preview them on your ship, buy with credits; choice survives save/load.
5. Space environment: per-system deep-space backdrops (8 distinct), real sun/planet
   surfaces, glow/haze/color treatment. The one-node-per-star starfield is retired.
6. Combat and travel effects: engine trails, muzzle flashes, impact sparks,
   explosions, jump-gate and docking effects, camera shake.
7. Window upgrade: 1920×1080 base resolution, fullscreen support, proper scaling;
   all ~25 screens re-verified at the new size.
8. UI completion: military-stencil display font + readable HUD companion font,
   icons, existing dark-navy theme extended to every control type, hangar backdrop
   images behind dock screens.
9. Sound effects: engine hum tied to throttle, weapons, impacts, docking, UI —
   replacing the generated beeps.
10. Store identity: Draywar logo, desktop/taskbar icon, Steam capsule/key art.

**Out (explicitly):**
- Music (deferred by decision — sounds yes, music later).
- In-cockpit camera view (mood reference only; candidate for a future pass).
- Visible 3D docking sequences (docking stays menu-based, with hangar backdrop art).
- Raising the 20-ship performance budget.
- Any change to combat hitboxes or tuned combat values.
- Visible models for the 10 equipment items (shield boosters etc.) — they stay
  internal; only weapons render on hulls.

## 4. Invariants — things this pass must not break

1. **Hitboxes and combat feel.** Collision shapes are separate constants, deliberately
   not derived from meshes. New models are sized to the existing hitboxes. The
   recently tuned values (swept-bolt collision, spawn grace distance, hit sphere)
   are untouchable.
2. **Readability axes.** Four things are currently told apart by color and must stay
   instantly readable after the repaint: (a) which star system you are in,
   (b) civilian vs patrol vs pirate, (c) hauler vs fighter, (d) standing tier.
   Solution: silhouettes + liveries for ships; trim colors + lighting keep system
   identity on stations.
3. **Accessibility (signed gate).** Standing tiers render as color + glyph + word,
   never color alone. `BalanceStanding.tier_color()` and its guarding tests are
   untouched.
4. **Time-scale correctness.** The game runs at 1×/4×/16×. Every new effect makes an
   explicit scaled-vs-real-time decision, and every effect is eyeballed and measured
   at 16× before its phase closes. (Precedent: the 16× projectile tunneling bug.)
5. **Pause correctness.** No new visual animates behind the pause menu. The existing
   process-mode convention and the tree-walking test apply to every new node.
6. **Performance is measured, not vibed.** 20-ship budget holds. Each phase lands
   with a frame-time measurement at the densest scene at 16×, compared to the
   pre-pass baseline (2.66 ms physics at 1× with 12 ships + 24 bolts was the last
   recorded measure; a fresh full baseline is taken in G0).
7. **Project gates.** Strict typing (warnings as errors), gdlint/gdformat, the
   type re-parse gate, boundary/globals/groups gates, the Main.gd line cap, and all
   941+ tests stay green at every phase close.
8. **No half-states.** An entity keeps its primitive build until its finished model
   lands, then switches over completely in one change.

## 5. Architecture

### 5.1 Assets enter the repo for the first time

New top-level folder `assets/` with subfolders: `models/`, `textures/`,
`liveries/`, `fonts/`, `audio/`, `ui/` (icons, hangar backdrops, logo),
`skybox/`. Import settings are committed alongside. `export_presets.cfg` keeps
s3tc_bptc textures (desktop-only target).

### 5.2 Model pipeline (image → game)

1. Generate base mesh + textures from Elliot's reference images using the chosen
   image-to-3D tool (bake-off in G1 — see §7).
2. Clean up in Blender via the installed Blender bridge: scale to match existing
   hitbox dimensions, orient to the game's forward axis, polygon budget, UV/material
   sanity, apply worn-metal PBR texture dressing (Poly Haven / ambientCG CC0 sets)
   where the generated textures fall short.
3. Export GLB into `assets/models/`; Godot imports it.
4. Entity scripts load the model scene instead of building primitives. The
   per-entity build functions (`PlayerShip`, `HostileNpc`, `TrafficShip`,
   `SystemWorld` station/gate builders) become loaders; collision construction
   stays exactly where it is.
5. `BalancePresentation.gd` evolves from "six primitive materials" into the single
   place that hands out hull/livery/VFX materials. It remains the one chokepoint.

Polygon budgets (starting points, confirmed by G0 baseline + G1 measurement):
player/hostile ships ≤ 15k triangles, traffic ≤ 8k, station ≤ 30k, gate ≤ 15k,
projectiles stay primitive-simple with better materials.

### 5.3 Livery system

- Each ship model carries paint regions (mask): base coat, accent/stripe, markings.
- A livery is a small data resource (`.tres`): region colors + optional decal set.
- Each of the 8 entities/factions gets one livery. The two player hulls get a
  default player livery. Traffic roles (civilian/patrol) read via operator liveries.
- Hostiles keep a recognizably hostile scheme family so threat-reading stays instant.
- Liveries apply through the material chokepoint, so adding a skin later is data
  entry, not code.

### 5.4 Hardpoints and weapon visuals

- Every ship model carries named attachment points (hardpoints) placed during
  Blender cleanup: wingtips, nose, belly per hull as the silhouette allows.
  Hardpoints are part of the G1 hauler deliverable — retrofitting them later
  would mean redoing models.
- Weapon-model **families** cover all 12 weapons: cannon, twin cannon,
  launcher/pod, heavy barrel — differentiated by size, barrel count, and
  material. A weapon data row names its family + variant; no per-weapon sculpts.
- Equipping a different weapon swaps the mounted model on the player's ship.
  Hostiles mount their profile loadouts; traffic ships carry fixed simple mounts.
- Muzzle flashes and beam effects originate from the mounted barrels.
- **Invariant guard:** projectile *spawn* positions and the tuned combat values
  (spawn grace distance, swept collision) do not move. Barrels are aligned to the
  existing spawn math, never the reverse. This wiring is a Claude-tier job, not a
  mechanical one.

### 5.5 Paint shop (player feature)

- New station screen: list owned + purchasable skins, live preview on the player's
  hull, purchase with credits through the existing market/credits services.
- Skin ownership and the equipped skin persist in the save file (save version bump
  with migration for old saves: default livery).
- Skin prices live in the balance layer like every other price; the price list is
  part of the G7 gate Elliot signs.
- Tests: purchase deducts correct credits, ownership persists across save/load,
  equipped skin survives save/load, refusal path when credits are short.

### 5.6 Environment

- Starfield: replaced by a skybox pipeline — procedural star shader layered over
  deep-space imagery (CC0/public domain), one variant per system, seeded/stable
  per system exactly as today.
- `WorldEnvironment` gains glow, subtle haze/fog, and a filmic color treatment,
  tuned warm/dusty to match the reference mood; per-system tint preserved so all
  8 systems stay distinct.
- Sun/planets/moons get textured surfaces; asteroid-belt collision behavior
  unchanged.

### 5.7 Effects

GPU particles for trails/impacts/explosions/jump/dock; camera shake + small FOV
kick on hits, kills, and jumps in `ChaseCamera`. Every emitter declares its
time-scale behavior explicitly and respects pause via the existing convention.

### 5.8 Window and UI

- Project display settings set explicitly: 1920×1080 base, `canvas_items` stretch,
  aspect keep, fullscreen toggle + resolution handling in options.
- Windowed mode stays available at the current 1152×648 default; fullscreen runs
  at native resolution. All ~25 screens are re-verified at both sizes. The two
  recent off-screen-panel bugs make this a first-class verification job, not a
  formality.
- Fonts: military-stencil display face for titles + highly readable mono/technical
  companion for HUD numbers and body text. Candidates (all free for commercial
  use, Google Fonts): Black Ops One / Saira Stencil One / Big Shoulders Stencil
  for display; Share Tech Mono / JetBrains Mono / Rajdhani for HUD. Final pairing
  is chosen on real screenshots at the G1 gate.
- `DraywarUiTheme.gd` extends to every control class in use (scroll containers,
  line edits, option buttons, sliders, trees).
- Icons where the UI is text-only; hangar backdrop art behind dock screens (in the
  reference style, warm practical lighting).

### 5.9 Audio (SFX only)

Real samples replace generated beeps: engine loop tied to throttle, weapon fire,
impacts, dock/undock, UI clicks. Existing bus layout (Master/UI/SFX) stays.
Sources are license-clean (see §7). Music remains out of scope.

### 5.10 Store identity

Draywar logo (title screen + key art), proper desktop/taskbar icon (replaces the
placeholder `icon.svg`), Steam capsule/key art composed from the reference
imagery — the hangar shot is the key-art base. Produced as a 2D workstream in G8.

## 6. Phases and gates

Each phase on its own branch, merged when its gate passes. Every phase ends with
something Elliot can look at.

| Phase | Content | Gate |
|---|---|---|
| **G0 — Foundation** | 1080p/fullscreen/stretch + all screens re-verified; `assets/` structure + import conventions; fresh perf baseline at densest scene, 1× and 16× | All tests green; Elliot confirms the game still plays right at the new window |
| **G1 — The slice (style gate)** | Hauler model with hardpoints + default livery + one weapon family mounted; one full system backdrop + celestials; one station + gate; engine trail + impact + one explosion; font pairing on HUD; one hangar backdrop; image-to-3D bake-off decides the generation tool | **Elliot signs the style on 1080p screenshots. Nothing fans out until signed.** |
| **G2 — The fleet** | All remaining ship models with hardpoints; all weapon families + visible swapping; hostile loadouts mounted; all 8 faction liveries; projectile material/glow/trail upgrade | Screenshot review; readability spot-check (friend/foe/hull at combat distance); weapon-swap check at the outfitting screen; tests green |
| **G3 — The world** | All 8 system backdrops + celestials; remaining 15 stations; all gates | Screenshot review per system; system-identity spot-check |
| **G4 — Effects** | Full VFX set + camera work | Reviewed in motion at 1×/4×/16×; frame-time measurement vs G0 baseline |
| **G5 — Interface** | Theme to all control types; icons; all screens finished; hangar backdrops everywhere | Screen-by-screen review at 1080p |
| **G6 — Sound** | Full SFX set; beeps retired | Played session review; licenses logged |
| **G7 — Paint shop** | Browse/preview/buy/persist; price list | Feature playtest; save/load tests; Elliot signs prices |
| **G8 — Identity + close** | Logo, icon, key art; final polish | Full playthrough at 1× and 16×; final perf measure vs budget; **Elliot signs the pass closed** |

## 7. Sources, licensing, and spend

Researched 2026-08-08 against live pricing pages and license files (sources and
dates in the session research reports).

| Need | Source | License | Cost |
|---|---|---|---|
| Ship/station base models | Bake-off in G1: Meshy vs Tripo vs Hyper3D Rodin on the hauler reference image (free previews), then **one month** of the winner | Paid tiers: full commercial ownership, no attribution | ~$20–30 once, asked before buying |
| Worn-metal PBR textures | Poly Haven, ambientCG | CC0 / public domain | Free |
| Space backdrops | Procedural shader + Poly Haven / NASA imagery; fallback Blockade Labs one month if no free nebula matches | CC0 / public domain; Blockade paid = commercial | Free; fallback ~$20 once, asked first |
| Fonts | Google Fonts (candidates in §5.8) | SIL OFL / Apache | Free |
| SFX | Kenney packs first; Sonniss GDC bundle second; Freesound only CC0 with per-file check | CC0 / royalty-free commercial | Free |

**Ruled out, and why:** Tencent Hunyuan3D — license excludes EU/UK (Steam sells
there) and contains an unqualified "no military purposes" clause; the game is a
military-themed commercial product. Microsoft TRELLIS.2 — unresolved commercial-
licensing question on a required dependency (open issue in their tracker). Neither
ships in this game. Freesound CC-BY-NC files are unusable (non-commercial only) —
every Freesound download gets an individual license check.

**Expected total cash for the pass: ~$20–60.** Every purchase is asked at buy time
with the price.

A `docs/ASSET_LICENSES.md` ledger is created in G0 and updated every time an
asset enters the repo: file, source, license, date. This is the audit trail for
Steam.

## 8. Staffing

Both builder subscriptions are flat-rate (Claude Max; Grok subscription), so the
split is about fit and capacity, not per-token price.

- **Claude (strongest available tier, in Claude Code on this machine):** all
  judgment work — art direction calls, model generation/cleanup through the
  Blender bridge, shaders, lighting, environment tuning, livery/paint-shop
  architecture, and anything "mechanical but could turn tricky" (livery wiring,
  resolution scaling).
- **Grok (current arrangement):** pure repetition from tight specs — per-entity
  swap wiring once the pattern is proven in G1/G2, per-screen re-checks, data
  entry for the 8 faction liveries once the first two are approved.
- Jobs are sorted by **risk**, not just by type: if a "mechanical" job touches a
  signed invariant (§4), it goes to Claude.
- Research note (Aug 2026, sourced): current Claude models lead the hardest
  real-world coding benchmark; mid-tier Sonnet 5 edges Opus 5 at lower cost; Grok
  4.5 is efficient on spec-following work. All models occasionally emit outdated
  Godot syntax — the protection is the live project tooling and this repo's strict
  gates, which apply to every builder equally.

## 9. Risks

| Risk | Mitigation |
|---|---|
| Generated models disappoint on the reference style | G1 bake-off across three tools before any money or fan-out; fallback is hand-modeling in Blender via the bridge over a simple hull + CC0 grit textures |
| Style drifts apart across phases | Single style gate (G1) before fan-out; all materials through one chokepoint; reference images in-repo |
| Effects/skybox eat the frame budget | Fresh G0 baseline; per-phase measurement at 16× densest scene; 20-ship budget is a hard line |
| 1080p breaks screens (it has before) | G0 does the window change first and re-verifies every screen before any art lands on top |
| License contamination | §7 ruled-out list; per-file checks on mixed-license sites; `ASSET_LICENSES.md` ledger from G0 |
| Collision with the fix pass | This pass starts only after the fix pass closes; the only pre-close artifact is this document |
| Save-file breakage from skins | Save version bump + migration test (old saves get the default livery) |

## 10. Open items

1. **Elliot: copy the 8 reference images into `docs/art_direction/`** (they exist
   only in the planning chat right now; the repo needs them for builders).
2. Music pass — future decision.
3. Cockpit view — future pass candidate; HUD styling in this pass leans toward it.
4. Steam page timing (capsule art from G8 feeds it) — Elliot's call, outside this pass.

## 11. Decision log (all Elliot, 2026-08-08)

- Bar: full production look.
- Style: worn industrial per own reference images ("WWII bomber in space").
- Scope: everything visual + SFX; music deferred; store art (logo/icon/key art) in.
- Sources: free packs + AI generation; no Hunyuan3D/TRELLIS.2; spends asked first.
- Liveries: hulls stay colorful via government/org schemes; player skins.
- Paint shop: **full feature this pass** (browse/preview/buy/persist).
- Cockpit image: mood reference only. Hangar image: dock-screen backdrops + key art.
- Window: 1920×1080 + fullscreen this pass.
- Structure: A — slice first with style gate, then scale out.
- Staffing: Option A risk-sorted (Claude judgment, Grok mechanical), both flat-rate.
- Weapons: ships get hardpoints with visibly swappable weapons; model **families**
  (not 12 unique sculpts) cover all weapons; equipment stays invisible.
