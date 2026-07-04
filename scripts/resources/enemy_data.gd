class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var max_hp: int = 10
@export var damage: int = 1
@export var speed: float = 40.0
@export var xp: int = 5
@export var gold_min: int = 1
@export var gold_max: int = 3
@export var drop_item_id: String = ""
@export var drop_chance: float = 0.5
# Reserved for Phase 2 taming — populated but unused in the slice.
@export var tameable: bool = false
@export var favorite_food: String = ""
