# DRAYWAR ALPHA — Phase Plan

**Version:** 1.0  
**Date:** 2026-07-29  
**Goal:** Reach a playable vertical slice that proves the jurisdictional identity + personal recovery fantasy as quickly as possible, while leaving clean expansion paths.

---

## Guiding Rule

Each phase must leave the project in a state where the next phase can be added without rewriting the previous one.

---

## Phase A0 — Foundation (Short)

- Project skeleton, strict typing, EventBus, data pipeline, save schema, debug console, basic time control.
- Acceptance: empty systems can load, console can set values, save/load round-trips a trivial state.

---

## Phase A1 — Flight & One System

- Basic mouse-aim flight with one ship profile.
- One gray-box system with a station and a gate.
- Docking + minimal station menu (undock, launch).
- Simple chase camera and readable HUD.
- Acceptance: fly → dock → undock loop feels controllable. No combat required yet.

**Gate:** Elliot confirms basic flight is not nauseating and is controllable.

---

## Phase A2 — Standing Core (The Load-Bearing Phase)

Implement the heart of `docs/reputation_and_standing.md` at alpha scale.

- Entity + Person data loading (4–6 Entities, 12–18 People).
- Standing service (single writer, EventBus signals).
- Continuous scale + tier display.
- Status moment on system entry and station entry (local controller only).
- Docking refusal below threshold.
- Debug commands to set any standing.

Acceptance:
- Status moment appears correctly on entry.
- Docking is refused or allowed according to standing.
- Console can drive standing to any tier and the world reacts.

**This phase is the highest priority.** Do not expand content until it works.

---

## Phase A3 — Attribution & Everyday Change

- Combat attribution rules (security level of system, basic witnesses, evidence trail via selling cargo).
- Mission outcome standing effects (complete / fail / abandon).
- At least one simple mission type that can move standing.
- Light trade standing effects (optional but useful).

Acceptance:
- Killing in high-security space affects standing; clean deep-space kills do not (unless evidence is created).
- Mission outcomes produce the expected standing direction and rough magnitude.

---

## Phase A4 — Personal Recovery Path

- One Person who can offer the deniable first job when personal standing and history conditions are met.
- Short follow-on chain (3–5 steps) from the same Person.
- Rank influence on how much Entity standing can move.
- Basic betrayal action that can close that Person.

Acceptance:
- Player can start from deep negative Entity standing, build personal trust, receive the deniable job, and make visible (if small) progress up the Entity scale.
- Betraying the Person closes that recovery route.

**Gate:** Elliot plays the recovery path and confirms it feels like a meaningful, earned lever rather than a menu grind.

---

## Phase A5 — Minimal Playable Slice

- 3–4 systems with distinct controllers and security levels.
- Basic NPC traffic that reflects local standing/security.
- Simple money loop (mission pay, fuel, docking fees, repairs).
- Enough content to play a 30–60 minute session that demonstrates:
  - Different treatment in different places
  - Sticky negative standing
  - One personal recovery foothold

Acceptance:
- A coherent short session is possible without using the debug console.
- The status moment and recovery lever are both visible in normal play.

**Final Alpha Gate:** Elliot signs off that the core fantasy is legible and worth expanding.

---

## After Alpha

Once the Final Alpha Gate is passed, expansion follows the original larger plan (more systems, full combat interlock, Operation layer, economy depth, Holding, etc.) using the same services and data shapes.

The Alpha is deliberately small.  
The architecture is deliberately not.
