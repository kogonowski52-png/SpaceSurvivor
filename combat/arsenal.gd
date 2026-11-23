extends RefCounted

const CYAN := Color("#65e9ff")
const LASER := Color("#81f5ed")
const PLASMA := Color("#ec79ff")
const TESLA := Color("#b494ff")
const DRONE := Color("#ffdc87")
const HOT := Color("#f5fcff")
const MAX_TRACES := 24
const LASER_DURATION := 0.9
const LASER_TICK_INTERVAL := 0.16

class Trace:
	var points: PackedVector2Array
	var tint: Color
	var width: float
	var duration: float
	var life: float

var _traces: Array[Trace] = []
var _trace_pool: Array[Trace] = []
var _pulse_timer := 0.0
var _missile_timer := 0.0
var _laser_timer := 0.0
var _laser_remaining := 0.0
var _laser_tick := 0.0
var _laser_heading := 0.0
var _laser_start := Vector2.ZERO
var _laser_finish := Vector2.ZERO
var _orbital_timer := 0.0
var _tesla_timer := 0.0
var _drone_timer := 0.0
var _pulse_volley := 0
var _orbital_angle := 0.0
var _drone_angle := 0.0
var _drone_texture: Texture2D
var _drone_texture_checked := false


func step(arena: Node2D, delta: float) -> void:
	_step_traces(delta)
	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		var pulse_target: RefCounted = arena._closest_enemy(390.0)
		if pulse_target != null:
			_fire_pulse(arena, pulse_target.position)

	var missile_rank: int = arena._loadout.rank("missiles")
	if missile_rank > 0:
		_missile_timer -= delta
		if _missile_timer <= 0.0:
			var missile_target: RefCounted = arena._closest_enemy(480.0)
			if missile_target != null:
				_fire_missile(arena, missile_target, missile_rank)

	var laser_rank: int = arena._loadout.rank("laser")
	if laser_rank > 0:
		_step_laser(arena, delta, laser_rank)

	var plasma_rank: int = arena._loadout.rank("nova")
	if plasma_rank > 0:
		_step_orbitals(arena, delta, plasma_rank)

	var tesla_rank: int = arena._loadout.rank("tesla")
	if tesla_rank > 0:
		_tesla_timer -= delta
		if _tesla_timer <= 0.0:
			var tesla_target: RefCounted = arena._closest_enemy(242.0)
			if tesla_target != null:
				_fire_tesla(arena, tesla_target, tesla_rank)

	var drone_rank: int = arena._loadout.rank("drones")
	if drone_rank > 0:
		_step_drones(arena, delta, drone_rank)


func _fire_pulse(arena: Node2D, target: Vector2) -> void:
	var origin: Vector2 = arena._player_position
	var forward := origin.direction_to(target)
	var right := Vector2(-forward.y, forward.x)
	var spec: Resource = arena.PULSE
	var rank: int = arena._loadout.rank("pulse_damage")
	var damage := (float(spec.damage) + 5.0 * rank) * float(arena._stats["weapon_damage_multiplier"])
	var shot_count := 2 + (rank + 1) / 2
	for index in shot_count:
		var spread := lerpf(-19.0, 19.0, float(index) / (shot_count - 1))
		var launch := origin + forward * 18.0 + right * spread
		var velocity := launch.direction_to(target) * float(spec.projectile_speed)
		arena._launch_shot(arena.ShotKind.PULSE, launch, velocity, damage, 0.63)

	_pulse_volley += 1
	if arena._loadout.rank("pulse_crossfire") > 0 and _pulse_volley % 3 == 0:
		for angle: float in [-2.36, -0.79, 0.79, 2.36]:
			var ray := forward.rotated(angle)
			arena._launch_shot(arena.ShotKind.PULSE, origin + ray * 24.0, ray * 820.0, damage * 0.74, 0.43)
		arena._fx.ring(origin, CYAN, 39.0, 0.26)
	_pulse_timer = float(spec.interval_seconds) * float(arena._stats["pulse_interval_multiplier"])
	arena._firing_flash = 0.078
	arena.sound_requested.emit("shot")


