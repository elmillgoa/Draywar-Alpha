# Reputation and Standing — Design Document

**Status:** Source of truth for the reputation system  
**Written:** 2026-07-29  
**Owner:** Elliot (final authority)  
**Companion:** Supersedes the standing-related portions of the previous Destination and Phase Plan documents. Those documents have been updated to match.

---

## 1. Core Thesis (Locked)

There is no global player alignment.  
There is only per-entity standing, and standing is only enforced where an entity has reach.

The same player, with the same ship and cargo, can be:
- a trusted operator in one system,
- a tolerated independent in another,
- and kill-on-sight in a third.

**Guiding analogy:**  
Organizations and governments set the weather.  
Individuals let you find shelter, change local conditions, and — with enough work — eventually influence the larger weather.

**Protected UI moment:**  
On every system entry (and station entry), the game states what the player *is here*. This moment is mandatory and may never be removed or hidden by default.

---

## 2. Two-Layer Model (Locked)

### Entities
Governments, corporations, trade leagues, pirate syndicates, research outfits, military orders, etc.  
These are the institutions that set the weather. They hold (or contest) territory, have reach, and enforce standing.

### People
Named individuals.  
Personal standing is tracked separately from Entity standing.  
People have a primary Entity, a rank within it, and a small network of other people they would actually talk to.

**Alpha hierarchy rule:**  
Entities are flat. They use simple typed relationship links (allied, subsidiary, rival, enemy, member-of).  
True parent/child hierarchy is a long-term goal, not required for the alpha.

**Alpha simplification:**  
Secondary associations for People are ignored. Only the primary Entity relationship matters for influence and recovery help.

---

## 3. Numerical Scale & Stickiness (Locked)

**Internal scale:** continuous float from -100.0 to +100.0

**Display tiers:**

| Tier        | Range       |
|-------------|-------------|
| Revered     | +80 to +100 |
| Allied      | +50 to +79  |
| Friendly    | +20 to +49  |
| Neutral     | -19 to +19  |
| Unfriendly  | -20 to -49  |
| Hostile     | -50 to -79  |
| Hated       | -80 to -100 |

**Stickiness (asymmetric):**
- The negative side is stickier than the positive side.
- Everyday positive actions lose most of their effectiveness once standing is deeply negative (~-40 and below).
- Climbing out of Hostile or Hated requires specialized personal recovery content.
- It remains relatively easy to damage high positive standing quickly by clear offenses or betrayal.
- All magnitudes live in data (Balance / content files), never hard-coded.

---

## 4. Status Resolution — “What am I here?” (Locked)

**System entry:**  
Show only the player’s standing with the Entity that currently controls that system.

**Station entry:**  
Show only the player’s standing with the Entity that owns/controls that station.

Deeper information (other Entities with reach, personal contacts, history, relationship links) lives in relationship / standing menus the player can open when desired.

The status moment must remain fast and readable.

---

## 5. Personal Recovery Path (Alpha)

1. Requires roughly Friendly personal standing + history of successful work with that Person.
2. The Person can offer one small, low-impact, deniable job.  
   Standing movement with the larger Entity is tiny (trust test, not a real climb).
3. After success, the same Person offers a short chain of further jobs (first 4–5 stay one-on-one).
4. As trust builds, higher-rank People from the same Entity can be introduced.
5. **Alpha content rule:** One recovery chain version per Entity is sufficient for the prove-it.

**High-rank acceleration:**  
High-rank People can move Entity standing faster once they decide to help.  
Getting their attention and trust is significantly harder, especially when their Entity already dislikes the player. Extreme or highly valuable prior actions are required.

---

## 6. Betrayal & Network Effects (Alpha — Scoped)

- Clear, tagged actions can near-permanently close a Person (major betrayal, repeated abandonment of their missions, using their help against their own side, etc.).
- True pettiness is handled through authored moments and dialogue, not a general detection system.
- Recovery from a closed personal relationship requires deliberate special effort (targeted gestures, wanted technology, secrets, significant bribes, etc.), not passive time.
- Network damage is limited and data-driven: only the short list of people that contact would normally talk to, same system only.
- Known rivals/enemies of the harmed Person or their Entity can receive a small standing benefit.

---

## 7. Everyday Actions (Locked Direction)

### Combat Attribution
- High-security / well-patrolled space → kills are usually attributed.
- Deep / low-security space → kills are not attributed by default.
- Exception: the player later creates an obvious evidence trail (selling identifiable cargo in the wrong place, etc.).
- Light witness factor: presence of ships that would report the kill increases chance of attribution.

**Sanctioned kills (Locked):**  
An Entity does not charge the player for a kill it paid for.  
While the player holds an active bounty, kills inside that bounty's target system are exempt from the offering Entity's standing hit. No penalty is applied, and therefore no ripple is echoed — there is no source change to echo.

