extends "res://tests/chapter_one.gd"
## Captures Godot viewports and records a live-input finish, with explicit setup for stills.

const VIEWS := [4.3, 4.0, 4.0, 9.2, 5.5, 4.9, 10.0, 2.55, 2.92, 5.0]


func _run() -> void:
	await _load_chapter("-capture")
	var options := OS.get_cmdline_user_args()
	if "--record-live" in options:
		await _live_finish()
	elif "--stress-chapter" in options:
		if "--graphics-low" in options:
			game.mix_preferences.graphics.quality = "low"
		Engine.max_fps = 0
		await _stress("strait")
		await _stress("abyss")
	else:
		await _tour()
	game.queue_free()
	await _frames(8)
	print("QA chapter capture: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _tour() -> void:
	await _capture("00-menu")
	await _click("LaunchButton")
	await _capture("01-atlas-zablokowany")
	await _click("SectorJump_09")
	await _frames(37)
	var view: ScrollContainer = game.ui._route_scroll
	_check(view.scroll_vertical > 300 and _button("LaunchStage_abyss") == null, "sector tab scrolls to the locked finale")
	await _click("CampaignBackButton")
	_seed_showcase()
	await _click("LaunchButton")
	await _capture("02-atlas-rekordy")
	await _click("SectorJump_09")
	await _frames(37)
	await _capture("03-atlas-otchlan")
	await _click("SectorJump_00")
	await _frames(37)

	for index in Campaign.ROUTE.size():
		var id := Campaign.ROUTE[index]
		if not await _open_sortie(id):
			return
		var craft: Flight = game.flight
		if id == "strait":
			_last_wave(craft)
		await _at_time(craft, VIEWS[index])
		await _capture("%02d-lot-%s" % [index + 4, id])
		if Campaign.BOSS_NAMES.has(id):
			await _boss_stills(craft, id)
			if not _check(game.phase == "result" and game._result.boss_defeated, "capital defeat renders the real result: " + id):
				return
			if id == "abyss":
				await _capture("21-final-wynik")
			else:
				await _click("CampaignButton")
		else:
			await _click("PauseButton")
			await _click("MenuButton")
			await _click("LaunchButton")


func _seed_showcase() -> void:
	for index in Campaign.ROUTE.size():
		var id := Campaign.ROUTE[index]
		var stage: Dictionary = Campaign.STAGES[id]
		var record := _victory(id)
		if index % 3 != 0:
			record.kills = Campaign.enemy_quota(stage) + 9
			record.hull_ratio = 0.83 if index % 3 == 2 else 0.42
		record.score = 12_500 + index * 2150
		game.progression.credit_mission(record, stage.sector, "proof-" + id)


func _open_sortie(id: String) -> bool:
	var button := _button("LaunchStage_" + id)
	if not _check(button != null and game.phase == "campaign", "map can open sortie " + id):
		return false
	game.ui._route_scroll.ensure_control_visible(button)
	await _frames(5)
	return await _click("LaunchStage_" + id)


func _last_wave(craft: Flight) -> void:
	craft._enemies.clear()
	craft._wave_index = craft._stage.waves.size() - 2
	craft._next_in = 0.04


func _at_time(craft: Flight, seconds: float) -> void:
	for step in 700:
		if game.phase != "combat" or craft._seconds >= seconds:
			return
		await physics_frame


func _boss_stills(craft: Flight, id: String) -> void:
	_jump_to_commander(craft)
	var phases := 4 if id == "abyss" else 3
	for number in range(1, phases + 1):
		if not await _boss_condition(craft, number, "warning"):
			return
		if id != "helion" or number == 2:
			await _at_time(craft, craft._seconds + 0.58)
			await _capture("boss-%s-faza-%d" % [id, number])
		if number == phases and craft.boss != null:
			craft.boss.hp = maxf(craft.boss.hp, craft.boss.health_capacity() * 0.18)
		if not await _boss_condition(craft, number, "fire"):
			return
		if number == 1 and id != "helion":
			var capital := craft.boss as Warship
			var x := capital.position.x + capital._turrets[0].mount.x
			craft.beam_damage(Vector2(x, 812), 800.0)
		craft._damage_boss(craft.boss.health_capacity(), craft.boss.position + Vector2(0.0, -65.0))
	if id == "abyss":
		await _at_time(craft, craft._seconds + 0.86)
		await _capture("20-nadir-zniszczenie")
	await _at_time(craft, craft._seconds + 3.8)
	await _frames(16)


func _live_finish() -> void:
	_seed_showcase()
	await _click("LaunchButton")
	if not await _open_sortie("abyss"):
		return
	var craft: Flight = game.flight
	craft.revive_offer_enabled = false
	craft.gear.rank = 7
	craft.gear.mode = "plasma"
	_last_wave(craft)
	await _simulate(craft)
	_log_sortie("recording", "abyss", craft)
	_check(game.phase == "result" and game._result.boss_defeated and craft.boss_phases_fired == 15,
		"movie records a full active Nadir fight through all four patterns")
	await _frames(47)


func _stress(id: String) -> void:
	if game.phase != "menu":
		await _click("PauseButton")
		await _click("MenuButton")
	_seed_showcase()
	await _click("LaunchButton")
	if not await _open_sortie(id):
		return
	var craft: Flight = game.flight
	craft.gear.rank = 7
	craft.gear.mode = "plasma"
	_last_wave(craft)
	if id == "abyss":
		_jump_to_commander(craft)
		if not await _boss_condition(craft, 1, "warning"):
			return
		craft.boss.phase = 4
		(craft.boss as Warship)._warn(craft)
	var warmup := Time.get_ticks_msec() + 1700
	while game.phase == "combat" and Time.get_ticks_msec() < warmup:
		_chapter_input(craft)
		await _frames(3)
	var end := Time.get_ticks_msec() + 12_000
	var last := Time.get_ticks_usec()
	var frames: Array[float] = []
	var peaks := Vector3i.ZERO
	var memory := 0.0
	while game.phase == "combat" and Time.get_ticks_msec() < end:
		if frames.size() % 5 == 0:
			_chapter_input(craft)
			peaks.x = maxi(peaks.x, craft.active_enemy_count())
			peaks.y = maxi(peaks.y, craft._shots.size())
			peaks.z = maxi(peaks.z, craft.hazards.active.size())
			memory = maxf(memory, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
	_release_actions()
	if not _check(frames.size() > 55, "native combat sustains a timed sample: " + id):
		return
	frames.sort()
	var total := 0.0
	for duration in frames:
		total += duration
	await RenderingServer.frame_post_draw
	print("DESKTOP %s quality=%s device=%s raster=%s duration=%.2f FPS=%.2f p95=%.2f engine_MiB=%.1f peaks=%s" % [
		id, game.mix_preferences.graphics.quality, RenderingServer.get_video_adapter_name(), root.get_texture().get_image().get_size(), total / 1000.0,
		frames.size() * 1_000.0 / total, frames[floori((frames.size() - 1) * .95)], memory, peaks])
	print("DESKTOP SETUP " + JSON.stringify(game.diagnostics.report(game.mix_preferences.graphics, root.size, null).scene_setup_ms))
	if game.phase == "result":
		await _click("CampaignButton")
		await _click("CampaignBackButton")
