# Draywar Steam 1.0 — Product Plan

**Date:** 2026-08-02  
**Version:** 1.1 (Fable outside-review amendments absorbed 2026-08-02)  
**Status:** Accepted build queue (S0 done). S1 code only when Elliot says go.  
**Authority:** this plan + `docs/PRODUCT_DIRECTION.md` + Destination Fidelity/Tone + standing law  
**Review source:** `docs/OUTSIDE_REVIEW_2026-08-02.md` (read-only; findings folded in below)

---

## 1. One-sentence mission

Build a single-player freighter captain game that feels like **space Skyrim under Freelancer rules**: a dense hand-built sector, a real economy, a living job surface, a campaign that ends when you **clear your debts and buy a Holding**, then a **true sandbox** on the same save — good enough that a studio would take the systems seriously.

---

## 2. Locked product goals (from Elliot)

| Goal | Spec |
|------|------|
| Maturity language | Tech demo → **core complete (real Alpha)** → **content complete (real Beta)** → polish/launch |
| Campaign end | Debts paid **and** Holding purchased (asteroid/station rock) |
| After campaign | Same save continues as sandbox; world keeps running |
| Economy | Real simulator: production, consumption, scarcity, moving prices, player can dent locals |
| Hours | **≥30h** main path · **~80h** completionist · open sandbox after |
| Map philosophy | Hand-built dense sector + generated volume — **not** infinite procgen galaxy |
| Filters | Freelancer flight feel · jurisdictional identity · no landings/walk/MP |

---

## 3. What we have today (honest baseline)

| Layer | Status | Reality |
|-------|--------|---------|
| Flight / combat | Thin but real | Mouse aim, 2 hulls, hostiles, traffic targetable |
| Standing / People | Core machine | Status moment, dock refuse, attribution, **2** recovery chains |
| World shell | 6 systems / 10 stations | Solids, sky, density by law — still thin *activity* |
| Money | Thin teeth | Static prices, fees, upkeep, one loan, 10 goods |
| Jobs | 12 fixed templates | Courier / bounty / smuggle only — no escort, no radiant board |
| Economy sim | **Missing** | No stock, no production, no price drift |
| Ops / Holding / campaign spine | **Missing** | Design only |
| Save | Solid v1 envelope | Optional sections; no market/Ops/Holding/campaign flags |

**Label:** tech demo with strong foundation machines. Expand them; do not rebuild from zero.

### Key existing machines to keep

- `StandingService` — only standing writer  
- `WalletService` / `CargoService` / `MissionService`  
- `EventBus` + `docs/events.md` catalog  
- Content pipeline (`.tres` shapes + `ContentLibrary`)  
- Optional save sections + migrations pattern  
- `SystemWorld` / traffic / hostiles (raise behaviour, not throw away)

---

## 4. Maturity definitions (how we know we’re done)

### Core complete = **real Alpha** (bug-smash starts)

All of the following **exist and talk to each other**, even if content is still lean:

1. **Economy sim** — stocks, production/consumption, moving prices, player impact caps, save/load  
2. **Living activity** — generated jobs + opportunistic space events + escort job kind  
3. **Enforcement surface** — patrol response / customs light / bounty pressure beyond dock refuse  
4. **Ship layer complete enough** — equipment/weapons depth for both hulls; money sinks that matter  
5. **Operations** — hire at least one ship, warehouse, retainer/charter money loop  
6. **Campaign framework** — spine flags, milestones, authored beats scaffolded through Holding  
7. **Holding purchase path** — claim→…→ignition thin but playable; debts-clear gate  
8. **Sandbox continue** — post-ignition free career, no forced quit  
9. Save round-trips all new persistent state; lint + full GUT green; human gates on feel pillars  

### Content complete = **real Beta**

- Map/content budgets filled for 30h/80h targets  
- Full campaign authored and paced  
- Named Entities/People/places (placeholders replaced where required)  
- Most major bugs found; balance pass  
- Presentation floor for Steam (not AAA, but not gray boxes forever)

### Polish / launch

