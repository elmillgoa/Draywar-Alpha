# Beta E1 — Legible Sector

**Status:** **SIGNED** (Elliot 2026-07-31) — build in order  
**Date:** 2026-07-31  
**Authority after Final Alpha:** Destination filters (Fidelity / Tone) + standing law. Alpha architecture stays.

**Sign-off choices:**

- Plan: E1 as written  
- E1.5: **A — Enforcement lite**  
- E1.2: **Second stations in existing systems** (not a new system)

---

## Why this phase exists

Final Alpha **signed**. The loop works. It still *looks and plays* like a small gray-box demo:

- 3 systems, 3 stations, all same layout shape  
- 1 job kind (delivery × 3)  
- 1 pirate type, 0 real art assets, silent world  
- Trade is a price list; people are nameplates  

E1’s job: a cold **45–90 min** session feels like a **small real game**, not a tech demo — without redesigning standing, save, or recovery law.

---

## Elliot’s four priorities (how E1 hits them)

| Priority | Contracts |
|----------|-----------|
| Presentation (art / world feel) | **E1.1** first |
| More playable content | **E1.2**, **E1.3** |
| Deeper core systems | **E1.4**, **E1.5** |
| Full-game roadmap | **E1.6** (docs; not greenfield Destination P0) |

---

## Phase caps (this phase only)

| Element | E1 cap | Alpha had |
|---------|-------:|----------:|
| Systems | ≤ 5 | 3 |
| Stations | ≤ 7 | 3 |
| Entities | ≤ 6 | 4 |
| People | ≤ 20 | 12 |
| Job *kinds* | ≤ 3 | 1 |
| Commodities | ≤ 10 | 6 |
| Recovery chains | **1** (still) | 1 |
| Player hulls | **1** | 1 |

---

## Contracts (order)

### E1.1 · Presentation floor 2

**Scope:** Per-system sky/lighting contrast; ship, station, gate, traffic, hostile silhouettes that read as *objects* (not only colored boxes); kill/dock feedback polish; UI theme consistency. Placeholders OK if **readable**. Prefer in-engine / free in-repo assets; **new paid packs or deps = ask first**.

**Accept:**

1. Alpha / Beta / Gamma (and any new system) distinguishable in a screenshot without HUD labels.  
2. Player ship + station exterior readable at combat range.  
3. Status moment + station loop unchanged in behavior.  
4. Lint + headless tests green.

### E1.2 · Content pack — density

**Scope:** Add **one** new system **or** second stations in existing systems (prefer second stations if it makes space feel less empty; new system if gate graph needs a branch). Wire gates/NAV. Flavor lines. 2–4 new People **used** on Contacts (not dead data). Each major dock has ≥2 job options when the board is stocked. Full-sized data shapes only.

**Accept:**

1. Cold play visits ≥4 distinct dock-or-system places.  
2. Jobs accept/turn-in without console.  
3. Status moment still local controller only.  
4. Content loads via data pipeline; save/load still works.

### E1.3 · Second job kind

**Scope:** One new contract kind beyond pure delivery. Default: thin **patrol/bounty** — kill or drive off one tagged hostile near a gate/point, turn in at offering station. Pay + standing only through existing mission + standing writer. No new standing rules.

**Accept:**

1. Accept → complete and accept → fail/abandon move standing/credits in expected directions (automated tests).  
2. Playable without console.  
3. Does not invent standing law.

### E1.4 · Trade contrast + money pressure

**Scope:** Commodities toward 8–10. Clearer per-station buy/sell spreads (static, not dynamic economy). Fuel/repair/fees stay real sinks. Optional light contraband flags on 1–2 goods **only if** standing/reputation doc already supports the hook — otherwise spreads only.

**Accept:**

1. Documented profitable route A→B and a reverse industrial/scrap-style route a player can run.  
2. Wallet/cargo only through existing services.  
3. Save/load preserves cargo + credits.

### E1.5 · System depth (pick one package)

**Not all three.** Choose at plan sign-off:

| Option | Scope | Accept (playable proof) |
|--------|--------|-------------------------|
| **A — Enforcement lite** | Worse treatment when hated: higher fees, service denial or friction beyond dock refusal already in | “Hated at controller station feels worse” without console |
| **B — Combat world** | 2 hostile profiles **or** security-aware spawns + clearer attribution feedback in UI | Two fight shapes or clear “why standing moved” feedback |
| **C — Session shell** | Real Settings (audio levels, mouse sens at minimum); pause polish; settings persist | Settings change play and survive save/reload or re-launch |

**Default recommendation:** **A** (standing fantasy teeth) + light **C** only if settings are cheap; else pure **A**. Pick **B** if combat still feels like one encounter after content lands.

### E1.6 · Roadmap freeze (docs)

**Scope:** Write the post-E1 queue: map what Alpha did thin → E1 → next Destination-shaped phases (roughly combat interlock + economy pressure → opening → content scale; Operations/Holding later). No P7/P8 build.

**Accept:** Single plan doc Elliot can approve; `docs/state.md` points at it.

---

## Human gate (end of E1)

**[GATE: ELLIOT] E1 feel** — short cold play after E1.1–E1.5:

> Does this feel like a **small game** worth another phase of expansion?

Not a re-open of Final Alpha. Refuse → iterate E1 list only. Sign → open next planned phase.

---

## Explicitly deferred (not E1)

- Operations (hired captains, charters, warehouses)  
- Holding / endgame  
- Two-hull interlock (Hauler + Fighter)  
- Debt ladder / ship financing / career upkeep pressure  
- Character creation + annexation opening  
- True Entity hierarchy / multi-hop cascades  
- Multiple recovery chains  
- Dynamic economy, story campaign, edge mystery  
- Full production art/audio pipeline  
- Full v1 system count (8+)  

---

## After E1 — honest gaps (serious Beta still lacks)

Even with E1 green:

- Interlock law in combat  
- Economy that *forces* hard choices  
- Opening / life path  
- Enforcement with teeth (patrols, bounties, Traitor career)  
- ≥2 recovery footholds  
- Four real contract families (haul / escort / bounty / smuggle)  
- Operation + Holding pillars  
- Named universe + production audio/art  
- Map / trade lanes / multi-station logistics at full depth  

E1 is **demo → small game**. Not Beta as a product.

---

## Stop conditions (agents)

- Inventing standing rules not in `docs/reputation_and_standing.md`  
- Greenfield Destination Phase 0 rebuild  
- New paid deps/assets without asking  
- New **required** save fields without asking  
- Blowing E1 caps “for fun”  
- Building Operations / Holding / interlock in this phase  
- Cutting content silently to pass a criterion  

---

## Sign-off

| Field | Value |
|-------|--------|
| **Plan** | E1 — Legible Sector |
| **E1.5 package** | **A — Enforcement lite** |
| **Content bias E1.2** | **Second stations in existing systems** |
| **Elliot** | **signed** |
| **Date** | 2026-07-31 |

Mass build authorized in contract order E1.1 → E1.6.