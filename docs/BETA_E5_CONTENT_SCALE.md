# Beta E5 — Content scale toward Beta

**Status:** **CLOSED** — E5.1–E5.6 code complete; **E5.7 signed** 2026-08-02  
**Date:** 2026-07-31 (plan); E5.1–E5.6 built 2026-08-02; gate signed 2026-08-02  
**Authority:** Destination §1 Fidelity (hand-built universe / trade lanes) + §10 v1 budget + `docs/BETA_ROADMAP.md` E5 + standing law  
**Gates:** E1–E4 feel all signed; **E5.7 signed** — next phase **E6 Lived-in space**

## Job

Sector large enough for **multi-hour vetting**: more systems and docks, routes that force logistics choices, and a map/NAV that makes the larger graph readable — still **no** Operations or Holding.

## Locked defaults (no ask)

| ID | Lock |
|----|------|
| D1 | **Ship 6 systems** as the prove target (middle of roadmap 5–8). **Budget ceiling 8** (Destination v1). |
| D2 | **Stations ~10** content target; **budget 10** (Destination §10). Keep ≥1 dual-dock system; not every system needs 2 stations. |
| D3 | **Entities ≤6** (current budget). Prefer reuse of Reach / Drift / Fringe / Free Haulers as controllers. **0–1 new Entity** only if a system’s holder cannot honestly reuse. |
| D4 | **People ≤24** (small lift under Destination 20–35). New docks get Contacts used in play — not dead nameplates. |
| D5 | Gate graph **must branch** (not a single line of 6). At least one system with **two** gate exits. |
| D6 | Map/NAV is **functional first**: readable sector chart + current system + connections. Production art later. |
| D7 | **No fog of war** this phase — full chart known. Optional **visited** highlight is OK; not required for accept. |
| D8 | **No new job kind required.** Logistics uses courier / bounty / smuggle + trade. Escort stays OUT unless a later contract reopens it. |
| D9 | **E5.1 raises budgets first** in `Balance.CONTENT_BUDGET` before any new `.tres` that would fail load. Cap lifts are deliberate and documented in this file. |
| D10 | Status moment still fires on **every system entry** (local controller). Never hide or globalize. |
| D11 | Full-sized data shapes only (`StarSystem`, `Station`, etc.). No stub types. |
| D12 | New persistent state prefers **optional** save keys; missing keys = old saves still load. **Required** save schema changes = stop and ask. |
| D13 | Naming continues Greek letters for systems: keep Alpha / Beta / Gamma; add **Delta, Epsilon, Zeta**. Display names can be flavorful; ids stay `system_*`. |
| D14 | Standing mutations only via StandingService. No invented standing rules. |
| D15 | Performance budget stays **~12 ships** (1 player + traffic + hostiles). New systems must not break that. |

## Caps (E5)

| Element | Now (live) | E5 target | E5 budget ceiling | Destination v1 |
|---------|------------|-----------|-------------------|----------------|
| Star systems | **6** | **6** | **8** | 8 |
| Stations | **10** | **~10** | **10** | ~10 |
| Entities | 4 | 4–5 | **6** | 8–12 |
| People | **19** | ≤24 | **24** | 20–35 |
| Job kinds | 3 | **3** | (templates ≤12) | 4 kinds |
| Player hulls | 2 | **2** | 2 | 2 |
| Recovery chains | 2 | **2** | 2 | — |
| Commodities | (E3 set) | no forced expand | 10 | 12 |
| Performance | 12 ships | **12 ships** | 12 | — |

**Alpha hard ceilings no longer bind content count.** Final Alpha signed; E5 deliberately lifts past Alpha’s 3–4 systems. Architecture non-negotiables (standing writer, EventBus, status moment, full shapes) still bind.

## Starting map (today)

Linear chain only:

```
Alpha (Reach, patrolled, 2 docks)
  ↔ Beta (Drift, contested, 2 docks)
    ↔ Gamma (Fringe, lawless, 2 docks)
```

NAV is a **text** HERE + GATES panel on the flight HUD — not a sector chart.

## Target map (E5 content)

Six systems, **branched** (exact gate edges locked in E5.2; shape is not optional):

```
              Delta (new)
                 |
Alpha —— Beta —— Gamma
                 |
              Epsilon (new)
                 |
               Zeta (new)
```

| System id | Role (plain) | Controller (prefer reuse) | Policing | Stations (illustrative) |
|-----------|--------------|---------------------------|----------|-------------------------|
| `system_alpha` | Core Reach home | Reach | patrolled | Port + Yard (keep) |
| `system_beta` | Contested hub / branch point | Drift | contested | Hub + Spit (keep); **≥2 gates out** |
| `system_gamma` | Lawless fringe end | Fringe | lawless | Outpost + Rim (keep) |
| `system_delta` | Reach corridor / second lane | Reach (or Free Haulers flavor if held_by allows) | patrolled or light contested | 1–2 new docks |
| `system_epsilon` | Outer contested / smuggle belt | Drift or Fringe | contested or lawless | 1–2 new docks |
| `system_zeta` | Far spur — multi-hour depth | Fringe (or 0–1 new entity) | lawless | 1 new dock |

