# Human gates

Elliot’s words only. Agents never sign these.

---

## S2 — Economy: can I plan a trade route, and does the market fight back?

**Criteria (plan §5.6):** "I can plan a trade route and feel the market fight back."
Judged with the quantity control and a visible reason on screen — **not** one-unit-per-click theatre.

**Build:** commit `3963d84` on `main` (docs follow-up `30f49d9`). Start a **New Game** —
the market only makes sense from a fresh career, and an old save has no market section.

### The route (one gate out, one gate back)

Every number below is what a fresh career should show before anything ticks.
You start docked at **Alpha Port** with 500 credits and a 20-crate hold.

1. **Alpha Port — buy Medical.** It costs **42**. The dock makes medical: 200 on the
   shelf against the 100 it wants, and the row says so. Credits are the limit here,
   not the hold — **Max buy** should offer about 11.
2. **Undock, fly to the gate, jump to Beta Drift.** Eight hours of game time pass
   while you travel.
3. **Beta Hub — sell the Medical.** It pays **59**. That is **+17 a crate**, roughly
   190 credits on the run.
4. **Same dock, buy Fuel Cells at 17.** Beta Hub makes them.
5. **Jump back to Alpha, but dock at Alpha Yard this time** — the *other* dock in the
   system. Fuel Cells sell at **25** there. **+8 a crate.**
6. **While at Alpha Yard, look at Alloy: it buys at 28.** At Alpha Port, one short
   flight away in the same system, Alloy buys at **56**. Same good, same system,
   double the price — because one dock makes it and the other needs it.

### What "the market fights back" should feel like

- **The price moves while you trade.** Drag the quantity up and the total on the
  button climbs *faster* than the unit price times the amount. Twenty crates cost
  more than twenty times the first crate, because you are eating through the shelf.
- **You cannot clear a dock out.** Push the amount past what is sensible and the row
  tells you which wall you hit — the shelf, your hold, or your wallet.
- **Flipping in place always loses.** Buy and immediately sell back at the same dock,
  in either order, and you are down. There is no free money anywhere.
- **Leaving and coming back matters.** Strip a shelf, jump away, come back: it has
  partly refilled — but slowly, and never all the way. The far, thin docks stay
  short, which is why they pay best.
- **The ticker moves.** One line at the top of the station screen naming what the
  sector is short of.

### What to report back

- **Pass or fail**, in your own words.
- Did you ever have to guess *why* a price was what it was, or did the row tell you?
- Was the quantity control comfortable, or fiddly?
- Did anything feel like a cheat, a dead end, or a number that made no sense?
- Ideas are welcome and go on the pile — they do not block the gate.

### Attempt log

- **2026-08-03** — S2 code complete. Lint green, 72 scripts / 677 tests green. Every
  headless criterion in §5.6 passes, including the 10,000-tick stability run, away-time
  equivalence, byte-deterministic market save, both money-pump directions, no dead
  commodities, and the tick budget (0.44 ms against 2.0 ms). **Gate open, not signed.**

### Attempt 1 — 2026-08-03

**Verdict: signed — S2 economy feel passes.**

**Elliot (verbatim / option selected):**

> S2 has been completed.
> Pass — S2 signed, start S3a

**Notes:** Feel gate closed. S3a (radiant work surface) authorized. S3 human gate
(“not a thin menu loop”) remains after S3b.

---

## A1 — Flight feel

**Criteria:** basic flight is not nauseating and is controllable.

### Attempt 1 — 2026-07-30

**Verdict: not signed — iterate.**

**Elliot (verbatim):**

> Basic flight is controllable and it is smooth, but maybe too responsive. It is a little bit nauseating

**Response:** softened ship turn/accel/throttle/strafe; pulled camera back; slowed position + look lag; slightly narrower FOV. Retune in `BalanceFlight` + `hull_courier`. Re-play for attempt 2.

### Attempt 2 — 2026-07-31

**Verdict: signed — A1 flight feel passes.**

**Elliot (verbatim):**

> Working better now. i think it is something we will need to fine tune over time as we get more visual assets into place. I think it is good enough to move on with testing.

**Notes:** Fine-tune flight/camera later as art lands; not a reopen of A1. Phase A1 closed.

---

## A4 — Personal recovery feel

**Criteria:** recovery path feels like a meaningful, earned lever rather than a menu grind.

### Attempt 1 — 2026-07-31

**Verdict: signed — A4 recovery feel passes.**

**Elliot (verbatim):**

> That worked. We are good to go.

**Notes:** Console offer text was opaque at first (`recovery status`/`list`); fixed to plain-English JOB AVAILABLE before sign-off. Phase A4 closed.

---

## Final Alpha — Core fantasy

**Criteria:** the core fantasy is legible and worth expanding.

**What that means in play (plain):**

- Different places treat you differently (status line, fees, NPC traffic, controllers).
- Sticky negative standing is real, and there is one personal recovery foothold without the debug console.
- You can fly a short session: dock, take a job, jump, turn in, trade, fight, recover — without needing console for the fantasy.

**Signed only by Elliot** after Path C B0–B5 and the decision-bar checklist in `Alpha/ALPHA_DECISION_BAR.md`. Agents never mark this signed.

### Final Alpha play script (cold launch — no console)

**Goal:** one continuous session (~30–60 min) that touches every decision-bar row enough to judge.

#### 0. Boot

