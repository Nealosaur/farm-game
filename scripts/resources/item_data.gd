class_name ItemData
extends Resource
## Base type for everything that can sit in the inventory.

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var max_stack: int = 99
@export var buy_price: int = 0   # 0 = not sold in the store
@export var sell_price: int = 0  # 0 = cannot be sold
