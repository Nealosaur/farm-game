class_name BossHealthBar
extends CanvasLayer
## Simple HUD-level ProgressBar shown while the boss is alive. dungeon_3
## builds one and calls track(boss) after spawning it; freed with the floor
## like any other scene-local node (no group/autoload wiring needed since the
## floor script holds the reference directly).

var bar: ProgressBar
var label: Label
var _health: HealthComponent


func _ready() -> void:
	layer = 9
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_WIDE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-100, 8)
	box.custom_minimum_size = Vector2(200, 0)
	root.add_child(box)

	label = Label.new()
	label.text = "Slime King"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UITheme.TEXT_LIGHT)
	box.add_child(label)

	bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 14)
	bar.show_percentage = false
	var styles := UITheme.bar_styleboxes(Color("60c060"))
	bar.add_theme_stylebox_override("background", styles["bg"])
	bar.add_theme_stylebox_override("fill", styles["fill"])
	box.add_child(bar)

	visible = false


func track(boss: SlimeKing) -> void:
	_health = boss.health
	bar.max_value = _health.max_hp
	bar.value = _health.hp
	visible = true
	# Named methods only (project convention).
	_health.damaged.connect(_on_boss_damaged)
	_health.died.connect(_on_boss_died)


func _on_boss_damaged(_amount: int) -> void:
	if _health != null:
		bar.value = _health.hp


func _on_boss_died() -> void:
	visible = false
