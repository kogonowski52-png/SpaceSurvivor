extends SceneTree
## Runs three deterministic seven-day profiles through the same wallet and upgrade code as the game.

const Pilot := preload("res://data/pilot_progression.gd")
const Campaign := preload("res://vertical/campaign.gd")
const Wallet := preload("res://data/store/wallet.gd")
const DAYS := [2, 1, 2, 1, 2, 1, 1]
# Recorded 1.1 Chapter One regression times, kills and hull ratios.
const FLIGHTS := [
	[133.18, 185, 0.83], [142.82, 198, 0.72], [157.48, 212, 0.87],
	[136.10, 168, 0.38], [133.90, 168, 0.54], [127.08, 154, 0.72],
	[131.45, 197, 0.72], [129.75, 203, 0.41], [133.22, 199, 0.59], [136.55, 181, 0.87],
]
const UPGRADES := ["hull", "output", "drive", "hull", "output"]
const FREE_REWARDS := ["free_1", "free_3", "free_6"]
const PASS_REWARDS := ["pass_1", "pass_3", "pass_6"]
const PACKAGES := ["starter", "arsenal_pilot", "hangar_supply", "season_helion"]
const CURRENCY := ["coins", "materials", "crystals", "crates"]

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for mode in ["free", "ads", "packages"]:
		_simulate(mode)
	print("QA economy 1.1: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)


func _simulate(mode: String) -> void:
	var pilot := Pilot.new()
	pilot.save_path = "user://economy-1-1-%s-%d" % [mode, Time.get_ticks_usec()]
	pilot.legacy_path = ""
	pilot.date_override = "2026-11-01"
	pilot.load_profile()
	var totals := {"flight": _empty_money(), "daily": _empty_money(), "helion": _empty_money(),
		"calendar": _empty_money(), "ad": _empty_money(), "pack": _empty_money()}
	var initial: Dictionary = pilot.snapshot().profile
	var unlocks := {"peregrine": 0}
	var seconds := 0.0
	var upgrade_index := 0
	var next_level := 0
	var equipment_day := 0
	var upgraded_day := 0
	var ads := 0
	if mode == "packages":
		for id: String in PACKAGES:
			var transfer := pilot.redeem_test_order(id, "gs-test-economy-" + id)
			if not transfer.ok:
				_failures += 1
		_add(totals.pack, _difference(pilot.snapshot().profile, initial))
	for day_index in DAYS.size():
		var day := day_index + 1
		pilot.date_override = "2026-11-%02d" % day
		var before: Dictionary = pilot.snapshot().profile
		pilot.apply("claim_calendar", str(day))
		_add(totals.calendar, _difference(pilot.snapshot().profile, before))
		if mode == "ads":
			for placement in ["bonus", "materials"]:
				_add(totals.ad, pilot.claim_rewarded_ad(placement, pilot.ad_day()).get("reward", {}))
				ads += 1
		for daily_index in int(DAYS[day_index]):
			var id := Campaign.ROUTE[next_level]
			var stage: Dictionary = Campaign.STAGES[id]
			var entry: Array = FLIGHTS[next_level]
			var report := {"stage": id, "won": true, "seconds": entry[0], "kills": entry[1],
				"hull_ratio": entry[2], "reward": stage.reward, "boss_defeated": Campaign.BOSS_NAMES.has(id), "score": 24000}
			var scope := "economy-" + id
			var base := pilot.credit_mission(report, stage.sector, scope)
			if not base.ok or not base.first_clear or base.stars < 1:
				_failures += 1
				return
			_add(totals.flight, base)
			seconds += float(entry[0])
			for ship: String in pilot.snapshot().profile.unlocked_ships:
				if not unlocks.has(ship):
					unlocks[ship] = next_level + 1
			if mode == "free":
				print("PAYOUT %s %s" % [id, JSON.stringify({"seconds": entry[0], "stars": base.stars,
					"credits": base.coins, "materials": base.materials, "crates": base.crates,
					"repeat_credits": base.coins - int(Campaign.first_reward(id)[0]),
					"repeat_materials": base.materials - int(Campaign.first_reward(id)[1]),
					"cache_percent": Campaign.cache_chance(id, base.stars)})])
			if mode == "ads":
				if report.boss_defeated:
					_add(totals.ad, pilot.claim_rewarded_ad("boss", scope).get("reward", {}))
					ads += 1
				if daily_index == int(DAYS[day_index]) - 1:
					_add(totals.ad, pilot.claim_rewarded_ad("double", scope).get("reward", {}))
					ads += 1
			next_level += 1
		before = pilot.snapshot().profile
		for mission in before_objectives(pilot):
			pilot.apply(mission.action, mission.id)
		_add(totals.daily, _difference(pilot.snapshot().profile, before))
		before = pilot.snapshot().profile
		for id: String in FREE_REWARDS:
			pilot.claim_season(id)
		if mode == "packages":
			for id: String in PASS_REWARDS:
				pilot.claim_season(id)
		_add(totals.helion, _difference(pilot.snapshot().profile, before))
		if equipment_day == 0 and pilot.shop_buy("equipment_patrol").ok:
			equipment_day = day
		while upgrade_index < UPGRADES.size() and pilot.apply("upgrade", UPGRADES[upgrade_index]).ok:
			upgrade_index += 1
		if upgraded_day == 0 and upgrade_index == UPGRADES.size():
			upgraded_day = day
		if day == 1 or day == 7:
			print("WALLET %s day=%d %s" % [mode, day, JSON.stringify(_difference(pilot.snapshot().profile, _empty_money()))])
	var end: Dictionary = pilot.snapshot().profile
	if end.campaign.size() != Campaign.ROUTE.size() or not end.campaign.abyss.cleared:
		_failures += 1
	print("ECONOMY %s %s" % [mode, JSON.stringify({"seconds": snappedf(seconds, 0.01), "ads_watched": ads,
		"equipment_day": equipment_day, "upgrade_goal_day": upgraded_day, "ship_unlocks": unlocks, "income": totals})])


func before_objectives(pilot: Pilot) -> Array[Dictionary]:
	var snapshot := pilot.snapshot()
	var tasks: Array[Dictionary] = []
	for key in ["daily", "achievements"]:
		for objective: Dictionary in snapshot[key]:
			if objective.available:
				tasks.append({"action": "claim_daily" if key == "daily" else "claim_achievement", "id": objective.id})
	return tasks


func _empty_money() -> Dictionary:
	return {"coins": 0, "materials": 0, "crystals": 0, "crates": 0}


func _difference(after: Dictionary, before: Dictionary) -> Dictionary:
	var diff := _empty_money()
	for key: String in CURRENCY:
		diff[key] = int(after[key]) - int(before[key])
	return diff


func _add(total: Dictionary, delta: Dictionary) -> void:
	for key: String in CURRENCY:
		total[key] += int(delta.get(key, 0))
