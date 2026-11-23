extends SceneTree
## Offline light atlas. The eight beam frames, projectile and contact flare share one texture.

const EMISSION := Color("#5bdacc")
const HOT := Color("#f0feff")


func _initialize() -> void:
	var atlas := Image.create_empty(256, 280, false, Image.FORMAT_RGBA8)
	for layer in 8:
		for y in 24:
			for x in 256:
				atlas.set_pixel(x, y + layer * 24, _beam(float(x) / 255.0, float(y) / 23.0 * 2.0 - 1.0, layer * TAU / 8.0))
	for y in 24:
		for x in 128:
			var length := float(x) / 127.0
			var cross_axis := float(y) / 23.0 * 2.0 - 1.0
			atlas.set_pixel(x, y + 192, _streak(length, cross_axis, false))
			atlas.set_pixel(x + 128, y + 192, _streak(length, cross_axis, true))
	for y in 64:
		for x in 64:
			var coord := Vector2(x, y) / 31.5 - Vector2.ONE
			atlas.set_pixel(x, y + 216, _contact(coord))
		for x in 96:
			var coord := Vector2(x / 47.5 - 1.0, y / 31.5 - 1.0)
			var fade := 1.0 - smoothstep(0.42, 0.99, coord.length())
			atlas.set_pixel(x + 64, y + 216, Color(0.018, 0.035, 0.065, 0.74 * fade))
	quit(0 if atlas.save_png("res://assets/art/flight_lights.png") == OK else 1)


func _beam(x: float, y: float, phase: float) -> Color:
	var head := smoothstep(0.0, 0.027, x)
	var tail := 1.0 - smoothstep(0.91, 1.0, x)
	var helix := sin(x * 62.0 - phase) * 0.30
	var core := 1.0 - smoothstep(0.035, 0.22, absf(y - helix * 0.15))
	var filament := (1.0 - smoothstep(0.01, 0.083, absf(y - helix))) * 0.55
	var haze := (1.0 - smoothstep(0.18, 0.94, absf(y))) * 0.20
	var packets := 0.48 + 0.52 * pow(0.5 + 0.5 * sin(x * 89.0 - phase), 3.0)
	var intensity := clampf(core + filament * packets + haze, 0.0, 1.0)
	return Color(EMISSION.lerp(HOT, clampf(core + filament * packets * 0.6, 0.0, 1.0)), intensity * head * tail)


func _streak(x: float, y: float, hostile: bool) -> Color:
	var width := lerpf(0.14, 0.76, smoothstep(0.08, 0.88, x))
	var profile := 1.0 - smoothstep(width * 0.17, width, absf(y))
	var core := (1.0 - smoothstep(0.04, width * 0.58, absf(y))) * smoothstep(0.29, 0.88, x)
	var envelope := smoothstep(0.01, 0.59, x) * (1.0 - smoothstep(0.89, 1.0, x))
	var light := lerpf(0.53, 1.0, core)
	if hostile:
		var tip := core * smoothstep(0.63, 0.94, x)
		return Color(Color("#f15245").lerp(Color("#fff6d9"), tip), envelope * (0.62 * profile + 0.38 * core))
	return Color(light, light, light, envelope * (0.72 * profile + 0.28 * core))


func _contact(coord: Vector2) -> Color:
	var radius := coord.length()
	var core := 1.0 - smoothstep(0.025, 0.34, radius)
	var angle := coord.angle()
	var fingers := (0.4 + 0.6 * cos(angle * 5.0 + radius * 6.4)) * pow(absf(sin(angle * 3.0 - 0.31)), 12.0)
	var rays := maxf(0.0, fingers) * (1.0 - smoothstep(0.08, 0.91, radius))
	return Color(EMISSION.lerp(HOT, core * 0.87), clampf(core + rays * 0.73, 0.0, 1.0))
