class_name ToolData
extends ItemData

enum ToolType { HOE, WATERING_CAN, SWORD }

@export var tool_type: ToolType = ToolType.HOE
@export var rp_cost: int = 2
@export var damage: int = 0  # swords only
## Craft Stride 2 (Forging): watering cans only. 1 = single target cell
## (every pre-Forge can). 3 = target cell + the two cells flanking it
## PERPENDICULAR to the player's facing (Copper Watering Can). Generic field
## (not hardcoded to any item id) so a future wider can just sets a bigger
## odd number — see FarmGrid.water_cells_for()/player.gd's _use_tool() for
## the consumer.
@export var water_width: int = 1
## DEPTH stride (tool tiers): hoes only. Same "1 = single target cell, 3 =
## target + 2 flanking cells" contract as water_width, reusing the identical
## FarmGrid.flanking_cells() geometry (see FarmGrid.till_wide()) — a tiered
## hoe tills a small row the same way the Copper Watering Can waters one.
@export var till_width: int = 1
