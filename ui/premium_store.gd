extends Control
## Product, wallet, season and simulator states all use the same tab shell.

signal action_requested(action: String, value: String)
signal offer_viewed(id: String)

const Palette := preload("res://ui/palette.gd")
const SafeLayout := preload("res://ui/safe_layout.gd")
const Offers := preload("res://data/store/commerce_catalog.gd")
const Visual := preload("res://ui/store_art.gd")
const Fleet := preload("res://data/progression_catalog.gd")
const Display := preload("res://assets/fonts/Oxanium.ttf")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")
const HANGAR := preload("res://assets/art/premium/hangar.jpg")
const CRYSTAL_TONES := [Color("#a4cdff"), Palette.VIOLET, Color("#dfb7ff")]
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
var _account_open := false
var _heading := FontVariation.new()
var _coins: Label
var _crystals: Label
var _platform_notice: Label
var _status: Label
var _status_plate: Control
var _scroll: ScrollContainer
var _back: Button
var _tabs: Dictionary[String, Button] = {}
var _last_status := ""
var _visible_cards: Dictionary[String, Control] = {}
var _seen: Dictionary = {}
var _reveal_card: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_heading.base_font = Display
	_heading.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 680}
	var image := TextureRect.new()
	image.texture = HANGAR
	image.modulate = Color("#899cba")
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var matte := ColorRect.new()
	matte.color = Color("#070d19bd")
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(matte)
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	add_child(shell)
	SafeLayout.fill(shell, Vector2(22.0, 20.0))
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
	_platform_notice = _label(notice, "", 16, Palette.AMBER)
	var tabs := GridContainer.new()
	tabs.columns = 3
	tabs.add_theme_constant_override("h_separation", 7)
	tabs.add_theme_constant_override("v_separation", 6)
	shell.add_child(tabs)
	for id: String in Offers.TABS:
		var button := _button(tabs, "StoreTab_" + id, Offers.TABS[id], _switch_tab.bind(id), Palette.CYAN)
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 15)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tabs[id] = button
	var status_body := _panel(shell, Palette.CYAN, 10)
	_status_plate = status_body.get_parent() as Control
	_status = _label(status_body, "", 18, Palette.TEXT)
	_status.name = "StoreStatus"
	_scroll = ScrollContainer.new()
	_scroll.name = "StoreScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	shell.add_child(_scroll)
	var scrollbar := _scroll.get_v_scroll_bar()
	scrollbar.add_theme_stylebox_override("scroll", Palette.panel(Color("#0a1521"), Color.TRANSPARENT, 2))
	scrollbar.value_changed.connect(func(_value: float) -> void: _scan_offers.call_deferred())
	for style in ["grabber", "grabber_highlight", "grabber_pressed"]:
		scrollbar.add_theme_stylebox_override(style, Palette.panel(Palette.OUTLINE, Color.TRANSPARENT, 2))


