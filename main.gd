extends Node

const Arena := preload("res://combat/arena.gd")
const Interface := preload("res://ui/interface.gd")
const FlightAudio := preload("res://audio/flight_audio.gd")
const PilotProgression := preload("res://data/pilot_progression.gd")
const AudioSettings := preload("res://ui/audio_settings.gd")
const MixPreferences := preload("res://audio/mix_preferences.gd")
const StoreCatalog := preload("res://data/store/commerce_catalog.gd")
const BillingService := preload("res://commerce/billing_service.gd")
const TestBillingAdapter := preload("res://commerce/test_billing_adapter.gd")
const AdService := preload("res://commerce/ad_service.gd")
const TestAdAdapter := preload("res://commerce/test_ad_adapter.gd")
const AndroidBillingAdapter := preload("res://commerce/android_billing_adapter.gd")
const AndroidAdAdapter := preload("res://commerce/android_ad_adapter.gd")
const DebugFlightMetrics := preload("res://ui/debug_flight_metrics.gd")

var arena: Arena
var ui: Interface
var phase := "menu"
var flight_audio: FlightAudio
var progression := PilotProgression.new()
var active_sortie: Dictionary
var mix_preferences := MixPreferences.new()
var _settings: AudioSettings
var _settings_origin := "menu"
var billing_ledger_path := "user://test_play_orders.cfg"
var billing: BillingService
var ads: AdService
var test_billing: TestBillingAdapter
var test_ads: TestAdAdapter
var _store_origin := "menu"
var _store_return_tab := "overview"
var _store_state := ""
var _store_notice := ""
var _flight_id := ""
var _result: Dictionary
var _ad_message := ""
var _play_test := false
var _privacy_policy_url := ""
var _debug_metrics: DebugFlightMetrics


func _ready() -> void:
	if OS.has_feature("android"):
		# Android builds before 0.6 carried simulated purchases. Keep those saves separate.
		var bridge := Engine.get_singleton("GalaxyCommerce") if Engine.has_singleton("GalaxyCommerce") else null
		var live: bool = bridge != null and bridge.playMode() == "live"
		if bridge != null:
			_privacy_policy_url = bridge.privacyPolicyUrl()
		_play_test = not live
		progression.save_path = "user://play_progress" if live else "user://play_debug_progress"
		progression.legacy_path = ""
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
	ui.store_requested.connect(_open_store)
	ui.store_action.connect(_store_action)
	ui.rewarded_ad_requested.connect(_request_ad)
	ui.revive_declined.connect(_decline_revive)
	_setup_commerce()
	ui.show_menu(progression.sortie())
	if OS.get_cmdline_user_args().has("--diagnostics"):
		_set_debug_metrics(true)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if phase in ["store", "revive"] and event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_toggle_pause()
			return
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
	if ads.busy():
		return
	var previous_arena := arena
	_discard_arena()
	_flight_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_result = {}
	_ad_message = ""
	phase = "combat"
	flight_audio.set_scene(phase)
	ui.show_hud()
	arena = Arena.new()
	arena.revive_offer_enabled = progression.save_block_reason().is_empty()
	active_sortie = progression.sortie()
	arena.configure(active_sortie, previous_arena)
	arena.name = "Arena"
	arena.telemetry.connect(ui.update_hud)
	arena.upgrade_requested.connect(_show_upgrades)
	arena.mission_ended.connect(_finish_mission)
	arena.sound_requested.connect(flight_audio.play_event)
	arena.revive_offered.connect(_offer_revive)
	add_child(arena)


func _return_to_menu() -> void:
	if ads.busy():
		return
	phase = "menu"
	flight_audio.set_scene(phase)
	_discard_arena()
	ui.show_menu(progression.sortie())


func _open_hangar() -> void:
	if (phase != "menu" and phase != "result") or ads.busy():
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
		"store":
			_open_store()
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
		"store":
			_leave_store()
		"revive":
			_decline_revive()


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
	_result = result.duplicate()
	_result.merge(progression.credit_mission(result, active_sortie.sector_id, _flight_id), true)
	_result.sector_title = active_sortie.sector_title
	_result.duration = active_sortie.duration
	_ad_message = ""
	_refresh_result()


func _setup_commerce() -> void:
	billing = BillingService.new()
	add_child(billing)
	billing.status_changed.connect(_shop_status)
	billing.catalog_changed.connect(_refresh_store)
	billing.account_changed.connect(_refresh_hangar_account)
	ads = AdService.new()
	add_child(ads)
	ads.status_changed.connect(_ad_status)
	ads.reward_ready.connect(_credit_ad)
	ads.privacy_changed.connect(_ad_privacy_changed)
	if OS.has_feature("android"):
		billing.configure(progression, AndroidBillingAdapter.new())
		ads.configure(AndroidAdAdapter.new())
	else:
		test_billing = TestBillingAdapter.new()
		test_billing.ledger_path = billing_ledger_path
		billing.configure(progression, test_billing)
		test_ads = TestAdAdapter.new()
		ads.configure(test_ads)
	ui.ad_label = ads.label()
	ui.ads_simulated = ads.adapter.is_test()


func _open_store() -> void:
	if phase != "menu" and phase != "hangar":
		return
	_store_origin = phase
	_store_return_tab = ui.hangar_tab()
	phase = "store"
	flight_audio.set_scene(phase)
	flight_audio.play_event("navigation")
	billing.adapter.refresh_catalog()
	_refresh_store()
	billing.refresh_balance()


func _refresh_hangar_account() -> void:
	if phase == "hangar":
		ui.show_hangar(progression.snapshot(), ui.hangar_tab())


