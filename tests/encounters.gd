extends "res://tests/smoke.gd"
## Focused encounter fixtures enter gameplay immediately before each scheduled warning.
## They use ordinary movement and attacks while tracing telegraph and attack transitions.
## Headless fixtures suppress escort spawns so both bosses can run complete attack cycles.

const WARNING_LEAD := 10.0
const CAPTURE_SCALE := 2.0


func _run() -> void:
	var entry := load("res://main.tscn") as PackedScene
	if entry == null:
		quit(1)
		return
	game = entry.instantiate()
	if not _check(game.get_script() != null and game.get_script().can_instantiate(), "main script compiles for encounter fixtures"):
		game.free()
		quit(1)
		return
	root.add_child(game)
	await _frames(20)
	if not capture_dir.is_empty():
		Engine.physics_ticks_per_second = 120
		Engine.time_scale = CAPTURE_SCALE
	await _encounter(false)
	await _return_to_title()
	await _encounter(true)
	print("QA encounter fixtures: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _encounter(final_boss: bool) -> void:
	if not await _click("LaunchButton"):
		return
	_watch_arena()
	var director = game.arena._director
	var encounter_time := float(director.BOSS_AT if final_boss else director.MINIBOSS_AT)
	var enemy_kind: int = game.arena.EnemyKind.BOSS if final_boss else game.arena.EnemyKind.MINIBOSS
	var label := "boss" if final_boss else "miniboss"
	game.arena._rng.seed = 104_805
	game.arena._mission_time = encounter_time - WARNING_LEAD
	if capture_dir.is_empty():
		game.arena._spawn_timer = MISSION_LENGTH
		if final_boss:
			director._miniboss_spawned = true

	var warning_seen := false
	var boss_hud_seen := false
	var attack_capture := false
	var telegraphs := {}
	var released := {}
	var charging := -1
	for step in 900:
		if game.phase == "result":
			break
		var boss = _find_boss(enemy_kind)
		if game.phase == "combat":
			if not warning_seen and boss == null and _visible_control("BossWarning") != null:
				warning_seen = true
				await _capture("%s-alert" % label)
			if boss != null:
				boss_hud_seen = boss_hud_seen or _visible_control("BossHUD") != null
				if boss.charge > 0.0 and boss.pattern >= 0:
					charging = boss.pattern
					telegraphs[charging] = true
					if not attack_capture and boss_hud_seen and _boss_inside_view(boss.position):
						attack_capture = await _capture("%s-attack" % label)
				elif charging >= 0:
					released[charging] = true
					charging = -1
		if capture_dir.is_empty():
			if released.size() == 3:
				break
			await _orbit_for_patterns(boss)
		else:
			if attack_capture:
				break
			await _align_for_capture(boss)

	_release_actions()
	_check(warning_seen, "%s has a visible pre-arrival warning" % label)
	_check(boss_hud_seen, "%s exposes its active HP bar" % label)
	if capture_dir.is_empty():
		_check(telegraphs.has(0) and telegraphs.has(1) and telegraphs.has(2), "%s telegraphs three patterns" % label)
		_check(released.has(0) and released.has(1) and released.has(2), "%s completes all three windups" % label)
		if final_boss and game.phase == "combat":
			await _deadline_without_defeating_boss()
	else:
		_check(attack_capture, "%s telegraph and ship were captured in the viewport" % label)


func _orbit_for_patterns(boss) -> void:
	if game.phase != "combat" or boss == null:
		await _pilot_step()
		return
	var player: Vector2 = game.arena._player_position
	var offset: Vector2 = player - boss.position
	var orbit := offset.normalized()
	var correction := clampf((255.0 - offset.length()) / 100.0, -1.4, 1.4)
	var movement := (orbit.orthogonal() + orbit * correction).normalized()
	if boss.charge > 0.0:
		movement = _dodge_boss(player, movement, boss)
	_drive(movement)
	await _steps(5)


func _align_for_capture(boss) -> void:
	if game.phase != "combat" or boss == null:
		await _pilot_step()
		return
	var player: Vector2 = game.arena._player_position
	var framing_point: Vector2 = boss.position + Vector2(0.0, 218.0)
	_drive(player.direction_to(framing_point))
	await _steps(5)


func _find_boss(kind: int):
	for enemy in game.arena._enemies:
		if enemy.kind == kind:
			return enemy
	return null


func _boss_inside_view(position: Vector2) -> bool:
	var viewport := root.get_visible_rect().size
	var world_offset: Vector2 = viewport * 0.5 - game.arena._camera
	var inner_rect := Rect2(Vector2(100.0, 155.0), viewport - Vector2(200.0, 250.0))
	return inner_rect.has_point(position + world_offset)


func _deadline_without_defeating_boss() -> void:
	if not _check(not game.arena._director._boss_defeated, "final boss remains alive in the timeout fixture"):
		return
	game.arena._mission_time = MISSION_LENGTH - 0.25
	await _advance_to(MISSION_LENGTH + 0.1)
	_check(game.phase == "result" and not finished.get("won", true), "mission times out without a defeated final boss")
	_check(float(finished.get("seconds", 0.0)) == MISSION_LENGTH, "timeout result reports 600 seconds")
	_check(int(finished.get("reward", -1)) == _earned_salvage(), "timeout reports earned salvage without a victory bonus")


func _return_to_title() -> void:
	if game.phase == "upgrade":
		await _click("UpgradeButton0")
	if game.phase == "combat":
		await _click("PauseButton")
	if game.phase == "pause" or game.phase == "result":
		await _click("MenuButton")