1. Run the main scene (project main).
2. You should see the **DRAYWAR** main menu: **New Game / Continue / Quit**.
3. Click **New Game**.
4. A short **controls tip** appears (mouse aim, WASD, F dock/jump, Space fire, Esc pause). Click **Got it**.
5. You **start already docked** at Alpha Port (storyboard entry — berth in the starter ship). Station menu is open. Not free-flying into combat.
6. Note HUD: **SYSTEM**, **STANDING**, **CREDITS**, **FUEL**, **HULL**, **NAV** (HERE + GATES). Alpha is patrolled government space — **no pirates on undock**.

#### 1. Flight + undock (place treatment)

7. Station menu: title + flavor line, sections **Jobs / Services / Trade / Contacts**, **Undock**.
8. Read the **status / standing** line (HUD + docked strip). Alpha is **Reach Authority**, patrolled — fees higher, more NPCs, **safe airspace**.
9. **Esc** → pause: Resume, Captain sheet, Save, Load, Quit to menu. Open **Captain sheet** — credits, fuel, hull, cargo, local standing, job line. Close.

#### 2. Job loop across systems

10. At Alpha Port **Jobs**: accept the courier (**Accept job → Beta Hub**). HUD shows **JOB … → Beta Hub**.
11. **Undock** into safe Alpha space. Fly to the **gate** (blue / labeled). **F** to jump when in range (needs fuel). Watch **SYSTEM** and **STANDING** change on arrival (**Beta Drift**, contested Syndicate). Contested/lawless systems may have a thin pirate.
12. Dock **Beta Hub**. **Turn in job**. Credits and Reach standing should move. Note flavor / fee difference vs Alpha.
13. Optional second hop: take Beta’s return job to Alpha, or jump **Gamma Fringe** (lawless, thinner traffic). Dock **Gamma Outpost**. Feel density and standing controller change.

#### 3. Trade contrast (money loop)

14. At a station, open **Trade**. Buy **Grain** at **Alpha Port** (cheaper buy).
15. Jump to **Gamma**, dock, **Sell Grain** — sell price should be **higher** than Alpha’s sell (fringe pays for grain).
16. Optional: buy **Scrap** at Gamma, sell at Alpha (scrap pays better at industry). Watch credits on HUD / sheet.

#### 4. Thin combat

17. Jump to **Beta or Gamma** (not Alpha). A **red hostile** spawns **out near the gate / open space** (not on the undock pad). Station airspace is a **safe zone**; Alpha undock stays pirate-free.
18. **Tab** locks the target. HUD shows **name, range, and target HULL %**. Aim the mouse reticle at the **red lead diamond**; **Space / LMB** fire travel bolts (no auto-hit on lock).
19. Enemy shots **travel** — strafe / afterburn can dodge. Your **HULL** drops only if their bolts hit. Kill if you can; or leave.
20. Contested kills need witnesses/evidence per standing law for attribution. Lawless default is quieter.
21. If your hull hits zero you are **crippled** (cannot fly). Dock + **Repair ship** restores. Refuel as needed.

#### 5. Sticky hole + recovery foothold (no console)

22. At Alpha, take and **Abandon** courier jobs a few times (or fight enough) until Reach standing is clearly bad (Unfriendly / Hostile / sticky). Status moment and fees/treatment should feel worse.
23. Dock Alpha Port. Contacts section should become **Recovery foothold** with a hint naming **Dockhand Mendi**.
24. **Ask favor of Dockhand Mendi** several times until personal trust opens **Talk to Dockhand Mendi**.
25. Accept recovery work → **Complete recovery work — Dockhand Mendi** (stipend + personal climb). Repeat steps as offered. Entity standing climbs slowly (sticky positives).

#### 6. Save / continue

26. **Esc → Save**. **Quit to menu**.
27. **Continue** — same system/career state (credits, standing, cargo if any, job if active).

#### 7. Judge (Elliot only)

28. Can you answer: *Is this worth building into a beta / full game?*  
   If it still feels only like a tech demo, **refuse** the gate. If core systems are present and the fantasy is legible enough to decide, sign below on a new Attempt.

**Console is optional** (debug standing/save). Do **not** need it for the script above.

### Attempt 1 — 2026-07-31

**Verdict: not signed — not Alpha yet.**

**Elliot (verbatim):**

> This isn't an Alpha. This is a rudimentary technology demonstrator

**Notes:** Mechanical A5 criteria (systems, money, normal-play levers, no console required for the loop) may hold as a tech slice. Final Alpha fantasy sign-off refused. Iterate until the play feels like a prove-it game, not a systems demo. Do not advance to full-plan expansion on this verdict.

### Combat feedback (pre–Attempt 2) — 2026-07-31

**Not a Final Alpha verdict.** Combat-specific refuse while Path C code was otherwise complete. Blocks gate retry until the Combat Fairness Pass lands.

**Elliot (verbatim intent):**

> The aiming does not work. You can't "dodge" shots. You do lock on to the enemy ship, but you can't see anything about it. At a minimum you should have an idea of hull %. … Combat is not good right now.

**Binding fix list (Combat Fairness Pass):**

1. **Aim** — lead pip and mouse aim must match where bolts go (locked aim depth).
2. **Dodge** — enemy shots must travel; motion must matter (no instant hitscan damage).
3. **Target info** — locked target shows live **hull %** (name + range at minimum plus hull).
4. Fight stays thin Alpha (one hostile type) but must feel like a **real exchange**, not a damage timer.

**Elliot’s Alpha bar (clarified same session, verbatim intent):**

> To me an actual Alpha is a playable game that has all of the core systems in and working. It has actual graphics and lets you do more than fly around a black screen with colored shapes. It has a minimal amount of content done so proper testing and vetting can be done. The current version has less than the basics.

**Binding bar for re-gate (plain):**

