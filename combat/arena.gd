class_name StrikeArena
extends Node2D

signal telemetry(data: Dictionary)
signal upgrade_requested(cards: Array[Dictionary])
signal mission_ended(result: Dictionary)
signal sound_requested(event: String)
signal revive_offered

const FlightLoadout := preload("res://combat/flight_loadout.gd")
const EffectLibrary := preload("res://combat/battle_fx.gd")
const MISSION := preload("res://data/missions/peryhelium.tres")
const HULL := preload("res://data/hangar/peregrine.tres")
const PULSE = HULL.primary_weapon
const Arsenal := preload("res://combat/arsenal.gd")
const WaveDirector := preload("res://combat/wave_director.gd")
const Catalog := preload("res://data/progression_catalog.gd")
const StoreCatalog := preload("res://data/store/commerce_catalog.gd")
const ARENA := Rect2(-1240.0, -1540.0, 2480.0, 3080.0)
const PLAYER_RADIUS := 21.0
const CRUISE_SPEED := 238.0
const PROMOTION_REPAIR := 10.0
const MAX_ENEMIES := 62
const MAX_SHOTS := 184
const MAX_FRIENDLY_SHOTS := 126
const MINE_RADIUS := 54.0
const MAX_ORBS := 96
const LAST_HIT_AUDIO_INTERVAL := 0.085
const SHIP_HIT_LIFETIME := 0.14
const HULL_HIT_LIFETIME := 0.33
const STAR_TILE_EXTENT := Vector2i(640, 1080)
const CYAN := Color("#65e9ff")
const VIOLET := Color("#b995ff")
const WARM := Color("#ff725c")
const WHITE_HOT := Color("#e7fcff")
const SHIP_ART: Array[String] = [
	"res://assets/art/enemy_scout.png",
	"res://assets/art/enemy_lancer.png",
	"res://assets/art/enemy_bastion.png",
	"res://assets/art/enemy_razor.png",
	"res://assets/art/enemy_mine.png",
	"res://assets/art/enemy_elite.png",
	"res://assets/art/miniboss.png",
	"res://assets/art/boss.png"
]
const SHIP_TINTS: Array[Color] = [
	Color("#ffb164"), Color("#ca97ff"), Color("#fa7367"), Color("#64e9ca"),
	Color("#ecc571"), Color("#ee91c5"), Color("#ffb580"), Color("#c2a4ff"),
]
const SHIP_BOUNDS: Array[float] = [62.0, 71.0, 96.0, 58.0, 89.0, 99.0, 153.0, 222.0]

enum EnemyKind { SCOUT, LANCER, BASTION, RAZOR, MINELAYER, ELITE, MINIBOSS, BOSS }
enum ShotKind { PULSE, MISSILE, HOSTILE, MINE, SHARD }

class Enemy:
	var kind: int
	var position: Vector2
	var heading: float
	var hp: float
	var max_hp: float
	var speed: float
	var radius: float
	var action_timer: float
	var phase: float
	var hit_flash: float
	var xp: int
	var contact_damage: float
	var pattern: int
	var charge: float
	var afterglow: float
	var aim: Vector2
	var attack_origin: Vector2
	var attack_target: Vector2

class Shot:
	var kind: int
	var position: Vector2
	var velocity: Vector2
	var damage: float
	var life: float
	var target: Enemy

class Orb:
	var position: Vector2
	var velocity: Vector2
	var value: int
	var phase: float

var _loadout := FlightLoadout.new()
var _fx := EffectLibrary.new()
var _director := WaveDirector.new()
var _arsenal := Arsenal.new()
var _rng := RandomNumberGenerator.new()
var _duration := float(MISSION.duration_seconds)
var _ship_id := "peregrine"
var _sector_id := "peryhelium"
var _ship: Dictionary = Catalog.SHIPS[_ship_id]
var _sector: Dictionary = Catalog.SECTORS[_sector_id]
var _stats := Catalog.build_stats(_ship_id, {}, {})
var _enemies: Array[Enemy] = []
var _shots: Array[Shot] = []
var _xp_orbs: Array[Orb] = []
var _enemy_pool: Array[Enemy] = []
var _shot_pool: Array[Shot] = []
var _friendly_shots := 0
var _mine_count := 0
var _recovered := 0
var _orb_pool: Array[Orb] = []
var _pending_cards: Array[Dictionary] = []
var _textures: Array[Texture2D] = []
var _enemy_frames: Array[Rect2] = []
var _player_texture: Texture2D
var _nebula_texture: Texture2D
var _distant_star_tile: Texture2D
var _near_stars := PackedVector2Array()
var _camera := Vector2.ZERO
var _player_position := Vector2.ZERO
var _player_velocity := Vector2.ZERO
var _player_heading := -PI * 0.5
var _steer_offset := Vector2.ZERO
var _pointer_position := Vector2.ZERO
var _touch_index := -1
var _mouse_drag := false
var _hp := 100.0
var _max_hp := 100.0
var _xp := 0
var _xp_fraction := 0.0
var _xp_goal := 12
var _level := 1
var _kills := 0
var _mission_time := 0.0
var _spawn_timer := 0.7
var _engine_timer := 0.0
var _report_timer := 0.0
var _hit_cooldown := 0.0
var _hull_flash := 0.0
var _last_hit_audio := -LAST_HIT_AUDIO_INTERVAL
var _last_boss_down := ""
var _boss_down_until := 0.0
var _firing_flash := 0.0
var _suspended := false
var _ended := false
var revive_offer_enabled := false
var _revive_pending := false
var _revive_spent := false
var _livery := Color.WHITE
var _livery_accent := Color.TRANSPARENT