func refresh(data: Dictionary, reset_scroll: bool = false) -> void:
	var pending_reveal := str(data.get("reveal", ""))
	_data = data.duplicate()
	_data.erase("reveal")
	var profile: Dictionary = data.profile
	_coins.text = str(profile.coins)
	_crystals.text = str(profile.crystals)
	if data.simulation:
		_platform_notice.text = "SYMULATOR · zakupy i reklamy testowe"
	elif data.play_test:
		_platform_notice.text = "ANDROID TEST · %s" % ("zakupy licencyjne" if data.purchase_allowed else "płatności wyłączone")
	else:
		_platform_notice.text = "Płatności wyłączone"
	_back.disabled = data.ad_busy
	_status.text = str(data.get("message", ""))
	_status_plate.visible = not _status.text.is_empty() and pending_reveal.is_empty()
	var failed: bool = data.get("state") in ["error", "save", "storage_error", "funds", "network_error", "unavailable"]
	_status.add_theme_color_override("font_color", Palette.DANGER if failed else Palette.TEXT)
	if _last_status != _status.text:
		_last_status = _status.text
		_status.modulate.a = 0.6
		_status.create_tween().tween_property(_status, "modulate:a", 1.0, 0.22)
	for id: String in _tabs:
		_style_button(_tabs[id], Palette.CYAN, id == current_tab)
	var offset := 0 if reset_scroll else _scroll.scroll_vertical
	_visible_cards.clear()
	for previous in _scroll.get_children():
		_scroll.remove_child(previous)
		previous.queue_free()
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	_scroll.add_child(body)
	body.resized.connect(func() -> void: _scan_offers.call_deferred())
	var subtitle := {
		"featured": "Oferty specjalne", "crystals": "Portfel Crystals",
		"skins": "Flota i poszycia", "gear": "Wyposażenie", "season": "Przepustka Helion", "free": "Darmowe nagrody",
	}
	if current_tab != "season":
		_label(body, subtitle[current_tab], 27, Palette.TEXT, true)
	if data.play_test and data.purchase_allowed and current_tab in ["featured", "crystals", "season"]:
		_label(body, "Przed zatwierdzeniem wybierz kartę testową Google Play.", 17, Palette.AMBER)
	if current_tab == "crystals":
		_wallet_details(body)
	elif current_tab == "skins":
		_fleet(body)
	var show_pending: bool = current_tab == "featured" and not data.pending.is_empty()
	if show_pending:
		_featured_tools(body)
	for id: String in Offers.OFFERS:
		var offer: Dictionary = Offers.OFFERS[id]
		if offer.tab == current_tab:
			_product(body, id, offer)
	match current_tab:
		"featured":
			if _data.bonus:
				_reward_card(body, "bonus", "Bonus dzienny", Palette.AMBER)
			if not show_pending:
				_featured_tools(body)
		"season":
			_season(body)
		"skins":
			if "peregrine_helion" in profile.commerce.skins:
				_product(body, "helion_reward", {"title": "Peregrine · Helion", "subtitle": "Nagroda przepustki",
					"description": "Karminowe poszycie Peregrine. Bez zmian parametrów lotu.",
					"art": "peregrine", "skin": "peregrine_helion", "kind": "earned"})
		"free":
			_reward_card(body, "bonus", "Bonus dzienny", Palette.AMBER)
			_reward_card(body, "materials", "Odzysk materiałów", Palette.CYAN)
			_button(body, "StoreCalendarButton", "KALENDARZ I ZADANIA W HANGARZE", _action.bind("hangar_rewards", ""), Palette.CYAN)
	# Layout settles after adding product cards. Restore the old scroll position on status updates.
	_scroll.set_deferred("scroll_vertical", offset)
	_scan_offers.call_deferred()
	if not pending_reveal.is_empty():
		_reveal_reward(pending_reveal)


func _wallet_details(parent: Container) -> void:
	_label(parent, "Crystals zdobędziesz za zwycięstwa, kalendarz i darmowy tor Helionu.", 18, Palette.MUTED)
	if _data.simulation:
		return
	var paid: Dictionary = _data.paid_wallet
	_label(parent, "Zdobyte lokalnie · %d Crystals" % _data.profile.crystals, 18, Palette.TEXT)
	if paid.known:
		_label(parent, "%s · %d Crystals" % ["Konto" if paid.online else "Ostatni odczyt konta", paid.crystals], 18, Palette.VIOLET)
		if paid.debt > 0:
			_label(parent, "Do rozliczenia po zwrotach · %d Crystals" % paid.debt, 18, Palette.AMBER)
	if not paid.online:
		_label(parent, "Wydatki z konta wymagają połączenia.", 17, Palette.MUTED)