**Illustrative only for names of new docks** — implementers pick readable display names; ids `station_*`. Total stations after pack: **9–10**.

## Contracts

| ID | Name | Status |
|----|------|--------|
| E5.1 | Content budget lift | **complete** |
| E5.2 | Systems + stations pack | **complete** |
| E5.3 | Branch gate graph + world | **complete** |
| E5.4 | Multi-station logistics | **complete** |
| E5.5 | Map / NAV upgrade | **complete** |
| E5.6 | Integration / balance / perf | **complete** |
| E5.7 | **[GATE] Content scale feel** | **signed** 2026-08-02 |

### Sequencing

```
E5.1 (budget)
  → E5.2 (data pack)
    → E5.3 (gates + world wiring)
      → E5.4 (jobs/trade logistics)  ──┐
      → E5.5 (map/NAV)               ──┼→ E5.6 (integration) → E5.7 gate
```

E5.4 and E5.5 may proceed in parallel after E5.3 if two agents; both must finish before E5.6.

---

### E5.1 Content budget lift

**Status:** **complete** (2026-08-02)

**Shape:** Raise `Balance.CONTENT_BUDGET` (and comments) to E5 ceilings **before** adding files that would fail `ContentLibrary` load. No new play content required in this contract — only the deliberate lift + tests that assert the new ceilings.

| Key | From | To |
|-----|-----:|---:|
| `star_systems` | 4 | **8** |
| `stations` | 7 | **10** |
| `people` | 20 | **24** |
| entities / hulls / recovery / life_path | unchanged unless a later contract needs it | |

**Acceptance:**

1. `CONTENT_BUDGET` matches the E5 budget ceiling column above for systems, stations, people.  
2. Headless test or existing load path still fails loudly if counts exceed budget (behavior preserved).  
3. Live content still loads (3/6/15 under new ceilings).  
4. This doc’s Caps table and `docs/state.md` note the lift.  
5. Lint + GUT green.

**Evidence:** `Balance.CONTENT_BUDGET` at 8/10/24; `tests/test_e5_content_budget.gd` + existing over-budget path in `test_content_library.gd`; live counts still 3/6/15; lint + GUT green at complete.

---

### E5.2 Systems + stations pack

**Status:** **complete** (2026-08-02)

**Shape:** Add **Delta, Epsilon, Zeta** as full `StarSystem` resources + enough new `Station` resources to reach **9–10** docks total. Full-sized fields (held_by, policing, station_ids, flavor_line, position offsets). **0–1 new Entity** only if needed (D3). **2–6 new People** used on Contacts at new docks (not orphan data). Presentation: placeholders OK if systems are distinguishable (sky/light reuse patterns from E1.1).

**Acceptance:**

1. Exactly **6** star systems load via the data pipeline (ids include alpha/beta/gamma/delta/epsilon/zeta).  
2. Station count **9–10**; every station has a valid `system_id` and appears in that system’s `station_ids`.  
3. Each new system has ≥1 dock and a non-empty flavor line.  
4. Each new dock used in play has ≥1 Contact person wired (board or Contacts UI).  
5. Status moment data resolves for every new system (local controller entity exists).  
6. No new standing rules; no Ops/Holding content.  
7. Lint + GUT green (`tests/test_e5_content_pack.gd` or equivalent).

---

### E5.3 Branch gate graph + world

**Status:** **complete** (2026-08-02)

**Shape:** Wire `gate_destination_ids` so the six-system graph **branches** (D5). Beta (or another hub) has **≥2** gate destinations. Gate meshes + travel service work for every edge both ways (or document one-way only if deliberately designed — default **bidirectional**). World rebuild on jump still correct; undock/dock unchanged in law.

**Acceptance:**

1. Automated: graph is connected (every system reachable from Alpha by some gate path).  
2. Automated: at least one system has **≥2** distinct gate destinations (branch).  
3. Automated: graph is **not** a pure path of length 5 (proves branch, not a longer line).  
4. Headless or integration: jump Alpha → … → a new system succeeds; status moment fires for the destination controller.  
5. HUD/gate prompts list real destination display names for the current system’s gates.  
6. Station safe radius + undock grace still apply in new systems.  
7. Lint + GUT green.

---

### E5.4 Multi-station logistics

**Status:** **complete** (2026-08-02)

**Shape:** Make the larger sector **force route choices**, not only more scenery.

Minimum logistics pack (all required):

1. **Secondary-dock jobs** — at least one courier (or smuggle) offer that **starts or ends** at a non-primary dock (Yard / Spit / Rim / new secondary), not only Port/Hub/Outpost.  
2. **Long-haul jobs** — at least two board offers whose pickup and destination are **≥2 gate hops** apart on the new graph (so multi-hour path exists without console).  
3. **Trade contrast** — at least one commodity with a meaningful buy/sell spread between a core Reach dock and a far spur (Zeta or Epsilon); numbers in balance, asserted by test.  
4. Boards still stock without softlock: major docks keep ≥2 job options when stocked (E1 law preserved where boards exist).

