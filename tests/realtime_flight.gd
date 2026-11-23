extends "res://tests/smoke.gd"
## Runs a full mission using real elapsed time and normal physics/input.
## Starts from a disposable profile with a midgame loadout.

const MINIMUM_WALL_TIME := 600.0
const MAXIMUM_WALL_TIME := 750.0


func _run() -> void:
	var entry := load("res://main.tscn") as PackedScene
	game = entry.instantiate()
	var path := "user://qa-realtime-%d" % Time.get_ticks_usec()
	game.progression.save_path = path
	game.progression.legacy_path = path + "-legacy.cfg"
	root.add_child(game)
	_prepare_loadout()
	await _frames(18)
	var started := Time.get_ticks_msec()
	if not await _click("LaunchButton"):
		quit(1)
		return
	_watch_arena()
	game.arena._rng.seed = 976_138
	var reached := 0.0
	var sample_at := started + 1000
	var fps_samples := PackedFloat64Array()
	while game.phase in ["combat", "upgrade"] and _wall_seconds(started) < MAXIMUM_WALL_TIME:
		await _pilot_step()
		if Time.get_ticks_msec() >= sample_at:
			sample_at = Time.get_ticks_msec() + 1000
			if DisplayServer.get_name() != "headless" and game.phase == "combat":
				fps_samples.append(Engine.get_frames_per_second())
		if _seconds() >= reached:
			print("REALTIME progress: %.2fs mission / %.2fs wall" % [_seconds(), _wall_seconds(started)])
			reached += 60.0
	_release_actions()
	var elapsed := _wall_seconds(started)
	print("REALTIME result: ", finished, " wall_seconds=", elapsed)
	if not fps_samples.is_empty():
		fps_samples.sort()
		print("REALTIME desktop fps samples=%d p05=%.1f p50=%.1f highest=%.1f" %
			[fps_samples.size(), fps_samples[floori(fps_samples.size() * 0.05)],
			fps_samples[fps_samples.size() >> 1], fps_samples[-1]])
	_check(elapsed >= MINIMUM_WALL_TIME, "flight was exercised for at least ten real minutes")
	_check(game.phase == "result" and bool(finished.get("boss_defeated", false)), "real-time sortie defeated Leviathan")
	_check(is_equal_approx(float(finished.get("seconds", 0.0)), MISSION_LENGTH), "real-time sortie completes all 600 gameplay seconds")
	for index in 2:
		var slot := "%s.%d.json" % [path, index]
		if FileAccess.file_exists(slot):
			DirAccess.remove_absolute(slot)
	print("QA realtime: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _prepare_loadout() -> void:
	var pilot = game.progression
	for index in 4:
		pilot.credit_mission({"won": true, "seconds": 600.0, "kills": 1000, "reward": 450}, "peryhelium")
	pilot.apply("select_ship", "aegis")
	for item in ["pulse_coil", "titanium_plate", "trim_nozzle", "flux_cell", "escort_bay"]:
		pilot.apply("equip", item)
	for index in 3:
		for track in ["hull", "drive", "output"]:
			pilot.apply("upgrade", track)
	game.ui.show_menu(pilot.sortie())
	print("REALTIME fixture: ", pilot.sortie())


func _wall_seconds(started: int) -> float:
	return (Time.get_ticks_msec() - started) * 0.001
