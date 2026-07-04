class_name CropData
extends Resource
## stage_days[i] = watered days needed to leave growth stage i.
## Sprite convention: assets/placeholder/crop_<id>_<0..stage_days.size()>.png
## (last sprite index = ripe).

@export var id: String = ""
@export var stage_days: Array[int] = [1, 1, 1]
@export var product_id: String = ""
