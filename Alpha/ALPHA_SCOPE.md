# DRAYWAR ALPHA — Scope

**Version:** 1.0  
**Date:** 2026-07-29  
**Status:** Hard ceiling for the prove-it phase

---

## Population (Hard Caps)

| Element                    | Alpha Count      | Notes                                      |
|---------------------------|------------------|--------------------------------------------|
| Star systems              | 3–4              | One controlled, one contested, one low-security/lawless |
| Entities                  | 4–6              | Enough for jurisdictional contrast         |
| Fully tracked People      | 12–18            | Enough for recovery + betrayal tests       |
| Stations / dockables      | 3–5              |                                           |
| Player ships              | 1 primary (+ optional light second) | Feel over interlock proof          |
| Recovery chains           | 1 total          | One complete personal recovery path        |
| Contract types            | 2–3              | Enough to move standing and money          |
| Commodities               | 6–8              | Sufficient for basic trade contrast        |

These are ceilings, not targets to hit for their own sake.

---

## In Scope (Must Exist)

### Reputation Core
- Entities + People two-layer model
- Continuous standing (-100 to +100) with display tiers
- Sticky asymmetric extremes
- Status moment on system and station entry (local controller only)
- One personal recovery path (deniable job → short chain)
- Basic betrayal → near-permanent personal closure
- Combat attribution by location/security + light witness/evidence rules
- Docking refusal below a standing threshold

### Minimal World
- 3–4 systems with distinct jurisdictional character
- Jump travel between them
- Docking and basic station menus
- Simple NPC traffic that reflects local security

### Minimal Play Loop
- Fly, dock, take a job, fight or deliver, see standing change
- Experience being treated differently in different places
- Have one realistic path to start repairing deep negative standing through a person

### Support Systems
- Debug console (set standing, teleport, spawn, grant credits)
- Save / load
- Basic money in and money out (docking fees, fuel, simple repairs, mission pay)

---

## Explicitly Out of Scope for Alpha

- Full two-hull interlock proof and heavy combat balancing
- Hired captains / Operation layer
- Warehouses and arbitrage
- Full debt ladder (garnishment, repossession, etc.)
- Holding / endgame milestones
- Character creation with many combinations
- Rich variety of secret help methods
- True Entity parent/child hierarchy
- Multi-hop reputation cascades
- Large authored dialogue sets
- Dynamic economy
- Multiple recovery chains
- Bounty hunting networks, customs minigames, etc.

These are deferred, not discarded. The architecture should not make them expensive to add later.

---

## Architectural Rules for Expandability

1. **Data shapes are full-sized.**  
   Even if only 5 Entities exist, the Entity and Person resources contain the fields the full game will need (relationship links, rank, network lists, reach, etc.).

2. **Standing service is the single writer.**  
   All standing changes go through one service and the EventBus. Future systems only emit events; they never write standing directly.

3. **Status resolution is already general.**  
   The “what am I here?” service takes a location and returns the relevant standing view. Adding more Entities or People later does not require changing the call sites.

4. **Content is data.**  
   Missions, recovery steps, and People are data-driven so new ones can be added without code changes.

5. **No temporary hacks that paint us into a corner.**  
   Prefer a slightly more general system with small content over a special-case system that will be thrown away.
