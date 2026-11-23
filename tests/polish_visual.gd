extends "res://tests/audit_visual.gd"
## One capture scenario runs against both the 0.7.0 checkout and the revised game.

const POLISH_SEED := 74218


func _run() -> void:
	if capture_dir.is_empty() or DisplayServer.get_name() == "headless" or not await _open_game():
		printerr("Provide a native display, --capture-dir and --expect-size.")
		quit(1)
		return
	await _capture_hangar_and_rewards()
	await _capture_store()
	await _capture_flight()
	print("QA polish captures: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _capture_hangar_and_rewards() -> void:
	var pilot = game.progression
	await _click("HangarButton")
	await _audit_capture("01-peregrine-zablokowana-flota")
	for index in 7:
		_check(pilot.credit_mission(_completed_mission(), "peryhelium").ok, "seed a victory through the regular progression service")
	for id in ["pulse_coil", "titanium_plate", "trim_nozzle", "flux_cell", "escort_bay"]:
		_check(pilot.apply("equip", id).ok, "install " + id + " on Peregrine")
	await _click("HangarBackButton")
	await _click("HangarButton")
	for id in ["aegis", "specter", "aurora"]:
		await _click_scrolled("ShipButton_" + id)
		_check(_profile().ship_id == id, "display the selected " + id + " hull")
		await _audit_capture("02-" + id)
	await _click_scrolled("ShipButton_peregrine")
	await _click("HangarTabInventory")
	await _audit_capture("03-ekwipunek")
	await _click("HangarTabOverview")
	await _click_scrolled("WorkshopButton")
	var level_before: int = _profile().levels.get("peregrine", {}).get("hull", 0)
	await _click_scrolled("UpgradeHullButton")
	_check(_profile().levels.peregrine.hull == level_before + 1, "buy a permanent upgrade using the actual button")
	await _capture_page("04-ulepszenie")
	await _click("HangarTabRewards")
	await _audit_capture("05-kalendarz")
	for tier in ["epic", "legendary"]:
		# Preview candidate RNG seeds against an unchanged copy, then open the real crate once.
		var seed_value := _crate_seed(tier)
		if not _check(seed_value >= 0, "select a reproducible " + tier + " crate"):
			continue
		pilot._rng.seed = seed_value
		await _click_scrolled("OpenCrate")
		var id: String = pilot.snapshot().loot
		_check(Catalog.ITEMS.get(id, {}).get("rarity") == tier, "actual crate grants the desired tier")
		await _audit_capture("06-skrzynia-" + tier)
	await _click("HangarBackButton")


func _crate_seed(tier: String) -> int:
	var candidate: Dictionary = _profile()
	for offset in 1000:
		var value := POLISH_SEED + offset
		game.progression._rng.seed = value
		var id: String = game.progression._roll_crate(candidate)
		if Catalog.ITEMS[id].rarity == tier:
			return value
	return -1


func _capture_store() -> void:
	if not await _click("StoreButton") or not await _click("StoreTab_crystals"):
		return
	await _audit_capture("07-crystals-portfel")
	var scroll := _visible_control("StoreScroll") as ScrollContainer
	for id in ["crystals_100", "crystals_350", "crystals_900"]:
		var card := _visible_control("Product_" + id)
		if _check(card != null, "store displays " + id):
			scroll.ensure_control_visible(card)
			await _capture_page("08-" + id)
	await _click("StoreBackButton")


func _capture_flight() -> void:
	for sector in ["peryhelium", "umbra", "zenith"]:
		game.progression.apply("select_sector", sector)
		if not await _click("LaunchButton"):
			return
		var arena: Node2D = game.arena
		arena.set_physics_process(false)
		arena._rng.seed = POLISH_SEED
		arena._fx._rng.seed = POLISH_SEED
		arena._mission_time = 119.3
		if sector == "zenith":
			arena._camera = Vector2(640.0, 975.0)
			arena._player_position = arena._camera
		_combat_pose(arena)
		arena._publish_telemetry()
		arena.queue_redraw()
		await _audit_capture("09-sylwetki-" + sector)
		if sector == "peryhelium":
			await _capture_leviathan(arena)
		await _click("PauseButton")
		await _click("MenuButton")


func _combat_pose(arena: Node2D) -> void:
	var origin: Vector2 = arena._player_position
	for offset in [Vector2(-140, -154), Vector2(-145, 147)]:
		arena._spawn_enemy(arena.EnemyKind.SCOUT, origin + offset)
	for offset in [Vector2(0, -181), Vector2(5, 157)]:
		arena._spawn_enemy(arena.EnemyKind.RAZOR, origin + offset)
	for offset in [Vector2(143, -156), Vector2(136, 148)]:
		arena._spawn_enemy(arena.EnemyKind.ELITE, origin + offset)
	for index in arena._enemies.size():
		arena._enemies[index].heading = -PI * 0.5 + (0.37 if index % 2 else -0.17)


func _capture_leviathan(arena: Node2D) -> void:
	var origin: Vector2 = arena._player_position
	arena._mission_time = 493.1
	arena._director._miniboss_spawned = true
	arena._director._boss_spawned = true
	arena._spawn_enemy(arena.EnemyKind.BOSS, origin + Vector2(58, -228))
	var boss: RefCounted = arena._enemies.back()
	boss.heading = -PI * 0.5
	boss.charge = 0.48
	boss.pattern = 0
	boss.aim = boss.position.direction_to(origin)
	boss.attack_origin = boss.position
	for index in 17:
		var direction := Vector2.from_angle(float(index) / 17.0 * TAU)
		arena._launch_shot(arena.ShotKind.HOSTILE, origin + direction * (38.0 + float(index % 5) * 12.0), direction * -240.0, 12.0, 2.0)
	for index in 12:
		var direction := Vector2.from_angle(float(index) / 12.0 * TAU + 0.21)
		arena._launch_shot(arena.ShotKind.PULSE, origin + direction * 42.0, direction * 500.0, 10.0, 2.0)
	arena._fx.ring(origin + Vector2(-34, -23), Color("#d194ff"), 106.0, 0.62)
	arena._fx.burst(origin + Vector2(30, -26), Color("#ff9a73"), 37, 225.0)
	arena._fx.step(0.22)
	arena._loadout.increment("laser")
	arena._arsenal._laser_heading = origin.angle_to_point(boss.position)
	arena._arsenal._laser_remaining = 0.82
	arena._arsenal._step_laser(arena, 0.01, 1)
	arena._publish_telemetry()
	arena.queue_redraw()
	await _audit_capture("10-leviathan-laser")
	arena._damage_enemy(arena._enemies.find(boss), boss.hp + 1.0, Vector2.UP)
	arena._fx.step(0.18)
	arena._publish_telemetry()
	arena.queue_redraw()
	await _audit_capture("11-leviathan-eksplozja")
