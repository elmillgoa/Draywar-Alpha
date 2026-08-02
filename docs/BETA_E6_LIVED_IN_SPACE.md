# Beta E6 — Lived-in space

**Status:** **PLAN LOCKED** (build next) — E5.7 signed 2026-08-02  
**Date:** 2026-08-02  
**Authority:** Destination Fidelity / Tone + `docs/BETA_ROADMAP.md` E6 + standing law + this file  
**Gates:** E1–E5 feel all signed; this phase ends at **[GATE] E6.6**

## Job

Turn each star system from a **toy box** (station + gate + a few ghosts) into a **place you fly through**: solid matter, real distances, a sky that reads as a system, ships you can attack with consequences, and density that matches law and habitation — still **no** Operations or Holding.

## Why this phase exists (Elliot, 2026-08-02)

After E5.7 sign (routes/map scale OK; flying fine), play feedback:

- Everything too close; fly straight through docks, gates, ships  
- Not every ship attackable  
- Pirates next to the gate feel wrong outside lawless  
- Want sun, planets, moons, belts; inhabited systems should feel busy  

**Decision:** Full E6 in package order **A → C → B → D**. Soft bump with **impact damage scaled by what you hit**. Not a half-slice.

## Locked defaults (no ask)

| ID | Lock |
|----|------|
| D1 | Build order **A → C → B → D** then integration → human gate. No reordering without `/escalate`. |
| D2 | **Soft bump** on solids (slide / push off along contact normal). Not a hard wall that freezes the ship. |
| D3 | Impact deals **hull damage to the player** (and to other ships when both are damageable). Damage scales by **obstacle mass class × relative impact speed** (see impact table). Station/gate take **no permanent destruction** this phase (props stay; player pays the price). |
| D4 | **Mass classes** live in balance only: `station`, `gate`, `rock`, `hostile`, `traffic_light`, `traffic_heavy` (names free; classes required). |
| D5 | **Layout stretch:** station pad, secondary dock (if any), and gates must read as separate places — not stacked in a 200 m knot. Target feel: **afterburner or sustained flight** between pad and gate (exact metres in balance; order-of-magnitude larger than today’s ~220 m gate offset). |
| D6 | **Encounter ecology by policing** (not one global “near gate” rule): **patrolled** — zero ambient pirates near pad/gate; optional far-out threat only if balance allows later. **Contested** — hostiles on lanes / mid-system / belt, not camping the undock. **Lawless** — freer placement including nearer gates. Station **safe radius + undock grace** still block pad ganking. |
| D7 | **Celestials are backdrop + landmarks** this phase: sun, ≥1 planet, optional moon, belt band. **No landing, no mining loop, no orbital physics.** Belts may include sparse **rock colliders** for impact class `rock`. |
| D8 | **Every live ship is lockable and damageable** after Package B (player, hostiles, traffic). Traffic kills use **existing AttributionService / standing law** only — no invented rules. |
| D9 | Traffic roles readable in lock/HUD: at least **civilian / patrol / pirate** (display names can vary; three roles). Patrols only where policing supports them (patrolled/contested). |
| D10 | **Performance:** deliberate ship budget lift for density. **E6 target cap: 20 concurrent ships** (player + traffic + hostiles) with 60 fps still the goal on the dev machine. If 20 fails, stop and report — do not silently drop density to fake the gate. Old `PERF_BUDGET_SHIPS = 12` becomes the E5 baseline, not the E6 ceiling. |
| D11 | Status moment still fires on **every system entry**. Never hide or globalize. |
| D12 | Standing mutations only via StandingService. Kill attribution only via AttributionService. |
| D13 | Full-sized data shapes only. Prefer **optional** save keys; required schema changes = stop and ask. |
| D14 | No Ops, Holding, escort job kind, fog of war, click-to-jump, production art pipeline, or greenfield flight rewrite. |
| D15 | Existing E2–E5 loops stay playable: dock, job, jump, trade, combat fairness (lead/bolts), recovery footholds, save/continue, opening cast. |
| D16 | Docking interaction stays **range + F** (or current interact). Collision must not softlock undock/dock; undock spawn stays clear of solids. |

## Caps (E6)

