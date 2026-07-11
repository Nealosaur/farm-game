# farm-rpg Marriage & Dating — design

> The flagship post-slice pillar. Reuses the existing relationship system
> (10 levels), heart events (choice scenes), the cutscene DSL (proposal +
> wedding), festival crowd machinery, and NPC schedules (spouse on the farm).
> Dialog authored VERBATIM in characters.md like all NPC content.
> ROSTER (§1) is Forrest's call — confirm before authoring per-character arcs.

## 1. Romance roster — CONFIRMED (Forrest, 2026-07-07): THE 5
Romanceable: **Rosa, Willow, Doc Bram, Sten, Garrick**. Platonic (keep their
existing arcs, no romance content): **Marta** (grief arc for Tomas stays
intact), **Alden** (mayor/mentor), **Finn** (teen).

| NPC | Romanceable? | Note |
|---|---|---|
| **Rosa** (saloon keeper) | ✅ | Warm, unattached; "no one leaves sad" openness. |
| **Willow** (herbalist) | ✅ | "Found my voice in the quiet" deepens toward intimacy. |
| **Doc Bram** (doctor) | ✅ | Romance pulls him back toward caring; fits his burnout arc. |
| **Sten** (blacksmith) | ✅ | Slow-burn; gruff-softening + masterwork threads. |
| **Garrick** (retired adventurer) | ✅ | Wry, unattached; peer/mentor-turned-partner. |
| **Marta** (widow) | ❌ platonic | Grief arc for Tomas kept intact. |
| **Alden** (aging mayor) | ❌ platonic | Mentor figure. |
| **Finn** (teen) | ❌ platonic | Best-friend arc only ("The Shed" L7). |

## 2. Dating & marriage flow (mechanics)
Builds on the existing 10-level relationship (100 pts/level, gifts/talk/decay).
- **Heart-event extension**: romance candidates gain events at **L8 and L10**
  (beyond the existing L3/L7), authored per-character in characters.md — these
  turn from friendship to romantic interest. Non-candidates keep L3/L7 only.
- **Bouquet** (new item, buy at Marta ~200g): give to a candidate at **L8+**
  to start **dating** (world["romance"][id].dating = true). Unlocks dating
  dialog + confirms mutual interest. Dating multiple candidates is allowed
  (no jealousy system this phase — keep simple; document).
- **Pendant** (new item, rare — e.g. a reward from deep mine / Willow at high
  bond, ~a real gate): give to a candidate you're **dating at L10** → triggers
  the **proposal cutscene** (DSL). Accept → engaged; next day-rollover → the
  **wedding**.
- **Wedding cutscene** (DSL, at the plaza): reuse the festival crowd override
  (all NPCs present), an authored ceremony scene per... no — ONE parametric
  wedding scene that names the spouse (DSL supports actor by id), + a short
  spouse-specific vow line authored per candidate. Sets spouse flag; spouse
  moves to the farm.
- One spouse at a time. Marrying ends other dating (they revert to friends,
  a small bond ding + a one-line reaction — authored). Document.

## 3. Spouse life (post-marriage)
- Spouse **lives on the farm**: gets a farm-map schedule (kitchen/porch/field
  wander) via the existing NPCRegistry (add a "farm" schedule branch keyed on
  married-to-this-id). Leaves their old town job's schedule.
- **Spouse dialog pool**: a new tier above KINDRED, authored per spouse
  (morning greetings, "made you something", occasional worry when you're deep
  in the Delve).
- **Spouse help** (RF/Stardew flavor): each morning a chance the spouse waters
  a few crop cells OR leaves a dish/gift on the bed (reuse the barn-slime
  morning-help pattern). Small, cozy, once/day.
- **14-heart spouse event**: one authored capstone scene per spouse (the
  relationship cap moves to L14 for a spouse, like Stardew's 14-heart).

## 4. Systems touched (all EXTEND, don't rewrite)
- Relationships: allow L11-14 for a spouse (cap lift); dating/married state in
  the world blob.
- Heart-event/trigger system: L8/L10 candidate events + proposal + 14-heart.
- Cutscene DSL: parametric proposal + wedding scenes (actor-by-id already works).
- NPCRegistry: married-spouse "farm" schedule branch.
- DialogBox: dating/spouse dialog pools in the resolver precedence.
- Content: bouquet + pendant items + icons; gen_content additions.
- Save: world["romance"] = {candidate_id: {dating: bool, married: bool}},
  spouse id, events_seen extended — all int/bool-coercion-safe.

## 5. Build strides (after roster confirmed)
- **M1 — Romance framework**: world["romance"] blob, dating/marriage state,
  bouquet/pendant items, L8/L10 event gating, dating dialog resolver hook,
  the parametric proposal + wedding DSL scenes (generic, one candidate wired
  as pilot). Tests.
- **M2 — Per-candidate content**: L8/L10/14 heart events + dating + vow +
  spouse dialog for each confirmed candidate, VERBATIM in characters.md.
- **M3 — Spouse-on-farm**: farm schedule branch, spouse morning-help, spouse
  dialog live, marry-ends-other-dating handling. Tests + integration.
- **M4 — Review + merge + push.**

## Out of scope (this pillar)
Children, jealousy/rivalry, divorce, polyamory-beyond-dating, spouse combat
companion. Real portraits (parallel real-art track). Multiple save slots.
