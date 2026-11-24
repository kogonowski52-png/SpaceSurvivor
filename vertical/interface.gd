extends "res://ui/interface.gd"

signal stage_requested(id: String)
signal campaign_requested

const Campaign := preload("res://vertical/campaign.gd")
const ROUTE_ART := preload("res://assets/art/premium/sky/helion.jpg")
const HERO := preload("res://assets/art/premium/hero.jpg")
const BOSS_IMAGE := preload("res://assets/art/premium/enemies/asterion.webp")
const Commander := preload("res://vertical/commander.gd")
const Ordnance := preload("res://vertical/ordnance.gd")
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
var _rank_ticks: Array[ColorRect] = []
var _boss_fill: StyleBoxFlat
var _boss_integrity_label: Label


func show_menu(sortie: Dictionary = {}) -> void:
	_close_campaign()
	_clear_modal()
	_drop_store()
	_drop_hangar()
	_drop(_hud)
	_drop(_menu)
	_hud = null
	_telemetry = {}
	_menu = _page("Menu")

	_image(_menu, HERO, Color.WHITE)
	_menu_scrim(_menu)

	var content := _safe_content(_menu, 27.0, 24.0)
	var wordmark := _column(3)
	content.add_child(wordmark)
	wordmark.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var masthead := _row(10)
	wordmark.add_child(masthead)
	var strap := _tag(masthead, "KAMPANIA  /  %s" % ProjectSettings.get_setting("application/config/version"), Palette.CYAN, 16)
	strap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var settings := _button(masthead, "SettingsButton", "", settings_requested.emit)
	settings.custom_minimum_size = Vector2(53, 48)
	settings.accessibility_name = "Ustawienia"
	settings.tooltip_text = settings.accessibility_name
	_button_glyph(settings, "settings", Palette.TEXT)
	_tag(wordmark, "GALAXY STRIKE", Palette.TEXT, 57)
	_tag(wordmark, "Próg Helionu", Color("#b6daea"), 25)

	var bottom := _column(10)
	content.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var mission := _paper(bottom, Palette.CYAN, Color("#0b1723ed"), 15.0)
	var heading := _row(10)
	mission.add_child(heading)
	var copy := _column(2)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(copy)
	_tag(copy, "TRASA PILOTA", Palette.MUTED, 14)
	_tag(copy, "Trzy sektory do Helionu", Palette.TEXT, 25)
	var status := _column(2)
	heading.add_child(status)
	_tag(status, str(sortie.get("route_progress", "0 / 3")), Palette.CYAN, 24)
	_tag(status, "UKOŃCZONE", Palette.MUTED, 13)
	var launch := _button(bottom, "LaunchButton", "OTWÓRZ KAMPANIĘ", launch_requested.emit, true)
	launch.custom_minimum_size.y = 65
	launch.add_theme_font_size_override("font_size", 21)
	_button_glyph(launch, "arrow", Palette.NIGHT, true)
	var second := _row(10)
	bottom.add_child(second)
	var hangar := _button(second, "HangarButton", "HANGAR", hangar_requested.emit)
	var store := _button(second, "StoreButton", "SKLEP", store_requested.emit)
	for control in [hangar, store]:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.y = 53
		control.add_theme_font_size_override("font_size", 18)
	_reveal(wordmark, 0.31)
	_reveal(bottom, 0.38)


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
	_image(_route, ROUTE_ART, Color("#53657c"))
	_menu_scrim(_route)
	var content := _safe_content(_route, 25.0, 22.0)
	var stack := _column(12)
	content.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)

	var nav := _row(13)
	stack.add_child(nav)
	var back := _button(nav, "CampaignBackButton", "‹ MENU", menu_requested.emit)
	back.custom_minimum_size = Vector2(101, 47)
	back.add_theme_font_size_override("font_size", 17)
	var chapter := _tag(nav, "PRÓG HELIONU", Palette.CYAN, 17)
	chapter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag(stack, "Wybierz lot", Palette.TEXT, 43)
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
	_reveal(stack, 0.29)


