extends "res://tests/smoke.gd"
## The production campaign shell with isolated profiles, receipts and simulated providers.

const Pilot := preload("res://data/pilot_progression.gd")
const Offers := preload("res://data/store/commerce_catalog.gd")
const Campaign := preload("res://vertical/campaign.gd")
const Metrics := preload("res://commerce/metrics.gd")
const DAY := "2026-11-24"

var _save := "user://store-1-1-qa-%d" % Time.get_ticks_usec()


func _run() -> void:
	_open_game()
	await _frames(8)
	if capture_dir.is_empty():
		_test_migration()
		_test_telemetry_privacy()
		await _test_rewards()
		await _test_draft_offer()
		await _test_display_prices()
	else:
		await _capture_shop()
	print("QA monetization 1.1: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _open_game() -> void:
	game = (load("res://vertical/main.tscn") as PackedScene).instantiate()
	game.progression.save_path = _save
	game.progression.legacy_path = ""
	game.progression.date_override = DAY
	game.billing_ledger_path = _save + "-orders.cfg"
	root.add_child(game)
	game.test_billing.response_delay = 0.0
	game.test_ads.response_delay = 0.0


func _test_migration() -> void:
	var pilot := Pilot.new()
	pilot.save_path = _save + "-v5"
	pilot.legacy_path = ""
	pilot.date_override = DAY
	pilot.load_profile()
	var prior: Dictionary = pilot.snapshot().profile
	for id: String in Campaign.ROUTE:
		prior.campaign[id] = {"cleared": true, "best": 23145, "stars": 3}
	prior.coins = 975
	prior.crystals = 137
	prior.commerce.skins = ["peregrine_ion"]
	prior.commerce.entitlements = ["starter", "season_helion"]
	prior.commerce.season = ["free_1", "pass_1"]
	prior.commerce.bonus_day = DAY
	prior.commerce.erase("materials_day")
	prior.commerce.erase("effect")
	var key := "play:" + "historical-starter".sha256_text()
	prior.commerce.receipts = {"flight:prior": "flight", key: "starter"}
	prior.commerce.flight = {"id": "prior", "doubled": true, "coins": 350, "materials": 24, "crates": 1, "crystals": 4}
	var payload := JSON.stringify({"version": 5, "revision": 17, "data": prior})
	var slot := FileAccess.open(pilot.save_path + ".1.json", FileAccess.WRITE)
	slot.store_string(JSON.stringify({"payload": payload, "sha256": payload.sha256_text()}))
	slot.close()
	pilot.load_profile()
	var profile: Dictionary = pilot.snapshot().profile
	_check(profile.campaign.size() == 10 and profile.campaign.abyss.stars == 3 and profile.campaign.prism.best == 23145,
		"schema 5 migration preserves all ten campaign records")
	_check(profile.coins == 975 and profile.crystals == 137 and profile.commerce.entitlements == prior.commerce.entitlements
		and profile.commerce.skins == prior.commerce.skins and profile.commerce.season == prior.commerce.season
		and profile.commerce.receipts == prior.commerce.receipts, "schema 5 migration preserves wallet, receipts, skins and Helion claims")
	_check(not pilot.ad_eligible("bonus", DAY) and pilot.ad_eligible("materials", DAY)
		and not pilot.ad_eligible("double", "prior") and not pilot.ad_eligible("boss", "prior"), "old bonus and flight receipts stay settled")
	_check(pilot.claim_rewarded_ad("materials", DAY).ok, "migrated profile can record a new reward")
	pilot.load_profile()
	_check(not pilot.ad_eligible("materials", DAY) and pilot.snapshot().profile.commerce.entitlements == prior.commerce.entitlements,
		"new slot retains the old rights and the new daily claim after reload")


func _test_telemetry_privacy() -> void:
	var metrics := Metrics.new()
	for i in Metrics.CAPACITY + 2:
		metrics.record("rewarded_request", {"placement": "boss", "source": "simulator",
			"token": "QA_TOKEN", "scope": "QA_FLIGHT"})
	metrics.record("invalid_event", {"source": "QA_USER"})
	var rows := metrics.snapshot()
	_check(rows.size() == Metrics.CAPACITY and rows.back().keys().size() == 4
		and rows.back().source == "simulator" and not "QA_TOKEN" in str(rows), "local metrics bound the buffer and drop identifiers")
	rows.back().placement = "changed"
	_check(metrics.snapshot().back().placement == "boss", "exported snapshot cannot alter telemetry state")


func _test_rewards() -> void:
	await _click("LaunchButton")
	game._launch_stage("echo")
	game.flight.mission_ended.emit(_report("echo", false))
	_check(not game._result.double_available and not game._result.boss_bonus_available,
		"a loss cannot offer double payout or boss bonus")
	await _click("CampaignButton")
	for id in ["echo", "prism"]:
		game.progression.credit_mission(_report(id), Campaign.STAGES[id].sector)
	game._launch_stage("helion")
	game.flight.mission_ended.emit(_report("helion"))
	await _frames(4)
	var base: Dictionary = game._result.duplicate()
	var materials: int = _pilot().materials
	for failure in ["unavailable", "network_error", "cancelled"]:
		game.test_ads.scenario = failure
		await _click("BossRewardButton")
		_check(_pilot().materials == materials and game.phase == "result" and game._result.boss_bonus_available,
			"boss placement does not pay after %s" % failure)
	game.test_ads.scenario = "repeat"
	await _click("BossRewardButton")
	var boss_materials: int = Offers.ADS.boss.materials
	_check(_pilot().materials == materials + boss_materials and _button("BossRewardButton") == null,
		"boss placement credits 35 materials once for repeated SDK callbacks")
	await _click("DoubleRewardButton")
	_check(_pilot().materials == materials + boss_materials + base.materials and game._result.materials == base.materials * 2 + boss_materials
		and game._result.coins == base.coins * 2, "double pays the original result only and shows the actual total")
	var flight_id: String = game._flight_id
	await _click("ResultHangarButton")
	await _click("HangarTabRewards")
	var before: int = _pilot().materials
	await _press_scrolled("HangarMaterialsButton", "HangarScroll")
	_check(_pilot().materials == before + Offers.ADS.materials.materials, "hangar awards 45 materials after the player taps the button")
	await _click("HangarStoreButton")
	await _click("StoreTab_free")
	_check(_button("StoreMaterialsButton") == null and game.phase == "store", "store and hangar share the daily materials limit")
	var events: Array[Dictionary] = game.metrics.snapshot()
	_check(events.filter(func(event: Dictionary) -> bool: return event.event == "reward_granted").size() == 3
		and events.any(func(event: Dictionary) -> bool: return event.event == "level_complete" and event.level == "helion")
		and events.any(func(event: Dictionary) -> bool: return event.event == "level_fail" and event.level == "echo")
		and events.any(func(event: Dictionary) -> bool: return event.event == "offer_view" and event.offer == "starter"),
		"instrumented flow records losses, clear, visible offer and committed reward counts")
	var counts := {"rewarded_request": 0, "available": 0, "rewarded_complete": 0, "reward_granted": 0,
		"level_start": 0, "level_complete": 0, "level_fail": 0}
	for row: Dictionary in events:
		if counts.has(row.event):
			counts[row.event] += 1
		elif row.event == "rewarded_availability" and row.state == "available":
			counts.available += 1
	_check(counts.rewarded_request == 6 and counts.available == 4 and counts.rewarded_complete == 3,
		"availability, completion and payout remain separate metrics")
	print("SIMULATED TELEMETRY " + JSON.stringify(counts))
	game.queue_free()
	await _frames(5)
	_open_game()
	await _frames(5)
	_check(not game.progression.ad_eligible("boss", flight_id) and not game.progression.ad_eligible("double", flight_id)
		and not game.progression.ad_eligible("materials", DAY), "reopening retains both flight claims and the daily cap")
	game.progression.date_override = "2026-11-25"
	_check(game.progression.ad_eligible("materials", game.progression.ad_day()), "materials unlock on the next day")


func _test_draft_offer() -> void:
	await _click("StoreButton")
	await _click("StoreTab_skins")
	var stats: Dictionary = game.progression.sortie().stats
	game.test_billing.scenario = "repeat"
	await _press_scrolled("BuyOffer_pilot_fx_prism", "StoreScroll")
	_check(is_instance_valid(game.ui._store._reveal_card), "a successful purchase opens the reward presentation")
	await _press_scrolled("EquipEffect_pilot_fx_prism", "StoreScroll")
	_check(game.progression.sortie().effect_id == "pilot_fx_prism" and game.progression.sortie().stats == stats,
		"desktop Prism purchase equips effects with no stat change")
	var pilot := Pilot.new()
	pilot.save_path = _save
	pilot.legacy_path = ""
	pilot.load_profile()
	_check(pilot.sortie().effect_id == "pilot_fx_prism", "equipped cosmetic persists")
	await _click("StoreTab_gear")
	_check(not is_instance_valid(game.ui._store._reveal_card), "switching tabs dismisses a reward without replaying it")
	await _click("StoreBackButton")
	await _click("LaunchButton")
	game._launch_stage("echo")
	await _frames(4)
	_check(game.flight._effect == Offers.EFFECTS.pilot_fx_prism, "Prism reaches the actual flight visuals")


func _test_display_prices() -> void:
	game._return_to_menu()
	await _click("StoreButton")
	var store: Control = game.ui._store
	var synthetic: Dictionary = store._data.duplicate()
	synthetic.simulation = false
	synthetic.play_test = true
	synthetic.purchase_allowed = true
	synthetic.catalog = {"gs_crystals_100": {"price": "¥123"}, "gs_arsenal_v1": {"price": "¥456"}}
	store.refresh(synthetic)
	await _frames(5)
	_check(_button("BuyOffer_arsenal_pilot") == null, "draft IAP stays disabled even when a native listing is supplied")
	await _click("StoreTab_crystals")
	var known := _button("BuyOffer_crystals_100")
	_check(known != null and known.text.ends_with("¥123") and _button("BuyOffer_crystals_350") == null,
		"native prices use supplied ProductDetails and missing products cannot be purchased")


func _capture_shop() -> void:
	for index in 6:
		var id := Campaign.ROUTE[index]
		game.progression.credit_mission(_report(id), Campaign.STAGES[id].sector, "visual-%d" % index)
	await _click("StoreButton")
	await _screen("oferty")
	await _press_scrolled("BuyOffer_arsenal_pilot", "StoreScroll")
	await _screen("pakiet-uzbrojenia")
	for tick in 120:
		if not is_instance_valid(game.ui._store._reveal_card):
			break
		await process_frame
	for tab in ["crystals", "skins", "gear", "season", "free"]:
		await _click("StoreTab_" + tab)
		await _screen(tab)
	await _press_scrolled("BonusCreditsButton", "StoreScroll")
	await _screen("bonus-odebrany")
	await _click("StoreTab_season")
	await _press_scrolled("BuyOffer_season_helion", "StoreScroll")
	await _press_scrolled("ClaimSeason_free_1", "StoreScroll")
	await _reveal_button("ClaimSeason_pass_6", "StoreScroll")
	await _screen("helion-tory")
	await _press_scrolled("ClaimSeason_pass_6", "StoreScroll")
	await _screen("helion-odbior")
	await _click("StoreTab_free")
	await _press_scrolled("StoreCalendarButton", "StoreScroll")
	await _screen("hangar-nagrody")
	await _click("HangarBackButton")
	await _click("LaunchButton")
	game._launch_stage("helion")
	game.flight.mission_ended.emit(_report("helion"))
	await _screen("nagroda-bossa")


func _press_scrolled(name: String, scroller: String) -> bool:
	await _reveal_button(name, scroller)
	return await _click(name)


func _reveal_button(name: String, scroller: String) -> void:
	await _frames(4)
	var target := _button(name)
	var scroll := game.find_child(scroller, true, false) as ScrollContainer
	if target != null and scroll != null:
		scroll.ensure_control_visible(target)
	await _frames(5)


func _screen(name: String) -> void:
	await _frames(9)
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if not _check(frame != null and frame.get_size() == expected_size, "exact raster for " + name):
		return
	for button in game.find_children("*", "BaseButton", true, false):
		if button.is_visible_in_tree() and not _inside_scroller(button):
			_check(root.get_visible_rect().encloses(button.get_global_rect()), "%s fits in %s" % [button.name, name])
	var path := capture_dir.path_join("%dx%d-%s.png" % [expected_size.x, expected_size.y, name])
	_check(frame.save_png(path) == OK, "captured " + name)


func _inside_scroller(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false


func _pilot() -> Dictionary:
	return game.progression.snapshot().profile


func _report(id: String, won := true) -> Dictionary:
	return {"stage": id, "won": won, "boss_defeated": won and Campaign.BOSS_NAMES.has(id),
		"seconds": 140, "kills": 220, "hull_ratio": 0.77, "score": 24000, "level": 7,
		"waves": Campaign.STAGES[id].waves.size(), "reward": Campaign.STAGES[id].reward}
