# DRAYWAR ALPHA — Expansion Path

**Version:** 1.0  
**Date:** 2026-07-29  
**Purpose:** Show how the small Alpha grows into the full game without redesign.

---

## Principle

Every Alpha system is built as a subset of the full system, not as a temporary special case.

When we add content or behavior later, we are mostly:
- adding rows to data,
- enabling already-written code paths,
- or tuning values.

We are not throwing away the Alpha standing service, status resolver, or Person model.

---

## Growth Map

### Entities & People
- Alpha: 4–6 Entities, 12–18 People
- Full: 8–12+ Entities, 40–80+ People (and eventually more)
- How: same resource format. Relationship links and rank fields already exist.

### Hierarchy
- Alpha: flat Entities + simple relationship links
- Full: true parent/child hierarchy
- How: add optional parent_id and cascade rules; existing link system continues to work.

### Recovery & Personal Help
- Alpha: one deniable job + short chain from one Person
- Full: many chains, high-rank acceleration, private channels, black-site meetings, covers, discovery risk, etc.
- How: recovery content is data. New help types are additional actions that the same Person/standing service can gate.

### Status Moment
- Alpha: local controller only
- Full: still local controller by default; deeper views remain in menus (or optional expanded HUD later)
- How: the resolution service already takes a location. No change to the protected moment required.

### Combat Attribution
- Alpha: security level + light witnesses + evidence trail
- Full: richer witness networks, delayed discovery, faction intelligence, etc.
- How: attribution is a function. New factors are additional inputs.

### Enforcement
- Alpha: docking refusal only
- Full: patrols, bounties, customs scaling, charter breach → Traitor consequences, etc.
- How: these become additional listeners to standing change and status events.

### Economy & Ships
- Alpha: simple money in/out, one (or lightly two) ships
- Full: two-hull interlock, Operation layer, debt ladder, warehouses, retainers
- How: standing service is already independent of the economy systems. They consume standing; they do not own it.

### Endgame
- Alpha: none
- Full: Holding milestone ladder and epitaph that reads the whole standing ledger
- How: Holding is registered as an Entity. The standing ledger already exists.

---

## What We Refuse to Do in Alpha

- Special-case code that only works for 5 Entities
- Hard-coded recovery logic that cannot accept new People
- Status UI that assumes a fixed list of factions
- Standing writes scattered across mission, combat, and trade code

If a shortcut would force a redesign later, we do not take it.

---

## Summary

The Alpha is small in content and surface area.  
It is not small in architectural ambition.

That is the point.
