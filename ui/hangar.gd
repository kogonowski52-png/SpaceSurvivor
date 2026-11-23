extends Control

signal action_requested(action: String, value: String)

const Palette := preload("res://ui/palette.gd")
const Catalog := preload("res://data/progression_catalog.gd")
const ShopCatalog := preload("res://data/store/commerce_catalog.gd")
const Pages := preload("res://ui/hangar_pages.gd")
const Glyph := preload("res://ui/hangar_glyph.gd")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")
const Display := preload("res://assets/fonts/Oxanium.ttf")
const Inspection := preload("res://ui/hull_inspection.gdshader")
const HangarArt := preload("res://assets/art/hangar.jpg")
const TABS := {
	"overview": "HANGAR", "inventory": "EKWIPUNEK", "sectors": "SEKTORY", "rewards": "NAGRODY",
}
const TRACKS := {
	"hull": {"title": "Kadłub", "stat": "max_hp", "button": "UpgradeHullButton", "tone": Palette.CYAN, "icon": "armor"},
	"drive": {"title": "Napęd", "stat": "speed_multiplier", "button": "UpgradeDriveButton", "tone": Palette.VIOLET, "icon": "engine"},
	"output": {"title": "Uzbrojenie", "stat": "weapon_damage_multiplier", "button": "UpgradeOutputButton", "tone": Palette.AMBER, "icon": "weapon"},
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
var _crystals: Label
var _back_button: Button
var _launch_button: Button
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
	_crystals.text = str(_profile.get("crystals", 0))
	_back_button.text = "‹ HANGAR" if tab == "workshop" else "‹ MENU"
	var sector: Dictionary = Catalog.SECTORS.get(str(_profile.get("sector_id", "peryhelium")), Catalog.SECTORS["peryhelium"])
	_launch_button.text = "ROZPOCZNIJ MISJĘ  ·  %s" % str(sector["title"]).to_upper()
	_status.text = str(data.get("message", ""))
	_status.visible = not _status.text.is_empty()
	_status.modulate = Palette.CYAN if not str(data.get("highlight", "")).is_empty() else Color.WHITE
	var active := "overview" if tab == "workshop" else tab
	for key in _tabs:
		_style_button(_tabs[key], false, Palette.CYAN if key == active else Color.TRANSPARENT)
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
	image.texture = HangarArt
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
	_coins = _wallet(header, "CREDITS", Palette.AMBER)
	_materials = _wallet(header, "MATERIAŁY", Palette.CYAN)
	_crystals = _wallet(header, "CRYSTALS", Palette.VIOLET)

	_title = _label(shell, "HANGAR", 40)
	_body = ScrollContainer.new()
	_body.name = "HangarScroll"
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.follow_focus = true
	shell.add_child(_body)
	var scrollbar := _body.get_v_scroll_bar()
	var track := Palette.panel(Color("#101c2bae"), Color.TRANSPARENT, 2)
	track.content_margin_left = 2.0
	track.content_margin_right = 2.0
	var handle := Palette.panel(Color("#406174"), Color.TRANSPARENT, 2)
	for style in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(style, handle)
	scrollbar.add_theme_stylebox_override("scroll", track)

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
	var actions := _row(7)
	shell.add_child(actions)
	_launch_button = _button(actions, "HangarLaunchButton", "ROZPOCZNIJ MISJĘ", action_requested.emit.bind("launch", ""), true)
	_launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(actions, "HangarStoreButton", "SKLEP", action_requested.emit.bind("store", "")).custom_minimum_size.x = 88.0


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
	var description := _label(parent, ship["description"], 20, Palette.TEXT, true)
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var picker := _row(7)
	parent.add_child(picker)
	var unlocked: Array = _profile.get("unlocked_ships", ["peregrine"])
	for id in Catalog.SHIPS:
		var option: Dictionary = Catalog.SHIPS[id]
		_ship_option(picker, id, option, id == selected, id not in unlocked)
	var workshop := _button(parent, "WorkshopButton", "ULEPSZENIA STAŁE  ›", _switch_tab.bind("workshop"))
	workshop.custom_minimum_size.y = 54
	_style_button(workshop, false, tone)

	var stats: Dictionary = _data.get("stats", Catalog.BASE_STATS)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	for stat in STAT_NAMES:
		var tile := _panel(grid, Color("#0d1b2aed"), Palette.OUTLINE, 8.0)
		tile.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(tile, STAT_NAMES[stat], 16, Palette.MUTED)
		_label(tile, _stat_value(stat, stats), 27, tone.lightened(0.10))


func _ship_option(picker: HBoxContainer, id: String, ship: Dictionary, selected: bool, locked: bool) -> void:
	var tone: Color = ship["accent"]
	var control := _button(picker, "ShipButton_%s" % id, "", action_requested.emit.bind("select_ship", id))
	control.custom_minimum_size.y = 98.0
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.accessibility_name = str(ship["title"])
	control.disabled = locked
	if selected:
		_style_button(control, false, tone)
	if locked:
		var style := Palette.plate(Color("#152338"), tone.darkened(0.68), 8)
		style.set_border_width(SIDE_BOTTOM, 2)
		control.add_theme_stylebox_override("disabled", style)
	var thumbnail := TextureRect.new()
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := _hull_art(id, ship)
	if ResourceLoader.exists(path):
		thumbnail.texture = load(path)
	thumbnail.modulate = Color("#c8d5e5") if locked else Color.WHITE
	control.add_child(thumbnail)
	thumbnail.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	thumbnail.offset_left = 7.0
	thumbnail.offset_right = -7.0
	thumbnail.offset_top = 6.0
	thumbnail.offset_bottom = 58.0
	var name_label := _label(control, str(ship["title"]), 16, tone.lightened(0.23) if selected else Palette.TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	name_label.offset_top = 57.0
	name_label.offset_bottom = 78.0
	if locked:
		var sector: Dictionary = Catalog.SECTORS.get(ship["unlock_sector"], {})
		var unlock := "%s · %d wygr." % [sector.get("title", ""), ship["unlock_wins"]]
		control.accessibility_description = "Zablokowany · " + unlock
		control.tooltip_text = control.accessibility_description
		_ship_option_status(control, "OD %d WYGR." % ship["unlock_wins"], Palette.MUTED)
	elif selected:
		_ship_option_status(control, "AKTYWNY", tone)


func _ship_option_status(control: Button, text: String, tone: Color) -> void:
	var hint := _label(control, text, 12, tone)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -21.0
	hint.offset_bottom = -4.0


func _preview(parent: VBoxContainer, id: String, ship: Dictionary) -> void:
	var frame := PanelContainer.new()
	frame.name = "ShipPreview"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tone: Color = ship["accent"]
	var extra_height := clampf(get_viewport_rect().size.y - 960.0, 0.0, 240.0)
	frame.custom_minimum_size.y = 256.0 + extra_height * 0.44
	frame.add_theme_stylebox_override("panel", Palette.plate(Color("#0a1422"), tone.darkened(0.62), 13, 3))
	parent.add_child(frame)
	var field := Control.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.clip_contents = true
	frame.add_child(field)
	var backdrop := TextureRect.new()
	backdrop.texture = HangarArt
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.modulate = tone.lerp(Color("#a7bad3"), 0.74)
	backdrop.modulate.a = 0.38
	field.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var docking := Control.new()
	docking.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(docking)
	docking.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	docking.draw.connect(_draw_docking_field.bind(docking, tone))
	var sprite := TextureRect.new()
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := _hull_art(id, ship)
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	var skin_id: String = _profile.get("commerce", {}).get("equipped_skins", {}).get(id, "")
	if ShopCatalog.SKINS.has(skin_id):
		sprite.modulate = ShopCatalog.SKINS[skin_id].tint
	var lighting := ShaderMaterial.new()
	lighting.shader = Inspection
	lighting.set_shader_parameter("accent", tone)
	sprite.material = lighting
	field.add_child(sprite)
	sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite.offset_left = 42
	sprite.offset_right = -42
	sprite.offset_top = 13
	sprite.offset_bottom = -13
	sprite.resized.connect(func() -> void: sprite.pivot_offset = sprite.size * 0.5)
	var light_sweep := sprite.create_tween().set_trans(Tween.TRANS_SINE)
	light_sweep.tween_method(func(value: float) -> void: lighting.set_shader_parameter("sweep", value), -0.16, 1.48, 1.12)
	var float_animation := sprite.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	float_animation.tween_property(sprite, "rotation", 0.033, 2.8).from(-0.033)
	float_animation.parallel().tween_property(sprite, "offset_top", 17.0, 2.8).from(9.0)
	float_animation.parallel().tween_property(sprite, "offset_bottom", -9.0, 2.8).from(-17.0)
	float_animation.tween_property(sprite, "rotation", -0.033, 2.8)
	float_animation.parallel().tween_property(sprite, "offset_top", 9.0, 2.8)
	float_animation.parallel().tween_property(sprite, "offset_bottom", -17.0, 2.8)


func _hull_art(id: String, ship: Dictionary) -> String:
	return "res://assets/art/ship_peregrine_preview.png" if id == "peregrine" else str(ship["sprite"])


func _draw_docking_field(field: Control, tone: Color) -> void:
	var center := field.size * Vector2(0.5, 0.59)
	var radius := minf(field.size.x * 0.40, field.size.y * 0.43)
	field.draw_set_transform(center, 0.0, Vector2(1, 0.46))
	field.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(tone, 0.24), 1.0, true)
	field.draw_arc(Vector2.ZERO, radius + 12.0, 0.32, 2.81, 36, Color(tone, 0.56), 1.5, true)
	field.draw_set_transform(Vector2.ZERO)
	for side: int in [-1, 1]:
		var x := center.x + side * radius * 1.18
		field.draw_line(Vector2(x, center.y - 76), Vector2(x, center.y + 41), Color(tone, 0.26), 1.0, true)
		for mark in 5:
			var y := center.y - 62.0 + mark * 19.0
			field.draw_line(Vector2(x, y), Vector2(x + side * (13 if mark == 2 else 7), y), Color(tone, 0.43), 1.2, true)


func _workshop(parent: VBoxContainer) -> void:
	var selected := str(_profile.get("ship_id", "peregrine"))
	var ship: Dictionary = Catalog.SHIPS.get(selected, Catalog.SHIPS["peregrine"])
	var title := _panel(parent, Color("#111e2cf2"), Palette.OUTLINE)
	_label(title, ship["title"], 27, ship["accent"])
	_label(title, "Zmiany dotyczą tego statku we wszystkich kolejnych misjach.", 20, Palette.MUTED, true)

	var stats: Dictionary = _data.get("stats", Catalog.BASE_STATS)
	var prices: Dictionary = _data.get("upgrade_prices", {})
	for track in TRACKS:
		var spec: Dictionary = TRACKS[track]
		var price: Dictionary = prices.get(track, {})
		var tone: Color = spec["tone"]
		var card := _panel(parent, Color("#0d1b2bf5"), tone.darkened(0.59))
		var header := _row(8)
		card.add_child(header)
		var icon := Glyph.new()
		icon.kind = spec["icon"]
		icon.tint = tone
		icon.custom_minimum_size = Vector2(35, 35)
		header.add_child(icon)
		var track_title := _label(header, spec["title"], 25)
		track_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var level := int(price.get("level", 0))
		var cap := int(price.get("max_level", 0))
		_label(header, "POZIOM %d / %d" % [level, cap], 17, tone)
		var stat: String = spec["stat"]
		var upgraded: bool = _data.get("highlight") == "upgrade" and _data.get("highlight_value") == track
		var before := stats
		var after: Dictionary = price.get("next_stats", {}) if level < cap else {}
		if upgraded:
			var prior: Dictionary = _profile.get("levels", {}).get(selected, {}).duplicate()
			prior[track] = maxi(0, level - 1)
			before = Catalog.build_stats(selected, prior, _profile.get("equipped", {}).get(selected, {}))
			after = stats
		var comparison := _row(9)
		card.add_child(comparison)
		_label(comparison, _stat_value(stat, before), 25, tone if after.is_empty() else Palette.MUTED)
		var gain: Label
		if not after.is_empty():
			_label(comparison, "→", 21, Palette.MUTED)
			var future := _label(comparison, _stat_value(stat, after), 27, tone.lightened(0.12))
			future.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var delta := float(after[stat]) - float(before[stat])
			var increase := "+%d HP" % roundi(delta) if stat == "max_hp" else "+%d pp" % roundi(delta * 100.0)
			gain = _label(comparison, ("UZYSKANO  " if upgraded else "") + increase, 18, tone.lightened(0.20))
		var rank := ProgressBar.new()
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rank.show_percentage = false
		rank.custom_minimum_size.y = 7
		rank.max_value = maxi(1, cap)
		rank.value = level
		rank.add_theme_stylebox_override("background", Palette.panel(Palette.TRACK, Palette.TRACK, 2))
		rank.add_theme_stylebox_override("fill", Palette.panel(tone, tone, 2))
		card.add_child(rank)
		var can_afford := bool(price.get("affordable", false))
		var text := "MAKSYMALNY POZIOM" if level >= cap else "ULEPSZ  ·  %d KR  +  %d MAT" % [price.get("coins", 0), price.get("materials", 0)]
		if level < cap and not can_afford:
			text = "POTRZEBA  %d KR  +  %d MAT" % [price.get("coins", 0), price.get("materials", 0)]
		var upgrade := _button(card, spec["button"], text, action_requested.emit.bind("upgrade", track))
		upgrade.custom_minimum_size.y = 54
		_style_button(upgrade, false, tone)
		upgrade.disabled = level >= cap or not can_afford
		if upgraded:
			var panel := card.get_parent() as PanelContainer
			var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			style.set_border_width(SIDE_LEFT, 3)
			var animation := panel.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			animation.tween_property(style, "border_color", tone.darkened(0.28), 0.78).from(tone.lightened(0.33))
			animation.parallel().tween_property(style, "bg_color", style.bg_color, 0.71).from(style.bg_color.lerp(tone, 0.23))
			animation.parallel().tween_property(rank, "value", float(level), 0.57).from(float(maxi(0, level - 1)))
			if gain != null:
				animation.parallel().tween_property(gain, "modulate:a", 1.0, 0.45).from(0.35).set_delay(0.12)


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
	shell.add_theme_stylebox_override("panel", Palette.plate(color, border, 10, inset))
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


func _style_button(control: Button, primary: bool, accent := Color.TRANSPARENT) -> void:
	var highlighted := accent.a > 0.0
	var ink := Palette.NIGHT if primary else (accent.lightened(0.21) if highlighted else Palette.TEXT)
	var tint := Palette.CYAN if primary else Color("#142538f5")
	var border := Palette.CYAN if primary else Palette.OUTLINE
	if highlighted and not primary:
		tint = tint.lerp(accent, 0.15)
		border = accent.darkened(0.30)
	control.add_theme_stylebox_override("normal", Palette.plate(tint, border, 8, 5.0))
	control.add_theme_stylebox_override("hover", Palette.plate(tint.lightened(0.16), border, 8, 5.0))
	control.add_theme_stylebox_override("pressed", Palette.plate(tint.darkened(0.13), border, 8, 5.0))
	control.add_theme_stylebox_override("disabled", Palette.plate(Color("#111b28ed"), Color("#293b4b"), 8, 5.0))
	var focus := Palette.plate(Color.TRANSPARENT, Palette.VIOLET, 8)
	focus.draw_center = false
	focus.set_border_width_all(2)
	control.add_theme_stylebox_override("focus", focus)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(key, ink)
	control.add_theme_color_override("font_disabled_color", Palette.MUTED)


func _label(parent: Control, text: String, point_size: int, color: Color = Palette.TEXT, wrap: bool = false) -> Label:
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