| Element | Live (E5 end) | E6 target | Ceiling this phase |
|---------|---------------|-----------|--------------------|
| Star systems | 6 | 6 (no forced +systems) | 8 |
| Stations | 10 | 10 (use distance/traffic to feel multi-dock) | 10 |
| Entities / People | 4 / ≤24 | no forced lift | 6 / 24 |
| Job kinds | 3 | 3 | 3 |
| Player hulls | 2 | 2 | 2 |
| Concurrent ships | 12 | **≤20** | **20** |
| Ambient hostiles / system | ≤3 | ≤3 (pirates stay thin) | 3 |
| Celestial bodies / system | 0 real | sun + 1–2 planets + optional moon + belt | per-system hand layout |
| Collision mass classes | none | **6** (D4) | 6 |

**Alpha/E5 content count ceilings still hold.** E6 is **in-system fidelity**, not more Greek letters.

## Packages → contracts

| Package | Contract | Name |
|---------|----------|------|
| **A** Solid space | **E6.1** | Layout, solids, soft bump, impact damage, encounter ecology |
| **C** Lived-in sky | **E6.2** | Celestial backdrop + per-system landmarks |
| **B** Every ship a target | **E6.3** | Lock/fire traffic; roles; standing on kills |
| **D** Density | **E6.4** | Traffic counts by law/habitation; use multi-dock space |
| Glue | **E6.5** | Integration / balance / perf |
| Gate | **E6.6** | **[GATE] Lived-in space feel** |

### Sequencing

```
E6.1 (Package A — solids + layout + ecology)
  → E6.2 (Package C — sky)
    → E6.3 (Package B — attackable traffic)
      → E6.4 (Package D — density under ship cap)
        → E6.5 (integration) → E6.6 gate
```

No parallel packages that touch the same ship collision or traffic code without a single owner contract. E6.2 may start art-only constants after E6.1 layout anchors exist (system origin / sun direction locked in E6.1).

---

## Impact damage (locked behaviour)

Soft contact = velocity component into the surface is **cancelled or reduced**, lateral slide kept (soft bump). Damage applies on impact when relative closing speed exceeds a **minimum threshold** (balance).

Rough model (tunable in balance, not free numbers in entity code):

```
damage = IMPACT_BASE * mass_class_factor(obstacle) * speed_factor(closing_speed)
```

| Mass class | Feel (plain) | Player damage | Other ship damage |
|------------|--------------|---------------|-------------------|
| `station` | Hitting a city | **High** | n/a (station not destroyed) |
| `gate` | Hitting heavy infrastructure | **High** | n/a |
| `rock` | Asteroid chunk | Medium | n/a |
| `hostile` | Fighting hull | Medium | Both take impact |
| `traffic_light` | Small freighter / courier | Low–medium | Both take impact |
| `traffic_heavy` | Fat hauler / patrol boat | Medium–high | Both take impact |

**Crippled at 0 hull** still applies. Ramming is a weapon with consequences — not free. No standing change from ramming alone unless a kill is attributed through existing combat kill path (if impact kills a ship, treat as kill for attribution when Package B is live; until then hostiles only).

---

### E6.1 Package A — Solid space

**Status:** complete (2026-08-02)  

**Shape:**

1. **Layout** — Reposition primary station, secondary stations, and gate arcs so pad → gate is a real transit. Multi-dock systems place secondaries off-axis (not on the pad). Safe undock volume clear of solids.  
2. **Collision layers** — Player, hostiles, traffic, stations, gates, rocks participate. Soft bump (D2).  
3. **Impact damage** — Table above; all factors in balance.  
4. **Encounter ecology** — Rewrite ambient spawn offsets by policing (D6). Bounty ensure still finds prey outside safe radius and in lock range when required.  
5. **Flight feel preserved** — soft bump must not recreate A1 nausea; if it does, retune damping before gate.

**Acceptance:**

