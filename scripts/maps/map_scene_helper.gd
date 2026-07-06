class_name MapSceneHelper
extends RefCounted
## Shared bits every map scene (farm, dungeon floors) repeats. Extracted
## rather than copy-pasted per dungeon_floor.gd's note — farm.gd keeps its
## own copy of the auto-instance loop (it predates this helper and touching
## it isn't required by this stride), but every dungeon floor calls this.

const AUTO_INSTANCE_SCRIPTS := [
	"res://scripts/components/day_tint.gd",
	"res://scripts/ui/hud.gd",
	"res://scripts/ui/inventory_screen.gd",
	"res://scripts/ui/dialog_box.gd",
	"res://scripts/ui/shop_screen.gd",
	"res://scripts/ui/journal.gd",
	"res://scripts/components/day_flow.gd",
	"res://scripts/ui/pause_menu.gd",
	"res://scripts/util/debug_keys.gd",
	"res://scripts/ui/forge_screen.gd",  # Craft Stride 2: Sten's Forge UI
]


static func instance_ui_and_flow_layer(host: Node) -> void:
	## HUD/InventoryScreen/DayFlow/debug_keys auto-instance loop, copied from
	## farm.gd's Task 9-11 pattern so scripts can exist or not without editing
	## callers.
	for extra in AUTO_INSTANCE_SCRIPTS:
		if ResourceLoader.exists(extra):
			var node: Node = (load(extra) as GDScript).new()
			host.add_child(node)


static func attach_season_palette(host: Node, ground: TileMapLayer) -> void:
	## World Stride A: outdoor maps call this right after building their
	## Ground layer — the SeasonPalette node recolors it per season (and
	## re-applies on day_passed). Dungeon floors deliberately DON'T call
	## this: underground is exempt from seasonal + rain visuals (see
	## dungeon_floor.gd / day_tint.gd). Lives in the host scene so it dies
	## (and auto-disconnects) with it.
	var palette := SeasonPalette.new()
	palette.name = "SeasonPalette"
	host.add_child(palette)
	palette.setup(ground)


static func spawn_cell(spawns: Dictionary, default_key: String) -> Vector2i:
	## Resolves SceneChanger.spawn_name against a map's SPAWNS dict, falling
	## back to default_key (and to Vector2i.ZERO if even that is missing).
	var name: String = SceneChanger.spawn_name
	if spawns.has(name):
		return spawns[name]
	return spawns.get(default_key, Vector2i.ZERO)