- Audio pass, VFX, UI, Steamworks (achievements, overlay, depot), performance, accessibility  
- RC human gate  

---

## 5. Economy simulator (design — first-class pillar)

### 5.1 Thesis

Stations are **economic actors**, not infinite shops. Goods have **stock**. Stock moves **prices**. Production and consumption run on a **world clock**. The player is a **local force**, not a god.

### 5.2 Core model

| Concept | Behaviour |
|---------|-----------|
| **Station market** | Per station, per commodity: `stock`, optional `capacity` |
| **Price** | Derived from stock vs target band (not freeform chaos). Low stock → high buy price; high stock → low buy / soft sell |
| **Production** | Station profile produces goods per tick (e.g. yard makes alloy/parts; habitat makes demand for grain) |
| **Consumption** | Station profile consumes goods per tick |
| **Player trade** | Buy reduces stock / sell increases stock; price recalculates after trade |
| **NPC freight (abstract)** | Soft background flow between linked systems so empty markets refill slowly without player babysitting |
| **Shocks** | System security, blocked gates (later), campaign flags, player-mass dumps apply temporary modifiers |
| **Player weight** | Hard caps per trade + soft diminishing impact so one run cannot zero a core hub forever |
| **Contraband** | Still jurisdictional (existing law); illegal goods use black-market stock where controller forbids open trade |

### 5.3 Architecture (implementation shape)

New single owner (name flexible; recommend **`MarketService`**):

- Loads station economic profiles from data (extend `Station` or companion resource — full-sized fields)  
- Owns runtime market state; only writer of stocks/prices  
- Emits EventBus signals: market changed, shortage, price shock  
- `CargoService` asks MarketService for quote and commits trades through it  
- `WalletService` stays money/fuel/debt only (split hull-condition out before S6 — see §12 S5/S6)  
- Static mul tables in `BalanceEconomy` become **seed / fallback**, then retire as primary once sim is live  

**Pricing is per-station, not per-system.** Today’s code is system-keyed and throws the station away when pricing; S2 must invert that. Station content needs **economic identity** (profile fields) and **real world positions** (end all-stations-at-offset-zero stacking). Two stations in one system can and should show different prices for the same good.

**World clock (S1 — not a TimeScale reuse):** a real **`WorldClock`** (or equivalent service) that:

- Owns **accumulated game time** (elapsed seconds / ticks) independent of the player ship and of world load/unload  
- Exposes tick categories consumers subscribe to (market, board, security, upkeep)  
- Exposes explicit **advance N hours** for away-time (jump; later long dock rest)  
- Persists in the save (clock lives with sim state — market section may carry it from day one)  
- **Combat policy (locked 2026-08-02):** world clock **always advances**. Combat only caps player time-scale UI to **1x** (no 4x/16x during combat). Combat does **not** freeze the sector economy.  
- Wallet **upkeep moves onto the world clock** (stop using the player ship’s physics update as the economy heartbeat)

Tick markets while undocked; advance compressed away-time on jump (and later long dock rest). Docked trading remains immediate.

**Save:** optional section `market` (or `economy`) — world clock + station_id → commodity stocks + last tick. Prefer optional keys first; required fields only with migration if unavoidable.

### 5.4 Commodities

Keep ~10–12 goods for 1.0 (Destination ~12). Expand profiles, not SKU explosion.

Suggested economic roles (content tags, not code spaghetti):

- Staples (grain, rations)  
- Industry (ore, scrap, alloy, spare parts)  
- Energy (fuel cells — still distinct from ship tank fuel unless we later link them deliberately)  
- War (munitions)  
- Care (medical)  
- Luxury (luxuries)  

### 5.5 Player-facing readability (required)

Captain must answer without a wiki:

- “What’s expensive here?”  
- “Why?” (short reason: shortage / war demand / production hub)  
- “Where might this sell?” (hints from map or trade board, not spoiler GPS for every unit)

**S2 gate surfaces (not deferred to S3):**

