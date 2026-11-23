extends "res://tests/smoke.gd"
## Tests a disposable pilot profile and drives the hangar through its normal controls.

const Catalog := preload("res://data/progression_catalog.gd")
const Progression := preload("res://data/pilot_progression.gd")
const QA_DATE := "2026-05-14"

var profile_path := "user://qa-stage3-%d.json" % Time.get_ticks_usec()


func _run() -> void:
	_test_catalog()
	if capture_dir.is_empty():
		_test_storage()
		_test_unlocks()
	if not await _open_game():
		quit(1)
		return
	await _test_hangar()
	print("QA progression: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _test_catalog() -> void:
	_check(Catalog.SHIPS.size() == 4, "catalog has four ships")
	_check(Catalog.SECTORS.size() >= 3, "catalog has at least three sectors")
	_check(Catalog.SLOTS.size() == 5 and Catalog.ITEMS.size() == 20, "catalog has five slots and twenty pieces of equipment")
	for slot in Catalog.SLOTS:
		var rarities := {}
		for item in Catalog.ITEMS.values():
			if item.slot == slot:
				rarities[item.rarity] = true
		_check(rarities.size() == Catalog.RARITIES.size(), "%s has all four rarity tiers" % slot)


func _open_game() -> bool:
	var entry := load("res://main.tscn") as PackedScene
	if not _check(entry != null, "main scene loads for progression"):
		return false
	game = entry.instantiate()
	if not _check(game.get_script() != null and game.get_script().can_instantiate(), "main script compiles for progression"):
		game.free()
		return false
	game.progression.save_path = profile_path
	game.progression.legacy_path = profile_path + ".legacy.cfg"
	game.progression.date_override = QA_DATE
	root.add_child(game)
	await _frames(9)
	return _check(game.phase == "menu", "game starts at the title with a disposable profile")


func _test_hangar() -> void:
	var player = game.progression
	var start := _profile()
	var reward: Dictionary = player.credit_mission(_completed_mission(), "peryhelium")
	var credited := _profile()
	_check(reward.ok and credited.coins == start.coins + reward.coins and credited.materials == start.materials + reward.materials and credited.crates == start.crates + reward.crates, "mission credits coins, materials and crates together")
	_check(credited.wins == 1 and "aegis" in credited.unlocked_ships and "umbra" in credited.unlocked_sectors, "first victory unlocks Aegis and Umbra")
	player._rng.seed = 197_747
	if not await _click("HangarButton"):
		return
	_check(game.phase == "hangar", "title Hangar button opens the hangar")
	await _click_scrolled("ShipButton_aegis")
	_check(_profile().ship_id == "aegis", "hangar selects the unlocked hull")
	await _capture_page("hangar")
	await _click("HangarTabRewards")
	await _test_rewards()
	await _click("HangarTabInventory")
	await _test_equipment()
	await _capture_page("ekwipunek")
	await _click("HangarTabOverview")
	await _click_scrolled("WorkshopButton")
	await _test_upgrades()
	await _capture_page("ulepszenia")
	await _click("HangarTabSectors")
	await _click_scrolled("SelectSector_umbra")
	_check(_profile().sector_id == "umbra", "sector button selects the newly unlocked route")
	await _click("HangarBackButton")
	_check(game.phase == "menu", "hangar back button returns to the title")
	game.queue_free()
	await _frames(3)
	if not await _open_game():
		return
	var restored := _profile()
	_check(restored.ship_id == "aegis" and restored.sector_id == "umbra", "fresh main scene restores the ship and route")
	var restored_items: Dictionary = restored.equipped.get("aegis", {})
	var restored_levels: Dictionary = restored.levels.get("aegis", {})
	_check(restored_items.get("weapon") == "pulse_coil" and restored_items.get("engine") == "trim_nozzle", "fresh main scene restores installed equipment")
	_check(restored_levels.get("hull") == 1 and restored_levels.get("drive") == 1 and restored_levels.get("output") == 1, "fresh main scene restores all permanent upgrade levels")
	_check(restored.calendar_day == 1 and "fly" in restored.daily.claimed and "first_sortie" in restored.achievements, "fresh main scene restores claimed rewards")
	await _click("HangarButton")
	if await _click("HangarLaunchButton") and _check(game.phase == "combat" and is_instance_valid(game.arena), "hangar launches a sortie through the arena"):
		await _test_applied_sortie()
		await _test_result_reward()


func _test_rewards() -> void:
	var player = game.progression
	var before := _profile()
	await _click_scrolled("OpenCrate")
	var after := _profile()
	var loot := str(player.snapshot().loot)
	_check(Catalog.ITEMS.has(loot) and after.crates == before.crates - 1, "opening a crate consumes it and reveals a catalog item")
	_check(loot in after.inventory and (after.inventory.size() == before.inventory.size() + 1 or after.materials > before.materials), "crate awards new gear or compensates for a duplicate")
	await _click_scrolled("ClaimCalendar_1")
	await _click_scrolled("ClaimDaily_fly")
	await _click_scrolled("ClaimAchievement_first_sortie")
	var claimed := _profile()
	_check(claimed.calendar_day == 1 and "fly" in claimed.daily.claimed and "first_sortie" in claimed.achievements, "calendar, daily and achievement buttons claim their rewards")
	_check(claimed.coins == after.coins + 510 and claimed.materials == after.materials + 80, "claim buttons credit the exact three configured prices")
	_check(not player.apply("claim_calendar", "1").ok and not player.apply("claim_daily", "fly").ok and not player.apply("claim_achievement", "first_sortie").ok, "each reward can be claimed only once in its applicable period")
	_check(_profile().coins == claimed.coins and _profile().materials == claimed.materials, "repeat reward requests cannot credit more funds")


func _test_equipment() -> void:
	await _click_scrolled("Equip_pulse_coil")
	_check(_equipment().get("weapon") == "pulse_coil", "inventory button equips a weapon in its mapped slot")
	await _click_scrolled("Unequip_weapon")
	_check(not _equipment().has("weapon"), "remove button clears the equipped weapon slot")
	await _click_scrolled("Equip_pulse_coil")
	await _click_scrolled("Equip_titanium_plate")
	await _click_scrolled("Equip_trim_nozzle")
	await _click_scrolled("Equip_escort_bay")
	var equipment := _equipment()
	_check(equipment.get("weapon") == "pulse_coil" and equipment.get("armor") == "titanium_plate" and equipment.get("engine") == "trim_nozzle" and equipment.get("drone") == "escort_bay", "equipped modules are stored in their own slots")


func _test_upgrades() -> void:
	for track in Progression.TRACKS:
		var before := _profile()
		var price: Dictionary = game.progression.snapshot().upgrade_prices[track]
		await _click_scrolled("Upgrade%sButton" % track.capitalize())
		var after := _profile()
		var levels: Dictionary = after.levels.get("aegis", {})
		_check(levels.get(track, 0) == int(price.level) + 1 and after.coins == before.coins - price.coins and after.materials == before.materials - price.materials, "%s upgrade charges the displayed price and increases the level" % track)
	var stats: Dictionary = game.progression.sortie().stats
	_check(is_equal_approx(float(stats.max_hp), 154.0) and is_equal_approx(float(stats.speed_multiplier), 1.03) and is_equal_approx(float(stats.weapon_damage_multiplier), 1.17), "ship, equipment and workshop upgrades combine into the expected sortie stats")


func _test_applied_sortie() -> void:
	var sortie: Dictionary = game.progression.sortie()
	_check(game.arena._ship_id == sortie.ship_id, "arena uses the selected spacecraft")
	_check(game.arena._sector_id == sortie.sector_id, "arena uses the selected combat sector")
	_check(is_equal_approx(float(game.arena._max_hp), float(sortie.stats.max_hp)), "arena HP uses the permanent profile stats")
	_check(is_equal_approx(float(game.arena._stats.weapon_damage_multiplier), float(sortie.stats.weapon_damage_multiplier)), "arena receives equipped weapon and permanent output bonus")
	_check(game.arena._loadout.rank("drones") == 1, "equipped drone module starts active in the sortie")
	_check(game.arena._player_texture.resource_path == Catalog.SHIPS.aegis.sprite, "arena uses the selected hull sprite")
	_check(game.arena._director.miniboss_at() == 196.0 and game.arena._director.boss_at() == 455.0, "Umbra activates its own boss schedule")

	var damage_seen := false
	for step in 95:
		for shot in game.arena._shots:
			if shot.kind == game.arena.ShotKind.PULSE:
				var expected_damage := float(game.arena.PULSE.damage) * float(sortie.stats.weapon_damage_multiplier)
				damage_seen = is_equal_approx(shot.damage, expected_damage)
		if damage_seen:
			break
		await physics_frame
	_check(damage_seen, "live auto-fire uses the upgraded weapon damage")

	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await _steps(32)
	var velocity: float = game.arena._player_velocity.length()
	key = key.duplicate() as InputEventKey
	key.pressed = false
	Input.parse_input_event(key)
	await _steps(2)
	var expected_speed := float(game.arena.CRUISE_SPEED) * float(sortie.stats.speed_multiplier)
	_check(absf(velocity - expected_speed) < 0.5, "actual keyboard flight uses the configured engine speed")


func _test_result_reward() -> void:
	var initial := _profile()
	var result := _completed_mission()
	result.sector_id = "umbra"
	game.arena.mission_ended.emit(result)
	await _frames(6)
	_check(game.phase == "result" and _visible_control("RewardRow") != null, "arena result is routed to the reward view")
	var credited := _profile()
	_check(credited.wins == initial.wins + 1 and credited.materials == initial.materials + result.reward and credited.crates == initial.crates + 1 and credited.coins > initial.coins, "result callback persists mission earnings")
	game.arena.mission_ended.emit(result)
	_check(_profile().wins == credited.wins and _profile().coins == credited.coins, "repeated mission result cannot credit another reward")
	await _click("ResultHangarButton")
	_check(game.phase == "hangar", "mission result opens the hangar directly")


func _test_storage() -> void:
	var storage := _new_profile("storage")
	storage.load_profile()
	var starter: int = storage.snapshot().profile.materials
	var legacy := ConfigFile.new()
	legacy.set_value("pilot", "salvage", 347)
	_check(legacy.save(storage.legacy_path) == OK, "legacy fixture writes old ConfigFile")
	storage.load_profile()
	_check(storage.snapshot().profile.materials == starter + 347, "legacy salvage migrates to materials")
	storage.load_profile()
	_check(storage.snapshot().profile.materials == starter + 347, "legacy migration is applied once")
	_check(storage.apply("equip", "pulse_coil").ok and storage.apply("upgrade", "hull").ok, "two transactions create alternating save revisions")

	var latest := _new_profile("storage")
	latest.load_profile()
	_check(latest.snapshot().profile.levels.peregrine.hull == 1, "latest intact save restores the new level")
	var newest_slot := "%s.%d.json" % [latest.save_path, latest._revision % 2]
	var corrupt := FileAccess.open(newest_slot, FileAccess.WRITE)
	if not _check(corrupt != null, "can corrupt the disposable fixture slot"):
		return
	corrupt.store_string('{"payload":"truncated"}')
	corrupt.close()
	latest.load_profile()
	var recovered: Dictionary = latest.snapshot().profile
	_check(recovered.equipped.peregrine.weapon == "pulse_coil" and recovered.levels.peregrine.hull == 0 and recovered.materials == starter + 347, "damaged latest slot recovers the previous valid transaction")
	_check(latest.apply("upgrade", "hull").ok, "profile accepts writes after recovery")
	var future_slot := "%s.%d.json" % [latest.save_path, (latest._revision + 1) % 2]
	var future := FileAccess.open(future_slot, FileAccess.WRITE)
	if not _check(future != null, "future-version fixture opens"):
		return
	var payload := JSON.stringify({"version": 99, "revision": latest._revision + 1, "data": {}})
	future.store_string(JSON.stringify({"payload": payload, "sha256": payload.sha256_text()}))
	future.close()
	latest.load_profile()
	_check(not latest.apply("upgrade", "hull").ok and latest.snapshot().profile.levels.peregrine.hull == 1,
		"newer schema preserves the older valid profile and prevents writes")

	var blocked := _new_profile("write")
	blocked.save_path += "/missing-directory/flight_progress"
	blocked.load_profile()
	var before: Dictionary = blocked.snapshot().profile
	_check(not blocked.apply("upgrade", "hull").ok, "unwritable destination rejects the purchase")
	_check(before == blocked.snapshot().profile, "failed save does not deduct funds or apply an upgrade")


func _test_unlocks() -> void:
	var pilot := _new_profile("unlocks")
	pilot.load_profile()
	var starting: Dictionary = pilot.snapshot().profile
	_check(starting.unlocked_ships == ["peregrine"] and starting.unlocked_sectors == ["peryhelium"], "fresh pilots start with one unlocked hull and route")
	_check(not pilot.apply("select_ship", "aegis").ok and not pilot.apply("select_sector", "umbra").ok and not pilot.apply("equip", "starbreaker").ok, "locked hulls, routes and unowned equipment are rejected")
	_check(not pilot.apply("claim_daily", "fly").ok and not pilot.apply("claim_calendar", "2").ok, "incomplete daily and future calendar rewards are rejected")
	for win in 7:
		var route := "peryhelium" if win < 3 else ("umbra" if win < 6 else "zenith")
		var reward := pilot.credit_mission(_completed_mission(), route)
		if not _check(reward.ok, "test victory %d is saved" % (win + 1)):
			return
		var profile: Dictionary = pilot.snapshot().profile
		if win == 2:
			_check("specter" in profile.unlocked_ships and not "zenith" in profile.unlocked_sectors, "third win unlocks Specter before Zenith")
		elif win == 3:
			_check("zenith" in profile.unlocked_sectors and not "aurora" in profile.unlocked_ships, "fourth win unlocks Zenith before Aurora")
	_check(pilot.snapshot().profile.unlocked_ships.size() == 4 and pilot.snapshot().profile.unlocked_sectors.size() == 3, "seventh win unlocks all hulls and sectors")
	_check(pilot.apply("select_ship", "aurora").ok and pilot.sortie().stats.drone_rank == 1,
		"newly unlocked Aurora can sortie with its built-in drones")
	_check(pilot.apply("claim_calendar", "1").ok, "first calendar reward is available today")
	pilot.date_override = "2026-05-15"
	_check(not pilot.apply("claim_daily", "fly").ok and pilot.apply("claim_calendar", "2").ok, "new date resets daily progress and advances the calendar")
	pilot.date_override = "2026-05-13"
	_check(not pilot.apply("claim_calendar", "3").ok, "moving the clock backwards cannot advance the calendar")
	for day in range(3, 8):
		pilot.date_override = "2026-05-%02d" % (13 + day)
		_check(pilot.apply("claim_calendar", str(day)).ok, "calendar pays day %d" % day)
	pilot.date_override = "2026-05-21"
	_check(not pilot.apply("claim_calendar", "8").ok, "calendar completes after seven rewards")


func _new_profile(name: String) -> Progression:
	var player := Progression.new()
	player.save_path = "%s-%s" % [profile_path, name]
	player.legacy_path = player.save_path + ".legacy.cfg"
	player.date_override = QA_DATE
	return player


func _profile() -> Dictionary:
	return game.progression.snapshot().profile


func _equipment() -> Dictionary:
	return _profile().equipped.get("aegis", {})


func _completed_mission() -> Dictionary:
	return {"won": true, "seconds": 600.0, "kills": 204, "level": 14, "reward": 122, "boss_defeated": true}


func _click_scrolled(button_name: String) -> bool:
	await _frames(3)
	var button := _button(button_name)
	if not _check(button != null, "%s is available in the scroll view" % button_name):
		return false
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await _frames(2)
		ancestor = ancestor.get_parent()
	return await _click(button_name)


func _capture_page(label: String) -> bool:
	if capture_dir.is_empty():
		return true
	var hangar: Control = game.find_child("Hangar", true, false)
	if hangar != null:
		for scroll in hangar.find_children("*", "ScrollContainer", true, false):
			scroll.scroll_vertical = 0
	await _frames(4)
	await RenderingServer.frame_post_draw
	var frame := root.get_texture().get_image()
	if not _check(frame != null and not frame.is_empty(), "Godot rendered %s" % label):
		return false
	if not _check(frame.get_size() == expected_size, "%s raster is exactly %s" % [label, expected_size]):
		return false
	var path := capture_dir.path_join("%dx%d-%s.png" % [expected_size.x, expected_size.y, label])
	return _check(frame.save_png(path) == OK, "saved native game frame: %s" % path)