func configure(sortie: Dictionary) -> void:
	if is_inside_tree():
		return
	var wanted_ship := String(sortie.get("ship_id", "peregrine"))
	var wanted_sector := String(sortie.get("sector_id", "peryhelium"))
	_ship_id = wanted_ship if Catalog.SHIPS.has(wanted_ship) else "peregrine"
	_sector_id = wanted_sector if Catalog.SECTORS.has(wanted_sector) else "peryhelium"
	_ship = Catalog.SHIPS[_ship_id]
	var livery: Dictionary = StoreCatalog.SKINS.get(String(sortie.get("skin_id", "")), {})
	if livery.get("ship") == _ship_id:
		_livery = livery.tint
		_livery_accent = livery.accent
	_sector = Catalog.SECTORS[_sector_id]
	_stats = Catalog.build_stats(_ship_id, {}, {})
	var derived: Dictionary = sortie.get("stats", {})
	for metric: String in _stats:
		var supplied: Variant = derived.get(metric)
		if typeof(supplied) == TYPE_INT or typeof(supplied) == TYPE_FLOAT:
			_stats[metric] = supplied
	_duration = float(_sector["duration"])
	_director.configure(_sector_id)


func _ready() -> void:
	_rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_fx.prepare()
	get_viewport().size_changed.connect(queue_redraw)
	_player_texture = HULL.sprite if _ship_id == "peregrine" else _texture(_ship["sprite"])
	if _player_texture == null:
		_player_texture = HULL.sprite
	_max_hp = float(_stats["max_hp"])
	_hp = _max_hp
	for index in int(_stats["drone_rank"]):
		_loadout.increment("drones")
	_nebula_texture = _texture("res://assets/art/arena_nebula.jpg")
	for kind in SHIP_ART.size():
		var texture := _texture(SHIP_ART[kind])
		_textures.append(texture)
		var size := _ship_size(texture, SHIP_BOUNDS[kind]) if texture != null else Vector2.ZERO
		_enemy_frames.append(Rect2(-size * 0.5, size))
	_seed_sky()
	_spawn_enemy(EnemyKind.SCOUT, Vector2(-230.0, -250.0))
	var starting_escort := EnemyKind.SCOUT
	match _sector_id:
		"umbra":
			starting_escort = EnemyKind.RAZOR
		"zenith":
			starting_escort = EnemyKind.BASTION
	_spawn_enemy(starting_escort, Vector2(235.0, 239.0))
	_publish_telemetry()


func set_suspended(suspended: bool) -> void:
	_suspended = suspended
	_clear_pointer()


func can_revive() -> bool:
	return _revive_pending and not _ended


func revive() -> bool:
	if not can_revive():
		return false
	_revive_pending = false
	_revive_spent = true
	_hp = _max_hp * 0.5
	_hit_cooldown = 1.55
	_hull_flash = 0.0
	set_suspended(false)
	_fx.ring(_player_position, CYAN, 102.0, 0.55)
	sound_requested.emit("upgrade")
	_publish_telemetry()
	return true


func decline_revive() -> void:
	if can_revive():
		_revive_pending = false
		_finish(false)


func apply_upgrade(id: String) -> bool:
	if _ended:
		return false
	for card in _pending_cards:
		if id != String(card["id"]):
			continue
		if not _loadout.increment(id):
			return false
		if id == "repair":
			_max_hp += 15.0
			_hp += 30.0
		_hp = minf(_max_hp, _hp + PROMOTION_REPAIR)
		_pending_cards.clear()
		_fx.ring(_player_position, CYAN, 97.0, 0.55)
		_fx.burst(_player_position, CYAN, 18, 170.0)
		sound_requested.emit("upgrade")
		_publish_telemetry()
		return true
	return false


func _texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	push_warning("Brak zasobu areny: " + path)
	return null


func _clear_pointer() -> void:
	_touch_index = -1
	_mouse_drag = false
	_steer_offset = Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_clear_pointer()


