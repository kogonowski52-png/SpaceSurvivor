extends "res://main.gd"
## The campaign shares the hangar, wallet, audio, pause and rewarded placements.

const Campaign := preload("res://vertical/campaign.gd")
const Flight := preload("res://vertical/field.gd")
const FlightInterface := preload("res://vertical/interface.gd")

var flight: Flight
var selected_stage := ""


func _make_interface() -> Interface:
	var view := FlightInterface.new()
	view.stage_requested.connect(_launch_stage)
	view.campaign_requested.connect(_open_campaign)
	return view


func _menu_data() -> Dictionary:
	var completed := 0
	for record: Dictionary in progression.snapshot().profile.campaign.values():
		completed += int(record.get("cleared", false))
	return {"campaign_mode": true, "sector_title": "Próg Helionu", "route_progress": "%d / %d" % [completed, Campaign.ROUTE.size()]}


func _hangar_data() -> Dictionary:
	var data := super._hangar_data()
	data.campaign_mode = true
	return data


func _combat_actor() -> Node:
	return flight


func _input(event: InputEvent) -> void:
	if phase == "campaign" and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_menu()
		return
	super._input(event)


func _toggle_pause() -> void:
	if phase == "campaign":
		_return_to_menu()
	else:
		super._toggle_pause()


func _open_campaign() -> void:
	if ads.busy() or phase not in ["menu", "hangar", "result"]:
		return
	var reveal := Campaign.next(selected_stage) if phase == "result" and _result.get("first_clear", false) else ""
	_discard_arena()
	phase = "campaign"
	flight_audio.set_scene(phase)
	flight_audio.play_event("navigation")
	ui.show_campaign(progression.snapshot().profile.campaign, reveal)


func _start_mission() -> void:
	if phase in ["pause", "result"]:
		_launch_stage(selected_stage)
	else:
		_open_campaign()


func _launch_stage(id: String) -> void:
	if ads.busy() or phase not in ["campaign", "pause", "result"]:
		return
	if not Campaign.access(progression.snapshot().profile.campaign, id):
		return
	_discard_arena()
	selected_stage = id
	var stage: Dictionary = Campaign.STAGES[id]
	active_sortie = progression.sortie()
	active_sortie.sector_id = stage.sector
	active_sortie.sector_title = stage.title
	active_sortie.duration = Campaign.time_limit(stage)
	_flight_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_result = {}
	_ad_message = ""
	phase = "combat"
	flight_audio.set_frontier_score(Campaign.ROUTE.find(id) >= 3)
	flight_audio.set_scene(phase)
	ui.show_hud()
	flight = Flight.new()
	flight.name = "VerticalFlight"
	flight.revive_offer_enabled = progression.save_block_reason().is_empty()
	flight.configure(id, active_sortie)
	flight.telemetry.connect(ui.update_hud)
	flight.sound_requested.connect(flight_audio.play_event)
	flight.mission_ended.connect(_finish_mission)
	flight.revive_offered.connect(_offer_revive)
	add_child(flight)


func _refresh_result() -> void:
	var following := Campaign.next(selected_stage)
	_result.next_stage = following if _result.get("won", false) and Campaign.access(progression.snapshot().profile.campaign, following) else ""
	super._refresh_result()


func _discard_arena() -> void:
	if is_instance_valid(flight):
		remove_child(flight)
		flight.queue_free()
		flight = null
	super._discard_arena()
