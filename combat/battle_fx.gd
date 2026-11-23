extends RefCounted

const MAX_SPARKS := 216
const MAX_RINGS := 20
const MAX_COLLAPSES := 2
const COLLAPSE_LIFETIME := 0.88
const CYAN := Color("#7deaff")
const WHITE_HOT := Color("#effbff")

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

var _plume: Texture2D
var _collapses: Array[Collapse] = []

var _rng := RandomNumberGenerator.new()
var _sparks: Array[Spark] = []
var _rings: Array[Ring] = []
var _spark_pool: Array[Spark] = []
var _ring_pool: Array[Ring] = []


func prepare() -> void:
	# The short thruster plume is baked once so regular ships only need one draw each.
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


func render(canvas: Node2D, offset: Vector2, view: Rect2) -> void:
	for wave in _rings:
		var origin := wave.position + offset
		var progress := 1.0 - wave.life / wave.duration
		var radius := maxf(4.0, wave.radius * ease(progress, 0.42))
		if not view.grow(radius).has_point(origin):
			continue
		var opacity := pow(1.0 - progress, 1.4)
		canvas.draw_arc(origin, radius, 0.0, TAU, 40, Color(wave.tint, opacity * 0.17), 9.0, true)
		canvas.draw_arc(origin, radius, 0.0, TAU, 40, Color(wave.tint, opacity * 0.9), 1.8, true)
		canvas.draw_arc(origin, radius * 0.89, 0.0, TAU, 36, Color(WHITE_HOT, opacity * 0.4), 1.0, true)
	for spark in _sparks:
		var origin := spark.position + offset
		if not view.has_point(origin):
			continue
		var opacity := spark.life / spark.duration
		canvas.draw_line(origin - spark.velocity * 0.031, origin, Color(spark.tint, opacity), 1.7, true)


func render_capital_breaks(canvas: Node2D, offset: Vector2, view: Rect2) -> void:
	for wreck in _collapses:
		var center := wreck.position + offset
		var body := maxf(wreck.frame.size.x, wreck.frame.size.y)
		if not view.grow(body).has_point(center):
			continue
		var progress := 1.0 - wreck.life / COLLAPSE_LIFETIME
		var outward := sqrt(progress) * body
		var opacity := 1.0 - progress
		if wreck.texture != null:
			canvas.draw_set_transform(center + Vector2(12.0, 17.0) * progress, wreck.heading + progress * 0.22)
			var fade := opacity * (0.77 if progress < 0.5 else 0.64)
			canvas.draw_texture_rect(wreck.texture, wreck.frame, false, Color(wreck.tint.lightened(0.66), fade))
			canvas.draw_set_transform(Vector2.ZERO)
		var circum := maxf(6.0, outward * 0.91)
		canvas.draw_arc(center, circum, 0.0, TAU, 44, Color(wreck.tint, opacity * 0.81), 2.4, true)
		var inner := maxf(4.0, outward * 0.55)
		canvas.draw_arc(center, inner, 0.0, TAU, 36, Color(WHITE_HOT, opacity * 0.44), 1.2, true)
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
