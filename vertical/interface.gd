extends "res://ui/interface.gd"

signal stage_requested(id: String)
signal campaign_requested

const Campaign := preload("res://vertical/campaign.gd")
const ROUTE_ART := preload("res://assets/art/chapter_one/galaxy.jpg")
const Stars := preload("res://vertical/route_stars.gd")
const HERO := preload("res://assets/art/premium/hero.jpg")
const BOSS_IMAGE := preload("res://assets/art/premium/enemies/asterion.webp")
const Ordnance := preload("res://vertical/ordnance.gd")

var _route: Control
var _route_scroll: ScrollContainer
var _route_motion: Tween
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
var _boss_modules: Label
var _threshold_ticks: Array[ColorRect] = []


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
	_tag(copy, "Rozdział I · %d lotów" % Campaign.ROUTE.size(), Palette.TEXT, 25)
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


func show_campaign(records: Dictionary, reveal_stage := "") -> void:
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
	_image(_route, ROUTE_ART, Color("#a8bdcb"))
	_menu_scrim(_route)
	var content := _safe_content(_route, 24.0, 20.0)
	var shell := _column(9)
	content.add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var nav := _row(12)
	shell.add_child(nav)
	var back := _button(nav, "CampaignBackButton", "‹ MENU", menu_requested.emit)
	back.custom_minimum_size = Vector2(98, 45)
	back.add_theme_font_size_override("font_size", 16)
	var completed := 0
	for record: Dictionary in records.values():
		completed += int(record.get("cleared", false))
	var chapter := _tag(nav, "ROZDZIAŁ I", Palette.CYAN, 17)
	chapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tally := _tag(nav, "%02d / %02d LOTÓW" % [completed, Campaign.ROUTE.size()], Palette.TEXT, 15)
	tally.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag(shell, "Atlas kampanii", Palette.TEXT, 41)

	var tabs := ScrollContainer.new()
	tabs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tabs.custom_minimum_size.y = 49.0
	shell.add_child(tabs)
	var jumps := _row(5)
	jumps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(jumps)

	_route_scroll = ScrollContainer.new()
	_route_scroll.name = "CampaignScroll"
	_route_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_route_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_route_scroll.scroll_deadzone = 12
	_route_scroll.follow_focus = true
	shell.add_child(_route_scroll)
	var scrollbar := _route_scroll.get_v_scroll_bar()
	var handle := Palette.panel(Color("#749aa9"), Color.TRANSPARENT, 3)
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(state, handle)
	scrollbar.add_theme_stylebox_override("scroll", Palette.panel(Color("#182433"), Color.TRANSPARENT, 3))
	var spine := _column(9)
	spine.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_scroll.add_child(spine)

	for sector: Dictionary in Campaign.SECTORS:
		var first: int = sector.start
		var ids := Campaign.ROUTE.slice(first, first + int(sector.size))
		if ids.is_empty():
			continue
		var open := Campaign.access(records, ids.front())
		var zone := _section(spine, sector, open, str(ids.front()))
		var short: String = sector.get("tab", str(sector.title).split(" ")[-1])
		var jump := _button(jumps, "SectorJump_%02d" % first, short.to_upper(), _scroll_to_route.bind(zone))
		jump.add_theme_font_size_override("font_size", 13)
		jump.custom_minimum_size = Vector2(103.0, 44.0)
		jump.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for id: String in ids:
			var anchor := _stage_card(spine, id, records, id == reveal_stage)
			if id == reveal_stage:
				_scroll_when_ready(anchor)
	_reveal(shell, 0.27)


func _section(parent: Container, sector: Dictionary, open: bool, id: String) -> Control:
	var tone: Color = sector.tone
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", Palette.plate(Color("#102131"), tone.darkened(0.57), 13, 2.0))
	parent.add_child(panel)
	var cover := Control.new()
	cover.clip_contents = true
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.custom_minimum_size.y = 87.0
	panel.add_child(cover)
	_image(cover, load(Campaign.STAGES[id].sky), Color("#b5c2cf"))
	_card_scrim(cover)
	var labels := _column(1)
	cover.add_child(labels)
	labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	labels.offset_left = 16.0
	labels.offset_top = 12.0
	labels.offset_right = -12.0
	_tag(labels, "SEKTOR %02d–%02d  ·  %s" % [int(sector.start) + 1, int(sector.start) + int(sector.size),
		"OTWARTY" if open else "ZABLOKOWANY"], tone, 14)
	_tag(labels, str(sector.title), Palette.TEXT, 29)
	return panel


