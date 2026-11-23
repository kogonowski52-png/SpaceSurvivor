extends RefCounted

const MAX_SPARKS := 216
const MAX_RINGS := 20
const MAX_COLLAPSES := 2
const COLLAPSE_LIFETIME := 0.88
const CYAN := Color("#7deaff")
const WHITE_HOT := Color("#effbff")
const LIGHTS := preload("res://assets/art/flight_lights.png")
const STREAK := Rect2(0, 192, 128, 24)
const HOSTILE_STREAK := Rect2(128, 192, 128, 24)
const CONTACT := Rect2(0, 216, 64, 64)
const PILOT_SHADE := Rect2(64, 216, 96, 64)
const PILOT_CLEARANCE_SQ := 56.0 * 56.0

class Spark:
	var position: Vector2
	var velocity: Vector2
	var tint: Color
	var life: float
	var duration: float

class Ring:
	var position: Vector2
	var tint: Color
	var radius: float
	var life: float
	var duration: float

class Collapse:
	var texture: Texture2D
	var position: Vector2
	var heading: float
	var frame: Rect2
	var tint: Color
	var life: float

static var _plume: Texture2D
var _collapses: Array[Collapse] = []

var _rng := RandomNumberGenerator.new()
var _sparks: Array[Spark] = []
var _rings: Array[Ring] = []
var _spark_pool: Array[Spark] = []
var _ring_pool: Array[Ring] = []