1. **Core systems in and working** — not stubs you have to imagine around  
2. **Actual graphics** — not black space + colored boxes only  
3. **More than flying shapes** — a real play session, not a tech demo  
4. **Minimal content for real vetting** — enough places/jobs/people to test the fantasy properly  
5. **Current build is below that bar** — less than the basics  

### Path C — Hybrid (Elliot, same session)

**Choice:** C (hybrid). Not full game. Enough game to decide if full/beta is worth building.

**Elliot (paraphrase + intent locked):**

- Does not need full game.  
- Needs enough to decide if building the full game is worth it.  
- Does **not** need full graphics and sounds.  
- **Does** need menu, character sheet, job tracking, trade, combat, etc.  
- Not at 100% — good enough to decide on beta.  

**Authority doc:** `Alpha/ALPHA_DECISION_BAR.md` (checklist must be ratified before mass build).

### Attempt 2 — 2026-07-31

**Verdict: signed — Final Alpha passes. Expand toward full/beta.**

**Elliot (verbatim):**

> It is working now. Lock on worked and every just doesn't just hit. Aiming matters. A kill causes a little explosion and you move on. Everything we've built seems to work. Flying still needs fine tuning, but that is something that could be done later. This is still more a a playable technology demonstrator than an alpha though. That said, we should make this more and really look at pushing towards the full build.

**Formal call (same session, after clarification):** **Signed — expand toward full/beta.** Residual polish (flight fine-tune, art, content depth) is later work, not a reopen of this gate. Combat Fairness Pass re-play accepted.

**Next priorities (Elliot, multi-select — all four):**

1. Presentation (art / world feel)
2. More playable content
3. Deeper core systems
4. Start full-game roadmap work

**Notes:** Path C Alpha closed. Do **not** re-open Final Alpha for residual demo feel. Destination / expansion planning is authorized. Sequence the four priorities; do not treat Destination Phase 0 as greenfield — Alpha already proved standing, flight, combat shell, and save.

---

## E1 feel — Legible Sector

**Criteria:** Does this feel like a **small game** worth another phase of expansion?  
Not a re-open of Final Alpha. Refuse → iterate E1 list only. Sign → open roadmap E2+.

### Play script (cold, ~30–45 min)

1. **New Game** — docked Alpha Port. Note sky/silhouettes (not pure black boxes).
2. **Undock** — freighter shape, station modules, second station **Alpha Yard** visible off-offset. Jump **Beta**.
3. **Beta Spit** — dock secondary; jobs board has courier + **bounty**. Accept bounty → undock → kill hostile → turn in.
4. **Trade** — buy grain at Alpha, sell Gamma; or scrap/ore Gamma → Alpha. Watch credits.
5. **Standing teeth** — abandon jobs or fight until Unfriendly/Hostile at Reach. Re-dock (recovery if needed): higher fees, repair/trade friction when hated. Mendi recovery still works.
6. **Save / Continue** once.
7. Judge: small game worth E2, or still tech demo?

### Attempt log

#### Attempt 1 — 2026-07-31

**Verdict: signed — E1 feel passes.**

**Elliot (verbatim):**

> I've already signed off. Take the build through as many phases as you can. Only stop if I need to make a decision. I'll test systems when they are built.

**Also (combat/aim slice earlier same day):**

> Much better. We are good on this section

**Notes:** Roadmap approved to open E2+. Formal mid-play script not re-run in this session; Elliot authorized phase drive and deferred testing to when systems land.

### Play fixes (pre–formal Attempt) — 2026-07-31

**Absorbed into Attempt 1.** Combat/aim/job path fixed before formal sign.

**Fixes in that slice:** Accept-job crash (free mid-pressed); free-fire reticle (camera ray); bounty prey ensure (near player if none in lock range).

---

## E2.7 — Combat & hull feel

**Criteria:** Does combat + the two-hull interlock feel like **Destination combat identity** worth expanding (E3+)?  
Not a re-open of E1 or Final Alpha. Refuse → iterate E2 list only. Sign → open roadmap E3.

**What that means in play (plain):**

- Two pirate fight shapes read differently (Skirmisher vs Gunboat).
- Security-aware space: Alpha safe on undock; Beta/Gamma have hostiles; density differs.
- Kill feedback tells you when standing moved vs when it did not.
- Hauler vs Fighter trade-off is real (cargo vs guns); buy once, switch docked only, blocked when cargo too heavy.
- Traffic feels busier (multi-ship systems) without the game falling apart.

### Play script (cold, ~30–45 min)

1. **New Game** — docked Alpha Port on the **Hauler**. Note captain sheet hull name.
2. **Undock Alpha** — busy freighter traffic, **no pirates**. Fly, re-dock. Safe government space.
3. **Jobs** — accept courier to Beta. Jump. Note denser/contested feel + skirmisher ambient.
4. **Fight a Skirmisher** — Tab lock, lead pip, strafe bolts. Kill. Read HUD toast (attributed or not — witnesses matter in contested).
5. **Bounty (optional)** — at Beta Spit or board with bounty: accept → ensure prey in lock range → kill → turn in.
6. **Gamma** — jump lawless. **Two gunboats** (meaner). Traffic thinner freighters, harder fight. Kill one; note toast (lawless often “not recorded”).
7. **Hull buy** — earn/save to **1000** credits. Dock Services: **Buy Fighter**. Switch to Fighter (empty hold or light cargo). Silhouette/combat feel should differ.
8. **Cargo block** — switch back to Hauler, load grain past Fighter hold size, try Switch to Fighter — should refuse until you sell down.
9. **Fighter fight** — undock Fighter in Beta/Gamma; one exchange should feel snappier than Hauler.
10. **Save / Continue** once with Fighter owned.
11. Judge: combat + hull law worth E3, or still not Destination identity?