func _leave_store() -> void:
	if ads.busy():
		return
	if _store_origin == "hangar":
		phase = "hangar"
		flight_audio.set_scene(phase)
		ui.show_hangar(progression.snapshot(), _store_return_tab)
	else:
		_return_to_menu()


func _refresh_store() -> void:
	if phase != "store":
		return
	var pending: Array[String] = []
	for id: String in StoreCatalog.OFFERS:
		if billing.pending(id):
			pending.append(id)
	ui.show_store({
		"profile": progression.snapshot().profile,
		"bonus": progression.ad_eligible("bonus", progression.ad_day()),
		"pending": pending, "ad_busy": ads.busy(), "billing_busy": billing.busy(),
		"simulation": billing.adapter.is_test(), "ad_label": ads.label(),
		"catalog": billing.adapter.catalog(), "checkout_ready": billing.adapter.online_ready(),
		"purchase_allowed": billing.adapter.checkout_available(), "paid_wallet": billing.account(),
		"can_connect_account": billing.adapter.can_connect_account(),
		"play_test": _play_test,
		"billing_case": test_billing.scenario if test_billing != null else "",
		"ad_case": test_ads.scenario if test_ads != null else "",
		"state": _store_state, "message": _store_notice,
	})


func _store_action(action: String, value: String) -> void:
	if phase != "store":
		return
	match action:
		"back":
			_leave_store()
		"billing":
			billing.buy(value)
		"restore", "pending":
			billing.restore(action == "pending")
		"account":
			billing.connect_account(value)
		"wallet":
			_show_shop_outcome(progression.shop_buy(value))
		"wallet_account":
			billing.spend_paid(value)
		"skin":
			_show_shop_outcome(progression.shop_skin(value))
		"season":
			_show_shop_outcome(progression.claim_season(value))
		"bonus":
			_request_ad("bonus")
		"billing_case":
			if test_billing != null and value in ["success", "cancelled", "error", "pending", "network_error", "unavailable", "repeat"]:
				test_billing.scenario = value
				_refresh_store()
		"ad_case":
			if test_ads != null and value in ["rewarded", "cancelled", "network_error", "unavailable", "repeat"]:
				test_ads.scenario = value
				_refresh_store()


func _show_shop_outcome(outcome: Dictionary) -> void:
	_shop_status(outcome.state, outcome.message)


func _shop_status(state: String, message: String) -> void:
	_store_state = state
	_store_notice = message
	if state == "success":
		flight_audio.play_event("reward")
	_refresh_store()


func _offer_revive() -> void:
	if phase != "combat":
		return
	phase = "revive"
	_ad_message = ""
	flight_audio.set_scene("pause")
	ui.show_revive(false, "")


func _decline_revive() -> void:
	if phase != "revive" or ads.busy() or not is_instance_valid(arena) or not arena.can_revive():
		return
	phase = "combat"
	arena.decline_revive()


func _refresh_result() -> void:
	_result.double_available = bool(_result.get("ok", false)) and progression.ad_eligible("double", _flight_id)
	_result.ad_busy = ads.busy()
	_result.ad_message = _ad_message
	ui.show_result(_result)


func _request_ad(placement: String) -> void:
	var scope := _flight_id
	match placement:
		"bonus":
			if phase != "store":
				return
			scope = progression.ad_day()
		"double":
			if phase != "result" or not bool(_result.get("ok", false)):
				return
		"revive":
			if phase != "revive" or not is_instance_valid(arena) or not arena.can_revive():
				return
		_:
			return
	if progression.ad_eligible(placement, scope):
		ads.request(placement, scope)
	else:
		_ad_status("claimed", "Ta nagroda nie jest już dostępna.")


func _ad_status(state: String, message: String) -> void:
	_ad_message = message
	match phase:
		"store":
			_shop_status(state, message)
		"result":
			_refresh_result()
		"revive":
			ui.show_revive(ads.busy(), message)


func _credit_ad(placement: String, scope: String) -> void:
	if placement == "revive" and (phase != "revive" or scope != _flight_id or not arena.can_revive()):
		return
	var outcome := progression.claim_rewarded_ad(placement, scope)
	if outcome.ok and scope == _flight_id:
		match placement:
			"revive":
				phase = "combat"
				flight_audio.set_scene(phase)
				arena.revive()
				ui.show_hud()
				return
			"double":
				for key in ["coins", "crystals", "materials", "crates"]:
					_result[key] *= 2
				flight_audio.play_event("reward")
	_ad_status(outcome.state, outcome.message)


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
	_settings.privacy_required = ads.privacy_required
	_settings.privacy_policy_url = _privacy_policy_url
	_settings.diagnostics_available = OS.is_debug_build()
	_settings.diagnostics_enabled = is_instance_valid(_debug_metrics)
	_settings.mix_previewed.connect(_preview_audio)
	_settings.privacy_requested.connect(ads.show_privacy)
	_settings.diagnostics_changed.connect(_set_debug_metrics)
	_settings.effects_sample_requested.connect(flight_audio.play_event.bind("equip"))
	_settings.confirmed.connect(_confirm_settings)
	_settings.cancelled.connect(_cancel_settings)
	ui.get_parent().add_child(_settings)


func _set_debug_metrics(enabled: bool) -> void:
	if not OS.is_debug_build() or enabled == is_instance_valid(_debug_metrics):
		return
	if not enabled:
		_debug_metrics.queue_free()
		_debug_metrics = null
		return
	_debug_metrics = DebugFlightMetrics.new()
	_debug_metrics.name = "DebugFlightMetrics"
	_debug_metrics.arena_provider = func() -> Arena: return arena if phase in ["combat", "pause"] else null
	ui.get_parent().add_child(_debug_metrics)


func _ad_privacy_changed(required: bool, message: String) -> void:
	if is_instance_valid(_settings):
		_settings.update_privacy(required, message)


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