func prepare() -> void:
	# The short thruster plume is baked once so regular ships only need one draw each.
	if _plume != null:
		return
	const WIDTH := 24
	const HEIGHT := 62
	var image := Image.create_empty(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in HEIGHT:
		var progress := float(y) / (HEIGHT - 1)
		for x in WIDTH:
			var distance := absf(float(x) * 2.0 / (WIDTH - 1) - 1.0)
			var envelope := lerpf(0.95, 0.1, progress)
			var band := 1.0 - smoothstep(envelope * 0.22, envelope, distance)
			var alpha := band * pow(1.0 - progress, 1.25)
			var core := (1.0 - smoothstep(0.02, envelope * 0.54, distance)) * (1.0 - progress)
			var color := Color(0.46, 0.46, 0.46).lerp(WHITE_HOT, core)
			image.set_pixel(x, y, Color(color, alpha))
	_plume = ImageTexture.create_from_image(image)


func small_engine(canvas: Node2D, nozzle: Vector2, width: float, length: float, tint: Color, time: float) -> void:
	var flutter := 0.94 + sin(time * 58.0) * 0.10
	var bounds := Rect2(nozzle - Vector2(width, 2.0), Vector2(width * 2.0, length * flutter))
	canvas.draw_texture_rect(_plume, bounds, false, tint.lightened(0.37))


func projectile(canvas: Node2D, origin: Vector2, heading: float, tail: float, width: float, tint: Color, hostile: bool) -> void:
	canvas.draw_set_transform(origin, heading)
	canvas.draw_texture_rect_region(LIGHTS, Rect2(-tail, -width * 0.5, tail + 6.0, width),
		HOSTILE_STREAK if hostile else STREAK, tint)
	canvas.draw_set_transform(Vector2.ZERO)


func laser(canvas: Node2D, start: Vector2, finish: Vector2, age: float, opacity: float) -> void:
	var span := finish - start
	var layer := int(age * 36.0) % 8
	canvas.draw_set_transform(start, span.angle())
	canvas.draw_texture_rect_region(LIGHTS, Rect2(0, -10, span.length(), 20), Rect2(0, layer * 24, 256, 24),
		Color(1, 1, 1, opacity))
	canvas.draw_set_transform(Vector2.ZERO)


func laser_contact(canvas: Node2D, origin: Vector2, extent: float, opacity: float) -> void:
	var dimensions := Vector2.ONE * extent
	canvas.draw_texture_rect_region(LIGHTS, Rect2(origin - dimensions * 0.5, dimensions), CONTACT, Color(1, 1, 1, opacity))


func pilot_backlight(canvas: Node2D, origin: Vector2) -> void:
	canvas.draw_texture_rect_region(LIGHTS, Rect2(origin - Vector2(62, 59), Vector2(124, 118)), PILOT_SHADE)


func capital_break(texture: Texture2D, position: Vector2, heading: float, bounds: Rect2, tint: Color) -> void:
	if _collapses.size() >= MAX_COLLAPSES:
		_collapses.pop_front()
	var wreck := Collapse.new()
	wreck.texture = texture
	wreck.position = position
	wreck.heading = heading
	wreck.frame = bounds
	wreck.tint = tint
	wreck.life = COLLAPSE_LIFETIME
	_collapses.append(wreck)
	var size := maxf(bounds.size.x, bounds.size.y)
	burst(position, tint, 34, 245.0)
	burst(position + Vector2.from_angle(heading) * size * 0.28, WHITE_HOT, 12, 200.0)


func step(delta: float) -> void:
	for index in range(_sparks.size() - 1, -1, -1):
		var spark := _sparks[index]
		spark.life -= delta
		if spark.life <= 0.0:
			_spark_pool.append(spark)
			_sparks[index] = _sparks.back()
			_sparks.pop_back()
			continue
		spark.position += spark.velocity * delta
		spark.velocity *= 1.0 - minf(0.7, 2.1 * delta)
	for index in range(_rings.size() - 1, -1, -1):
		var wave := _rings[index]
		wave.life -= delta
		if wave.life <= 0.0:
			_ring_pool.append(wave)
			_rings[index] = _rings.back()
			_rings.pop_back()

	for index in range(_collapses.size() - 1, -1, -1):
		var wreck := _collapses[index]
		wreck.life -= delta
		if wreck.life <= 0.0:
			_collapses.remove_at(index)


func burst(position: Vector2, tint: Color, count: int, impulse: float, direction := Vector2.ZERO) -> void:
	for index in mini(count, MAX_SPARKS - _sparks.size()):
		var spark: Spark = Spark.new() if _spark_pool.is_empty() else _spark_pool.pop_back()
		spark.position = position
		var drift := Vector2.from_angle(_rng.randf_range(0.0, TAU)) * _rng.randf_range(0.16, 1.0)
		spark.velocity = (drift + direction * 0.45) * impulse
		spark.duration = _rng.randf_range(0.16, 0.58)
		spark.life = spark.duration
		spark.tint = tint.lightened(0.35) if index % 3 == 0 else tint
		_sparks.append(spark)


func ring(position: Vector2, tint: Color, radius: float, duration: float) -> void:
	if _rings.size() >= MAX_RINGS:
		return
	var wave: Ring = Ring.new() if _ring_pool.is_empty() else _ring_pool.pop_back()
	wave.position = position
	wave.tint = tint
	wave.radius = radius
	wave.duration = duration
	wave.life = duration
	_rings.append(wave)


func render(canvas: Node2D, offset: Vector2, view: Rect2, pilot: Vector2) -> void:
	for wave in _rings:
		var origin := wave.position + offset
		var progress := 1.0 - wave.life / wave.duration
		var radius := maxf(4.0, wave.radius * ease(progress, 0.42))
		if not view.grow(radius).has_point(origin):
			continue
		var opacity := pow(1.0 - progress, 1.4)
		var clearance := absf(wave.position.distance_to(pilot) - radius)
		var separation := smoothstep(22.0, 83.0, clearance)
		canvas.draw_arc(origin, radius, 0.0, TAU, 36, Color(wave.tint, opacity * lerpf(0.22, 0.82, separation)), 1.7, true)
		if separation > 0.25:
			canvas.draw_arc(origin, radius * 0.89, 0.0, TAU, 32, Color(WHITE_HOT, opacity * separation * 0.33), 1.0, true)
	for spark in _sparks:
		var origin := spark.position + offset
		if not view.has_point(origin):
			continue
		var close_to_pilot := spark.position.distance_squared_to(pilot) < PILOT_CLEARANCE_SQ
		var opacity := spark.life / spark.duration * (0.26 if close_to_pilot else 0.84)
		if opacity > 0.08:
			canvas.draw_line(origin - spark.velocity * (0.019 if close_to_pilot else 0.031), origin, Color(spark.tint, opacity), 1.6, true)


func render_capital_breaks(canvas: Node2D, offset: Vector2, view: Rect2, pilot: Vector2) -> void:
	for wreck in _collapses:
		var center := wreck.position + offset
		var body := maxf(wreck.frame.size.x, wreck.frame.size.y)
		if not view.grow(body).has_point(center):
			continue
		var progress := 1.0 - wreck.life / COLLAPSE_LIFETIME
		var outward := sqrt(progress) * body
		var clearance := wreck.position.distance_to(pilot)
		var separation := lerpf(0.51, 1.0, smoothstep(42.0, body, clearance))
		var opacity := (1.0 - progress) * separation
		if wreck.texture != null:
			canvas.draw_set_transform(center + Vector2(12.0, 17.0) * progress, wreck.heading + progress * 0.22)
			var fade := opacity * (0.77 if progress < 0.5 else 0.64)
			canvas.draw_texture_rect(wreck.texture, wreck.frame, false, Color(wreck.tint.lightened(0.66), fade))
			canvas.draw_set_transform(Vector2.ZERO)
		var circum := maxf(6.0, outward * 0.91)
		canvas.draw_arc(center, circum, 0.0, TAU, 44, Color(wreck.tint, opacity * 0.81), 2.4, true)
		var inner := maxf(4.0, outward * 0.55)
		canvas.draw_arc(center, inner, 0.0, TAU, 36, Color(WHITE_HOT, opacity * 0.44), 1.2, true)
		if progress < 0.42:
			var flare := Vector2.ONE * (28.0 + progress * body * 0.77)
			var energy := (1.0 - progress / 0.42) * separation
			canvas.draw_texture_rect_region(LIGHTS, Rect2(center - flare * 0.5, flare), CONTACT,
				Color(wreck.tint.lightened(0.48), energy))
		for index in 4:
			var angle := wreck.heading + index * TAU / 4.0 + progress * 0.37
			var direction := Vector2.from_angle(angle)
			canvas.draw_line(center + direction * inner * 0.72, center + direction * circum,
				Color(wreck.tint, opacity * 0.63), 2.0, true)


func engine(canvas: Node2D, nozzle: Vector2, width: float, length: float, tint: Color, time: float) -> void:
	var flicker := 0.88 + 0.12 * sin(time * 59.0 + nozzle.x * 0.85) + 0.1 * cos(time * 97.0)
	var plume := length * flicker
	var outer := PackedVector2Array([
		nozzle + Vector2(-width, 0), nozzle + Vector2(width, 0),
		nozzle + Vector2(width * 0.82, plume * 0.31), nozzle + Vector2(width * 0.2, plume * 0.88),
		nozzle + Vector2(0, plume), nozzle + Vector2(-width * 0.4, plume * 0.76),
		nozzle + Vector2(-width * 0.8, plume * 0.31)
	])
	var inner := PackedVector2Array([
		nozzle + Vector2(-width * 0.56, -0.5), nozzle + Vector2(width * 0.56, -0.5),
		nozzle + Vector2(width * 0.44, plume * 0.27), nozzle + Vector2(0, plume * 0.68),
		nozzle + Vector2(-width * 0.37, plume * 0.31)
	])
	canvas.draw_polygon(outer, PackedColorArray([
		Color(tint, 0.42), Color(tint, 0.63), Color(tint, 0.3), Color(tint, 0.02),
		Color(tint, 0), Color(tint, 0.05), Color(tint, 0.33)
	]))
	canvas.draw_polygon(inner, PackedColorArray([
		Color(WHITE_HOT, 0.92), Color(WHITE_HOT, 0.92), Color(tint, 0.76),
		Color(tint, 0.03), Color(tint, 0.8)
	]))
	canvas.draw_line(nozzle + Vector2(0, 4.0), nozzle + Vector2(0, plume * 0.5), Color(WHITE_HOT, 0.47), 1.1, true)
