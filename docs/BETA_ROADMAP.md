# Draywar — Post-Alpha roadmap (frozen after E1)

**Status:** **Approved** — E1 feel signed 2026-07-31; E2+ active  
**Date:** 2026-07-31  
**Authority:** Destination filters (Fidelity / Tone) + standing law + this queue.

This is **not** greenfield Destination Phase 0. Alpha already shipped foundation, thin flight/combat/world/standing/economy shell, and save.

---

## What Alpha already did (thin)

| Destination-shaped phase | Alpha / Path C result |
|--------------------------|------------------------|
| P0 Foundation | Done (EventBus, data pipeline, save, GUT, console) |
| P1 Flight | Done thin (A1 signed; fine-tune deferred) |
| P2 Combat | Done thin shell (fairness pass; no interlock) |
| P3 World | Done thin (3 systems, 6 stations after E1) |
| P4 Standing | Done thin Alpha-scale (1 recovery, dock refuse, E1 fees/services) |
| P5 Economy | Started thin (jobs, trade, sinks; no debt ladder) |
| P6 Opening | Not started |
| P7 Operations | Not started |
| P8 Holding | Not started |
| P9 Full content ship | Not started |

---

## E1 — Legible Sector (this phase)

| Contract | Status |
|----------|--------|
| E1.1 Presentation floor 2 | **code complete** |
| E1.2 Content density (2nd stations) | **code complete** |
| E1.3 Bounty job kind | **code complete** |
| E1.4 Trade contrast | **code complete** |
| E1.5 Enforcement lite | **code complete** |
| E1.6 Roadmap freeze | **this doc** |
| **[GATE] E1 feel** | **signed** 2026-07-31 |

**E1 job:** demo → small game (presentation, places, second job kind, trade routes, standing teeth).

**E2 plan:** `docs/BETA_E2_COMBAT_HULL.md` (thin two-hull interlock required by Destination §6).

---

## Recommended next phases (order)

### E2 — Combat & hull law — **CLOSED** (gate signed 2026-07-31)
**Job:** Prove Destination combat identity without full mid-game.

- Hostile profiles + security-aware encounters
- **Two-hull interlock thin proof** (Hauler + Fighter; Dest §6 locked)
- Attribution feedback polish
- Performance budget with denser traffic

**Not:** Operations, Holding.

### E3 — Economy pressure — **CLOSED** (gate signed 2026-07-31)
**Job:** Money stops being optional.

- Upkeep / fuel as career pressure (time or jump-based) — **done**
- Debt or financing seed (thin) — **done**
- Contraband / jurisdiction goods if standing law hooks land — **done**
- Job variety: smuggle as third kind — **done**
- Integration / balance pass — **done**
- **[GATE] E3.6 economy feel** — **signed** 2026-07-31

### E4 — Opening & cast — **CLOSED** (gate signed 2026-07-31)
**Job:** Career starts as a story, not mid-dock.

- Life-path 3×3 + create UI + annexation + Jax recovery — **done**
- Plan: `docs/BETA_E4_OPENING_CAST.md`
- **[GATE] E4.7 Opening feel** — **signed** 2026-07-31; next build **E5**

### E5 — Content scale toward Beta — **CLOSED** (E5.7 signed 2026-08-02)
**Job:** Sector large enough for multi-hour vetting.

- Plan: `docs/BETA_E5_CONTENT_SCALE.md`
- Ship **6 systems** (budget 8); stations **~10**; branched gate graph
- Multi-station logistics (long hauls + secondary docks + trade contrast)
- Map / NAV sector chart (functional)
- **[GATE] E5.7** — **signed** 2026-08-02

### E6 — Lived-in space — **CLOSED** (gate signed 2026-08-02)
**Job:** Systems feel like places — solids, distance, sky, attackable ships, density by law.

- Plan: `docs/BETA_E6_LIVED_IN_SPACE.md`
- Soft bump + impact damage by mass class; ship budget **20**
- **Elliot:** technically closed; still feels super thin (tech-demo maturity)

### Product bar raise (2026-08-02) — plan next, do not freestyle build
**Authority:** `docs/PRODUCT_DIRECTION.md` (overrides “story / dynamic economy deferred” for Steam 1.0 intent)

Elliot’s bar: not real Alpha yet (core systems incomplete). Real Alpha = all core loops built and under bug smash. Real Beta = content in, major bugs found, polish / endgame / launch prep.

Locked product calls:
- **Campaign** through debts paid + buy Holding (asteroid/station) → then **true sandbox**
- **Real economy simulator** (prices, scarcity/abundance, goods that move) — first-class pillar
- **Hours:** ≥30h main-path campaign; ~80h completionist
- Ambition frame: **space Skyrim** (dense freedom + main spine + radiant volume) on Freelancer/Tone filters

### Later (queued; order set by product plan, not this freeze alone)
- Living activity density / world tick
- **Economy sim** (production, consumption, regional prices)
- **Operations** (hired ships, charters, warehouses)
- **Story campaign spine** (through Holding ignition)
- **Holding** + sandbox continue
- Production art/audio pipeline
- Full Traitor career / patrol fleets / customs minigames
- Mining / belt economy

---

## Explicitly deferred until named phase

| Item | Opens in |
|------|----------|
| Two-hull interlock proof | E2 |
| Debt ladder / Operation economy | E3 / Ops |
| Character creation + annexation opening | E4 |
| Multiple recovery chains | E4+ |
| Lived-in space (collision, sky, attackable traffic) | **E6** |
| Operations layer | post E6 |
| Holding endgame | after Ops |
| Asteroid mining / belt economy | post E6 |
| Dynamic economy / story campaign / edge mystery | Destination DEFERRED until unlocked |
| Greenfield rebuild of P0–P2 | **never** |

---

## Stop conditions (all phases)

- Invent standing rules not in reputation doc  
- New required save fields without asking  
- Paid deps/assets without asking  
- Skip human gates  
- Build Ops/Holding early “because fun”  
- Silently cut content to pass a criterion  

---

## Sign-off

| Field | Value |
|-------|--------|
| E1 code | complete |
| E1 feel gate | signed 2026-07-31 |
| This roadmap | **approved** |
| Elliot | "I've already signed off… Take the build through as many phases as you can…" |
| Date | 2026-07-31 |
