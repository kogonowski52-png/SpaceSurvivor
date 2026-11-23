extends "res://ui/interface.gd"

signal stage_requested(id: String)
signal campaign_requested

const Campaign := preload("res://vertical/campaign.gd")
const ROUTE_ART := preload("res://assets/art/vertical/helion.jpg")
const STAGES_PER_PAGE := 3

var _route: Control
var _flight_title: Label
var _flight_wave: Label
var _flight_score: Label
var _weapon: Label
var _fire_rank: Label
var _power_flash: Label
var _flight_notice: Label
var _notice_anchor: CenterContainer
var _warning_strip: PanelContainer


func show_campaign(records: Dictionary, page_index := 0) -> void:
	_clear_modal()
	_close_campaign()
	_drop_hangar()
	_drop_store()
	_drop(_hud)
	_drop(_menu)
	_hud = null
	_menu = null
	_telemetry = {}
	_route = _page("Campaign")
	var background := TextureRect.new()
	background.texture = ROUTE_ART
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.modulate = Color("#687a93")
	_route.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_menu_scrim(_route)
	var content := _safe_content(_route, 26.0, 23.0)
	var stack := _column(13)
	content.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var nav := _row(10)
	stack.add_child(nav)
	var back := _button(nav, "CampaignBackButton", "‹ MENU", menu_requested.emit)
	back.custom_minimum_size = Vector2(105, 49)
	back.add_theme_font_size_override("font_size", 17)
	var chapter := _tag(nav, "KAMPANIA  /  PRÓG HELIONU", Palette.CYAN, 17)
	chapter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag(stack, "Wybierz lot", Palette.TEXT, 42)
	var pages := ceili(float(Campaign.ROUTE.size()) / STAGES_PER_PAGE)
	page_index = clampi(page_index, 0, pages - 1)
	var start := page_index * STAGES_PER_PAGE
	for id: String in Campaign.ROUTE.slice(start, start + STAGES_PER_PAGE):
		_stage_card(stack, id, records)
	if pages > 1:
		var navigation := _row(10)
		stack.add_child(navigation)
		var previous := _button(navigation, "PreviousRoutePage", "‹ POPRZEDNIA", show_campaign.bind(records, page_index - 1))
		var index := _tag(navigation, "%d / %d" % [page_index + 1, pages], Palette.MUTED, 17)
		index.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		index.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var following := _button(navigation, "NextRoutePage", "NASTĘPNA ›", show_campaign.bind(records, page_index + 1))
		previous.disabled = page_index == 0
		following.disabled = page_index == pages - 1
	_reveal(stack, 0.24)


