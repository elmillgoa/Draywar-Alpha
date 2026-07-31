# Draywar Alpha — Decision bar (Hybrid path C)

**Status:** **Ratified** (Elliot 2026-07-31). Authority for what “Alpha done” means after Final Alpha refuse.  
**Build order:** `Alpha/ALPHA_DECISION_PHASE_PLAN.md` (Path C phases B0–B5).  
**Date:** 2026-07-31  
**Does not replace:** `docs/reputation_and_standing.md` (standing law) or Destination fidelity/tone filters.  
**Does replace:** “smallest gray-box tech slice” as the success definition for Final Alpha.

---

## Path

**C — Hybrid**

- Keep growable architecture and standing/recovery as the fantasy core.
- Pull the **system checklist** from core game intent (Destination + phase plan), not “shrunken full game.”
- Alpha is **not** the full game. It is **enough game** to decide whether building Beta / full product is worth it.

---

## Success (Elliot, plain)

Alpha is successful when Elliot can play a real session and decide:

> Is this worth building into a beta / full game?

### Required quality

| Required | Not required |
|----------|----------------|
| Core systems **present and working** | Full game content volume |
| Good enough to **judge** the design | 100% polish |
| Readable world (not only black + boxes) | Full art / full sound production |
| Minimal content for **real vetting** | Operations, Holding, debt ladder, etc. |

### Explicitly not required for this Alpha bar

- Full production graphics and soundtrack  
- Every Destination system at full depth  
- Operations layer, Holding endgame, full debt ladder, large authored dialogue  

---

## Core systems checklist (decision-quality)

Each row must be **playable without debug console** for the fantasy path (console may remain for debug).  
**Depth:** thin is OK; **missing** is not.

| # | System | Decision-quality bar | Now (honest) |
|---|--------|----------------------|--------------|
| 1 | **Flight** | Controllable mouse-aim freighter; not a nauseating tech demo | **Present / good enough** (A1 signed; mouse-aim freighter) |
| 2 | **World / travel** | **3–4 systems** you can **reach and tell apart** (not one start + mystery boxes); jump/dock clear | **Present / good enough** (B0: Alpha/Beta/Gamma, gates, NAV, dock) |
| 3 | **Station menus** | Dock → readable station UI (services, jobs, undock) | **Present / good enough** (B1 theme + B3 sections: jobs/services/trade/contacts) |
| 4 | **Main menu / pause** | Start / continue / quit / settings bare minimum | **Present / good enough** (B2: New Game / Continue / Quit; Esc pause) — settings still thin/absent |
| 5 | **Character / captain sheet** | See who you are: money, ship, standing summary, open jobs | **Present / good enough** (B2 captain sheet) |
| 6 | **Job tracking** | Accept, objective, destination, complete/fail/abandon without guessing | **Present / good enough** (HUD + sheet + station accept/turn-in/abandon; dest on button) |
| 7 | **Standing + status moment** | Different treatment by place; status on entry; sticky + recovery foothold | **Present / good enough** (status moment, fees/NPC by place; B5 drama header when deep negative) |
| 8 | **Personal recovery** | One chain, visible in normal play, works when deep negative | **Present / good enough** (Mendi chain; favor/talk/complete on station; deep-neg foothold copy) |
| 9 | **Trade** | Buy/sell or station trade that moves cargo/money (thin OK) | **Present / good enough** (B3 cargo + B5 per-system price contrast) |
| 10 | **Combat** | Shoot / be shot / win or lose a fight that matters (thin OK, not full interlock) | **Present / good enough** (B4 Space fire, hostile, hull, attribution, cripple/repair) |
| 11 | **Money loop** | Pay in and out (jobs, fuel, fees, repairs, trade) | **Present / good enough** (pay in/out wired; thin balance) |
| 12 | **NPC traffic** | Space feels occupied; security reads differently | **Present / good enough** (density by policing; still placeholder silhouettes) |
| 13 | **Save / load** | Career continues without console-only ritual | **Present / good enough** (B2 menu/pause save·load + continue) |
| 14 | **Presentation floor** | More than black void + colored primitives — placeholders OK if readable (silhouettes, skybox, basic UI theme) | **Present / good enough** (B1 skybox/silhouettes/theme — not final art) |
| 15 | **Minimal content pack** | Enough systems/stations/jobs/entities for a 30–60 min vetting session | **Present / good enough** (B5: 3 systems, 3 jobs, 6 goods, flavor, recovery path, play script) |

**Residual partials (honest, not blockers for “judge”):** settings menu; final art/audio; NPC still simple; combat/trade depth thin by design; recovery only at Reach/Mendi; no dynamic economy.

---

## Still protected (from Alpha vision + standing law)

1. No global alignment — standing per-Entity, enforcement where they have reach.  
2. Status moment on system and station entry.  
3. Personal recovery as the realistic climb from deep negative.  
4. Full-sized data shapes / EventBus / single standing writer.

---

## Final Alpha Gate (revised)

Elliot signs only when:

1. Every checklist row is **present and good enough to judge**, and  
2. He can answer: *worth building the full/beta game or not?*

Not signed if it still feels like a technology demonstrator.

---

## Out of scope until after Final Alpha

Deferred full-plan items remain deferred: Operations, Holding, full interlock proof, large dialogue, dynamic economy, multi-recovery, etc.  
If a checklist row would force inventing standing rules, stop and ask.

---

## How agents use this

1. **Authority for “is Alpha done?”** — this file + standing law + Destination fidelity/tone on ambiguity.  
2. **Do not** mark Final Alpha ready until checklist rows pass in **play**, not only unit tests.  
3. **Build order** — prefer closing **Fail / Missing** rows that block a coherent session (world, menus, jobs, combat/trade) before polish.