- Station Trade UI with **quantity control** (not 1-unit-per-click only)  
- **Visible reason line** on prices  
- **One-line news ticker** (minimal “why the sector is moving”) so the sim is legible while docked  
- Optional later: personal **trade log** of prices the player observed (stale until revisit) — strong Tone fit; S2 or S3 if capacity allows  

### 5.6 Acceptance criteria (economy pillar)

- Same good can be scarce in one station and abundant in another **because of stock**, not only a hardcoded mul  
- After player buys out a local stock, price rises and further buy is limited or expensive  
- Over time without player, production/consumption + NPC flow move prices  
- Save/load restores market state  
- Headless tests: production tick, player dent, weight cap, contraband path still legal  
- Human gate: “I can plan a trade route and feel the market fight back”  
- **Long-run stability:** 10,000 ticks across all systems with no player → every stock stays in band; no price zero/explode/NaN  
- **Away-time equivalence:** jump compressed time ≈ equivalent live ticks within tolerance  
- **Determinism:** same seed + same actions → byte-identical market save section  
- **No same-station money pump:** buy-then-sell at one station is always a net loss  
- **No dead commodities:** every commodity has ≥1 profitable route somewhere in the live sector at boot  
- **Tick cost budget:** full sector market tick under a named millisecond budget (measure; no vibes)  

### 5.7 Explicit non-goals (economy 1.0)

- Full player-to-player / multi-agent auction house  
- Real-time global ticker UI  
- Perfect general equilibrium solver  
- Mining loop required for sim (belts may feed later; not blocking)  

---

## 6. Living sector & activity density

### 6.1 Job generation

Replace “12 fixed board rows forever” with:

| Layer | Role |
|-------|------|
| **Templates** | Hand-authored job *kinds* and story jobs |
| **Radiant instances** | Generated offers from market shortages, bounties from threat, haul from stock imbalance |
| **Board restock** | Stations refresh offers over world clock |
| **One active mission** (keep) unless Ops later allows fleet jobs |

**Job kinds for core complete:**

1. Delivery / haul (exists)  
2. Bounty / patrol (exists)  
3. Smuggle (exists)  
4. **Escort** (new — Destination v1)  
5. Optional later in content: salvage, passenger, recovery-as-flown mission  

### 6.2 Opportunistic space events

While free-flying (not only menus):

- Distress / convoy under attack  
- Wreck / salvage marker  
- Customs scan in patrolled space  
- Pirate intercept on rich cargo  
- Rumor beacon → station contact  

Spawn under ship budget (20 concurrent still law until raised with evidence).

### 6.3 Traffic with purpose (lite)

Upgrade ambient traffic from pure orbits toward:

- Lane-ish routes pad ↔ gate  
- Occasional dock/undock  
- Roles already readable (civilian / patrol / pirate)  

Full Elite-scale AI **not** required for 1.0.

### 6.4 News / rumor layer

One thin feed (station board + optional HUD toast):

- “Gamma short on medical”  
- “Drift hunting in Beta spit”  
- Campaign beats surface here too  

Driven by market + security + campaign flags — not a novel generator.

---

## 7. Standing career surface (expand, don’t reinvent)

Law stays in `docs/reputation_and_standing.md`. Product fills **play surface**:

| Feature | Core complete? | Notes |
|---------|----------------|-------|
| Status moment | Have | Protected forever |
| Dock refuse + recovery exception | Have | Keep |
| Kill attribution | Have | Keep |
| More recovery chains | Content + framework | Raise budget past 2 |
| Network betrayal | Partial | Reputation doc allows; implement when content needs it |
| Customs / fines loop | Light | Expand contraband path into playable scans |
| Patrol response | New | Crime in patrolled space draws heat over time |
| Traitor career flags | Mid/late core | Standing flags + enforcement, not a separate alignment bar |
| High-rank People intros | Content phase | Same recovery machine |

---

## 8. Progression: Ship → Operation → Holding

### 8.1 Ship (early game) — finish the layer