func _stage_card(parent: Container, id: String, records: Dictionary) -> void:
	var stage: Dictionary = Campaign.STAGES[id]
	var tone: Color = stage.tone
	var accessible := Campaign.access(records, id)
	var record: Dictionary = records.get(id, {})
	var panel := PanelContainer.new()
	var style := Palette.plate(Color("#101a29f5"), tone.darkened(0.52 if accessible else 0.72), 12, 11.0)
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	var card := _row(12)
	panel.add_child(card)
	var preview := TextureRect.new()
	preview.texture = load(stage.sky)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.custom_minimum_size = Vector2(112.0, 152.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hung := preview.modulate
	hung.a = 1.0 if accessible else 0.64
	preview.modulate = hung
	card.add_child(preview)
	if id == "helion":
		var command_ship := TextureRect.new()
		command_ship.texture = preload("res://assets/art/vertical/asterion.webp")
		command_ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		command_ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		command_ship.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(command_ship)
		command_ship.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		command_ship.offset_left = 7
		command_ship.offset_right = -7
	var details := _column(5)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(details)
	var index := Campaign.ROUTE.find(id) + 1
	var state := "UKOŃCZONO" if record.get("cleared", false) else ("DOSTĘPNY" if accessible else "ZABLOKOWANY")
	_tag(details, "LOT %02d  ·  %s" % [index, state], tone if accessible else Palette.MUTED, 14)
	_tag(details, stage.title, Palette.TEXT, 24)
	_body(details, str(stage.subtitle), 18, Palette.MUTED)
	if int(record.get("best", 0)) > 0:
		_tag(details, "REKORD  %s" % str(record.best), tone, 15)
	var launch := _button(details, "LaunchStage_" + id, "ROZPOCZNIJ LOT" if accessible else "PO UKOŃCZENIU POPRZEDNIEGO",
		stage_requested.emit.bind(id), accessible)
	launch.custom_minimum_size.y = 48
	launch.add_theme_font_size_override("font_size", 16)
	launch.disabled = not accessible


func show_menu(sortie: Dictionary = {}) -> void:
	_close_campaign()
	super.show_menu(sortie)


func show_hud() -> void:
	_close_campaign()
	super.show_hud()


func _close_campaign() -> void:
	_drop(_route)
	_route = null


func _build_hud(content: Control) -> void:
	var header := _column(7)
	content.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var rail := _row(7)
	header.add_child(rail)
	var course := _hud_cell(rail)
	course.get_parent().size_flags_stretch_ratio = 2.05
	_flight_title = _tag(course, "LOT", Palette.TEXT, 19)
	_flight_wave = _tag(course, "FALA 01 / 04", Palette.CYAN, 13)
	var shield := _hud_cell(rail)
	_health_value = _tag(shield, "KADŁUB 100%", Palette.TEXT, 15)
	_health_bar = _bar(shield, Palette.CYAN, 5.0)
	_pause_button = _button(rail, "PauseButton", "", pause_requested.emit)
	_pause_button.custom_minimum_size = Vector2(52, 54)
	_pause_button.accessibility_name = "Pauza"
	_button_glyph(_pause_button, "pause", Palette.TEXT)
	var boss_info := _hud_cell(header)
	_boss_panel = boss_info.get_parent() as PanelContainer
	_boss_panel.name = "BossHUD"
	_boss_name = _tag(boss_info, "ASTERION", Palette.DANGER, 17)
	_boss_bar = _bar(boss_info, Palette.DANGER, 7.5)

	var notice := PanelContainer.new()
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.add_theme_stylebox_override("panel", Palette.plate(Color("#111b2bf0"), Palette.OUTLINE, 8, 9.0))
	_notice_anchor = CenterContainer.new()
	_notice_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_notice_anchor)
	_notice_anchor.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_notice_anchor.add_child(notice)
	_flight_notice = _tag(notice, "", Palette.TEXT, 18)
	_flight_notice.name = "FlightNotice"
	_flight_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_strip = notice

	var footer := _column(5)
	content.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_power_flash = _tag(footer, "", Palette.CYAN, 19)
	_power_flash.name = "PowerNotice"
	_power_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var line := _row(8)
	footer.add_child(line)
	var power := _hud_cell(line)
	power.get_parent().size_flags_stretch_ratio = 2.1
	_weapon = _tag(power, "LASER CANNON", Palette.TEXT, 17)
	_fire_rank = _tag(power, "MOC 01 / 07", Palette.CYAN, 14)
	_fire_rank.name = "PowerRank"
	var score := _hud_cell(line)
	_tag(score, "WYNIK", Palette.MUTED, 13)
	_flight_score = _tag(score, "0", Palette.TEXT, 20)


