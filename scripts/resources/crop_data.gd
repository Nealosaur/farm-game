class_name CropData
extends Resource
## stage_days[i] = watered days needed to leave growth stage i.
## Sprite convention: assets/placeholder/crop_<id>_<0..stage_days.size()>.png
## (last sprite index = ripe).

@export var id: String = ""
@export var stage_days: Array[int] = [1, 1, 1]
@export var product_id: String = ""
## Season indices this crop can be planted in (Clock: 0 Spring .. 3 Winter).
## Standing crops whose seasons exclude the new season WILT at the rollover.
@export var seasons: Array[int] = [0]
## 0 = single harvest (crop cleared). >0 = after harvest the crop stays at
## its final growth stage and re-ripens after this many watered days (see
## FarmGrid's "regrown" plot flag).
@export var regrow_days: int = 0
