# farm-rpg Visual & Feel Overhaul — "Make It a Real Game"

> Triggered by playtest verdict "the game so far is terrible": 855 green tests
> of systems rendered as flat-color shapes. This doc is the source of truth
> for turning the tech demo into something that reads and plays as a real
> pixel game. Order: **LOOK → FEEL → DEPTH** (user directive).
>
> LEGAL NOTE: the Stardew decompile (WeDias/StardewValley) is 692 .cs files,
> ZERO art — code only. We study its *mechanics* (ideas, not copyrightable)
> for Depth. We DO NOT ship its art. All art here is PROCEDURALLY GENERATED
> pixel art we own, or a properly-licensed free pack the user supplies.
> Reference template proven working: `tools/proto_char.gd` (parametric farmer
> + slime — real pixel characters, not rectangles).

## Art direction (from the proven spike)
- **Parametric pixel art**: characters/enemies/crops/props built from rect +
  pixel primitives with a shaded side (volume), a 1px dark outline around the
  silhouette, and a soft translucent ground shadow. Palette: warm skin
  (#e8b88a / shade #c99268), earthy hair/wood, saturated-but-not-neon clothes
  and crops. Outlines ~#2b2233, never pure black.
- **Sizes stay stable** for collision/gameplay: tiles 16×16, player/NPC frame
  16×32 (feet at bottom of frame), small enemies 16×16, goblin 16×24, boss
  48×48, item icons 16×16, crop stages 16×16.
- **Review loop (mandatory)**: every art stride emits a CONTACT SHEET PNG
  (all sprites tiled + 4-6× nearest-scaled) to `tools/_proto/` (gitignored);
  the orchestrator READS it and iterates on quality before the stride closes.
  Green tests do NOT prove art quality — eyes do.

## LOOK strides

### V1 — Pixel-art generation library
Replace flat-shape `gen_placeholders.gd` with a real generator (`tools/
pixelart/*.gd` helpers or an expanded single file) producing, in the spike's
style:
- **Characters (player + 8 NPCs)** as SHEETS: 4 directions (down/up/left/right)
  × walk cycle (≥3 frames: contact/passing/contact, or 4) + idle (1) + use
  (1). Layout convention: one PNG per character `char_<id>.png`, a grid of
  16×32 cells, rows = animation, cols = frame; a sidecar `.frames.json`
  (or a const in code) naming row order + frame counts so the slicer is
  data-driven. Per-NPC palette (hair/clothes) so all 8 read distinct.
- **Enemies**: slime/wisp/goblin/slime_king with idle bob + hurt + die frames,
  each with character (slime dome+eyes, wisp wispy, goblin stocky, king huge).
- **Crops**: 4 growth stages that actually look like sprout→plant→ripe per
  crop silhouette (turnip/carrot/strawberry/tomato/corn/melon/pumpkin/
  eggplant/amberleaf), not colored circles.
- **Items**: readable icons (produce, seeds as packets, tools as tool shapes,
  swords as blades, materials).
- **Tiles**: grass with subtle noise/detail + a few variants; tilled/watered
  soil with furrow lines; stone floor; wall with a face; water with a
  highlight; path; sand. Enough texture that a field of them isn't flat.
- **Props**: house, barn, fence, bed, bin, kitchen, counter, stairs, sign,
  boat shed — read as objects with shading + outline.
Determinism preserved (rerun → git clean). Emit the contact sheet.

### V2 — Animation pipeline (make it move)
- Sheet slicer: `SpriteFrames` built from a character sheet via the frame
  convention (replaces single-frame `PlaceholderFrames` for sheeted art;
  keep a fallback for any not-yet-sheeted texture). Animation names unchanged
  (`walk_down`, `idle_left`, `use_up`, enemy `idle/hurt/die`) so consumers
  don't churn.
- Player/NPC/enemy: play walk cycle while moving (speed-scaled fps), idle when
  still, use-anim on tool/attack; wisp bobs; crops sway optional (skip if
  costly). Real ground-shadow node under each character (a small dark ellipse
  Sprite/Polygon that stays flat on the ground, separate from the sprite so
  it doesn't Y-sort weird).
- Verify by rendering (generate an in-engine screenshot IF a display is
  usable; else verify frame-slicing + animation state via tests + inspect the
  sheet). Tests stay green.

### V3 — World / tile / UI polish
- Tile rendering: per-cell variant selection (grass noise), so maps aren't
  uniform; subtle autotile-ish edges where cheap. Layered decoration (flowers,
  pebbles, grass tufts scattered deterministically).
- Day/night + season tint retuned to look good (current values may be muddy);
  add a soft vignette or lamp glow at night if cheap.
- UI skin pass: HUD bars/panels/hotbar/dialog/shop/journal get a simple pixel
  frame style (StyleBoxFlat/Texture) instead of default gray; a pixel font if
  one is bundled/free, else keep default but style the panels.

## FEEL strides (after Look)
- **Movement**: acceleration + friction (not instant velocity); slight
  sub-pixel smoothing; camera position smoothing + small look-ahead.
- **Combat/tool juice**: hit-stop (freeze 2-4 frames on a landed hit),
  impact particles (dust on footstep cadence, dirt puff on till, water
  droplets on watering, leaf burst on harvest, spark/blood-pop on hit,
  slime splat on kill), retuned screen shake (subtle), sword swing arc VFX.
- **SFX**: procedural or bundled free SFX for step/till/water/plant/harvest/
  swing/hit/enemy-die/menu/coin/level-up/sleep. AudioManager exists as a stub
  — wire it. If no audio files are available, generate simple tones or leave
  clearly-marked hooks + document.
- **Feedback**: floating "+15"/"+80" bond numbers, damage numbers optional,
  tool-target cell highlight, interactable prompt ("E") when in range.

## DEPTH strides (after Feel — study the decompile's MECHANICS, reimplement)
- **Mine variety** (Stardew's mines are the model): procedural dungeon floor
  layouts, ladders/holes to descend, occasional treasure floors, monster
  density variety, a descend-depth counter, better loot tables.
- **Tool upgrade tiers** beyond Sten's one arc: hoe/can/sword copper→iron→
  gold style tiers with area/efficiency gains.
- **Fishing** minigame (Riverwoods river + Beach pier already exist): a
  simple catch bar; fish as sellable/edible items; a few species per water.
- Rebalance economy/combat as these land.

## Out of scope for this overhaul
Marriage/dating, new NPCs, multiplayer, controller glyphs. Real hand-drawn
art (the user may drop a licensed pack onto the stable filenames at any time;
the sheet convention + slicer make that a no-code swap).
