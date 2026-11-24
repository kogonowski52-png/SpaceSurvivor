extends RefCounted
## Durable, local progress. Each transaction writes the other slot before it becomes visible.

const Catalog := preload("res://data/progression_catalog.gd")
const Offers := preload("res://data/store/commerce_catalog.gd")
const Wallet := preload("res://data/store/wallet.gd")
const Campaign := preload("res://vertical/campaign.gd")
const VERSION := 6
const MAX_LEVEL := 5
const TRACKS := ["hull", "drive", "output"]
const STARTER_ITEMS := ["pulse_coil", "titanium_plate", "trim_nozzle", "flux_cell", "escort_bay"]
const DAILY := [
	["fly", "Lot patrolowy", "flights", 1, 160, 25],
	["kills", "Odprawa floty", "kills", 200, 240, 45],
	["win", "Sygnał zwycięstwa", "wins", 1, 320, 80],
]
const ACHIEVEMENTS := [
	["first_sortie", "Pierwszy lot", "flights", 1, 200, 35],
	["fleet_ace", "As Helionu", "kills", 750, 360, 95],
	["pathfinder", "Szlak do Zenithu", "wins", 4, 650, 160],
	["quartermaster", "Pełny magazyn", "inventory", 12, 500, 110],
]
const CALENDAR := [[150, 20, 0], [200, 25, 0], [150, 45, 1], [300, 40, 0],
	[240, 65, 0], [380, 60, 1], [500, 100, 2]]
const DUPLICATE_SALVAGE := [24, 50, 90, 160]

var save_path := "user://flight_progress"
var legacy_path := "user://flight_profile.cfg"
var date_override := ""
var _data: Dictionary = {}
var _revision := 0
var _read_only := false
var _rng := RandomNumberGenerator.new()
var _message := ""
var _highlight := ""
var _highlight_value := ""
var _loot := ""
var _account_offers: Array[String] = []
var _account_skins: Array[String] = []
var _account_items: Array[String] = []


func load_profile() -> void:
	_rng.randomize()
	_revision = 0
	_read_only = false
	_message = ""
	_highlight = ""
	_highlight_value = ""
	_loot = ""
	_data = _fresh()
	var records: Array[Dictionary] = []
	var slots_present := 0
	for slot in 2:
		var path := _slot_path(slot)
		if FileAccess.file_exists(path):
			slots_present += 1
			var record := _read_slot(path)
			if not record.is_empty():
				records.append(record)
	records.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.revision) > int(b.revision))
	if not records.is_empty():
		_read_only = int(records[0].version) > VERSION
		for record in records:
			if int(record.version) <= VERSION:
				_data = _normalize(record.data, int(record.version))
				_revision = int(record.revision)
				break
		if _read_only:
			_message = "Zapis wymaga nowszej wersji gry. Zmiany profilu są zablokowane."
		elif records.size() < slots_present:
			_message = "Odzyskano ostatnią poprawną kopię profilu."
	elif slots_present > 0:
		_read_only = true
		_message = "Brak poprawnej kopii profilu. Zapis jest zablokowany, a oryginalne pliki zostały zachowane."
	elif not legacy_path.is_empty() and FileAccess.file_exists(legacy_path):
		var legacy := ConfigFile.new()
		if legacy.load(legacy_path) == OK:
			var imported := _data.duplicate(true)
			imported.materials += _count(legacy.get_value("pilot", "salvage", 0))
			if _commit(imported):
				_message = "Przeniesiono rdzenie odzysku z poprzedniego zapisu."
			else:
				_message = "Odczytano poprzedni zapis, ale migracja nie została zapisana."