func _stage_card(parent: Container, id: String, records: Dictionary) -> void:
	var stage: Dictionary = Campaign.STAGES[id]
	var tone: Color = stage.tone
	var accessible := Campaign.access(records, id)
	var record: Dictionary = records.get(id, {})
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := Palette.plate(Color("#101b2b"), tone.darkened(0.55 if accessible else 0.69), 12, 2.0)
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var bay := Control.new()
	bay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bay.custom_minimum_size.y = 189.0
	bay.clip_contents = true
	panel.add_child(bay)
	_image(bay, load(stage.sky), Color("#afc3d7") if accessible else Color("#8194ae"))
	var artwork := TextureRect.new()
	artwork.texture = BOSS_IMAGE if id == "helion" else load(stage.planet)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.modulate = Color("#f2f6ff") if accessible else Color("#aebaca")
	bay.add_child(artwork)
	artwork.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	artwork.offset_left = -230.0
	artwork.offset_right = 15.0 if id != "helion" else 0.0
	artwork.offset_top = -100.0
	artwork.offset_bottom = 107.0
	_card_scrim(bay)
	var details := _column(3)
	bay.add_child(details)
	details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details.offset_left = 17.0
	details.offset_right = -17.0
	details.offset_top = 13.0
	details.offset_bottom = -10.0

	_tag(details, "%02d  /  %s" % [Campaign.ROUTE.find(id) + 1, stage.region], tone, 14)
	_tag(details, stage.title, Palette.TEXT, 30)
	var description := _body(details, str(stage.subtitle), 18, Color("#c2d2e4"))
	description.custom_minimum_size.y = 44
	var footer := _row(11)
	details.add_child(footer)
	if accessible:
		var launch := _button(footer, "LaunchStage_" + id, "ROZPOCZNIJ LOT", stage_requested.emit.bind(id), true)
		launch.custom_minimum_size = Vector2(185, 45)
		launch.add_theme_font_size_override("font_size", 16)
		if int(record.get("best", 0)) > 0:
			var best := _tag(footer, "REKORD %s" % str(record.best), Palette.TEXT, 15)
			best.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	else:
		_tag(footer, "■  UKOŃCZ POPRZEDNI LOT", Palette.MUTED, 15)


func _image(parent: Control, art: Texture2D, tone: Color) -> void:
	var view := TextureRect.new()
	view.texture = art
	view.modulate = tone
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _menu_scrim(parent: Control) -> void:
	_scrim(parent, PackedFloat32Array([0.0, 0.23, 0.36, 0.59, 0.74, 1.0]),
		PackedColorArray([Color("#050a15ed"), Color("#050a154f"), Color("#050a1503"),
			Color("#050a1514"), Color("#050a15b5"), Color("#050a15ff")]), Vector2.DOWN)


func _card_scrim(parent: Control) -> void:
	_scrim(parent, PackedFloat32Array([0.0, 0.50, 0.82, 1.0]),
		PackedColorArray([Color("#071220fa"), Color("#071220dd"), Color("#0712205c"), Color("#0712202b")]), Vector2.RIGHT)