### Attempt log

#### Attempt 1 — 2026-07-31

**Verdict: signed — E2.7 combat & hull feel passes.**

**Elliot (verbatim):**

> Sign all three now

**Also (same session, drive-past order):**

> I've already signed off. Take the build through as many phases as you can. Only stop if I need to make a decision. I'll test systems when they are built.

**Notes:** Code-complete E2 suite green before sign. Formal cold script not re-run in-session; Elliot authorized clearing open feel gates after phase drive. Refuse later if play finds a fix list.

---

## E3.6 — Economy pressure feel

**Criteria:** Do bills, risk, and the thin debt hatch force real money choices?  
Not a re-open of E2. Refuse → iterate E3 list only. Sign → open roadmap E4.

**What that means in play (plain):**

- Sitting in free-fly burns credits; docked life is free of that drain.
- Fuel and jumps still cost; idle multi-hop travel without earning loses money vs taking a courier.
- Broke is not dead — Free Haulers loan at Services once; repay or live with garnish.
- Munitions are illegal at Reach docks (fine + standing + seize); legal elsewhere.
- Smuggle jobs pay more because of that risk; Hauler can take them, Fighter hold cannot.
- Captain sheet and HUD show money, fuel, hull, debt, and active job clearly.

### Play script (cold, ~30–45 min)

1. **New Game** — docked Alpha Port. Open **Captain sheet** (pause or menu): credits **500**, fuel full, hull full, **Debt — none**, no job.
2. **Undock Alpha** — fly for ~30–60s. Watch **credits fall** on HUD (LOW warn near 50). Re-dock — drain stops. Note dock fee bite.
3. **First courier** — Jobs: accept courier → Beta. Jump (fuel drops). Deliver / turn in. Credits up. Compare “working” vs step 2 idle.
4. **Pressure without earning (optional feel)** — undock, free-fly and/or hop without taking pay. Confirm you are poorer for it; still not stuck if you re-dock for a job.
5. **Broke escape** — if not broke yet, spend on refuel/fees or free-fly down. At Services: **Borrow 400 (owe 480)**. Sheet shows debt. No second borrow while open.
6. **Garnish** — take and complete a job with debt open. Pay is less than full (25% toward debt); remainder still lands in credits. **Repay** at Services when you can; debt clears; borrow available again.
7. **Contraband** — buy munitions at **Beta** (legal). Dock **Alpha** with them still held → fine, Reach standing hit, munitions seized. Try trade at Alpha: munitions **RESTRICTED**.
8. **Smuggle** — at Beta (Hauler): accept smuggle → Gamma. Cargo loads. Do **not** stop at Reach with the load if you want the pay. Turn in at Gamma Outpost for **240**. (Fighter: confirm accept refuses — hold too small.)
9. **Save / Continue** once with debt and/or cargo state if interesting.
10. Judge: do bills + risk force choices worth E4, or still optional money?

### Attempt log

#### Attempt 1 — 2026-07-31

**Verdict: signed — E3.6 economy pressure feel passes.**

**Elliot (verbatim):**

> Sign all three now

**Also (same session, drive-past order):**

> I've already signed off. Take the build through as many phases as you can. Only stop if I need to make a decision. I'll test systems when they are built.

**Notes:** Code-complete E3 suite green before sign. Formal cold script not re-run in-session; Elliot authorized clearing open feel gates after phase drive. Refuse later if play finds a fix list.

---

## E4.7 — Opening feel

**Criteria:** Does New Game feel like a career starting — picks with teeth, annexation landing, and a playable first dock — without softlocks or dead ends?

Not a re-open of E2/E3. Refuse → iterate E4 list only. Sign → E4 closed; roadmap continues.

**What that means in play (plain):**

- Create screen makes three picks matter (standing / debt teeth visible before Confirm).
- Annexation beat lands the corridor-claimed story without rewriting the map (Alpha was already Reach).
- You wake docked with status/standing that match your path; Captain sheet shows Origin / Trade / Mark.
- Continue skips create + annexation; save/load keeps path lines.
- Two recovery footholds exist (Mendi at Reach, Jax at Drift) without needing the console.
- No softlock: default-ish path is playable; debt start has a loan; ugly standing still has a recovery contact path.

### Play script (cold, ~25–40 min)

1. **Main menu** — see **DRAYWAR** + tagline. **New Game**.
2. **Create** — Confirm disabled until all three columns picked. Read teeth on Smuggler vs Ex-Navy (different). Cancel once → back to menu clean; **New Game** again.
3. **Pick a path with teeth** — e.g. Periphery-born + Merchant marine + Clean (or Core + Navy + Clean). Confirm.
4. **Annexation** — title about the corridor claimed; body that Reach runs the pad; baggage line shows your standing. Continue.
5. **Tip → docked** — Got it. Station menu at Alpha Port. Read flavor (Reach / pad). HUD standing matches path.
6. **Captain sheet** (Esc → Captain sheet) — Origin / Trade / Mark lines match your picks. Credits/fuel/hull sane. Close.
7. **Optional debt path (second New Game)** — Mark **Debt**. Confirm → annexation → dock. Sheet shows Free Haulers debt (~480 owed) and higher credits.
8. **Optional ugly path** — Cancelled + Smuggler. Confirm. Reach standing worse; sheet still shows path. Undock/re-dock ok. At **Beta Hub** Contacts, **Jax** recovery path exists when Friendly personal; at Alpha, **Mendi** still the Reach foothold.
9. **Save / Quit to menu / Continue** — Continue must **not** re-show create or annexation. Sheet still shows Origin/Trade/Mark after load.
10. Judge: does opening feel like a career start worth keeping, or still a menu gluing onto Alpha?