func _stage_card(parent: Container, id: String, records: Dictionary, highlight: bool) -> Control:
	var stage: Dictionary = Campaign.STAGES[id]
	var tone: Color = stage.tone
	var accessible := Campaign.access(records, id)
	var record: Dictionary = records.get(id, {})
	var cleared := bool(record.get("cleared", false))
	var title := str(stage.title)
	var route_row := _row(5)
	parent.add_child(route_row)
	var rail := CenterContainer.new()
	rail.custom_minimum_size.x = 51.0
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	route_row.add_child(rail)
	rail.draw.connect(_draw_route_rail.bind(rail, tone, accessible))
	rail.resized.connect(rail.queue_redraw)
	var marker := PanelContainer.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.custom_minimum_size = Vector2(43.0, 40.0)
	marker.add_theme_stylebox_override("panel", Palette.plate(Color("#142638"), tone.darkened(0.19 if accessible else 0.64), 9, 3))
	rail.add_child(marker)
	var number := _tag(marker, "%02d" % (Campaign.ROUTE.find(id) + 1), tone if accessible else Palette.MUTED, 18)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := Palette.plate(Color("#101b2b"), tone.darkened(0.54 if accessible else 0.70), 13, 2.0)
	style.border_width_left = 3
	panel.add_theme_stylebox_override("panel", style)
	route_row.add_child(panel)
	var bay := Control.new()
	bay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bay.custom_minimum_size.y = 158.0 if accessible else 133.0
	bay.clip_contents = true
	panel.add_child(bay)
	_image(bay, load(stage.sky), Color("#92a9be") if accessible else Color("#6d829b"))
	var art := TextureRect.new()
	art.texture = _route_art(stage, id)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.modulate = Color("#e0ebf2") if accessible else Color("#95a7be")
	bay.add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	art.offset_left = -183
	art.offset_right = 0
	art.offset_top = -86
	art.offset_bottom = 86
	_card_scrim(bay)
	var content := _column(3)
	bay.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14.0
	content.offset_top = 8.0
	content.offset_right = -12.0
	content.offset_bottom = -8.0
	var boss_name := str(Campaign.BOSS_NAMES.get(id, ""))
	_tag(content, str(stage.region) if boss_name.is_empty() else "BOSS · " + boss_name.to_upper(),
		Palette.AMBER if not boss_name.is_empty() else tone, 14)
	_tag(content, title, Palette.TEXT, 25)
	var record_row := _row(9)
	content.add_child(record_row)
	_add_stars(record_row, int(record.get("stars", 0)))
	var best := int(record.get("best", 0))
	_tag(record_row, "REKORD %d" % best if best > 0 else "REKORD —", Palette.MUTED, 15)
	var extras := Campaign.first_reward(id)
	var payout := "Premia +%d Credits · +%d mat." % [extras[0], extras[1]]
	if cleared:
		payout = "Materiały od %d · skrzynia do %d%%" % [stage.reward, Campaign.cache_chance(id, 3)]
	if not accessible:
		payout = "Ukończ poprzedni lot"
	_body(content, payout, 16, Palette.TEXT if accessible else Palette.MUTED)
	if accessible:
		var actions := _row(6)
		content.add_child(actions)
		var launch := _button(actions, "LaunchStage_" + id, "POWTÓRZ LOT" if cleared else "ROZPOCZNIJ LOT", stage_requested.emit.bind(id), true)
		launch.custom_minimum_size = Vector2(170, 43)
		launch.add_theme_font_size_override("font_size", 15)
	if highlight:
		var tween := panel.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(style, "border_color", tone.darkened(0.24), 1.24).from(tone.lightened(0.52))
		tween.parallel().tween_property(art, "modulate", art.modulate, 1.02).from(tone.lightened(0.40))
	return route_row


func _add_stars(parent: Container, grade: int) -> void:
	var stars := Stars.new()
	stars.grade = grade
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(stars)


