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

# Each wave mixes threat roles. Bosses have dedicated slots outside this table.
const ENEMY_WEIGHTS := [
	[13, 1, 0, 0, 0, 0], [9, 4, 2, 4, 0, 0], [8, 4, 3, 3, 3, 0],
	[8, 4, 3, 4, 3, 1], [7, 5, 5, 4, 3, 3], [6, 6, 4, 5, 4, 4],
	[6, 5, 4, 5, 4, 4], [5, 6, 6, 5, 5, 5],
]

var wave := 0
var arrival_notice := 0.0
var _miniboss_spawned := false
var _boss_spawned := false
var _boss_defeated := false
var _miniboss_defeated := false


func phase_at(time: float) -> int:
	for index in range(WAVE_TIMES.size() - 1, 0, -1):
		if time >= WAVE_TIMES[index]:
			return index
	return 0


func update(arena, delta: float) -> void:
	wave = phase_at(arena._mission_time)
	arrival_notice = maxf(0.0, arrival_notice - delta)
	if not _miniboss_spawned and arena._mission_time >= MINIBOSS_AT and arena._mission_time < BOSS_AT:
		_miniboss_spawned = true
		_spawn_boss(arena, arena.EnemyKind.MINIBOSS)
	if not _boss_spawned and arena._mission_time >= BOSS_AT:
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
	var weights: Array = ENEMY_WEIGHTS[wave]
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
		enemy.charge = 1.40 if enemy.pattern == 1 else 1.18
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
	var pulse := 0.68 + 0.24 * sin(now * 18.0)
	if enemy.charge <= 0.0:
		if enemy.afterglow > 0.0:
			var alpha: float = enemy.afterglow / 0.24
			var finish := origin + aim * 620.0
			canvas.draw_line(origin, finish, Color(DANGER, alpha * 0.38), beam_width(final_boss) * 2.0, true)
			canvas.draw_line(origin, finish, Color(HOT, alpha), 8.0 * alpha + 2.0, true)
		return
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
		2:
			for center in _zone_centers(enemy, final_boss):
				draw_zone(canvas, center + offset, zone_radius(final_boss), pulse)


func draw_zone(canvas: Node2D, center: Vector2, radius: float, pulse: float) -> void:
	canvas.draw_circle(center, radius, Color(DANGER, pulse * 0.12))
	canvas.draw_arc(center, radius, 0.0, TAU, 46, Color(DANGER, pulse), 2.2, true)
	canvas.draw_arc(center, radius * 0.82, 0.0, TAU, 36, Color(HOT, pulse * 0.42), 1.1, true)
	for spoke in range(4):
		var direction := Vector2.from_angle(PI * 0.5 * spoke)
		canvas.draw_line(center + direction * (radius - 10.0), center + direction * (radius + 4.0), Color(HOT, pulse), 2.0, true)
