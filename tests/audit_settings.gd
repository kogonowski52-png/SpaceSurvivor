extends "res://tests/smoke.gd"
## Uses the normal settings controls and fresh scene instances in an isolated profile.

const SETTINGS_PATH := "user://qa-audio-settings.cfg"


func _run() -> void:
	DirAccess.remove_absolute(SETTINGS_PATH)
	_open_title()
	await _frames(10)
	if not await _click("SettingsButton"):
		quit(1)
		return
	_check(game.phase == "settings", "title settings button opens controls")
	_check(_button("PrivacyPolicyButton") == null and _button("PrivacyOptionsButton") == null,
		"desktop simulator exposes no unconfigured policy link or UMP button")
	game.ads.adapter.privacy_changed.emit(true, "")
	_check(_button("PrivacyOptionsButton") != null, "settings exposes the UMP control when the provider requires it")
	game.ads.adapter.privacy_changed.emit(false, "")
	var master := _slider("MasterVolume")
	var music := _slider("MusicVolume")
	var effects := _slider("EffectsVolume")
	if not _check(master != null and music != null and effects != null, "all three independent volume controls exist"):
		quit(1)
		return
	_check(master.value == 90.0 and music.value == 65.0 and effects.value == 80.0, "new settings use the default mix")
	master.value = 52.0
	music.value = 24.0
	effects.value = 0.0
	await _click("SettingsDone")
	_check(game.phase == "menu" and game.mix_preferences.levels.is_equal_approx(Vector3(0.52, 0.24, 0.0)), "save commits the independent levels including mute")
	game.queue_free()
	await _frames(3)
	_open_title()
	await _frames(10)
	game._privacy_policy_url = "https://privacy.example.invalid/galaxy-strike"
	await _click("SettingsButton")
	_check(_button("PrivacyPolicyButton") != null, "a configured policy URL adds a link in settings")
	master = _slider("MasterVolume")
	_check(master != null and master.value == 52.0, "fresh scene loads the saved audio levels")
	if master != null:
		master.value = 76.0
	await _click("SettingsCancel")
	_check(game.phase == "menu" and is_equal_approx(game.mix_preferences.levels.x, 0.52), "cancel leaves the saved mix intact")
	await _click("LaunchButton")
	await _click("PauseButton")
	var paused := _seconds()
	await _click("PauseSettingsButton")
	_check(game.phase == "settings", "pause settings button opens the same mix controls")
	await _steps(30)
	_check(is_equal_approx(_seconds(), paused), "mission clock stays frozen while adjusting paused audio")
	await _click("SettingsCancel")
	_check(game.phase == "pause", "return from settings restores pause")
	await _click("ResumeButton")
	_check(game.phase == "combat", "mission resumes from the original pause controls")
	DirAccess.remove_absolute(SETTINGS_PATH)
	print("QA audio settings: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _open_title() -> void:
	var entry := load("res://main.tscn") as PackedScene
	game = entry.instantiate()
	game.mix_preferences.path = SETTINGS_PATH
	root.add_child(game)


func _slider(id: String) -> HSlider:
	return game.find_child(id, true, false) as HSlider
