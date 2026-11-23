extends SceneTree
## Economy projection; supplies representative results to production profile rules.

const PilotProgression := preload("res://data/pilot_progression.gd")
const Catalog := preload("res://data/progression_catalog.gd")
const WINDOW_SECONDS := 5 * 60 * 60


func _initialize() -> void:
	_simulate("learning", [[false, 345, 350, 120], [false, 400, 470, 180], [false, 490, 620, 230], [true, 600, 930, 390]])
	_simulate("regular", [[false, 480, 540, 190], [true, 600, 1150, 480]])
	quit()


func _simulate(label: String, results: Array) -> void:
	var pilot := PilotProgression.new()
	pilot.save_path = "user://qa-economy-%s-%d" % [label, Time.get_ticks_usec()]
	pilot.legacy_path = pilot.save_path + "-unused.cfg"
	pilot.date_override = "2026-11-23"
	pilot.load_profile()
	pilot._rng.seed = 573_103
	pilot.apply("claim_calendar", "1")
	var elapsed := 0
	var completed := 0
	var credits := 0
	var resources := 0
	var spent := _service_profile(pilot)
	var sector_launch_counts := {}
	while true:
		var data: Array = results[completed % results.size()]
		var seconds: int = data[1]
		if elapsed + seconds > WINDOW_SECONDS:
			break
		elapsed += seconds
		completed += 1
		var state := pilot.snapshot()
		var sector_id: String = state.profile.unlocked_sectors.back()
		sector_launch_counts[sector_id] = int(sector_launch_counts.get(sector_id, 0)) + 1
		var sector: Dictionary = Catalog.SECTORS[sector_id]
		var sortie_result := {
			"won": data[0], "seconds": seconds, "kills": data[2],
			"reward": roundi(float(data[3]) * float(sector.reward_multiplier)),
		}
		var payout := pilot.credit_mission(sortie_result, sector_id)
		credits += int(payout.coins)
		resources += int(payout.materials)
		spent += _service_profile(pilot)
		var wins: int = pilot.snapshot().profile.wins
		if bool(data[0]) and wins in [1, 3, 4, 7]:
			print("%s: win %d at %.1f min" % [label, wins, elapsed / 60.0])

	var finish: Dictionary = pilot.snapshot().profile
	print("%s summary: %s" % [label, {
		"minutes": elapsed / 60.0, "sorties": completed, "wins": finish.wins,
		"coins_from_sorties": credits, "materials_from_sorties": resources,
		"coins_spent": spent, "remaining_coins": finish.coins,
		"modules": finish.inventory.size(), "ranks": finish.levels.get("peregrine", {}),
		"sectors_visited": sector_launch_counts,
	}])
	for index in 2:
		var path := "%s.%d.json" % [pilot.save_path, index]
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _service_profile(pilot: PilotProgression) -> int:
	var state := pilot.snapshot()
	for task in state.daily:
		if task.available:
			pilot.apply("claim_daily", task.id)
	for task in state.achievements:
		if task.available:
			pilot.apply("claim_achievement", task.id)
	for count in int(pilot.snapshot().profile.crates):
		pilot.apply("open_crate")
	var spent := 0
	for purchase in 15:
		state = pilot.snapshot()
		var chosen := ""
		var lowest := 6
		for track in ["hull", "drive", "output"]:
			var price: Dictionary = state.upgrade_prices[track]
			if price.affordable and price.level < lowest:
				chosen = track
				lowest = price.level
		if chosen.is_empty() or not pilot.apply("upgrade", chosen).ok:
			break
		spent += int(state.upgrade_prices[chosen].coins)
	return spent
