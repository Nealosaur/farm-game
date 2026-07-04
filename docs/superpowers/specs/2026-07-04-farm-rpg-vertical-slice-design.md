# farm-rpg — Vertical Slice Design

**Date:** 2026-07-04
**Status:** Approved by Forrest (brainstorm session 2026-07-04)
**Engine:** Godot 4.4+ (GDScript, TileMapLayer nodes)
**Project path:** `C:\Users\Forrest\Desktop\farm-rpg`
**Working title:** farm-rpg (placeholder — rename later)

---

## 1. Vision

A 2D pixel art farming + combat RPG: Stardew Valley's farm loop crossed with
Rune Factory's action combat and shared-stamina design. Farming and combat feed
each other: crops become food that fuels dungeon runs; dungeon runs yield XP,
gold, and materials that grow the farm and the character.

This spec covers the **vertical slice** only: every core system present but
small, playable end-to-end. Later phases extend content on top of these
systems without rewrites.

**Slice win condition:** defeat the boss on dungeon floor 3.

## 2. Core Loop

Wake 6:00 AM → farm chores (till / plant / water) → dungeon with remaining RP
→ fight for XP, gold, drops → return, eat, sleep → crops grow overnight →
repeat, pushing deeper each time.

## 3. World

Five maps connected by exit portals:

| Map | Contents |
|---|---|
| Farm | House (bed = sleep + save), tillable field, shipping bin |
| Town | One screen; General Store NPC (buy seeds/food/Iron Sword, sell items). Open 9:00–17:00 |
| Dungeon F1 | Slimes; easy intro floor |
| Dungeon F2 | Slimes + Wisps + Goblins; tighter layout |
| Dungeon F3 | Goblins + Wisps; boss room: Slime King |

Dungeon enemies respawn at the start of each day. Dungeon has no open hours.

## 4. Player

- 8-direction movement, 4-direction facing (down/up/left/right sprites).
- **Stats:** HP, RP (stamina), attack, level, XP, gold.
- **Leveling:** combat XP → level up: +HP max, +RP max, +1 attack.
- **RP rule (Rune Factory):** every tool use, sword swing, and dodge costs RP.
  At 0 RP, the action happens anyway but the cost drains HP instead.
- **Collapse:** at HP 0 or at 2:00 AM, the player collapses and wakes next
  morning in bed with half RP.
- **Food:** eating crops or bought food restores RP (and some HP). This is the
  farming → combat bridge.

### Controls (Godot input actions — gamepad is a remap, not a rewrite)

| Action | Binding |
|---|---|
| Move | WASD |
| Use held item (contextual: swing/till/water/plant/eat) | Left-click or J |
| Interact (bin, bed, NPC, portals via touch) | E |
| Dodge roll | Space |
| Hotbar select | 1–0, scroll wheel |
| Inventory | Tab |
| Pause | Esc |

## 5. Combat

Real-time action combat:

- Directional sword swings with hitboxes; 3-hit combo (click timing chains).
- Dodge roll with invincibility frames; costs RP.
- Knockback + hit-stun on both player and enemies; brief i-frames after being hit.
- Player hit flash + small screen shake on impact (cheap juice, in slice).

### Enemies

| Enemy | Behavior | Floor |
|---|---|---|
| Slime | Wanders, chases on sight, contact damage | F1–F2 |
| Wisp | Erratic floating movement, contact damage, ignores terrain | F2–F3 |
| Goblin | Chases, telegraphed heavy melee swing (windup → strike) | F2–F3 |
| **Slime King (boss)** | Large, slow chase; telegraphed jump-slam AoE; spawns baby slimes at HP thresholds | F3 |

All enemies: HP, contact/attack damage, XP, gold, and a material drop table
defined in data. Materials have no use in the slice (sell only); they are
reserved for Phase 2 forging/taming.

## 6. Farming

Tile-grid farming on the farm map:

1. Hoe tills a grass tile → tilled soil.
2. Plant a seed on tilled soil.
3. Water daily with watering can.
4. On day rollover, crops **advance one growth stage only if watered**;
   watered flags reset.
5. Final stage → harvestable by hand (no RP cost).
6. Ship via bin (pays out overnight at day rollover) or eat / sell at store.

### Crops (slice)

| Crop | Days to grow | Seed cost | Sell price | Eat effect |
|---|---|---|---|---|
| Turnip | 3 | 20g | 45g | +30 RP |
| Carrot | 5 | 40g | 105g | +50 RP |
| Pumpkin | 8 | 80g | 250g | +80 RP, +20 HP |

(Numbers are starting values — tune during playtesting.)

No seasons in the slice: one endless "spring."

## 7. Time

- In-game clock 6:00 AM → 2:00 AM; ~14 real minutes per full day.
- Sleep in bed any time → day rollover (crops advance, shipping pays,
  enemies respawn, autosave).
- Sleep restores HP and RP to full. Collapse (HP 0 or 2:00 AM) also rolls the
  day over but restores RP only to half of max (HP to full).
- Clock pauses in menus and dialogs.

## 8. Economy

- Money in: shipping bin, direct store sales, enemy gold drops.
- Money out: seeds, food, **Iron Sword** (store, 2500g — the slice's one gear
  upgrade; roughly double starting sword damage).
- Starting kit: 500g, hoe, watering can, Wooden Sword, 5 turnip seeds.

## 9. UI