func _route_art(stage: Dictionary, id: String) -> Texture2D:
	match id:
		"helion": return BOSS_IMAGE
		"guardian": return load("res://assets/art/chapter_one/enemies/vesperon.webp")
		"abyss": return load("res://assets/art/chapter_one/enemies/nadir.webp")
	return load(stage.planet)


func _draw_route_rail(rail: Control, tone: Color, available: bool) -> void:
	var x := rail.size.x * 0.5
	var ends := Vector2(x, rail.size.y + 9.0)
	var color := Color(tone, 0.53 if available else 0.25)
	rail.draw_line(Vector2(x, -9.0), ends, Color(tone, 0.13), 5.0, true)
	rail.draw_dashed_line(Vector2(x, -9.0), ends, color, 1.8, 9.0)


func _scroll_when_ready(anchor: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(anchor):
		_scroll_to_route(anchor)


func _scroll_to_route(anchor: Control) -> void:
	if not is_instance_valid(_route_scroll) or not anchor.is_inside_tree():
		return
	var from := _route_scroll.scroll_vertical
	var delta := anchor.get_global_rect().position.y - _route_scroll.get_global_rect().position.y
	var limit := _route_scroll.get_v_scroll_bar().max_value - _route_scroll.get_v_scroll_bar().page
	var goal := roundi(clampf(from + delta - 8.0, 0.0, maxf(0.0, limit)))
	if _route_motion != null and _route_motion.is_valid():
		_route_motion.kill()
	_route_motion = _route_scroll.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_route_motion.tween_property(_route_scroll, "scroll_vertical", goal, 0.33)


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
	_route_scroll = null


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
	_boss_modules = _tag(boss_labels, "", Palette.MUTED, 13)
	_boss_modules.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_boss_integrity_label = _tag(boss_labels, "100%", Palette.TEXT, 18)
	_boss_bar = _bar(boss_info, Palette.DANGER, 8.0)
	_boss_fill = _boss_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var thresholds := Control.new()
	thresholds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar.add_child(thresholds)
	thresholds.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_threshold_ticks.clear()
	for index in 3:
		var tick := ColorRect.new()
		tick.color = Color("#121322bc")
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thresholds.add_child(tick)
		tick.anchor_bottom = 1.0
		_threshold_ticks.append(tick)

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
		var phases := maxi(1, int(_telemetry.get("boss_phases", 3)))
		var phase_index := clampi(int(_telemetry.get("boss_phase", 1)), 1, phases)
		var tone: Color = _telemetry.get("boss_tone", Palette.DANGER)
		_boss_name.text = "%s  ·  FAZA %d / %d" % [_telemetry.get("boss_name", "ASTERION"), phase_index, phases]
		_boss_name.add_theme_color_override("font_color", tone)
		var parts := int(_telemetry.get("boss_modules", -1))
		_boss_modules.visible = parts >= 0
		_boss_modules.text = "MODUŁY %d" % parts
		_boss_bar.max_value = float(_telemetry.boss_max)
		_boss_bar.value = hp_boss
		_boss_fill.bg_color = tone
		_boss_fill.border_color = tone
		_boss_integrity_label.text = "%d%%" % ceili(hp_boss / _boss_bar.max_value * 100.0)
		for index in _threshold_ticks.size():
			var tick := _threshold_ticks[index]
			tick.visible = index + 1 < phases
			tick.anchor_left = float(index + 1) / phases
			tick.anchor_right = tick.anchor_left
			tick.offset_left = -1.0
			tick.offset_right = 1.0


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
	var boss_name := str(Campaign.BOSS_NAMES.get(data.get("stage", ""), "Okręt dowodzenia"))
	var summary := boss_name + " zniszczony" if data.get("boss_defeated", false) else "%d ukończonych fal" % int(data.waves)
	var caption := "%s  ·  %s" % [summary, _clock(float(data.seconds))]
	_heading(stack, title, caption, color, "victory" if won else "defeat")
	if won:
		var stars := _row(10)
		stack.add_child(stars)
		var grade := int(data.get("stars", 0))
		_add_stars(stars, grade)
		_tag(stars, "%d / 3" % grade, Palette.AMBER, 17)
		if data.get("first_clear", false):
			_tag(stars, "PIERWSZE UKOŃCZENIE", Palette.SUCCESS, 15)
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
	if data.get("bonus_cache", false):
		_body(rewards, "Odnaleziono dodatkową skrzynię", 17, Palette.AMBER)
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
