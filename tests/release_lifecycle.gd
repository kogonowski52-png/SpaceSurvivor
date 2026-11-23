extends "res://tests/smoke.gd"

const PATH := "user://qa-release-relaunch"


func _run() -> void:
	var entry := load("res://main.tscn") as PackedScene
	game = entry.instantiate()
	game.progression.save_path = PATH
	game.progression.legacy_path = ""
	root.add_child(game)
	await _frames(8)
	if OS.get_cmdline_user_args().has("--verify-relaunch"):
		var profile: Dictionary = game.progression.snapshot().profile
		_check(game.phase == "menu" and game.arena == null, "the new process opens a clean menu")
		_check(profile.levels.get("peregrine", {}).get("hull") == 1, "committed upgrade survives process termination")
		_check(profile.totals.flights == 0, "an interrupted flight does not award a result")
		if await _click("LaunchButton"):
			_check(game.phase == "combat" and _seconds() < 2.0, "fresh sortie starts after process relaunch")
		quit(0 if failures == 0 else 1)
		return
	_check(game.progression.apply("upgrade", "hull").ok, "commits the fixture upgrade to disk")
	if await _click("LaunchButton"):
		await _steps(12)
		game.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		var paused_at := _seconds()
		await _steps(12)
		_check(game.phase == "pause" and is_equal_approx(paused_at, _seconds()), "focus loss pauses the flight clock")
		game.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
		_check(game.phase == "pause", "focus return preserves the pause")
		await _click("ResumeButton")
		_check(game.phase == "combat", "player can choose to resume after backgrounding")
	if failures:
		quit(1)
		return
	print("READY_FOR_TERMINATION")
