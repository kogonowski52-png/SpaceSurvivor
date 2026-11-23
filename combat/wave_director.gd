extends RefCounted
## Fleet schedule and boss attack state. The arena owns enemy lifetimes and damage.

const MINIBOSS_AT := 210.0
const BOSS_AT := 480.0
const WAVE_TIMES := [0.0, 55.0, 125.0, MINIBOSS_AT, 295.0, 380.0, BOSS_AT, 545.0]
const WAVE_NAMES := [
	"Patrol Helionu", "Skrzydło pościgowe", "Pole minowe", "Eskorta Aegis",
	"Przełamanie", "Widma Helionu", "Leviathan", "Ostatnia linia",
]
const BOSS_NAMES := ["Aegis", "Leviathan"]
const PATTERN_NAMES := ["Salwa pierścieniowa", "Cięcie osiowe", "Pola detonacji"]
const DANGER := Color("#ff9674")
const HOT := Color("#ffdac6")
const BEAM_CHARGE := 1.40
const ZONE_CHARGE := 1.18

# Each wave mixes threat roles. Bosses have dedicated slots outside this table.
const ENEMY_WEIGHTS := [
	[13, 1, 0, 0, 0, 0], [9, 4, 2, 4, 0, 0], [8, 4, 3, 3, 3, 0],
	[8, 4, 3, 4, 3, 1], [7, 5, 5, 4, 3, 3], [6, 6, 4, 5, 4, 4],
	[6, 5, 4, 5, 4, 4], [5, 6, 6, 5, 5, 5],
]

const UMBRA_TIMES := [0.0, 42.0, 96.0, 196.0, 265.0, 348.0, 455.0, 526.0]
const UMBRA_NAMES := [
	"Przechwycenie w cieniu", "Gęsta zasłona", "Sieć min", "Aegis w cieniu",
	"Martwy sektor", "Widmowa eskadra", "Leviathan Umbry", "Ucieczka z cienia",
]
const UMBRA_WEIGHTS := [
	[10, 1, 0, 6, 0, 0], [6, 3, 0, 7, 3, 0], [6, 3, 2, 7, 7, 1],
	[6, 4, 2, 7, 5, 2], [5, 5, 2, 8, 8, 3], [5, 6, 2, 8, 8, 4],
	[5, 5, 3, 8, 7, 4], [4, 5, 3, 8, 8, 5],
]

const ZENITH_TIMES := [0.0, 35.0, 90.0, 180.0, 250.0, 335.0, 435.0, 514.0]
const ZENITH_NAMES := [
	"Przednia straż", "Klin pancerny", "Dywizjon elit", "Aegis w natarciu",
	"Ciężka flota", "Straż Zenithu", "Leviathan Zenithu", "Oblężenie",
]
const ZENITH_WEIGHTS := [
	[10, 1, 3, 1, 0, 0], [6, 4, 7, 3, 1, 2], [5, 4, 7, 4, 2, 5],
	[5, 5, 7, 4, 3, 6], [4, 5, 8, 4, 3, 8], [4, 5, 9, 4, 4, 9],
	[4, 6, 9, 4, 4, 9], [4, 6, 10, 5, 5, 11],
]

var wave := 0
var arrival_notice := 0.0
var _miniboss_spawned := false
var _boss_spawned := false
var _boss_defeated := false
var _miniboss_defeated := false

var _wave_times: Array = WAVE_TIMES
var _wave_names: Array = WAVE_NAMES
var _enemy_weights: Array = ENEMY_WEIGHTS


func configure(sector_id: String) -> void:
	match sector_id:
		"umbra":
			_wave_times = UMBRA_TIMES
			_wave_names = UMBRA_NAMES
			_enemy_weights = UMBRA_WEIGHTS
		"zenith":
			_wave_times = ZENITH_TIMES
			_wave_names = ZENITH_NAMES
			_enemy_weights = ZENITH_WEIGHTS
		_:
			_wave_times = WAVE_TIMES
			_wave_names = WAVE_NAMES
			_enemy_weights = ENEMY_WEIGHTS


func wave_name() -> String:
	return _wave_names[wave]