func _fleet(parent: Container) -> void:
	var strip := _panel(parent, Palette.CYAN, 12)
	var row := _row(strip, 6)
	for id: String in Fleet.SHIPS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		row.add_child(cell)
		var livery: String = _data.profile.commerce.equipped_skins.get(id, "")
		var unlocked: bool = id in _data.profile.unlocked_ships
		var ship := Visual.new()
		ship.motif = id
		ship.extent = Vector2(72, 64)
		ship.tint = Offers.SKINS.get(livery, {}).get("tint", Color.WHITE) if unlocked else Color("#8598bd")
		cell.add_child(ship)
		var title := _label(cell, Fleet.SHIPS[id].title, 14, Palette.TEXT, true)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var detail := _label(cell, "DOSTĘPNY" if unlocked else "%d ZWYCIĘSTW" % Fleet.SHIPS[id].unlock_wins, 12, Palette.MUTED)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(strip, "StoreFleetButton", "WYBIERZ STATEK W HANGARZE", _action.bind("hangar_ships", ""), Palette.CYAN)


func _scan_offers() -> void:
	var window := _scroll.get_global_rect()
	for id: String in _visible_cards:
		if _seen.has(id):
			continue
		var rect := _visible_cards[id].get_global_rect()
		if rect.has_area() and window.intersection(rect).get_area() >= rect.get_area() * 0.55:
			_seen[id] = true
			offer_viewed.emit(id)


func _reward_card(parent: Container, id: String, title: String, accent: Color) -> void:
	var award: Dictionary = Offers.ADS[id]
	var card := _panel(parent, accent, 13)
	var row := _row(card, 12)
	var illustration := Visual.new()
	illustration.motif = "salvage" if id == "bonus" else "supply"
	illustration.extent = Vector2(141, 94)
	row.add_child(illustration)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	_label(copy, title, 21, Palette.TEXT, true)
	_label(copy, _reward_title(award), 24, accent, true)
	_label(copy, "Raz dziennie po ukończeniu dobrowolnej reklamy.", 17, Palette.MUTED)
	var available: bool = _data.get(id, false)
	var button_name := "BonusCreditsButton" if id == "bonus" else "StoreMaterialsButton"
	var label := "ODBIERZ · " + str(_data.ad_label) if available else "DZIŚ NIEDOSTĘPNE"
	_button(card, button_name, label, _action.bind(id, ""), accent, available).disabled = _data.ad_busy or not available


func _reward_title(award: Dictionary) -> String:
	if award.has("skin"):
		return Offers.SKINS[award.skin].title
	if award.has("coins"):
		return "+%d Credits" % award.coins
	if award.has("crystals"):
		return "+%d Crystals" % award.crystals
	return "+%d materiałów" % award.get("materials", 0)


