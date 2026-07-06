class_name RecipeData
extends Resource
## Cooking recipe (Craft Stride 1). ingredients maps item_id -> required count;
## result_id is the FoodData (dish) produced. All recipes are known from the
## start this phase (bible: "recipe discovery... out of Phase 2").

@export var id: String = ""
@export var ingredients: Dictionary = {}  # item_id (String) -> count (int)
@export var result_id: String = ""
