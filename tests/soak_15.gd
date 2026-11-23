extends "res://tests/realtime_flight.gd"
## One actual process and a 15-minute flight session, including the normal results/restart path.

const REQUIRED_SECONDS := 900.0
const SOAK_LIMIT := 1140.0


func _run() -> void:
	var entry := load("res://main.tscn") as PackedScene
	game = entry.instantiate()
	var path := "user://qa-15min-%d" % Time.get_ticks_usec()
	game.progression.save_path = path
	game.progression.legacy_path = ""
	root.add_child(game)
	_prepare_loadout()
	if not await _click("LaunchButton"):
		quit(1)
		return
	_watch_arena()
	game.arena._rng.seed = 976_138
	var started := Time.get_ticks_msec()
	var completed := 0.0
	var victories := 0
	var next_log := 60.0
	while _wall_seconds(started) < SOAK_LIMIT:
		var combat_time := completed + _seconds()
		var elapsed := _wall_seconds(started)
		if elapsed >= REQUIRED_SECONDS and combat_time >= REQUIRED_SECONDS:
			break
		if combat_time >= next_log:
			print("SOAK %.1f s in mission / %.1f s wall, active enemies %d" %
				[combat_time, elapsed, game.arena.active_enemy_count()])
			next_log += 60.0
		match game.phase:
			"combat", "upgrade":
				await _pilot_step()
			"revive":
				_release_actions()
				await _click("DeclineReviveButton")
			"result":
				_release_actions()
				completed += float(finished.get("seconds", 0.0))
				victories += int(bool(finished.get("boss_defeated", false)))
				if not await _click("RestartButton"):
					break
				_watch_arena()
				game.arena._rng.seed = 976_138
			_:
				_check(false, "unexpected screen during 15-minute session")
				break
	_release_actions()
	print("SOAK result wall=%.2f mission=%.2f completed_boss_victories=%d" %
		[_wall_seconds(started), completed + _seconds(), victories])
	_check(_wall_seconds(started) >= REQUIRED_SECONDS and completed + _seconds() >= REQUIRED_SECONDS,
		"15 real minutes and 15 gameplay minutes elapsed in one process")
	_check(victories > 0, "session completed a boss victory and restarted")
	print("QA soak 15: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
