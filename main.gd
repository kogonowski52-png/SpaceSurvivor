extends Node

const Arena := preload("res://combat/arena.gd")
const Interface := preload("res://ui/interface.gd")
const FlightAudio := preload("res://audio/flight_audio.gd")
const PilotProgression := preload("res://data/pilot_progression.gd")
const AudioSettings := preload("res://ui/audio_settings.gd")
const MixPreferences := preload("res://audio/mix_preferences.gd")

var arena: Arena
var ui: Interface
var phase := "menu"
var flight_audio: FlightAudio
var progression := PilotProgression.new()
var active_sortie: Dictionary
var mix_preferences := MixPreferences.new()
var _settings: AudioSettings
var _settings_origin := "menu"


func _ready() -> void:
	progression.load_profile()
	mix_preferences.load_settings()
	flight_audio = FlightAudio.new()
	add_child(flight_audio)
	_preview_audio(mix_preferences.levels)
	flight_audio.set_scene(phase)

	var layer := CanvasLayer.new()
	layer.name = "InterfaceLayer"
	layer.layer = 10
	add_child(layer)

	ui = Interface.new()
	ui.name = "Interface"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	ui.launch_requested.connect(_start_mission)
	ui.restart_requested.connect(_start_mission)
	ui.menu_requested.connect(_return_to_menu)
	ui.pause_requested.connect(_pause_mission)
	ui.resume_requested.connect(_resume_mission)
	ui.upgrade_selected.connect(_select_upgrade)
	ui.hangar_requested.connect(_open_hangar)
	ui.hangar_action.connect(_hangar_action)
	ui.settings_requested.connect(_open_settings)
	ui.show_menu(progression.sortie())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if phase == "settings" and event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_cancel_settings()
			return
		if phase == "hangar" and event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_return_to_menu()
			return
		if phase == "combat" or phase == "pause":
			get_viewport().set_input_as_handled()
			_toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_mission()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if phase == "hangar" and is_instance_valid(ui):
			ui.show_hangar(progression.snapshot(), ui.hangar_tab())


func _start_mission() -> void:
	_discard_arena()
	phase = "combat"
	flight_audio.set_scene(phase)
	ui.show_hud()
	arena = Arena.new()
	active_sortie = progression.sortie()
	arena.configure(active_sortie)
	arena.name = "Arena"
	arena.telemetry.connect(ui.update_hud)
	arena.upgrade_requested.connect(_show_upgrades)
	arena.mission_ended.connect(_finish_mission)
	arena.sound_requested.connect(flight_audio.play_event)
	add_child(arena)


func _return_to_menu() -> void:
	phase = "menu"
	flight_audio.set_scene(phase)
	_discard_arena()
	ui.show_menu(progression.sortie())


func _open_hangar() -> void:
	if phase != "menu" and phase != "result":
		return
	phase = "hangar"
	flight_audio.set_scene(phase)
	flight_audio.play_event("navigation")
	_discard_arena()
	ui.show_hangar(progression.snapshot())


func _hangar_action(action: String, value: String) -> void:
	if phase != "hangar":
		return
	match action:
		"back":
			_return_to_menu()
		"launch":
			_start_mission()
		_:
			var tab := ui.hangar_tab()
			var outcome := progression.apply(action, value)
			if outcome.ok:
				match action:
					"upgrade":
						flight_audio.play_event("upgrade")
					"open_crate":
						flight_audio.play_event("crate")
					"equip", "unequip":
						flight_audio.play_event("equip")
					"claim_calendar", "claim_daily", "claim_achievement":
						flight_audio.play_event("reward")
					_:
						flight_audio.play_event("navigation")
			ui.show_hangar(progression.snapshot(), tab)


func _pause_mission() -> void:
	if phase != "combat" or not is_instance_valid(arena):
		return
	phase = "pause"
	flight_audio.set_scene(phase)
	arena.set_suspended(true)
	ui.show_pause()


func _resume_mission() -> void:
	if phase != "pause":
		return
	phase = "combat"
	flight_audio.set_scene(phase)
	ui.show_hud()
	arena.set_suspended(false)


func _toggle_pause() -> void:
	match phase:
		"combat":
			_pause_mission()
		"pause":
			_resume_mission()
		"result", "hangar":
			_return_to_menu()
		"settings":
			_cancel_settings()


func _show_upgrades(cards: Array[Dictionary]) -> void:
	if phase != "combat":
		return
	phase = "upgrade"
	flight_audio.set_scene(phase)
	arena.set_suspended(true)
	ui.show_upgrades(cards)


func _select_upgrade(id: String) -> void:
	if phase != "upgrade" or not arena.apply_upgrade(id):
		return
	phase = "combat"
	flight_audio.set_scene(phase)
	ui.show_hud()
	arena.set_suspended(false)


func _finish_mission(result: Dictionary) -> void:
	if phase != "combat":
		return
	phase = "result"
	flight_audio.set_scene(phase)
	arena.set_suspended(true)
	flight_audio.play_event("victory" if result.get("won", false) else "defeat")
	var report := result.duplicate()
	report.merge(progression.credit_mission(result, active_sortie.sector_id), true)
	report.sector_title = active_sortie.sector_title
	report.duration = active_sortie.duration
	ui.show_result(report)


func _open_settings() -> void:
	if phase != "menu" and phase != "pause":
		return
	_settings_origin = phase
	phase = "settings"
	flight_audio.play_event("navigation")
	flight_audio.set_scene(phase)
	get_viewport().gui_release_focus()
	ui.process_mode = Node.PROCESS_MODE_DISABLED
	_settings = AudioSettings.new()
	_settings.name = "AudioSettings"
	_settings.initial_mix = mix_preferences.levels
	_settings.mix_previewed.connect(_preview_audio)
	_settings.effects_sample_requested.connect(flight_audio.play_event.bind("equip"))
	_settings.confirmed.connect(_confirm_settings)
	_settings.cancelled.connect(_cancel_settings)
	ui.get_parent().add_child(_settings)


func _preview_audio(values: Vector3) -> void:
	flight_audio.set_mix(values.x, values.y, values.z)


func _confirm_settings(values: Vector3) -> void:
	if not mix_preferences.save_settings(values):
		_settings.show_save_error()
		return
	_close_settings()


func _cancel_settings() -> void:
	_preview_audio(mix_preferences.levels)
	_close_settings()


func _close_settings() -> void:
	_settings.get_parent().remove_child(_settings)
	_settings.queue_free()
	_settings = null
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	phase = _settings_origin
	flight_audio.set_scene(phase)
	flight_audio.play_event("navigation")


func _discard_arena() -> void:
	if not is_instance_valid(arena):
		return
	remove_child(arena)
	arena.queue_free()
	arena = null
