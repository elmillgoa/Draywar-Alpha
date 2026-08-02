# Draywar — Outside Review (Fable, 2026-08-02)

**What this is:** Independent read-only review of the Steam 1.0 plan and codebase, commissioned before S1.
No code was changed by the review. This file is the findings, verbatim.

**How to use it:** Next session ingests this per `docs/state.md` — summarize Top 5, propose plan
patches, Elliot accepts/rejects, write accepted amendments into `docs/STEAM_PHASE_PLAN.md`,
then unblock S1 only when Elliot says go.

**Docs read in full:** `docs/PRODUCT_DIRECTION.md`, `docs/STEAM_PHASE_PLAN.md`, `docs/state.md`,
`DRAYWAR_DESTINATION_v2.md`, `docs/reputation_and_standing.md`, `AGENTS.md`, `docs/save_schema.md`.
Skimmed: `docs/BETA_ROADMAP.md`, `docs/gates.md`, `docs/events.md`.
**Code sampled:** full service layer (`src/systems/`), data layer (`Balance*`, content shapes,
ContentLibrary), world layer (SystemWorld, NpcTraffic, TrafficShip, HostileNpc), station UI
(StationMenu + helpers), test harness (571 tests / 63 files, three read in full).

---

## 1. Executive verdict

The Steam plan is pointed at the right product. "Space Skyrim under Freelancer rules" with a
hand-built dense sector is a real, sellable niche, and the maturity reframe (tech demo, not Alpha)
is the most honest self-assessment I've seen in a solo project.

**Biggest strength:** the foundation discipline is genuinely rare. Single-writer standing is real
and verified (every write site traced — there are six, all sanctioned). Saves are byte-deterministic
with a hostile test fixture. Content loads fail loudly. The signal catalog is enforced by the build.
This is not theater.

**Biggest hole:** the plan builds the economy (S2) on a world clock (S1) that the plan itself
underspecifies — and the codebase actively contradicts it. There is no clock today: a speed
multiplier that locks to 1x in combat, with the player's ship acting as the economy's heartbeat.
S1 as written ("reuse TimeScale") would inherit both problems. Second hole: the 30-hour promise
rests almost entirely on radiant content quality, which no phase gates.

**Build S1 as planned: yes-with-changes.** The changes are in section 8. None of them reorder the
phases; they make S1 and S2 land on solid ground.

---

## 2. Plan vs product bar

**Solid — do not reopen:**
- Campaign-through-Holding → sandbox on the same save. Right shape, matches the structural rhyme,
  and the "no forced game over" call is correct for this audience.
- Economy before Ops before campaign (S2 → S6 → S7). Each layer consumes the one below it.
  Reordering would mean building Ops against a dead market.
- Hand-built sector + generated volume, not procgen galaxy. Locked correctly.
- Standing law staying frozen. The reputation doc is complete enough to build against.
- Keeping ~10–12 commodities and expanding *profiles* rather than SKU count. Correct — X3 proved
  200 wares is spreadsheet punishment, not depth.

**Underspecified for a 30h/80h game:**
- **The world clock (S1).** The plan gives it four bullet points. It's the load-bearing wall for
  everything after. What exists today: a 3-speed multiplier (1x/4x/16x) that has no memory, resets
  on load, stops when the world is torn down, and drops to 1x during combat. Nothing anywhere
  records elapsed game time — not even the save file. S1 needs a real specification: who owns
  accumulated time, what "advance 8 hours on jump" actually does to markets/boards/heat, whether
  combat freezes the world or only the player's ship, and how time is saved. As written, an
  implementing agent could "pass" S1 without building any of that.
- **Radiant job quality.** S3 says "radiant job generator fed by market + security" — one line for
  the system that must carry roughly 60–70% of the 30 hours and nearly all of the 80. Battletech
  2018 (the plan's own reference) lived or died on its procedural contract variety, and even it got
  repetitive by hour 40. The plan has a gate for "not a thin menu loop" but no design for *why*
  generated job #200 feels different from #20 (varying stakes, standing entanglements, chained
  consequences).