func _render_hud() -> void:
	if not is_instance_valid(_flight_title):
		return
	_flight_title.text = str(_telemetry.get("title", "Lot")).to_upper()
	_flight_wave.text = "FALA %02d / %02d" % [maxi(1, int(_telemetry.get("wave", 1))), int(_telemetry.get("waves", 4))]
	var limit := maxf(1.0, float(_telemetry.get("max_hp", 100.0)))
	var hp := float(_telemetry.get("hp", limit))
	_health_bar.max_value = limit
	_health_bar.value = hp
	_health_value.text = "KADŁUB %d%%" % roundi(hp / limit * 100.0)
	_health_value.modulate = Palette.DANGER if hp < limit * 0.27 else Color.WHITE
	_weapon.text = str(_telemetry.get("weapon", "Laser Cannon")).to_upper()
	_fire_rank.text = "MOC %02d / 07" % int(_telemetry.get("power", 1))
	_flight_score.text = str(_telemetry.get("score", 0))
	_power_flash.text = str(_telemetry.get("power_notice", ""))
	_power_flash.visible = not _power_flash.text.is_empty()
	_power_flash.add_theme_color_override("font_color", _telemetry.get("power_color", Palette.CYAN))
	var danger := str(_telemetry.get("danger", ""))
	_flight_notice.text = str(_telemetry.get("briefing", "")) if danger.is_empty() else danger
	_flight_notice.add_theme_color_override("font_color", Palette.TEXT if danger.is_empty() else Palette.DANGER)
	var notice_position := 0.10 if danger.is_empty() else 0.37
	_notice_anchor.anchor_top = notice_position
	_notice_anchor.anchor_bottom = notice_position
	_warning_strip.visible = not _flight_notice.text.is_empty()
	var hp_boss := float(_telemetry.get("boss_hp", -1.0))
	_boss_panel.visible = hp_boss >= 0.0
	if _boss_panel.visible:
		_boss_name.text = "ASTERION  ·  FAZA %d / 3" % int(_telemetry.get("boss_phase", 1))
		_boss_bar.max_value = float(_telemetry.boss_max)
		_boss_bar.value = hp_boss


func _animate_hud_changes(previous: Dictionary) -> void:
	if int(_telemetry.get("power", 1)) > int(previous.get("power", 1)):
		_reveal(_power_flash, 0.23)


func show_result(data: Dictionary) -> void:
	var won := bool(data.won)
	var color := Palette.SUCCESS if won else Palette.DANGER
	var stack := _modal_stack("ResultOverlay", color, 0.67)
	_tag(stack, str(data.sector_title).to_upper(), color, 16)
	var title := "LOT UKOŃCZONY" if won else ("CZAS UPŁYNĄŁ" if data.get("timed_out", false) else "STATEK UTRACONY")
	var caption := ("Asterion rozpadł się na orbicie." if data.get("boss_defeated", false) else
		"Fale zaliczone: %d  ·  %s" % [int(data.waves), _clock(float(data.seconds))])
	_heading(stack, title, caption, color, "victory" if won else "defeat")
	var stats := _row(8)
	stack.add_child(stats)
	_stat(stats, "WYNIK", str(data.score))
	_stat(stats, "ZESTRZELENIA", str(data.kills))
	_stat(stats, "MOC OGNIA", str(data.level))
	_tag(stack, "NAGRODY Z LOTU", Palette.AMBER, 15)
	var loot := _row(8)
	loot.name = "RewardRow"
	stack.add_child(loot)
	_stat(loot, "CREDITS", "+%d" % int(data.get("coins", 0)))
	_stat(loot, "MATERIAŁY", "+%d" % int(data.get("materials", 0)))
	_stat(loot, "SKRZYNIE", "+%d" % int(data.get("crates", 0)))
	if int(data.get("crystals", 0)) > 0:
		_body(stack, "+%d Crystals" % int(data.crystals), 18, Palette.VIOLET)
	if not data.get("ok", true):
		_body(stack, "Zapis wyniku nie powiódł się.", 19, Palette.DANGER)
	var busy := bool(data.get("ad_busy", false))
	if data.get("double_available", false):
		var bonus := _button(stack, "DoubleRewardButton", "PODWÓJ WYPŁATĘ · " + ad_label, rewarded_ad_requested.emit.bind("double"))
		bonus.add_theme_font_size_override("font_size", 16)
		bonus.disabled = busy
	if not str(data.get("ad_message", "")).is_empty():
		_body(stack, data.ad_message, 16, Palette.MUTED)
	var followup := str(data.get("next_stage", ""))
	if won and not followup.is_empty():
		_button(stack, "NextStageButton", "NASTĘPNY LOT", stage_requested.emit.bind(followup), true).disabled = busy
	var navigation := _row(7)
	stack.add_child(navigation)
	var replay := _button(navigation, "RestartButton", "POWTÓRZ", restart_requested.emit)
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay.disabled = busy
	var levels := _button(navigation, "CampaignButton", "LISTA LOTÓW", campaign_requested.emit)
	levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels.disabled = busy
	_button(stack, "ResultHangarButton", "HANGAR", hangar_requested.emit).disabled = busy
