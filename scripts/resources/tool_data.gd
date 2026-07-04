class_name ToolData
extends ItemData

enum ToolType { HOE, WATERING_CAN, SWORD }

@export var tool_type: ToolType = ToolType.HOE
@export var rp_cost: int = 2
@export var damage: int = 0  # swords only
