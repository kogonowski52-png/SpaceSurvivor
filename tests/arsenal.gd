extends SceneTree

const Arena := preload("res://combat/arena.gd")
const Arsenal := preload("res://combat/arsenal.gd")
const Loadout := preload("res://combat/flight_loadout.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_cards()
	_test_pulse()
	_test_missiles()
	_test_laser()
	_test_plasma()
	_test_tesla()
	_test_drones()
	print("Arsenal QA: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)


func _check(passed: bool, label: String) -> void:
	if passed:
		print("PASS: " + label)
	else:
		_failures += 1
		push_error("FAIL: " + label)


func _arena() -> Arena:
	var arena := Arena.new()
	root.add_child(arena)
	arena.set_physics_process(false)
	arena._enemies.clear()
	arena._shots.clear()
	return arena


func _enemy(arena: Arena, position: Vector2) -> RefCounted:
	arena._spawn_enemy(Arena.EnemyKind.SCOUT, position)
	var enemy: RefCounted = arena._enemies.back()
	enemy.hp = 500.0
	enemy.max_hp = enemy.hp
	return enemy


func _test_cards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4821
	var loadout := Loadout.new()
	_check(Loadout.UPGRADES.size() == 12 and Loadout.WEAPONS.size() == 6, "catalog has exactly twelve cards for six weapons")
	_check(not loadout.increment("pulse_crossfire") and not loadout.increment("unknown"), "locked and unknown IDs cannot modify the loadout")
	var first := loadout.cards(rng, 2)
	_check(first[0].id != "pulse_damage" and first[0].id in Loadout.WEAPONS, "first promotion guarantees an offer to unlock a new weapon")
	var distinct := {}
	for card in loadout.cards(rng, 5):
		distinct[card.id] = true
	_check(distinct.size() == 3, "promotion offers three distinct eligible cards")
	var rarities := {}
	for id: String in Loadout.UPGRADES:
		rarities[Loadout.UPGRADES[id].rarity] = true
	_check(rarities.size() == 4 and not first[0].icon.is_empty() and rarities.has(first[0].rarity),
		"catalog covers four rarities and offered cards include rarity and icon metadata")
	for id: String in Loadout.WEAPONS:
		while loadout.increment(id):
			pass
	for id: String in ["pulse_crossfire", "missile_cluster", "tesla_branch"]:
		_check(loadout.increment(id) and not loadout.increment(id), id + " unlocks at rank three and can be selected once")
	var fallback := {}
	for card in loadout.cards(rng, 999):
		fallback[card.id] = true
	_check(fallback.size() == 3 and fallback.has("repair") and fallback.has("tractor") and fallback.has("shield"),
		"three utility cards remain available after fully upgrading and evolving every weapon")


func _test_pulse() -> void:
	var arena := _arena()
	var arsenal := Arsenal.new()
	_enemy(arena, Vector2(180.0, 0.0))
	arsenal.step(arena, 0.01)
	_check(arena._shots.size() == 2 and arena._shots[0].damage == float(arena.PULSE.damage), "starter pulse cannon automatically launches paired shots")
	for index in 3:
		arena._loadout.increment("pulse_damage")
	arena._loadout.increment("pulse_crossfire")
	arsenal.step(arena, 0.6)
	_check(arena._shots.size() == 6 and arena._shots[-1].damage > arena._shots[0].damage, "pulse ranks raise damage and projectile count")
	arsenal.step(arena, 0.6)
	_check(arena._shots.size() == 14, "crossfire adds four directional shots on the third volley")
	_check(arena._shots[10].velocity.dot(arena._shots[11].velocity) < 2000.0, "crossfire projectiles follow different bearings")
	arena.free()


func _test_missiles() -> void:
	var arena := _arena()
	var arsenal := Arsenal.new()
	var enemy := _enemy(arena, Vector2(140.0, 0.0))
	for index in 3:
		arena._loadout.increment("missiles")
	arena._loadout.increment("missile_cluster")
	arsenal.step(arena, 0.01)
	_check(arena._shots.size() == 3 and arena._shots[-1].kind == Arena.ShotKind.MISSILE and arena._shots[-1].target == enemy,
		"homing missile tracks an assigned target")
	arena._shots.clear()
	arena._launch_shot(Arena.ShotKind.MISSILE, Vector2(105.0, 0.0), Vector2.RIGHT * 468.0, 53.0, 1.8, enemy)
	for tick in 6:
		arena._step_shots(1.0 / 60.0)
		if arena._shots.size() != 1:
			break
	_check(arena._shots.size() == 5 and arena._shots[0].kind == Arena.ShotKind.SHARD and enemy.hp < 500.0,
		"missile collision deals area damage and creates five evolved shards")
	arena.free()


func _test_laser() -> void:
	var arena := _arena()
	var arsenal := Arsenal.new()
	var front := _enemy(arena, Vector2(140.0, 0.0))
	var rear := _enemy(arena, Vector2(270.0, 0.0))
	var off_axis := _enemy(arena, Vector2(230.0, 100.0))
	arena._loadout.increment("laser")
	arsenal.step(arena, 0.01)
	_check(front.hp < 500.0 and rear.hp < 500.0 and off_axis.hp == 500.0,
		"laser beam pierces two aligned enemies and misses an enemy outside its path")
	var hp: float = front.hp
	arsenal.step(arena, 0.17)
	_check(front.hp < hp and arsenal._laser_remaining > 0.0, "active laser repeatedly damages targets on subsequent physics ticks")
	arena.free()


func _test_plasma() -> void:
	var arena := _arena()
	var arsenal := Arsenal.new()
	var orbit := _enemy(arena, Vector2(93.0, 0.0))
	var outside := _enemy(arena, Vector2(250.0, 60.0))
	arena._loadout.increment("nova")
	arsenal.step(arena, 0.01)
	_check(orbit.hp < 500.0 and outside.hp == 500.0, "plasma orbital deals contact damage on its path")
	var angle := arsenal._orbital_angle
	arsenal.step(arena, 0.08)
	_check(arsenal._orbital_angle > angle, "plasma charges rotate around the ship")
	arena.free()


func _test_tesla() -> void:
	var arena := _arena()
	var arsenal := Arsenal.new()
	var targets: Array[RefCounted] = []
	for index in 6:
		targets.append(_enemy(arena, Vector2(140.0, index * 17.0)))
	for index in 3:
		arena._loadout.increment("tesla")
	arsenal.step(arena, 0.01)
	_check(arsenal._traces.size() == 4 and targets[-1].hp == 500.0,
		"rank three Tesla arcs between four unique targets with decay")
	arena._loadout.increment("tesla_branch")
	arsenal.step(arena, 3.0)
	_check(arsenal._traces.size() == 6 and targets[-1].hp < 500.0,
		"Tesla branch evolution strikes two extra targets from the first impact")
	arena.free()


func _test_drones() -> void:
	var arena := _arena()
	var arsenal := Arsenal.new()
	var enemy := _enemy(arena, Vector2(165.0, 0.0))
	arena._loadout.increment("drones")
	arsenal.step(arena, 0.01)
	_check(enemy.hp < 500.0 and not arsenal._traces.is_empty() and arsenal._drone_count(1) == 2,
		"two escort drones orbit the player and independently fire at nearby enemies")
	arena.free()
