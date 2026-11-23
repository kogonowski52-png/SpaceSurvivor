extends "res://tests/smoke.gd"
## Drive the public shop controls and adversarial/repeated adapter responses in an isolated profile.

const Pilot := preload("res://data/pilot_progression.gd")
const Billing := preload("res://commerce/billing_service.gd")
const BillingAdapter := preload("res://commerce/billing_adapter.gd")
const Offers := preload("res://data/store/commerce_catalog.gd")
const DAY := "2026-11-23"

class UnverifiedAdapter extends BillingAdapter:
	func begin_purchase(id: String, sku: String) -> void:
		answered.emit(id, "success", [{"sku": sku, "token": "gs-test-forged", "stage": "purchased"}])


var _path := "user://commerce-qa-%d" % Time.get_ticks_usec()
var _notices: Array[String] = []


func _run() -> void:
	_open_title()
	await _frames(12)
	if not await _click("StoreButton"):
		quit(1)
		return
	_check(game.phase == "store", "title opens the test shop")
	if capture_dir.is_empty():
		await _test_wallet_schema()
		await _test_billing()
		await _test_catalog_access()
		await _test_ads()
	else:
		await _store_frames()
	print("QA commerce: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _open_title() -> void:
	game = (load("res://main.tscn") as PackedScene).instantiate()
	game.progression.save_path = _path
	game.progression.legacy_path = _path + "-none.cfg"
	game.progression.date_override = DAY
	game.billing_ledger_path = _path + "-orders.cfg"
	root.add_child(game)
	game.test_ads.response_delay = 0.0
	game.test_billing.response_delay = 0.0
	game.billing.status_changed.connect(func(state: String, _message: String) -> void: _notices.append(state))


func _test_wallet_schema() -> void:
	var migrated := Pilot.new()
	migrated.save_path = _path + "-migration"
	migrated.legacy_path = _path + "-none.cfg"
	migrated.load_profile()
	var saved: Dictionary = migrated.snapshot().profile
	saved.coins = 765
	saved.erase("commerce")
	saved.erase("crystals")
	var payload := JSON.stringify({"version": 2, "revision": 1, "data": saved})
	var file := FileAccess.open(migrated.save_path + ".1.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": payload, "sha256": payload.sha256_text()}))
	file.close()
	migrated.load_profile()
	var profile: Dictionary = migrated.snapshot().profile
	_check(profile.coins == 765 and profile.crystals == 0 and profile.commerce.receipts.is_empty(),
		"v2 Credits migrate without granting premium currency")
	var calendar := Pilot.new()
	calendar.save_path = _path + "-calendar"
	calendar.legacy_path = _path + "-none.cfg"
	calendar.load_profile()
	for day in range(1, 8):
		calendar.date_override = "2026-12-%02d" % day
		var gift := calendar.apply("claim_calendar", str(day))
		_check(gift.ok and calendar.snapshot().profile.crystals == (15 if day == 7 else 0),
			"calendar day %d grants the expected free Crystals" % day)
	var failure := migrated.shop_buy("skin_ion")
	_check(not failure.ok and failure.state == "funds" and migrated.snapshot().profile.coins == 765,
		"insufficient Crystals do not debit Credits")
	migrated.save_path = _path + "/missing/wallet"
	_check(not migrated.shop_buy("equipment_patrol").ok and migrated.snapshot().profile.coins == 765,
		"failed wallet write rolls back purchase and debit")

	var forged := Billing.new()
	root.add_child(forged)
	forged.configure(game.progression, UnverifiedAdapter.new())
	var before := _wallet("crystals")
	forged.buy("crystals_900")
	_check(_wallet("crystals") == before, "unverified provider and forged test token cannot grant currency")
	forged.queue_free()