No new job *kind*. No new standing law. Pay/standing only through existing mission + StandingService paths.

**Acceptance:**

1. Automated: ≥1 active template (or stocked offer path) references a secondary/new non-hub station as origin or destination.  
2. Automated: ≥2 stocked-or-template routes require ≥2 gate hops (graph distance).  
3. Automated: trade price contrast core vs far spur asserted from balance/content.  
4. Accept / carry / turn-in still works for courier and smuggle on a long route (integration or unit with services).  
5. Fighter still cannot take oversize smuggle holds (E3 law preserved).  
6. Lint + GUT green.

---

### E5.5 Map / NAV upgrade

**Status:** **complete** (2026-08-02)

**Shape:** Replace “text-only NAV is the whole story” with a **sector chart** the player can open in flight and/or pause.

Minimum chart (all required):

- Shows all **6** systems (D7 full chart).  
- Shows **gate connections** (lines or clear adjacency list per system).  
- Highlights **current** system.  
- Readable without production art (shapes + labels OK).  
- Existing flight HUD may keep a compact HERE/GATES strip; chart is the upgrade.

Optional (nice, not accept blockers): visited tint; station count under system name; open from station menu.

**Not in E5.5:** click-to-autopilot jump, warp from map, fog of war, 3D galaxy flythrough, paid map assets.

**Acceptance:**

1. Player can open a sector map UI without the console.  
2. Map lists/draws all loaded systems by display name.  
3. Map shows connectivity consistent with `gate_destination_ids` (test the data→UI mapping).  
4. Current system is visually distinct.  
5. Jumping updates current highlight after system enter (EventBus or existing enter signal).  
6. Status moment / standing UI unchanged in behavior.  
7. Lint + GUT green (`tests/test_e5_map_nav.gd` or equivalent).

---

### E5.6 Integration / balance / perf

**Status:** **complete** (2026-08-02)

**Shape:** One contract that proves the phase holds together: multi-system path, save/load, performance, no softlocks after opening cast.

**Acceptance:**

1. Automated scenario: New Game (or headless default career) → path that visits **≥4 systems including ≥1 new** → dock → job accept or trade → save → load → still in valid system with cargo/credits sane.  
2. Cold-path softlock check: default life path still reaches a job board and a gate without console.  
3. Perf: densest system still respects ~12-ship budget constants (no silent raise).  
4. `docs/events.md` updated if any new EventBus signals shipped in E5.1–E5.5.  
5. `docs/state.md` reflects code-complete E5 pending gate.  
6. Full lint + full GUT green.

---

### E5.7 Gate — Content scale feel

**Status:** open

**Criteria (plain):** After a long session, does the sector feel big enough to keep playing — routes, places, and map — without needing Ops or Holding yet?

Play script and attempt log: **`docs/gates.md`** → E5.7.

Sign → E5 closed; roadmap moves to post-E5 (Ops later).  
Refuse → iterate E5.1–E5.6 only; do not open Ops to “fix” scale.

---

## OUT (explicit)

- Operations (hired ships, charters, warehouses)  
- Holding / ignition endgame  
- Fog of war / system discovery meta  
- Click-to-jump / autopilot from map  
- Full visible **trade-lane meshes** in space (Destination flavor — honest gap if chart-only; do not block E5 on lane art)  
- 4th job kind (**escort**)  
- 3rd recovery chain  
- Dynamic economy / story campaign  
- Dead Charterfall edge mystery (**DEFERRED** in Destination)  
- Production art/audio pipeline  
- Raising entities to full Destination 8–12 (only 0–1 new if required)  
- Shipping all **8** systems this phase (budget allows; content target is **6**)  
- Greenfield rebuild of flight/combat/standing  

## Honest gaps (after E5 green, still not “product done”)

A serious multi-hour Beta will still lack: escort family, deeper NPC schedules, trade-lane spectacle, full 8 systems, Operations layer, and production presentation. E5 proves **scale and legibility**, not the whole Destination mid-game.

## Stop conditions (this phase)

- Invent standing rules not in `docs/reputation_and_standing.md`  
- New **required** save fields without asking  
- Paid deps / third-party assets without asking  
- Skip E5.7 or sign it as an agent  
- Build Ops/Holding early “because the map feels empty”  
- Silently cut systems/stations to pass a criterion  
- Raise budgets past Destination v1 without updating this plan and asking if past 8/10  
- Blow the 12-ship perf budget without a deliberate lock change  

## Sign-off

| Field | Value |
|-------|--------|
| Plan | **locked for build** 2026-07-31 (Elliot: plan now, build when usage resets) |
| Code | E5.1–E5.6 complete 2026-08-02 |
| E5.7 | open — play script in `docs/gates.md` |
| Next session | `/start` → **play + sign E5.7** |
