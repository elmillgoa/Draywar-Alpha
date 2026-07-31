# Draywar Alpha — Decision-bar phase plan (Path C)

**Status:** Draft for Elliot agreement · after sign-off = build authority for Path C  
**Date:** 2026-07-31  
**Checklist authority:** `Alpha/ALPHA_DECISION_BAR.md` (ratified)  
**Standing law:** `docs/reputation_and_standing.md`  
**Does not replace Destination** after Final Alpha Gate.

---

## Goal

Close every decision-bar row to **good enough to judge**, then re-run **Final Alpha Gate**.

Not full game. Not full art/sound. Not black void + mystery boxes.

---

## Rules for every phase

1. **Play proof beats unit tests.** Tests required; they do not alone close a row.  
2. **Fantasy path without debug console.** Console stays for debug only.  
3. **EventBus-only** cross-system; balance numbers in balance layer; content as data.  
4. **Standing mutations** only through StandingService.  
5. **Do not invent standing rules.** Escalate.  
6. **Ceilings** still apply unless Elliot raises them (systems 3–4, entities 4–6, people 12–18, one recovery chain).  
7. Phase end = definition of done + adversary/verify as needed + state update + commit. Human gates only where marked.

---

## Parallelism (Grok Build worktrees)

Use **isolated git worktrees** when tracks do not thrash the same core files.

| Track | Safe to parallelize with | Avoid parallel with |
|-------|--------------------------|---------------------|
| **World** (travel, gates, systems) | UI shell, presentation art assets, combat sandbox | Mission destination rules if same frames |
| **UI shell** (menu, pause, sheet, job panel) | Combat damage prototype, trade data shapes | Main.tscn boot rewrites same time |
| **Presentation** (skybox, silhouettes, UI theme) | Almost everything if assets-only | Systems that hardcode mesh colors heavily |
| **Trade** | Combat (after wallet/cargo seam lands) | Wallet save schema churn |
| **Combat** | Trade (after shared ship/NPC hooks) | Attribution + standing if both rewrite StandingService |

**Orchestration pattern for a build chat:**

1. Main agent reads `docs/state.md` + this plan → picks **one phase**.  
2. Splits phase into **tracks** below.  
3. Spawns worktree agents for independent tracks.  
4. Main merges in dependency order, runs lint/tests once, updates state.  
5. Max parallel tracks per phase: **2–3** unless Elliot says more.

**Shared merge choke points (serialize):**

- `src/Main.gd` / `Main.tscn` boot  
- `EventBus.gd` + `docs/events.md`  
- `SaveConsoleCommands` / save schema sections  
- `StandingService.gd`  
- `Balance*.gd` (coordinate; prefer one writer per phase for a domain file)

---

## Dependency graph (why this order)

```
B0  World playable (3–4 systems you can reach)
 │
 ├─► B1  Presentation floor (readable world + UI chrome)
 │
 └─► B2  Session shell (main menu, pause, save/load UI, captain sheet, job tracking)
          │
          ├─► B3  Station depth + trade + money loop completeness
          │
          └─► B4  Thin combat (matters for standing / survival)
                   │
                   ▼
                 B5  Content pack + standing drama pass + Final Alpha Gate
```

B1 can start **in parallel** with late B0 if art/UI theme does not touch gate travel code.  
B3 and B4 can run **in parallel** after B2 lands shared HUD/sheet and wallet/cargo seams.

---

## Phase B0 — World you can actually travel

**Closes checklist:** #2 World/travel (primary), contributes #12 NPC, #15 content skeleton  

**Why first:** Nothing else can be vetted if the player only ever sees one start system.

### Scope

- 3 systems (Alpha / Beta / Gamma already in data) **reachable in play** without a scavenger hunt  
- Jump **discoverable**: nav hint / map marker / long-range gate cue / system list — pick one clear UX  
- Each system **tells apart** (lighting, backdrop tint, station silhouette, status line already helps)  
- Dock at each system’s station; status moment on every system entry  
- Gate travel reliable (fuel cost OK; failure feedback clear)

### Acceptance