The exemption is deliberately narrow:
- **Only the offering Entity.** Any other Entity with reach in that system attributes the kill normally. Nobody else paid for it.
- **Only the bounty's target system.** A kill anywhere else is not the job.
- **Only while the contract is live.** The test is applied at the moment of the kill. Completing, failing, or abandoning the contract afterwards does not reach back and re-charge a kill that was sanctioned when it happened.

A bounty is therefore net positive with the Entity that offered it. A paid job may not make the payer hate the player for doing it.

**Escort deaths (Locked):**  
A mission escort is a ship, and its death is a kill.  
When an escort freighter is destroyed the death is attributed under the same security, witness, and evidence rules as any other kill, and it costs the same as any other kill. Destroying it yourself and losing it to hostiles carry the same standing cost; the system does not ask who fired.

That cost is separate from, and additional to, the mission's own failure penalty with the offering Entity. The dead ship and the failed job are two different things and both are charged.

### Missions
- Completion → solid positive movement.
- Failure after a genuine attempt → milder negative.
- Abandonment → significantly stronger negative.

### Trade & Gray Activity
- Legal trade → small, slow, soft-capped positive. Cannot be the primary climbing method.
- Smuggling / gray-market activity is double-sided:  
  moving something an Entity wants but cannot normally obtain can improve standing;  
  acting against their interests damages it.

### Relative Strength (Alpha)
1. Attributed combat  
2. Missions  
3. Context-dependent smuggling  
4. Legal trade

---

## 8. Ripple Rules Between Entities (Alpha — Simple)

Only two effects:
- Allied / Subsidiary / Member-of → modest echo of the original standing change (weaker than the source change).
- Rival / Enemy → small inverse echo.

No multi-hop cascading in alpha.  
Ripples are capped so they cannot by themselves push standing across a major tier boundary.

---

## 9. Alpha Population Targets

- Entities: **8–12**
- Fully tracked People: **20–35**

Keep the population deliberately low so the prove-it can be content-complete and tunable. Expand only after the core loop is proven fun.

---

## 10. Data Shape (Implementation Guidance)

**Entity**
- id, display name (placeholders acceptable in alpha)
- standing: Dictionary or resource mapping player → float
- relationship_links: array of {target_id, relation_type}
- reach (systems / stations where it can act)
- control flags for systems and stations it currently holds

**Person**
- id, display name
- primary_entity_id
- rank (low / mid / high)
- personal_standing: player → float
- history / trust flags
- network: short array of Person ids (same-system contacts)

**Player Standing Store**
- Entity standings
- Person standings
- Optional change log for UI and debugging

All standing mutations flow through a single service and emit on the EventBus. Nothing outside that service may write standing directly.

---

## 11. Long-Term (Explicitly Deferred)

- True parent/child hierarchy between Entities
- Secondary associations for People
- Rich variety of secret help methods (private channels, black-site meetings, covers, discovery risk, influence tokens, dark-web style boards, etc.)
- Full social simulation of pettiness
- Multi-hop reputation cascades
- Large population counts

These remain desired but are content- and complexity-expensive. They are out of scope until the alpha loop is proven.

---

## 12. Worked Examples (Required)

**Example A — Clean operator**  
Player has Friendly standing with Entity 3 (system controller) and Allied personal standing with a mid-rank Person inside it.  
System entry status: `Friendly (Entity 3)`  
Station entry (same controller): `Friendly (Entity 3)`

**Example B — Regional problem**  
Player is Hated by Entity 1 (controls the system) but has a strong personal relationship with one low-rank Person still willing to talk.  
System entry status: `Hated (Entity 1)`  
The personal relationship does not appear in the status line; it surfaces only when the player seeks that Person out. That Person can still offer the first deniable recovery job.

**Example C — Station vs System mismatch**  
System is controlled by Entity 2 (player is Neutral).  
A station inside it is owned by Entity 5 (player is Hostile).  
System entry: `Neutral (Entity 2)`  
Docking at the station: `Hostile (Entity 5)` — docking may be refused below the threshold.

---

## 13. Open Gaps (Honest)

- Exact final IDs, names, and behavior profiles for the 8–12 alpha Entities
- Concrete mission text and rewards for the first recovery chains
- Precise ripple percentage values (to be tuned in data)
- Exact docking-refusal threshold per Entity (data)
- How charter / Traitor career states from the original design map onto the new continuous scale + personal layer (see updated Destination document)

---

## 14. Relationship to Original Design

This document expands and partially replaces the standing model in the original Destination document.  
The jurisdictional thesis, the protected status moment, and the idea that Traitor is a career state rather than a fail state are preserved and strengthened.  
The continuous scale + personal layer + sticky recovery paths are the major additions.
