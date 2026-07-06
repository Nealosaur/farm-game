class_name NPCFactory
extends RefCounted
## Generic "build an NPC scene node from data" helper (World Stride C).
## Replaces each map's hand-rolled _make_marta()-style method with one shared
## builder, since 7 more NPCs now need the identical construction — an Area2D
## with a Sprite2D + CollisionShape2D child, wired to a data/dialog pair.
##
## Every registered NPC (see ALL_IDS) has a matching data/npcs/<id>.gd factory
## (static build() -> NPCData) and data/dialog/<id>.gd (a DATA constant in the
## DialogResolver shape) plus a char_<id>.png placeholder. This file only
## needs the three script paths + the sprite path — everything else is read
## off NPCData/dialog data at call time.

## id -> {"data": data script path, "dialog": dialog script path, "sprite": texture path, "has_shop": bool}
const REGISTRY := {
	"marta": {
		"data": "res://data/npcs/marta.gd", "dialog": "res://data/dialog/marta.gd",
		"sprite": "res://assets/placeholder/char_marta.png", "has_shop": true,
	},
	"sten": {
		"data": "res://data/npcs/sten.gd", "dialog": "res://data/dialog/sten.gd",
		"sprite": "res://assets/placeholder/char_sten.png", "has_shop": false,
	},
	"bram": {
		"data": "res://data/npcs/bram.gd", "dialog": "res://data/dialog/bram.gd",
		"sprite": "res://assets/placeholder/char_bram.png", "has_shop": false,
	},
	"rosa": {
		"data": "res://data/npcs/rosa.gd", "dialog": "res://data/dialog/rosa.gd",
		"sprite": "res://assets/placeholder/char_rosa.png", "has_shop": false,
	},
	"alden": {
		"data": "res://data/npcs/alden.gd", "dialog": "res://data/dialog/alden.gd",
		"sprite": "res://assets/placeholder/char_alden.png", "has_shop": false,
	},
	"finn": {
		"data": "res://data/npcs/finn.gd", "dialog": "res://data/dialog/finn.gd",
		"sprite": "res://assets/placeholder/char_finn.png", "has_shop": false,
	},
	"willow": {
		"data": "res://data/npcs/willow.gd", "dialog": "res://data/dialog/willow.gd",
		"sprite": "res://assets/placeholder/char_willow.png", "has_shop": false,
	},
	"garrick": {
		"data": "res://data/npcs/garrick.gd", "dialog": "res://data/dialog/garrick.gd",
		"sprite": "res://assets/placeholder/char_garrick.png", "has_shop": false,
	},
}

const ALL_IDS := ["marta", "sten", "bram", "rosa", "alden", "finn", "willow", "garrick"]


static func build_data(npc_id: String) -> NPCData:
	var factory: GDScript = load(REGISTRY[npc_id]["data"])
	return factory.build()


static func dialog_data(npc_id: String) -> Dictionary:
	var script: GDScript = load(REGISTRY[npc_id]["dialog"])
	return script.DATA


static func make_npc(npc_id: String) -> NPC:
	var cfg: Dictionary = REGISTRY[npc_id]
	var area := NPC.new()
	area.name = npc_id.capitalize()
	area.npc_data = build_data(npc_id)
	area.dialog_data = dialog_data(npc_id)
	area.has_shop = bool(cfg.get("has_shop", false))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(cfg["sprite"])
	area.add_child(sprite)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 32)
	col.shape = shape
	area.add_child(col)
	return area
