extends Control

signal launch_requested
signal pause_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal upgrade_selected(id: String)
signal hangar_requested
signal hangar_action(action: String, value: String)

const Palette = preload("res://ui/palette.gd")
const FlightGlyph = preload("res://ui/flight_glyph.gd")
const Body = preload("res://assets/fonts/Barlow-Medium.ttf")
const Display = preload("res://assets/fonts/Oxanium.ttf")
const Mission := preload("res://data/missions/peryhelium.tres")
const Hangar := preload("res://ui/hangar.gd")
const PAGE_MARGIN := 28.0
const RARITIES := {
	"common": { "title": "POSPOLITA", "accent": Palette.MUTED },
	"rare": { "title": "RZADKA", "accent": Palette.CYAN },
	"epic": { "title": "EPICKA", "accent": Palette.VIOLET },
	"legendary": { "title": "LEGENDARNA", "accent": Color("#ffd17e") },
}

var _headline := FontVariation.new()
var _detail := FontVariation.new()
var _menu: Control
var _hangar: Hangar
var _hud: Control
var _modal: Control
var _pause_button: Button
var _health_bar: ProgressBar
var _health_value: Label
var _timer: Label
var _kills: Label
var _xp_bar: ProgressBar
var _xp_value: Label
var _level: Label
var _wave_panel: PanelContainer
var _wave_number: Label
var _wave_name: Label
var _warning: Label
var _boss_panel: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_integrity: Label
var _hp_pulse: Tween
var _xp_pulse: Tween
var _wave_pulse: Tween
var _telemetry: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var weight := TextServerManager.get_primary_interface().name_to_tag("wght")
	_headline.base_font = Display
	_headline.variation_opentype = {weight: 680}
	_detail.base_font = Display
	_detail.variation_opentype = {weight: 540}
	theme = Theme.new()
	theme.set_stylebox("panel", "TooltipPanel", Palette.panel(Palette.SURFACE, Palette.OUTLINE, 6, 8.0))
	theme.set_font("font", "TooltipLabel", Body)
	theme.set_font_size("font_size", "TooltipLabel", 17)
	theme.set_color("font_color", "TooltipLabel", Palette.TEXT)


