extends Control

signal action_requested(action: String, value: String)

const Palette := preload("res://ui/palette.gd")
const Catalog := preload("res://data/progression_catalog.gd")
const Pages := preload("res://ui/hangar_pages.gd")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")
const Display := preload("res://assets/fonts/Oxanium.ttf")
const TABS := {
	"overview": "HANGAR", "inventory": "EKWIPUNEK", "sectors": "SEKTORY", "rewards": "NAGRODY",
}
const TRACKS := {
	"hull": {"title": "Kadłub", "stat": "max_hp", "button": "UpgradeHullButton", "tone": Palette.CYAN},
	"drive": {"title": "Napęd", "stat": "speed_multiplier", "button": "UpgradeDriveButton", "tone": Palette.VIOLET},
	"output": {"title": "Uzbrojenie", "stat": "weapon_damage_multiplier", "button": "UpgradeOutputButton", "tone": Palette.AMBER},
}
const STAT_NAMES := {
	"max_hp": "INTEGRALNOŚĆ", "speed_multiplier": "PRĘDKOŚĆ",
	"weapon_damage_multiplier": "OBRAŻENIA", "damage_taken_multiplier": "REDUKCJA OBRAŻEŃ",
}

var current_tab := "overview"
var _data: Dictionary
var _profile: Dictionary
var _title: Label
var _coins: Label
var _materials: Label
var _back_button: Button
var _status: Label
var _body: ScrollContainer
var _content: VBoxContainer
var _tabs: Dictionary
var _revision := 0
var _face := FontVariation.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.base_font = Display
	_face.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}
	_background()
	_build_shell()


func refresh(data: Dictionary, tab: String = "overview") -> void:
	if tab != "workshop" and not TABS.has(tab):
		tab = "overview"
	var scroll := _body.scroll_vertical if tab == current_tab else 0
	current_tab = tab
	_data = data
	_profile = data.get("profile", {})
	_title.text = "ULEPSZENIA" if tab == "workshop" else TABS[tab]
	_coins.text = str(_profile.get("coins", 0))
	_materials.text = str(_profile.get("materials", 0))
	_back_button.text = "‹ HANGAR" if tab == "workshop" else "‹ MENU"
	_status.text = str(data.get("message", ""))
	_status.visible = not _status.text.is_empty()
	_status.modulate = Palette.CYAN if not str(data.get("highlight", "")).is_empty() else Color.WHITE
	var active := "overview" if tab == "workshop" else tab
	for key in _tabs:
		_style_button(_tabs[key], key == active)
	if is_instance_valid(_content):
		_body.remove_child(_content)
		_content.queue_free()
	_content = _column(10)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_content)
	match tab:
		"overview":
			_overview(_content)
		"workshop":
			_workshop(_content)
		_:
			Pages.new().build(tab, _content, _data, action_requested.emit)
	_revision += 1
	_restore_scroll(scroll, _revision)


func _restore_scroll(offset: int, revision: int) -> void:
	await get_tree().process_frame
	if revision == _revision and is_inside_tree():
		_body.scroll_vertical = offset


