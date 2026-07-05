# farm-rpg World Bible — "Emberhollow"

> Source of truth for the living-world build. Design grounded in Stardew
> Valley's hub-and-spoke town + learnable schedules and Rune Factory's
> bond/festival rhythm. Companion doc: `characters.md` (full NPC roster,
> dialog pools, heart events — implement dialog FROM THAT FILE verbatim).

## Design principles (from research)
1. **Hub-and-spoke world.** A social town square at the heart; every compass
   direction has one personality (farm, wilds, water, danger). Nothing more
   than one screen-transition from the hub's spokes.
2. **Learnable routines.** NPCs are somewhere specific because of the time,
   day, weather, and season — players are rewarded for learning patterns.
3. **Empathy is the winning move.** Relationship events offer choices; the
   validating/curious option gains bond, the dismissive one loses it.
4. **The calendar reshapes everything.** Seasons change crops, palettes,
   dialog, schedules, and festivals — a year is the real content loop.
5. **Fill the world before the art.** All of this ships on placeholder
   silhouettes; filenames stay stable for the later art drop.

## The world: Emberhollow (map graph)

```
                 [Dungeon F1→F2→F3]  (the Old Delve)
                        ↑ east stairs
[Town: Emberhollow] ←west— [FARM: Hearthstead] —south→ [Riverwoods]
        |south                                          (forest, forage)
     [Beach: Graywater Shore]
```

- **Farm — "Hearthstead"** (existing): player home, field, bed, shipping bin.
- **Town — "Emberhollow"** (EXPAND existing ~44x30): central **plaza**
  (festival ground, notice board), **General Store** (Marta) west side,
  **Clinic** (Doc Bram) + **Smithy** (Sten) east side, **Saloon "The Ember"**
  (Rosa) south of plaza, **Mayor's house** (Alden) north. Buildings are
  exterior shells with counters/awnings — no interiors this phase.
  Exits: east→farm, south→Beach.
- **Riverwoods** (NEW ~34x22, south of farm): winding forest path, river
  tiles, Willow's hut, daily **forage spawns** (2-4 items). Exit: north→farm.
- **Graywater Shore** (NEW ~34x18, south of town): pier, Finn's spot, daily
  **shell/driftwood forage**. Exit: north→town.
- **Dungeon** (existing 3 floors): unchanged; Garrick loiters at the farm-side
  entrance some days.

## Calendar & time
- **4 seasons × 28 days**, then Year+1. Display: "Spring 12, Yr 1".
- Clock day length unchanged (~14 min). Sleep advances the date.
- **Seasonal palette**: Ground layer modulate per season — Spring #ffffff
  (neutral), Summer (1.02, 1.0, 0.9) sun-baked, Fall (1.1, 0.85, 0.6) amber,
  Winter (0.8, 0.85, 1.0) pale. Stacks with day/night tint.
- **Weather**: each day rolls rain 20% (Spring 30%, Winter 0% — winter is
  clear/frozen). Rain: blue-gray tint layer, crops auto-watered, NPCs use
  rain dialog lines, Beach/Riverwoods NPCs shelter (schedule variant).
- **Birthdays**: each NPC has one (see characters.md); gifts ×8 bond.

## Crops by season (data — gen_content additions)
| Season | Crop | Days | Seed buy | Sell | Eat |
|---|---|---|---|---|---|
| Spring | Turnip (existing) | 3 | 20 | 45 | +30 RP |
| Spring | Carrot (existing) | 5 | 40 | 105 | +50 RP |
| Spring | Strawberry (NEW) | 7, regrows 3 | 90 | 130/pick | +45 RP |
| Summer | Tomato (NEW) | 6, regrows 4 | 60 | 90/pick | +40 RP |
| Summer | Corn (NEW) | 8, regrows 4 | 80 | 100/pick | +55 RP |
| Summer | Melon (NEW) | 10 | 120 | 320 | +90 RP, +15 HP |
| Fall | Pumpkin (MOVED to fall) | 8 | 80 | 250 | +80 RP, +20 HP |
| Fall | Eggplant (NEW) | 6 | 45 | 95 | +45 RP |
| Fall | Amberleaf (NEW, flavor crop) | 9 | 100 | 260 | +70 RP |
| Winter | — nothing plantable outdoors. Forage + dungeon season. |

