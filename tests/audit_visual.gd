extends "res://tests/progression.gd"
## Repeatable native capture using the real title scene, in-game buttons and game render.
## Mission reward fixtures provide repeatable profiles and results for before/after comparison.

const AUDIT_SEED := 976_138


func _run() -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		printerr("Provide a native display, --capture-dir and --expect-size.")
		quit(1)
		return
	if not await _open_game():
		quit(1)
		return
	print("Visual audit fixture: stable date and seeded gear; card/result fixtures are labeled in this log.")
	await _audit_capture("01-menu")
	await _audit_hangar()
	await _audit_sortie()
	if OS.get_cmdline_user_args().has("--flight-detail"):
		await _audit_flight_detail()
	await _audit_settings()
	print("QA visual audit: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _audit_hangar() -> void:
	var pilot = game.progression
	for victory in 3:
		var earnings: Dictionary = pilot.credit_mission(_completed_mission(), "peryhelium")
		_check(earnings.ok, "saved the reproducible victory fixture")
	for item in ["pulse_coil", "titanium_plate", "trim_nozzle", "flux_cell", "escort_bay"]:
		_check(pilot.apply("equip", item).ok, "fixture equips " + item)
	for track in ["hull", "drive", "output"]:
		_check(pilot.apply("upgrade", track).ok, "fixture levels " + track)
	pilot._rng.seed = AUDIT_SEED
	if not await _click("HangarButton"):
		return
	await _audit_capture("04-hangar")
	await _click_scrolled("ShipButton_aegis")
	_check(_profile().ship_id == "aegis", "selected Aegis through the ship button")
	await _audit_capture("06-wybor-statku")
	await _click_scrolled("ShipButton_peregrine")
	await _click("HangarTabInventory")
	await _audit_capture("05-ekwipunek")
	await _click("HangarTabSectors")
	await _audit_capture("12-sektory")
	await _click("HangarTabRewards")
	await _audit_capture("09-nagrody")
	var crates_before: int = _profile().crates
	if await _click_scrolled("OpenCrate"):
		_check(_profile().crates == crates_before - 1 and Catalog.ITEMS.has(pilot.snapshot().loot), "opened actual earned crate")
		await _audit_capture("10-skrzynia")
	await _click("HangarTabOverview")
	await _click_scrolled("WorkshopButton")
	await _audit_capture("13-ulepszenia-stale")
	await _click("HangarTabOverview")
	await _click("HangarBackButton")


func _audit_sortie() -> void:
	if not await _click("LaunchButton") or not _check(game.phase == "combat", "menu launches the real combat arena"):
		return
	_watch_arena()
	game.arena._rng.seed = AUDIT_SEED
	await _advance_to(4.0)
	await _wait_for_combat_frame()
	_check(game.phase == "combat", "combat capture uses a live fight")
	await _audit_capture("02-walka")
	if game.phase == "combat":
		print("Card fixture: supply the next XP threshold, the arena grants an actual promotion and picks all three cards.")
		game.arena._rng.seed = AUDIT_SEED
		game.arena._xp = game.arena._xp_goal
		await _steps(6)
	_check(game.phase == "upgrade" and offered.size() == 3, "arena opens three-card upgrade overlay")
	await _audit_capture("03-karty")
	await _click("UpgradeButton0")
	await _click("PauseButton")
	_check(game.phase == "pause", "combat pauses through the HUD button")
	await _audit_capture("14-pauza")
	await _click("ResumeButton")

	var victory := _completed_mission()
	victory.kills = 1190
	victory.level = 37
	victory.reward = 501
	print("Result fixtures: deliver fixed victory/defeat events to the live arena result pipeline.")
	await _result_fixture(victory, "07-wygrana")
	if not await _click("RestartButton"):
		return
	var defeat := {"won": false, "seconds": 196.0, "kills": 172, "level": 15, "reward": 79, "boss_defeated": false}
	await _result_fixture(defeat, "08-porazka")
	await _click("MenuButton")


func _result_fixture(result: Dictionary, label: String) -> void:
	if not _check(game.phase == "combat" and is_instance_valid(game.arena), "result fixture starts in combat"):
		return
	result.sector_id = game.arena._sector_id
	result.ship_id = game.arena._ship_id
	game.arena.mission_ended.emit(result)
	await _frames(12)
	_check(game.phase == "result" and _visible_control("RewardRow") != null, "renders played result and reward summary")
	await _audit_capture(label)


func _audit_flight_detail() -> void:
	if not await _click("SettingsButton") or not await _click("DiagnosticsButton"):
		return
	await _click("SettingsCancel")
	if not await _click("LaunchButton"):
		return
	var arena: Node2D = game.arena
	await _audit_capture("15-diagnostyka")
	print("Combat detail fixture: equip a laser and place an enemy in visual range.")
	_check(arena._loadout.increment("laser"), "laser becomes active in the flight fixture")
	arena._spawn_enemy(arena.EnemyKind.BASTION, arena._player_position + Vector2(110, -190))
	await _steps(3)
	_check(arena._arsenal._laser_remaining > 0, "the rendered laser is firing")
	await _capture_page("16-laser")
	print("Combat detail fixture: apply lethal damage to trigger the real boss destruction effect.")
	arena._spawn_enemy(arena.EnemyKind.BOSS, arena._player_position + Vector2(0, -185))
	var boss_index: int = arena._enemies.size() - 1
	arena._damage_enemy(boss_index, arena._enemies[boss_index].hp + 1.0, Vector2.UP)
	_check(not arena._fx._collapses.is_empty(), "boss defeat triggers the live destruction renderer")
	await _capture_page("17-eksplozja-bossa")
	await _click("PauseButton")
	await _click("MenuButton")


func _audit_settings() -> void:
	if _button("SettingsButton") == null:
		_check(OS.get_cmdline_user_args().has("--baseline"), "settings unavailable only in the baseline")
		print("Settings were absent in baseline 33d03ba. No substitute frame generated.")
		return
	if not await _click("SettingsButton"):
		return
	for name in ["MasterVolume", "MusicVolume", "EffectsVolume", "SettingsDone", "SettingsCancel"]:
		var control := _visible_control(name)
		_check(control != null and root.get_visible_rect().encloses(control.get_global_rect()), "settings exposes " + name + " in the viewport")
	await _audit_capture("11-ustawienia")


func _audit_capture(label: String) -> void:
	await _frames(5 if OS.get_cmdline_user_args().has("--quick-capture") else 12)
	var viewport := root.get_visible_rect()
	for node in game.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.is_visible_in_tree() and not button.disabled and not _inside_scroll(button):
			_check(viewport.encloses(button.get_global_rect()), "%s %s fits in viewport" % [label, button.name])
	await _capture_page(label)


func _inside_scroll(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false
