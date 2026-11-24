extends RefCounted
## The nebula, planet and three star speeds share a low-contrast flight corridor.

const SIZE := Vector2(540.0, 960.0)
const STAR_LOOP := 1_290.0
const STAR_LAYERS := [21.0, 63.0, 123.0]

var _nebula: Texture2D
var _planet: Texture2D
var _orbit := Vector2.ZERO
var _tone := Color.WHITE
var _stars := PackedVector2Array()
var _magnetic := false


func configure(stage: Dictionary) -> void:
	_nebula = load(stage.sky)
	_planet = load(stage.planet)
	_orbit = stage.planet_offset
	_tone = stage.tone
	_magnetic = str(stage.get("scape", "")) == "magnetic"
	var rng := RandomNumberGenerator.new()
	rng.seed = 726_571 + int(stage.threat) * 7
	for index in 60:
		_stars.append(Vector2(rng.randf_range(0.0, SIZE.x), rng.randf_range(0.0, STAR_LOOP)))


func draw(canvas: Node2D, view: Rect2, time: float, pilot_x: float, energy: float) -> void:
	if view.size.x > SIZE.x + 0.5:
		canvas.draw_rect(view, Color("#040915"))
	var drift := fposmod(time * 28.0, SIZE.y * 2.0)
	var tone := Color("#9aacc8").lerp(_tone.lightened(0.38), energy * 0.23)
	for index in range(-3, 2):
		var top := drift + index * SIZE.y
		if top > view.end.y or top + SIZE.y < view.position.y:
			continue
		var flip := posmod(index, 2) == 1
		canvas.draw_set_transform(Vector2(0.0, top + SIZE.y if flip else top), 0.0, Vector2(1.0, -1.0 if flip else 1.0))
		canvas.draw_texture_rect(_nebula, Rect2(Vector2.ZERO, SIZE + Vector2(0.0, 1.0)), false, tone)
	canvas.draw_set_transform(Vector2.ZERO)

	var moon := _orbit + Vector2(-pilot_x * 0.043, fposmod(time * 8.4 + _orbit.y + 240.0, 1_500.0) - 240.0 - _orbit.y)
	var diameter := _planet.get_size().normalized() * 344.0
	canvas.draw_texture_rect(_planet, Rect2(moon - diameter * 0.5, diameter), false, Color(0.69, 0.75, 0.86, 0.72))
	if _magnetic and energy > 0.1:
		for side: int in [-1, 1]:
			var arc := PackedVector2Array()
			for segment in 9:
				var x := 270.0 + side * (213.0 + sin(segment * 8.3 + time * 19.0) * 27.0)
				arc.append(Vector2(x, 56.0 + segment * 72.0))
			canvas.draw_polyline(arc, Color("#a6ecfc", energy * 0.27), 2.0, true)

	for index in _stars.size():
		var layer := index % STAR_LAYERS.size()
		var point := _stars[index]
		point.y = fposmod(point.y + time * float(STAR_LAYERS[layer]), STAR_LOOP) - 165.0
		point.x = fposmod(point.x - pilot_x * (0.008 + 0.012 * layer), SIZE.x)
		var brightness := 0.27 + 0.15 * sin(time * 2.0 + index * 1.87) + energy * 0.10
		if layer == 2:
			canvas.draw_line(point, point - Vector2(0.0, 6.0 + energy * 9.0), Color(_tone, brightness * 0.68), 1.1, true)
		else:
			canvas.draw_circle(point, 0.87 + layer * 0.39, Color("#d6e8ff", brightness + 0.14), true, -1.0, true)
	if view.position.y < -0.5:
		canvas.draw_rect(Rect2(0.0, view.position.y, SIZE.x, -view.position.y), Color("#05091278"))
		canvas.draw_rect(Rect2(0.0, SIZE.y, SIZE.x, view.end.y - SIZE.y), Color("#05091278"))
		canvas.draw_line(Vector2.ZERO, Vector2(SIZE.x, 0.0), Color(_tone, 0.23), 1.0)
		canvas.draw_line(Vector2(0.0, SIZE.y), SIZE, Color(_tone, 0.23), 1.0)