- **What the player does with money mid-game.** Plan §8.1 lists sinks, but between "paid off debt"
  (maybe hour 10–15) and "can afford a Holding" (hour 28+), the only stated purchases are
  outfitting and Ops ships. That's the exact stretch where trading games go dead. Needs explicit
  intermediate money milestones.
- **Onboarding.** Not mentioned in any phase. See section 7.

**Overscoped / will die mid-build:**
- Honestly, less than expected. The plan already cut the right things (§14: no Eve market, no
  empire sim, no landings).
- The one to watch: **S3's full list in one phase** (radiant generator + escort + board restock +
  space events + news feed + traffic purpose). That's five systems. If S3 slips, split it —
  radiant jobs + escort first, events + news second — rather than shipping all six thin.
- The calendar (§13: 4–7 months to 1.0) is optimistic for the 30h/80h bar even with agents. S1–S8
  in ~9–15 weeks is plausible; S9 "content complete" at 4–8 weeks assumes writing, balancing, and
  playtesting 30 hours of content in two months. Plan for S9 to double. This isn't a reason to
  change the plan — it's a reason not to schedule anything against its end date.

**Phase order:** Correct overall. One insertion recommended (amendment 6): a small
"infrastructure" step inside S1 — CI and a test-support harness — because after S2 you will never
again want to hand-run 571+ tests on one machine. One flag: art/presentation is deferred to S9/S10,
but the Steam page needs screenshots months before launch to accumulate wishlists — pull a
"screenshot floor" milestone earlier (see section 7).

---

## 3. Economy sim design review (plan §5)

**Is MarketService + stock/production/consumption the right 1.0 model?** Yes.
Station-as-economic-actor with stock-derived prices inside a target band is the proven middle
ground — essentially Patrician/Port Royale economics, which is exactly right for a freighter game.
The explicit non-goals (§5.7) are correctly chosen. The "static tables become seed data, then
retire" migration path is smart and cheap: every price in the game flows through exactly two
functions with three call sites total. Swapping the source behind them is a genuinely small change.

**But the plan has one wrong assumption and three unaddressed failure modes.**

**The wrong assumption:** prices today are per-*system*; the plan's model is per-*station* stock.
Two stations in the same system currently sell grain at the identical number, and the code throws
the station away when pricing. The plan never mentions this inversion. Related and worse: the
`Station` data shape has **no economic identity at all** — four fields, none economic — and every
station in the game sits at position offset zero, meaning stations in the same system are stacked
at the same point in space and the E6 multi-dock traffic features are silently inert. Per-station
economy needs stations that are actually different places, in data and in space. That's S2 scope
the plan doesn't count.

**Failure modes:**

1. **Player breaks the market.** The plan handles this well (hard caps + diminishing impact + NPC
   background flow). One gap: nothing prevents the classic *same-station buy/sell ping-pong* — the
   spread and the update timing need a test, because this is the first exploit every trading-game
   player tries.
2. **Spreadsheet hell — and its opposite, click hell.** §5.5's readability requirements are right.
   But the current trade UI buys and sells in **fixed quantities of 1** — buying a 20-unit load is
   20 clicks. A stock-based market makes this unbearable and it's not in any phase. A quantity
   control is a hard prerequisite for the S2 gate.
3. **Invisible sim.** The plan ticks markets *while undocked* and trading is *immediate while
   docked* — so the player mostly sees the market when it's frozen. If prices only visibly move
   between visits, the sim reads as random numbers, not a living economy. The reason line
   ("shortage — pirate raids") and the news feed are what make the sim visible, but the news feed
   is in S3, one phase after the economy gate. Move a one-line news ticker into S2, or the S2 human
   gate ("market fights back") will be judging a sim the player can't see fighting.
4. **Time-compression edge cases** the plan doesn't address: combat locks time to 1x globally
   today — does a dogfight freeze the sector's economy? Does sitting docked for an hour advance
   markets or not ("long dock rest" is mentioned but undefined)? These sound like trivia; they're
   the exploit surface.