- Cold boot → undock → reach second system → dock → third system → back, **no console**, under ~10 minutes guided by UI  
- Player can name which system they are in without opening the editor  
- Automated tests for jump + multi-system build; **play smoke** recorded in state  

### Parallel tracks (worktrees)

| Track | Work | Depends |
|-------|------|---------|
| **B0-A World** | Gate discoverability, jump UX, system visual distinction, docking per system | — |
| **B0-B Nav UI** | Minimal system map or gate list + current system (can be HUD-only) | EventBus system enter (exists) |

Merge: B0-A then B0-B if both open, or single agent if small.

### Out of scope

Combat, trade, full art pipeline, new systems beyond 3–4.

---

## Phase B1 — Presentation floor

**Closes checklist:** #14 Presentation floor; improves #3, #12  

**Why early:** Decision bar says more than black + primitives. Placeholders OK; readable required.

### Scope

- Space backdrop (skybox / gradient / starfield) — not pure black  
- Ship / station / gate / NPC: distinct silhouettes or simple textured placeholders (not identical boxes)  
- Shared UI theme (panel, fonts, colors) applied to station menu + new menus  
- Optional: simple VFX for dock/jump (cheap)

### Acceptance

- Screenshot or play note: “reads as a game scene, not a mesh debug view”  
- Theme used by station menu and at least one new UI surface  

### Parallel tracks

| Track | Work | Depends |
|-------|------|---------|
| **B1-A Environment** | Skybox/stars, system tint | Can start during B0 |
| **B1-B Entities look** | Ship/station/gate/NPC meshes or sprites | Can start during B0 |
| **B1-C UI theme** | Theme resource + apply to existing StationMenu | Avoid fighting B2 if both touch same files — apply theme after B2 if conflict |

**Parallel with B0:** B1-A and B1-B recommended in worktrees while B0-A builds travel.

### Out of scope

Final art, audio pack, animation production.

---

## Phase B2 — Session shell (menu, sheet, jobs, save)

**Closes checklist:** #4 Main menu/pause, #5 Character sheet, #6 Job tracking, #13 Save/load (primary), improves #3  

**Why before trade/combat:** Session frame so play is a career, not a floating scene.

### Scope

- **Main menu:** New game / Continue / Quit (settings optional: volume/fullscreen stub OK)  
- **Pause menu** in flight: resume, captain sheet, save, load, quit to menu  
- **Captain sheet:** credits, fuel, hull, active job, standing summary (local or top entities), ship name/hull  
- **Job tracking:** objective text, destination, status; abandon/complete only where rules allow; always visible when active (HUD + sheet)  
- **Save/load** from menu/pause (not console-only); round-trip standing + wallet + position/system if schema allows (optional section; no silent data loss)

### Acceptance

- Boot → menu → new game → play → pause → save → quit → continue → same career state  
- Active job destination obvious without guessing  
- Tests for save sections; play smoke for menu loop  

### Parallel tracks

| Track | Work | Depends |
|-------|------|---------|
| **B2-A Boot & menus** | Main menu scene, pause, flow into Main play | B0 done preferred |
| **B2-B Sheet + jobs UI** | Captain sheet, job panel, wire Mission/Recovery readouts | MissionService APIs |
| **B2-C Save UX** | Menu save/load + persist system/position if agreed | Wallet + standing sections exist |

**Note:** Save schema changes after A0 → **ask Elliot** if new **required** fields; optional sections preferred.

### Out of scope

Trade inventory UI (B3), combat HUD full (B4).

---

## Phase B3 — Station depth, trade, money loop

**Closes checklist:** #3 Station menus (complete), #9 Trade, #11 Money loop  

### Scope

- Station UI sections: services (fuel/repair), jobs, **trade**, recovery contact, undock  
- Thin **trade:** buy/sell at least a few commodities; cargo capacity; credits move; optional standing soft effect (legal trade already exists)  
- Money: job pay, trade, fees, fuel, repair all visible on sheet  
- Content: commodity data under ceiling (6–8 max)

### Acceptance

- Dock → buy something → undock → sell elsewhere or same station → net credit change without console  
- Station menu readable under B1 theme  