- Equipment / weapons ~12 + ~10 gear (Destination budget) with real tradeoffs  
- Hauler vs Fighter interlock remains law  
- Stronger sinks: repair, insurance-ish fees optional, outfitting  
- Escort + trade + bounty all viable openings depending on life path  

### 8.2 Operation (mid game) — anti-boredom layer

Minimum playable Ops for core complete:

| Piece | Behaviour |
|-------|-----------|
| Hire 1–N ships (start N=1–2) | Cost + upkeep; standing gates hire |
| Orders | Haul route, escort player, park at station |
| Warehouse | Off-ship cargo at owned/friendly dock |
| Retainer / charter | Standing-sensitive contract; breach → standing hit |
| Dashboard | Simple income/risk UI |
| Save | `operation` section |

Fleet ships count against a **raised** performance budget only after measured; ambient traffic may reduce when fleet active.

### 8.3 Holding (campaign climax)

Destination ladder kept: **Claim → Power → Supply → Protect → People → Ignition**

| Rule | Spec |
|------|------|
| Candidates | ≥2 rocks/stations purchasable |
| Gates | **Debt clear** required for purchase/ignition (Elliot) + enough credits + milestones |
| Holding as Entity | Register player Holding; status moment on entry |
| **Ignition climax** | **Authored crisis mission**, not a bare purchase: a power contests the claim; player’s accumulated standings resolve the standoff; then epitaph + celebration. Buy/claim alone is not the final beat. |
| Act III money | Milestone work should **pay toward** Holding (price reduction or financing unlock) so late-game is not pure credit farm |
| After | **Sandbox** — free career, markets/jobs/Ops continue; Holding may offer passive hooks thin (dock, storage) without full empire sim |
| Deferred | Running a full post-ignition faction wargame |

---

## 9. Campaign architecture (Battletech spine + Skyrim freedom)

### 9.1 Structure

```
Life path + annexation (exists)
  → Act I: Survive the debt / learn the sector (~0–8h)
  → Act II: Choose a lane — trade, gun, shadow; Ops unlock (~8–20h)
  → Act III: Sector crisis / standing climax; Holding path opens (~20–28h)
  → Climax: Clear debt + buy/ignite Holding (~28–32h main)
  → Sandbox epilogue: open-ended
```

Hours are design targets; pacing tuned at content complete.

### 9.2 Mission mix

| Type | Purpose |
|------|---------|
| **Spine missions** | Authored; advance flags; cannot all be skipped if you want “campaign complete” |
| **Flashpoints** | Optional authored arcs (People, Traitor, war beats) — completionist meat |
| **Radiant** | Economy/security generated — volume for 80h |

Player may freeroam anytime; spine waits. “Campaign complete” = debt clear + Holding ignition. Sandbox does not require 100% flashpoints.

### 9.3 Save

Optional `campaign` section: act, flags, completed spine ids, Holding progress. Missing = sandbox-only / old saves.

### 9.4 Writing / content production

Spine needs real prose quality. Plan assumes **data-driven missions** (same as jobs) + a content pass phase — not hardcoded cutscene engine for every beat. Menu + space objectives + status moments carry Tone.

---

## 10. Content budgets (planning targets for 30h / 80h)

| Element | Now | Core complete (min) | Content complete (Steam 1.0 aim) |
|---------|-----|---------------------|----------------------------------|
| Star systems | 6 | 6–8 | **8–10** hand-built |
| Stations / docks | 10 | 10–14 | **16–22** |
| Entities | 4 | 6 | **8–12** |
| People | ~18 | 24+ | **35–50** (tracked) |
| Recovery / personal chains | 2 | 4+ | **8–12** |
| Commodities | 10 | 10–12 | 12 |
| Job kinds | 3 | 4 (+escort) | 4–5 |
| Radiant templates | 0 | Generator live | Tuned volume |
| Spine missions | 0 (+opening) | Framework + ~6–8 beats | **12–20** authored peaks |
| Holdings | 0 | 1 purchasable path | **2** candidates |
| Weapons / equipment | thin | usable sets both hulls | ~12 + ~10 |
| Concurrent ships | 20 | 20; raise only with evidence | same |