### Attempt log

#### Attempt 1 — 2026-07-31

**Verdict: signed — E4.7 opening feel passes.**

**Elliot (verbatim):**

> Sign all three now

**Also (same session, drive-past order):**

> I've already signed off. Take the build through as many phases as you can. Only stop if I need to make a decision. I'll test systems when they are built.

**Notes:** Code-complete E4 suite green before sign. Formal cold script not re-run in-session; Elliot authorized clearing open feel gates after phase drive. Refuse later if play finds a fix list. E4 phase closed.


---

## E5.7 — Content scale feel

**Criteria:** After a long session, does the sector feel big enough to keep playing — routes, places, and map — without needing Ops or Holding yet?

Not a re-open of E2–E4. Refuse ? iterate E5.1–E5.6 only. Sign ? E5 closed; post-E5 roadmap (Ops later).

**What that means in play (plain):**

- Six systems on a **branched** map (not a longer dead line).
- You can open a **sector chart** and see where you are and where gates go.
- Jobs and/or trade pull you across **multiple hops** and sometimes to **secondary docks**, not only the three old hubs.
- Status moment still reads local controller on each system enter.
- Opening cast (E4) still works; Continue still skips create/annexation.
- Broke / debt / combat laws from E2–E3 still hold — scale did not delete teeth.

### Play script (cold, ~60–90 min)

1. **New Game** — create path (any solid path), annexation, tip, docked Alpha Port. Note standing.
2. **Open map / NAV chart** — confirm all six systems and gate links; current = Alpha.
3. **Short loop** — undock, gate to Beta, dock Hub or Spit. Status moment on enter. Re-check map current = Beta.
4. **Branch** — from Beta take a gate toward **Delta or Epsilon** (not only Gamma). Dock a **new** system. Read flavor + status.
5. **Logistics** — accept a job that is either multi-hop or ends/starts at a secondary/new dock. Complete or deliberately abandon after cargo loads (both teach the graph).
6. **Far spur** — reach **Zeta** (or deepest new system) at least once. Trade or board once there if stocked.
7. **Law contrast** — if path allows: touch a patrolled new Reach dock and a lawless spur; ambient/hostiles still match policing.
8. **Save / Quit / Continue** — land in a non-Alpha system if possible; Continue restores place and does not re-show opening.
9. **Optional pressure** — one E3 money beat (upkeep, loan, or contraband) so scale did not make economy optional.
10. Judge: multi-hour sector worth keeping, or still a thin corridor with extra names?

### Attempt log

- **2026-08-02** — E5.1–E5.6 code complete (lint green, GUT 507/507). Gate open for Elliot play.
- **2026-08-02 (pre-play)** — **Blocked.** Elliot: opening screen pinned, bottom runs off viewport, no scroll — cannot start playing. Fix before E5.7 attempt can proceed.
- **2026-08-02 (fix)** — Create screen: option columns scroll; Confirm/Cancel stay pinned. Annexation: body scrolls; Continue pinned. Panels clamp to window. Gate open again for play.

### Attempt 1 — 2026-08-02

**Verdict: signed — E5.7 content scale feel passes.**

**Elliot (verbatim intent):**

> Signed, move on

**Notes:** Opening scroll fixed before play. Follow-on feedback (systems too close, no collision, traffic not attackable, pirates-by-gate, wants real star systems) is **not** an E5 reopen — opens **E6 Lived-in space**. Flying was fine.

---

## E6.6 — Lived-in space feel

**Criteria:** After a session in open space, does a system feel like a **place** — solid, spaced, sky, ships that matter, density by law — enough to keep expanding, without needing Ops yet?

Not a re-open of E1–E5. Refuse → iterate E6.1–E6.5 only. Sign → E6 closed; Ops still later unless re-prioritised.

**What that means in play (plain):**

- Soft bump off stations/ships; ramming a station hurts more than clipping a small freighter.
- Pad and gate are a real transit, not the same prop cluster.
- Sun / planets / belt make systems look different.
- Freighters and patrols can be locked and shot; standing reacts where law says.
- Patrolled feels busier and safer near the pad; lawless meaner; pirates are not default gate greeters in government space.
- Flying still controllable.

### Play script (cold, ~45–75 min)

1. **New Game** — create path, annexation, tip, docked Alpha Port.
2. **Undock Alpha** — note sky (sun/planet). No pirates on the pad. Traffic visible.
3. **Fly toward gate** — should take a real transit. Soft-bump a station structure if you scrape (damage scales).
4. **Jump to Beta** — contested ecology: hostiles not camping undock; sky differs if layout says so.
5. **Lock a freighter** — fire or ram; note standing feedback vs pirate kill.
6. **Lawless spur** (Gamma or Zeta) — meaner placement; density contrast vs Alpha.
7. **Secondary dock** — fly to a second station in a dual-dock system; distance should read.
8. **Save / Quit / Continue** — still skips opening; state sane.
9. Judge: lived-in enough to keep going, or still a toy box with paint?

### Attempt log

- **2026-08-02** — E6 plan locked (`docs/BETA_E6_LIVED_IN_SPACE.md`). Gate opens after E6.5.
- **2026-08-02** — E6.1–E6.5 code complete (lint green, GUT 571/571). Gate ready for human play. **Not signed.**

### Attempt 1 — 2026-08-02

**Verdict: signed — E6 closed as a phase.** Technical place-pass accepted so expansion can continue. **Not** a claim that the product feels rich.

