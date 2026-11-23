extends RefCounted

const Palette := preload("res://ui/palette.gd")
const Catalog := preload("res://data/progression_catalog.gd")
const Glyph := preload("res://ui/hangar_glyph.gd")
const Display := preload("res://assets/fonts/Oxanium.ttf")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")
const SPACE := preload("res://assets/art/arena_nebula.jpg")
const SLOT_NAMES := {
	"weapon": "Broń", "armor": "Pancerz", "engine": "Silnik",
	"reactor": "Reaktor", "drone": "Dron",
}
const RARITY_COLORS := {
	"common": Palette.MUTED, "rare": Palette.CYAN,
	"epic": Palette.VIOLET, "legendary": Color("#ffd17e"),
}
const SURFACE := Color("#0e1929f5")

var _display := FontVariation.new()


func _init() -> void:
	_display.base_font = Display
	_display.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 560}


func build(tab: String, content: VBoxContainer, data: Dictionary, on_action: Callable) -> void:
	var profile: Dictionary = data.get("profile", {})
	content.add_theme_constant_override("separation", 12)
	match tab:
		"inventory":
			_inventory(content, profile, on_action)
		"sectors":
			_sectors(content, profile, on_action)
		"rewards":
			_rewards(content, data, profile, on_action)


func _inventory(parent: VBoxContainer, profile: Dictionary, action: Callable) -> void:
	var ship_id := str(profile.get("ship_id", "peregrine"))
	var ship: Dictionary = Catalog.SHIPS.get(ship_id, Catalog.SHIPS["peregrine"])
	var equipped_by_ship: Dictionary = profile.get("equipped", {})
	var equipped: Dictionary = equipped_by_ship.get(ship_id, {})
	var section := _panel(parent)
	var heading := _row(section, 10)
	_copy(heading, str(ship["title"]).to_upper(), 24, Palette.TEXT, true, true)
	_copy(heading, "%d / %d GNIAZD" % [equipped.size(), Catalog.SLOTS.size()], 14, Palette.CYAN, true)
	for slot in Catalog.SLOTS:
		var line := _row(section, 10)
		var id := str(equipped.get(slot, ""))
		var spec: Dictionary = Catalog.ITEMS.get(id, {})
		var filled := not spec.is_empty()
		var accent := _rarity(str(spec.get("rarity", "common")))
		_icon(line, slot, accent if filled else Palette.OUTLINE.lightened(0.28), id, 44,
			spec.get("rarity") == "legendary")
		var text := _stack(line, 0, true)
		_copy(text, str(SLOT_NAMES[slot]).to_upper(), 13, Palette.MUTED, true)
		_copy(text, str(spec.get("title", "Moduł fabryczny")), 19, Palette.TEXT if filled else Palette.MUTED)
		if filled:
			_button(line, "Unequip_" + slot, "ZDEJMIJ", action.bind("unequip", slot), Palette.TEXT, 102)

	var owned: Array = profile.get("inventory", [])
	var header := _row(parent, 8)
	_copy(header, "Magazyn", 27, Palette.TEXT, true, true)
	_copy(header, "%d / %d MODUŁÓW" % [owned.size(), Catalog.ITEMS.size()], 14, Palette.CYAN, true)
	if owned.is_empty():
		_copy(_panel(parent), "Zdobywaj skrzynie w misjach i odbieraj je w zakładce Nagrody.", 19, Palette.MUTED)
	for value in owned:
		var id := str(value)
		if not Catalog.ITEMS.has(id):
			continue
		var spec: Dictionary = Catalog.ITEMS[id]
		var equipped_here := str(equipped.get(spec["slot"], "")) == id
		_item_card(parent, id, spec, equipped_here, action)


func _item_card(parent: Container, id: String, spec: Dictionary, equipped: bool, action: Callable) -> void:
	var rarity := str(spec["rarity"])
	var accent := _rarity(rarity)
	var panel := _panel(parent, accent, equipped or rarity == "legendary")
	var line := _row(panel, 11)
	_icon(line, spec["slot"], accent, id, 57, rarity == "legendary")
	var text := _stack(line, 2, true)
	_copy(text, "%s  /  %s" % [rarity.to_upper(), str(SLOT_NAMES.get(spec["slot"], "")).to_upper()], 13, accent, true)
	_copy(text, spec["title"], 22, Palette.TEXT, true)
	_copy(text, spec["description"], 18, Palette.MUTED)
	if equipped:
		_copy(text, "NA POKŁADZIE", 13, Palette.CYAN, true)
	else:
		var controls := _row(panel, 6)
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(spacer)
		_button(controls, "Equip_" + id, "WYPOSAŻ", action.bind("equip", id), accent, 120)


