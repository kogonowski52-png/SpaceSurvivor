extends "res://combat/battle_fx.gd"
## Capped texture animations add readable hits without spawning particle scene nodes.

const FIRE := preload("res://assets/art/premium/effects/explosion.webp")
const ION := preload("res://assets/art/premium/effects/plasma.webp")
const ROCKET := preload("res://assets/art/premium/effects/rocket.webp")
const MAX_FLASHES := 14
const MAX_DEBRIS := 10

class Flare:
	var at := Vector2.ZERO
	var age := 1.0
	var span := 0.4
	var size := 0.0
	var angle := 0.0
	var tex: Texture2D

class Debris:
	var at := Vector2.ZERO
	var life := 0.0
	var frame := Rect2()
	var angle := 0.0
	var hull: Texture2D

var _flares: Array[Flare] = []
var _debris: Array[Debris] = []
var _next_flare := 0
var _next_debris := 0


func prepare() -> void:
	super.prepare()
	for index in MAX_FLASHES:
		_flares.append(Flare.new())
	for index in MAX_DEBRIS:
		_debris.append(Debris.new())


func step(delta: float) -> void:
	super.step(delta)
	for effect in _flares:
		effect.age += delta
	for wreck in _debris:
		wreck.life = maxf(0.0, wreck.life - delta)


func blast(at: Vector2, extent: float, ionized := false, span := 0.44) -> void:
	var slot := _flares[_next_flare]
	_next_flare = (_next_flare + 1) % MAX_FLASHES
	slot.at = at
	slot.age = 0.0
	slot.span = span
	slot.size = extent
	slot.angle = _rng.randf_range(-PI, PI)
	slot.tex = ION if ionized else FIRE


func shatter(hull: Texture2D, at: Vector2, frame: Rect2, angle: float) -> void:
	var slot := _debris[_next_debris]
	_next_debris = (_next_debris + 1) % MAX_DEBRIS
	slot.at = at
	slot.life = 0.48
	slot.frame = frame
	slot.angle = angle
	slot.hull = hull


func draw_flares(canvas: Node2D, view: Rect2, pilot: Vector2) -> void:
	for wreck in _debris:
		if wreck.life <= 0.0 or not view.has_point(wreck.at):
			continue
		var age := 1.0 - wreck.life / 0.48
		var image := wreck.hull.get_size()
		var width := wreck.frame.size.x * 0.5
		for side: int in [-1, 1]:
			var origin := wreck.at + Vector2(side * 23.0 * age, 20.0 * age)
			canvas.draw_set_transform(origin, wreck.angle + side * age * 0.56)
			var tint := Color(0.85, 0.72, 0.69, (1.0 - age) * 0.88)
			var part := 0.0 if side == -1 else 1.0
			var destination := Rect2(wreck.frame.position + Vector2(part * width, 0.0), Vector2(width, wreck.frame.size.y))
			var source := Rect2(Vector2(part * image.x * 0.5, 0.0), Vector2(image.x * 0.5, image.y))
			canvas.draw_texture_rect_region(wreck.hull, destination, source, tint)
	for flare in _flares:
		if flare.age >= flare.span or not view.has_point(flare.at):
			continue
		var progress := flare.age / flare.span
		var expansion := lerpf(0.33, 1.37, 1.0 - pow(1.0 - progress, 1.85))
		var height := flare.size * expansion
		var alpha := smoothstep(0.0, 0.11, progress) * (1.0 - smoothstep(0.22, 1.0, progress))
		if flare.at.distance_squared_to(pilot) < 103.0 * 103.0:
			alpha *= 0.48
		canvas.draw_set_transform(flare.at, flare.angle)
		canvas.draw_texture_rect(flare.tex, Rect2(Vector2(-height * 0.5, -height * 0.5), Vector2(height, height)), false,
			Color(1.0, 0.96, 0.94, alpha))
	canvas.draw_set_transform(Vector2.ZERO)


func missile(canvas: Node2D, center: Vector2, heading: float, tint: Color, pulse: float) -> void:
	canvas.draw_set_transform(center, heading + PI * 0.5)
	small_engine(canvas, Vector2(0.0, 6.0), 3.4, 24.0, tint, pulse)
	canvas.draw_texture_rect(ROCKET, Rect2(-4.1, -10.0, 8.2, 20.0), false, Color.WHITE)
	canvas.draw_set_transform(Vector2.ZERO)
