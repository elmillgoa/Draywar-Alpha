# DRAYWAR — Destination Document

**Version:** 2.0 (updated 2026-07-29 for expanded reputation system)  
**Owner:** Elliot (final authority on all gated decisions)  
**Audience:** The executing agent and future contributors  
**Companion docs:** `DRAYWAR_PHASE_PLAN.md`, `DRAYWAR_AGENT_GUARDRAILS.md`, `docs/reputation_and_standing.md`

---

## 0. How to use this document

This is the north star. When any implementation or scope question is ambiguous, resolve it with the two filters in Section 1. If the filters conflict or don't resolve the question, STOP and ask Elliot. Do not invent lore, systems, or content beyond what this document and its companions authorize.

Items marked **DEFERRED** are intentionally undeveloped — do not build them.

Everything marked **LOCKED** was decided deliberately. Do not reopen locked decisions. Propose changes only via a flagged question to Elliot.

The reputation system is defined in full in `docs/reputation_and_standing.md`. That document is the source of truth for standing, Entities, People, recovery, betrayal, and status resolution. This Destination document states only the high-level thesis and how reputation serves the larger game.

---

## 1. Destination statement and decision filters

**Draywar is the Freelancer sequel that never happened, set in a mercenary world with Honorverse-style institutional factions.**

A single-player 3D PC space game (Godot 4.x, Steam) where the player is an unaligned captain — freighter pilot, mercenary, smuggler, privateer, traitor, depending entirely on where they are and what they've done — earning toward the ultimate purchase: sovereign territory of their own.

**Filter 1 — Fidelity:** *Would Freelancer 2 have done it?*  
Mouse-aim flight that plays like an action game. Trade lanes. Faction standing. Menu-driven stations. A hand-built universe with placed secrets. If a proposed feature contradicts this (planetary landings, ship interiors, walking, six-axis Newtonian flight, VR, multiplayer), the answer is no.

**Filter 2 — Tone:** *Does it fit a working professional in a broken empire?*  
War is an industry. Technology is inherited, not invented. Ships are old, maintained, logged, named. Money is bills and margins, not loot showers. The player is a licensed independent with overhead, not a chosen one. If a proposed feature is power fantasy without cost, the answer is no.

Every contested scope call resolves through both filters. Both must pass.

---

## 2. Fiction spine (minimal, LOCKED)

- The setting is the aftermath of the **Charterfall** — the collapse of the old interstellar free-trade compact. The lanes used to be neutral. The war over who inherits them is called, with contempt, **the draywar**.
- Great powers (institutional nation-states in the Honorverse mold) fight a long declared war over lane infrastructure they can no longer rebuild, only capture.
- A neutral trade league profits and is resented. The periphery — single-system polities — is being swallowed.
- Dead systems from the Charterfall exist at the edge of the map. Something moves in them. **DEFERRED**.
- The player is nobody's citizen. Their identity is whatever the local jurisdiction says it is.

**Lore depth rule:** v1 Entities are numbered placeholders with behavior profiles, not names or histories. Do not write lore. Prove the machine first.

---

## 3. Core thesis: identity is jurisdictional (LOCKED)

There is no global player alignment.  
There is only per-entity standing, and standing is only *enforced* where an entity has reach.  
The same player with the same cargo is a chartered agent in one system, a smuggler in the next, an anonymous gun in a third.

**Mandatory UI expression:** On every system entry, the game states what the player *is here*. Every border crossing is a small narrative event. This is the game's signature moment and is protected.

Full rules for standing, the two-layer model (Entities + People), recovery paths, betrayal, combat attribution, and status resolution are defined in `docs/reputation_and_standing.md`.

**Key expansions beyond the original 1.0 model:**
- Standing uses a continuous -100 to +100 scale with named tiers.
- A distinct **People** layer exists alongside Entities. Personal relationships are the primary realistic lever for recovering from deep negative standing.
- Extremes are sticky and asymmetric.
- Combat standing changes depend on attribution (location, security, witnesses, evidence).
- Traitor remains a meaningful career state; it is expressed through the standing system and permanent flags rather than a completely separate track.

---

## 4. The player fantasy and progression spine (LOCKED)

The money is building toward **getting out**: buying sovereign territory. Three nested layers:

1. **The Ship (early game).** Upgrade hull systems, weapons, cargo within a deliberate ceiling.
2. **The Operation (mid game).** Hired ships with hired crews, standing charters, warehouse space.
3. **The Holding (end game).** The player buys an asteroid/moonlet and ignites the start of a faction. The game ends at ignition, not at empire.

**Structural rhyme (LOCKED):** The game opens with the player's neutral ground being annexed by a great power. The game ends with the player daring the powers to try that on ground the player owns.

---

## 5. Character creation (LOCKED shape)

Battletech-style life paths: few picks, mechanical teeth. Each pick pre-loads Entity standings, gear, and baggage.

**Three axes, three options each for v1 (9 options total):**

- **Origin:** Core World · Periphery-born · Stateless Charterfall refugee
- **Former trade:** Ex-Navy · Merchant marine · Smuggler
- **The mark you carry:** Cancelled charter · Debt · Clean

Numbers are tunable constants.

---

## 6. Combat, trade, and the interlock (LOCKED)

**Interlock principle:** No ship is a generalist. Cargo capacity and combat capability trade off. The fleet — not the ship — is how a player has both.

**v1 hulls: exactly two.**
- **Hauler.** Cargo, endurance, escape. Cannot win a dogfight.
- **Fighter.** Fast, gun-heavy, negligible hold. Cannot earn by trade.

**Combat feel:** Mouse-aim, chase camera, throttle + strafe + afterburner, close-range dogfighting.

**Trade:** 12 commodities, static base prices with per-station modifiers. Contraband is jurisdictional — legality is defined per Entity. Four contract types in v1: Haul, Escort, Bounty/Patrol, Smuggle.

---

## 7. Money loop and time (LOCKED)

Transactional sinks and time-based upkeep. Debt never ends the game — it transforms it through a grace ladder into a playable outlaw floor. There is no debt game-over.

---

## 8. Endgame: the Holding (LOCKED shape)

Five-milestone ladder (Claim → Power → Supply → Protect → People).  
Ignition produces a career epitaph. Playable holding-as-faction beyond ignition is DEFERRED.

---

## 9. Deferred list (do not build)

- Edge mystery beyond one hazardous empty system
- Story campaign
- Dynamic economy over time
- Damage/armor type matrix
- Hybrid and additional hulls
- Ironman / difficulty modes
- Playable holding beyond ignition
- Full Entity lore and names (placeholders until content phase)
- Multiplayer, VR, planetary landings, ship interiors, walking
- Rich long-term personal-help variety and true Entity hierarchy (see reputation doc)

---

## 10. Platform and v1 content budget

**Platform:** Godot 4.x, GDScript 2.0 strict typing, EventBus, composition over inheritance.

**v1 content budget (ceilings):**

| Content              | v1 count                          |
|----------------------|-----------------------------------|
| Star systems         | 8                                 |
| Entities             | 8–12                              |
| Fully tracked People | 20–35                             |
| Player hulls         | 2 (Hauler, Fighter)               |
| Weapons/equipment    | ~12 weapons + ~10 equipment       |
| Commodities          | 12                                |
| Contract types       | 4                                 |
| Stations/dockables   | ~10                               |
| Character options    | 9 (3×3×3)                         |
| Endgame holdings     | 2 candidate rocks                 |

**Tagline:** *The empire fell. The contracts didn't.*