func _fire_missile(arena: Node2D, target: RefCounted, rank: int) -> void:
	var origin: Vector2 = arena._player_position
	var forward := Vector2.from_angle(float(arena._player_heading))
	var damage := (29.0 + 12.0 * (rank - 1)) * float(arena._stats["weapon_damage_multiplier"])
	arena._launch_shot(arena.ShotKind.MISSILE, origin - forward * 18.0, forward * 468.0, damage, 1.8, target)
	_missile_timer = 2.65 - 0.29 * rank
	arena.sound_requested.emit("missile")


func missile_impact(arena: Node2D, position: Vector2, velocity: Vector2, damage: float) -> void:
	if arena._loadout.rank("missile_cluster") == 0:
		return
	var angle := velocity.angle()
	for index in 5:
		var ray := Vector2.from_angle(angle + TAU * index / 5.0)
		arena._launch_shot(arena.ShotKind.SHARD, position + ray * 17.0, ray * 492.0, damage * 0.43, 0.29)


func _laser_range(rank: int) -> float:
	return 420.0 + 24.0 * (rank - 1)


func _step_laser(arena: Node2D, delta: float, rank: int) -> void:
	_laser_timer -= delta
	_laser_remaining = maxf(0.0, _laser_remaining - delta)
	if _laser_remaining <= 0.0 and _laser_timer > 0.0:
		return
	var reach := _laser_range(rank)
	var target: RefCounted = arena._closest_enemy(reach)
	var origin: Vector2 = arena._player_position
	if _laser_remaining <= 0.0:
		if target == null:
			return
		_laser_remaining = LASER_DURATION
		_laser_tick = 0.0
		_laser_heading = origin.angle_to_point(target.position)
		_laser_timer = 3.8 - 0.21 * rank
		arena.sound_requested.emit("laser")
	elif target != null:
		_laser_heading = rotate_toward(_laser_heading, origin.angle_to_point(target.position), delta * 4.8)
	var direction := Vector2.from_angle(_laser_heading)
	_laser_start = origin + direction * 23.0
	_laser_finish = origin + direction * reach
	_laser_tick -= delta
	if _laser_tick > 0.0:
		return
	_laser_tick += LASER_TICK_INTERVAL
	var damage := (8.0 + 3.0 * (rank - 1)) * float(arena._stats["weapon_damage_multiplier"])
	for index in range(arena._enemies.size() - 1, -1, -1):
		var enemy: RefCounted = arena._enemies[index]
		var point := Geometry2D.get_closest_point_to_segment(enemy.position, _laser_start, _laser_finish)
		var width := float(enemy.radius) + 5.0
		if point.distance_squared_to(enemy.position) <= width * width:
			arena._damage_enemy(index, damage, direction)
	arena._fx.burst(_laser_start, LASER, 4, 106.0, direction)


func _orbital_count(rank: int) -> int:
	return 2 + (rank - 1) / 2


func _orbital_position(origin: Vector2, index: int, rank: int) -> Vector2:
	var angle := _orbital_angle + TAU * index / _orbital_count(rank)
	return origin + Vector2.from_angle(angle) * (88.0 + 5.0 * rank)


func _step_orbitals(arena: Node2D, delta: float, rank: int) -> void:
	_orbital_angle = fposmod(_orbital_angle + (2.1 + rank * 0.16) * delta, TAU)
	_orbital_timer -= delta
	if _orbital_timer > 0.0:
		return
	_orbital_timer = 0.2
	var origin: Vector2 = arena._player_position
	var hit := false
	var damage := (12.0 + 4.0 * (rank - 1)) * float(arena._stats["weapon_damage_multiplier"])
	for index in _orbital_count(rank):
		var charge := _orbital_position(origin, index, rank)
		for enemy_index in range(arena._enemies.size() - 1, -1, -1):
			var enemy: RefCounted = arena._enemies[enemy_index]
			var reach := float(enemy.radius) + 15.0
			var enemy_position: Vector2 = enemy.position
			if charge.distance_squared_to(enemy_position) > reach * reach:
				continue
			arena._damage_enemy(enemy_index, damage, charge.direction_to(enemy_position))
			arena._fx.burst(charge, PLASMA, 5, 100.0)
			hit = true
	if hit:
		arena.sound_requested.emit("nova")