func _reveal_reward(id: String) -> void:
	if is_instance_valid(_reveal_card):
		_reveal_card.queue_free()
	var panel := PanelContainer.new()
	panel.name = "RewardReveal"
	panel.add_theme_stylebox_override("panel", Palette.plate(Color("#172438"), Palette.AMBER, 14, 12.0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	var safe := SafeLayout.insets(self)
	panel.offset_left = 36 + safe.x
	panel.offset_right = -36 - safe.z
	panel.offset_top = -148 - safe.w
	panel.offset_bottom = -32 - safe.w
	_reveal_card = panel
	var row := _row(panel, 13)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := Visual.new()
	var title: String
	var description: String
	if Offers.OFFERS.has(id):
		var offer: Dictionary = Offers.OFFERS[id]
		art.motif = offer.art
		art.rank = int(offer.get("art_rank", 1))
		art.items = offer.get("items", [])
		art.tint = Offers.SKINS.get(offer.get("skin", ""), {}).get("tint", Color.WHITE)
		title = offer.title
		description = offer.description
	else:
		var award: Dictionary = Offers.SEASON.get(id, Offers.ADS.get(id, {}))
		var skin: Dictionary = Offers.SKINS.get(award.get("skin", ""), {})
		art.motif = skin.get("ship", "salvage")
		art.tint = skin.get("tint", Color.WHITE)
		title = _reward_title(award)
		description = "Nagroda Helionu" if Offers.SEASON.has(id) else "Nagroda za reklamę"
	art.extent = Vector2(100, 82)
	art.opening = true
	row.add_child(art)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	_label(copy, "ODEBRANO", 14, Palette.AMBER, true)
	_label(copy, title, 23, Palette.TEXT, true)
	_label(copy, description, 16, Palette.MUTED)
	panel.modulate.a = 0.0
	art.scale = Vector2.ONE * 0.84
	art.pivot_offset = art.extent * 0.5
	var motion := panel.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(panel, "modulate:a", 1.0, 0.22)
	motion.tween_property(art, "scale", Vector2.ONE, 0.54)
	motion.chain().tween_interval(2.25)
	motion.chain().tween_property(panel, "modulate:a", 0.0, 0.27)
	motion.chain().tween_callback(panel.queue_free)


func _product(parent: Container, id: String, offer: Dictionary) -> void:
	var art_tint := Palette.CYAN
	var crystal_rank := 0
	match str(offer.art):
		"crystals":
			crystal_rank = clampi(int(offer.get("art_rank", 1)), 1, CRYSTAL_TONES.size())
			art_tint = CRYSTAL_TONES[crystal_rank - 1]
		"gear", "supply", "season": art_tint = Palette.AMBER
		"prism", "arsenal": art_tint = Palette.VIOLET
	var skin: String = offer.get("skin", "")
	var skin_info: Dictionary = Offers.SKINS.get(skin, {})
	if not skin_info.is_empty():
		art_tint = skin_info.accent
	var card := _panel(parent, art_tint, 14)
	card.name = "Product_" + id
	if Offers.OFFERS.has(id):
		_visible_cards[id] = card
	if crystal_rank > 0:
		var plate := card.get_parent() as PanelContainer
		var face := plate.get_theme_stylebox("panel") as StyleBoxFlat
		face.bg_color = Color("#111e2cee") if crystal_rank == 1 else Color("#171829f7")
		face.set_border_width(SIDE_TOP, 2 if crystal_rank == 3 else 1)
	var row := _row(card, 12)
	var art := Visual.new()
	art.motif = offer.art
	art.accent = art_tint
	art.tint = skin_info.get("tint", Color.WHITE)
	art.rank = maxi(1, crystal_rank)
	art.items = offer.get("items", [])
	art.extent = Vector2(192, 154) if id == "starter" or crystal_rank == 3 else Vector2(167, 126)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if crystal_rank != 2:
		row.add_child(art)
	row.add_child(details)
	if crystal_rank == 2:
		row.add_child(art)
	if crystal_rank > 0:
		details.alignment = BoxContainer.ALIGNMENT_CENTER
	_label(details, str(offer.subtitle).to_upper(), 15 if crystal_rank > 0 else 13, art_tint, true)
	var listing: Dictionary = _data.catalog.get(offer.get("sku", ""), {})
	_label(details, offer.title, 31 if crystal_rank == 3 else 25, Palette.TEXT, true)
	_label(details, offer.description, 18, Palette.MUTED)

	var profile: Dictionary = _data.profile
	var owned: bool = Offers.owns_offer(profile, id) or offer.kind == "earned"
	if owned and not skin.is_empty():
		var equipped: bool = profile.commerce.equipped_skins.get(skin_info.ship) == skin
		var unlocked: bool = skin_info.ship in profile.unlocked_ships
		_button(card, "EquipSkin_" + skin, "ZDEJMIJ SKÓRKĘ" if equipped else ("ZAŁÓŻ SKÓRKĘ" if unlocked else "STATEK ZABLOKOWANY"),
			_action.bind("skin", skin), art_tint).disabled = not unlocked
	elif owned and offer.has("effect"):
		var equipped: bool = profile.commerce.effect == offer.effect
		_button(card, "EquipEffect_" + offer.effect, "WYŁĄCZ EFEKTY PRISM" if equipped else "WŁĄCZ EFEKTY PRISM",
			_action.bind("effect", offer.effect), art_tint)
	elif owned:
		_label(card, "W TWOJEJ KOLEKCJI", 15, Palette.SUCCESS, true)
	elif offer.kind == "play":
		var pending: bool = id in _data.pending
		var price: String = listing.get("price", "")
		var draft_locked: bool = offer.get("preview", false) and not _data.get("preview_catalog", false)
		var available: bool = _data.simulation or (_data.purchase_allowed and not price.is_empty() and not draft_locked)
		var purchase_label := "SYMULUJ · %s (TEST)" % offer.test_price if _data.simulation else "KUP · " + price
		if not _data.simulation and draft_locked:
			purchase_label = "KATALOG TESTOWY ZABLOKOWANY"
		elif not _data.simulation and not _data.purchase_allowed:
			purchase_label = "PŁATNOŚCI WYŁĄCZONE"
			if not price.is_empty():
				_label(details, price, 18, art_tint, true)
		elif not _data.simulation and price.is_empty():
			purchase_label = "CENA NIEDOSTĘPNA"
		_button(card, "BuyOffer_" + id, "ZAMÓWIENIE OCZEKUJE" if pending else purchase_label,
			_action.bind("billing", id), art_tint, available and not pending).disabled = pending or _data.billing_busy or not available
	else:
		if offer.has("items"):
			var collected: int = offer.items.filter(func(item: String) -> bool: return item in profile.inventory).size()
			if collected > 0:
				_label(card, "Masz już %d z %d modułów. Pakiet doda brakujące." % [collected, offer.items.size()], 16, Palette.MUTED)
		var bought_with_paid: bool = offer.currency == "crystals" and not _data.simulation and profile.crystals < offer.price \
			and _data.paid_wallet.online and _data.paid_wallet.crystals >= offer.price
		var action := "wallet_account" if bought_with_paid else "wallet"
		var cost_text := "Z KONTA · " if bought_with_paid else "KUP · "
		_button(card, "BuyOffer_" + id, cost_text + Offers.format_cost(offer),
			_action.bind(action, id), art_tint, true).disabled = bought_with_paid and _data.billing_busy
	card.modulate.a = 0.82
	card.create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(card, "modulate:a", 1.0, 0.18)


func _featured_tools(parent: Container) -> void:
	var tools := _panel(parent, Palette.OUTLINE, 12)
	var restore_label := "PRZYWRÓĆ ZAKUPY TESTOWE" if _data.simulation else "PRZYWRÓĆ ZAKUPY GOOGLE PLAY"
	_button(tools, "RestorePurchasesButton", restore_label, _action.bind("restore", ""), Palette.CYAN).disabled = _data.billing_busy
	if not _data.simulation:
		_account(tools)
		return
	if not _data.pending.is_empty():
		_button(tools, "CompletePendingButton", "ZATWIERDŹ OCZEKUJĄCE (TEST)",
			_action.bind("pending", ""), Palette.VIOLET).disabled = _data.billing_busy
	_button(tools, "TestOptionsButton", "UKRYJ SCENARIUSZE" if _options_open else "SCENARIUSZE TESTOWE",
		_toggle_options, Palette.CYAN)
	if _options_open:
		_scenario(tools, "Scenariusz zakupu", "BillingScenario", "billing_case", BILLING_CASES, _data.billing_case)
		_scenario(tools, "Scenariusz reklamy", "AdScenario", "ad_case", AD_CASES, _data.ad_case)


func _account(parent: VBoxContainer) -> void:
	if not _data.can_connect_account:
		return
	var label := "ZAKTUALIZUJ KOD KONTA" if _data.checkout_ready else "POŁĄCZ KONTO ZAKUPÓW"
	_button(parent, "PlayAccountButton", "ZAMKNIJ" if _account_open else label, _toggle_account, Palette.CYAN).disabled = _data.billing_busy
	if not _account_open:
		return
	var token := LineEdit.new()
	token.name = "PlayAccountCode"
	token.secret = true
	token.placeholder_text = "Kod połączenia konta"
	token.max_length = 256
	token.editable = not _data.billing_busy
	token.custom_minimum_size.y = 52
	token.add_theme_font_override("font", Body)
	token.add_theme_font_size_override("font_size", 19)
	token.add_theme_stylebox_override("normal", Palette.plate(Palette.STEEL, Palette.OUTLINE, 8, 11.0))
	parent.add_child(token)
	var connect_button := _button(parent, "ConfirmPlayAccount", "POŁĄCZ", _submit_account.bind(token), Palette.CYAN, true)
	connect_button.disabled = true
	token.text_changed.connect(func(value: String) -> void: connect_button.disabled = value.strip_edges().length() < 24)
	token.text_submitted.connect(func(_value: String) -> void:
		if not connect_button.disabled:
			_submit_account(token))


func _toggle_account() -> void:
	_account_open = not _account_open
	refresh(_data)
	if _account_open:
		var field := find_child("PlayAccountCode", true, false) as LineEdit
		if field != null:
			_scroll.ensure_control_visible.call_deferred(field)
			field.grab_focus.call_deferred()


func _submit_account(field: LineEdit) -> void:
	var token := field.text.strip_edges()
	field.clear()
	_account_open = false
	_action("account", token)


func _season(parent: Container) -> void:
	var profile: Dictionary = _data.profile
	var flights: int = profile.totals.flights
	var has_pass: bool = "season_helion" in profile.commerce.entitlements
	var progress := _panel(parent, Palette.AMBER, 12)
	_label(progress, "%d / 6 LOTÓW" % mini(flights, 6), 22, Palette.AMBER, true)
	var bar := ProgressBar.new()
	bar.max_value = 6.0
	bar.value = float(flights)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 9.0
	bar.add_theme_stylebox_override("background", Palette.panel(Color("#080f1b"), Palette.OUTLINE, 3))
	bar.add_theme_stylebox_override("fill", Palette.panel(Palette.AMBER, Color.TRANSPARENT, 3))
	progress.add_child(bar)
	_label(progress, "Liczą się rozegrane loty. Nagrody możesz odebrać w dowolnym momencie.", 16, Palette.MUTED)
	for tier in ["free", "pass"]:
		var accent := Palette.CYAN if tier == "free" else Palette.AMBER
		var block := _panel(parent, accent, 12)
		_label(block, "TOR DARMOWY" if tier == "free" else "TOR PRZEPUSTKI", 17, accent, true)
		for id: String in Offers.SEASON:
			if not id.begins_with(tier):
				continue
			var reward: Dictionary = Offers.SEASON[id]
			var done: bool = id in profile.commerce.season
			var cell := _panel(block, accent, 8)
			var row := _row(cell, 10)
			var icon := Visual.new()
			var skin: Dictionary = Offers.SKINS.get(reward.get("skin", ""), {})
			icon.motif = skin.get("ship", "crystals" if reward.has("crystals") else "salvage")
			icon.tint = skin.get("tint", Color.WHITE)
			icon.extent = Vector2(59, 48)
			row.add_child(icon)
			var copy := VBoxContainer.new()
			copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(copy)
			_label(copy, "PRÓG · %d" % reward.goal, 13, accent, true)
			_label(copy, _reward_title(reward), 20, Palette.TEXT, true)
			var claim_label := "ODEBRANO" if done else "ODBIERZ"
			if not done and tier == "pass" and not has_pass:
				claim_label = "ZABLOKOWANO"
			elif not done and flights < reward.goal:
				claim_label = "%d / %d" % [flights, reward.goal]
			var can_claim: bool = not done and flights >= reward.goal and (tier == "free" or has_pass)
			var button := _button(row, "ClaimSeason_" + id, claim_label, _action.bind("season", id), accent, can_claim)
			button.custom_minimum_size.x = 136.0
			button.disabled = not can_claim


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
	if current_tab == tab:
		return
	current_tab = tab
	if is_instance_valid(_reveal_card):
		_reveal_card.queue_free()
	_data.message = ""
	_data.state = ""
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
