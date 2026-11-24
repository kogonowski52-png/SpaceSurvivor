extends "res://tests/vertical_campaign.gd"
## Reuses the live scene and UI controls for comparable captures, video and timed desktop rendering.


func _run() -> void:
	var entry := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	game = entry.instantiate()
	game.progression.save_path = profile_path + "-visual"
	game.progression.legacy_path = ""
	root.add_child(game)
	game.test_ads.response_delay = 0.0
	await _frames(17)
	var args := OS.get_cmdline_user_args()
	if args.has("--record-live"):
		await _record_live()
	elif args.has("--measure-render"):
		await _measure_render()
	else:
		await _compare_screens()
	print("QA premium visuals: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _compare_screens() -> void:
	await _capture("00-menu")
	if not await _click("LaunchButton"):
		return
	await _capture("01-kampania")
	await _click("CampaignBackButton")
	if not await _click("HangarButton"):
		return
	await _capture("02-hangar")
	await _click("WorkshopButton")
	if _check(game.ui.hangar_tab() == "workshop", "hangar opens the workshop"):
		await _click("UpgradeHullButton")
		var levels: Dictionary = game.progression.snapshot().profile.levels
		_check(levels.get("peregrine", {}).get("hull", 0) == 1, "workshop button purchases an actual hull improvement")
	await _capture("03-ulepszenie")
	await _click("HangarTabInventory")
	if _check(game.ui.hangar_tab() == "inventory", "inventory tab is interactive"):
		await _click("Equip_pulse_coil")
		var mounted: Dictionary = game.progression.snapshot().profile.equipped.get("peregrine", {})
		_check(mounted.get("weapon") == "pulse_coil", "inventory card mounts the starter weapon")
	await _capture("04-ekwipunek")
	await _click("HangarBackButton")
	_seed_fleet()
	if OS.get_cmdline_user_args().has("--fleet-portraits"):
		await _click("HangarButton")
		for id in ["aegis", "specter", "aurora", "peregrine"]:
			await _click("ShipButton_" + id)
			_check(game.progression.snapshot().profile.ship_id == id, "selected ship applies to the profile: " + id)
			await _capture("15-" + id)
		await _click("HangarBackButton")
	await _click("LaunchButton")
	if not await _click("LaunchStage_echo"):
		return
	await _step_to(game.flight, 4.2)
	await _capture("05-echo")
	for index in 5:
		var id: String = ["core", "plasma", "rockets", "beam", "repair"][index]
		game.flight._spawn_pickup(id, Vector2(73.0 + index * 98.5, 558.0 if index % 2 == 0 else 468.0))
	await _step_to(game.flight, game.flight._seconds + 0.64)
	await _capture("06-power-upy")
	await _back_to_map()
	await _click("LaunchStage_prism")
	_peek_wave(game.flight, 1, "rockets")
	await _step_to(game.flight, 3.1)
	await _capture("07-pryzmat")
	await _back_to_map()
	await _click("LaunchStage_helion")
	_peek_wave(game.flight, 1, "plasma")
	await _step_to(game.flight, 3.35)
	await _capture("08-helion")
	var craft: Flight = game.flight
	_jump_to_commander(craft)

	if not await _boss_condition(craft, 1, "warning"):
		return
	await _step_to(craft, craft._seconds + 0.70)
	await _capture("09-asterion")
	if not await _boss_condition(craft, 1, "fire"):
		return
	craft._damage_boss(Commander.MAX_HP, craft.boss.position)
	if not await _boss_condition(craft, 2, "warning"):
		return
	await _step_to(craft, craft._seconds + 0.82)
	await _capture("10-kurtyna")
	if not await _boss_condition(craft, 2, "fire"):
		return
	craft._damage_boss(Commander.MAX_HP, craft.boss.position)
	if not await _boss_condition(craft, 3, "warning"):
		return
	craft.boss.hp = Commander.MAX_HP / 3.0
	craft.gear.mode = "beam"
	craft.gear._cycle_left = 0.0
	if not await _boss_condition(craft, 3, "fire"):
		return
	await _step_to(craft, craft._seconds + 0.35)
	await _capture("11-wir")
	if craft.boss != null:
		craft._damage_boss(Commander.MAX_HP, craft.boss.position)
	await _step_to(craft, craft._seconds + 0.62)
	await _capture("12-zniszczenie")
	await _step_to(craft, craft._seconds + 2.60)
	await _frames(16)
	_check(game.phase == "result" and game._result.boss_defeated, "commander rewards connect to the victory screen")
	await _capture("13-wygrana")
	await _click("RestartButton")
	game.flight.hit_player(4_000.0)
	await _click("DeclineReviveButton")
	_check(game.phase == "result" and not game._result.won, "the loss screen is reachable after replay")
	await _capture("14-porazka")
	await _click("CampaignButton")
	await _click("CampaignBackButton")
	_check(game.phase == "menu", "the result navigates back to the title screen")


func _seed_fleet() -> void:
	for id in Campaign.ROUTE:
		game.progression.credit_mission(_victory(id), Campaign.STAGES[id].sector, "visual-" + id)
	for index in 4:
		game.progression.credit_mission(_victory("echo"), "peryhelium", "visual-fleet-%d" % index)


func _back_to_map() -> void:
	await _click("PauseButton")
	await _click("MenuButton")
	await _click("LaunchButton")


func _jump_to_commander(craft: Flight) -> void:
	craft._enemies.clear()
	craft._wave_index = craft._stage.waves.size() - 1
	craft._next_in = 0.025


func _boss_condition(craft: Flight, number: int, state: String) -> bool:
	for tick in 400:
		if craft.boss != null and craft.boss.phase == number and craft.boss.state == state:
			return true
		if game.phase != "combat":
			break
		await physics_frame
	return _check(false, "Asterion reaches phase %d: %s" % [number, state])


func _scene_for_motion() -> Flight:
	_seed_fleet()
	await _click("LaunchButton")
	await _click("LaunchStage_helion")
	var craft: Flight = game.flight
	craft.gear.rank = 7
	craft.gear.mode = "plasma"
	craft._wave_index = craft._stage.waves.size() - 2
	craft._next_in = 0.04
	return craft


func _record_live() -> void:
	var craft := await _scene_for_motion()
	await _pilot_to_result()
	_check(game.phase == "result" and game._result.boss_defeated and craft.boss_phases_fired == 7,
		"recorded play defeats Asterion through pilot input and real damage")
	await _frames(55)


func _measure_render() -> void:
	var craft := await _scene_for_motion()
	var warmup := Time.get_ticks_msec() + 2_000
	while Time.get_ticks_msec() < warmup and game.phase == "combat":
		_pilot_input(craft)
		await process_frame
	var stop := Time.get_ticks_msec() + 15_000
	var last := Time.get_ticks_usec()
	var frametimes: Array[float] = []
	var peak_enemies := 0
	var peak_shots := 0
	var peak_mib := 0.0
	var count := 0
	while Time.get_ticks_msec() < stop and game.phase == "combat":
		if count % 4 == 0:
			_pilot_input(craft)
			peak_enemies = maxi(peak_enemies, craft.active_enemy_count())
			peak_shots = maxi(peak_shots, craft._shots.size())
			peak_mib = maxf(peak_mib, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		await process_frame
		var now := Time.get_ticks_usec()
		frametimes.append((now - last) / 1_000.0)
		last = now
		count += 1
	_release_actions()
	if not _check(frametimes.size() > 60, "real-time renderer samples sustained combat"):
		return
	frametimes.sort()
	var median := frametimes[frametimes.size() / 2]
	var p95 := frametimes[floori((frametimes.size() - 1) * 0.95)]
	var sum_ms := 0.0
	for value in frametimes:
		sum_ms += value
	await RenderingServer.frame_post_draw
	var raster := root.get_texture().get_image().get_size()
	print("RENDER device=%s raster=%s frames=%d wall_s=%.2f fps=%.2f median_ms=%.2f p95_ms=%.2f engine_mib=%.2f active_enemies=%d projectiles=%d" % [
		RenderingServer.get_video_adapter_name(), raster, frametimes.size(),
		sum_ms / 1_000.0, 1_000.0 * frametimes.size() / sum_ms, median, p95, peak_mib, peak_enemies, peak_shots,
	])


func _capture(label: String) -> bool:
	for candidate in game.find_children("*", "BaseButton", true, false):
		if not candidate.is_visible_in_tree() or _scroll_clips(candidate):
			continue
		_check(root.get_visible_rect().encloses(candidate.get_global_rect()), "%s: control %s is in reach" % [label, candidate.name])
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if not _check(frame != null and frame.get_size() == expected_size, "%s: Godot raster %s" % [label, expected_size]):
		return false
	var file := capture_dir.path_join("%dx%d-%s.png" % [expected_size.x, expected_size.y, label])
	return _check(frame.save_png(file) == OK, "saved " + file)


func _scroll_clips(element: Control) -> bool:
	var ancestor := element.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer and not ancestor.get_global_rect().encloses(element.get_global_rect()):
			return true
		ancestor = ancestor.get_parent()
	return false