func _test_billing() -> void:
	var before := _wallet("crystals")
	for state in ["cancelled", "network_error", "unavailable", "error"]:
		game.test_billing.scenario = state
		await _click_scrolled("BuyOffer_starter")
		_check(game._store_state == state and _wallet("crystals") == before,
			"%s does not grant a product" % state)

	await _click("StoreTab_crystals")
	game.test_billing.scenario = "pending"
	await _click_scrolled("BuyOffer_crystals_100")
	_check(game.billing.pending("crystals_100") and _wallet("crystals") == before,
		"pending order persists without granting Crystals")
	await _reopen()
	_check(game.billing.pending("crystals_100") and _wallet("crystals") == before, "pending order survives scene and profile reload")
	game.billing.buy("crystals_100")
	_check(game._store_state == "pending", "repeated request for the same pending SKU is blocked")
	await _click_scrolled("RestorePurchasesButton")
	_check(game._store_state == "restored" and _wallet("crystals") == before, "restore reports pending receipt without crediting it")
	await _click_scrolled("CompletePendingButton")
	_check(game._store_state == "restored" and not game.billing.pending("crystals_100") and _wallet("crystals") == before + 100,
		"resolving a pending test order credits it once")
	await _click_scrolled("RestorePurchasesButton")
	_check(_wallet("crystals") == before + 100, "subsequent restore is idempotent")

	before = _wallet("crystals")
	game.test_billing.scenario = "repeat"
	game.billing.buy("crystals_350")
	game.billing.buy("crystals_350")
	game.test_billing.answered.emit("wrong-request", "success", [])
	await _frames(10)
	_check(_wallet("crystals") == before + 350 and _notices.back() == "success",
		"double tap, duplicate callback and unmatched callback fulfill exactly one order")
	await _reopen()
	before = _wallet("crystals")
	await _click_scrolled("RestorePurchasesButton")
	_check(_wallet("crystals") == before and game._store_state == "restored",
		"consumable receipt cannot grant again after restart")
	game.progression.save_path = _path + "/missing/wallet"
	game.billing.buy("crystals_100")
	await _frames(10)
	_check(_wallet("crystals") == before and game._store_state == "error",
		"provider approval cannot debit or credit a broken save")
	game.progression.save_path = _path
	await _click_scrolled("RestorePurchasesButton")
	_check(_wallet("crystals") == before + 100, "restore recovers an approved order after a failed wallet write")
	await _click_scrolled("RestorePurchasesButton")
	_check(_wallet("crystals") == before + 100, "recovery still fulfills a write-failure receipt only once")


func _test_catalog_access() -> void:
	await _click("StoreBackButton")
	await _click("HangarButton")
	await _click("HangarStoreButton")
	_check(game.phase == "store", "hangar opens the same shop")
	await _click("StoreBackButton")
	_check(game.phase == "hangar", "back from the hangar shop returns to the hangar")
	await _click("HangarStoreButton")
	var coins := _wallet("coins")
	var crystals := _wallet("crystals")
	await _click_scrolled("BuyOffer_starter")
	_check(_wallet("coins") == coins + 600 and _wallet("crystals") == crystals + 120,
		"simulated starter grants the fixed package")
	crystals = _wallet("crystals")
	game.billing.buy("starter")
	_check(game._store_state == "duplicate" and _wallet("crystals") == crystals,
		"persistent non-consumable entitlement blocks a second starter")

	await _click("StoreTab_skins")
	var stats: Dictionary = game.progression.sortie().stats
	await _click_scrolled("BuyOffer_skin_sol")
	_check("peregrine_sol" in _pilot().commerce.skins, "Credits purchase unlocks a cosmetic")
	await _click_scrolled("EquipSkin_peregrine_sol")
	_check(game.progression.sortie().skin_id == "peregrine_sol" and game.progression.sortie().stats == stats,
		"equipped livery reaches the sortie without changing flight stats")

	await _click("StoreTab_gear")
	crystals = _wallet("crystals")
	await _click_scrolled("BuyOffer_equipment_signal")
	var inventory: Array = _pilot().inventory
	_check("dark_reactor" in inventory and "wing_controller" in inventory and _wallet("crystals") == crystals - 80,
		"fixed equipment bundle delivers its listed modules and debits Crystals once")
	_check(game.progression.apply("equip", "wing_controller").ok and game.progression.sortie().stats.drone_rank >= 2,
		"module from the shop modifies the next sortie after equipping")
	var repeat: Dictionary = game.progression.shop_buy("equipment_signal")
	_check(not repeat.ok and _wallet("crystals") == crystals - 80, "wallet offer cannot be applied twice")

	var free_before := _wallet("crystals")
	for index in 6:
		game.progression.credit_mission(_victory(), "peryhelium")
	_check(_wallet("crystals") == free_before + 24, "ordinary victories earn free Crystals")
	game._refresh_store()
	await _click("StoreTab_season")
	await _click_scrolled("ClaimSeason_free_1")
	_check(_wallet("crystals") == free_before + 32, "free season milestone earns Crystals without a pass")
	_check(_button("ClaimSeason_pass_1") == null, "pass reward is locked before ownership")
	await _click_scrolled("BuyOffer_season_helion")
	_check("season_helion" in _pilot().commerce.entitlements, "season pass is restored as a permanent entitlement")
	await _click_scrolled("ClaimSeason_pass_6")
	_check("peregrine_helion" in _pilot().commerce.skins, "pass rewards unlock a cosmetic through the season track")
	_check(not game.progression.claim_season("pass_6").ok, "season rewards are one-time")


