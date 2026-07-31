# DRAYWAR — Phase Plan (Guidelines)

**Version:** 2.0 (updated 2026-07-29 for expanded reputation system)  
**Execution model:** Agent executes contracts in order within a phase. Phases are sequential. A phase is complete only when every contract's acceptance criteria pass and any human gate is signed off.  
**Companion docs:** `DRAYWAR_DESTINATION.md`, `DRAYWAR_CONVENTIONS.md`, `DRAYWAR_AGENT_GUARDRAILS.md`, `docs/reputation_and_standing.md`

## Contract format

Every contract: **ID · Name — Scope / Acceptance criteria / Notes.**  
Acceptance criteria are testable. Do not begin a contract whose dependencies are incomplete. Do not implement content or systems from later phases early.

**Human gates** are marked **[GATE: ELLIOT]**.

---

## Phase 0 — Foundation

**Goal:** A repo an agent can work in for a year without entropy.

- **P0.1 · Project skeleton** — Godot 4.x, strict typing, directory layout, lint config.  
- **P0.2 · EventBus** — Autoload signal bus; typed signal catalog in `/docs/events.md`.  
- **P0.3 · Data-driven content pipeline** — All content in Resources/JSON; one `Balance.gd` for tunables.  
- **P0.4 · Save schema v1** — Versioned save/load; schema documented.  
- **P0.5 · Test harness & CI** — GUT (or equivalent); headless smoke test.  
- **P0.6 · Debug console & time control** — Console commands including set standing; time-scale service.

*No gate.*

---

## Phase 1 — Flight & Feel

**Goal:** The mouse feels like Freelancer.

- **P1.1 · Flight model**  
- **P1.2 · Camera & readability**  
- **P1.3 · HUD v1**  
- **P1.4 · Test range**  
- **P1.5 · [GATE: ELLIOT] Flight feel sign-off**

---

## Phase 2 — Combat Core

**Goal:** Dogfights are punchy and honest to the two-hull law.

- **P2.1 · Damage model**  
- **P2.2 · Weapons**  
- **P2.3 · NPC combat AI**  
- **P2.4 · Escort behavior**  
- **P2.5 · Combat encounter director**  
- **P2.6 · [GATE: ELLIOT] Combat feel sign-off**

---

## Phase 3 — World Shell

**Goal:** Space is places. Travel, dock, undock, repeat.

- **P3.1 · System scene architecture** — Includes jurisdiction / controlling Entity field.  
- **P3.2 · Jump gates & trade lanes**  
- **P3.3 · Docking & station menus**  
- **P3.4 · NPC traffic**  
- **P3.5 · Map & navigation**

*No gate.*

---

## Phase 4 — Jurisdiction & Standing

**Goal:** The core thesis becomes code. Identity is jurisdictional.  
**Source of truth:** `docs/reputation_and_standing.md`

This phase implements the two-layer model (Entities + People), continuous standing scale, status resolution, personal recovery path, betrayal rules, combat attribution, and the protected status moment.

- **P4.1 · Entity & Person data + standing service**  
  Load 8–12 Entities and 20–35 People from data.  
  Maintain per-player standing for both layers (-100 to +100).  
  Support relationship links between Entities.  
  All standing mutations go through this service and emit on EventBus.  
  *Accept:* unit tests for standing read/write; debug console can set any standing; data loads cleanly.

- **P4.2 · Status resolution service**  
  Answers “what is the player here?” for a system or station using controlling Entity + standing.  
  *Accept:* table-driven tests covering at least the three worked examples in the reputation design doc.

- **P4.3 · System-entry and station-entry status moment**  
  Protected UI beat. Displays standing with the local controlling Entity only.  
  *Accept:* appears on every entry; matches P4.2; dismissible; logged.

- **P4.4 · Everyday standing changes**  
  Implement combat attribution rules (security level, witnesses, evidence trail), mission outcome effects (complete / fail / abandon), and basic trade/smuggling hooks.  
  *Accept:* scripted tests demonstrate attributed vs unattributed kills and the three mission outcomes.

- **P4.5 · Personal recovery path (alpha)**  
  Friendly personal standing + history unlocks a small deniable job from a Person.  
  Short follow-on chain from the same Person.  
  Rank influences how much Entity standing can move later.  
  *Accept:* one full recovery chain can be driven via console/debug from Hated/Hostile into improved standing.

- **P4.6 · Betrayal and limited network effects**  
  Tagged betrayal actions can near-permanently close a Person.  
  Limited same-system network damage from data-defined lists.  
  *Accept:* tests show a closed Person no longer offers recovery help; network list receives standing hits.

- **P4.7 · Basic enforcement consequence**  
  Stations refuse docking below a configurable standing threshold with their controlling Entity.  
  (Further enforcement — patrols, bounties, customs scaling — may be staged after the core standing loop is proven.)  
  *Accept:* docking refused when standing is below threshold; allowed when above.

- **P4.8 · [GATE: ELLIOT] Standing feel sign-off**  
  Elliot plays scenarios covering: clean operator, regional problem with personal recovery foothold, station-vs-system mismatch, and a betrayal.  
  *Accept:* written sign-off that the jurisdictional identity and personal recovery lever feel correct.

**Notes for Phase 4:**  
Charters, full Traitor career arc, bounty scaling, and rich enforcement behaviors from the original plan are still desired but are now sequenced after the core standing + personal layer is solid. They may be re-introduced as later contracts once P4.8 is signed.

---

## Phase 5 — Economy

**Goal:** Money in, bills out, clock running.

(Contracts largely unchanged from previous plan: commodities, contraband jurisdictional, contract board, sinks, upkeep, debt ladder, ship financing. Standing effects on prices, fines, and contract availability hook into the new standing service.)

- **P5.7 · [GATE: ELLIOT] Economy pressure sign-off**

---

## Phase 6 — Character Creation & Opening

**Goal:** Who you were, then the ground moves.

Character creation pre-loads Entity and (where relevant) Person standings.  
The annexation opening re-fires the status moment with the player’s new effective statuses.

- **P6.4 · [GATE: ELLIOT] Opening sign-off**

---

## Phase 7 — The Operation Layer

Hired captains, standing charters & retainers, warehousing, operation dashboard.

---

## Phase 8 — The Holding

Claim → Power → Supply → Protect → People.  
Ignition and epitaph read the whole-game standing ledger (Entities + key People).

- **P8.5 · [GATE: ELLIOT] Endgame sign-off**

---

## Phase 9 — Content, Balance, Ship It

Fill the 8 systems, replace placeholders with approved names/identities, balance, release infrastructure.

- **P9.7 · [GATE: ELLIOT] Release candidate sign-off**

---

## Post-1.0 backlog (recorded)

Story campaign · dynamic economy · hybrid hulls · playable holding as ongoing faction · true Entity hierarchy · rich personal-help variety · edge-mystery development · ironman & difficulty modes · damage-type matrix.
