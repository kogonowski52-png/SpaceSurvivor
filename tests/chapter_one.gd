extends "res://tests/premium_visual.gd"
## Runs the saved, free-to-play progression and targeted balance samples as separate tests.

const Loadouts := preload("res://data/progression_catalog.gd")
const Warship := preload("res://vertical/dreadnought.gd")
const Hazards := preload("res://vertical/flight_hazards.gd")
const LOADOUTS := {
	"stock": {"ship": "peregrine", "tracks": {}, "equipment": {}},
	"mid": {"ship": "aegis", "tracks": {"hull": 2, "drive": 1, "output": 2},
		"equipment": {"weapon": "rapid_feed", "armor": "ceramic_shell", "engine": "plasma_sprint"}},
	"high": {"ship": "specter", "tracks": {"hull": 4, "drive": 4, "output": 4},
		"equipment": {"weapon": "starbreaker", "armor": "aegis_matrix", "engine": "quasar_drive",
			"reactor": "nova_core", "drone": "archon_bay"}},
}

var _peaks := Vector3i.ZERO
var _fighter_mask := 0


func _run() -> void:
	if "--balance-chapter" in OS.get_cmdline_user_args():
		await _balance()
	else:
		_validate_route()
		_test_saved_campaign()
		_test_new_combat()
		await _load_chapter("-route")
		await _finish_route()
	print("QA chapter one: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _load_chapter(suffix: String) -> void:
	var entry := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	game = entry.instantiate()
	game.progression.save_path = profile_path + suffix
	game.progression.legacy_path = ""
	root.add_child(game)
	game.test_ads.response_delay = 0.0
	await _frames(17)


func _validate_route() -> void:
	_check(Campaign.ROUTE.size() == 10 and Campaign.STAGES.size() == 10, "the chapter has ten authored sorties")
	var backgrounds: Dictionary = {}
	var roster := 0
	var sector_count := 0
	for region: Dictionary in Campaign.SECTORS:
		_check(int(region.start) == sector_count, "sector slices follow the authored route")
		sector_count += int(region.size)
	for id in Campaign.ROUTE:
		var stage: Dictionary = Campaign.STAGES[id]
		backgrounds[stage.sky] = true
		_check(ResourceLoader.exists(stage.sky) and Campaign.enemy_quota(stage) > 20, "authored background and deployable waves: " + id)
		var valid := true
		for wave: Dictionary in stage.waves:
			for group: Array in wave.groups:
				var kind := int(group[1])
				roster |= 1 << kind
				valid = valid and kind < Squadron.ART.size() and group[0] in ["line", "wedge", "arc", "raid", "group", "spiral", "flank"]
		_check(valid, "formation plan uses supported shapes and enemy IDs: " + id)
	_check(backgrounds.size() == 10 and roster == 127 and sector_count == 10, "ten backdrops, four connected sectors and all seven enemy classes")


func _test_saved_campaign() -> void:
	var prior := Pilot.new()
	prior.save_path = profile_path + "-v4"
	prior.legacy_path = ""
	var old := prior._fresh()
	old.coins = 1385
	old.crystals = 138
	old.materials = 275
	old.wins = 7
	old.ship_id = "aurora"
	old.campaign = {"echo": {"cleared": true, "best": 8504}, "prism": {"cleared": true, "best": 10242}}
	old.levels.aurora = {"hull": 2}
	old.equipped.aurora = {"weapon": "rapid_feed"}
	old.inventory.append("rapid_feed")
	old.commerce.entitlements.append("starter")
	old.commerce.skins.append("peregrine_ion")
	var receipt := "play:" + "historic-receipt".sha256_text()
	old.commerce.receipts[receipt] = "starter"
	var payload := JSON.stringify({"version": 4, "revision": 19, "data": old})
	var slot := FileAccess.open(prior.save_path + ".1.json", FileAccess.WRITE)
	slot.store_string(JSON.stringify({"payload": payload, "sha256": payload.sha256_text()}))
	slot.close()
	prior.load_profile()
	var restored: Dictionary = prior.snapshot().profile
	_check(restored.coins == 1385 and restored.crystals == 138 and restored.materials == 275 and restored.ship_id == "aurora"
		and restored.levels.aurora.hull == 2 and restored.equipped.aurora.weapon == "rapid_feed", "v4 migration retains currency, Aurora and gear")
	_check("starter" in restored.commerce.entitlements and "peregrine_ion" in restored.commerce.skins
		and restored.commerce.receipts.get(receipt) == "starter", "v4 migration retains purchased entitlements, skin and receipt evidence")
	_check(restored.campaign.prism.stars == 1 and restored.campaign.prism.best == 10242
		and Campaign.access(restored.campaign, "helion") and not Campaign.access(restored.campaign, "titan"), "v4 wins become one-star clears with their original records")
	var replay := _victory("echo")
	replay.kills = 200
	replay.hull_ratio = 0.81
	replay.score = 27_180
	var replayed := prior.credit_mission(replay, "peryhelium", "replay")
	_check(replayed.ok and replayed.stars == 3 and not replayed.first_clear, "migrated stage does not repeat the first clear award")
	var first := prior.credit_mission(_victory("helion"), "zenith", "helion")
	_check(first.ok and first.first_clear and first.stars == 1 and first.coins >= int(Campaign.first_reward("helion")[0])
		and first.crates >= 3, "first clear grants its stated rewards and one star")
	_check(not prior.credit_mission(_victory("helion"), "zenith", "helion").ok, "same flight cannot duplicate a payout")
	var retry := prior.credit_mission(_victory("helion"), "zenith", "helion-later")
	_check(retry.ok and not retry.first_clear and retry.coins + int(Campaign.first_reward("helion")[0]) == first.coins,
		"replay deducts the one-time credit premium and retains normal rewards")
	prior.load_profile()
	var saved: Dictionary = prior.snapshot().profile
	_check(saved.campaign.echo.stars == 3 and saved.campaign.echo.best == 27_180
		and Campaign.access(saved.campaign, "titan") and saved.commerce.receipts.has(receipt), "a second load restores stars, best and entitlement records")


func _test_new_combat() -> void:
	var craft := Flight.new()
	craft.configure("tempest", {})
	root.add_child(craft)
	craft.set_physics_process(false)
	var escort := _fighter(4, "line", Vector2(270, 234))
	var friend := _fighter(0, "line", Vector2(224, 253))
	craft._enemies.assign([escort, friend])
	var hp := friend.hp
	craft._damage_enemy(1, 10.0, friend.position)
	_check(is_equal_approx(friend.hp, hp - 2.4) and is_equal_approx(escort.shield, 80.4), "Shield Carrier intercepts allied damage and depletes its finite reserve")
	escort.shield = 0.0
	craft._damage_enemy(1, 5.0, friend.position)
	_check(is_equal_approx(friend.hp, hp - 7.4), "depleted carrier no longer reduces damage")
	var phantom := _fighter(6, "line", Vector2(442, 265))
	phantom.age = 1.9
	phantom.offset = 0.0
	phantom.fire_in = 1.3
	craft._enemies.assign([phantom])
	hp = phantom.hp
	_check(phantom.cloaked() and craft._nearest_target(Vector2(440, 482)) == Vector2.ZERO, "Phantom cloak breaks rocket lock")
	craft._damage_enemy(0, 10.0, phantom.position)
	_check(is_equal_approx(phantom.hp, hp - 3.8), "Phantom cloak reduces impact damage")
	phantom.fire_in = 0.05
	_check(not phantom.cloaked(), "Phantom is visible before it fires")
	craft._step_enemies(0.1)
	_check(craft._shots.size() == 2 and craft._shots[0].kind == Weapons.Kind.ORBIT, "Phantom fires two bending pulses")
	craft._clear_hostile_rounds()
	var intercept := _fighter(3, "raid", Vector2(300, 170))
	var scout := _fighter(0, "raid", Vector2(300, 170))
	intercept.age = intercept.entry
	scout.age = scout.entry
	intercept.advance(0.61)
	scout.advance(0.61)
	_check(intercept.position.y > scout.position.y + 50.0, "Interceptor dive outruns the Scout")
	craft._enemies.clear()
	craft.launch_bomb(Vector2(270, 290), craft.player_position)
	craft._step_shots(1.18)
	_check(craft.hazards.active.size() == 1 and craft.hazards.active[0].kind == Hazards.Kind.BLAST, "fused torpedo leaves a timed blast zone")
	var before := craft._hp
	craft.hazards.step(craft, 0.53)
	_check(craft._hp == before, "bomb warning has no premature damage")
	craft.hazards.step(craft, 0.47)
	_check(craft._hp < before, "bomb deals damage in its marked area")
	craft.free()

	for id in ["guardian", "abyss"]:
		var target := Flight.new()
		target.configure(id, {})
		root.add_child(target)
		target.set_physics_process(false)
		var capital := Warship.new(target._boss_id)
		target.boss = capital
		capital.state = "recover"
		capital.position = Vector2(270, 226)
		var body_hp := capital.hp
		for part in capital._turrets:
			var x := capital.position.x + part.mount.x
			target.beam_damage(Vector2(x, 828), 600.0)
		_check(capital.modules_left() == 0 and target.modules_destroyed == capital._turrets.size() and capital.hp == body_hp,
			"swept hits independently destroy every visible module on " + capital.encounter_name())
		target.free()


func _fighter(kind: int, form: String, point: Vector2) -> Squadron.Fighter:
	var unit := Squadron.Fighter.new()
	var plan := Squadron.plan([[form, kind, 1, 0.0, point.y]])[0]
	unit.reset(plan, 1, 9)
	unit.position = point
	unit.fire_in = 2.0
	return unit


func _finish_route() -> void:
	await _click("LaunchButton")
	var locked := _button("LaunchStage_abyss")
	_check(locked == null and _button("LaunchStage_echo") != null, "new pilot enters the first sortie and the finale is locked")
	if not await _click("LaunchStage_echo"):
		return
	for id in Campaign.ROUTE:
		if not _check(game.phase == "combat" and game.selected_stage == id, "normal campaign entry: " + id):
			return
		var craft: Flight = game.flight
		craft.revive_offer_enabled = false
		await _simulate(craft)
		_log_sortie("route", id, craft)
		if not _check(game.phase == "result" and game._result.get("won", false), "wins without ads or purchased gear: " + id):
			return
		_check(craft._waves_cleared == craft._stage.waves.size() and craft._seconds >= 115.0 and craft._seconds <= 240.0,
			"all authored waves resolve at campaign cadence: " + id)
		var profile: Dictionary = game.progression.snapshot().profile
		_check(profile.campaign[id].stars >= 1 and profile.campaign[id].best > 0 and game._result.first_clear, "record, stars and first clear persist: " + id)
		if Campaign.BOSS_NAMES.has(id):
			var expected_mask := 15 if id == "abyss" else 7
			_check(craft.boss_phases_fired == expected_mask, "all boss phases actually attack: " + id)
		var next := Campaign.next(id)
		if not next.is_empty():
			_check(Campaign.access(profile.campaign, next), "clearing the level unlocks the next sortie")
			await _click("NextStageButton")
	_check(_fighter_mask == 127, "all seven enemy classes spawned during the normal run")
	await _click("CampaignButton")
	await _click("SectorJump_00")
	await _frames(30)
	await _click("LaunchStage_echo")
	_check(game.phase == "combat" and game.selected_stage == "echo", "completed chapter allows replay from the map")
	await _click("PauseButton")
	await _click("MenuButton")
	_check(game.phase == "menu", "replay can return to menu")
	var save: String = game.progression.save_path
	game.queue_free()
	await _frames(3)
	var again := Pilot.new()
	again.save_path = save
	again.legacy_path = ""
	again.load_profile()
	_check(again.snapshot().profile.campaign.size() == 10 and again.snapshot().profile.campaign.abyss.stars >= 1,
		"new profile instance reloads all ten records and the finale stars")
	await _load_chapter("-pages")
	await _check_pages()


func _check_pages() -> void:
	await _click("SettingsButton")
	_check(game.phase == "settings", "main menu opens settings")
	await _click("SettingsDone")
	_check(game.phase == "menu", "settings save returns to title")
	await _click("HangarButton")
	await _click("WorkshopButton")
	_check(game.phase == "hangar" and game.ui.hangar_tab() == "workshop", "the hangar still opens the workshop")
	await _click("UpgradeHullButton")
	_check(game.progression.snapshot().profile.levels.peregrine.hull == 1, "hangar purchases a real upgrade")
	await _click("HangarTabRewards")
	await _click("HangarStoreButton")
	await _click("StoreTab_crystals")
	_check(game.phase == "store" and game.ui._store.current_tab == "crystals" and game.ui._store._data.simulation,
		"hangar connects to the existing shop using the test adapter")
	await _click("StoreBackButton")
	_check(game.phase == "hangar" and game.ui.hangar_tab() == "rewards", "shop returns to the originating rewards tab")


func _balance() -> void:
	for group in LOADOUTS:
		var sample: Dictionary = LOADOUTS[group]
		var stats: Dictionary = Loadouts.build_stats(sample.ship, sample.tracks, sample.equipment)
		for id in ["helion", "guardian", "abyss"]:
			var craft := Flight.new()
			craft.configure(id, {"ship_id": sample.ship, "stats": stats})
			craft.revive_offer_enabled = false
			root.add_child(craft)
			await _simulate(craft, 6 if group == "stock" else (8 if group == "mid" else 10))
			_log_sortie(group, id, craft)
			_check(craft._boss_defeated and craft._ended, "simulated loadout wins without continue: %s / %s" % [group, id])
			craft.queue_free()
			await _frames(2)


func _log_sortie(mode: String, id: String, craft: Flight) -> void:
	var objective: bool = craft._waves_cleared == craft._stage.waves.size() if craft._boss_id.is_empty() else craft._boss_defeated
	var won: bool = craft._ended and craft._hp > 0.0 and objective
	print("SORTIE %s %s win=%s seconds=%.2f kills=%d escaped=%d hull=%.1f rank=%d boss_mask=%d modules=%d peaks=%s" % [
		mode, id, won,
		craft._seconds, craft._kills, craft._escaped, craft._hp / craft._max_hp * 100.0, craft.gear.rank,
		craft.boss_phases_fired, craft.modules_destroyed, _peaks])


func _simulate(craft: Flight, input_period := 6) -> void:
	_peaks = Vector3i.ZERO
	var limit := ceili((craft._duration + 4.5) * 60.0 / input_period)
	for tick in limit:
		if craft._ended or craft._revive_pending:
			break
		_chapter_input(craft)
		await _steps(input_period)
		_peaks.x = maxi(_peaks.x, craft.active_enemy_count())
		_peaks.y = maxi(_peaks.y, craft._shots.size())
		_peaks.z = maxi(_peaks.z, craft.hazards.active.size())
	_fighter_mask |= craft.seen_fighters
	_release_actions()


func _chapter_input(craft: Flight) -> void:
	var preferred := Vector2(270.0, 793.0)
	if not craft._pickups.is_empty():
		var drop: Vector2 = craft._pickups.front().position
		preferred = Vector2(drop.x, clampf(drop.y + 28.0, 619.0, 839.0))
	else:
		var target := craft._nearest_target(craft.player_position)
		if target != Vector2.ZERO:
			preferred.x = target.x
	var depths := [preferred.y]
	if not craft.hazards.active.is_empty() or craft.boss != null:
		depths.append_array([651.0, 737.0, 840.0])
	var current := craft.player_position
	var best := current
	var lowest := INF
	for depth: float in depths:
		for lane in range(39, 506, 26):
			var point := Vector2(lane, depth)
			var distance := absf(lane - preferred.x) + absf(depth - preferred.y) * .42 + point.distance_to(current) * .20
			if distance >= lowest:
				continue
			var risk := distance + craft.hazards.risk(point, 0.73)
			risk += craft.hazards.risk(current.lerp(point, .42), 0.31) * .24
			if craft.boss != null and craft.boss.phase == 2:
				for rail: float in craft.boss.lanes:
					if absf(lane - rail) < 40.0 and craft.boss.state in ["warning", "fire"]:
						risk += 340.0
			for shot in craft._shots:
				if not shot.hostile() or shot.velocity.y < 25.0:
					continue
				var travel := (depth - shot.position.y) / shot.velocity.y
				if travel < -0.12 or travel > 0.82:
					continue
				var crossing := shot.position.x + shot.velocity.x * travel
				risk += maxf(0.0, 48.0 - absf(crossing - lane)) * (5.5 - travel * 3.2)
			for enemy in craft._enemies:
				if enemy.position.distance_squared_to(point) < 65.0 * 65.0:
					risk += 188.0
			if risk < lowest:
				lowest = risk
				best = point
	var move := best - current
	_release_actions()
	if absf(move.x) > 7.0:
		Input.action_press("move_left" if move.x < 0.0 else "move_right", clampf(absf(move.x) / 32.0, 0.28, 1.0))
	if absf(move.y) > 12.0:
		Input.action_press("move_up" if move.y < 0.0 else "move_down", clampf(absf(move.y) / 56.0, 0.27, 1.0))
