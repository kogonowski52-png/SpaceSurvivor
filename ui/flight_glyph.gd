extends Control

var glyph := ""
var tint := Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	match glyph:
		"pause":
			_line(center, Vector2(-4, -7), Vector2(-4, 7), 2.7)
			_line(center, Vector2(4, -7), Vector2(4, 7), 2.7)
		"arrow":
			_line(center, Vector2(-8, 0), Vector2(9, 0))
			_line(center, Vector2(3, -6), Vector2(9, 0))
			_line(center, Vector2(9, 0), Vector2(3, 6))
		"repair":
			_line(center, Vector2(-10, 0), Vector2(10, 0), 2.8)
			_line(center, Vector2(0, -10), Vector2(0, 10), 2.8)
		"shield":
			_path(center, [Vector2(0, -12), Vector2(10, -8), Vector2(8, 4),
				Vector2(0, 11), Vector2(-8, 4), Vector2(-10, -8), Vector2(0, -12)])
			_path(center, [Vector2(-3, 1), Vector2(0, 4), Vector2(5, -3)])
		"missiles", "missile_cluster":
			_path(center, [Vector2(-10, 5), Vector2(-4, -10), Vector2(-1, 1),
				Vector2(-10, 5)])
			_path(center, [Vector2(0, 1), Vector2(8, -12), Vector2(11, -1),
				Vector2(0, 1)])
			_line(center, Vector2(-9, 8), Vector2(-11, 12))
			_line(center, Vector2(3, 5), Vector2(1, 9))
			if glyph == "missile_cluster":
				_path(center, [Vector2(8, 10), Vector2(12, 2), Vector2(15, 7), Vector2(8, 10)])
		"nova":
			draw_arc(center, 11.0, -PI * 0.95, PI * 0.81, 22, tint, 1.8, true)
			draw_circle(center, 2.5, tint, true, -1.0, true)
			draw_circle(center + Vector2(7.8, -7.8), 3.6, tint, true, -1.0, true)
			draw_circle(center + Vector2(-7.8, 7.8), 3.6, tint, true, -1.0, true)
		"laser":
			_line(center, Vector2(-12, 8), Vector2(8, -6), 2.5)
			_line(center, Vector2(-12, 2), Vector2(-2, -6), 1.4)
			_line(center, Vector2(-8, 12), Vector2(2, 5), 1.4)
			_path(center, [Vector2(4, -9), Vector2(13, -11), Vector2(12, -2)])
		"tesla", "tesla_branch":
			_path(center, [Vector2(-12, 8), Vector2(-4, 0), Vector2(1, 3),
				Vector2(6, -8), Vector2(12, -9)])
			_path(center, [Vector2(-4, 0), Vector2(-4, -6), Vector2(-9, -9)])
			draw_circle(center + Vector2(12, -9), 2.0, tint, true, -1.0, true)
			if glyph == "tesla_branch":
				_path(center, [Vector2(1, 3), Vector2(7, 4), Vector2(11, 10)])
				draw_circle(center + Vector2(11, 10), 2.0, tint, true, -1.0, true)
		"drones":
			_path(center, [Vector2(-13, 6), Vector2(-9, -1), Vector2(-5, 6), Vector2(-13, 6)])
			_path(center, [Vector2(-5, -2), Vector2(0, -12), Vector2(5, -2), Vector2(-5, -2)])
			_path(center, [Vector2(5, 6), Vector2(9, -1), Vector2(13, 6), Vector2(5, 6)])
			_line(center, Vector2(-9, 9), Vector2(-5, 11))
			_line(center, Vector2(9, 9), Vector2(5, 11))
		"pulse_crossfire":
			_path(center, [Vector2(-11, 9), Vector2(-7, 0), Vector2(-9, -7)])
			_path(center, [Vector2(11, 9), Vector2(7, 0), Vector2(9, -7)])
			_line(center, Vector2(0, 8), Vector2(0, -12), 2.5)
		"salvage":
			_path(center, [Vector2(0, -11), Vector2(10, -5), Vector2(10, 5),
				Vector2(0, 11), Vector2(-10, 5), Vector2(-10, -5), Vector2(0, -11)])
			_path(center, [Vector2(-10, -5), Vector2(0, 1), Vector2(10, -5)])
			_line(center, Vector2(0, 1), Vector2(0, 10))
		"tractor":
			_path(center, [Vector2(-13, -9), Vector2(-5, 0), Vector2(-13, 9)])
			_path(center, [Vector2(13, -9), Vector2(5, 0), Vector2(13, 9)])
			draw_circle(center, 2.0, tint, true, -1.0, true)
		"thruster", "pulse_cadence":
			for shift in [-6.0, 3.0]:
				_path(center, [Vector2(shift - 4, -9), Vector2(shift + 4, 0),
					Vector2(shift - 4, 9)])
		_:
			_path(center, [Vector2(3, -12), Vector2(-7, 1), Vector2(0, 1),
				Vector2(-3, 12), Vector2(9, -2), Vector2(2, -2), Vector2(3, -12)])


func _line(center: Vector2, start: Vector2, end: Vector2, width: float = 1.8) -> void:
	draw_line(center + start, center + end, tint, width, true)


func _path(center: Vector2, vertices: Array[Vector2]) -> void:
	var points := PackedVector2Array()
	for point in vertices:
		points.append(center + point)
	draw_polyline(points, tint, 1.8, true)
