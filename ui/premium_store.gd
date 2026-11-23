extends Control
## Product, wallet, season and simulator states all use the same tab shell.

signal action_requested(action: String, value: String)

const Palette := preload("res://ui/palette.gd")
const Offers := preload("res://data/store/commerce_catalog.gd")
const Visual := preload("res://ui/store_art.gd")
const Display := preload("res://assets/fonts/Oxanium.ttf")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")
const HANGAR := preload("res://assets/art/hangar.jpg")
const BILLING_CASES := {
	"success": "Sukces", "cancelled": "Anulowanie", "error": "Błąd zakupu",
	"network_error": "Błąd sieci", "unavailable": "Usługa niedostępna",
	"pending": "Oczekujący", "repeat": "Podwójne powiadomienie",
}
const AD_CASES := {
	"rewarded": "Nagroda przyznana", "cancelled": "Zamknięcie reklamy", "network_error": "Błąd sieci",
	"unavailable": "Brak reklamy", "repeat": "Podwójne powiadomienie",
}

var current_tab := "featured"
var _data: Dictionary
var _options_open := false
var _heading := FontVariation.new()
var _coins: Label
var _crystals: Label
var _status: Label
var _status_plate: Control
var _scroll: ScrollContainer
var _back: Button
var _tabs: Dictionary[String, Button] = {}
var _last_status := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_heading.base_font = Display
	_heading.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 680}
	var image := TextureRect.new()
	image.texture = HANGAR
	image.modulate = Color("#a9b4dd")
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var matte := ColorRect.new()
	matte.color = Color("#050912a3")
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(matte)
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := DisplayServer.get_display_safe_area() if OS.has_feature("android") else Rect2i()
	var screen := DisplayServer.screen_get_size() if safe.has_area() else Vector2i.ONE
	var scale := get_viewport_rect().size / Vector2(screen)
	shell.offset_left = 22.0 + safe.position.x * scale.x
	shell.offset_right = -22.0 - (screen.x - safe.end.x) * scale.x if safe.has_area() else -22.0
	shell.offset_top = 20.0 + safe.position.y * scale.y
	shell.offset_bottom = -20.0 - (screen.y - safe.end.y) * scale.y if safe.has_area() else -20.0
	var header := _row(shell, 9)
	_back = _button(header, "StoreBackButton", "‹ POWRÓT", _action.bind("back", ""), Palette.CYAN)
	_back.custom_minimum_size.x = 104
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(gap)
	_coins = _balance(header, "CREDITS", Palette.AMBER)
	_crystals = _balance(header, "CRYSTALS", Palette.VIOLET)
	_label(shell, "SKLEP", 40, Palette.TEXT, true)
	var notice := _panel(shell, Palette.AMBER, 9)
	_label(notice, "TRYB TESTOWY · bez płatności i prawdziwych reklam", 16, Palette.AMBER)
	var tabs := _row(shell, 5)
	for id: String in Offers.TABS:
		var button := _button(tabs, "StoreTab_" + id, Offers.TABS[id], _switch_tab.bind(id), Palette.CYAN)
		button.custom_minimum_size.y = 49
		button.add_theme_font_size_override("font_size", 13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs[id] = button
	_scroll = ScrollContainer.new()
	_scroll.name = "StoreScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	shell.add_child(_scroll)
	var scrollbar := _scroll.get_v_scroll_bar()
	scrollbar.add_theme_stylebox_override("scroll", Palette.panel(Color("#0a1521"), Color.TRANSPARENT, 2))
	for style in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(style, Palette.panel(Palette.OUTLINE, Color.TRANSPARENT, 2))
	var status_body := _panel(shell, Palette.CYAN, 10)
	_status_plate = status_body.get_parent() as Control
	_status = _label(status_body, "", 18, Palette.TEXT)
	_status.name = "StoreStatus"


func refresh(data: Dictionary, reset_scroll: bool = false) -> void:
	_data = data
	var profile: Dictionary = data.profile
	_coins.text = str(profile.coins)
	_crystals.text = str(profile.crystals)
	_back.disabled = data.ad_busy
	_status.text = str(data.get("message", ""))
	_status_plate.visible = not _status.text.is_empty()
	var failed: bool = data.get("state") in ["error", "save", "storage_error", "funds", "network_error", "unavailable"]
	_status.add_theme_color_override("font_color", Palette.DANGER if failed else Palette.TEXT)
	if _last_status != _status.text:
		_last_status = _status.text
		_status.modulate.a = 0.6
		_status.create_tween().tween_property(_status, "modulate:a", 1.0, 0.22)
	for id: String in _tabs:
		_style_button(_tabs[id], Palette.CYAN, id == current_tab)
	var offset := 0 if reset_scroll else _scroll.scroll_vertical
	for previous in _scroll.get_children():
		_scroll.remove_child(previous)
		previous.queue_free()
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	_scroll.add_child(body)
	var subtitle := {
		"featured": "Zaopatrzenie orbitalne", "crystals": "Portfel Crystals",
		"skins": "Poszycia floty", "gear": "Pakiety modułów", "season": "Archiwum Helionu",
	}
	_label(body, subtitle[current_tab], 27, Palette.TEXT, true)
	if current_tab == "crystals":
		_label(body, "Crystals zdobędziesz też za zwycięstwa, kalendarz i darmowy tor Helionu.", 18, Palette.MUTED)
	for id: String in Offers.OFFERS:
		var offer: Dictionary = Offers.OFFERS[id]
		if offer.tab == current_tab:
			_product(body, id, offer)
	match current_tab:
		"featured":
			_featured_tools(body)
		"season":
			_season(body)
		"skins":
			if "peregrine_helion" in profile.commerce.skins:
				_product(body, "helion_reward", {"title": "Peregrine · Helion", "subtitle": "Nagroda przepustki",
					"description": "Karminowe poszycie Peregrine. Bez zmian parametrów lotu.",
					"art": "peregrine", "skin": "peregrine_helion", "kind": "earned"})
	# Layout settles after adding product cards. Restore the old scroll position on status updates.
	_scroll.set_deferred("scroll_vertical", offset)


func _product(parent: Container, id: String, offer: Dictionary) -> void:
	var art_tint := Palette.CYAN
	match str(offer.art):
		"crystals": art_tint = Palette.VIOLET
		"gear", "season": art_tint = Palette.AMBER
	var skin: String = offer.get("skin", "")
	var skin_info: Dictionary = Offers.SKINS.get(skin, {})
	if not skin_info.is_empty():
		art_tint = skin_info.accent
	var card := _panel(parent, art_tint, 14)
	card.name = "Product_" + id
	var row := _row(card, 12)
	var art := Visual.new()
	art.motif = offer.art
	art.accent = art_tint
	art.tint = skin_info.get("tint", Color.WHITE)
	art.rank = int(offer.get("art_rank", 1))
	art.items = offer.get("items", [])
	row.add_child(art)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	_label(details, str(offer.subtitle).to_upper(), 13, art_tint, true)
	_label(details, offer.title, 25, Palette.TEXT, true)
	_label(details, offer.description, 18, Palette.MUTED)

	var profile: Dictionary = _data.profile
	var owned: bool = Offers.owns_offer(profile, id) or offer.kind == "earned"
	if owned and not skin.is_empty():
		var equipped: bool = profile.commerce.equipped_skins.get(skin_info.ship) == skin
		var unlocked: bool = skin_info.ship in profile.unlocked_ships
		_button(card, "EquipSkin_" + skin, "ZDEJMIJ SKÓRKĘ" if equipped else ("ZAŁÓŻ SKÓRKĘ" if unlocked else "STATEK ZABLOKOWANY"),
			_action.bind("skin", skin), art_tint).disabled = not unlocked
	elif owned:
		_label(card, "W TWOJEJ KOLEKCJI", 15, Palette.SUCCESS, true)
	elif offer.kind == "play":
		var pending: bool = id in _data.pending
		_button(card, "BuyOffer_" + id, "ZAMÓWIENIE OCZEKUJE" if pending else "SYMULUJ ZAKUP",
			_action.bind("billing", id), art_tint, not pending).disabled = pending or _data.billing_busy
	else:
		if offer.has("items"):
			var collected: int = offer.items.filter(func(item: String) -> bool: return item in profile.inventory).size()
			if collected > 0:
				_label(card, "Masz już %d z %d modułów. Pakiet doda brakujące." % [collected, offer.items.size()], 16, Palette.MUTED)
		_button(card, "BuyOffer_" + id, "KUP · " + Offers.format_cost(offer),
			_action.bind("wallet", id), art_tint, true)
	card.modulate.a = 0.82
	card.create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(card, "modulate:a", 1.0, 0.18)


func _featured_tools(parent: Container) -> void:
	var bonus := _panel(parent, Palette.AMBER, 12)
	_label(bonus, "Bonus dzienny · +150 Credits", 23, Palette.TEXT, true)
	_label(bonus, "Jedna dobrowolna reklama testowa dziennie.", 18, Palette.MUTED)
	_button(bonus, "BonusCreditsButton", "ODBIERZ · REKLAMA TESTOWA" if _data.bonus else "ODEBRANO DZISIAJ",
		_action.bind("bonus", ""), Palette.AMBER).disabled = _data.ad_busy or not _data.bonus
	var tools := _panel(parent, Palette.OUTLINE, 12)
	_button(tools, "RestorePurchasesButton", "PRZYWRÓĆ ZAKUPY TESTOWE", _action.bind("restore", ""), Palette.CYAN).disabled = _data.billing_busy
	if not _data.pending.is_empty():
		_button(tools, "CompletePendingButton", "ZATWIERDŹ OCZEKUJĄCE (TEST)",
			_action.bind("pending", ""), Palette.VIOLET).disabled = _data.billing_busy
	_button(tools, "TestOptionsButton", "UKRYJ SCENARIUSZE" if _options_open else "SCENARIUSZE TESTOWE",
		_toggle_options, Palette.CYAN)
	if _options_open:
		_scenario(tools, "Scenariusz zakupu", "BillingScenario", "billing_case", BILLING_CASES, _data.billing_case)
		_scenario(tools, "Scenariusz reklamy", "AdScenario", "ad_case", AD_CASES, _data.ad_case)


func _season(parent: Container) -> void:
	var profile: Dictionary = _data.profile
	var flights: int = profile.totals.flights
	var has_pass: bool = "season_helion" in profile.commerce.entitlements
	_label(parent, "Ukończone loty · %d" % flights, 20, Palette.MUTED)
	for tier in ["free", "pass"]:
		var accent := Palette.CYAN if tier == "free" else Palette.AMBER
		var block := _panel(parent, accent, 12)
		_label(block, "TOR DARMOWY" if tier == "free" else "TOR PRZEPUSTKI", 17, accent, true)
		for id: String in Offers.SEASON:
			if not id.begins_with(tier):
				continue
			var reward: Dictionary = Offers.SEASON[id]
			var done: bool = id in profile.commerce.season
			var title := str(Offers.SKINS[reward.skin].title) if reward.has("skin") else (
				"+%d Credits" % reward.coins if reward.has("coins") else "+%d Crystals" % reward.crystals)
			var row := _row(block, 8)
			var text := _label(row, "%d lotów · %s" % [reward.goal, title], 17, Palette.TEXT)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var claim_label := "ODEBRANO" if done else "ODBIERZ"
			if tier == "pass" and not has_pass:
				claim_label = "WYMAGA PRZEPUSTKI"
			elif not done and flights < reward.goal:
				claim_label = "%d / %d" % [flights, reward.goal]
			_button(row, "ClaimSeason_" + id, claim_label,
				_action.bind("season", id), accent).disabled = done or flights < reward.goal or (tier == "pass" and not has_pass)


func _scenario(parent: Container, title: String, node_name: String, action: String, values: Dictionary, selected: String) -> void:
	_label(parent, title, 17, Palette.MUTED)
	var options := OptionButton.new()
	options.name = node_name
	options.custom_minimum_size.y = 47
	options.add_theme_font_override("font", Body)
	options.add_theme_font_size_override("font_size", 19)
	options.add_theme_stylebox_override("normal", Palette.plate(Palette.STEEL, Palette.OUTLINE, 8, 11.0))
	options.get_popup().add_theme_stylebox_override("panel", Palette.plate(Palette.STEEL, Palette.OUTLINE, 8, 9.0))
	for id: String in values:
		options.add_item(values[id])
		options.set_item_metadata(options.item_count - 1, id)
		if id == selected:
			options.select(options.item_count - 1)
	parent.add_child(options)
	options.item_selected.connect(func(index: int) -> void: _action(action, options.get_item_metadata(index)))


func _switch_tab(tab: String) -> void:
	current_tab = tab
	refresh(_data, true)


func _toggle_options() -> void:
	_options_open = not _options_open
	refresh(_data)


func _action(action: String, value: String) -> void:
	action_requested.emit(action, value)


func _balance(parent: Container, title: String, color: Color) -> Label:
	var box := _panel(parent, color, 7)
	box.custom_minimum_size.x = 112
	_label(box, title, 13, Palette.MUTED, true)
	return _label(box, "0", 22, color, true)


func _panel(parent: Container, accent: Color, inset: float) -> VBoxContainer:
	var plate := PanelContainer.new()
	var style := Palette.plate(Color("#101c2aee"), Palette.OUTLINE.lerp(accent, 0.38), 12, inset)
	style.border_width_top = 2
	plate.add_theme_stylebox_override("panel", style)
	parent.add_child(plate)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	plate.add_child(content)
	return content


func _row(parent: Container, separation: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row


func _label(parent: Container, value: String, point_size: int, color: Color, title := false) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", _heading if title else Body)
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Container, id: String, title: String, action: Callable, accent: Color, primary := false) -> Button:
	var button := Button.new()
	button.name = id
	button.text = title
	button.custom_minimum_size.y = 54
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _heading)
	button.add_theme_font_size_override("font_size", 16)
	parent.add_child(button)
	_style_button(button, accent, primary)
	button.pressed.connect(action)
	return button


func _style_button(button: Button, accent: Color, primary: bool) -> void:
	var base := accent if primary else Color("#17283b")
	var ink := Palette.NIGHT if primary else Palette.TEXT
	for state in ["normal", "hover", "pressed"]:
		var fill := base if state == "normal" else (base.lightened(0.13) if state == "hover" else base.darkened(0.16))
		button.add_theme_stylebox_override(state, Palette.plate(fill, Palette.OUTLINE.lerp(accent, 0.47), 8, 7.0))
	button.add_theme_stylebox_override("disabled", Palette.plate(Palette.GRAPHITE, Palette.OUTLINE, 8, 6.0))
	var focus := Palette.plate(Color.TRANSPARENT, accent, 8)
	focus.draw_center = false
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color, ink)
	button.add_theme_color_override("font_disabled_color", Palette.MUTED)