**Elliot (verbatim / paraphrased from session, product call same day):**

> I have played and E6 is technically closed. It just still feels super thin. I wouldn't even call what we have an Alpha or Beta. If anything it is a super early tech demonstration Alpha.

**Notes (product, not E6 reopen):** Maturity reframe + Steam product bar raised same session — see `docs/PRODUCT_DIRECTION.md`. Campaign through Holding → sandbox; real economy sim; 30h / 80h targets; “space Skyrim.”

---

## S3 — Living activity density: not a thin menu loop

**Criteria (plan):** in a 60–90 min free session, the player finds varied work
without exhausting only a fixed board. Gate after **S3b** (S3a alone is not enough).

**Build:** S3b complete (`8d5c331` and later). Start a **New Game**. Do not sign
from headless green alone — this is a feel gate.

### How to find radiant vs incidents

| Activity | Where | What you do |
|----------|--------|-------------|
| **Hand / radiant board jobs** | Dock → station **Jobs** board | Accept a haul, bounty, escort, or smuggle row. Boards restock on the world clock (jump away and come back; the list changes). |
| **Distress** | Free flight in a system | A toast/prompt: freighter in trouble. **Help** or **Ignore**. Help with no active job → short rescue haul mission. Help while already on a job → small credit reward; your mission stays. |
| **Intercept** | Free flight | Hostile pressure prompt. Submit (pay a cut) or resist (small payoff). Does **not** need the mission slot. |
| **Customs light** | Patrolled space (e.g. Alpha) with **restricted cargo** in hold (e.g. munitions under Reach) | Scan prompt. Cooperate → fine/seize using existing contraband law; flee → walk away. If you cooperated, the **same undocked trip** will not fine you again at the next dock for that load. |
| **News** | Station ticker **and** flight toast while undocked | Shortage/glut, patrol chatter, and echoes of real incidents. |
| **Traffic purpose** | Look at freighters in space | Some approach pads and leave (dock cycle). When a dock is short, a freighter may push toward that station. |

Console / debug (if needed for the brief, not required for pass): incident respond paths are driven from service APIs in headless tests; in play, prompts surface on the flight HUD toast.

### What "thin menu loop" failure looks like

Fail the gate if any of these are true for you after ~an hour:

1. **Only the board** — you never get work or pressure that is not a dock menu row (no space events, no reason to undock except travel to turn in).
2. **Board goes dead** — after a few accepts the list feels empty forever and restock is invisible.
3. **Incidents feel like the mission slot** — helping a distress always blocks or steals your current job, or you cannot help while employed.
4. **Space is wallpaper** — freighters never look like they are going somewhere; news never names a real shortage or incident you just saw.
5. **Double-punish customs** — you cooperate with a scan in space, then the same load is seized again the moment you dock with no undock in between.

Pass when: you can chain board work **and** space incidents **and** see the sector talk (news/traffic) without the session collapsing into "dock → click job → undock → dock".

### What to report back

- **Pass or fail**, in your own words.
- Did you find work that was **not** on the station board?
- Did distress-with-a-job-active feel fair?
- Did customs / restricted cargo feel readable?
- Anything that felt like a cheat, a dead end, or noise?

### External playtest (after this gate)

Do **not** call the 30h career claim honest until strangers touch the build.
Plan who, how many, and what is measured (time-to-first-fun, did they undock for
non-board reasons, did they quit at the menu loop). Agents do not run that plan
for you — schedule it after you sign S3.

### Attempt log

- **2026-08-03** — S3b code complete. Headless proxies for varied activity classes
  green (717 tests). **Gate open, not signed.**
- **2026-08-03** — Elliot approved S3 in session ("I approve S3"). **Gate signed.**

**Verdict: signed — S3 living activity density passes.**

**Signed by:** Elliot  
**Date:** 2026-08-03  
**Verbatim:**
> I approve S3

**Notes:** Feel gate closed. S3 phase done. External stranger playtest still to schedule (not a code gate). S4 authorized.

---

## S4 — Jurisdictional identity: crime feels local, recovery still works

**Criteria (plan):** crime in patrolled space is not the same as crime in
lawless space; heat/pressure stays per-Entity (no global wanted bar); status
moment still shows local controller standing; personal recovery still works.

**Build:** S4 code complete. Start a **New Game**. Do **not** sign from headless
green alone — this is a feel gate. **Signed 2026-08-03** (Elliot: approved).

### How to raise heat / feel the difference

| Action | Where | What you should feel |
|--------|--------|----------------------|
| **Kill with witnesses / patrols** | Alpha (patrolled, Reach) | Standing falls with Reach (existing law). **Heat** rises on Reach. After enough heat, intercepts come more often; high heat can force a **patrol response** prompt ("you are wanted here"). Keys **[1] resist** / **[2] submit**. |
| **Flee customs** | Alpha free flight with munitions (or other Reach-restricted cargo) | Toast: customs scan. **[1] cooperate** / **[2] flee**. Flee raises Reach heat without the dock fine path. |
| **Cooperate customs** | Same | Fine/seize via existing contraband law; same-trip dock skip still applies. Does **not** use the flee-heat path. |
| **Crime in Gamma** | Gamma (lawless, Fringe) | Kills without evidence often **not** attributed. Even when attributed, **heat does not rise** for lawless space — law has no teeth. Pressure/hunt flags stay off in Gamma even if some Entity has high heat numbers from elsewhere. |
| **Status moment** | Jump or dock | Local controller standing line still shows on system/station entry. Must not vanish. |
| **Recovery** | Dock + talk / console recovery | Mendi (Reach), Jax (Drift), **Wren (Free Haulers)**, **Kade (Fringe)** — four chains. Bootstrap Friendly personal, accept deniable first step, complete. Betrayal of a contact also nicks their network personally (small hit; does not close the network). |