**Density rule:** prefer more **activity per system** over empty systems. Map growth is scheduled in content phases, not as the first fix for boredom.

---

## 11. Production presence (not optional for “oh shit”)

Core complete can stay readable primitives. **Beta/content complete** must include a real floor:

| Track | When | Bar |
|-------|------|-----|
| Ship / station readability | Early content | Silhouettes, materials, not final AAA |
| VFX (weapons, jump, impacts) | Mid | Combat and travel pop |
| Audio (engines, weapons, station, UI) | Mid–late | Presence |
| UI theme polish | Continuous | Steam screenshot test |
| Music / radio thin | Late | Tone, not full OST required for Alpha |

Art pipeline phase is scheduled; do not block economy/Ops on final art.

---

## 12. Phase map (execution order)

Phases are sequential. Each ends with definition-of-done + tests + `docs/state.md` + human gate where marked. **Do not freestyle reorder** without escalate.

### Phase S0 — Plan freeze & maturity reframe *(docs only)*

- Promote accepted plan into `docs/STEAM_PHASE_PLAN.md`  
- Update Destination deferred unlocks (story + dynamic economy) with pointer to product plan  
- Update `docs/state.md` next-work pointer  
- **Gate:** Elliot accepts this plan (this document)

### Phase S1 — World clock & sim foundation

**Job:** Real time owner + infrastructure every later sim needs. **Not** “reuse TimeScale as the clock.”

- **WorldClock service:** owns accumulated game time; ticks independent of player ship and world load/unload  
- Tick categories / subscribers (market, board, security, **wallet upkeep**)  
- Explicit **advance N hours** (jump away-time; long dock rest may hook later)  
- **Combat policy:** clock always runs; combat caps time-scale to 1x only  
- Save: clock + empty/scaffolded sim sections round-trip  
- EventBus signals catalogued  
- **Service lifecycle registry** (or resettable convention): career-reset no longer depends only on a hand-maintained name list in the main scene  
- **CI:** suite runs automatically on push (GitHub Actions or equivalent)  
- **Test-support helpers:** shared “build seeded world / advance N days” scaffolding under tests support (folder is empty today — fill it)  
- **Housekeeping:** fix text-encoding corruption in shipped UI strings + `docs/gates.md` (garbled em-dashes)

**Accept:**

- Clock advances deterministically in tests (including multi-frame vs chunk equivalence pattern already used elsewhere)  
- Away-time advance moves the same accumulators  
- Save round-trip of clock + empty sim sections  
- Upkeep no longer depends on player-ship physics as the only heartbeat  
- CI green on push for the suite  
- Career reset path covers new services without forgetting a name string  

**No human feel gate on S1.** First Steam play gate is S2.

### Phase S2 — Economy simulator *(pillar)*

**Job:** Living markets the player can see and poke without UI friction.

- MarketService + **per-station** economic profiles (station-keyed prices — invert system-only pricing)  
- Station data: economic fields + **real positions** (no stacked zero-offset stations)  
- Stock, production, consumption, price curves, player weight  
- Wire CargoService trade through market  
- Trade UI: **stock + reason line + quantity control**  
- **One-line news ticker** (minimal visibility of sim motion; full rumor layer can thicken in S3)  
- Seed content for all live stations  
- **Money-event telemetry log** (local CSV or equivalent of credit events by activity — balance fuel for S9)  
- Headless criteria in §5.6 including stability / equivalence / exploit / tick budget tests  

**Accept:** criteria in §5.6 (including new kill-shot tests)  
**Gate [Elliot]:** trade route feel / market fights back — judged with quantity UI + visible reason, not 1-unit theater  

### Phase S3 — Living activity density *(pillar)*

**Job:** Hours of things to do without Ops yet. **Split into two sub-slices; gate after the second.**

**S3a — Radiant work surface**

- Radiant job generator fed by market + security (design for variety: stakes, standing entanglement, chained consequences — not only “another haul row”)  
- Escort job kind  
- Board restock on world clock  

**S3b — Space life + news**