func _nearest_from(arena: Node2D, origin: Vector2, reach: float, excluded: Array[RefCounted]) -> RefCounted:
	var closest: RefCounted
	var best := reach * reach
	for enemy: RefCounted in arena._enemies:
		if enemy in excluded:
			continue
		var candidate := origin.distance_squared_to(enemy.position)
		if candidate < best:
			best = candidate
			closest = enemy
	return closest


func _fire_tesla(arena: Node2D, first: RefCounted, rank: int) -> void:
	var target: RefCounted = first
	var origin: Vector2 = arena._player_position
	var fork_origin: Vector2 = first.position
	var seen: Array[RefCounted] = []
	var damage := (24.0 + 8.0 * (rank - 1)) * float(arena._stats["weapon_damage_multiplier"])
	for index in 3 + (rank - 1) / 2:
		if target == null:
			break
		var landing: Vector2 = target.position
		_discharge(arena, origin, landing, target, damage * pow(0.72, index), 3.3)
		seen.append(target)
		origin = landing
		target = _nearest_from(arena, origin, 126.0 + rank * 7.0, seen)
	if arena._loadout.rank("tesla_branch") > 0:
		for index in 2:
			var fork := _nearest_from(arena, fork_origin, 192.0, seen)
			if fork == null:
				break
			_discharge(arena, fork_origin, fork.position, fork, damage * (0.61 - 0.12 * index), 2.35)
			seen.append(fork)
	_tesla_timer = 2.9 - 0.23 * rank
	arena.sound_requested.emit("tesla")


func _discharge(arena: Node2D, origin: Vector2, finish: Vector2, target: RefCounted, damage: float, width: float) -> void:
	var points := PackedVector2Array([origin])
	var axis := origin.direction_to(finish).orthogonal()
	for index in range(1, 6):
		var bend := sin(float(index) * 17.12 + finish.dot(Vector2(0.02, 0.06))) * 11.0
		points.append(origin.lerp(finish, float(index) / 6.0) + axis * bend)
	points.append(finish)
	_add_trace(points, TESLA, width, 0.26)
	var index: int = arena._enemies.find(target)
	if index >= 0:
		arena._damage_enemy(index, damage, origin.direction_to(finish))
	arena._fx.burst(finish, TESLA, 8, 157.0)


func _drone_count(rank: int) -> int:
	return 2 + (rank - 1) / 2


func _drone_position(origin: Vector2, index: int, rank: int) -> Vector2:
	var angle := _drone_angle + TAU * index / _drone_count(rank)
	return origin + Vector2.from_angle(angle) * (63.0 + index % 2 * 8.0)


func _step_drones(arena: Node2D, delta: float, rank: int) -> void:
	if not _drone_texture_checked:
		_drone_texture_checked = true
		var path := "res://assets/art/drone.png"
		if ResourceLoader.exists(path):
			_drone_texture = load(path) as Texture2D
	_drone_angle = fposmod(_drone_angle - 1.32 * delta, TAU)
	_drone_timer -= delta
	if _drone_timer > 0.0:
		return
	var hit := false
	var origin: Vector2 = arena._player_position
	var excluded: Array[RefCounted] = []
	var drone_scale := float(arena._stats["weapon_damage_multiplier"]) * float(arena._stats["drone_damage_multiplier"])
	var damage := (9.0 + 4.0 * (rank - 1)) * drone_scale
	for index in _drone_count(rank):
		var source := _drone_position(origin, index, rank)
		var target := _nearest_from(arena, source, 205.0 + rank * 8.0, excluded)
		if target == null:
			continue
		var finish: Vector2 = target.position
		excluded.append(target)
		arena._damage_enemy(arena._enemies.find(target), damage, source.direction_to(finish))
		_add_trace(PackedVector2Array([source, finish]), DRONE, 1.8, 0.14)
		hit = true
	if hit:
		_drone_timer = 1.72 - 0.13 * rank
		arena.sound_requested.emit("drone")


