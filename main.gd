extends Node

const Arena := preload("res://combat/arena.gd")
const Interface := preload("res://ui/interface.gd")
const FlightAudio := preload("res://audio/flight_audio.gd")

var arena: Arena
var ui: Interface
var phase := "menu"
var flight_audio: FlightAudio


func _ready() -> void:
	flight_audio = FlightAudio.new()
	add_child(flight_audio)

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
	ui.show_menu()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if phase == "combat" or phase == "pause":
			get_viewport().set_input_as_handled()
			_toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_toggle_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_mission()


func _start_mission() -> void:
	_discard_arena()
	phase = "combat"
	ui.show_hud()
	arena = Arena.new()
	arena.name = "Arena"
	arena.telemetry.connect(ui.update_hud)
	arena.upgrade_requested.connect(_show_upgrades)
	arena.mission_ended.connect(_finish_mission)
	arena.sound_requested.connect(flight_audio.play_event)
	add_child(arena)


func _return_to_menu() -> void:
	phase = "menu"
	_discard_arena()
	ui.show_menu()


func _pause_mission() -> void:
	if phase != "combat" or not is_instance_valid(arena):
		return
	phase = "pause"
	arena.set_suspended(true)
	ui.show_pause()


func _resume_mission() -> void:
	if phase != "pause":
		return
	phase = "combat"
	ui.show_hud()
	arena.set_suspended(false)


func _toggle_pause() -> void:
	match phase:
		"combat":
			_pause_mission()
		"pause":
			_resume_mission()
		"result":
			_return_to_menu()


func _show_upgrades(cards: Array[Dictionary]) -> void:
	if phase != "combat":
		return
	phase = "upgrade"
	arena.set_suspended(true)
	ui.show_upgrades(cards)


func _select_upgrade(id: String) -> void:
	if phase != "upgrade":
		return
	phase = "combat"
	ui.show_hud()
	arena.apply_upgrade(id)
	if phase == "combat":
		arena.set_suspended(false)


func _finish_mission(result: Dictionary) -> void:
	if phase != "combat":
		return
	phase = "result"
	arena.set_suspended(true)
	flight_audio.play_event("victory" if result.get("won", false) else "defeat")
	ui.show_result(result)


func _discard_arena() -> void:
	if not is_instance_valid(arena):
		return
	remove_child(arena)
	arena.queue_free()
	arena = null