1. Player cannot ghost through station mesh, gate mesh, hostile, or traffic hull (asserted in headless tests with forced overlap → separation / blocked penetration).  
2. Soft bump: after head-on contact, ship retains lateral motion / does not hard-stop to zero in one frame (behaviour test or documented physics constants + integration test).  
3. Impact damage: same closing speed vs `station` deals **more** player damage than vs `traffic_light` (numeric assert from balance).  
4. Impact above threshold damages player hull; below threshold = bump only.  
5. Gate still interactable with **F** in interact radius; collision does not prevent interact when in range.  
6. Layout: distance station→nearest gate **≥** balance `LAYOUT_MIN_STATION_GATE_SEPARATION` (new constant; clearly larger than pre-E6). Secondary dock (if present) **≥** `LAYOUT_MIN_DOCK_SEPARATION` from primary.  
7. Patrolled system: **zero** ambient combat hostiles inside station safe radius and inside gate approach radius on build.  
8. Contested: ambient hostiles allowed; spawn positions **outside** safe radius and **not** on the undock pad; preferred mid/lane/belt slots from balance.  
9. Lawless: denser/meaner placement allowed nearer gates than contested (assert difference).  
10. Bounty ensure still works.  
11. Save/load, dock/undock, jump loop green.  
12. Lint + full GUT green.  
13. No new standing rules. No Ops/Holding.

---

### E6.2 Package C — Lived-in sky

**Status:** complete (2026-08-02)  


**Shape:** Per-system celestial layout (data or balance-driven hand layout): **sun direction/disc**, **1–2 planets**, optional **moon**, **belt band** (visual + optional sparse rocks with mass class `rock`). Systems must be **visually distinct** at a glance (Alpha ≠ Zeta). No landing, no mining.

**Acceptance:**

1. Every loaded system has a sun cue and at least one planet-scale body visible from the primary pad (or documented fail if intentionally black-site — none for E6 content).  
2. At least three systems differ in planet/belt layout enough that a screenshot test or scene query shows different body counts/colours/placements.  
3. Belt rocks (if any) use mass class `rock` and soft-bump rules from E6.1.  
4. Celestials do not break docking, gates, or status moment.  
5. Perf: adding backdrop meshes does not alone break smoke boot / 60 fps goal with empty traffic.  
6. Lint + GUT green.

---

### E6.3 Package B — Every ship a target

**Status:** complete (2026-08-02)  

**Shape:** Traffic ships are **lockable** (Tab cycle includes them), **damageable** by player bolts and impact, and **can die**. On death: AttributionService with witnesses (live traffic/patrol count). HUD/lock shows **role** (civilian / patrol / pirate). Hostiles remain pirate-role. Patrolled systems may spawn **non-hostile patrol** traffic (not free kills without standing cost).

**Acceptance:**

1. Every live ship class (player excluded as target) is lockable when in lock range rules.  
2. Player bolts damage traffic; traffic can reach 0 hull and despawn/die.  
3. Kill of civilian/patrol in **patrolled** space attributes to controller (standing falls) when witnesses/evidence rules say so — same law as combat kills, not a new rule.  
4. Kill in **lawless** without evidence stays quiet when law says so.  
5. HUD/lock line distinguishes role (string from balance).  
6. Ramming kill (impact to 0) goes through same death/attribution path as bolt kill.  
7. Cannot softlock: dead traffic removed from lock list; Tab still works.  
8. Lint + GUT green.  
9. No invented standing rules.

---

### E6.4 Package D — Density

**Status:** pending  

**Shape:** Raise live traffic toward the **20-ship** budget by policing/habitation: patrolled home systems denser near pads; lawless thinner but meaner hostiles; contested mixed. Use existing dual docks so secondary stations have **some** local traffic or landmark spacing from E6.1 (not empty clones). Hostiles still ≤3 concurrent combat targets unless balance deliberately raises (default stay ≤3).

**Acceptance:**

1. `PERF_BUDGET_SHIPS` (or successor) is **20** and tests assert densest system spawn ≤ cap.  
2. Patrolled Alpha (or densest patrolled) live non-player ship count **>** pre-E6 typical (assert floor, e.g. ≥8 including hostiles 0). Exact floor in balance.  
3. Lawless densest combat pressure still respects hostile cap; traffic + hostiles ≤ 20.  
4. Dual-dock system: secondary dock not co-located with primary (E6.1) and has either traffic nearby or a clear empty approach (not overlapping primary pad).  
5. Headless densest-system smoke: no hard error; optional frame-time probe if project already has one.  
6. Lint + GUT green.

