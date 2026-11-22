extends SceneTree
## Exercises the normal entry scene and routes real GUI, keyboard and touch events through Godot.

const ARROWS := [&"move_left", &"move_right", &"move_up", &"move_down"]
const MISSION_LENGTH := 240.0

var game: Node
var capture_dir := ""
var expected_size := Vector2i.ZERO
var full_mission := false
var late_capture := false
var finished: Dictionary
var offered: Array
var selected_upgrade := ""
var pilot_hp := 100.0
var max_hp := 100.0
var failures := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	full_mission = args.has("--full-mission")
	late_capture = args.has("--late-capture")
	var capture_index := args.find("--capture-dir")
	if capture_index >= 0 and capture_index + 1 < args.size():
		capture_dir = args[capture_index + 1]
		var size_index := args.find("--expect-size")
		if size_index >= 0 and size_index + 1 < args.size():
			var dimensions := args[size_index + 1].split("x")
			expected_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	_run.call_deferred()


func _run() -> void:
	var entry := load("res://main.tscn") as PackedScene
	if not _check(entry != null, "main scene loads"):
		quit(1)
		return
	game = entry.instantiate()
	if not _check(game.get_script() != null and game.get_script().can_instantiate(), "main script compiles"):
		game.free()
		quit(1)
		return
	root.add_child(game)
	game.ui.upgrade_selected.connect(func(id: String) -> void: selected_upgrade = id)
	await _frames(20)
	if not _check(game.phase == "menu", "normal startup shows menu"):
		quit(1)
		return
	if late_capture:
		await _capture_late_combat()
		quit(0 if failures == 0 else 1)
		return
	if not await _capture("menu") or not await _click("LaunchButton"):
		quit(1)
		return
	if not _check(game.phase == "combat" and is_instance_valid(game.arena), "launch button starts mission"):
		quit(1)
		return
	_watch_arena()
	await _test_movement()
	await _advance_to(3.5)
	if not capture_dir.is_empty():
		await _wait_for_combat_frame()
	if not await _capture("walka"):
		quit(1)
		return
	if not await _until_upgrade():
		quit(1)
		return
	_check(game.arena._kills >= 3 and game.arena._level == 2, "autofire kills enemies and pickups award level two")
	_check(offered.size() == 3, "first level-up offers three cards")
	var distinct := {}
	for card: Dictionary in offered:
		distinct[card.id] = true
	_check(distinct.size() == 3, "the three upgrade IDs are distinct")
	for i in 3:
		_check(_button("UpgradeButton%d" % i) != null, "upgrade %d has a visible button" % (i + 1))
	if not await _capture("ulepszenie"):
		quit(1)
		return
	var upgrade_at := _seconds()
	await _steps(20)
	_check(is_equal_approx(_seconds(), upgrade_at), "simulation clock freezes while choosing an upgrade")
	var expected_id: String = offered[0].id
	await _click("UpgradeButton0")
	_check(selected_upgrade == expected_id, "the clicked card emits its matching upgrade ID")
	_check(game.arena._loadout.rank(expected_id) == 1, "the selected upgrade is applied to the ship loadout")
	_check(game.phase == "combat", "selecting one card resumes combat")
	await _click("PauseButton")
	_check(game.phase == "pause", "pause button opens pause overlay")
	var paused_at := _seconds()
	await _steps(40)
	_check(is_equal_approx(_seconds(), paused_at), "simulation clock freezes under pause")
	await _click("ResumeButton")
	_check(game.phase == "combat", "resume button returns to combat")
	await _steps(15)
	_check(_seconds() > paused_at, "simulation clock advances after resume")
	await _click("PauseButton")
	var previous_arena_id: int = game.arena.get_instance_id()
	await _click("RestartButton")
	_check(game.phase == "combat" and game.arena.get_instance_id() != previous_arena_id, "restart creates a fresh combat arena")
	_check(_seconds() < 1.0, "restart resets mission clock")
	_check(game.arena._hp == game.arena._max_hp and game.arena._level == 1, "restart restores full HP and level one")

	if capture_dir.is_empty():
		await _test_defeat()
	if full_mission:
		await _test_completion()

	print("QA: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _test_movement() -> void:
	var start: Vector2 = game.arena._player_position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await _steps(14)
	key = key.duplicate() as InputEventKey
	key.pressed = false
	Input.parse_input_event(key)
	await _steps(2)
	var after_key: Vector2 = game.arena._player_position
	_check(after_key.x > start.x + 8.0, "physical D key moves ship right")

	var touch_at := root.get_visible_rect().size * Vector2(0.5, 0.60)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = touch_at
	touch.pressed = true
	root.push_input(touch, true)
	for i in 8:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = touch_at + Vector2(-10 * (i + 1), 0)
		drag.relative = Vector2(-10, 0)
		drag.screen_relative = drag.relative
		root.push_input(drag, true)
		await physics_frame
	await _steps(12)
	var after_touch: Vector2 = game.arena._player_position
	touch = touch.duplicate() as InputEventScreenTouch
	touch.pressed = false
	touch.position = touch_at + Vector2(-80, 0)
	root.push_input(touch, true)
	await _steps(2)
	_check(after_touch.x < after_key.x - 8.0, "single-finger drag moves ship left")


func _until_upgrade() -> bool:
	var deadline := _seconds() + 45.0
	while game.phase == "combat" and _seconds() < deadline:
		_collect_xp()
		await _steps(5)
	_release_actions()
	await _frames(18)
	return _check(game.phase == "upgrade", "autofire and collected XP produce a real level-up")


func _test_defeat() -> void:
	_watch_arena()
	for attempt in 12:
		if game.phase == "result" or _seconds() > 130.0:
			break
		await _advance_to(_seconds() + 12.0)
		if game.phase == "upgrade":
			await _click("UpgradeButton0")
	if not _check(game.phase == "result" and not finished.get("won", true), "unmanned ship reaches natural defeat result"):
		return
	_check(finished.get("seconds", 0.0) > 0.0, "defeat reports elapsed play time")
	await _click("RestartButton")
	_check(game.phase == "combat", "result restart begins a new run")
	await _click("PauseButton")
	await _click("MenuButton")
	_check(game.phase == "menu", "pause menu button returns to title")


func _test_completion() -> void:
	if game.phase != "menu":
		return
	var won := false
	var victory_at := 0.0
	for seed_value in [976_138, 473_240, 295_820]:
		await _click("LaunchButton")
		_watch_arena()
		game.arena._rng.seed = seed_value
		for step in 4000:
			if game.phase != "combat" and game.phase != "upgrade":
				break
			await _pilot_step()
		_release_actions()
		print("QA mission result (wave seed %d): " % seed_value, finished)
		if game.phase == "result":
			won = finished.get("won", false)
			victory_at = float(finished.get("seconds", 0.0))
			await _click("MenuButton")
			_check(game.phase == "menu", "result menu button returns to title")
		if won or game.phase != "menu":
			break
	_check(won, "scripted input survives the complete mission")
	_check(absf(victory_at - MISSION_LENGTH) < 0.25, "winning result is reached at 240 seconds")


func _pilot_step() -> void:
	if game.phase == "upgrade":
		_release_actions()
		await _click("UpgradeButton%d" % _winning_choice())
	else:
		_survive()
		await _steps(5)


func _capture_late_combat() -> void:
	if not _check(not capture_dir.is_empty(), "late capture receives an output directory"):
		return
	if not await _click("LaunchButton"):
		return
	_watch_arena()
	game.arena._rng.seed = 473_240
	Engine.physics_ticks_per_second = 120
	Engine.time_scale = 2.0
	var best_kind_count := 0
	for step in 1600:
		if game.phase == "result" or _seconds() > 110.0:
			break
		if game.phase == "combat" and _seconds() >= 64.0:
			var visible := _visible_enemies()
			if visible.count >= 3 and visible.kinds > best_kind_count:
				if not await _capture("walka-fala"):
					break
				print("QA late scene %.2fs: %d fully visible ships, %d types" % [_seconds(), visible.count, visible.kinds])
				best_kind_count = visible.kinds
				if best_kind_count == 3:
					break
		await _pilot_step()
	_release_actions()
	_check(best_kind_count >= 2, "late combat frame contains ships from multiple enemy types")


func _visible_enemies() -> Dictionary:
	var viewport := root.get_visible_rect().size
	var world_offset: Vector2 = viewport * 0.5 - game.arena._camera
	var interior := Rect2(Vector2(45.0, 100.0), viewport - Vector2(90.0, 178.0))
	var kinds := {}
	var count := 0
	for enemy in game.arena._enemies:
		if interior.has_point(enemy.position + world_offset):
			kinds[enemy.kind] = true
			count += 1
	return {"count": count, "kinds": kinds.size()}


func _wait_for_combat_frame() -> void:
	for step in 210:
		if game.phase != "combat":
			return
		if _visible_enemies().count > 0 and not game.arena._shots.is_empty():
			return
		await physics_frame


func _winning_choice() -> int:
	var ranked := ["missiles", "pulse_damage", "nova", "shield", "pulse_cadence", "repair", "thruster", "tractor"]
	if pilot_hp < max_hp * 0.65:
		ranked.erase("repair")
		ranked.push_front("repair")
	var choice := 0
	var best := ranked.size()
	for i in offered.size():
		var rank := ranked.find(offered[i].id)
		if rank >= 0 and rank < best:
			choice = i
			best = rank
	return choice


func _survive() -> void:
	var position: Vector2 = game.arena._player_position
	var drift := Vector2.from_angle(_seconds() * 0.74)
	var danger := Vector2.ZERO
	for enemy in game.arena._enemies:
		var offset: Vector2 = position - enemy.position
		var range_px := 255.0 if enemy.kind == game.arena.EnemyKind.LANCER else 145.0
		var separation := offset.length()
		if separation < range_px:
			danger += offset.normalized() * (1.0 - separation / range_px) * 3.0
	var attraction := _xp_direction(drift)
	var arena_bounds: Rect2 = game.arena.ARENA
	var return_to_center := (arena_bounds.get_center() - position) / (arena_bounds.size * 0.5)
	if absf(return_to_center.x) > 0.78 or absf(return_to_center.y) > 0.78:
		attraction = return_to_center.normalized() * 1.8
	var movement := (attraction + danger).normalized()
	for shot in game.arena._shots:
		if shot.kind != game.arena.ShotKind.HOSTILE:
			continue
		var incoming: Vector2 = shot.velocity - movement * 238.0
		var projected: Vector2 = Geometry2D.get_closest_point_to_segment(position, shot.position, shot.position + incoming * 0.55)
		var slide: Vector2 = position - projected
		if slide.length_squared() < 52.0 * 52.0:
			movement = (movement + slide.normalized() * 2.4).normalized()
	_drive(movement)


func _collect_xp() -> void:
	_drive(_xp_direction(Vector2.ZERO))


func _xp_direction(fallback: Vector2) -> Vector2:
	var position: Vector2 = game.arena._player_position
	var closest := INF
	var direction := fallback
	for orb in game.arena._xp_orbs:
		var offset: Vector2 = orb.position - position
		var distance := offset.length_squared()
		if distance < closest:
			closest = distance
			direction = offset.normalized()
	return direction


func _drive(direction: Vector2) -> void:
	var active := [
		direction.x < -0.20, direction.x > 0.20,
		direction.y < -0.20, direction.y > 0.20,
	]
	for i in ARROWS.size():
		if active[i]:
			Input.action_press(ARROWS[i])
		else:
			Input.action_release(ARROWS[i])


func _release_actions() -> void:
	_drive(Vector2.ZERO)


func _watch_arena() -> void:
	offered = []
	finished = {}
	game.arena.upgrade_requested.connect(func(cards: Array[Dictionary]) -> void: offered = cards)
	game.arena.mission_ended.connect(func(result: Dictionary) -> void: finished = result)
	game.arena.telemetry.connect(func(data: Dictionary) -> void:
		pilot_hp = float(data.hp)
		max_hp = float(data.max_hp)
	)


func _seconds() -> float:
	return float(game.arena._mission_time) if is_instance_valid(game.arena) else 0.0


func _advance_to(target: float) -> void:
	var allowance := int(maxf(0.0, target - _seconds()) * 60.0) + 180
	for i in allowance:
		if game.phase != "combat" or _seconds() >= target:
			return
		await physics_frame
	_check(false, "active simulation advances while waiting for %.1f seconds" % target)


func _steps(count: int) -> void:
	for i in count:
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _button(button_name: String) -> BaseButton:
	for candidate in game.find_children(button_name, "BaseButton", true, false):
		if candidate.is_visible_in_tree() and not candidate.disabled:
			return candidate
	return null


func _click(button_name: String) -> bool:
	await _frames(3)
	var button := _button(button_name)
	if not _check(button != null, "%s is available" % button_name):
		return false
	var bounds := button.get_global_rect()
	if not _check(root.get_visible_rect().encloses(bounds), "%s stays inside the viewport" % button_name):
		return false
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = bounds.get_center()
		event.global_position = event.position
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await _frames(18)
	return true


func _capture(label: String) -> bool:
	if capture_dir.is_empty():
		return true
	for candidate in game.find_children("*", "BaseButton", true, false):
		if candidate.is_visible_in_tree():
			_check(root.get_visible_rect().encloses(candidate.get_global_rect()), "%s visible button %s fits" % [label, candidate.name])
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if not _check(frame != null and not frame.is_empty(), "Godot rendered the %s frame" % label):
		return false
	if not _check(frame.get_size() == expected_size, "%s image has exact %s raster size" % [label, expected_size]):
		return false
	if label == "walka":
		print("QA desktop frame-rate snapshot: %d fps at %s (%s)" % [Engine.get_frames_per_second(), expected_size, RenderingServer.get_video_adapter_name()])
	var path := capture_dir.path_join("%dx%d-%s.png" % [expected_size.x, expected_size.y, label])
	return _check(frame.save_png(path) == OK, "saved native game frame: %s" % path)


func _check(condition: bool, description: String) -> bool:
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		printerr("FAIL: ", description)
	return condition
