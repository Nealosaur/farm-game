extends GutTest
## Craft Stride 1: HUD's small "+N ATK" buff indicator — hidden with no buff
## active, shown with the right text while GameState.temp_attack > 0, and
## hidden again once the buff clears.

var hud: Hud


func before_each() -> void:
	GameState.reset_new_game()
	hud = (load("res://scripts/ui/hud.gd") as GDScript).new() as Hud
	add_child_autofree(hud)


func test_buff_label_hidden_with_no_buff() -> void:
	assert_false(hud.buff_label.visible)


func test_buff_label_shown_with_text_while_buff_active() -> void:
	GameState.set_temp_attack(2)
	assert_true(hud.buff_label.visible)
	assert_eq(hud.buff_label.text, "+2 ATK")


func test_buff_label_hides_again_after_clear() -> void:
	GameState.set_temp_attack(2)
	GameState.clear_temp_attack()
	assert_false(hud.buff_label.visible)


func test_buff_label_updates_on_replace() -> void:
	GameState.set_temp_attack(2)
	GameState.set_temp_attack(5)
	assert_eq(hud.buff_label.text, "+5 ATK")
