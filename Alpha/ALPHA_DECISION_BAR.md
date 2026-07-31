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
| 1 | **Flight** | Controllable mouse-aim freighter; not a nauseating tech demo | Partial (feel signed A1) |
| 2 | **World / travel** | **3–4 systems** you can **reach and tell apart** (not one start + mystery boxes); jump/dock clear | **Fail** — lives as one start system |
| 3 | **Station menus** | Dock → readable station UI (services, jobs, undock) | Partial (gray panel buttons) |
| 4 | **Main menu / pause** | Start / continue / quit / settings bare minimum | **Missing** |
| 5 | **Character / captain sheet** | See who you are: money, ship, standing summary, open jobs | **Missing** |
| 6 | **Job tracking** | Accept, objective, destination, complete/fail/abandon without guessing | Partial (HUD job line; thin) |
| 7 | **Standing + status moment** | Different treatment by place; status on entry; sticky + recovery foothold | Partial (logic stronger than presentation) |
| 8 | **Personal recovery** | One chain, visible in normal play, works when deep negative | Partial |
| 9 | **Trade** | Buy/sell or station trade that moves cargo/money (thin OK) | **Missing** |
| 10 | **Combat** | Shoot / be shot / win or lose a fight that matters (thin OK, not full interlock) | **Missing** (attribution stub only) |
| 11 | **Money loop** | Pay in and out (jobs, fuel, fees, repairs, trade) | Partial |
| 12 | **NPC traffic** | Space feels occupied; security reads differently | Partial (boxes by density) |
| 13 | **Save / load** | Career continues without console-only ritual | Partial (console save) |
| 14 | **Presentation floor** | More than black void + colored primitives — placeholders OK if readable (silhouettes, skybox, basic UI theme) | **Fail** |
| 15 | **Minimal content pack** | Enough systems/stations/jobs/entities for a 30–60 min vetting session | **Fail** as *felt* content |

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