func miniboss_at() -> float:
	return _wave_times[3]


func boss_at() -> float:
	return _wave_times[6]


func phase_at(time: float) -> int:
	for index in range(_wave_times.size() - 1, 0, -1):
		if time >= _wave_times[index]:
			return index
	return 0


func update(arena, delta: float) -> void:
	wave = phase_at(arena._mission_time)
	arrival_notice = maxf(0.0, arrival_notice - delta)
	if not _miniboss_spawned and arena._mission_time >= miniboss_at() and arena._mission_time < boss_at():
		_miniboss_spawned = true
		_spawn_boss(arena, arena.EnemyKind.MINIBOSS)
	if not _boss_spawned and arena._mission_time >= boss_at():
		_boss_spawned = true
		_spawn_boss(arena, arena.EnemyKind.BOSS)


func _spawn_boss(arena, kind: int) -> void:
	var origin: Vector2 = arena._player_position
	var direction := origin.direction_to(arena.ARENA.get_center())
	if direction == Vector2.ZERO:
		direction = Vector2.UP
	var position: Vector2 = arena._clamp_to_arena(origin + direction * 314.0, 105.0)
	arena._spawn_enemy(kind, position)
	arena._fx.ring(position, DANGER, 126.0, 0.82)
	arrival_notice = 2.1


func next_kind(rng: RandomNumberGenerator) -> int:
	var weights: Array = _enemy_weights[wave]
	var roll := rng.randi_range(1, weights.reduce(func(sum: int, weight: int) -> int: return sum + weight, 0))
	for kind in weights.size():
		roll -= weights[kind]
		if roll <= 0:
			return kind
	return 0


func boss_name(kind: int) -> String:
	return BOSS_NAMES[kind - 6]


func boss_travel(arena, enemy, forward: Vector2, distance: float, delta: float) -> Vector2:
	enemy.afterglow = maxf(0.0, enemy.afterglow - delta)
	if enemy.charge > 0.0:
		enemy.charge = maxf(0.0, enemy.charge - delta)
		if enemy.charge == 0.0:
			_release(arena, enemy)
		return Vector2.ZERO
	enemy.action_timer -= delta
	if enemy.action_timer <= 0.0 and distance < 520.0:
		enemy.pattern = (enemy.pattern + 1) % PATTERN_NAMES.size()
		enemy.attack_origin = enemy.position
		enemy.aim = forward.normalized() if distance > 1.0 else Vector2.UP
		enemy.attack_target = arena._player_position
		enemy.charge = BEAM_CHARGE if enemy.pattern == 1 else ZONE_CHARGE
		arena.sound_requested.emit("boss_warning")
		return Vector2.ZERO
	# Stay in weapon range and traverse between attacks.
	return forward * clampf((distance - 200.0) / 115.0, -0.4, 1.0)


func _release(arena, enemy) -> void:
	var final_boss: bool = enemy.kind == arena.EnemyKind.BOSS
	var origin: Vector2 = enemy.attack_origin
	var aim: Vector2 = enemy.aim
	enemy.action_timer = 2.2 if final_boss else 3.1
	match enemy.pattern:
		0:
			var lanes := 18 if final_boss else 13
			# Two adjacent trajectories are omitted in the telegraphed escape lane.
			for lane in range(2, lanes):
				var direction := aim.rotated(TAU * (float(lane) - 0.5) / lanes)
				arena._launch_shot(arena.ShotKind.HOSTILE, origin + direction * enemy.radius, direction * 232.0,
					13.0 if final_boss else 10.0, 2.8)
			arena._fx.ring(origin, DANGER, enemy.radius + 66.0, 0.48)
		1:
			enemy.afterglow = 0.24
			var player: Vector2 = arena._player_position
			var nearest := Geometry2D.get_closest_point_to_segment(player, origin, origin + aim * 620.0)
			if player.distance_squared_to(nearest) <= pow(beam_width(final_boss) + arena.PLAYER_RADIUS, 2.0):
				arena._hurt_player(24.0 if final_boss else 18.0)
		2:
			var player: Vector2 = arena._player_position
			var radius := zone_radius(final_boss)
			var hit := false
			for center in _zone_centers(enemy, final_boss):
				arena._fx.ring(center, DANGER, radius, 0.46)
				arena._fx.burst(center, DANGER, 13, 176.0)
				hit = hit or player.distance_squared_to(center) < pow(radius + arena.PLAYER_RADIUS * 0.52, 2.0)
			if hit:
				arena._hurt_player(22.0 if final_boss else 16.0)