func snapshot() -> Dictionary:
	var profile := _data.duplicate(true)
	for offer: String in _account_offers:
		if offer not in profile.commerce.entitlements:
			profile.commerce.entitlements.append(offer)
	for skin: String in _account_skins:
		if skin not in profile.commerce.skins:
			profile.commerce.skins.append(skin)
	for item: String in _account_items:
		if item not in profile.inventory:
			profile.inventory.append(item)
	for ship: String in profile.equipped:
		profile.equipped[ship] = _available_equipment(ship)
	for ship: String in profile.commerce.equipped_skins.keys():
		if _active_skin(ship).is_empty():
			profile.commerce.equipped_skins.erase(ship)
	profile.unlocked_ships = _unlocked_ships(profile.wins)
	profile.unlocked_sectors = _unlocked_sectors(profile.wins)
	var loadout := sortie()
	var prices := {}
	for track in TRACKS:
		var levels: Dictionary = profile.levels.get(profile.ship_id, {}).duplicate()
		var price := _price(track, int(levels.get(track, 0)))
		price.affordable = not _read_only and price.level < MAX_LEVEL and profile.coins >= price.coins and profile.materials >= price.materials
		levels[track] = mini(MAX_LEVEL, price.level + 1)
		price.next_stats = Catalog.build_stats(profile.ship_id, levels, profile.equipped.get(profile.ship_id, {}))
		prices[track] = price
	var today := _today(profile)
	var daily := _daily_state(profile, today)
	var lifetime: Dictionary = profile.totals.duplicate()
	lifetime.inventory = profile.inventory.size()
	var calendar: Array[Dictionary] = []
	for index in CALENDAR.size():
		var reward: Array = CALENDAR[index]
		calendar.append({"id": str(index + 1), "coins": reward[0], "materials": reward[1],
			"crates": reward[2], "crystals": 15 if index == 6 else 0, "claimed": index < profile.calendar_day,
			"available": not _read_only and index == profile.calendar_day and today > profile.calendar_date})
	return {
		"profile": profile, "stats": loadout.stats, "upgrade_prices": prices, "message": _message,
		"highlight": _highlight, "highlight_value": _highlight_value, "loot": _loot,
		"daily": _objectives(DAILY, daily, daily.claimed),
		"achievements": _objectives(ACHIEVEMENTS, lifetime, profile.achievements),
		"calendar": calendar, "read_only": _read_only,
	}


func save_block_reason() -> String:
	return _message if _read_only else ""


func set_account_offers(ids: Array[String]) -> void:
	_account_offers = ids.duplicate()
	_account_skins.clear()
	_account_items.clear()
	for id: String in _account_offers:
		var offer: Dictionary = Offers.OFFERS[id]
		if offer.has("skin") and offer.skin not in _account_skins:
			_account_skins.append(offer.skin)
		for item: String in offer.get("items", []):
			if item not in _account_items:
				_account_items.append(item)


func _available_equipment(ship: String) -> Dictionary:
	var equipment: Dictionary = _data.equipped.get(ship, {}).duplicate()
	for slot: String in equipment.keys():
		if equipment[slot] not in _data.inventory and equipment[slot] not in _account_items:
			equipment.erase(slot)
	return equipment


func _active_skin(ship: String) -> String:
	var skin: String = _data.commerce.equipped_skins.get(ship, "")
	return skin if skin in _data.commerce.skins or skin in _account_skins else ""


func sortie() -> Dictionary:
	var ship_id: String = _data.ship_id
	var sector_id: String = _data.sector_id
	var sector: Dictionary = Catalog.SECTORS[sector_id]
	return {
		"ship_id": ship_id, "sector_id": sector_id, "sector_title": sector.title, "duration": sector.duration,
		"stats": Catalog.build_stats(ship_id, _data.levels.get(ship_id, {}), _available_equipment(ship_id)),
		"skin_id": _active_skin(ship_id), "effect_id": _data.commerce.effect,
	}