**Missing for "space Skyrim trade":** routes as *knowledge*. Skyrim's magic is learning a place.
The plan gives prices and reasons, but nothing persistent the player earns — e.g., a trade log that
remembers prices *you personally observed* at stations you visited (stale until you return). That
single feature turns trading from spreadsheet into exploration, fits the Tone filter (a captain
keeps books), and is cheap. Strongly recommend adding to S2 or S3.

**Concrete acceptance tests to add to §5.6:**
- **Long-run stability:** 10,000 ticks across all systems with no player input → every stock stays
  within its band, no price hits zero or explodes, no NaN. (Guards against runaway feedback loops —
  the #1 sim-killer.)
- **Away-time equivalence:** jumping (compressed time) produces the same market state as ticking
  the equivalent seconds live, within tolerance. (Guards the S1/S2 seam.)
- **Determinism:** same seed + same actions → byte-identical market save section. (The harness for
  this already exists; it keeps the byte-deterministic save guarantee alive.)
- **No same-station money pump:** buy-then-sell at one station is always a net loss.
- **No dead commodities:** every commodity has at least one profitable route somewhere in the live
  sector at boot.
- **Tick cost budget:** a full market tick for the whole sector completes under a set millisecond
  budget — because there is currently no performance measurement anywhere in the project (the
  "60fps" test is a no-crash smoke).

---

## 4. Campaign → sandbox

**The shape works.** Debt-clear + Holding purchase as the climax is structurally sound and the
annexation-opening → sovereign-ground-ending rhyme is genuinely good writing architecture.

**Risk 1 — the climax is a purchase, not a peak.** As written (plan §8.3: milestones, purchase,
ignition, epitaph, celebration), the final beat of a 30-hour game is *clicking buy*. The
Destination's own rhyme — "daring the powers to try that on ground the player owns" — implies the
powers *respond*. Without an authored ignition crisis (a claim contested, a defense, a standoff
resolved by the standings you've built), the ending is an account balance. Battletech understood
this: its campaign ends in an authored assault, not in reaching a C-bill target. This is the single
most important content decision in the plan and it's currently one table row.

**Risk 2 — the pre-climax grind.** If Act III's gate is "have Holding-scale money," the last 5–8
hours risk becoming pure credit farming. The mitigation is making Act III beats *pay toward* the
Holding (milestone work reduces the price, or unlocks financing) so story progress and money
progress are the same progress.

**Risk 3 — spine/radiant integration is asserted, not designed.** "Radiant integrates around
spine" (S7) is the hard problem: what stops a player from out-leveling the debt pressure with
radiant income before Act I's debt beats fire? Battletech solved this with reputation/tonnage
gating on story missions. Here the natural gate is standing — spine beats requiring standing tiers
you can only reach by playing in a jurisdiction. That's a design decision to make *before* S7.

**Enough for 30h/80h?** The math is tight but honest: 12–20 spine missions is maybe 8–12 authored
hours; the other ~20 must come from trading, standing careers, and radiant volume. That's the
correct *shape* for this genre (Freelancer's campaign was ~15h; the game was the freelancing). But
it means economy visibility and radiant quality *are* the hours target. The 80h completionist
figure depends on the flashpoint/People chain budget (8–12 chains, 35–50 People), which is listed
but has no writing-production plan behind it (see section 7).

**Vs Battletech-2018 career structure, what's missing:** (a) a between-mission home base with
texture — Battletech's ship gave downtime meaning; the equivalent here is station depth, currently
one menu; (b) time-based financial pressure — Battletech's monthly bills forced action; upkeep
exists, but the plan should make recurring obligations (loan schedule, Ops retainers) the pacing
engine, which conveniently is also what makes the economy matter; (c) crew/companion attachment —
People are the equivalent and the 2 existing recovery chains prove the machine, but 35–50 tracked
People with no writing pipeline is where this dies.

---

## 5. Codebase readiness (honest)

**Real and reusable — build on all of it:**
- **StandingService** — verified single-writer (all six write sites go through the sanctioned API
  with reason codes), tiers, stickiness, ripple, save section. The best code in the project.
- **Save stack** — versioned envelope, byte-for-byte deterministic, canonical encoding, optional
  sections that cost zero migrations, and the best test file in the repo proving it. Adding
  `market` / `operation` / `campaign` sections is the designed-for case.
- **ContentLibrary** — loud-failure loading, per-category budgets, add-content-without-code. New
  content categories (station economic profiles, campaign flags) slot straight in.
- **EventBus + enforced catalog** — 83 typed signals, build fails if code and docs disagree. Scales
  to the ~120 signals the new systems need.
- **Test harness** — 571 real tests, strict typing enforced as build errors, and the exact patterns
  an economy sim needs already proven (deterministic multi-frame-equals-single-chunk ticking in the
  wallet tests; byte-stable save round-trips).

**Thin theater (known and honestly labeled, but confirm you know):**
- Traffic movement is a parametric circle — no destinations, no docking. The *consequence* layer on
  traffic (targetable, killable, witnessed, attributed) is real; the *life* is not.
- The migration system has never performed a real migration. The seam is tested with fakes; the
  first real schema bump is its first live fire.
- The 20-ship budget holds by arithmetic and tests, not by any runtime guard, and no FPS is
  measured anywhere.
- "Feel"-area tests (E5/E6 density) largely assert constants and "at least 1 exists" — they'd stay
  green if the game felt dead, which is exactly what happened at the E6 gate.

**Architectural landmines for the S-phases — the review's core code findings:**

1. **No world clock exists, and the current heartbeat is the player's ship.** Credit upkeep ticks
   inside the player ship's physics update; when the world unloads, economic time stops. Time speed
   drops to 1x whenever combat locks. Nothing records elapsed time — not even the save. S1 must
   replace this pattern, not extend it.
2. **WalletService is four services in one** — money, fuel, *hull condition and the combat
   fail-state*, and the loan system, in one 710-line file. The plan itself says "WalletService
   stays money/fuel/debt only" — it isn't that today. Ops (recurring payments to N payees) and the
   ship-equipment phase (S5, which needs hull state) will both collide with it. Budget a split
   before S6.
3. **Two service lifecycles with a hand-maintained reset list.** Some services live forever, some
   per-career, some per-play-session, and resetting between careers depends on a hardcoded name
   list in the main scene. A MarketService added to the wrong bucket, or forgotten on that list,
   silently carries one career's market state into the next. This will bite exactly once,
   expensively, unless S1 adds a registry or a "resettable" convention.
4. **Cross-service queries are stringly-typed duck-typing** (group lookup + "does it have this
   method" checks, ~50/128 occurrences). Fine at current scale, sanctioned by the lint rules — but
   Ops querying wallet+cargo+market+standing per tick will be ceremony-heavy. Not a blocker; a
   known tax.
5. **Per-system pricing must invert to per-station** (section 3), and station content needs real
   positions and economic fields.
6. **One-active-mission is load-bearing in MissionService** — S3's opportunistic events (distress
   calls) can't be missions without either a lightweight "incident" concept or a rework. Decide
   which before S3.
7. Small but player-visible: **text encoding corruption** (garbled em-dashes) appears in shipped UI
   strings and in `docs/gates.md`. Cosmetic, but it's on screen.

**Save/EventBus patterns: help or hinder?** Help, strongly. The optional-section save pattern is
precisely what a phased build needs, and the enforced signal catalog is what will keep six new
systems debuggable. The one save gap: no concept of time anywhere in it — the market section must
carry the clock from day one.

---

## 6. "Alive systems" gap

What makes a system feel busy for hours, beyond S3's list — ranked:

**Must-have for 1.0:**
- **Traffic that visibly participates in the economy.** Not full AI — but when the news says
  "Gamma short on medical," a freighter with medical should actually fly there. Even 2–3
  "purposeful" ships per system among the decorative ones closes the loop between sim and eyes.
  This is the single highest-value liveliness feature because it makes the *economy* visible in
  *space*, uniting the two pillars.
- **Docking/undocking traffic.** Ships that arrive, dock, leave. The current eternal circles are
  the #1 "tech demo" tell. (The code path is unobstructed; the movement layer needs a small state
  machine.)
- **Consequence persistence you can see:** the pirate you fled is still in the system when you
  return; the shortage you profited from is visibly easing. The sim will already do the second
  one — surface it.

**Nice:**
- Station chatter/comms barks keyed to standing and local state (text only, cheap, huge Tone
  payoff).
- Visible patrol behavior — patrols that scan someone *else* occasionally, so law feels ambient
  rather than player-targeted.
- Scheduled events — a convoy that runs weekly, a market day. Gives regulars a rhythm to learn
  (very Skyrim).

**Cut for 1.0:**
- Full lane networks with physical trade-lane infrastructure (Freelancer's rings) — beautiful,
  expensive, not needed at this density.
- Off-screen full simulation of other systems (abstract flow, as planned, is right).
- Any NPC-vs-NPC live combat simulation beyond scripted event spawns.

---

## 7. What's missing from the plan entirely

1. **Onboarding/tutorial.** Zero mentions in any phase. This game fronts flight + trade + standing
   + debt simultaneously; Steam refunds happen inside 2 hours. Needs a phase-level line item
   (likely S7, with the Act I beats doubling as tutorial), plus a "new player cold start" gate.
2. **External playtesting.** Every gate is Elliot. By S3 you cannot feel your own game anymore —
   nobody can. The 30h claim specifically cannot be validated by its author. Plan needs: when
   strangers first touch it (recommend after S3), how many, and what's measured.
3. **A writing production plan.** S9 needs 12–20 spine missions, 8–12 chains, 35–50 People, plus
   news lines and barks. That's a real word count with a quality bar ("real prose quality," §9.4)
   and no owner, no tooling (no dialog/conversation data shape exists — only mission templates),
   and no schedule. This is the most likely S9 blowout.
4. **CI and automated builds.** Tests run only when a human runs a script on one machine; there is
   no continuous run, no export pipeline, no nightly build. Before S2's sim lands, get the suite
   running automatically on push — the economy will be the first system whose regressions aren't
   visible in a quick play.
5. **Steam go-to-market timing.** S10 treats Steam as packaging. Reality: the page should be live
   with a capsule and screenshots around content-complete-minus-6-months, because wishlists gate
   the launch algorithm; a demo (Next Fest) is the single best discovery lever for a game like
   this. That pulls a "screenshot-grade presentation floor" milestone from S10 back to ~S5–S6.
6. **Options/accessibility/input floor.** Rebindable keys, sensitivity, FOV, colorblind-safe
   standing colors, controller decision (yes/no — decide, don't drift). Cheap early, expensive
   late; currently nowhere.
7. **Performance measurement.** A 60fps budget exists with no instrument attached. One measured
   scene (densest system, full hostiles, market ticking) tracked from S2 onward.
8. **Balance telemetry.** For a 30h economy game you need to know credits/hour by activity or
   balancing S9 is guesswork. A local CSV log of money events, added in S2 when the market lands,
   costs nearly nothing and pays for itself at S9.

---

## 8. Recommended amendments

1. **Rewrite S1's spec around a real WorldClock.** Change: S1 delivers a clock that owns
   accumulated game time, ticks independently of the player ship and of world load/unload, exposes
   explicit "advance N hours" for away-time, persists in the save, and states its combat-lock
   policy; move wallet upkeep onto it. Why: everything S2+ hangs off this, and the current plan
   text ("reuse TimeScale") points at a component that is a speed knob, not a clock.
   **Severity: blocker.**
2. **Add per-station pricing inversion + station economic identity to S2's scope explicitly.**
   Change: S2 includes station-keyed (not system-keyed) price resolution, economic fields on the
   Station shape, and real station positions (ending the all-at-zero stacking). Why: the plan's
   market model assumes per-station stock that the current data layer cannot express; discovering
   this mid-S2 will look like scope creep when it's actually day one. **Severity: blocker.**
3. **Make trade-UI quantity control + visible reason line + one-line news ticker part of the S2
   gate, not S3.** Change: the "market fights back" gate is judged with a quantity selector and at
   least one visible "why" surface. Why: a sim the player can't see or can only poke 1 unit at a
   time will fail the feel gate for UI reasons, not sim reasons. **Severity: important.**
4. **Add the stability/equivalence/exploit acceptance tests to §5.6** (long-run stability,
   away-time equivalence, determinism, no same-station pump, no dead commodities, tick-time
   budget). Why: these are the specific ways economy sims die quietly. **Severity: important.**
5. **Author the ignition climax as a mission, not a transaction.** Change: S8 scope includes one
   authored crisis beat where a power contests the claim and the player's accumulated standings
   resolve it. Why: a 30-hour game cannot end on a buy button; the plan's own structural rhyme
   demands the powers respond. **Severity: important.**
6. **Add CI + a shared test-support harness to S1's deliverables.** Change: suite runs
   automatically on push; a support folder gains "build seeded world / advance N days" helpers.
   Why: S2 makes regressions invisible to play; the support folder is currently empty and every sim
   test will need the same scaffolding. **Severity: important.**
7. **Schedule the WalletService split (money/debt vs fuel vs hull-condition) before S6, and decide
   the "incident vs mission" question before S3.** Why: both are known collisions the plan
   currently walks into blind; deciding at a phase boundary is cheap, mid-phase is not.
   **Severity: important.**
8. **Add a service-lifecycle registry (or "resettable" convention) to S1.** Change: new persistent
   services register for career-reset instead of being hand-added to a name list. Why:
   MarketService/Ops state leaking between careers is a guaranteed, hard-to-notice bug under the
   current hand-maintained list. **Severity: important.**
9. **Insert external playtesting after S3 and a Steam-page/screenshot milestone around S5–S6; add
   an onboarding line item to S7.** Why: section 7, items 1, 2, 5. **Severity: important
   (playtesting), polish (page timing — but calendar-critical).**
10. **Add a money-event telemetry log to S2 and split S3 into two sub-slices (radiant+escort /
    events+news) with the gate after the second.** Why: S9 balance needs the data; S3 is the plan's
    most overloaded phase. **Severity: polish.**
11. **Fix the text-encoding corruption (UI strings + gates doc) as an S1 housekeeping item.** Why:
    it's player-visible and it will silently spread through copy-paste into new content.
    **Severity: polish.**

---

## 9. What NOT to change

- **The phase order.** Economy → activity → enforcement → ship → Ops → campaign → Holding is
  right. Resist any urge to start campaign writing early "because it's the fun part."
- **The standing system.** Complete, enforced in code, and the single most differentiated thing in
  the design. Do not let the campaign invent shortcuts around it.
- **The optional-save-section pattern and byte-determinism.** A reviewer might call the
  canonical-bytes rule over-engineering. It isn't — it's what will make economy desyncs findable.
- **The 10–12 commodity cap.** More goods is the most tempting and most wrong way to "deepen" the
  economy.
- **The content budgets and loud-failure loading.** The ceilings feel bureaucratic; they're the
  reason a months-long build won't drown in orphaned content.
- **The maturity language.** "Tech demo" is correct and keeping it correct is what stops the E1–E6
  "signed but thin" pattern from repeating in S-phases.
- **The 20-ship budget until measured.** Raise it with instruments, not vibes.
- **AGENTS.md discipline** (single-writer, EventBus-only, tunables in balance files, docs gated by
  the build). This is why the codebase can carry the plan at all.

---

## Top 5 things to fix in the plan before S1 coding starts

1. **Specify the WorldClock properly in S1** — owns elapsed time, survives world teardown, explicit
   away-time advance, saved, combat-lock policy stated; wallet upkeep moves onto it. (Amendment 1)
2. **Write the per-station inversion into S2** — station-keyed prices, economic fields and real
   positions on stations. The current data layer cannot express the plan's own market model.
   (Amendment 2)
3. **Move the sim's visibility into the S2 gate** — quantity selector, reason line, minimal news
   ticker — so the "market fights back" judgment isn't sunk by a 1-unit-per-click UI. (Amendment 3)
4. **Add the economy kill-shot tests to §5.6** — long-run stability, away-time equivalence, no
   same-station money pump, no dead commodities, tick budget. (Amendment 4)
5. **Commit to an authored ignition climax and an external-playtest checkpoint after S3** — the two
   decisions that most determine whether 30 hours ends with "oh shit" or with a receipt.
   (Amendments 5, 9)