- Opportunistic **incidents** (distress, intercept, customs light) — **not** full MissionService missions by default  
  - **Locked 2026-08-02:** incidents are a lightweight concept separate from the one-active-mission slot; accepting an incident may promote it to a mission  
- News/rumor feed v1 (thicken S2 ticker if needed)  
- Traffic purpose lite (dock/undock + a few purposeful freighters when news says a shortage exists)  

**Accept:** in a 60–90 min free session, player finds varied work without exhausting a fixed 12-row board  
**Gate [Elliot]:** “not a thin menu loop” (after S3b)  

**External playtest checkpoint (after S3 gate):** first strangers touch the build. Plan who/how many and what is measured before calling the 30h path honest.  

### Phase S4 — Enforcement & standing career surface

**Job:** Law has teeth in space, not only at the pad.

- Patrol heat / response  
- Customs scan playable loop  
- Bounty pressure from crime  
- Extra recovery chains (budget lift)  
- Betrayal network lite if law requires for content  

**Accept:** crime in patrolled space feels different from lawless; recovery still works  
**Gate [Elliot]:** jurisdictional identity still the star  

### Phase S5 — Ship layer complete

**Job:** Outfitting and combat/trade identity for long careers.

- Weapons/equipment data + install/remove  
- Balance both hulls for 10+ hour play  
- Money sinks tied to outfitting  
- Perf pass under denser events (**measure** densest system: full hostiles + market ticking — 60fps budget needs an instrument)  
- **Before S6 starts:** schedule **WalletService split** (money/debt vs fuel vs hull-condition / combat fail-state) so Ops retainers and ship equipment do not collide in one 700-line god service  
- **Screenshot / Steam-page floor (S5–S6 window):** capsule-ready presentation milestone pulled forward from S10 — wishlists need months; do not wait for polish phase to first look shippable  

**Accept:** both careers (hauler-first, fighter-first) viable into mid-game  
**Gate [Elliot]:** ship fantasy not bored  

### Phase S6 — Operations *(mid-game pillar)*

**Job:** Fleet is how you have cargo *and* guns.

- Hire/fire, upkeep, orders, warehouse, dashboard  
- Standing-gated charters  
- Save section  
- Economy + radiant interact with fleet hauls  
- Wallet split complete enough that Ops payees are not bolted into hull-condition code  

**Accept:** player can run a small operation and feel progression past solo courier  
**Gate [Elliot]:** Ops feel  

### Phase S7 — Campaign framework + Acts I–II content

**Job:** Spine exists and first half is playable; new players survive the first two hours.

- Campaign flags, mission data shape, UI journal thin  
- Act I–II authored beats (debt, annexation fallout, first real choice of lane)  
- Integrate radiant around spine (standing-tier gates on spine beats so radiant income cannot trivially skip debt pressure — design before writing)  
- **Onboarding:** Act I beats double as tutorial for flight + trade + standing + debt; add a “new player cold start” check to the gate  

**Accept:** new player can follow spine ~half campaign without console; cold start does not refund-bait in the first 2h  
**Gate [Elliot]:** story / freeroam balance + cold start  

### Phase S8 — Holding + Act III + climax + sandbox continue

**Job:** Campaign complete path and epilogue.

- Holding candidates, milestones, purchase path  
- Debt-clear gate  
- Act III crisis beats (milestones pay toward Holding — see §8.3)  
- **Authored ignition crisis mission** (power contests claim; standings resolve) + epitaph + celebration  
- Sandbox continue (no soft-lock, markets/Ops live)  

**Accept:** debt clear + Holding ignition (crisis resolved) ends campaign; continue play free  
**Gate [Elliot]:** endgame feel + structural rhyme (“powers respond”)  

### Phase S9 — Content complete (real Beta)

**Job:** Fill toward 30h / 80h.

- Map expansion to budget  
- People / chains / flashpoints  
- Spine complete count  
- Names/lore pass where approved  
- Balance economy + combat + pay (use S2 money telemetry)  
- **Writing production:** spine + chains + People need an owner/schedule; dialog/conversation data shape if menus are not enough — S9 is the most likely schedule blowout; plan for it to run long  