- **Season gating**: seeds plant only in their season (CropData.seasons).
  Standing out-of-season crops **wilt** at season rollover (plot keeps
  tilled, crop cleared, toast on wake: "The season turned — your <crop>
  wilted."). Marta stocks only in-season seeds (data-driven).
- **Regrowing crops** (strawberry/tomato/corn): after first harvest, crop
  returns to stage N-1 and regrows in `regrow_days` (new CropData fields:
  `regrow_days: int = 0`, 0 = single harvest).
- **Forage** (NEW ItemData, sell-only + eat): Riverwoods — Wildroot (35g,
  +25 RP), Emberberry (60g, +40 RP); Beach — Tideshell (45g), Driftglass
  (80g); Winter-only both maps — Frostcap (75g, +50 RP). 2-4 spawns/day/map.

## Relationships (systems contract)
- **10 levels × 100 pts** (0-999). Tier names for dialog pools:
  **Stranger** (L0-1) → **Acquaintance** (L2-3) → **Friend** (L4-6) →
  **Close** (L7-9) → **Kindred** (L10).
- **Talk** once/day: +15. **Gift** once/day per NPC (use held item on them):
  loved +80, liked +45, neutral +20, disliked −20. Birthday ×8.
- **Decay**: −2/day untalked, only at L2+, floor at each tier's base (never
  decay below a reached tier — kinder than Stardew, closer to RF).
- **Festival attendance**: talking to an NPC at a festival +30 (RF-style).
- **Heart events**: auto-play on next talk at L3 and L7 (per NPC, once).
  Multi-line dialog with ONE two-option choice: empathetic +30 / dismissive
  −30. Scripts in characters.md — implement verbatim.
- **Level perks**: at L5 and L8 every NPC hands a one-time gift next talk
  (defined per NPC). Marta additionally: L4+ = 5% shop discount, L7+ = 10%.
- **Journal (J key)**: Quests tab + Social tab (all NPCs: level bar, tier
  name, birthday, gift checkmark today, talked-today check).
- HUD niceties: talking shows "+15" style floaters via existing toast queue.

## NPC schedule system (contract)
- Central **NPCRegistry** (autoload or data file): per NPC, per time-block
  (blocks: 6-9, 9-12, 12-17, 17-20, 20-2), a (map, cell) location, with
  optional weekend (day%7>=5) and rain/winter overrides. Maps ask the
  registry "who is here now" at build + on time-block changes (respawn/move
  NPC instances on block boundaries; within-map walking optional — teleport
  between spots at block change is acceptable this phase, document it).
- All 8 NPCs' schedules are specified in characters.md.

## Festivals (4/year, on the plaza, 10:00-18:00 that day)
On festival day: notice-board toast at wake; plaza gets colored-tile
decoration + all 8 NPCs present (schedule override); each has festival
dialog; talking gives the +30 festival bond bonus. Portal to town stays
open; farm chores still possible. Shop closed (Marta's at the plaza).
1. **Sowing Festival — Spring 14**: Alden speech dialog; Marta stall sells
   all spring seeds at −20%; everyone gets +30 on talk.
2. **Sunfire Festival — Summer 21**: evening event (16:00-22:00 override);
   Rosa's bonfire (decor); Finn's "dare you to touch the Delve door" line.
3. **Harvest Fair — Fall 16**: **crop contest**: bring your highest-value
   crop; Alden judges at 14:00 (interact with him with crop selected):
   value ≥250 → 1st (500g + all NPCs +50), ≥100 → 2nd (200g), else
   participation (50g). One entry/year.
4. **Winter Star Night — Winter 24**: secret-gift exchange, simplified:
   at wake, journal names your assigned NPC; gifting them today = loved
   reaction regardless of item + ×5 bond; you receive a gift from a random
   NPC at the plaza (their loved item or gold).

## Opening: Day 1 has hooks (fixes "start lacks depth")
1. Wake Day 1 → **Mayor Alden is standing on the farm** (one-time): intro
   dialog (see characters.md §Alden/Intro) — inherited Hearthstead from
   grandmother, town's fading, the Delve's gotten dangerous, "make this
   place live again."
2. Grants **Quest: "New Roots — meet everyone in Emberhollow"** (journal
   lists the 8 names, auto-checks on first talk; reward on completion,
   handed by Alden next talk: 300g + 5 turnip seeds "from Marta").
3. **Garrick chain** (picked up by talking to Garrick): Q2 "Prove It —
   reach Delve floor 2" (reward 200g + 2 carrot seeds... reward: 200g +
   iron-tier hint dialog); Q3 "The King Below — defeat the Slime King"
   (reward 500g; auto-completes if already done).
4. Notice board on the plaza (interactable): shows next festival + any
   active quest hints (flavor text, one-liner per season).

## Save/load additions (world blobs, follow the documented contract)
- `world["calendar"]` {season:int, day_of_season:int, year:int, weather_today:String, festival_done flags}
- `world["relationships"]` per NPC {points:int, talked_day:int, gifted_day:int, events_seen:[], perks_given:[]}
- `world["quests"]` {id: {state, progress}}
- `world["forage"]` {map: {day, taken:[cells]}}
- All JSON-float-coercion safe (int() on read — established gotcha).

## Explicitly OUT (later phases)
Marriage/dating, building interiors, NPC pathfinding (block-teleport ok),
cooking/forging, taming (schema still reserved), weather beyond rain,
animations. Sprites: filenames stable; new placeholders only for new
content (NPC silhouettes, forage items, new crops) via gen_placeholders.