### What failure looks like

Fail the gate if any of these are true for you:

1. **Global wanted** — every system feels equally "hot" after one crime; Alpha and Gamma play the same.
2. **Lawless has teeth** — Gamma starts hunting you with patrol-response pressure the way Alpha does.
3. **Status moment gone** — system/station entry no longer shows local standing.
4. **Recovery broken** — cannot open or complete a deniable step on Wren or Kade (or the old Mendi/Jax paths).
5. **Customs unreadable** — no way to answer the scan without a debug console ([1]/[2] missing or useless).

Pass when: Alpha crime makes Reach care and press you there; Gamma stays soft; standing status still reads; recovery still gives a climb path.

### What to report back

- **Pass or fail**, in your own words.
- Did Alpha vs Gamma feel different after crime?
- Did patrol response / customs [1][2] feel readable?
- Did status moment and recovery still work?

### Attempt log

- **2026-08-03** — S4 code complete (EnforcementService heat, customs loop keys,
  recovery budget 4, network betrayal lite). Headless tests added. **Gate open,
  not signed.**
- **2026-08-03** — **Signed pass** (Elliot: “S4 approved”). Jurisdictional identity
  accepted; S5 authorized.

---

## S5 — Ship fantasy: outfitting and long careers, not bored

**Criteria (plan):** both careers (hauler-first, fighter-first) feel viable into
mid-game; outfitting is a real money sink and identity choice; ship fantasy is
not “same starter forever.”

