extends Control
## Schematic equipment illustrations share a frame with the hangar cargo display.

var kind := ""
var tint := Color.WHITE
var variation := 0
var legendary := false
var _cycle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(legendary)


func _process(delta: float) -> void:
	_cycle = fposmod(_cycle + delta * 0.85, TAU)
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var scale_factor := clampf(minf(size.x, size.y) / 52.0, 0.59, 1.60)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	var frame := PackedVector2Array([
		Vector2(-22, -14), Vector2(-14, -22), Vector2(14, -22), Vector2(22, -14),
		Vector2(22, 14), Vector2(14, 22), Vector2(-14, 22), Vector2(-22, 14),
	])
	draw_colored_polygon(frame, Color(tint, 0.066 if not legendary else 0.14))
	frame.append(frame[0])
	draw_polyline(frame, Color(tint, 0.37 if not legendary else 0.73), 1.0, true)
	_stroke([Vector2(-19, 0), Vector2(-16, 0)], 0.43)
	_stroke([Vector2(16, 0), Vector2(19, 0)], 0.43)
	match kind:
		"weapon":
			_weapon()
		"armor":
			_armor()
		"engine":
			_engine()
		"reactor":
			_reactor()
		"drone":
			_drone()
		"crate":
			_crate()
	if legendary:
		var glint := sin(_cycle) * 0.20
		var upper: Array[Vector2] = [Vector2(-17, -15), Vector2(-12, -20), Vector2(-5, -20)]
		var lower: Array[Vector2] = [Vector2(17, 15), Vector2(12, 20), Vector2(5, 20)]
		_stroke(upper, 0.18 + glint * 0.5, 3.1)
		_stroke(lower, 0.18 - glint * 0.5, 3.1)
		_stroke(upper, 0.78 + glint)
		_stroke(lower, 0.78 - glint)
		for x in [-5.0, 0.0, 5.0]:
			draw_circle(Vector2(x, 14.5), 0.95, tint, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)


func _weapon() -> void:
	var barrel_y := -12.0 + (variation % 3) * 1.5
	_plate([Vector2(-5, barrel_y), Vector2(5, barrel_y), Vector2(5, -5), Vector2(8, -1),
		Vector2(8, 8), Vector2(3, 11), Vector2(-3, 11), Vector2(-8, 8),
		Vector2(-8, -1), Vector2(-5, -5)])
	_stroke([Vector2(-2.5, barrel_y), Vector2(-2.5, 3), Vector2(2.5, 3), Vector2(2.5, barrel_y)], 0.76)
	for side in [-1, 1]:
		var x: float = side * (10.0 + variation % 2)
		_stroke([Vector2(x, 5), Vector2(x, -7), Vector2(side * 7, -5)], 0.58)
		draw_circle(Vector2(side * 5.2, 6), 1.2, tint, true, -1.0, true)


func _armor() -> void:
	var shoulder := 10.0 + variation % 3
	_plate([Vector2(0, -12), Vector2(shoulder, -7), Vector2(9, 4),
		Vector2(0, 12), Vector2(-9, 4), Vector2(-shoulder, -7)])
	_stroke([Vector2(-8, -3), Vector2(0, -6), Vector2(8, -3)], 0.63)
	_stroke([Vector2(-7, 2), Vector2(0, 0), Vector2(7, 2)], 0.80)
	_stroke([Vector2(-5, 6), Vector2(0, 9), Vector2(5, 6)], 0.61)


func _engine() -> void:
	_plate([Vector2(-8, -10), Vector2(8, -10), Vector2(12, -1), Vector2(7, 5),
		Vector2(-7, 5), Vector2(-12, -1)])
	_stroke([Vector2(-8, -4), Vector2(8, -4)], 0.67)
	_stroke([Vector2(-7, 1), Vector2(7, 1)], 0.89)
	for x in [-5.0, 0.0, 5.0]:
		_stroke([Vector2(x, 7), Vector2(x, 10.0 + variation % 3)], 0.71 if x != 0 else 1.0, 2.0)


func _reactor() -> void:
	_plate([Vector2(0, -13), Vector2(11, -6), Vector2(11, 6),
		Vector2(0, 13), Vector2(-11, 6), Vector2(-11, -6)])
	draw_arc(Vector2.ZERO, 7.5, 0.35, TAU + 0.05, 22, Color(tint, 0.64), 1.1, true)
	var core_offset := Vector2(3 - variation % 3, -6)
	_plate([core_offset, Vector2(-5, 1), Vector2(-0.5, 1),
		Vector2(-2.5, 7), Vector2(5, -1), Vector2(1.5, -1)], 0.85)


func _drone() -> void:
	var pod := 11.0 + variation % 3
	_plate([Vector2(0, -12), Vector2(pod, -4), Vector2(10, 6), Vector2(5, 5),
		Vector2(0, 10), Vector2(-5, 5), Vector2(-10, 6), Vector2(-pod, -4)])
	_stroke([Vector2(-9, -4), Vector2(0, -1.5), Vector2(9, -4)], 0.65)
	_stroke([Vector2(-3, 7), Vector2(0, 12.5), Vector2(3, 7)], 0.61)
	draw_circle(Vector2(0, -4), 2.0, tint, true, -1.0, true)


func _crate() -> void:
	_plate([Vector2(-12, -8), Vector2(12, -8), Vector2(14, 6), Vector2(9, 11),
		Vector2(-9, 11), Vector2(-14, 6)])
	_stroke([Vector2(-13, 0), Vector2(13, 0)], 0.7)
	_stroke([Vector2(-7, -11), Vector2(7, -11)], 0.72)
	_plate([Vector2(-3.5, -2.5), Vector2(3.5, -2.5), Vector2(3.5, 4), Vector2(-3.5, 4)], 0.43)


func _plate(points: Array[Vector2], fill := 0.19) -> void:
	var path := PackedVector2Array(points)
	draw_colored_polygon(path, Color(tint, fill))
	path.append(points[0])
	draw_polyline(path, tint, 1.25, true)


func _stroke(points: Array[Vector2], opacity := 1.0, width := 1.2) -> void:
	draw_polyline(PackedVector2Array(points), Color(tint, opacity), width, true)