func _background() -> void:
	var matte := ColorRect.new()
	matte.color = Palette.NIGHT
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(matte)
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var image := TextureRect.new()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/art/hangar.jpg"):
		image.texture = load("res://assets/art/hangar.jpg")
	add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.36, 0.6, 0.76, 1.0])
	gradient.colors = PackedColorArray([
		Color("#050912fc"), Color("#050912bf"), Color("#05091238"),
		Color("#05091238"), Color("#050912bb"), Color("#050912ff"),
	])
	var texture := GradientTexture2D.new()
	texture.width = 4
	texture.height = 512
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1)
	var scrim := TextureRect.new()
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.texture = texture
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_shell() -> void:
	var shell := _column(9)
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := DisplayServer.get_display_safe_area() if OS.has_feature("android") else Rect2i()
	var screen := DisplayServer.screen_get_size() if safe.has_area() else Vector2i.ONE
	var scale := get_viewport_rect().size / Vector2(screen)
	shell.offset_left = 22.0 + safe.position.x * scale.x
	shell.offset_right = -22.0 - (screen.x - safe.end.x) * scale.x if safe.has_area() else -22.0
	shell.offset_top = 20.0 + safe.position.y * scale.y
	shell.offset_bottom = -20.0 - (screen.y - safe.end.y) * scale.y if safe.has_area() else -20.0

	var header := _row(8)
	shell.add_child(header)
	_back_button = _button(header, "HangarBackButton", "‹ MENU", _back)
	_back_button.custom_minimum_size = Vector2(106, 46)
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(space)
	_coins = _wallet(header, "KREDYTY", Palette.AMBER)
	_materials = _wallet(header, "MATERIAŁY", Palette.CYAN)

	_title = _label(shell, "HANGAR", 40)
	_body = ScrollContainer.new()
	_body.name = "HangarScroll"
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.follow_focus = true
	shell.add_child(_body)

	_status = _label(shell, "", 18, Palette.TEXT, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.name = "HangarStatus"
	_status.hide()

	var nav := _row(5)
	shell.add_child(nav)
	for key in TABS:
		var tab_button := _button(nav, "HangarTab%s" % key.capitalize(), TABS[key], _switch_tab.bind(key))
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.add_theme_font_size_override("font_size", 14)
		_tabs[key] = tab_button
	_button(shell, "HangarLaunchButton", "ROZPOCZNIJ MISJĘ", action_requested.emit.bind("launch", ""), true)


func _wallet(parent: Container, caption: String, tint: Color) -> Label:
	var block := _panel(parent, Color("#101c2bf2"), Palette.OUTLINE, 7.0)
	block.get_parent().custom_minimum_size.x = 113
	_label(block, caption, 12, Palette.MUTED)
	return _label(block, "0", 20, tint)


func _switch_tab(tab: String) -> void:
	var fresh := _data.duplicate()
	fresh["highlight"] = ""
	fresh["message"] = ""
	refresh(fresh, tab)


func _back() -> void:
	if current_tab == "workshop":
		_switch_tab("overview")
	else:
		action_requested.emit("back", "")


func _overview(parent: VBoxContainer) -> void:
	var selected := str(_profile.get("ship_id", "peregrine"))
	var ship: Dictionary = Catalog.SHIPS.get(selected, Catalog.SHIPS["peregrine"])
	var tone: Color = ship["accent"]
	var name_label := _label(parent, ship["title"], 36, Palette.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview(parent, selected, ship)
	var description := _label(parent, ship["description"], 19, Palette.TEXT, true)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var picker := _row(7)
	parent.add_child(picker)
	var unlocked: Array = _profile.get("unlocked_ships", ["peregrine"])
	for id in Catalog.SHIPS:
		var option: Dictionary = Catalog.SHIPS[id]
		var cell := _column(4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.add_child(cell)
		var buy := _button(cell, "ShipButton_%s" % id, option["title"], action_requested.emit.bind("select_ship", id), id == selected)
		buy.add_theme_font_size_override("font_size", 16)
		buy.disabled = id not in unlocked
		if buy.disabled:
			var sector: Dictionary = Catalog.SECTORS.get(option["unlock_sector"], {})
			var unlock := "%s · %d wygr." % [sector.get("title", ""), option["unlock_wins"]]
			buy.accessibility_description = unlock
			var hint := _label(cell, unlock, 13, Palette.MUTED, true)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var stats: Dictionary = _data.get("stats", Catalog.BASE_STATS)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for stat in STAT_NAMES:
		var tile := _panel(grid, Color("#0d1b2aed"), Palette.OUTLINE, 10.0)
		tile.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(tile, STAT_NAMES[stat], 13, Palette.MUTED)
		_label(tile, _stat_value(stat, stats), 25, tone)
	_button(parent, "WorkshopButton", "ULEPSZENIA STAŁE  ›", _switch_tab.bind("workshop"))


func _preview(parent: VBoxContainer, id: String, ship: Dictionary) -> void:
	var frame := Control.new()
	frame.name = "ShipPreview"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var extra_height := clampf(get_viewport_rect().size.y - 960.0, 0.0, 240.0)
	frame.custom_minimum_size.y = 254.0 + extra_height * 0.6
	parent.add_child(frame)
	var sprite := TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://assets/art/ship_peregrine_preview.png" if id == "peregrine" else str(ship["sprite"])
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	frame.add_child(sprite)
	sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite.offset_left = 70
	sprite.offset_right = -70
	var drift := extra_height * 0.37
	sprite.resized.connect(func() -> void: sprite.pivot_offset = sprite.size * 0.5)
	var float_animation := sprite.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	float_animation.tween_property(sprite, "rotation", 0.035, 2.8).from(-0.035)
	float_animation.parallel().tween_property(sprite, "offset_top", drift + 6.0, 2.8).from(drift - 6.0)
	float_animation.parallel().tween_property(sprite, "offset_bottom", 6.0, 2.8).from(-6.0)
	float_animation.tween_property(sprite, "rotation", -0.035, 2.8)
	float_animation.parallel().tween_property(sprite, "offset_top", drift - 6.0, 2.8)
	float_animation.parallel().tween_property(sprite, "offset_bottom", -6.0, 2.8)


func _workshop(parent: VBoxContainer) -> void:
	var selected := str(_profile.get("ship_id", "peregrine"))
	var ship: Dictionary = Catalog.SHIPS.get(selected, Catalog.SHIPS["peregrine"])
	var title := _panel(parent, Color("#111e2cf2"), Palette.OUTLINE)
	_label(title, ship["title"], 30, ship["accent"])
	_label(title, "Ulepszenia są przypisane do tego statku i działają w każdej misji.", 19, Palette.MUTED, true)

	var stats: Dictionary = _data.get("stats", Catalog.BASE_STATS)
	var prices: Dictionary = _data.get("upgrade_prices", {})
	for track in TRACKS:
		var spec: Dictionary = TRACKS[track]
		var price: Dictionary = prices.get(track, {})
		var tone: Color = spec["tone"]
		var card := _panel(parent, Color("#0d1b2bf5"), tone.darkened(0.59))
		var header := _row(8)
		card.add_child(header)
		var track_title := _label(header, spec["title"], 25)
		track_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var level := int(price.get("level", 0))
		var cap := int(price.get("max_level", 0))
		_label(header, "POZIOM %d / %d" % [level, cap], 15, tone)
		var stat: String = spec["stat"]
		var current := _stat_value(stat, stats)
		if level < cap and price.has("next_stats"):
			var future := _stat_value(stat, price["next_stats"])
			_label(card, "%s  →  %s" % [current, future], 25, tone)
		else:
			_label(card, current, 25, tone)
		var rank := ProgressBar.new()
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rank.show_percentage = false
		rank.custom_minimum_size.y = 5
		rank.max_value = maxi(1, cap)
		rank.value = level
		rank.add_theme_stylebox_override("background", Palette.panel(Palette.TRACK, Palette.TRACK, 2))
		rank.add_theme_stylebox_override("fill", Palette.panel(tone, tone, 2))
		card.add_child(rank)
		var text := "MAKSYMALNY POZIOM" if level >= cap else "ULEPSZ  ·  %d KR  +  %d MAT" % [price.get("coins", 0), price.get("materials", 0)]
		var upgrade := _button(card, spec["button"], text, action_requested.emit.bind("upgrade", track), true)
		upgrade.disabled = level >= cap or not price.get("affordable", false)
		if _data.get("highlight", "") == "upgrade" and _data.get("highlight_value", "") == track:
			var panel := card.get_parent() as PanelContainer
			var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			var animation := panel.create_tween().set_trans(Tween.TRANS_CUBIC)
			animation.tween_property(style, "border_color", style.border_color, 0.82).from(tone)
			animation.parallel().tween_property(rank, "value", float(level), 0.55).from(float(maxi(0, level - 1)))


func _stat_value(stat: String, stats: Dictionary) -> String:
	var value := float(stats.get(stat, Catalog.BASE_STATS[stat]))
	match stat:
		"max_hp":
			return "%d HP" % roundi(value)
		"damage_taken_multiplier":
			return "%d%%" % roundi((1.0 - value) * 100.0)
		_:
			return "%d%%" % roundi(value * 100.0)


func _panel(parent: Container, color: Color, border: Color, inset: float = 12.0) -> VBoxContainer:
	var shell := PanelContainer.new()
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_theme_stylebox_override("panel", Palette.panel(color, border, 10, inset))
	parent.add_child(shell)
	var contents := _column(4)
	shell.add_child(contents)
	return contents


func _button(parent: Container, node_name: String, caption: String, callback: Callable, primary: bool = false) -> Button:
	var control := Button.new()
	control.name = node_name
	control.text = caption
	control.custom_minimum_size.y = 52
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_font_override("font", _face)
	control.add_theme_font_size_override("font_size", 18)
	_style_button(control, primary)
	parent.add_child(control)
	control.pressed.connect(callback)
	return control


func _style_button(control: Button, primary: bool) -> void:
	var ink := Palette.NIGHT if primary else Palette.TEXT
	var tint := Palette.CYAN if primary else Color("#142538f5")
	var border := Palette.CYAN if primary else Palette.OUTLINE
	control.add_theme_stylebox_override("normal", Palette.panel(tint, border, 8, 5.0))
	control.add_theme_stylebox_override("hover", Palette.panel(tint.lightened(0.16), border, 8, 5.0))
	control.add_theme_stylebox_override("pressed", Palette.panel(tint.darkened(0.13), border, 8, 5.0))
	control.add_theme_stylebox_override("disabled", Palette.panel(Color("#111b28ed"), Color("#293b4b"), 8, 5.0))
	var focus := Palette.panel(Color.TRANSPARENT, Palette.VIOLET, 8)
	focus.draw_center = false
	focus.set_border_width_all(2)
	control.add_theme_stylebox_override("focus", focus)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(key, ink)
	control.add_theme_color_override("font_disabled_color", Palette.MUTED)


func _label(parent: Container, text: String, point_size: int, color: Color = Palette.TEXT, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Body if wrap else _face)
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


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
