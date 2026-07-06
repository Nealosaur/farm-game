extends GutTest
## Alive Stride 2 (I1 coverage gap): EventDirector's own bookkeeping —
## world["events_seen"] "one scene per day" enforcement (_any_fired_day),
## seen-forever marking, never stacking two EventRunners, and the
## JSON-round-trip coercion the persisted blob must survive (ints come back
## as floats — see save_manager.gd's sanctioned "events_seen" key doc and
## TriggerService's int() coercion in fires_at_most_once_per_day()/
## seen_today()). Uses trivial single-command scripts ("end" or a short
## "wait") rather than any real map/dialog dependency — EventDirector only
## needs a Node to host the EventRunner child and a `finished` signal to
## react to, both of which a bare scene script provides.

var director: EventDirector


func before_each() -> void:
	Clock.day = 1
	SaveManager.world.erase("events_seen")


func after_each() -> void:
	Clock.day = 1
	SaveManager.world.erase("events_seen")


func _scene(id: String, preconditions: Dictionary = {}) -> Dictionary:
	return {"id": id, "preconditions": preconditions, "script": ["end"]}


func _make_director(candidates: Array[Dictionary]) -> EventDirector:
	var d := EventDirector.new()
	d.current_map_id = "test_map"
	d.candidates = candidates
	add_child_autofree(d)
	return d


## ---- events_seen: marking on completion ----

func test_check_plays_the_first_qualifying_candidate() -> void:
	director = _make_director([_scene("scene_a")])
	watch_signals(director)
	director.check()
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(director, "scene_played", ["scene_a"])


func test_check_marks_scene_seen_forever_once_it_finishes() -> void:
	director = _make_director([_scene("scene_a")])
	director.check()
	await wait_process_frames(2)
	var seen: Dictionary = SaveManager.world.get("events_seen", {})
	assert_true(TriggerService.seen_forever(seen, "scene_a"))


func test_check_marks_any_fired_day_once_it_finishes() -> void:
	director = _make_director([_scene("scene_a")])
	director.check()
	await wait_process_frames(2)
	var seen: Dictionary = SaveManager.world.get("events_seen", {})
	assert_eq(int(seen.get("_any_fired_day", -1)), Clock.day)


func test_check_never_plays_a_second_scene_the_same_day_even_if_the_first_is_seen_forever_gated_out() -> void:
	## "One scene per day" (_any_fired_day) — not just "one scene per id".
	## After scene_a fires and finishes, scene_b (a DIFFERENT id, otherwise
	## eligible) must NOT fire later the same day.
	director = _make_director([_scene("scene_a")])
	director.check()
	await wait_process_frames(2)
	watch_signals(director)
	director.candidates = [_scene("scene_b")]
	director.check()
	await wait_process_frames(2)
	assert_signal_emit_count(director, "scene_played", 0, "no second scene may fire the same day")


func test_check_allows_a_new_scene_the_next_day() -> void:
	director = _make_director([_scene("scene_a")])
	director.check()
	await wait_process_frames(2)
	Clock.day = 2
	watch_signals(director)
	director.candidates = [_scene("scene_b")]
	director.check()
	await wait_process_frames(2)
	assert_signal_emitted_with_parameters(director, "scene_played", ["scene_b"])


## ---- never stacks two runners ----

func test_check_no_ops_while_a_scene_is_already_playing() -> void:
	# A script that does NOT finish within the first check() (a long `wait`)
	# so a second check() call lands while the first scene is still playing.
	director = _make_director([{"id": "busy_scene", "preconditions": {}, "script": ["wait 60", "end"]}])
	director.check()
	await wait_process_frames(1)
	var child_count_after_first := director.get_child_count()
	director.check()  # must no-op: _playing is true
	await wait_process_frames(1)
	assert_eq(director.get_child_count(), child_count_after_first, "must not stack a second EventRunner while one is playing")


## ---- world["events_seen"] JSON round-trip (coercion) ----

func test_events_seen_blob_survives_json_round_trip() -> void:
	var seen := TriggerService.mark_seen_forever({}, "scene_a")
	seen = TriggerService.mark_seen_today(seen, "scene_daily", 3)
	seen = TriggerService.mark_any_fired_today(seen, 3)
	var round_tripped = JSON.parse_string(JSON.stringify(seen))
	assert_true(TriggerService.seen_forever(round_tripped, "scene_a"))
	assert_eq(typeof(round_tripped.get("scene_daily")), TYPE_FLOAT,
		"JSON round-trips ints as floats — seen_today()/callers must int() coerce")
	assert_true(TriggerService.seen_today(round_tripped, "scene_daily", 3))
	assert_false(TriggerService.seen_today(round_tripped, "scene_daily", 4))
	assert_eq(typeof(round_tripped.get("_any_fired_day")), TYPE_FLOAT)
	assert_false(TriggerService.fires_at_most_once_per_day(round_tripped, 3))
	assert_true(TriggerService.fires_at_most_once_per_day(round_tripped, 4))


func test_director_check_respects_a_json_round_tripped_seen_blob() -> void:
	## End-to-end: persist events_seen through an actual JSON round trip (as
	## save_game()/load_game() would) and confirm EventDirector.check() still
	## correctly refuses to re-fire a seen-forever scene / a same-day cap.
	var seen := TriggerService.mark_seen_forever({}, "scene_a")
	seen = TriggerService.mark_any_fired_today(seen, Clock.day)
	SaveManager.world["events_seen"] = JSON.parse_string(JSON.stringify(seen))
	director = _make_director([_scene("scene_a")])
	watch_signals(director)
	director.check()
	await wait_process_frames(2)
	assert_signal_emit_count(director, "scene_played", 0)