func apply(action: String, value: String = "") -> Dictionary:
	_highlight = ""
	_highlight_value = ""
	_loot = ""
	if _read_only:
		return _fail(_message)
	var candidate := _data.duplicate(true)
	var today := _today(candidate)
	var ship: String = candidate.ship_id
	var message := ""
	var loot := ""
	match action:
		"select_ship":
			if value not in _unlocked_ships(candidate.wins):
				return _fail("Ten statek jest jeszcze zablokowany.")
			candidate.ship_id = value
			message = "Aktywny statek · " + String(Catalog.SHIPS[value].title)
		"select_sector":
			if value not in _unlocked_sectors(candidate.wins):
				return _fail("Ten sektor jest jeszcze zablokowany.")
			candidate.sector_id = value
			message = "Kurs ustawiony · " + String(Catalog.SECTORS[value].title)
		"upgrade":
			if value not in TRACKS:
				return _fail("Nieznany system statku.")
			var levels: Dictionary = candidate.levels.get(ship, {})
			var price := _price(value, int(levels.get(value, 0)))
			if price.level >= MAX_LEVEL or candidate.coins < price.coins or candidate.materials < price.materials:
				return _fail("Brak zasobów lub osiągnięto maksymalny poziom.")
			candidate.coins -= price.coins
			candidate.materials -= price.materials
			levels[value] = price.level + 1
			candidate.levels[ship] = levels
			message = "Modernizacja zakończona · poziom %d" % levels[value]
		"equip", "unequip":
			var equipment: Dictionary = candidate.equipped.get(ship, {})
			if action == "equip":
				if (value not in candidate.inventory and value not in _account_items) or not Catalog.ITEMS.has(value):
					return _fail("Tego modułu nie ma w magazynie.")
				var item: Dictionary = Catalog.ITEMS[value]
				equipment[item.slot] = value
				message = "Zamontowano · " + String(item.title)
			else:
				if not equipment.erase(value):
					return _fail("W tym slocie nie ma modułu.")
				message = "Moduł zdjęty."
			candidate.equipped[ship] = equipment
		"open_crate":
			if candidate.crates <= 0:
				return _fail("Brak skrzyń do otwarcia.")
			candidate.crates -= 1
			loot = _roll_crate(candidate)
			var rarity := Catalog.RARITIES.find(Catalog.ITEMS[loot].rarity)
			candidate.crate_streak = 0 if rarity >= 2 else candidate.crate_streak + 1
			if loot in candidate.inventory:
				var refund: int = DUPLICATE_SALVAGE[rarity]
				candidate.materials += refund
				message = "Duplikat · %s · +%d materiałów" % [Catalog.ITEMS[loot].title, refund]
			else:
				candidate.inventory.append(loot)
				message = "Odzyskano moduł · " + String(Catalog.ITEMS[loot].title)
		"claim_daily", "claim_achievement":
			var daily := _daily_state(candidate, today)
			var lifetime: Dictionary = candidate.totals.duplicate()
			lifetime.inventory = candidate.inventory.size()
			var claim_list: Array = daily.claimed if action == "claim_daily" else candidate.achievements
			var tasks := DAILY if action == "claim_daily" else ACHIEVEMENTS
			var progress := daily if action == "claim_daily" else lifetime
			var claimed := _claim_objective(value, tasks, progress, claim_list, candidate)
			if not claimed:
				return _fail("Nagroda jest niedostępna lub została odebrana.")
			candidate.daily = daily
			message = "Nagroda odebrana."
		"claim_calendar":
			var index: int = candidate.calendar_day
			if value != str(index + 1) or index >= CALENDAR.size() or today <= candidate.calendar_date:
				return _fail("Ten dzień kalendarza nie jest dostępny.")
			var gift: Array = CALENDAR[index]
			candidate.coins += gift[0]
			candidate.materials += gift[1]
			candidate.crates += gift[2]
			if index == 6:
				candidate.crystals += 15
			candidate.calendar_day += 1
			candidate.calendar_date = today
			message = "Nagroda kalendarza · dzień %d" % (index + 1)
		_:
			return _fail("Nieznana operacja hangaru.")
	candidate.last_day = today
	if not _commit(candidate):
		return _fail("Zapis nie powiódł się. Zmiany nie zostały pobrane.")
	_message = message
	_highlight = action
	_highlight_value = value
	_loot = loot
	return {"ok": true, "message": message, "loot": loot}