- HUD: HP bar, RP bar, gold, clock + day counter, 10-slot hotbar.
- Inventory screen (Tab): grid, move/swap stacks, assign to hotbar.
- Shop screen: buy list / sell from inventory.
- Pause menu: resume, save, quit to title.
- Title screen: new game / continue.
- Dialog box for NPC lines (simple, no branching in slice).

## 10. Architecture

### Autoload singletons

| Autoload | Responsibility |
|---|---|
| `EventBus` | Signals only: `day_passed`, `time_ticked(hour, minute)`, `money_changed`, `enemy_died(data)`, `item_shipped`, `player_leveled`, … |
| `Clock` | Time-of-day, day counter, tick emission, day rollover |
| `GameState` | Gold, player stats/XP/level, story flags (e.g. `boss_defeated`) |
| `Inventory` | Hotbar + bag slots, stacking, add/remove/query API |
| `ItemDB` | Loads all `.tres` content at startup; lookup by string id; asserts unique ids |
| `SaveManager` | JSON save/load, versioned |
| `SceneChanger` | Fade → swap map scene → place player at named spawn marker |

### Content as custom Resources (`.tres`)

- `ItemData`: id, display name, icon, max stack, buy price, sell price.
  - `SeedData` extends it: crop id.
  - `FoodData` extends it: rp_restore, hp_restore.
  - `ToolData` extends it: tool type (hoe/can/sword), rp_cost, damage (sword).
- `CropData`: id, stage count, days per stage, product item id, stage sprites.
- `EnemyData`: id, HP, damage, speed, XP, gold, drop table, sprite frames,
  plus reserved Phase-2 fields: `tameable: bool`, `favorite_food: String`.

Adding content later = new `.tres` files, no code.

### Combat components (reusable child scenes)

- `HealthComponent` — HP, `died` / `health_changed` signals.
- `HitboxComponent` (Area2D) — deals damage + knockback vector.
- `HurtboxComponent` (Area2D) — receives hits, applies i-frames, forwards to HealthComponent.
- `StateMachine` — generic node-based FSM used by player and enemies.

Player = CharacterBody2D + FSM (Idle, Move, Attack1/2/3, Dodge, UseTool,
Hurt, Dead). Enemy = CharacterBody2D + FSM (Wander, Chase, Windup, Attack,
Hurt, Dead) parameterized by `EnemyData`. Boss = same scene pattern + two
extra states (Slam, Summon).

### Farming implementation

`FarmGrid` node on the farm map: `Dictionary[Vector2i → SoilPlot]` where
SoilPlot = { tilled, watered, crop_id, stage, days_in_stage } —
`days_in_stage` counts watered days toward the current stage, so stages
longer than one day work. Rendering via TileMapLayer
(soil/water overlay) + one crop Sprite2D per planted plot. Listens to
`EventBus.day_passed` for growth/reset. Serializes directly into the save.

### Maps & travel

Each map is a scene. `Portal` (Area2D) nodes carry `target_scene` +
`target_spawn` exported fields; on body-enter → `SceneChanger.travel(...)`.
Invalid target → fall back to farm default spawn (fail safe, log warning).

## 11. Save System

- `user://save1.json`, single slot in slice.
- Written on sleep and manual save (pause menu).
- Contents: `save_version`, day, time, gold, player stats/level/XP, inventory,
  farm grid, story flags.
- Load: validate `save_version`, fill missing keys with defaults (forward
  compatible); corrupt/missing file → new game + warning, never a crash.

## 12. Rendering & Placeholder Art

- Base viewport **640×360**, integer-scaled window; `texture_filter = nearest`.
- Tile size **16×16**. Character frames 16×32 (player, NPC), enemies 16×16 to
  32×32, boss 48×48.
- Placeholders: flat-color labeled PNGs at exact final dimensions, generated
  into `assets/placeholder/`. Real tilesets/sprites from Forrest later replace
  files + re-slice frames; animation names and sizes stay stable.
- All characters use `AnimatedSprite2D` with standard animation names:
  `idle_down/up/left/right`, `walk_*`, `attack_*` (+ enemy `windup_*`, `die`).
- Y-sorting for depth on all maps.
- Audio: none in slice; `AudioManager` stub autoload so hooks exist.

## 13. Error Handling

- ItemDB startup validation: duplicate/missing ids assert in dev builds.
- SaveManager: version check + defaults; never crash on bad save.
- Portals: invalid destination → farm spawn + warning.
- RP/HP math clamped ≥ 0; day rollover idempotent (guard against double fire).

## 14. Testing

- **GUT** addon for pure-logic unit tests: crop growth math, inventory
  stacking/overflow, save round-trip, RP→HP drain rule, XP/level curve.
- Manual playtest checklist per milestone (movement feel, combat feel, full
  day loop, full save/load loop, boss fight).
- Debug hotkeys (dev builds only): F1 +1000g, F2 skip day, F3 teleport to
  dungeon entrance, F4 refill RP/HP.

## 15. Out of Scope (Slice) → Roadmap

| Phase | Content |
|---|---|
| **Phase 2** | Monster taming (barn, brush, favorite foods — data fields already reserved), cooking, forging/upgrades, more weapons + magic/RP spells |
| **Phase 3** | More NPCs with schedules + friendship, seasons + more crops, dungeon floors 4+, mining nodes |
| **Phase 4** | Audio, festivals, animals, polish, marriage candidates |

Explicitly not in the slice: taming, cooking, forging, magic, seasons, NPC
schedules/friendship, festivals, mining nodes, farm animals, multiple save
slots, gamepad glyph UI, controller rumble.