### Parallel tracks

| Track | Work | Depends |
|-------|------|---------|
| **B3-A Trade systems** | Cargo, commodity content, buy/sell service, save cargo | B2 wallet/sheet |
| **B3-B Station UI** | Restructure station menu into sections | B1 theme, B2 patterns |

**Can parallel B4** after B2 if combat does not need cargo (prefer B3 cargo land first if loot later).

---

## Phase B4 — Thin combat

**Closes checklist:** #10 Combat; uses #7 attribution; improves #12  

### Scope

- Player weapons (one hardpoint class OK)  
- Hostile or ambient NPC that can fight (thin AI)  
- Damage to player hull (ties to condition/wallet repair)  
- Kill/damage path through **attribution** → standing where rules say  
- Encounter that **matters**: lose credits/hull or gain standing risk — not infinite invuln boxes  

### Acceptance

- Find or spawn a fight in play → deal and take damage → dock repair or die/fail state defined  
- At least one attributed standing change from combat in normal play (or clear unattributed lawless case)  
- Not full two-hull interlock  

### Parallel tracks

| Track | Work | Depends |
|-------|------|---------|
| **B4-A Weapons & damage** | Fire, projectiles/hitscan, hull HP | Player ship |
| **B4-B Hostile NPC** | Target player, die, attribution hook | B4-A, AttributionService |

**Parallel with B3** after B2: yes, separate worktrees; merge carefully on PlayerShip.

### Out of scope

Fleet ops, escort AI, full weapon matrix, heavy balance.

---

## Phase B5 — Content pack, drama pass, Final Alpha Gate

**Closes checklist:** #7, #8, #15 (primary), residual partials; **Final Alpha Gate**  

### Scope

- Content pass so 30–60 min vetting is real: jobs across systems, trade contrast, one recovery path obvious, places feel different  
- Standing drama scripted or guided: different treatment by place, sticky hole, recovery foothold — **all without console**  
- Fix leftover decision-bar partials from playtest notes  
- Prep Final Alpha play script; Elliot gate  

### Acceptance

- Every checklist row **Present / good enough** in `docs/state.md` table  
- Elliot plays Final Alpha script  
- **[GATE: ELLIOT]** Final Alpha — worth building beta/full or not  

### Parallel tracks

| Track | Work |
|-------|------|
| **B5-A Content data** | Jobs, copy, commodities, light dialogue strings |
| **B5-B Playability fixes** | Bugs from B0–B4 play |
| **B5-C Gate prep** | Script in `docs/gates.md`, state proof table |

Serialize gate itself (human only).

---

## Phase summary

| Phase | Name | Checklist rows | Parallel tracks | Gate |
|-------|------|----------------|-----------------|------|
| **B0** | World travel | #2, +#12/#15 | World + Nav UI | No |
| **B1** | Presentation floor | #14 | Env + meshes + theme | No |
| **B2** | Session shell | #4 #5 #6 #13 | Menus + sheet/jobs + save UX | No |
| **B3** | Trade & station | #3 #9 #11 | Trade systems + station UI | No |
| **B4** | Thin combat | #10 (+#7) | Weapons + hostile NPC | No |
| **B5** | Content + drama + Final Alpha | #7 #8 #15 + residuals | Content + fixes + gate prep | **Final Alpha** |

**Suggested start order in a build chat:**  
B0 (+ B1 tracks in parallel) → B2 → B3∥B4 → B5 → gate.

**Flight (#1):** keep; only touch if play breaks feel. A1 gate already signed.

---

## Fresh chat handoff

When Elliot agrees this plan:

1. Close this planning chat (optional `/wrap` for clean push).  
2. New chat: `/start` then **go on B0** (or **go on B0+B1 parallel**).  
3. Agents use worktrees for tracks listed in that phase.  
4. Do not skip to B3/B4 until B0 is play-proven multi-system.

---

## Agreement checkbox (Elliot)

- [ ] Phase order B0→B5 accepted  
- [ ] Parallel worktree rules accepted  
- [ ] Final Alpha only after B5 checklist green  

Edit this file if a phase should split or merge before build starts.