func credit_mission(result: Dictionary, sector_id: String, flight_id: String = "") -> Dictionary:
	if _read_only:
		return _unsaved_result()
	if flight_id.length() > 64 or (not flight_id.is_empty() and _data.commerce.receipts.has("flight:" + flight_id)):
		return _unsaved_result()
	var candidate := _data.duplicate(true)
	var stage := str(result.get("stage", ""))
	if not stage.is_empty() and not Campaign.access(candidate.campaign, stage):
		return _unsaved_result()
	var seconds := clampf(float(result.get("seconds", 0)), 0, 1800)
	var kills := _count(result.get("kills", 0))
	var won := bool(result.get("won", false))
	var sector: Dictionary = Catalog.SECTORS.get(sector_id, Catalog.SECTORS.peryhelium)
	var gross := 25 + floori(seconds / 6.0) + floori(kills / 11.0) + (230 if won else 0)
	var coins := floori(gross * float(sector.reward_multiplier))
	var materials := _count(result.get("reward", 0))
	var crates := (2 if sector_id == "zenith" else 1) if won else int(seconds >= 180.0)
	var crystals := 4 if won else 0
	var stars := Campaign.grade(stage, result)
	var previous: Dictionary = candidate.campaign.get(stage, {})
	var first := not stage.is_empty() and won and not bool(previous.get("cleared", false))
	var bonus := Campaign.cache_earned(stage, stars, flight_id)
	if first:
		var award := Campaign.first_reward(stage)
		coins += int(award[0])
		materials += int(award[1])
		crates += int(award[2])
	crates += int(bonus)
	var payout := {"ok": true, "coins": coins, "materials": materials, "crates": crates, "crystals": crystals,
		"stars": stars, "first_clear": first, "bonus_cache": bonus}
	candidate.coins += coins
	candidate.materials += materials
	candidate.crates += crates
	candidate.crystals += crystals
	candidate.wins += int(won)
	if not stage.is_empty():
		candidate.campaign[stage] = {"cleared": won or bool(previous.get("cleared", false)),
			"best": maxi(_count(previous.get("best", 0)), _count(result.get("score", 0))),
			"stars": maxi(_count(previous.get("stars", 0)), stars)}
	if not flight_id.is_empty():
		candidate.commerce.receipts["flight:" + flight_id] = "flight"
		candidate.commerce.flight = {"id": flight_id, "doubled": false, "coins": coins,
			"materials": materials, "crates": crates, "crystals": crystals,
			"won": won, "boss": won and Campaign.BOSS_NAMES.has(stage) and result.get("boss_defeated", false),
			"boss_bonus": false}
	var today := _today(candidate)
	var daily := _daily_state(candidate, today)
	for counters in [candidate.totals, daily]:
		counters.flights += 1
		counters.kills += kills
		counters.wins += int(won)
	candidate.daily = daily
	candidate.last_day = today
	if not _commit(candidate):
		_message = "Zapis wyniku nie powiódł się."
		return _unsaved_result()
	_message = "Lot zapisany · +%d Credits, +%d materiałów" % [coins, materials]
	_highlight = ""
	_highlight_value = ""
	_loot = ""
	return payout


func shop_buy(id: String) -> Dictionary:
	if not _account_offers.is_empty() and Offers.owns_offer(snapshot().profile, id):
		return Wallet.failure("owned", "Zawartość tej oferty jest już w kolekcji.")
	return _wallet_transaction(Wallet.buy.bind(id))


func shop_skin(id: String) -> Dictionary:
	return _wallet_transaction(Wallet.set_skin.bind(id, _unlocked_ships(_data.wins), _account_skins))


func shop_effect(id: String) -> Dictionary:
	return _wallet_transaction(Wallet.set_effect.bind(id))


func claim_season(id: String) -> Dictionary:
	return _wallet_transaction(Wallet.claim_season.bind(id, "season_helion" in _account_offers))


