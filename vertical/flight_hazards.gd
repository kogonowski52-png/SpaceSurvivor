extends RefCounted
## Flight telegraphs and impacts share their geometry so warnings describe actual danger.

enum Kind { BLAST, BEAM, DEBRIS }

const CAPACITY := 22
const DEBRIS := [
	preload("res://assets/art/chapter_one/debris/wreck.webp"),
	preload("res://assets/art/chapter_one/debris/slab.webp"),
	preload("res://assets/art/chapter_one/debris/turbine.webp"),
]
const ALERT := Color("#ffab8a")
const DRIVER_MARGIN := 15.0

class Hazard:
	var kind := 0
	var origin := Vector2.ZERO
	var target := Vector2.ZERO
	var velocity := Vector2.ZERO
	var size := 0.0
	var age := 0.0
	var warning := 0.0
	var duration := 0.0
	var damage := 0.0
	var tint := ALERT
	var label := ""
	var art := 0
	var impact_played := false

	func is_warned() -> bool:
		return age < warning

	func center() -> Vector2:
		return origin + velocity * maxf(0.0, age - warning)

var active: Array[Hazard] = []
var _pool: Array[Hazard] = []


func _init() -> void:
	for index in CAPACITY:
		_pool.append(Hazard.new())


func _place(kind: Kind, from: Vector2, to: Vector2, extent: float, windup: float, duration: float,
		damage: float, tone: Color, label: String) -> Hazard:
	if _pool.is_empty():
		return null
	var zone: Hazard = _pool.pop_back()
	zone.kind = kind
	zone.origin = from
	zone.target = to
	zone.velocity = Vector2.ZERO
	zone.size = extent
	zone.age = 0.0
	zone.warning = windup
	zone.duration = duration
	zone.damage = damage
	zone.tint = tone
	zone.label = label
	zone.art = 0
	zone.impact_played = false
	active.append(zone)
	return zone


func blast(at: Vector2, radius: float, windup: float, damage: float, tone := ALERT, label := "") -> void:
	_place(Kind.BLAST, at, at, radius, windup, 0.32, damage, tone, label)


func beam(from: Vector2, to: Vector2, width: float, windup: float, span: float,
		damage: float, tone: Color, label := "") -> void:
	_place(Kind.BEAM, from, to, width * 0.5, windup, span, damage, tone, label)


func debris(lane: float, shimmer: float, drift: float, art: int, tone: Color) -> void:
	var origin := Vector2(lane, -68.0)
	var velocity := Vector2(drift, 219.0)
	var span := (1_020.0 - origin.y) / velocity.y
	var zone := _place(Kind.DEBRIS, origin, origin + velocity * span, 31.0 + art * 3.0,
		shimmer, span, 20.0 + art * 2.0, tone, "ODŁAMEK · ZMIEŃ KURS")
	if zone != null:
		zone.art = art
		zone.velocity = velocity


func step(field: Node2D, delta: float) -> void:
	for index in range(active.size() - 1, -1, -1):
		var zone := active[index]
		zone.age += delta
		if zone.age >= zone.warning + zone.duration:
			_pool.append(zone)
			active[index] = active.back()
			active.pop_back()
			continue
		if zone.is_warned():
			continue
		if not zone.impact_played:
			zone.impact_played = true
			match zone.kind:
				Kind.BLAST:
					field.fx.blast(zone.center(), zone.size * 1.64, false, 0.43)
					field.fx.ring(zone.center(), zone.tint, zone.size, 0.49)
					field.sound_requested.emit("frontier_impact")
				Kind.BEAM:
					field.sound_requested.emit("frontier_rail")
		if _distance(zone, field.player_position, 0.0) < zone.size + DRIVER_MARGIN:
			field.hit_player(zone.damage)


func clear() -> void:
	_pool.append_array(active)
	active.clear()


func urgent() -> String:
	var label := ""
	var soonest := INF
	for zone in active:
		var time := zone.warning - zone.age
		if time > 0.0 and time < soonest and not zone.label.is_empty():
			label = zone.label
			soonest = time
	return label


func risk(at: Vector2, horizon: float) -> float:
	var caution := 0.0
	for zone in active:
		var time := zone.warning - zone.age
		if time > horizon + 0.25 or time + zone.duration < 0.0:
			continue
		var reach := zone.size + 27.0
		var distance := minf(_distance(zone, at, maxf(time, 0.0)), _distance(zone, at, horizon))
		if distance < reach:
			caution += (1.0 - distance / reach) * 325.0
	return caution


func _distance(zone: Hazard, point: Vector2, future: float) -> float:
	if zone.kind == Kind.BEAM:
		return Geometry2D.get_closest_point_to_segment(point, zone.origin, zone.target).distance_to(point)
	return point.distance_to(zone.origin + zone.velocity * maxf(0.0, zone.age + future - zone.warning))


func render(canvas: Node2D, time: float) -> void:
	for zone in active:
		if zone.is_warned():
			_render_warning(canvas, zone, time)
			continue
		match zone.kind:
			Kind.BEAM:
				var alpha := 0.46 + 0.16 * sin(time * 46.0)
				canvas.draw_line(zone.origin, zone.target, Color(zone.tint, alpha), zone.size * 2.0, true)
				canvas.draw_line(zone.origin, zone.target, zone.tint.lightened(0.56), 5.0, true)
			Kind.DEBRIS:
				var texture: Texture2D = DEBRIS[zone.art]
				var scale := texture.get_size().normalized() * zone.size * 2.6
				canvas.draw_set_transform(zone.center(), (zone.age - zone.warning) * (0.40 + zone.art * 0.13))
				canvas.draw_texture_rect(texture, Rect2(-scale * 0.5, scale), false)
				canvas.draw_set_transform(Vector2.ZERO)
			Kind.BLAST:
				var fraction := (zone.age - zone.warning) / zone.duration
				canvas.draw_circle(zone.center(), zone.size, Color(zone.tint, (1.0 - fraction) * 0.17), true, -1.0, true)


func _render_warning(canvas: Node2D, zone: Hazard, time: float) -> void:
	var progress := clampf(zone.age / zone.warning, 0.0, 1.0)
	var tone := Color(zone.tint, 0.54 + progress * 0.29)
	if zone.kind == Kind.BLAST:
		canvas.draw_circle(zone.origin, zone.size, Color(zone.tint, 0.10), true, -1.0, true)
		canvas.draw_arc(zone.origin, zone.size, 0.0, TAU, 34, tone, 2.0, true)
		canvas.draw_arc(zone.origin, zone.size - 5.0, -PI * 0.5, -PI * 0.5 + maxf(0.05, TAU * progress), 30,
			zone.tint.lightened(0.42), 2.1, true)
		return

	var axis := (zone.target - zone.origin).normalized()
	var normal := axis.orthogonal()
	canvas.draw_line(zone.origin, zone.target, Color(zone.tint, 0.10), zone.size * 2.0, true)
	for side: int in [-1, 1]:
		var edge := normal * zone.size * side
		canvas.draw_dashed_line(zone.origin + edge, zone.target + edge, tone, 1.7, 17.0)
	for marker in 3:
		var middle := zone.origin.lerp(zone.target, 0.38 + marker * 0.16) + axis * sin(time * 14.0) * 6.0
		canvas.draw_line(middle - normal * 8.0 - axis * 6.0, middle, tone, 2.0, true)
		canvas.draw_line(middle, middle + normal * 8.0 - axis * 6.0, tone, 2.0, true)
