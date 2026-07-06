class_name FoodData
extends ItemData

@export var rp_restore: int = 0
@export var hp_restore: int = 0
## Craft Stride 1: cooked buff food. 0 = no buff. Eating sets
## GameState.temp_attack to this value (replace, not stack) — see player.gd's
## _eat() and GameState.set_temp_attack().
@export var attack_bonus: int = 0
## Craft Stride 1: true for cooked dishes (RecipeData results). Drives the
## Relationships.gift() cooked-gift x1.5 rule and defaults dishes to "liked"
## for every NPC unless explicitly loved/disliked (see gift resolution order
## in relationships.gd).
@export var is_dish: bool = false