func redeem_test_order(id: String, verified_token: String) -> Dictionary:
	return _wallet_transaction(Wallet.redeem_play.bind(id, verified_token))


func redeem_starter_credits(delivery: String) -> Dictionary:
	return _wallet_transaction(Wallet.redeem_starter_credits.bind(delivery))


func ad_day() -> String:
	return _today(_data)


func ad_eligible(placement: String, scope: String) -> bool:
	return not _read_only and scope.length() <= 64 and Wallet.ad_eligible(_data, placement, scope, ad_day())


func claim_rewarded_ad(placement: String, scope: String) -> Dictionary:
	if not ad_eligible(placement, scope):
		return Wallet.failure("claimed", "Nagroda jest już odebrana lub wygasła.")
	return _wallet_transaction(Wallet.claim_ad.bind(placement, scope, ad_day()))


func _wallet_transaction(operation: Callable) -> Dictionary:
	if _read_only:
		return Wallet.failure("save", _message)
	var draft := _data.duplicate(true)
	var outcome: Dictionary = operation.call(draft)
	if outcome.get("changed", false):
		draft.last_day = _today(draft)
		if not _commit(draft):
			return Wallet.failure("save", "Zapis nie powiódł się. Saldo i nagrody pozostają bez zmian.")
	return outcome


func _unsaved_result() -> Dictionary:
	return {"ok": false, "coins": 0, "materials": 0, "crates": 0, "crystals": 0}


func _roll_crate(candidate: Dictionary) -> String:
	# Rarity odds begin at 68/28/4, then evolve with wins.
	var weights := [68.0, 28.0, 4.0, 0.0]
	if candidate.inventory.size() == STARTER_ITEMS.size():
		weights = [0.0, 85.0, 15.0, 0.0]
	elif candidate.wins >= 4:
		weights = [35.0, 39.0, 22.0, 4.0]
	elif candidate.wins >= 1:
		weights = [54.0, 33.0, 12.0, 1.0]
	if candidate.crate_streak >= 4:
		weights[0] = 0.0
		weights[1] = 0.0
	var total := 0.0
	for weight: float in weights:
		total += weight
	var roll := _rng.randf() * total
	var rarity := 2
	for index in weights.size():
		roll -= weights[index]
		if roll < 0.0:
			rarity = index
			break
	var matches: Array[String] = []
	var unowned: Array[String] = []
	for id: String in Catalog.ITEMS:
		if Catalog.ITEMS[id].rarity == Catalog.RARITIES[rarity]:
			matches.append(id)
			if id not in candidate.inventory:
				unowned.append(id)
	var pool := unowned if not unowned.is_empty() else matches
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _price(track: String, level: int) -> Dictionary:
	var base := {"hull": 120, "drive": 135, "output": 155}
	return {"coins": base[track] + 95 * level + 32 * level * level,
		"materials": 18 + 14 * level + 6 * level * level, "level": level, "max_level": MAX_LEVEL}


func _claim_objective(id: String, definitions: Array, progress: Dictionary, claimed: Array, candidate: Dictionary) -> bool:
	if id in claimed:
		return false
	for entry: Array in definitions:
		if entry[0] == id and int(progress.get(entry[2], 0)) >= int(entry[3]):
			claimed.append(id)
			candidate.coins += entry[4]
			candidate.materials += entry[5]
			return true
	return false