func _step_traces(delta: float) -> void:
	for index in range(_traces.size() - 1, -1, -1):
		var trace := _traces[index]
		trace.life -= delta
		if trace.life <= 0.0:
			_trace_pool.append(trace)
			_traces[index] = _traces.back()
			_traces.pop_back()


func _add_trace(points: PackedVector2Array, tint: Color, width: float, duration: float) -> void:
	if _traces.size() >= MAX_TRACES:
		return
	var trace: Trace = Trace.new() if _trace_pool.is_empty() else _trace_pool.pop_back()
	trace.points = points
	trace.tint = tint
	trace.width = width
	trace.duration = duration
	trace.life = duration
	_traces.append(trace)


func draw_weapons(arena: Node2D, offset: Vector2, _frame: Rect2) -> void:
	arena.draw_set_transform(offset)
	if _laser_remaining > 0.0:
		var fade := minf(1.0, _laser_remaining / 0.19)
		var pulse := 0.82 + 0.18 * sin(_laser_remaining * 115.0)
		arena.draw_line(_laser_start, _laser_finish, Color(LASER, 0.22 * fade), 17.0 * pulse, true)
		arena.draw_line(_laser_start, _laser_finish, Color(LASER, fade), 5.8 * pulse, true)
		arena.draw_line(_laser_start, _laser_finish, Color(HOT, fade), 1.9 * pulse, true)
	for trace in _traces:
		var opacity := trace.life / trace.duration
		arena.draw_polyline(trace.points, Color(trace.tint, opacity * 0.19), trace.width * 3.6, true)
		arena.draw_polyline(trace.points, Color(trace.tint, opacity * 0.92), trace.width, true)
		arena.draw_polyline(trace.points, Color(HOT, opacity), maxf(1.0, trace.width * 0.35), true)
	var origin: Vector2 = arena._player_position
	var plasma_rank: int = arena._loadout.rank("nova")
	for index in _orbital_count(plasma_rank) if plasma_rank > 0 else 0:
		_draw_orbital(arena, origin, index, plasma_rank)
	var drone_rank: int = arena._loadout.rank("drones")
	if drone_rank > 0:
		_draw_drones(arena, origin, offset, drone_rank)
	arena.draw_set_transform(Vector2.ZERO)


func _draw_orbital(arena: Node2D, origin: Vector2, index: int, rank: int) -> void:
	var angle := _orbital_angle + TAU * index / _orbital_count(rank)
	var position := _orbital_position(origin, index, rank)
	var distance := origin.distance_to(position)
	arena.draw_arc(origin, distance, angle - 0.46, angle, 14, Color(PLASMA, 0.26), 6.5, true)
	arena.draw_arc(origin, distance, angle - 0.33, angle, 14, Color(PLASMA, 0.65), 2.1, true)
	arena.draw_circle(position, 15.5, Color(PLASMA, 0.13), true, -1.0, true)
	arena.draw_circle(position, 8.2, Color(PLASMA, 0.81), true, -1.0, true)
	arena.draw_circle(position, 4.5, HOT, true, -1.0, true)
	arena.draw_arc(position, 11.8, angle, angle + 2.3, 12, Color(HOT, 0.75), 1.3, true)


func _draw_drones(arena: Node2D, origin: Vector2, offset: Vector2, rank: int) -> void:
	if _drone_texture == null:
		return
	var native_size := _drone_texture.get_size()
	var size := native_size * 30.0 / maxf(native_size.x, native_size.y)
	for index in _drone_count(rank):
		var center := _drone_position(origin, index, rank)
		var direction := origin.direction_to(center)
		arena.draw_set_transform(offset + center, direction.angle())
		arena.draw_line(Vector2(-2.5, size.y * 0.28), Vector2(-2.5, size.y * 0.78), Color(DRONE, 0.58), 2.0, true)
		arena.draw_line(Vector2(2.5, size.y * 0.28), Vector2(2.5, size.y * 0.78), Color(DRONE, 0.58), 2.0, true)
		arena.draw_texture_rect(_drone_texture, Rect2(-size * 0.5, size), false)