---

### E6.5 Integration / balance / perf

**Status:** pending  

**Shape:** One continuous career path: New Game → open space transit pad→gate → sky reads → lock/shoot a freighter (standing feedback) → contested/lawless ecology differs → multi-dock hop → save/continue. Tune impact damage so casual docking approach does not cripple; deliberate ram does. Retune flight only if soft bump broke A1 feel.

**Acceptance:**

1. Cold path scriptable in tests or manual checklist: dock, undock, transit, gate, combat, traffic kill standing, save/load.  
2. Opening cast + Continue skip still hold.  
3. E3 money teeth and E2 combat fairness (lead/bolts) still hold.  
4. Full GUT green; lint green.  
5. `docs/state.md` + journal updated.  
6. No Ops/Holding creep.

---

### E6.6 **[GATE] Lived-in space feel**

**Status:** open (after E6.5)  

**Criteria (plain):** After a session in open space, does a system feel like a **place** — solid, spaced, sky, ships that matter, density by law — enough to keep expanding, without needing Ops yet?

**What that means in play:**

- You bounce off stations/ships; ramming hurts more into a station than a small freighter.  
- Pad and gate are a **trip**, not a hop onto the same prop.  
- Sun/planets/belt make systems look different.  
- You can lock and shoot freighters/patrols; standing reacts where law says.  
- Patrolled feels busier and safer near the pad; lawless feels meaner; pirates are not default gate greeters in government space.  
- Flying still controllable (A1 not reopened lightly — flag if broken).

**Play script (cold, ~45–75 min):** see `docs/gates.md` → E6.6 (added with this plan).

Sign → E6 closed; roadmap moves on (Ops still later unless re-prioritised).  
Refuse → iterate E6.1–E6.5 only; do not open Ops to “fix” empty space.

---

## OUT (explicit)

- Operations / Holding  
- Planet landing, surface content, orbital simulation  
- Asteroid **mining** loop / resource nodes as economy  
- Full production art/audio pipeline (E6 uses readable primitives + lighting — same honesty as E1 presentation floor)  
- Escort job kind  
- Trade-lane ribbon meshes as a hard accept (nice-to-have only)  
- Raising system/station budgets past E5 without a new plan  
- Greenfield rewrite of flight, standing, or save  
- Hard-stop collision (locked out by D2)  
- Indestructible player ramming (locked out by D3)

## Honest gaps (after E6 green)

Still not a shipped space sim: no mining, no customs minigames, no fleet ops, no AAA art, no dynamic economy, no 8th system required, traffic AI will still be thin (lanes/orbits lite, not Elite full simulation). E6 proves **place**, not **product done**.

## What a more serious production version would still add (named gaps)

| Gap | Why it matters | When |
|-----|----------------|------|
| Lane meshes / freight spectacle | Eyes read commerce | post-E6 presentation |
| Deeper NPC schedules / undock waves | Ports feel alive over time | Ops-adjacent |
| Patrol AI that intercepts | Crime has response | post-E6 combat |
| Destructible modules / wrecks | Ramming spectacle | later |
| Audio pass (engines, impacts, radio) | Presence | art pipeline |
| Mining / belt economy | Belts more than paint | economy phase |
| Per-system music / VO | Tone | art pipeline |

## Stop conditions (this phase)

- Invent standing rules  
- New **required** save fields without asking  
- Paid deps / third-party assets without asking  
- Skip E6.6 or agent-sign the gate  
- Build Ops/Holding early  
- Silently cut density or collision to “pass”  
- Blow 20-ship budget without reporting  
- Reorder packages A→C→B→D without escalate  
- Hard-stop collision or zero impact damage against D2/D3  

## Sign-off

| Field | Value |
|-------|--------|
| E5.7 | signed 2026-08-02 |
| E6 plan | locked 2026-08-02 |
| Collision | soft bump + scaled impact damage |
| Package order | A → C → B → D |
| Ship budget | 20 |
| Next | Build E6.1 in a fresh chat |

**Kickoff:** open new chat in this repo → `/start` → position should read E6 plan locked, next **E6.1**. Then `/work` or “go on E6.1”.
