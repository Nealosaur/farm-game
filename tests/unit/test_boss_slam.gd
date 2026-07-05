extends GutTest
## BossSlam: emits camera_shake when the slam actually lands (telegraph ->
## active transition), not on entering the telegraph itself.

var boss: SlimeKing
var slam: BossSlam


func before_each() -> void:
	GameState.flags = {}
	boss = (load("res://scenes/enemies/slime_king.tscn") as PackedScene).instantiate()
	boss.enemy_id = "slime_king"
	add_child_autofree(boss)
	slam = boss.machine.get_node("Slam") as BossSlam


func test_entering_slam_does_not_shake_yet() -> void:
	watch_signals(EventBus)
	boss.machine.transition("Slam")
	assert_signal_not_emitted(EventBus, "camera_shake")


func test_slam_landing_emits_camera_shake() -> void:
	watch_signals(EventBus)
	boss.machine.transition("Slam")
	slam.physics_update(BossSlam.TELEGRAPH_DURATION + 0.01)
	assert_signal_emitted(EventBus, "camera_shake")
