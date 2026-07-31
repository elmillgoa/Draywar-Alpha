# Human gates

Elliot’s words only. Agents never sign these.

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

*(none yet — waiting on Elliot)*

### Play fixes (pre–formal Attempt) — 2026-07-31

**Not a full E1 feel verdict.** Mid-gate play after E1 code. Combat/aim/job path fixed and accepted for this slice.

**Elliot (verbatim):**

> Much better. We are good on this section

**Fixes in that slice:** Accept-job crash (free mid-pressed); free-fire reticle (camera ray); bounty prey ensure (near player if none in lock range).

**Still open:** Formal E1 feel Attempt (small game worth another phase?) — not signed yet.