func _test_ads() -> void:
	await _click("StoreTab_featured")
	var coins := _wallet("coins")
	for state in ["unavailable", "cancelled", "network_error"]:
		game.test_ads.scenario = state
		await _click_scrolled("BonusCreditsButton")
		_check(game._store_state == state and _wallet("coins") == coins, "ad %s cannot grant Credits" % state)
	game.test_ads.scenario = "repeat"
	await _click_scrolled("BonusCreditsButton")
	_check(_wallet("coins") == coins + 150, "repeated ad completion grants one daily bonus")
	game._request_ad("bonus")
	_check(_wallet("coins") == coins + 150 and game._store_state == "claimed", "daily placement cannot be harvested twice")
	await _reopen()
	_check(_button("BonusCreditsButton") == null and _wallet("coins") == coins + 150, "daily claim survives profile reload")

	await _click("StoreBackButton")
	await _click("LaunchButton")
	game._request_ad("bonus")
	_check(not game.ads.busy(), "ads cannot be opened from live combat")
	var flights: int = _pilot().totals.flights
	_damage_to_zero()
	_check(game.phase == "revive" and game.arena.can_revive() and _pilot().totals.flights == flights,
		"fatal hit offers optional revive before paying a result")
	var paused := _seconds()
	await _steps(6)
	_check(is_equal_approx(_seconds(), paused), "flight stays frozen on the revive choice")
	game.test_ads.scenario = "cancelled"
	await _click("ReviveAdButton")
	_check(game.phase == "revive" and game.arena._hp == 0, "cancel does not revive or spend the choice")
	game.test_ads.scenario = "repeat"
	await _click("ReviveAdButton")
	_check(game.phase == "combat" and is_equal_approx(game.arena._hp, game.arena._max_hp * 0.5),
		"completed ad revives the same flight at half HP")
	_check(not game.progression.ad_eligible("revive", game._flight_id), "revive receipt is persisted before resuming")
	_damage_to_zero()
	_check(game.phase == "result" and _pilot().totals.flights == flights + 1 and _button("ReviveAdButton") == null,
		"second death settles the mission without another revive")

	await _click("RestartButton")
	var original: Dictionary = _pilot()
	game.arena.mission_ended.emit(_victory())
	var report: Dictionary = game._result.duplicate()
	var base: Dictionary = _pilot()
	await _click("DoubleRewardButton")
	var doubled: Dictionary = _pilot()
	for currency in ["coins", "materials", "crates", "crystals"]:
		_check(doubled[currency] == base[currency] + report[currency], "double ad includes base " + currency)
	_check(doubled.totals.flights == original.totals.flights + 1 and doubled.wins == original.wins + 1,
		"doubling rewards does not double flight progression")
	game._request_ad("double")
	_check(_wallet("crystals") == doubled.crystals and _button("DoubleRewardButton") == null,
		"replayed mission ad cannot change payout")

	var reread := Pilot.new()
	reread.save_path = _path
	reread.load_profile()
	_check(not reread.ad_eligible("double", game._flight_id), "settled mission does not become doubleable on reload")


func _store_frames() -> void:
	await _shop_frame("oferta")
	await _click_scrolled("TestOptionsButton")
	await _shop_frame("scenariusze")
	await _click_scrolled("TestOptionsButton")
	game.test_ads.scenario = "unavailable"
	await _click_scrolled("BonusCreditsButton")
	_check(game._store_state == "unavailable", "unavailable rewarded ad is visible to the tester")
	await _shop_frame("reklama-niedostepna")
	for tab in ["crystals", "skins", "gear", "season"]:
		if await _click("StoreTab_" + tab):
			await _shop_frame(tab)
	await _click("StoreTab_crystals")
	game.test_billing.scenario = "pending"
	await _click_scrolled("BuyOffer_crystals_100")
	await _shop_frame("oczekuje")
	await _click("StoreBackButton")
	await _click("LaunchButton")
	_damage_to_zero()
	await _shop_frame("ozywienie")
	await _click("DeclineReviveButton")
	await _shop_frame("podwojenie")


func _shop_frame(label: String) -> void:
	for candidate in game.find_children("*", "BaseButton", true, false):
		if candidate.is_visible_in_tree() and not _inside_scroll(candidate):
			_check(root.get_visible_rect().encloses(candidate.get_global_rect()), "%s visible control %s fits" % [label, candidate.name])
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	var is_exact := frame != null and frame.get_size() == expected_size
	if _check(is_exact, "%s has exact native raster" % label):
		var path := capture_dir.path_join("%dx%d-%s.png" % [expected_size.x, expected_size.y, label])
		_check(frame.save_png(path) == OK, "saved native frame " + path)


func _inside_scroll(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func _reopen() -> void:
	game.queue_free()
	await _frames(4)
	_open_title()
	await _frames(8)
	await _click("StoreButton")


func _damage_to_zero() -> void:
	game.arena._hit_cooldown = 0.0
	game.arena._hurt_player(10000.0)


func _pilot() -> Dictionary:
	return game.progression.snapshot().profile


func _wallet(currency: String) -> int:
	return int(_pilot()[currency])


func _victory() -> Dictionary:
	return {"won": true, "seconds": 600.0, "kills": 230, "level": 18, "reward": 120, "boss_defeated": true}


func _click_scrolled(name: String) -> bool:
	var button := _button(name)
	if button == null:
		return _check(false, name + " exists and can be used")
	var scroller := game.find_child("StoreScroll", true, false) as ScrollContainer
	if scroller:
		scroller.ensure_control_visible(button)
	await _frames(8)
	return await _click(name)
