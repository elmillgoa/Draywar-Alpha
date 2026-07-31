# Draywar — State

**Where the build is right now.** Keep short. Detail lives in `docs/journal/`.

**Current position:** **Beta E1 — Legible Sector** code complete (E1.1–E1.6). Play fixes after gate start landed (job accept crash, free-fire reticle, bounty prey). **[GATE: ELLIOT] E1 feel** still open — Elliot said combat/aim section is good (“Much better. We are good on this section”) but has not formal-signed the full E1 feel gate yet.

| Doc | Role |
|-----|------|
| `docs/BETA_E1_LEGIBLE_SECTOR.md` | E1 plan (signed) |
| `docs/BETA_ROADMAP.md` | Post-E1 queue (draft until after gate) |
| `docs/gates.md` | Final Alpha signed; E1 feel gate |
| `docs/reputation_and_standing.md` | Standing law |

## E1 progress

| Contract | Status |
|----------|--------|
| E1.1 Presentation floor 2 | **done** |
| E1.2 Content density (2nd stations) | **done** |
| E1.3 Bounty job kind | **done** |
| E1.4 Trade contrast | **done** |
| E1.5 Enforcement lite (A) | **done** |
| E1.6 Roadmap freeze | **done** (doc draft) |
| Play fixes (accept crash, free-fire, bounty ensure) | **done** (Elliot: good on this section) |
| **[GATE] E1 feel** | **open** — formal sign still needed |

## What the game can do now (E1)

- 3 systems, **6 docks**, distinct sky/silhouettes
- Courier + **bounty** jobs; multi-job boards; contacts
- **10 commodities** with clear trade routes
- Standing teeth: fee surcharge, service markup/denial when hated
- Combat: free-fire follows reticle; lock uses lead; bounty ensures local pirates
- Recovery (Mendi), save/load

## Evidence

- Suite **314/314**. Lint green.
- `main` @ `7daccd9` (reticle + bounty ensure) pushed to `origin/main`.

## Next session starts here

1. `/start` — confirm E1 code + play fixes; gate still open.
2. Elliot finishes **E1 feel** cold play (script in `docs/gates.md`) if not done, then **formal sign or refuse**.
3. Sign → record verdict; approve `docs/BETA_ROADMAP.md`; open **E2**.
4. Refuse → iterate only from his list. Do not start E2 until signed.

## Standing decisions

- Final Alpha signed. Destination filters govern. No greenfield P0.
- Flying fine-tune deferred.
- Never free() UI mid-pressed; free-fire aim on camera ray; bounty ensures prey in lock range.

## Session history

- **2026-07-31 (this wrap)** — E1 built; play fixes (job accept, free-fire/reticle, bounty spawn); Elliot good on combat section; E1 feel formal gate still open.
- **2026-07-31** — Final Alpha signed; Path C closed; E1 plan signed and built.