func _objectives(definitions: Array, progress: Dictionary, claimed: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Array in definitions:
		var done: bool = entry[0] in claimed
		var count := int(progress.get(entry[2], 0))
		result.append({"id": entry[0], "title": entry[1], "progress": mini(count, int(entry[3])),
			"goal": entry[3], "coins": entry[4], "materials": entry[5], "claimed": done,
			"available": not _read_only and not done and count >= int(entry[3])})
	return result


func _today(profile: Dictionary) -> String:
	var device_date := Time.get_date_string_from_system() if date_override.is_empty() else date_override
	var last: String = profile.last_day
	return device_date if device_date > last else last


func _daily_state(profile: Dictionary, today: String) -> Dictionary:
	if profile.daily.get("date", "") == today:
		return profile.daily.duplicate(true)
	return {"date": today, "flights": 0, "kills": 0, "wins": 0, "claimed": []}


func _fresh() -> Dictionary:
	return {
		"coins": 420, "crystals": 0, "materials": 90, "wins": 0, "crates": 1, "crate_streak": 0,
		"commerce": Wallet.empty_state(), "campaign": {},
		"ship_id": "peregrine", "sector_id": "peryhelium", "inventory": STARTER_ITEMS.duplicate(),
		"levels": {}, "equipped": {}, "totals": {"flights": 0, "kills": 0, "wins": 0},
		"achievements": [], "daily": {}, "calendar_day": 0, "calendar_date": "", "last_day": "",
	}


func _unlocked_sectors(wins: int) -> Array[String]:
	var unlocked: Array[String] = []
	for id: String in Catalog.SECTORS:
		if wins >= Catalog.SECTORS[id].unlock_wins:
			unlocked.append(id)
	return unlocked


func _unlocked_ships(wins: int) -> Array[String]:
	var unlocked: Array[String] = []
	var sectors := _unlocked_sectors(wins)
	for id: String in Catalog.SHIPS:
		var spec: Dictionary = Catalog.SHIPS[id]
		if wins >= spec.unlock_wins and spec.unlock_sector in sectors:
			unlocked.append(id)
	return unlocked


func _commit(candidate: Dictionary) -> bool:
	var next := _revision + 1
	var target := _slot_path(next % 2)
	var temporary := target + ".tmp"
	var payload := JSON.stringify({"version": VERSION, "revision": next, "data": candidate})
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"payload": payload, "sha256": payload.sha256_text()}))
	file.flush()
	file.close()
	if _read_slot(temporary).is_empty():
		return false
	if DirAccess.rename_absolute(temporary, target) != OK:
		return false
	_data = candidate
	_revision = next
	return true


func _slot_path(slot: int) -> String:
	return "%s.%d.json" % [save_path, slot]