func _scrim(parent: Control, stops: PackedFloat32Array, colors: PackedColorArray, direction: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.offsets = stops
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.width = 256 if direction == Vector2.RIGHT else 4
	texture.height = 256 if direction == Vector2.DOWN else 4
	texture.gradient = gradient
	texture.fill_to = direction
	_image(parent, texture, Color.WHITE)
	var mask := parent.get_child(-1) as TextureRect
	mask.stretch_mode = TextureRect.STRETCH_SCALE


func _paper(parent: Container, tone: Color, fill: Color, inset: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := Palette.plate(fill, tone.darkened(0.56), 13, inset)
	surface.border_width_left = 3
	panel.add_theme_stylebox_override("panel", surface)
	parent.add_child(panel)
	var content := _column(4)
	panel.add_child(content)
	return content


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
	course.get_parent().size_flags_stretch_ratio = 2.18
	_flight_title = _tag(course, "LOT", Palette.TEXT, 20)
	_flight_wave = _tag(course, "FALA 01", Palette.CYAN, 14)
	var shield := _hud_cell(rail)
	_health_value = _tag(shield, "KADŁUB 100%", Palette.TEXT, 15)
	_health_bar = _bar(shield, Palette.CYAN, 6.0)
	_pause_button = _button(rail, "PauseButton", "", pause_requested.emit)
	_pause_button.custom_minimum_size = Vector2(52, 54)
	_pause_button.accessibility_name = "Pauza"
	_button_glyph(_pause_button, "pause", Palette.TEXT)
	var boss_info := _paper(header, Palette.DANGER, Color("#151824f6"), 9.0)
	_boss_panel = boss_info.get_parent() as PanelContainer
	_boss_panel.name = "BossHUD"
	var boss_labels := _row(8)
	boss_info.add_child(boss_labels)
	_boss_name = _tag(boss_labels, "ASTERION", Palette.DANGER, 18)
	_boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_integrity_label = _tag(boss_labels, "100%", Palette.TEXT, 18)
	_boss_bar = _bar(boss_info, Palette.DANGER, 8.0)
	_boss_fill = _boss_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var thresholds := Control.new()
	thresholds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(thresholds)
	thresholds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for position_ratio in [1.0 / 3.0, 2.0 / 3.0]:
		var tick := ColorRect.new()
		tick.color = Color("#121322bc")
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thresholds.add_child(tick)
		tick.anchor_left = position_ratio
		tick.anchor_right = position_ratio
		tick.anchor_bottom = 1.0
		tick.offset_left = -1.0
		tick.offset_right = 1.0

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
	var rank_meter := _row(4)
	power.add_child(rank_meter)
	_rank_ticks.clear()
	for index in Ordnance.EMITTERS.size():
		var tick := ColorRect.new()
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.custom_minimum_size.y = 4.0
		tick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rank_meter.add_child(tick)
		_rank_ticks.append(tick)
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
	var rank := clampi(int(_telemetry.get("power", 1)), 1, _rank_ticks.size())
	var rank_tone: Color = Ordnance.RANK_COLORS[rank - 1]
	_fire_rank.text = "MOC %02d / 07" % rank
	_fire_rank.add_theme_color_override("font_color", rank_tone)
	for index in _rank_ticks.size():
		_rank_ticks[index].color = rank_tone if index < rank else Color("#284050")
	_flight_score.text = str(_telemetry.get("score", 0))
	_power_flash.text = str(_telemetry.get("power_notice", ""))
	_power_flash.visible = not _power_flash.text.is_empty()
	_power_flash.add_theme_color_override("font_color", _telemetry.get("power_color", Palette.CYAN))
	var danger := str(_telemetry.get("danger", ""))
	_flight_notice.text = str(_telemetry.get("briefing", "")) if danger.is_empty() else danger
	_flight_notice.add_theme_color_override("font_color", Palette.TEXT if danger.is_empty() else Palette.DANGER)
	var notice_position := 0.10 if danger.is_empty() else 0.43
	_notice_anchor.anchor_top = notice_position
	_notice_anchor.anchor_bottom = notice_position
	_warning_strip.visible = not _flight_notice.text.is_empty()
	var hp_boss := float(_telemetry.get("boss_hp", -1.0))
	_boss_panel.visible = hp_boss >= 0.0
	if _boss_panel.visible:
		var phase_index := clampi(int(_telemetry.get("boss_phase", 1)), 1, 3)
		var tone: Color = Commander.PHASE_COLORS[phase_index - 1]
		_boss_name.text = "ASTERION  ·  FAZA %d / 3" % phase_index
		_boss_name.add_theme_color_override("font_color", tone)
		_boss_bar.max_value = float(_telemetry.boss_max)
		_boss_bar.value = hp_boss
		_boss_fill.bg_color = tone
		_boss_fill.border_color = tone
		_boss_integrity_label.text = "%d%%" % ceili(hp_boss / _boss_bar.max_value * 100.0)


func _animate_hud_changes(previous: Dictionary) -> void:
	if int(_telemetry.get("power", 1)) > int(previous.get("power", 1)):
		_reveal(_power_flash, 0.23)
	if previous.get("boss_phase", 0) != _telemetry.get("boss_phase", 0) and _boss_panel.visible:
		_reveal(_boss_panel, 0.22)


func show_result(data: Dictionary) -> void:
	var won := bool(data.won)
	var color := Palette.SUCCESS if won else Palette.DANGER
	var stack := _modal_stack("ResultOverlay", color, 0.58)
	_tag(stack, str(data.sector_title).to_upper(), color, 16)
	var title := "LOT UKOŃCZONY" if won else ("CZAS UPŁYNĄŁ" if data.get("timed_out", false) else "STATEK UTRACONY")
	var summary := "Asterion zniszczony" if data.get("boss_defeated", false) else "%d ukończonych fal" % int(data.waves)
	var caption := "%s  ·  %s" % [summary, _clock(float(data.seconds))]
	_heading(stack, title, caption, color, "victory" if won else "defeat")
	var tally := _paper(stack, color, Color("#0d1927"), 11.0)
	var report := _row(9)
	tally.add_child(report)
	for spec in [["WYNIK", data.score], ["ZESTRZELENIA", data.kills], ["MOC OGNIA", data.level]]:
		var cell := _column(2)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		report.add_child(cell)
		_tag(cell, spec[0], Palette.MUTED, 13)
		_tag(cell, str(spec[1]), color, 30)
	var rewards := _paper(stack, Palette.AMBER, Color("#161e2a"), 10.0)
	_tag(rewards, "NAGRODY Z LOTU", Palette.AMBER, 15)
	var loot := _row(8)
	loot.name = "RewardRow"
	rewards.add_child(loot)
	_stat(loot, "CREDITS", "+%d" % int(data.get("coins", 0)))
	_stat(loot, "MATERIAŁY", "+%d" % int(data.get("materials", 0)))
	_stat(loot, "SKRZYNIE", "+%d" % int(data.get("crates", 0)))
	if int(data.get("crystals", 0)) > 0:
		_body(rewards, "+%d Crystals" % int(data.crystals), 18, Palette.VIOLET)
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
	var replay := _button(navigation, "RestartButton", "POWTÓRZ", restart_requested.emit, not won)
	replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay.disabled = busy
	var levels := _button(navigation, "CampaignButton", "LISTA LOTÓW", campaign_requested.emit)
	levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels.disabled = busy
	_button(stack, "ResultHangarButton", "HANGAR", hangar_requested.emit).disabled = busy