**Build:** S5 Session A code complete (weapons/equipment, station Outfitting,
loadout save). Start a **New Game**. Do **not** sign from headless green alone —
this is a feel gate. **Signed 2026-08-03** (Elliot: “I'm good. Continue”).

### Playtest brief

1. **New Game → dock at Alpha Port.** Open station. Find **Outfitting** under
   Services (after Buy Fighter / Switch hull).
2. **Hauler path:** install a **cargo rack** (or straps). Confirm hold feels
   bigger when trading. Optionally put on light armor. Fly a short trade or job.
3. **Earn and buy Fighter** (Services). Switch hulls. Note: Fighter hold is tiny;
   cargo racks that are hauler-only should not fit the fighter fantasy.
4. **Fighter path:** install a mid/high weapon (Pulse → Interceptor when you can
   afford it). Dogfight a skirmisher in contested/lawless. Stock hauler guns
   should feel weaker than a geared fighter.
5. **Money sink:** top weapons + fighter purchase should clear several jobs’
   worth of credits — progression spends, not infinite wallet.
6. **Save/load** once with a loadout; gear should still be there.
7. **Screenshot honesty:** ships are still code-mesh gray-box
   (`docs/S5_SCREENSHOT_FLOOR.md`). Gate is about *fantasy of upgrade*, not art.

### What failure looks like

1. Outfitting missing, broken, or only on one hull with no reason.
2. No meaningful difference between stock and upgraded weapons.
3. Hauler and fighter feel the same job (no cargo vs guns trade).
4. Gear disappears on load, or installs free / without dock.
5. You are bored within an hour because there is nothing to spend on for the ship.

Pass when: you want the next gun or rack; hauler and fighter pull different
play; spending on the ship feels like progress.

### What to report back

- **Pass or fail**, in your own words.
- Did Outfitting read in the station menu?
- Hauler cargo vs fighter guns — did both careers feel real?
- Any broke / stuck / “why can’t I install” moments?

### Attempt log

- **2026-08-03** — S5 Session A code complete (12 weapons, 10 equipment, install
  / remove, loadout save, PerfProbe, screenshot floor notes). **Gate open, not
  signed.**
  WalletService split (Session B) was required before S6 — not part of this
  feel gate.
- **2026-08-03** — Adversary fix: `apply_section` always emits `on_loadout_changed`
  so save/load re-arms flight stats when the active hull id is unchanged;
  StationMenu listens; cargo-rack uninstall refuses overweight hold.
- **2026-08-03** — **Signed pass** (Elliot: “I'm good. Continue”). Ship fantasy
  accepted; WalletService split (Session B) authorized before S6.
- **2026-08-03** — Session B landed: WalletService / FuelService /
  HullConditionService; single save key `wallet` via CareerSave merge.

**Verdict: signed — S5 ship fantasy passes.**

**Signed by:** Elliot  
**Date:** 2026-08-03  
**Verbatim:**
> I'm good. Continue

**Notes:** Feel gate closed. Session B (wallet split) **done** 2026-08-03 — S6 unblocked on wallet.

---

## S6 — Ops feel: progression past solo courier

**Criteria (plan):** player can run a small operation and feel progression past
solo courier. Hire/fire, upkeep, orders, warehouse, standing-gated charters,
save, market hauls.

**Build:** S6 code complete on `main` (after this session’s commit). Start a
**New Game**. Do **not** sign from headless green alone — this is a feel gate.

### Playtest brief

Full steps: **`docs/S6_OPS_PLAYTEST.md`**.

Short path:

1. New Game → dock Alpha Port. Need credits (~800 hire) and **Friendly** with
   Reach Authority (hire gate). Console if needed: `credits set 5000` + standing.
2. Station **Operations** — hire hauler; set haul order; advance time / jump so
   a leg resolves; check wallet and that fleet line shows upkeep.
3. Warehouse deposit/withdraw a few crates; save/load once.
4. Hire second ship (escort); third hire should refuse. Fire one — upkeep drops.
5. Optional: zero wallet, wait for breach (3 unpaid hours) — standing hit + ship
   released.

### What failure looks like

1. Operations missing or dead buttons.
2. Hire ignores standing / max 2.
3. Haul never moves money or markets (or steals personal mission slot).
4. Warehouse or fleet lost on load.
5. Still feels like solo courier with a useless menu.

Pass when: retainers + warehouse + abstract haul feel like a small company, not
a second menu toy.

### What to report back

- **Pass or fail**, in your own words.
- Did Operations read in the station menu?
- Haul / warehouse / upkeep — did any of it feel real?
- Escort is label-only this phase — did that bother you?

### Attempt log

- **2026-08-03** — S6 code complete (OperationService, station Ops UI, save
  `operation`, 18 ops tests after adversary harden). Lint green; full suite
  green. **Gate open, not signed.**
- **2026-08-04** — **Signed pass** (Elliot: “Signed.” Full S7 authorized this
  chat unless stronger model required). Ops feel accepted; S7 authorized.

**Verdict: signed — S6 Ops feel passes.**

**Signed by:** Elliot  
**Date:** 2026-08-04  
**Verbatim:**
> Signed. This chat should run it all unless a stronger model is required.

**Notes:** Feel gate closed. S7 campaign framework + Acts I–II authorized in
the same session (framework + content unless Content-tier switch forced).

---

## S7 — Story / freeroam + cold start

**Criteria (plan):** new player can follow spine ~half campaign without console;
cold start does not refund-bait in the first 2h; freeroam still works around spine.

**Build:** CampaignService + 9 Act I–II spine beats, Story station section,
Journal (pause), `campaign` save section. Boards exclude spine. Commit `4ca17dc`.

**Playtest brief:** **`docs/S7_COLD_START_PLAYTEST.md`**

### Attempt log

- **2026-08-04** — S7 code complete (framework + content). Lint green; full
  suite green (779 tests). **Gate open, not signed.**
- **2026-08-04** — **Signed pass** (Elliot: “Pass”). Story / freeroam + cold
  start accepted; S8 authorized when he says go.

**Verdict: signed — S7 story / freeroam + cold start passes.**

**Signed by:** Elliot  
**Date:** 2026-08-04  
**Verbatim:**
> Pass

**Notes:** Feel gate closed. S7 phase done. Next phase S8 (Holding + Act III)
when authorized — do not start until he says so.

---

## S8 — Endgame feel + structural rhyme

**Criteria (plan):** debt clear + Holding ignition (crisis resolved) ends campaign;
continue play free. Endgame feel + structural rhyme (“powers respond on ground
you own”). Purchase alone is not the ending.

**Build:** BalanceHolding, CampaignService purchase/ignition, station controller
overrides, Act III milestones + dual-path ignition (papers/force by standing),
player Holding entity, station Holding UI, save `campaign.holding`. Commit
`9ab4930`.

**Playtest brief:** **`docs/S8_ENDGAME_PLAYTEST.md`**

### Attempt log

- **2026-08-04** — S8 code complete. Lint green; full suite green (792 tests).
  **Gate open, not signed.**
- **2026-08-04** — **Signed pass** (Elliot: “Signed”). Endgame + rhyme accepted;
  S9 queued until authorized.

**Verdict: signed — S8 endgame feel + structural rhyme passes.**

**Signed by:** Elliot  
**Date:** 2026-08-04  
**Verbatim:**
> Signed

**Notes:** Feel gate closed. S8 phase done. Plan marks real Alpha at S8 accept.
Next phase S9 (content complete) when authorized — do not start until he says so.

---

## S9 — Content complete (real Beta)

**Criteria (plan):** measured playtests (including external) hit ~30h main path
without dead air; completionist hooks exist. **Gate [Elliot]: content complete.**

**Build (floor):** Steam §10 floor fill — 8 systems / 16 stations / 8 entities /
35 people / 12 commodities / 8 recovery chains; Ice + Components; Eta/Theta map +
presentation; board flashpoint hand jobs; markets rebalanced. No new save schema.

**Playtest brief:** **`docs/S9_CONTENT_PLAYTEST.md`**

### Attempt log

- **2026-08-04** — S9 content floor complete. Lint green; full suite green
  (792+ tests including `test_s9_content_floor`). **Gate open, not signed.**
  Hours not claimed — needs Elliot (+ external) measure.

### Attempt 1 — 2026-08-04

**Verdict: signed — content complete.**

**Elliot (verbatim):**

> Pass.

**Notes:** Content-complete gate closed. Maturity = **real Beta** per plan.
S9 phase done. **S10** (polish + RC) next when authorized — Standard tier (§22).

---

## S10 — Production polish + launch prep (RC)

**Criteria (plan):** art/audio floor, UI, performance, accessibility (rebinds,
sensitivity, FOV, colorblind-safe standing colors, controller decision),
Steamworks hooks as needed, bug smash. **Gate [Elliot]: release candidate.**

**Build (floor):** Options (FOV / sensitivity / volumes / fullscreen / rebinds);
keyboard+mouse only for 1.0; standing tier color + glyph + text; lit ship/station
materials; thin procedural audio; product name Draywar; SteamService stub;
Windows export preset; ship budget still 20. Playtest: `docs/S10_RC_PLAYTEST.md`.

### Attempt log

- **2026-08-04** — S10 code floor complete. Lint green; full suite green
  (818 tests including `test_s10_*`). **Gate open, not signed.**

**Verdict: open — release candidate not signed.**

**Notes:** Full GodotSteam SDK not added (no new dependency without approval).
Gamepad intentionally out for 1.0. Another polish pass stays S10 if he names holes.