func beam_width(final_boss: bool) -> float:
	return 46.0 if final_boss else 32.0


func zone_radius(final_boss: bool) -> float:
	return 76.0 if final_boss else 62.0


func _zone_centers(enemy, final_boss: bool) -> Array[Vector2]:
	var aim: Vector2 = enemy.aim
	var center: Vector2 = enemy.attack_target
	var side := aim.orthogonal()
	if final_boss:
		return [center, center + side * 138.0 + aim * 38.0, center - side * 138.0 + aim * 38.0]
	return [center, center - aim * 122.0]


func draw_telegraph(canvas: Node2D, enemy, offset: Vector2, now: float, final_boss: bool) -> void:
	var origin: Vector2 = enemy.attack_origin + offset
	var aim: Vector2 = enemy.aim
	if enemy.charge <= 0.0:
		if enemy.afterglow > 0.0:
			var alpha: float = enemy.afterglow / 0.24
			var finish := origin + aim * 620.0
			canvas.draw_line(origin, finish, Color(DANGER, alpha * 0.38), beam_width(final_boss) * 2.0, true)
			canvas.draw_line(origin, finish, Color(HOT, alpha), 8.0 * alpha + 2.0, true)
		return
	var progress := 1.0 - float(enemy.charge) / (BEAM_CHARGE if enemy.pattern == 1 else ZONE_CHARGE)
	var pulse := 0.55 + progress * 0.28 + 0.085 * sin(now * 16.0)
	match enemy.pattern:
		0:
			var lanes := 18 if final_boss else 13
			for lane in range(2, lanes):
				var direction := aim.rotated(TAU * (float(lane) - 0.5) / lanes)
				var start: Vector2 = origin + direction * (enemy.radius + 8.0)
				canvas.draw_line(start, start + direction * 68.0, Color(DANGER, pulse * 0.72), 2.4, true)
			canvas.draw_arc(origin, enemy.radius + 13.0, 0.0, TAU, 42, Color(DANGER, pulse), 2.0, true)
		1:
			var edge := aim.orthogonal() * beam_width(final_boss)
			var finish := origin + aim * 620.0
			canvas.draw_line(origin, finish, Color(DANGER, pulse * 0.14), edge.length() * 2.0, true)
			canvas.draw_line(origin + edge, finish + edge, Color(HOT, pulse), 2.0, true)
			canvas.draw_line(origin - edge, finish - edge, Color(HOT, pulse), 2.0, true)
			canvas.draw_dashed_line(origin, finish, Color(DANGER, pulse), 1.8, 14.0)
			var sweep := origin.lerp(finish, minf(0.97, 0.10 + progress * 0.86))
			canvas.draw_line(sweep - edge, sweep + edge, Color(DANGER, pulse * 0.79), 1.8, true)
		2:
			for center in _zone_centers(enemy, final_boss):
				draw_zone(canvas, center + offset, zone_radius(final_boss), pulse, progress > 0.65)


func draw_zone(canvas: Node2D, center: Vector2, radius: float, pulse: float, urgent := false) -> void:
	canvas.draw_circle(center, radius, Color(DANGER, pulse * (0.18 if urgent else 0.10)))
	canvas.draw_arc(center, radius, 0.0, TAU, 36, Color(DANGER, pulse), 2.6 if urgent else 1.8, true)
	if urgent:
		canvas.draw_arc(center, radius * 0.82, 0.0, TAU, 32, Color(HOT, pulse * 0.42), 1.1, true)
	for index in 4:
		var axis := Vector2.from_angle(index * PI * 0.5)
		canvas.draw_line(center + axis * (radius - 7.0), center + axis * (radius + 3.0), Color(HOT, pulse * 0.82), 1.8, true)
