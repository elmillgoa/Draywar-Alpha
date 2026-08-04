# S8 endgame / Holding playtest brief

**Gate [Elliot]:** endgame feel + structural rhyme (“powers respond on ground you own”).

## What “campaign complete” means

Debt clear **and** Holding **ignition** (authored crisis mission that standing
resolves) — not the purchase button alone. After that, the same save keeps
markets, boards, Ops, and freeroam.

## Exact path to climax (console-free)

1. Finish Acts I–II (see `docs/S7_COLD_START_PLAYTEST.md`) so Act III is open
   (`flag_act2_done`, career act III).
2. **Story** milestones (order locked by flags):
   - **Claim survey** — Alpha Port → Epsilon Belt (`flag_holding_claim`)
   - **Power brief** — Beta Hub → Spit (`flag_holding_power`)
   - **Supply run** — Delta Port → Epsilon (`flag_holding_supply`)
   - **Protect approaches** — bounty in Epsilon, turn-in Spit (`flag_holding_protect`)
   - **People kit** — Gamma Outpost → Zeta Spur (`flag_holding_people`)
3. Each milestone cuts Holding price by 400 cr (base 3500 → floor 1500 at 5/5).
4. **Clear all debt** (Services repay if you borrowed).
5. Dock a **candidate**: **Epsilon Belt** or **Zeta Spur** (must be docked there).
6. **Holding** section: **Purchase Holding** when milestones + debt clear + credits.
7. Status on that dock should read **Captain's Holding** (your entity), not the old power.
8. **Story** at the **claimed** dock only — ignition path depends on **standing**:
   - **Papers** (prior controller Neutral or better): leave the pad, deliver claim
     papers to **Alpha Port**, complete the job.
   - **Force** (prior Unfriendly/Hostile): need **Friendly Free Haulers or Reach**
     as backing; bounty kill in the Holding system, turn-in at your pad.
   - If neither condition holds, Story stays locked (“Standoff unresolved…”).
9. Celebration / epitaph line appears (peaceful vs contested text). Campaign complete.
   Keep playing — boards and trade still work.

## Standing setups to try

| Setup | How | What rhyme should feel like |
|-------|-----|------------------------------|
| Peaceful papers | Keep prior controller (Syndicate on Epsilon / Collective on Zeta) Neutral+ before ignition | Papers path opens; must fly to Alpha Port; epitaph uncontested |
| Contested bay | Drop prior to Hostile; raise Free Haulers or Reach to Friendly | Force bounty path; kill in system; epitaph contested |
| No leverage | Hostile prior + nobody Friendly | Both ignition paths locked until standing changes |
| Wrong dock | Claim Epsilon, fly to Zeta | No ignition Story at Zeta; only at your claim |
| Debt trap | Borrow after purchase | Ignition locked until debt is zero; purchase also blocked while owed |

## What failure looks like (gate fail)

- Purchase alone feels like the ending (no crisis mission / no epitaph).
- Ignition is accept-and-done at the same dock with no travel or fight and no standing fork.
- After “complete,” boards/markets/Ops dead or soft-lock.
- Status moment still shows the old controller on your purchased dock.
- Tone: chosen-one space opera instead of freighter + jurisdiction.
- You would refund because the end is a button, not a stand-off you earned.

## Out of scope this gate

- Empire sim, new systems/stations, ship budget raise
- Inventing standing law or tiers
- Art polish beyond gray-box readability

## Sign-off

When signed: endgame + structural rhyme OK. Record in `docs/gates.md` and
`docs/state.md`.