func show_menu(sortie: Dictionary = {}) -> void:
	_clear_modal()
	_drop_hangar()
	_drop(_hud)
	_hud = null
	_telemetry = {}
	_drop(_menu)
	_menu = _page("Menu")

	var matte := ColorRect.new()
	matte.color = Palette.NIGHT
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(matte)
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := TextureRect.new()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var hero := "res://assets/art/hero.jpg"
	if ResourceLoader.exists(hero):
		backdrop.texture = load(hero)
	elif ResourceLoader.exists("res://assets/art/arena_nebula.jpg"):
		backdrop.texture = load("res://assets/art/arena_nebula.jpg")
	_menu.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_menu_scrim(_menu)

	var content := _safe_content(_menu)
	var title := _column(0)
	content.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tag(title, "GALAXY STRIKE", Palette.TEXT, 61)
	_label(title, "S P A C E   S U R V I V O R", _detail, 24, Palette.CYAN)
	_spacer(title, 16)
	var rule := ColorRect.new()
	rule.color = Palette.CYAN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(56, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title.add_child(rule)

	var bottom := _column(12)
	content.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var briefing := PanelContainer.new()
	briefing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := Palette.panel(Color("#0d1928ed"), Color("#385062"), 12, 16.0)
	briefing.add_theme_stylebox_override("panel", surface)
	bottom.add_child(briefing)
	var details := _column(4)
	briefing.add_child(details)
	var top := _row(10)
	details.add_child(top)
	var mission := _column(1)
	mission.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(mission)
	_tag(mission, "SEKTOR MISJI", Palette.MUTED, 13)
	_tag(mission, str(sortie.get("sector_title", Mission.title)).to_upper(), Palette.TEXT, 31)
	var duration := float(sortie.get("duration", Mission.duration_seconds))
	var time := _tag(top, _clock(duration), Palette.CYAN, 24)
	time.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_body(details, "Rozwiń uzbrojenie i odeprzyj kolejne fale floty.", 20)

	var actions := _row(10)
	bottom.add_child(actions)
	var launch := _button(actions, "LaunchButton", "ROZPOCZNIJ MISJĘ", launch_requested.emit, true)
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hangar := _button(actions, "HangarButton", "HANGAR", hangar_requested.emit)
	hangar.custom_minimum_size.x = 132.0

	var controls := _body(bottom, "Przeciągnij palcem • WASD / strzałki na PC", 18)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func show_hangar(data: Dictionary, tab: String = "overview") -> void:
	_clear_modal()
	_drop(_menu)
	_menu = null
	_drop(_hud)
	_hud = null
	_telemetry = {}
	if not is_instance_valid(_hangar):
		_hangar = Hangar.new()
		_hangar.name = "Hangar"
		_hangar.action_requested.connect(hangar_action.emit)
		add_child(_hangar)
	_hangar.refresh(data, tab)


func hangar_tab() -> String:
	return _hangar.current_tab if is_instance_valid(_hangar) else "overview"


func _drop_hangar() -> void:
	_drop(_hangar)
	_hangar = null


func show_hud() -> void:
	_clear_modal()
	_drop_hangar()
	_drop(_menu)
	_menu = null
	if not is_instance_valid(_hud):
		_hud = _page("CombatHUD")
		_build_hud(_safe_content(_hud, 22.0, 20.0))
		_render_hud()


func update_hud(data: Dictionary) -> void:
	var previous := _telemetry
	_telemetry = data.duplicate()
	if is_instance_valid(_hud):
		_render_hud()
		if not previous.is_empty() and float(data.get("seconds", 0)) >= float(previous.get("seconds", 0)):
			_animate_hud_changes(previous)


func show_pause() -> void:
	var stack := _modal_stack("PauseOverlay")
	_heading(stack, "MISJA WSTRZYMANA", "Wznów lot lub rozpocznij misję od nowa.", Palette.CYAN)
	_spacer(stack, 4)
	_button(stack, "ResumeButton", "WZNÓW LOT", resume_requested.emit, true)
	_button(stack, "RestartButton", "RESTART MISJI", restart_requested.emit)
	_button(stack, "MenuButton", "MENU GŁÓWNE", menu_requested.emit)


func show_upgrades(cards: Array[Dictionary]) -> void:
	var stack := _modal_stack("UpgradeOverlay")
	_tag(stack, "POZIOM %02d" % int(_telemetry.get("level", 2)), Palette.VIOLET, 16)
	_heading(stack, "AWANS", "Wybierz jedno z trzech ulepszeń.", Palette.VIOLET)
	_spacer(stack, 4)
	for index in cards.size():
		_add_upgrade(stack, cards[index], index)


func show_result(data: Dictionary) -> void:
	var stack := _modal_stack("ResultOverlay")
	var won := bool(data.get("won", false))
	var elapsed := float(data.get("seconds", 0.0))
	var accent := Palette.CYAN if won else Palette.DANGER
	_tag(stack, str(data.get("sector_title", Mission.title)).to_upper(), accent, 16)
	var title := "MISJA UKOŃCZONA" if won else "STATEK UTRACONY"
	var subtitle := "Przetrwano atak floty. Trasa jest otwarta." if won else "Sygnał statku zanikł przed końcem misji."
	if data.get("boss_defeated", false):
		subtitle = "Okręt dowodzenia został zniszczony."
	elif not won and elapsed >= float(data.get("duration", Mission.duration_seconds)):
		title = "CZAS UPŁYNĄŁ"
		subtitle = "Okręt dowodzenia pozostał w sektorze."
	_heading(stack, title, subtitle, accent)
	_spacer(stack, 5)
	var stats := _row(8)
	stack.add_child(stats)
	_stat(stats, "CZAS LOTU", _clock(elapsed))
	_stat(stats, "ZESTRZELENIA", str(data.get("kills", 0)))
	_stat(stats, "POZIOM", str(data.get("level", 1)))
	if data.has("coins"):
		var loot := _row(8)
		loot.name = "RewardRow"
		stack.add_child(loot)
		_stat(loot, "KREDYTY", "+%d" % int(data.get("coins", 0)))
		_stat(loot, "MATERIAŁY", "+%d" % int(data.get("materials", 0)))
		_stat(loot, "SKRZYNIE", "+%d" % int(data.get("crates", 0)))
		if not data.get("ok", true):
			_body(stack, "Zapis nagrody nie powiódł się.", 19, Palette.DANGER)
	elif data.has("reward"):
		var salvage := _hud_cell(stack)
		salvage.get_parent().name = "RewardRow"
		var reward := _row(9)
		salvage.add_child(reward)
		_glyph(reward, "salvage", Palette.AMBER, Vector2(32, 32))
		var currency := _tag(reward, "RDZENIE ODZYSKU", Palette.MUTED, 15)
		currency.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		currency.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var total := _tag(reward, "+%d" % int(data["reward"]), Palette.AMBER, 27)
		total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_spacer(stack, 5)
	_button(stack, "ResultHangarButton", "WRÓĆ DO HANGARU", hangar_requested.emit, true)
	_button(stack, "RestartButton", "LEĆ PONOWNIE", restart_requested.emit)
	_button(stack, "MenuButton", "MENU GŁÓWNE", menu_requested.emit)


func _build_hud(content: Control) -> void:
	var cockpit := _column(7)
	content.add_child(cockpit)
	cockpit.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var header := _row(8)
	cockpit.add_child(header)
	var health := _hud_cell(header)
	(health.get_parent() as Control).size_flags_stretch_ratio = 1.45
	health.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var health_top := _row(4)
	health.add_child(health_top)
	var health_label := _tag(health_top, "KADŁUB", Palette.MUTED, 13)
	health_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_value = _tag(health_top, "100", Palette.TEXT, 15)
	_health_bar = _bar(health, Palette.CYAN, 7)

	var timer := _hud_cell(header)
	_tag(timer, "POZOSTAŁO", Palette.MUTED, 13)
	_timer = _tag(timer, _clock(Mission.duration_seconds), Palette.TEXT, 26)

	var kills := _hud_cell(header)
	_tag(kills, "ZESTRZEL.", Palette.MUTED, 13)
	_kills = _tag(kills, "00", Palette.TEXT, 26)

	_pause_button = _button(header, "PauseButton", "", pause_requested.emit)
	_pause_button.custom_minimum_size = Vector2(57, 62)
	_pause_button.tooltip_text = "Wstrzymaj misję"
	_pause_button.accessibility_name = "Wstrzymaj misję"
	var pause_mark := _glyph(_pause_button, "pause", Palette.TEXT, Vector2(32, 32))
	pause_mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_encounters(cockpit)

	var footer := _hud_cell(content)
	var footer_panel := footer.get_parent() as Control
	footer_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var xp_top := _row(10)
	footer.add_child(xp_top)
	_level = _tag(xp_top, "POZIOM 01", Palette.VIOLET, 16)
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_value = _tag(xp_top, "XP 0 / 0", Palette.MUTED, 16)
	_xp_bar = _bar(footer, Palette.VIOLET, 6)


func _build_encounters(cockpit: Container) -> void:
	var wave := _hud_cell(cockpit)
	_wave_panel = wave.get_parent() as PanelContainer
	_wave_panel.name = "WaveHUD"
	_wave_panel.hide()
	var wave_top := _row(9)
	wave.add_child(wave_top)
	_wave_number = _tag(wave_top, "", Palette.CYAN, 14)
	_wave_name = _tag(wave_top, "", Palette.MUTED, 15)
	_wave_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_warning = _body(wave, "", 19, Palette.AMBER)
	_warning.name = "BossWarning"
	_warning.hide()

	var boss := _hud_cell(cockpit)
	_boss_panel = boss.get_parent() as PanelContainer
	_boss_panel.name = "BossHUD"
	var shell := Palette.panel(Color("#221622f2"), Color("#794863"), 9, 9.0)
	_boss_panel.add_theme_stylebox_override("panel", shell)
	_boss_panel.hide()
	var boss_top := _row(9)
	boss.add_child(boss_top)
	_boss_name = _tag(boss_top, "", Palette.DANGER, 16)
	_boss_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_boss_integrity = _tag(boss_top, "", Palette.TEXT, 16)
	_boss_bar = _bar(boss, Palette.DANGER, 7)


func _render_hud() -> void:
	var hp := float(_telemetry.get("hp", 100))
	var max_hp := maxf(1.0, float(_telemetry.get("max_hp", 100)))
	_health_value.text = "%d / %d" % [ceili(hp), int(max_hp)]
	_health_bar.max_value = max_hp
	_health_bar.value = hp
	var fill := _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	var low_hp := hp <= max_hp * 0.25
	fill.bg_color = Palette.DANGER if low_hp else Palette.CYAN
	_health_value.add_theme_color_override("font_color", Palette.DANGER if low_hp else Palette.TEXT)

	var total := float(_telemetry.get("duration", Mission.duration_seconds))
	var remaining := maxf(0, total - float(_telemetry.get("seconds", 0)))
	_timer.text = _clock(ceilf(remaining))
	_timer.modulate = Palette.AMBER if remaining <= 20.0 else Color.WHITE
	_kills.text = "%02d" % int(_telemetry.get("kills", 0))
	var xp := int(_telemetry.get("xp", 0))
	var goal := maxi(1, int(_telemetry.get("xp_goal", 1)))
	_level.text = "POZIOM %02d" % int(_telemetry.get("level", 1))
	_xp_value.text = "XP %d / %d" % [xp, goal]
	_xp_bar.max_value = goal
	_xp_bar.value = xp
	_render_encounters()


func _render_encounters() -> void:
	var wave := int(_telemetry.get("wave", 0))
	_warning.text = str(_telemetry.get("warning", ""))
	_warning.visible = not _warning.text.is_empty()
	_wave_number.text = "FALA %02d" % wave if wave > 0 else "OSTRZEŻENIE"
	_wave_name.text = str(_telemetry.get("wave_name", ""))
	_wave_panel.visible = wave > 0 or _warning.visible
	var boss_hp := float(_telemetry.get("boss_hp", 0))
	var boss_max_hp := float(_telemetry.get("boss_max_hp", 0))
	_boss_panel.visible = boss_max_hp > 0.0 and boss_hp > 0.0
	if _boss_panel.visible:
		_boss_name.text = str(_telemetry.get("boss_name", "Drednot")).to_upper()
		_boss_bar.max_value = boss_max_hp
		_boss_bar.value = boss_hp
		_boss_integrity.text = "%d%%" % ceili(100.0 * boss_hp / boss_max_hp)


func _animate_hud_changes(previous: Dictionary) -> void:
	var hp := _health_bar.value
	if hp < float(previous.get("hp", hp)) and hp <= _health_bar.max_value * 0.25:
		_hp_pulse = _pulse(_health_bar, _hp_pulse)
	var leveled_up := int(_telemetry.get("level", 1)) != int(previous.get("level", 1))
	if _xp_bar.value > float(previous.get("xp", 0)) or leveled_up:
		_xp_pulse = _pulse(_xp_bar, _xp_pulse)
	var changed_wave := int(_telemetry.get("wave", 0)) != int(previous.get("wave", 0))
	var changed_warning := _warning.visible and _warning.text != str(previous.get("warning", ""))
	if _wave_panel.visible and (changed_wave or changed_warning):
		_wave_pulse = _pulse(_warning if changed_warning else _wave_number, _wave_pulse)


func _pulse(target: Control, active: Tween) -> Tween:
	if active and active.is_running():
		return active
	var tween := target.create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "modulate:a", 0.48, 0.10)
	tween.tween_property(target, "modulate:a", 1.0, 0.23)
	return tween