**Accept:** measured playtests (including external) hit ~30h main path without dead air; completionist hooks exist  
**Gate [Elliot]:** content complete  

### Phase S10 — Production polish + launch prep

**Job:** Steam-ready presentation and packaging.

- Art/audio floor, UI, performance, accessibility (rebinds, sensitivity, FOV, colorblind-safe standing colors, controller yes/no — decide early if still open)  
- Steamworks hooks as needed; page should already be live from S5–S6 screenshot floor  
- Bug smash from Alpha/Beta debt  
**Gate [Elliot]:** release candidate  

---

## 13. Rough calendar (solo + AI agents — honest)

Not a promise — a planning envelope:

| Block | Phases | Rough span |
|-------|--------|------------|
| Foundation + economy + living activity | S1–S3 | 3–5 weeks |
| Enforcement + ship + Ops | S4–S6 | 3–5 weeks |
| Campaign + Holding | S7–S8 | 3–5 weeks |
| Content complete | S9 | 4–8 weeks *(plan for this to double — writing + 30h balance)* |
| Polish / RC | S10 | 3–6 weeks |

**Order-of-magnitude: ~4–7 months** to a serious 1.0 candidate at this bar, not “a few weeks.” Weeks get you **real Alpha (core complete)** if focused (through ~S6–S8 thin). Full 30/80 + polish is longer. **Do not schedule external commitments against the end date.** Scope cuts only by Elliot.

---

## 14. What we deliberately will not build for Steam 1.0

| Out | Why |
|-----|-----|
| Infinite procedural galaxy | Fights Freelancer filter; density > sprawl |
| Planetary landings / walking / interiors | Destination locked out |
| Multiplayer / VR | Locked out |
| Full Eve market | Wrong fantasy; unmaintainable solo |
| Playable empire sim after ignition | Deferred; sandbox freighter life stays the post-game |
| Edge mystery campaign | Deferred unless reopened |
| Hybrid hulls / damage matrix | Optional post-1.0 |
| Greenfield rewrite of flight/standing/save | Refuse |

---

## 15. Architecture rules (carry forward)

1. Standing mutations only via StandingService  
2. Cross-system communication EventBus-only; catalog every signal  
3. Full-sized data shapes; content is rows  
4. Tunables in balance files  
5. Optional save sections preferred; required fields → ask + migrate  
6. Definition of done: criteria, lint, tests, events.md, state.md  
7. Human feel gates for economy, activity, Ops, campaign, Holding, RC  
8. No invented standing rules  

---

## 16. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Economy too abstract / spreadsheety | Reason line + ticker + quantity UI in S2 gate; human gate S2 |
| Economy too gameable | Player weight caps + NPC flow + kill-shot tests (sec 5.6) |
| Player ship was the sim heartbeat | WorldClock owns time; upkeep moves off ship physics (S1) |
| Per-system prices vs per-station model | Explicit S2 inversion + station economic identity/positions |
| S3 overload (six systems thin) | S3a / S3b split; gate after S3b |
| Ops + traffic blow 60 fps | Fleet budget; reduce ambient when fleet active; measure before raise |
| Campaign fights freeroam | Spine optional timing; radiant always available; standing gates on spine |
| Climax is a purchase | Authored ignition crisis mission (S8) |
| Scope fantasy vs months | S0 sign-off; cut only at phase boundaries with Elliot |
| Content writing bottleneck | Data-driven missions; thin VO; prioritize spine prose; S9 may double |
| Calling tech demo "Alpha" again | Maturity language in state.md only |
| Regressions invisible after S2 | CI on push from S1; money telemetry from S2 |
| Career state leaks across saves | Service lifecycle registry in S1 |

---

## 17. Immediate next steps (post-review absorb)

