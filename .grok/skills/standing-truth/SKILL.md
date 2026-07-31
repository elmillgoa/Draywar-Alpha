---
name: standing-truth
description: Standing system rules for Draywar. Use when implementing or testing Entities, People, status moment, recovery, betrayal, attribution, or docking refusal. Forbids inventing standing rules. /standing-truth
---

# Standing law

**Source of truth:** `docs/reputation_and_standing.md`  
**Alpha population:** `Alpha/ALPHA_SCOPE.md` (4–6 Entities, 12–18 People) — not the full-doc 8–12 / 20–35.

## Locked

- No global alignment. Per-Entity standing; enforce only where Entity has reach.
- Two layers: Entities + People.
- Continuous −100..+100; display tiers as in the doc; sticky asymmetric negatives.
- Status moment: system entry and station entry show **local controller only**.
- Personal recovery is the realistic climb out of deep negative Entity standing.
- Single writer service + EventBus for all standing mutations.
- Alpha: flat Entities + relationship links; People primary Entity only.

## Do not invent

If a magnitude, threshold, ripple %, docking refusal value, or recovery step is not in the doc or Balance data, put it in **data** with a named constant — or `/escalate` if the rule itself is missing.

## Protected

The status moment may never be removed, hidden by default, or made unreliable (`AGENTS.md`, guardrails).