func _sectors(parent: VBoxContainer, profile: Dictionary, action: Callable) -> void:
	var selected := str(profile.get("sector_id", "peryhelium"))
	var unlocked: Array = profile.get("unlocked_sectors", ["peryhelium"])
	var wins := int(profile.get("wins", 0))
	for id in Catalog.SECTORS:
		var spec: Dictionary = Catalog.SECTORS[id]
		var accessible: bool = id in unlocked
		var active: bool = id == selected
		var accent: Color = spec.get("star_tint", Palette.CYAN)
		var body := _panel(parent, accent, active)
		var row := _row(body, 11)
		var image := TextureRect.new()
		image.texture = SPACE
		image.modulate = spec.get("sky_tint", Color.WHITE)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.custom_minimum_size = Vector2(115, 103)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
		var text := _stack(row, 3, true)
		_copy(text, str(spec["title"]).to_upper(), 27, Palette.TEXT, true)
		_copy(text, str(spec["description"]), 18, Palette.MUTED)
		var duration := floori(float(spec["duration"]) / 60.0)
		_copy(text, "%d MIN   /   NAGRODY ×%.2f" % [duration, float(spec.get("reward_multiplier", 1.0))], 13, accent, true)
		if active:
			_copy(body, "WYBRANY SEKTOR", 15, Palette.CYAN, true)
		elif accessible:
			_button(body, "SelectSector_" + id, "WYBIERZ SEKTOR", action.bind("select_sector", id), accent)
		else:
			var need := int(spec.get("unlock_wins", 0))
			_copy(body, "ZABLOKOWANY   /   %d / %d ZWYCIĘSTW" % [mini(wins, need), need], 15, Palette.MUTED, true)


func _rewards(parent: VBoxContainer, data: Dictionary, profile: Dictionary, action: Callable) -> void:
	var count := int(profile.get("crates", 0))
	var box := _panel(parent, Palette.AMBER, count > 0)
	var line := _row(box, 12)
	_icon(line, "crate", Palette.AMBER, "", 68)
	var copy := _stack(line, 2, true)
	_copy(copy, "Skrzynie odzysku", 24, Palette.TEXT, true)
	_copy(copy, "DO OTWARCIA   /   %02d" % count, 14, Palette.AMBER, true)
	_copy(copy, "Skrzynie zdobywasz podczas misji.", 17, Palette.MUTED)
	if count > 0:
		_button(box, "OpenCrate", "OTWÓRZ SKRZYNIĘ", action.bind("open_crate", ""), Palette.AMBER)
	var loot_id := str(data.get("loot", ""))
	if Catalog.ITEMS.has(loot_id):
		var loot: Dictionary = Catalog.ITEMS[loot_id]
		var tier := str(loot["rarity"])
		var color := _rarity(tier)
		var reveal := _panel(parent, color, true)
		_copy(reveal, "ZDOBYTY MODUŁ  /  %s" % tier.to_upper(), 14, color, true)
		_copy(reveal, str(loot["title"]), 23, Palette.TEXT, true)
		var animation := reveal.create_tween()
		reveal.modulate.a = 0.35
		animation.tween_property(reveal, "modulate:a", 1.0, 0.32)

	_calendar(parent, data.get("calendar", []), action)
	_copy(parent, "Codzienne zadania", 26, Palette.TEXT, true)
	for task in data.get("daily", []):
		_milestone(parent, task, "claim_daily", "ClaimDaily_", action)
	_copy(parent, "Osiągnięcia", 26, Palette.TEXT, true)
	for task in data.get("achievements", []):
		_milestone(parent, task, "claim_achievement", "ClaimAchievement_", action)