func _add_upgrade(parent: Container, card: Dictionary, index: int) -> void:
	var id := str(card.get("id", ""))
	var rarity: Dictionary = RARITIES.get(str(card.get("rarity", "common")), RARITIES["common"])
	var accent: Color = rarity["accent"]
	var category := str(card.get("tag", "SYSTEM")).to_upper()
	if card.get("is_evolution", false) and not category.begins_with("EWOLUCJA"):
		category = "EWOLUCJA"
	elif int(card.get("next_rank", 1)) > 1 and category.find("POZIOM") == -1:
		category += " • POZIOM %d" % int(card["next_rank"])
	var metadata := "%s  /  %s" % [rarity["title"], category]
	var upgrade := _button(parent, "UpgradeButton%d" % index, "", upgrade_selected.emit.bind(id))
	upgrade.custom_minimum_size.y = 110
	upgrade.accessibility_name = str(card.get("title", "Ulepszenie"))
	upgrade.accessibility_description = "%s. %s" % [metadata, card.get("description", "")]
	var normal := Palette.panel(Palette.SURFACE.lerp(accent, 0.055), Palette.OUTLINE)
	normal.border_width_left = 3
	normal.border_color = accent.darkened(0.48)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#21364b")
	hover.border_color = accent
	upgrade.add_theme_stylebox_override("normal", normal)
	upgrade.add_theme_stylebox_override("hover", hover)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#29425a")
	upgrade.add_theme_stylebox_override("pressed", pressed)

	var row := _row(14)
	upgrade.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -12
	row.offset_top = 10
	row.offset_bottom = -10
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(49, 49)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override(
		"panel", Palette.panel(accent.darkened(0.89), accent.darkened(0.62), 8))
	row.add_child(badge)
	_glyph(badge, str(card.get("icon", id)), accent, Vector2(45, 45))

	var copy := _column(1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(copy)
	var tier := _tag(copy, metadata, accent, 13)
	tier.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var name_label := _tag(copy, str(card.get("title", "Ulepszenie")), Palette.TEXT, 25)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body(copy, str(card.get("description", "")), 19)
	var arrow := _glyph(row, "arrow", accent, Vector2(24, 24))
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.minimum_size_changed.connect(func() -> void:
		upgrade.custom_minimum_size.y = maxf(110.0, row.get_combined_minimum_size().y + 20.0)
	)


func _modal_stack(page_name: String) -> VBoxContainer:
	_clear_modal()
	if is_instance_valid(_pause_button):
		_pause_button.focus_mode = Control.FOCUS_NONE
	_modal = _page(page_name)
	var scrim := ColorRect.new()
	scrim.color = Color("#03070ed4")
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := _safe_content(_modal)
	var centering := CenterContainer.new()
	centering.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(centering)
	centering.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shell := PanelContainer.new()
	shell.custom_minimum_size.x = safe.size.x
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_theme_stylebox_override("panel", Palette.panel(Color("#0b1523f6"), Palette.OUTLINE, 15, 21.0))
	centering.add_child(shell)
	safe.resized.connect(func() -> void: shell.custom_minimum_size.x = safe.size.x)
	var stack := _column(11)
	shell.add_child(stack)
	_modal.modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(_modal, "modulate:a", 1.0, 0.18)
	return stack


func _heading(parent: Container, title: String, body: String, accent: Color) -> void:
	var copy := _column(3)
	parent.add_child(copy)
	var rule := ColorRect.new()
	rule.color = accent
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size = Vector2(33, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	copy.add_child(rule)
	_spacer(copy, 4)
	_tag(copy, title, Palette.TEXT, 38)
	_body(copy, body, 21)


func _stat(parent: Container, title: String, number: String) -> void:
	var cell := _hud_cell(parent)
	_tag(cell, title, Palette.MUTED, 13)
	_tag(cell, number, Palette.TEXT, 27)


func _hud_cell(parent: Control) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel", Palette.panel(Color("#101d2aee"), Palette.OUTLINE, 9, 9.0))
	parent.add_child(panel)
	var content := _column(4)
	panel.add_child(content)
	return content


func _bar(parent: Container, accent: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.custom_minimum_size.y = height
	bar.add_theme_stylebox_override("background", Palette.panel(Palette.TRACK, Palette.TRACK, 3))
	bar.add_theme_stylebox_override("fill", Palette.panel(accent, accent, 3))
	parent.add_child(bar)
	return bar


func _button(
	parent: Container, button_name: String, label_text: String, action: Callable, primary: bool = false
) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = label_text
	button.custom_minimum_size.y = 56.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_override("font", _headline)
	button.add_theme_font_size_override("font_size", 19)

	var base := Palette.CYAN if primary else Palette.SURFACE
	var border := Palette.CYAN.lightened(0.24) if primary else Palette.OUTLINE
	var text_color := Palette.NIGHT if primary else Palette.TEXT
	var hovered := Palette.CYAN.lightened(0.20) if primary else Color("#21364b")
	var pressed := Palette.CYAN.darkened(0.13) if primary else Color("#29425a")
	button.add_theme_stylebox_override("normal", Palette.panel(base, border, 9, 9.0))
	button.add_theme_stylebox_override("hover", Palette.panel(hovered, border, 9, 9.0))
	button.add_theme_stylebox_override("pressed", Palette.panel(pressed, border, 9, 9.0))
	var focus := Palette.panel(Color.TRANSPARENT, Palette.CYAN.lightened(0.5), 9)
	focus.draw_center = false
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color_key, text_color)

	parent.add_child(button)
	button.pressed.connect(action)
	return button


func _glyph(parent: Control, id: String, color: Color, minimum: Vector2) -> Control:
	var glyph := FlightGlyph.new()
	glyph.glyph = id
	glyph.tint = color
	glyph.custom_minimum_size = minimum
	parent.add_child(glyph)
	return glyph


func _safe_content(parent: Control, margin_x: float = PAGE_MARGIN, margin_y: float = 32.0) -> Control:
	var region := Control.new()
	region.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(region)
	region.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin_left := margin_x
	var margin_right := margin_x
	var margin_top := margin_y
	var margin_bottom := margin_y
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if safe.has_area() and screen.x > 0 and screen.y > 0:
			var scale := get_viewport_rect().size / Vector2(screen)
			margin_left += safe.position.x * scale.x
			margin_top += safe.position.y * scale.y
			margin_right += maxf(0.0, screen.x - safe.end.x) * scale.x
			margin_bottom += maxf(0.0, screen.y - safe.end.y) * scale.y
	region.offset_left = margin_left
	region.offset_top = margin_top
	region.offset_right = -margin_right
	region.offset_bottom = -margin_bottom
	return region


func _page(page_name: String) -> Control:
	var page := Control.new()
	page.name = page_name
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return page


func _clear_modal() -> void:
	_drop(_modal)
	_modal = null
	if is_instance_valid(_pause_button):
		_pause_button.focus_mode = Control.FOCUS_ALL


func _drop(control: Control) -> void:
	if is_instance_valid(control):
		remove_child(control)
		control.queue_free()


func _add_menu_scrim(parent: Control) -> void:
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.28, 0.39, 0.59, 0.76, 1.0])
	shade.colors = PackedColorArray([
		Color("#050912f7"), Color("#050912a8"), Color("#05091217"),
		Color("#05091200"), Color("#050912bb"), Color("#050912ff")
	])
	var texture := GradientTexture2D.new()
	texture.width = 4
	texture.height = 512
	texture.gradient = shade
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(0.0, 1.0)
	var scrim := TextureRect.new()
	scrim.texture = texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _row(gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", gap)
	return row


func _column(gap: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", gap)
	return column


func _spacer(parent: Container, height: float) -> void:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)


func _tag(parent: Container, contents: String, color: Color, font_size: int) -> Label:
	var font := _detail if font_size <= 16 else _headline
	return _label(parent, contents, font, font_size, color)


func _body(parent: Container, contents: String, font_size: int, color: Color = Palette.MUTED) -> Label:
	var label := _label(parent, contents, Body, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(parent: Container, contents: String, font: Font, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = contents
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _clock(seconds: float) -> String:
	var whole := maxi(0, floori(seconds))
	return "%02d:%02d" % [floori(float(whole) / 60.0), whole % 60]
