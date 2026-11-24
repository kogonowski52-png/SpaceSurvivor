extends "res://tests/smoke.gd"
## Screen flow, application interruptions and sanitized reports using the regular vertical scene.

const Campaign := preload("res://vertical/campaign.gd")
const Graphics := preload("res://data/graphics_preferences.gd")
const SafeLayout := preload("res://ui/safe_layout.gd")
const SHIPS := ["peregrine", "aegis", "specter", "aurora"]
const PREFIX := "user://qa-android-1-2"

var _profile_path := PREFIX + "-" + str(Time.get_ticks_usec())


func _run() -> void:
	_open_game()
	await _frames(10)
	if capture_dir.is_empty():
		_test_insets()
		await _test_tuning()
		await _test_interruption()
		await _test_reward_and_export()
		await _test_ship_persistence()
	else:
		await _capture_release_views()
	print("QA Android candidate: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _open_game() -> void:
	var entry := load("res://vertical/main.tscn") as PackedScene
	game = entry.instantiate()
	game.progression.save_path = _profile_path
	game.progression.legacy_path = ""
	game.progression.date_override = "2026-11-24"
	game.mix_preferences.path = _profile_path + "-settings.cfg"
	game.billing_ledger_path = _profile_path + "-orders.cfg"
	game.diagnostic_path = _profile_path + "-diagnostics.json"
	root.add_child(game)
	game.test_ads.response_delay = 0.0


func _test_insets() -> void:
	var tall := SafeLayout.logical_insets(Vector2(540, 1200), Rect2i(0, 0, 1080, 2400), Rect2i(0, 96, 1080, 2224))
	_check(tall.is_equal_approx(Vector4(0, 48, 0, 40)), "portrait notch and navigation bar become canvas margins")
	var windowed := SafeLayout.logical_insets(Vector2(540, 960), Rect2i(25, 90, 1080, 1920), Rect2i(60, 0, 1000, 2020))
	_check(windowed.is_equal_approx(Vector4(17.5, 0, 22.5, 0)), "insets respect the physical origin of a window")
	_check(Graphics.tuning({"quality": "high"}).sparks > Graphics.tuning({"quality": "standard"}).sparks
		and Graphics.tuning({"quality": "standard"}).sparks > Graphics.tuning({"quality": "low"}).sparks,
		"each quality preset allocates a different decorative budget")


func _test_tuning() -> void:
	await _click("SettingsButton")
	await _click("SettingsTab_graphics")
	await _click("Quality_low")
	var sliders := ["EffectsIntensity", "ParticleDensity"]
	for name: String in sliders:
		var slider := game.find_child(name, true, false) as HSlider
		slider.value = 40.0
	await _click("Limit30Button")
	await _click("PowerSaverButton")
	var active: Dictionary = game._settings._graphics
	_check(Graphics.tuning(active).fps_cap == 30 and Graphics.tuning(active).stars == 30, "energy saving applies a 30 FPS cap and star budget")
	await _click("SettingsDone")
	game.queue_free()
	await _frames(4)
	_open_game()
	await _frames(5)
	_check(game.mix_preferences.graphics == {"quality": "low", "effects": 0.4, "particles": 0.4, "limit_30": true, "saver": true},
		"graphics selection and independent sliders persist on fresh launch")
	await _click("LaunchButton")
	await _click("LaunchStage_echo")
	var craft: Node = game.flight
	_check(craft._sky.star_count == 30 and craft.fx.spark_density < 0.25 and not craft.fx.draw_debris,
		"conservative budget reaches the running flight")
	var standard: Dictionary = game.active_sortie.stats.duplicate()
	await _click("PauseButton")
	await _click("PauseSettingsButton")
	await _click("SettingsTab_graphics")
	await _click("Quality_high")
	await _click("SettingsCancel")
	_check(game.phase == "pause" and game.mix_preferences.graphics.quality == "low", "cancel preserves the saved quality and pause")
	await _click("ResumeButton")
	_check(game.active_sortie.stats == standard and is_equal_approx(craft._max_hp, float(standard.max_hp)),
		"graphics options preserve pilot statistics")


func _test_interruption() -> void:
	var craft: Node = game.flight
	craft._grab(2, craft.to_global(craft.player_position))
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	var time: float = craft._seconds
	await _steps(10)
	_check(game.phase == "pause" and is_equal_approx(time, craft._seconds) and craft._pointer == -1,
		"background pauses the clock and clears the active finger without movement")
	_check(game.flight_audio._external_silence, "background silences the game mix")
	game.notification(NOTIFICATION_APPLICATION_RESUMED)
	_check(game.phase == "pause" and not game.flight_audio._external_silence,
		"return restores audio and retains deliberate pause")
	await _click("ResumeButton")
	await _click("PauseButton")
	await _click("MenuButton")


func _test_reward_and_export() -> void:
	await _click("StoreButton")
	await _click("StoreTab_free")
	game.test_ads.scenario = "network_error"
	var baseline: int = game.progression.snapshot().profile.coins
	await _click("BonusCreditsButton")
	_check(game.phase == "store" and game._store_state == "network_error" and game.progression.snapshot().profile.coins == baseline,
		"ad connection failure preserves wallet and navigation")
	game.test_ads.response_delay = 100.0
	# Drive the same boundary Android uses without asserting that the SDK ran.
	game._request_ad("bonus")
	var request: String = game.ads._request
	game.ads.adapter.diagnostic.emit("late-request", "showing")
	_check(not game.flight_audio._external_silence, "an unrelated SDK signal cannot mute the mix")
	game.ads.adapter.diagnostic.emit(request, "ready")
	game.ads.adapter.diagnostic.emit(request, "showing")
	_check(game.flight_audio._external_silence, "matched presentation silences the mix")
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	game.ads.adapter.diagnostic.emit(request, "closed")
	game.ads.adapter.answered.emit(request, "rewarded")
	game.ads.adapter.answered.emit(request, "rewarded")
	_check(game.flight_audio._external_silence and game.progression.snapshot().profile.coins == baseline + 150,
		"duplicate callback pays once and background audio stays muted")
	game.notification(NOTIFICATION_APPLICATION_RESUMED)
	_check(not game.flight_audio._external_silence and not game.ads.busy(), "returned focus restores game audio after the ad")
	var private_marker := "PRIVATE_f43e_profile_QA"
	game._ad_diagnostic(private_marker, "bonus")
	game._ad_diagnostic("closed", private_marker)
	await _click("StoreBackButton")
	await _click("SettingsButton")
	await _click("SettingsTab_diagnostics")
	await _click("ExportDiagnosticsButton")
	var raw := FileAccess.get_file_as_string(game.diagnostic_path)
	var exported: Variant = JSON.parse_string(raw)
	_check(exported is Dictionary and exported.version == ProjectSettings.get_setting("application/config/version") and exported.ad_events.back().state == "granted"
		and not private_marker in raw and not request in raw and not "token" in raw, "diagnostic export has allowlisted states and no private identifiers")
	await _click("SettingsCancel")


func _unlock_fleet() -> void:
	for index in 7:
		var stage := Campaign.ROUTE[index]
		game.progression.credit_mission({"won": true, "stage": stage, "kills": 200, "seconds": 135,
			"hull_ratio": 0.80, "score": 27000, "reward": 48}, Campaign.STAGES[stage].sector, "fixture-" + stage)


func _test_ship_persistence() -> void:
	_unlock_fleet()
	await _click("HangarButton")
	for ship in SHIPS:
		await _click("ShipButton_" + ship)
		_check(game.progression.sortie().ship_id == ship, "hangar can equip " + ship)
	await _click("HangarTabInventory")
	await _click("HangarTabRewards")
	await _click("HangarBackButton")
	await _click("LaunchButton")
	await _click("LaunchStage_echo")
	_check(game.flight._ship_id == "aurora", "chosen fourth hull reaches active combat after navigation")


func _capture_release_views() -> void:
	await _shot("rc-menu")
	await _click("SettingsButton")
	await _shot("rc-dzwiek")
	await _click("SettingsTab_graphics")
	await _click("Quality_low")
	await _click("PowerSaverButton")
	await _shot("rc-grafika")
	await _click("SettingsTab_diagnostics")
	await _click("DiagnosticsButton")
	await _shot("rc-diagnostyka")
	await _click("SettingsCancel")
	_unlock_fleet()
	await _click("HangarButton")
	await _click("ShipButton_aurora")
	await _shot("rc-hangar")
	await _click("WorkshopButton")
	await _shot("rc-warsztat")
	await _click("HangarTabInventory")
	await _shot("rc-ekwipunek")
	await _click("HangarTabRewards")
	await _shot("rc-nagrody")
	await _click("HangarStoreButton")
	await _shot("rc-sklep")
	await _click("StoreTab_season")
	await _shot("rc-helion")
	await _click("StoreBackButton")
	await _click("HangarBackButton")
	await _click("LaunchButton")
	await _shot("rc-atlas")
	await _click("LaunchStage_echo")
	await _steps(120)
	await _shot("rc-walka")
	await _click("PauseButton")
	await _shot("rc-pauza")
	await _click("ResumeButton")
	game.flight.revive_offer_enabled = false
	game.flight.hit_player(10000.0)
	await _frames(8)
	_check(game.phase == "result" and not game._result.won, "real fatal hit displays defeat")
	await _shot("rc-porazka")


func _shot(label: String) -> void:
	await _frames(9)
	for node in game.find_children("*", "BaseButton", true, false):
		if not node.is_visible_in_tree():
			continue
		var parent: Node = node.get_parent()
		while parent != null and not parent is ScrollContainer:
			parent = parent.get_parent()
		if parent == null:
			_check(root.get_visible_rect().encloses(node.get_global_rect()), "%s contains %s" % [label, node.name])
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if _check(frame != null and frame.get_size() == expected_size, "exact raster " + label):
		var filename := "%dx%d-%s.png" % [expected_size.x, expected_size.y, label]
		_check(frame.save_png(capture_dir.path_join(filename)) == OK, "captured " + filename)