1. Plan v1.1 written into this file (done when this section is current)  
2. `docs/state.md` → review absorbed; **S1 ready when Elliot says go**  
3. Journal: review outcome + locked decisions  
4. **Only after Elliot says go:** open S1 implementation session with `/work` — **subagents build**  
5. Do **not** start Ops/Holding/campaign code before S1–S2 foundations  
6. Do **not** start S1 until go (planning complete ≠ code authorized)

---

## 18. Decision summary for Elliot

| Decision | Plan recommendation |
|----------|---------------------|
| Mode shape | Campaign-through-Holding, then sandbox (your lock) |
| Map | Hand-built dense; grow to ~8–10 systems in content phase |
| Economy | Full MarketService sim (S2) before Ops/Holding |
| Procgen | Jobs, events, market noise — not star map |
| First code phase | S1 WorldClock → S2 economy → S3a/S3b activity |
| Combat + time | Clock always runs; combat caps speed to 1x (locked) |
| Space events | Incidents ≠ MissionService by default (locked) |
| Real Alpha | **plan marks real Alpha at S8 accept** (all core pillars including Holding path) |
| Real Beta | S9 accept |
| Timeline honesty | Months for 1.0; weeks for early core pillars only; S9 may double |

---

## 19. Open questions (non-blocking defaults if you accept as-is)

Defaults used in this plan unless you change them:

1. **Ship fuel vs fuel-cells commodity** — stay separate for 1.0 (simpler); optional link later  
2. **Active missions** — still one personal mission; fleet jobs are Ops orders, not second player mission  
3. **Incidents** — lightweight; may promote to mission on accept (locked 2026-08-02)  
4. **Holding after ignition** — passive dock/storage only; no empire management  
5. **Early Access** — not assumed; plan aims at full 1.0 candidate (EA can be a later cut of S9)  
6. **Player trade log** (observed prices) — optional S2/S3 if capacity; not blocking  
7. **Controller support** — decide yes/no by S5 screenshot floor, not at S10  

If any default is wrong, say so before S1 go; we amend the plan first.

---

## 20. Sign-off block

| Field | Value |
|-------|--------|
| Plan version | **1.1** (2026-08-02) |
| Elliot accept (v1.0) | **accepted 2026-08-02** |
| Outside review | Fable, 2026-08-02 — `docs/OUTSIDE_REVIEW_2026-08-02.md` |
| Amendments (v1.1) | **All 11 Fable amendments accepted** 2026-08-02 — see §21 |
| Combat/time policy | Clock always runs; combat caps to 1x |
| Incident vs mission | Incidents separate; may promote to mission |

**v1.1 accept means:** amended plan is the build queue; S1 is next **when Elliot says go**.

**Code still requires explicit go** for S1 — absorbing review is not a build order.

---

## 21. Fable amendments absorbed (v1.1)

| # | Severity | Amendment | Where landed |
|---|----------|-----------|--------------|
| 1 | Blocker | Real WorldClock in S1 (elapsed time, away-time, save, combat policy, upkeep on clock) | §5.3, Phase S1 |
| 2 | Blocker | Per-station pricing + station economic identity/positions in S2 | §5.3, Phase S2 |
| 3 | Important | Quantity UI + reason line + news ticker in S2 gate | §5.5, Phase S2 |
| 4 | Important | Economy kill-shot tests | §5.6 |
| 5 | Important | Authored ignition climax mission | §8.3, Phase S8 |
| 6 | Important | CI + test-support harness in S1 | Phase S1 |
| 7 | Important | WalletService split before S6; incidents vs missions before S3 | S5/S6, S3b, §19 |
| 8 | Important | Service lifecycle registry in S1 | Phase S1 |
| 9 | Important | External playtest after S3; screenshot floor S5–S6; onboarding in S7 | S3, S5, S7 |
| 10 | Polish | Money telemetry in S2; S3 split a/b | Phase S2, S3 |
| 11 | Polish | Text-encoding fix in S1 | Phase S1 |

**Explicitly not changed (review §9):** phase order; standing law; optional-save + byte-determinism; 10–12 commodity cap; content budgets / loud-failure loading; tech-demo maturity language; 20-ship budget until measured; AGENTS.md discipline.
