extends RefCounted

const Palette := preload("res://ui/palette.gd")
const Catalog := preload("res://data/progression_catalog.gd")
const Glyph := preload("res://ui/hangar_glyph.gd")
const Display := preload("res://assets/fonts/Oxanium.ttf")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")
const SPACE := preload("res://assets/art/arena_nebula.jpg")
const Inspection := preload("res://ui/hull_inspection.gdshader")
const SLOT_NAMES := {
	"weapon": "Broń", "armor": "Pancerz", "engine": "Silnik",
	"reactor": "Reaktor", "drone": "Dron",
}
const RARITY_COLORS := {
	"common": Palette.MUTED, "rare": Palette.CYAN,
	"epic": Palette.VIOLET, "legendary": Color("#ffd17e"),
}
const SECTOR_VIEW := {
	"peryhelium": Vector2(0.08, 0.58), "umbra": Vector2(0.46, 0.27), "zenith": Vector2(0.88, 0.72),
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
			var highlighted := str(data.get("highlight_value", "")) if data.get("highlight") == "equip" else ""
			_inventory(content, profile, on_action, highlighted)
		"sectors":
			_sectors(content, profile, on_action)
		"rewards":
			_rewards(content, data, profile, on_action)


func _inventory(parent: VBoxContainer, profile: Dictionary, action: Callable, highlighted: String) -> void:
	var ship_id := str(profile.get("ship_id", "peregrine"))
	var ship: Dictionary = Catalog.SHIPS.get(ship_id, Catalog.SHIPS["peregrine"])
	var equipped_by_ship: Dictionary = profile.get("equipped", {})
	var equipped: Dictionary = equipped_by_ship.get(ship_id, {})
	var heading := _row(parent, 10)
	_copy(heading, "Na pokładzie · " + str(ship["title"]), 25, Palette.TEXT, true, true)
	_copy(heading, "%d / %d GNIAZD" % [equipped.size(), Catalog.SLOTS.size()], 16, Palette.CYAN, true)
	var section := _stack(parent, 6)
	for slot in Catalog.SLOTS:
		var id := str(equipped.get(slot, ""))
		var spec: Dictionary = Catalog.ITEMS.get(id, {})
		var filled := not spec.is_empty()
		var accent := _rarity(str(spec.get("rarity", "common")))
		var slot_body := _panel(section, accent, filled, 8)
		var line := _row(slot_body, 10)
		var symbol := _icon(line, slot, accent if filled else Palette.OUTLINE.lightened(0.38), id, 43,
			spec.get("rarity") == "legendary")
		var text := _stack(line, 0, true)
		_copy(text, str(SLOT_NAMES[slot]).to_upper(), 15, accent if filled else Palette.MUTED, true)
		_copy(text, str(spec.get("title", "Moduł fabryczny")), 21, Palette.TEXT if filled else Palette.MUTED)
		if filled:
			_button(line, "Unequip_" + slot, "ZDEJMIJ", action.bind("unequip", slot), Palette.MUTED, 104, 16)
		if filled and id == highlighted:
			symbol.pivot_offset = symbol.custom_minimum_size * 0.5
			_reveal_motion(slot_body, symbol, accent, false)

	var owned: Array = profile.get("inventory", [])
	var header := _row(parent, 8)
	_copy(header, "Magazyn", 27, Palette.TEXT, true, true)
	_copy(header, "%d / %d MODUŁÓW" % [owned.size(), Catalog.ITEMS.size()], 16, Palette.CYAN, true)
	if owned.is_empty():
		_copy(_panel(parent), "Zdobywaj skrzynie w misjach i odbieraj je w zakładce Nagrody.", 19, Palette.MUTED)
	var ordered: Array[String] = []
	for value in owned:
		var id := str(value)
		if Catalog.ITEMS.has(id):
			ordered.append(id)
	ordered.sort_custom(_inventory_order)
	for id in ordered:
		var spec: Dictionary = Catalog.ITEMS[id]
		var equipped_here := str(equipped.get(spec["slot"], "")) == id
		_item_card(parent, id, spec, equipped_here, action)


func _inventory_order(left: String, right: String) -> bool:
	var a: Dictionary = Catalog.ITEMS[left]
	var b: Dictionary = Catalog.ITEMS[right]
	var tier_a := Catalog.RARITIES.find(a["rarity"])
	var tier_b := Catalog.RARITIES.find(b["rarity"])
	if tier_a != tier_b:
		return tier_a > tier_b
	var slot_a := Catalog.SLOTS.find(a["slot"])
	var slot_b := Catalog.SLOTS.find(b["slot"])
	return slot_a < slot_b if slot_a != slot_b else left < right


func _item_card(parent: Container, id: String, spec: Dictionary, equipped: bool, action: Callable) -> void:
	var rarity := str(spec["rarity"])
	var accent := _rarity(rarity)
	var rare := rarity != "common"
	var panel := _panel(parent, accent, rare)
	var line := _row(panel, 11)
	_icon(line, spec["slot"], accent, id, 60, rarity == "legendary")
	var text := _stack(line, 4, true)
	var labels := _row(text, 6)
	_copy(labels, str(SLOT_NAMES[spec["slot"]]).to_upper(), 15, Palette.MUTED, true)
	_chip(labels, rarity.to_upper(), accent)
	_copy(text, spec["title"], 24, Palette.TEXT, true)
	_copy(text, spec["description"], 20, Palette.MUTED)
	if equipped:
		var status := _row(text, 5)
		_chip(status, "NA POKŁADZIE", Palette.CYAN)
	else:
		var controls := _row(panel, 6)
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(spacer)
		_button(controls, "Equip_" + id, "WYPOSAŻ", action.bind("equip", id), accent, 136, 17)


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
		var sector_crop := AtlasTexture.new()
		sector_crop.atlas = SPACE
		var image_size := SPACE.get_size()
		var crop_size := Vector2(image_size.x * 0.53, image_size.y * 0.47)
		sector_crop.region = Rect2((image_size - crop_size) * SECTOR_VIEW.get(id, Vector2(0.5, 0.5)), crop_size)
		image.texture = sector_crop
		image.modulate = spec.get("sky_tint", Color.WHITE)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.custom_minimum_size = Vector2(116, 111)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(image)
		var text := _stack(row, 3, true)
		_copy(text, str(spec["title"]), 27, Palette.TEXT, true)
		_copy(text, str(spec["description"]), 18, Palette.MUTED)
		var duration := floori(float(spec["duration"]) / 60.0)
		var metadata := _row(text, 5)
		_chip(metadata, "%d MIN" % duration, Palette.MUTED)
		_chip(metadata, "NAGRODY ×%.2f" % float(spec.get("reward_multiplier", 1.0)), accent)
		if active:
			_chip(_row(body, 5), "AKTYWNY KURS", accent)
		elif accessible:
			_button(body, "SelectSector_" + id, "WYBIERZ SEKTOR", action.bind("select_sector", id), accent)
		else:
			var need := int(spec.get("unlock_wins", 0))
			var locked := _row(body, 6)
			_chip(locked, "ZABLOKOWANY", Palette.MUTED)
			_copy(locked, "%d / %d ZWYCIĘSTW" % [mini(wins, need), need], 14, Palette.MUTED, true)


func _rewards(parent: VBoxContainer, data: Dictionary, profile: Dictionary, action: Callable) -> void:
	var count := int(profile.get("crates", 0))
	var box := _panel(parent, Palette.AMBER, count > 0)
	var line := _row(box, 12)
	_icon(line, "crate", Palette.AMBER, "", 72)
	var copy := _stack(line, 2, true)
	_copy(copy, "Skrzynie odzysku", 24, Palette.TEXT, true)
	_chip(_row(copy, 5), "DO OTWARCIA  %02d" % count, Palette.AMBER if count else Palette.MUTED)
	if count == 0:
		_copy(copy, "Skrzynie zdobywasz w misjach i kalendarzu lotów.", 17, Palette.MUTED)
	if count > 0:
		_button(box, "OpenCrate", "OTWÓRZ SKRZYNIĘ", action.bind("open_crate", ""), Palette.AMBER, 0, 16, true)
	var loot_id := str(data.get("loot", ""))
	if Catalog.ITEMS.has(loot_id):
		_recovered_module(parent, loot_id, data.get("highlight") == "open_crate")

	_calendar(parent, data.get("calendar", []), action)
	_copy(parent, "Codzienne zadania", 26, Palette.TEXT, true)
	for task in data.get("daily", []):
		_milestone(parent, task, "claim_daily", "ClaimDaily_", action)
	_copy(parent, "Osiągnięcia", 26, Palette.TEXT, true)
	for task in data.get("achievements", []):
		_milestone(parent, task, "claim_achievement", "ClaimAchievement_", action)


func _recovered_module(parent: VBoxContainer, loot_id: String, animate: bool) -> void:
	var loot: Dictionary = Catalog.ITEMS[loot_id]
	var tier := str(loot["rarity"])
	var color := _rarity(tier)
	var slot := str(loot["slot"])
	var legendary := tier == "legendary"
	var premium := legendary or tier == "epic"
	var panel := _panel(parent, color, true, 15 if premium else 13)
	panel.get_parent().name = "CrateResult"
	if premium:
		var plate := panel.get_parent() as PanelContainer
		var style := plate.get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color = Color("#211c1af7") if legendary else Color("#18162cf7")
		style.set_border_width(SIDE_TOP, 2)
	var detail := _row(panel, 13)
	var badge: Control
	if premium:
		var art := TextureRect.new()
		art.texture = load("res://assets/art/modules/%s.webp" % slot)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.custom_minimum_size = Vector2(160, 141) if legendary else Vector2(130, 115)
		art.pivot_offset = art.custom_minimum_size * 0.5
		var gloss := ShaderMaterial.new()
		gloss.shader = Inspection
		gloss.set_shader_parameter("accent", color)
		art.material = gloss
		detail.add_child(art)
		if animate:
			art.create_tween().tween_method(func(value: float) -> void: gloss.set_shader_parameter("sweep", value), -0.16, 1.48, 1.0)
		badge = art
	else:
		badge = _icon(detail, slot, color, loot_id, 66)
		badge.pivot_offset = Vector2(33, 33)
	var details := _stack(detail, 5, true)
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	_copy(details, tier.to_upper() + "  ·  " + str(SLOT_NAMES[slot]).to_upper(), 16, color, true)
	_copy(details, str(loot["title"]), 28 if premium else 24, Palette.TEXT, true)
	_copy(details, str(loot["description"]), 20 if premium else 18, Palette.MUTED)
	if animate:
		_reveal_motion(panel, badge, color, premium)


func _reveal_motion(body: VBoxContainer, artwork: Control, color: Color, premium: bool) -> void:
	var plate := body.get_parent() as PanelContainer
	var style := plate.get_theme_stylebox("panel") as StyleBoxFlat
	var duration := 0.64 if premium else 0.41
	var animation := plate.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	animation.tween_property(style, "border_color", style.border_color, duration).from(color.lightened(0.26))
	animation.parallel().tween_property(style, "bg_color", style.bg_color, duration).from(style.bg_color.lerp(color, 0.23))
	animation.parallel().tween_property(artwork, "scale", Vector2.ONE, duration).from(Vector2.ONE * 0.83)
	animation.parallel().tween_property(artwork, "modulate:a", 1.0, duration * 0.67).from(0.3)


func _calendar(parent: VBoxContainer, days: Array, action: Callable) -> void:
	if days.is_empty():
		return
	var section := _panel(parent)
	var heading := _row(section, 8)
	_copy(heading, "Kalendarz lotów", 27, Palette.TEXT, true, true)
	var completed := 0
	for day: Dictionary in days:
		completed += int(day.get("claimed", false))
	_copy(heading, "ODEBRANO  %d / %d" % [completed, days.size()], 15, Palette.MUTED, true)
	var active: Dictionary = days[mini(completed, days.size() - 1)]
	var active_id := str(active.get("id", ""))
	var available := bool(active.get("available", false))
	var claimed := bool(active.get("claimed", false))
	var color := Palette.CYAN if available else Palette.VIOLET
	var featured := _panel(section, color, true, 11)
	var topline := _row(featured, 9)
	_copy(topline, "Dzień %s" % active_id, 27, Palette.TEXT, true, true)
	_copy(topline, "DO ODBIORU" if available else ("ODEBRANO" if claimed else "NASTĘPNA NAGRODA"), 15, color, true)
	_copy(featured, "   ·   ".join(_calendar_prizes(active)), 20, Palette.TEXT)
	if available and not claimed:
		_button(featured, "ClaimCalendar_" + active_id, "ODBIERZ NAGRODĘ", action.bind("claim_calendar", active_id), color, 0, 17, true)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	section.add_child(grid)
	for day: Dictionary in days:
		var id := str(day.get("id", ""))
		if id == active_id:
			continue
		var day_claimed := bool(day.get("claimed", false))
		var final := int(day.get("crystals", 0)) > 0
		var accent := Palette.VIOLET if final else (Palette.SUCCESS if day_claimed else Palette.MUTED)
		var tile := _panel(grid, accent, final or day_claimed, 8)
		tile.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_copy(tile, "DZIEŃ %s" % id, 16, accent, true)
		_copy(tile, "\n".join(_calendar_prizes(day)), 17, Palette.TEXT)
		if day_claimed:
			_chip(_row(tile, 0), "ODEBRANO", accent)


func _calendar_prizes(day: Dictionary) -> PackedStringArray:
	var prizes := PackedStringArray(["%d Credits" % int(day.get("coins", 0)), "%d mat." % int(day.get("materials", 0))])
	if int(day.get("crates", 0)) > 0:
		prizes.append("+%d skrz." % int(day["crates"]))
	if int(day.get("crystals", 0)) > 0:
		prizes.append("+%d Crystals" % int(day["crystals"]))
	return prizes


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
		_button(footer, button_prefix + id, "ODBIERZ", action.bind(command, id), Palette.CYAN, 108, 16, true)
	elif claimed:
		_chip(footer, "ODEBRANO", Palette.CYAN)


func _rarity(id: String) -> Color:
	return RARITY_COLORS.get(id, Palette.MUTED)


func _chip(parent: Container, title: String, accent: Color) -> void:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := Palette.panel(SURFACE.lerp(accent, 0.13), accent.darkened(0.57), 4, 5)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	badge.add_theme_stylebox_override("panel", style)
	parent.add_child(badge)
	var text := _copy(badge, title, 13, accent.lightened(0.13), true)
	text.autowrap_mode = TextServer.AUTOWRAP_OFF


func _panel(parent: Container, accent: Color = Palette.OUTLINE, emphasis := false, inset := 13) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := accent.darkened(0.51) if emphasis else Palette.OUTLINE
	var fill := SURFACE.lerp(accent, 0.08) if emphasis else SURFACE
	var style := Palette.plate(fill, border, 10, inset)
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


func _icon(parent: Container, slot: String, accent: Color, item: String, extent: int, legendary := false) -> Control:
	var icon := Glyph.new()
	icon.kind = slot
	icon.tint = accent
	icon.variation = Catalog.RARITIES.find(str(Catalog.ITEMS.get(item, {}).get("rarity", "common")))
	icon.legendary = legendary
	icon.custom_minimum_size = Vector2(extent, extent)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(icon)
	return icon


func _button(parent: Container, name: String, label: String, task: Callable, accent: Color, width := 0, size := 16, primary := false) -> Button:
	var button := Button.new()
	button.name = name
	button.text = label
	button.custom_minimum_size = Vector2(width, 48)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _display)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", Palette.NIGHT if primary else accent)
	button.add_theme_color_override("font_hover_color", Palette.NIGHT if primary else Palette.TEXT)
	button.add_theme_color_override("font_pressed_color", Palette.NIGHT)
	button.add_theme_stylebox_override("normal", Palette.plate(accent if primary else SURFACE.lerp(accent, 0.10), accent.darkened(0.46), 7, 5))
	button.add_theme_stylebox_override("hover", Palette.plate(accent.lightened(0.13) if primary else SURFACE.lerp(accent, 0.22), accent, 7, 5))
	button.add_theme_stylebox_override("pressed", Palette.plate(accent, accent, 7, 5))
	var focus := Palette.plate(Color.TRANSPARENT, accent, 7)
	focus.draw_center = false
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(task)
	parent.add_child(button)
	return button
