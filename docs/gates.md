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
- You can fly a short session: dock, take a job, jump, turn in, refuel, talk to Mendi — without needing console for the fantasy.

### Play script (cold launch)

1. Run main scene. Note **SYSTEM**, **STANDING**, **CREDITS**, **FUEL**.
2. Dock Alpha Port (F). Accept job → destination name on the button. Undock.
3. Fly to the **blue gate**, F to jump (needs fuel). Status line should change with the new system.
4. Dock Beta Hub. **Turn in job**. Credits and standing should move.
5. Jump around; notice NPC traffic density (busy Alpha vs thinner Gamma).
6. At Alpha Port: **Ask favor of Mendi** a few times until **Talk to Mendi** appears. Accept, **Complete recovery work**.
7. Optional: grind Reach down hard (abandon jobs). You should still be able to dock Alpha to reach Mendi while that recovery route is open.

**Console is optional** (save/load, debug). Do not need it for the loop above.

### Attempt 1 — 2026-07-31

**Verdict: not signed — not Alpha yet.**

**Elliot (verbatim):**

> This isn't an Alpha. This is a rudimentary technology demonstrator

**Notes:** Mechanical A5 criteria (systems, money, normal-play levers, no console required for the loop) may hold as a tech slice. Final Alpha fantasy sign-off refused. Iterate until the play feels like a prove-it game, not a systems demo. Do not advance to full-plan expansion on this verdict.