func _calendar(parent: VBoxContainer, days: Array, action: Callable) -> void:
	if days.is_empty():
		return
	var section := _panel(parent)
	_copy(section, "Kalendarz lotów", 24, Palette.TEXT, true)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	section.add_child(grid)
	for day in days:
		var id := str(day.get("id", ""))
		var available := bool(day.get("available", false))
		var claimed := bool(day.get("claimed", false))
		var tile := _panel(grid, Palette.CYAN if available else Palette.MUTED, available, 7)
		tile.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_copy(tile, "DZIEŃ %s" % id, 13, Palette.CYAN if available else Palette.MUTED, true)
		var prize := "%d monet\n%d mat." % [int(day.get("coins", 0)), int(day.get("materials", 0))]
		if int(day.get("crates", 0)) > 0:
			prize += "\n+%d skrz." % int(day["crates"])
		_copy(tile, prize, 15, Palette.TEXT)
		if available and not claimed:
			_button(tile, "ClaimCalendar_" + id, "ODBIERZ", action.bind("claim_calendar", id), Palette.CYAN, 0, 14)
		elif claimed:
			_copy(tile, "ODEBRANO", 12, Palette.CYAN, true)


func _milestone(parent: Container, task: Dictionary, command: String, button_prefix: String, action: Callable) -> void:
	var claimed := bool(task.get("claimed", false))
	var ready := bool(task.get("available", false))
	var id := str(task.get("id", ""))
	var progress := int(task.get("progress", 0))
	var goal := maxi(1, int(task.get("goal", 1)))
	var panel := _panel(parent, Palette.CYAN, ready and not claimed)
	var title := _row(panel, 10)
	_copy(title, str(task.get("title", "")), 20, Palette.TEXT, true, true)
	_copy(title, "%d / %d" % [mini(progress, goal), goal], 16, Palette.MUTED, true)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = goal
	bar.value = progress
	bar.custom_minimum_size.y = 4
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", Palette.panel(Palette.TRACK, Palette.TRACK, 2))
	bar.add_theme_stylebox_override("fill", Palette.panel(Palette.CYAN, Palette.CYAN, 2))
	panel.add_child(bar)
	var footer := _row(panel, 7)
	_copy(footer, "+%d MONET   ·   +%d MAT." % [int(task.get("coins", 0)), int(task.get("materials", 0))],
		13, Palette.AMBER, true, true)
	if ready and not claimed:
		_button(footer, button_prefix + id, "ODBIERZ", action.bind(command, id), Palette.CYAN, 108)
	elif claimed:
		_copy(footer, "ODEBRANO", 13, Palette.CYAN, true)


func _rarity(id: String) -> Color:
	return RARITY_COLORS.get(id, Palette.MUTED)


func _panel(parent: Container, accent: Color = Palette.OUTLINE, emphasis := false, inset := 13) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := accent.darkened(0.51) if emphasis else Palette.OUTLINE
	var fill := SURFACE.lerp(accent, 0.08) if emphasis else SURFACE
	var style := Palette.panel(fill, border, 11, inset)
	if emphasis:
		style.set_border_width(SIDE_LEFT, 3)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return _stack(panel, 7)


func _stack(parent: Container, gap: int, expand := false) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", gap)
	if expand:
		stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(stack)
	return stack


func _row(parent: Container, gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", gap)
	parent.add_child(row)
	return row


func _copy(parent: Container, text: String, size: int, color: Color, heading := false, expand := false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _display if heading else Body)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if expand:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif parent is HBoxContainer:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(label)
	return label


func _icon(parent: Container, slot: String, accent: Color, item: String, extent: int, legendary := false) -> void:
	var icon := Glyph.new()
	icon.kind = slot
	icon.tint = accent
	icon.variation = Catalog.RARITIES.find(str(Catalog.ITEMS.get(item, {}).get("rarity", "common")))
	icon.legendary = legendary
	icon.custom_minimum_size = Vector2(extent, extent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(icon)


func _button(parent: Container, name: String, label: String, task: Callable, accent: Color, width := 0, size := 16) -> Button:
	var button := Button.new()
	button.name = name
	button.text = label
	button.custom_minimum_size = Vector2(width, 42)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _display)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", accent)
	button.add_theme_color_override("font_hover_color", Palette.TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.NIGHT)
	button.add_theme_stylebox_override("normal", Palette.panel(SURFACE.lerp(accent, 0.10), accent.darkened(0.46), 7, 5))
	button.add_theme_stylebox_override("hover", Palette.panel(SURFACE.lerp(accent, 0.22), accent, 7, 5))
	button.add_theme_stylebox_override("pressed", Palette.panel(accent, accent, 7, 5))
	var focus := Palette.panel(Color.TRANSPARENT, accent, 7)
	focus.draw_center = false
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(task)
	parent.add_child(button)
	return button