func _input(event: InputEvent) -> void:
	# Release is observed even if the pointer ends over a HUD button.
	if event is InputEventScreenTouch and not event.pressed and event.index == _touch_index:
		_touch_index = -1
		_steer_offset = Vector2.ZERO
	if event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_mouse_drag = false
		_steer_offset = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if _paused():
		return
	if event is InputEventScreenTouch and event.pressed and _touch_index == -1:
		_touch_index = event.index
		_pointer_position = event.position
		_steer_offset = Vector2.ZERO
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_pointer_position = event.position
		_steer_offset = (_steer_offset + event.relative).limit_length(52.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_mouse_drag = true
		_pointer_position = event.position
		_steer_offset = Vector2.ZERO
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _mouse_drag:
		_pointer_position = event.position
		_steer_offset = (_steer_offset + event.relative).limit_length(52.0)
		get_viewport().set_input_as_handled()


func _paused() -> bool:
	return _ended or _revive_pending or _suspended or not _pending_cards.is_empty()


func _physics_process(delta: float) -> void:
	if _paused():
		return
	_mission_time = minf(_duration, _mission_time + delta)
	if _mission_time >= _duration - 0.0001:
		_mission_time = _duration
		_finish(_director._boss_defeated)
		return
	_step_player(delta)
	_director.update(self, delta)
	_step_spawns(delta)
	_step_enemies(delta)
	if _ended or _revive_pending:
		queue_redraw()
		return
	_step_weapons(delta)
	_step_shots(delta)
	if _ended or _revive_pending:
		queue_redraw()
		return
	_step_orbs(delta)
	_fx.step(delta)
	_report_timer -= delta
	if _report_timer <= 0.0:
		_report_timer = 0.12
		_publish_telemetry()
	if _xp >= _xp_goal:
		_offer_level()
	queue_redraw()


func _step_player(delta: float) -> void:
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var max_speed := CRUISE_SPEED * float(_stats["speed_multiplier"]) * _loadout.speed_multiplier()
	var direction := keyboard
	if _touch_index != -1 or _mouse_drag:
		var pull := _steer_offset.length()
		direction = _steer_offset.normalized() * smoothstep(4.0, 52.0, pull)
	_player_velocity = _player_velocity.move_toward(direction * max_speed, delta * 2100.0)
	_player_position = _clamp_to_arena(_player_position + _player_velocity * delta, PLAYER_RADIUS)
	var target := _closest_enemy(450.0)
	if target != null:
		_player_heading = lerp_angle(_player_heading, (target.position - _player_position).angle(), 1.0 - exp(-delta * 13.0))
	elif _player_velocity.length_squared() > 64.0:
		_player_heading = lerp_angle(_player_heading, _player_velocity.angle(), 1.0 - exp(-delta * 8.0))
	_camera = _camera.lerp(_player_position, 1.0 - exp(-delta * 9.0))
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	_hull_flash = maxf(0.0, _hull_flash - delta)
	_firing_flash = maxf(0.0, _firing_flash - delta)
	_engine_timer -= delta
	if _engine_timer <= 0.0:
		_engine_timer = 0.052
		var backward := -Vector2.from_angle(_player_heading)
		var origin := _player_position + backward * 33.0
		var exhaust: Color = Color("#57aaff") if _ship_id == "peregrine" else _ship["accent"]
		_fx.burst(origin, exhaust, 2, 68.0 + _player_velocity.length() * 0.34, backward)


func _clamp_to_arena(position: Vector2, margin: float) -> Vector2:
	var inset := Vector2.ONE * margin
	return position.clamp(ARENA.position + inset, ARENA.end - inset)


func _step_spawns(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var pressure := clampf(_mission_time / _duration, 0.0, 1.0)
	_spawn_timer = lerpf(0.99, 0.54, pressure) * float(_sector["spawn_interval_multiplier"])
	if _enemies.size() >= MAX_ENEMIES - 2:
		return
	_spawn_at_edge(_director.next_kind(_rng))
	if _enemies.size() < MAX_ENEMIES - 2 and _director.wave >= 2 and _rng.randf() < 0.28 + 0.48 * pressure:
		_spawn_at_edge(_director.next_kind(_rng))


func _spawn_at_edge(kind: int) -> void:
	var viewport_half := get_viewport_rect().size * 0.5
	var ray := Vector2.from_angle(_rng.randf_range(0.0, TAU))
	var extent := minf(viewport_half.x / maxf(0.01, absf(ray.x)), viewport_half.y / maxf(0.01, absf(ray.y)))
	var position := _clamp_to_arena(_camera + ray * (extent + 47.0), 28.0)
	# When the player reaches the sector wall, fold pressure in from open space.
	if position.distance_squared_to(_player_position) < 190.0 * 190.0:
		position = _clamp_to_arena(_camera - ray * (extent + 47.0), 28.0)
	_spawn_enemy(kind, position)
	_fx.ring(position, SHIP_TINTS[kind], 42.0, 0.6)


func _spawn_enemy(kind: int, position: Vector2) -> void:
	var enemy: Enemy = Enemy.new() if _enemy_pool.is_empty() else _enemy_pool.pop_back()
	enemy.kind = kind
	enemy.position = position
	enemy.heading = (_player_position - position).angle()
	enemy.phase = _rng.randf_range(0.0, TAU)
	enemy.action_timer = _rng.randf_range(0.65, 1.65)
	enemy.hit_flash = 0.0
	enemy.pattern = -1
	enemy.charge = 0.0
	enemy.afterglow = 0.0
	enemy.aim = Vector2.UP
	enemy.attack_origin = position
	enemy.attack_target = position
	match kind:
		EnemyKind.SCOUT:
			enemy.radius = 19.0
			enemy.max_hp = 21.0
			enemy.speed = 109.0
			enemy.xp = 4
			enemy.contact_damage = 12.0
		EnemyKind.LANCER:
			enemy.radius = 24.0
			enemy.max_hp = 42.0
			enemy.speed = 96.0
			enemy.xp = 7
			enemy.contact_damage = 15.0
		EnemyKind.BASTION:
			enemy.radius = 34.0
			enemy.max_hp = 107.0
			enemy.speed = 63.0
			enemy.xp = 13
			enemy.contact_damage = 24.0
		EnemyKind.RAZOR:
			enemy.radius = 18.0
			enemy.max_hp = 31.0
			enemy.speed = 108.0
			enemy.xp = 8
			enemy.contact_damage = 12.0
		EnemyKind.MINELAYER:
			enemy.radius = 30.0
			enemy.max_hp = 132.0
			enemy.speed = 72.0
			enemy.xp = 15
			enemy.contact_damage = 20.0
		EnemyKind.ELITE:
			enemy.radius = 35.0
			enemy.max_hp = 182.0
			enemy.speed = 122.0
			enemy.xp = 24
			enemy.contact_damage = 23.0
		EnemyKind.MINIBOSS:
			enemy.radius = 55.0
			enemy.max_hp = 1150.0
			enemy.speed = 113.0
			enemy.xp = 116
			enemy.contact_damage = 20.0
			enemy.action_timer = 2.4
		EnemyKind.BOSS:
			enemy.radius = 78.0
			enemy.max_hp = 3650.0
			enemy.speed = 123.0
			enemy.xp = 230
			enemy.contact_damage = 29.0
			enemy.action_timer = 2.6
	if kind < EnemyKind.MINIBOSS:
		enemy.max_hp *= 1.0 + _mission_time / _duration * 0.85
		enemy.speed *= 1.0 + _mission_time / _duration * 0.24
	enemy.max_hp *= float(_sector["enemy_hp_multiplier"])
	enemy.speed *= float(_sector["enemy_speed_multiplier"])
	enemy.hp = enemy.max_hp
	_enemies.append(enemy)


func _step_enemies(delta: float) -> void:
	for index in _enemies.size():
		var enemy := _enemies[index]
		var toward := _player_position - enemy.position
		var distance := toward.length()
		var forward := toward / maxf(1.0, distance)
		var travel := forward
		match enemy.kind:
			EnemyKind.SCOUT:
				travel += Vector2(-forward.y, forward.x) * sin(_mission_time * 4.5 + enemy.phase) * 0.31
			EnemyKind.LANCER:
				travel = _lancer_travel(enemy, forward, distance, delta)
			EnemyKind.RAZOR:
				travel = _razor_travel(enemy, forward, delta)
			EnemyKind.MINELAYER:
				travel = _minelayer_travel(enemy, forward, distance, delta)
			EnemyKind.ELITE:
				travel = _elite_travel(enemy, forward, distance, delta)
			EnemyKind.MINIBOSS, EnemyKind.BOSS:
				travel = _director.boss_travel(self, enemy, forward, distance, delta)
		if _ended or _revive_pending:
			return
		if enemy.kind < EnemyKind.MINIBOSS:
			travel += _separation(index, enemy)
		enemy.position = _clamp_to_arena(enemy.position + travel.limit_length(2.7 if enemy.kind == EnemyKind.RAZOR else 1.34) * enemy.speed * delta, enemy.radius)
		var aim_heading := toward.angle()
		if (enemy.kind >= EnemyKind.MINIBOSS and (enemy.charge > 0.0 or enemy.afterglow > 0.0)) or (enemy.kind == EnemyKind.RAZOR and enemy.action_timer <= 0.0):
			aim_heading = enemy.aim.angle()
		enemy.heading = lerp_angle(enemy.heading, aim_heading, 1.0 - exp(-delta * 7.0))
		enemy.hit_flash = maxf(0.0, enemy.hit_flash - delta)
		if distance < PLAYER_RADIUS + enemy.radius:
			_hurt_player(enemy.contact_damage)
			enemy.position = _clamp_to_arena(enemy.position - forward * delta * 92.0, enemy.radius)
			if _ended or _revive_pending:
				return


func _separation(index: int, enemy: Enemy) -> Vector2:
	# Compare nearby entries in the bounded active pool so dense waves do not stack.
	var push := Vector2.ZERO
	var count := _enemies.size()
	for step in range(1, mini(8, count)):
		var neighbor := _enemies[(index + step) % count]
		var difference := enemy.position - neighbor.position
		var spacing := enemy.radius + neighbor.radius + 8.0
		var distance_squared := difference.length_squared()
		if distance_squared > 0.001 and distance_squared < spacing * spacing:
			var distance := sqrt(distance_squared)
			push += difference / distance * (1.0 - distance / spacing)
	return push.limit_length(0.9)


func _lancer_travel(enemy: Enemy, forward: Vector2, distance: float, delta: float) -> Vector2:
	enemy.action_timer -= delta
	if distance < 420.0 and enemy.action_timer <= 0.0:
		var launch := enemy.position + forward * 32.0
		_fx.burst(launch, WARM, 5, 85.0, forward)
		_launch_shot(ShotKind.HOSTILE, launch, forward * 284.0, 9.0, 2.2)
		enemy.action_timer = _rng.randf_range(2.3, 3.15)
	var advance := clampf((distance - 213.0) / 75.0, -0.62, 1.0)
	var orbit := sin(enemy.phase) * 0.8 * (1.0 - clampf((distance - 240.0) / 150.0, 0.0, 1.0))
	return forward * advance + Vector2(-forward.y, forward.x) * orbit


func _razor_travel(enemy: Enemy, forward: Vector2, delta: float) -> Vector2:
	enemy.action_timer -= delta
	if enemy.action_timer < -0.46:
		enemy.action_timer = 2.1
	if enemy.action_timer > 0.0 and enemy.action_timer < 0.36:
		enemy.aim = forward
		return forward * 0.15
	if enemy.action_timer <= 0.0:
		return enemy.aim * 2.62
	return forward * 0.95 + forward.orthogonal() * sin(enemy.phase + _mission_time * 3.0) * 0.34


func _minelayer_travel(enemy: Enemy, forward: Vector2, distance: float, delta: float) -> Vector2:
	enemy.action_timer -= delta
	if enemy.action_timer <= 0.0 and distance < 390.0:
		var intercept := _clamp_to_arena(_player_position + _player_velocity * 0.50, MINE_RADIUS)
		_launch_shot(ShotKind.MINE, intercept, Vector2.ZERO, 15.0, 1.55)
		enemy.action_timer = _rng.randf_range(3.7, 4.9)
	return forward * clampf((distance - 255.0) / 88.0, -0.65, 1.0) + forward.orthogonal() * 0.42


func _elite_travel(enemy: Enemy, forward: Vector2, distance: float, delta: float) -> Vector2:
	enemy.action_timer -= delta
	if enemy.action_timer <= 0.0 and distance < 360.0:
		for lane in [-1, 0, 1]:
			var direction := forward.rotated(lane * 0.23)
			_launch_shot(ShotKind.HOSTILE, enemy.position + direction * 36.0, direction * 319.0, 11.0, 1.7)
		_fx.burst(enemy.position + forward * 39.0, SHIP_TINTS[enemy.kind], 8, 118.0, forward)
		enemy.action_timer = _rng.randf_range(2.1, 3.0)
	var stride := clampf((distance - 157.0) / 100.0, -0.46, 1.0)
	return forward * stride + forward.orthogonal() * sin(_mission_time * 1.6 + enemy.phase) * 0.82


func _step_weapons(delta: float) -> void:
	_arsenal.step(self, delta)


func _closest_enemy(max_range: float) -> Enemy:
	var closest: Enemy
	var range_squared := max_range * max_range
	for enemy in _enemies:
		var candidate := _player_position.distance_squared_to(enemy.position)
		if candidate < range_squared:
			range_squared = candidate
			closest = enemy
	return closest


func _launch_shot(kind: int, position: Vector2, velocity: Vector2, damage: float, life: float, target: Enemy = null) -> void:
	var friendly := kind != ShotKind.HOSTILE and kind != ShotKind.MINE
	if _shots.size() >= MAX_SHOTS or (friendly and _friendly_shots >= MAX_FRIENDLY_SHOTS):
		return
	if kind == ShotKind.MINE:
		if _mine_count >= 12:
			return
		_mine_count += 1
	if friendly:
		_friendly_shots += 1
	var shot: Shot = Shot.new() if _shot_pool.is_empty() else _shot_pool.pop_back()
	shot.kind = kind
	shot.position = position
	shot.velocity = velocity
	shot.damage = damage
	shot.life = life
	shot.target = target
	_shots.append(shot)


func _step_shots(delta: float) -> void:
	for index in range(_shots.size() - 1, -1, -1):
		var shot := _shots[index]
		shot.life -= delta
		if shot.kind == ShotKind.MINE:
			if shot.life <= 0.0:
				_fx.ring(shot.position, WARM, MINE_RADIUS, 0.44)
				_fx.burst(shot.position, WARM, 10, 162.0)
				if shot.position.distance_squared_to(_player_position) < pow(MINE_RADIUS + PLAYER_RADIUS * 0.5, 2.0):
					_hurt_player(shot.damage)
				_recycle_shot(index)
				if _ended or _revive_pending:
					return
			continue
		if shot.life <= 0.0:
			_recycle_shot(index)
			continue
		if shot.kind == ShotKind.MISSILE and shot.target != null:
			var target_angle := (shot.target.position - shot.position).angle()
			shot.velocity = Vector2.from_angle(rotate_toward(shot.velocity.angle(), target_angle, delta * 5.7)) * 468.0
		var before := shot.position
		shot.position += shot.velocity * delta
		if shot.kind == ShotKind.HOSTILE:
			var closest := Geometry2D.get_closest_point_to_segment(_player_position, before, shot.position)
			if _player_position.distance_squared_to(closest) < PLAYER_RADIUS * PLAYER_RADIUS:
				_hurt_player(shot.damage)
				_recycle_shot(index)
				if _ended or _revive_pending:
					return
			continue
		var hit := _target_along_segment(before, shot.position)
		if hit == -1:
			continue
		if shot.kind == ShotKind.MISSILE:
			_fx.ring(shot.position, VIOLET, 90.0, 0.46)
			_fx.burst(shot.position, VIOLET, 16, 200.0)
			var impact := shot.position
			var velocity := shot.velocity
			var damage := shot.damage
			_area_damage(impact, 85.0, damage)
			_recycle_shot(index)
			_arsenal.missile_impact(self, impact, velocity, damage)
		else:
			_damage_enemy(hit, shot.damage, shot.velocity.normalized())
			_recycle_shot(index)


func _target_along_segment(start: Vector2, finish: Vector2, thickness := 0.0) -> int:
	var nearest := -1
	var fraction := 1.0001
	var travel := finish - start
	var length_squared := travel.length_squared()
	if length_squared < 0.00001:
		return nearest
	for index in _enemies.size():
		var enemy := _enemies[index]
		var radius := enemy.radius + thickness
		var center := enemy.position - start
		var bound_x := radius + absf(travel.x)
		var bound_y := radius + absf(travel.y)
		if absf(center.x) > bound_x or absf(center.y) > bound_y:
			continue
		var center_fraction := center.dot(travel) / length_squared
		var perpendicular_squared := center.length_squared() - center_fraction * center_fraction * length_squared
		var chord_squared := radius * radius - perpendicular_squared
		if chord_squared < 0.0:
			continue
		var half_chord := sqrt(chord_squared / length_squared)
		var entry := maxf(0.0, center_fraction - half_chord)
		if center_fraction + half_chord >= 0.0 and entry < fraction and entry <= 1.0:
			nearest = index
			fraction = entry
	return nearest


func _recycle_shot(index: int) -> void:
	var shot := _shots[index]
	if shot.kind == ShotKind.MINE:
		_mine_count -= 1
	elif shot.kind != ShotKind.HOSTILE:
		_friendly_shots -= 1
	shot.target = null
	_shot_pool.append(shot)
	_shots[index] = _shots.back()
	_shots.pop_back()


func _area_damage(origin: Vector2, radius: float, damage: float) -> void:
	for index in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[index]
		var reach := radius + enemy.radius
		if origin.distance_squared_to(enemy.position) <= reach * reach:
			_damage_enemy(index, damage, origin.direction_to(enemy.position))


func _damage_enemy(index: int, damage: float, direction: Vector2) -> void:
	var enemy := _enemies[index]
	enemy.hp -= damage
	var tint := SHIP_TINTS[enemy.kind]
	var recent_impact := enemy.hit_flash > SHIP_HIT_LIFETIME * 0.48
	var visible := _effect_visible(enemy.position, enemy.radius + 42.0)
	if enemy.hp > 0.0:
		if not recent_impact:
			enemy.hit_flash = SHIP_HIT_LIFETIME
			if visible:
				var contact := enemy.position - direction * enemy.radius * 0.72
				_fx.burst(contact, tint, 4, 178.0, -direction)
				if _mission_time - _last_hit_audio >= LAST_HIT_AUDIO_INTERVAL:
					_last_hit_audio = _mission_time
					sound_requested.emit("hit")
		return
	_kills += 1
	if enemy.kind == EnemyKind.ELITE:
		_recovered += 2
	elif enemy.kind == EnemyKind.MINIBOSS:
		_director._miniboss_defeated = true
		_recovered += 35
	elif enemy.kind == EnemyKind.BOSS:
		_director._boss_defeated = true
		_recovered += 90
	_spawn_orb(enemy.position, enemy.xp)
	var capital := enemy.kind >= EnemyKind.MINIBOSS
	if capital:
		_last_boss_down = "%s zniszczony" % _director.boss_name(enemy.kind)
		_boss_down_until = _mission_time + 2.3
		_fx.capital_break(_textures[enemy.kind], enemy.position, enemy.heading + PI * 0.5, _enemy_frames[enemy.kind], tint)
	elif visible:
		_fx.burst(enemy.position, tint, 10 + enemy.kind * 3, 233.0)
		_fx.ring(enemy.position, tint, 47.0 + enemy.kind * 10.0, 0.36)
	for shot in _shots:
		if shot.target == enemy:
			shot.target = null
	_enemy_pool.append(enemy)
	_enemies[index] = _enemies.back()
	_enemies.pop_back()
	if capital:
		sound_requested.emit("boss_break")
		_publish_telemetry()
	elif visible:
		sound_requested.emit("kill")


func _effect_visible(position: Vector2, margin: float) -> bool:
	var half_extent := get_viewport_rect().size * 0.5 + Vector2.ONE * margin
	var offset := (position - _camera).abs()
	return offset.x < half_extent.x and offset.y < half_extent.y


func _hurt_player(damage: float) -> void:
	if _hit_cooldown > 0.0 or _ended or _revive_pending:
		return
	_hp = maxf(0.0, _hp - damage * float(_sector["enemy_damage_multiplier"]) * float(_stats["damage_taken_multiplier"]) * _loadout.damage_multiplier())
	_hit_cooldown = 0.71
	_hull_flash = HULL_HIT_LIFETIME
	_fx.burst(_player_position, WARM, 19, 183.0)
	_fx.ring(_player_position, WARM, 69.0, 0.41)
	sound_requested.emit("hurt")
	_publish_telemetry()
	if _hp <= 0.0:
		if revive_offer_enabled and not _revive_spent:
			_revive_pending = true
			set_suspended(true)
			revive_offered.emit()
		else:
			_finish(false)


func _spawn_orb(position: Vector2, value: int) -> void:
	if _xp_orbs.size() >= MAX_ORBS:
		# Preserve XP when the pickup budget is full by merging it with a nearby core.
		var nearest := _xp_orbs[0]
		for current in _xp_orbs:
			if position.distance_squared_to(current.position) < position.distance_squared_to(nearest.position):
				nearest = current
		nearest.value += value
		return
	var orb: Orb = Orb.new() if _orb_pool.is_empty() else _orb_pool.pop_back()
	orb.position = position
	orb.velocity = Vector2.ZERO
	orb.value = value
	orb.phase = _rng.randf_range(0.0, TAU)
	_xp_orbs.append(orb)


func _step_orbs(delta: float) -> void:
	var magnet_range := _loadout.magnet_range() + float(_stats["magnet_bonus"])
	for index in range(_xp_orbs.size() - 1, -1, -1):
		var orb := _xp_orbs[index]
		var distance := orb.position.distance_to(_player_position)
		if distance < 24.0:
			var collected := orb.value * float(_stats["xp_multiplier"]) + _xp_fraction
			var whole := floori(collected + 0.000001)
			_xp += whole
			_xp_fraction = maxf(0.0, collected - whole)
			_fx.burst(orb.position, CYAN, 7, 112.0)
			_orb_pool.append(orb)
			_xp_orbs[index] = _xp_orbs.back()
			_xp_orbs.pop_back()
			sound_requested.emit("pickup")
			continue
		if distance < magnet_range:
			var desired := orb.position.direction_to(_player_position) * lerpf(560.0, 193.0, distance / magnet_range)
			orb.velocity = orb.velocity.lerp(desired, 1.0 - exp(-delta * 9.0))
		else:
			orb.velocity = orb.velocity.move_toward(Vector2.ZERO, 480.0 * delta)
		orb.position += orb.velocity * delta


func _offer_level() -> void:
	_level += 1
	_xp -= _xp_goal
	var tier := _level - 1
	_xp_goal = 12 + 6 * tier + ceili(0.42 * tier * tier)
	_pending_cards = _loadout.cards(_rng, _level)
	_clear_pointer()
	_publish_telemetry()
	upgrade_requested.emit(_pending_cards.duplicate(true))


func _finish(won: bool) -> void:
	_ended = true
	_clear_pointer()
	_publish_telemetry()
	var base_reward := _recovered + floori(_kills / 12.0) + _director.wave * 3 + (60 if won else 0)
	var reward := floori(base_reward * float(_sector["reward_multiplier"]))
	mission_ended.emit({
		"won": won, "seconds": _mission_time, "kills": _kills, "level": _level,
		"reward": reward, "boss_defeated": _director._boss_defeated, "sector_id": _sector_id, "ship_id": _ship_id,
	})


func _publish_telemetry() -> void:
	var boss: Enemy
	for enemy in _enemies:
		if enemy.kind >= EnemyKind.MINIBOSS and (boss == null or enemy.kind > boss.kind):
			boss = enemy
	var warning := ""
	if boss != null:
		if boss.charge > 0.0:
			warning = WaveDirector.PATTERN_NAMES[boss.pattern]
		elif _director.arrival_notice > 0.0:
			warning = "%s w zasięgu" % _director.boss_name(boss.kind)
	if warning.is_empty():
		if not _director._miniboss_spawned and _mission_time >= _director.miniboss_at() - 6.0 and _mission_time < _director.miniboss_at():
			warning = "Zbliża się Aegis"
		elif not _director._boss_spawned and _mission_time >= _director.boss_at() - 7.0 and _mission_time < _director.boss_at():
			warning = "Zbliża się Leviathan"
	telemetry.emit({
		"hp": _hp, "max_hp": _max_hp, "xp": _xp, "xp_goal": _xp_goal, "level": _level,
		"seconds": _mission_time, "duration": _duration, "kills": _kills,
		"wave": _director.wave + 1, "wave_name": _director.wave_name(),
		"warning": warning, "success": _last_boss_down if _mission_time < _boss_down_until else "",
		"boss_name": _director.boss_name(boss.kind) if boss else "",
		"boss_hp": boss.hp if boss else 0.0, "boss_max_hp": boss.max_hp if boss else 0.0,
		"sector_id": _sector_id, "sector_name": _sector["title"], "ship_id": _ship_id,
	})


func _seed_sky() -> void:
	var star_rng := RandomNumberGenerator.new()
	star_rng.seed = int(_sector["star_seed"])
	var star_palette: Color = _sector["star_tint"]
	var tile := Image.create_empty(STAR_TILE_EXTENT.x, STAR_TILE_EXTENT.y, false, Image.FORMAT_RGBA8)
	for index in 148:
		var point := Vector2(star_rng.randf(), star_rng.randf()) * Vector2(STAR_TILE_EXTENT)
		var tint := star_palette.lerp(WHITE_HOT, float(index % 8) / 8.0)
		var alpha := 0.22 + (index % 4) * 0.095
		var x := clampi(floori(point.x), 0, STAR_TILE_EXTENT.x - 2)
		var y := clampi(floori(point.y), 0, STAR_TILE_EXTENT.y - 2)
		tile.set_pixel(x, y, Color(tint, alpha))
		if index % 3 == 0:
			tile.set_pixel(x + 1, y, Color(tint, alpha * 0.46))
			tile.set_pixel(x, y + 1, Color(tint, alpha * 0.29))
	_distant_star_tile = ImageTexture.create_from_image(tile)
	for index in 25:
		_near_stars.append(Vector2(star_rng.randf(), star_rng.randf()))


func _draw() -> void:
	var viewport := get_viewport_rect().size
	var offset := viewport * 0.5 - _camera
	var frame := Rect2(Vector2.ZERO, viewport)
	_draw_sky(viewport)
	draw_rect(Rect2(ARENA.position + offset, ARENA.size), _sector["boundary"], false, 1.6)
	_draw_orbs(offset, frame)
	_fx.render_capital_breaks(self, offset, frame)
	_fx.render(self, offset, frame.grow(20.0))
	var near_view := frame.grow(140.0)
	var escort_view := frame.grow(77.0)
	for enemy in _enemies:
		if enemy.kind >= EnemyKind.MINIBOSS:
			_director.draw_telegraph(self, enemy, offset, _mission_time, enemy.kind == EnemyKind.BOSS)
		var origin := enemy.position + offset
		var visible := near_view if enemy.kind >= EnemyKind.MINIBOSS else escort_view
		if visible.has_point(origin):
			_draw_enemy(enemy, origin)
	for shot in _shots:
		var origin := shot.position + offset
		if near_view.has_point(origin):
			_draw_shot(shot, origin)
	_arsenal.draw_weapons(self, offset, frame)
	_draw_player(_player_position + offset)
	_draw_steering()
	if _hull_flash > 0.0:
		_draw_damage_edges(viewport)


func _draw_sky(viewport: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, viewport), Color("#080d1b"))
	if _nebula_texture != null:
		var texture_size := _nebula_texture.get_size()
		var fit := maxf(viewport.x / texture_size.x, viewport.y / texture_size.y) * 1.074
		var covered := texture_size * fit
		var slack := (covered - viewport) * 0.5
		var drift := _camera / ARENA.size * slack * 1.45
		draw_texture_rect(_nebula_texture, Rect2(-slack - drift, covered), false, _sector["sky_tint"])
	var star_tint: Color = _sector["star_tint"]
	var space := viewport + Vector2(48.0, 48.0)
	var sample := Rect2(_camera * 0.08, viewport)
	draw_texture_rect_region(_distant_star_tile, Rect2(Vector2.ZERO, viewport), sample, Color.WHITE, false, false)
	for index in _near_stars.size():
		var origin := _star_position(_near_stars[index], space, 0.24)
		var intensity := 0.44 + 0.18 * sin(index * 9.12 + _mission_time * 1.25)
		draw_circle(origin, 1.45, Color(WHITE_HOT, intensity), true, -1.0, true)
		if index % 7 == 0:
			draw_line(origin - Vector2(4.5, 0.0), origin + Vector2(4.5, 0.0), Color(star_tint, 0.21), 0.8, true)
			draw_line(origin - Vector2(0.0, 4.5), origin + Vector2(0.0, 4.5), Color(star_tint, 0.21), 0.8, true)


func _star_position(seed_position: Vector2, span: Vector2, parallax: float) -> Vector2:
	var drift := seed_position * span - _camera * parallax
	return Vector2(fposmod(drift.x, span.x) - 24.0, fposmod(drift.y, span.y) - 24.0)


func _draw_orbs(offset: Vector2, frame: Rect2) -> void:
	for orb in _xp_orbs:
		var origin := orb.position + offset
		if not frame.has_point(origin):
			continue
		var time := _mission_time * 2.6 + orb.phase
		origin.y += sin(time) * 2.7
		var width := 4.5 + 1.8 * absf(cos(time))
		var height := 8.0 + float(orb.value > 9) * 2.6
		var shard := PackedVector2Array([
			origin - Vector2(0.0, height), origin + Vector2(width, 0.0),
			origin + Vector2(0.0, height), origin - Vector2(width, 0.0)
		])
		draw_circle(origin, height * 1.36, Color(CYAN, 0.1), true, -1.0, true)
		draw_polygon(shard, PackedColorArray([WHITE_HOT, CYAN, Color("#32a8e9"), Color("#585ee1")]))
		draw_line(origin - Vector2(0.0, height), origin + Vector2(0.0, height * 0.55), Color(WHITE_HOT, 0.62), 0.8, true)


func _draw_enemy(enemy: Enemy, origin: Vector2) -> void:
	var texture := _textures[enemy.kind]
	if texture == null:
		return
	var hull := _enemy_frames[enemy.kind]
	var body_size := hull.size
	var hot := SHIP_TINTS[enemy.kind]
	draw_set_transform(origin, enemy.heading + PI * 0.5)
	var engine_time := _mission_time + enemy.phase
	if enemy.kind >= EnemyKind.MINIBOSS:
		for side in [-1, 1]:
			_fx.engine(self, body_size * Vector2(side * 0.16, 0.41), 6.0, 30.0, hot, engine_time)
	else:
		_fx.small_engine(self, Vector2(0.0, body_size.y * 0.43), body_size.x * 0.105,
			14.0 + enemy.kind * 2.7, hot, engine_time)
	var hit := enemy.hit_flash / SHIP_HIT_LIFETIME
	var tint := Color(1.0 + hit * 0.25, 1.0 + hit * 0.16, 1.0 + hit * 0.09)
	draw_texture_rect(texture, hull, false, tint)
	if hit > 0.0:
		var tip := body_size * Vector2(0.36, -0.29)
		draw_line(Vector2(-tip.x, tip.y), Vector2(-tip.x * 0.70, tip.y - 5.0), Color(hot, hit * 0.74), 1.6, true)
		draw_line(tip, Vector2(tip.x * 0.70, tip.y - 5.0), Color(hot, hit * 0.74), 1.6, true)
	if enemy.kind == EnemyKind.LANCER and enemy.action_timer > 0.0 and enemy.action_timer < 0.29:
		var muzzle := Vector2(0.0, -body_size.y * 0.47)
		var brightness := 1.0 - enemy.action_timer / 0.29
		draw_circle(muzzle, 11.0 * brightness, Color(WARM, 0.3), true, -1.0, true)
		draw_circle(muzzle, 3.7 * brightness, WHITE_HOT, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	if enemy.kind == EnemyKind.RAZOR and enemy.action_timer > 0.0 and enemy.action_timer < 0.36:
		draw_line(origin + enemy.aim * 22.0, origin + enemy.aim * 73.0, Color(hot, 0.62), 2.0, true)
	if enemy.hp < enemy.max_hp and enemy.kind < EnemyKind.MINIBOSS:
		var line_start := origin + Vector2(-15.0, body_size.length() * 0.42)
		draw_line(line_start, line_start + Vector2(30.0, 0.0), Color("#1a151f"), 3.0)
		draw_line(line_start, line_start + Vector2(30.0 * enemy.hp / enemy.max_hp, 0.0), Color(hot, 0.84), 1.5)


func _draw_shot(shot: Shot, origin: Vector2) -> void:
	if shot.kind == ShotKind.MINE:
		var urgent := shot.life < 0.45
		var pulse := 0.63 + 0.29 * sin(shot.life * (19.0 if urgent else 10.0))
		_director.draw_zone(self, origin, MINE_RADIUS, pulse, urgent)
		draw_line(origin - Vector2(6.0, 6.0), origin + Vector2(6.0, 6.0), Color(WARM, pulse), 1.9, true)
		draw_line(origin - Vector2(-6.0, 6.0), origin + Vector2(-6.0, 6.0), Color(WARM, pulse), 1.9, true)
		return
	var forward := shot.velocity.normalized()
	var tint := CYAN
	var tail := 29.0
	var width := 2.1
	if shot.kind == ShotKind.HOSTILE:
		tint = WARM
		tail = 18.0
		width = 2.8
	elif shot.kind == ShotKind.MISSILE:
		tint = VIOLET
		tail = 40.0
		width = 3.4
	elif shot.kind == ShotKind.SHARD:
		tint = Color("#efb4ff")
		tail = 18.0
		width = 2.9
	draw_line(origin - forward * tail, origin + forward * 5.0, Color(tint, 0.24), width * 3.3, true)
	draw_line(origin - forward * tail * 0.68, origin + forward * 5.0, tint, width * 1.4, true)
	draw_line(origin - forward * tail * 0.25, origin + forward * 5.0, WHITE_HOT, width * 0.63, true)


func _ship_size(texture: Texture2D, max_dimension: float) -> Vector2:
	var source := texture.get_size()
	return source * max_dimension / maxf(source.x, source.y)


func _draw_player(origin: Vector2) -> void:
	if _player_texture == null:
		return
	var body_size := _ship_size(_player_texture, 93.0)
	var boost := _player_velocity.length() / CRUISE_SPEED
	var accent: Color = _livery_accent if _livery_accent.a > 0 else _ship["accent"]
	var color := accent.lerp(WARM, _hull_flash / HULL_HIT_LIFETIME)
	draw_set_transform(origin, _player_heading + PI * 0.5)
	var exhaust: Vector2 = _ship["exhaust"]
	var nozzle := body_size * Vector2(-exhaust.x, exhaust.y)
	var length := 26.0 + 15.0 * boost
	_fx.engine(self, nozzle, 5.1, length, Color("#5099ff") if _ship_id == "peregrine" else accent.darkened(0.17), _mission_time)
	_fx.engine(self, Vector2(-nozzle.x, nozzle.y), 5.1, length, accent, _mission_time)
	var tint := _livery
	if _hull_flash > 0.0:
		var impact := _hull_flash / HULL_HIT_LIFETIME
		tint = _livery.lerp(Color("#ffb197"), impact * 0.45)
	draw_texture_rect(_player_texture, Rect2(-body_size * 0.5, body_size), false, tint)
	if _firing_flash > 0.0:
		for sign_x: int in [-1, 1]:
			var muzzle := Vector2(sign_x * 20.0, -17.0)
			var brightness := _firing_flash / 0.078
			draw_line(muzzle + Vector2(0.0, -11.0), muzzle + Vector2(0.0, 4.0), Color(CYAN, brightness * 0.48), 6.0, true)
			draw_line(muzzle + Vector2(0.0, -9.0), muzzle + Vector2(0.0, 2.0), Color(WHITE_HOT, brightness), 2.2, true)
	var hull_marks := 0.35 + 0.09 * sin(_mission_time * 2.6)
	draw_arc(Vector2.ZERO, 57.0, 0.23, 0.92, 12, Color(color, hull_marks), 1.0, true)
	draw_arc(Vector2.ZERO, 57.0, PI - 0.92, PI - 0.23, 12, Color(color, hull_marks), 1.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_steering() -> void:
	if _touch_index == -1 and not _mouse_drag:
		return
	var center := _pointer_position - _steer_offset
	draw_circle(center, 52.0, Color("#10243840"), true, -1.0, true)
	draw_arc(center, 52.0, 0.0, TAU, 40, Color(CYAN, 0.29), 1.2, true)
	draw_line(center, _pointer_position, Color(CYAN, 0.28), 1.4, true)
	draw_circle(_pointer_position, 12.0, Color(CYAN, 0.22), true, -1.0, true)
	draw_arc(_pointer_position, 12.0, 0.0, TAU, 20, Color(CYAN, 0.56), 1.3, true)


func _draw_damage_edges(viewport: Vector2) -> void:
	var strength := _hull_flash / HULL_HIT_LIFETIME
	var outer := Color(WARM, strength * 0.25)
	var inner := Color(WARM, 0.0)
	var colors := PackedColorArray([outer, outer, inner, inner])
	var width := viewport.x
	var height := viewport.y
	var gradient := width * 0.13
	draw_primitive(PackedVector2Array([
		Vector2.ZERO, Vector2(0.0, height), Vector2(gradient, height), Vector2(gradient, 0.0)
	]), colors, PackedVector2Array())
	draw_primitive(PackedVector2Array([
		Vector2(width, height), Vector2(width, 0.0), Vector2(width - gradient, 0.0), Vector2(width - gradient, height)
	]), colors, PackedVector2Array())