func _read_slot(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String:
		return {}
	var payload: String = envelope.payload
	if envelope.get("sha256") != payload.sha256_text():
		return {}
	if parser.parse(payload) != OK:
		return {}
	var record: Variant = parser.data
	if not record is Dictionary or not record.get("data") is Dictionary:
		return {}
	if _count(record.get("version", 0)) < 1 or _count(record.get("revision", 0)) < 1:
		return {}
	return record


func _normalize(source: Dictionary, version: int) -> Dictionary:
	var clean := _fresh()
	for key in ["coins", "crystals", "materials", "wins", "crates", "crate_streak", "calendar_day"]:
		clean[key] = _count(source.get(key, clean[key]))
	if version == 1 and not source.has("materials"):
		clean.materials += _count(source.get("salvage", 0))
	clean.calendar_day = mini(CALENDAR.size(), clean.calendar_day)
	for key in ["calendar_date", "last_day"]:
		clean[key] = _date(source.get(key, ""))
	var ships := _unlocked_ships(clean.wins)
	var sectors := _unlocked_sectors(clean.wins)
	if source.get("ship_id") in ships:
		clean.ship_id = source.ship_id
	if source.get("sector_id") in sectors:
		clean.sector_id = source.sector_id
	if source.get("inventory") is Array:
		for item: Variant in source.inventory:
			if item is String and Catalog.ITEMS.has(item) and item not in clean.inventory:
				clean.inventory.append(item)
	var levels := _dictionary(source.get("levels"))
	var equipment := _dictionary(source.get("equipped"))
	for ship in ships:
		var saved_levels := _dictionary(levels.get(ship))
		var saved_equipment := _dictionary(equipment.get(ship))
		clean.levels[ship] = {}
		clean.equipped[ship] = {}
		for track in TRACKS:
			clean.levels[ship][track] = mini(MAX_LEVEL, _count(saved_levels.get(track, 0)))
		for slot in Catalog.SLOTS:
			var item: Variant = saved_equipment.get(slot)
			if item is String and Catalog.ITEMS.has(item) and Catalog.ITEMS[item].slot == slot:
				clean.equipped[ship][slot] = item
	var totals := _dictionary(source.get("totals"))
	var daily := _dictionary(source.get("daily"))
	clean.daily = {"date": _date(daily.get("date")), "claimed": _string_list(daily.get("claimed"))}
	for key in ["flights", "kills", "wins"]:
		clean.totals[key] = _count(totals.get(key, 0))
		clean.daily[key] = _count(daily.get(key, 0))
	clean.achievements = _string_list(source.get("achievements"))
	var campaign := _dictionary(source.get("campaign"))
	for id: String in Campaign.ROUTE:
		if campaign.has(id) and Campaign.access(clean.campaign, id):
			var record := _dictionary(campaign[id])
			var cleared: bool = record.get("cleared", false) == true
			clean.campaign[id] = {"cleared": cleared, "best": _count(record.get("best", 0)),
				"stars": clampi(_count(record.get("stars", 0)), 1, 3) if cleared else 0}
	_restore_wallet(clean, _dictionary(source.get("commerce")))
	return clean


func _restore_wallet(profile: Dictionary, source: Dictionary) -> void:
	var wallet: Dictionary = profile.commerce
	for id in _string_list(source.get("entitlements")):
		if Offers.OFFERS.has(id):
			wallet.entitlements.append(id)
	for id in _string_list(source.get("skins")):
		if Offers.SKINS.has(id):
			wallet.skins.append(id)
	for id in _string_list(source.get("season")):
		if Offers.SEASON.has(id):
			wallet.season.append(id)
	var equipped := _dictionary(source.get("equipped_skins"))
	for ship: String in Catalog.SHIPS:
		var skin: Variant = equipped.get(ship)
		if skin is String and Offers.SKINS.has(skin) and Offers.SKINS[skin].ship == ship:
			wallet.equipped_skins[ship] = skin
	var receipts := _dictionary(source.get("receipts"))
	for key: Variant in receipts:
		if key is String and key.length() <= 72 and receipts[key] is String:
			var value: String = receipts[key]
			if ((key.begins_with("test:") or key.begins_with("play:")) and Offers.OFFERS.has(value)) or value in ["revive", "flight"]:
				wallet.receipts[key] = value
	wallet.bonus_day = _date(source.get("bonus_day"))
	wallet.materials_day = _date(source.get("materials_day"))
	var effect: Variant = source.get("effect")
	if effect is String and Offers.EFFECTS.has(effect) and effect in wallet.entitlements:
		wallet.effect = effect
	var flight := _dictionary(source.get("flight"))
	var id: Variant = flight.get("id")
	if id is String and id.length() <= 64 and wallet.receipts.get("flight:" + id) == "flight":
		wallet.flight = {"id": id, "doubled": flight.get("doubled", false) == true,
			"won": flight.get("won", false) == true, "boss": flight.get("boss", false) == true,
			"boss_bonus": flight.get("boss_bonus", false) == true}
		for currency in Wallet.VALUES:
			wallet.flight[currency] = _count(flight.get(currency))


func _date(value: Variant) -> String:
	if value is String and value.length() == 10:
		var parts: PackedStringArray = value.split("-")
		if parts.size() == 3 and parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int():
			if int(parts[1]) in range(1, 13) and int(parts[2]) in range(1, 32):
				return value
	return ""


func _string_list(value: Variant) -> Array:
	var result := []
	if value is Array:
		for entry: Variant in value:
			if entry is String and entry.length() < 40 and entry not in result:
				result.append(entry)
	return result


func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


func _count(value: Variant) -> int:
	if value is int or value is float:
		return int(clampf(float(value), 0, 100000000))
	return 0


func _fail(message: String) -> Dictionary:
	_message = message
	return {"ok": false, "message": message}
