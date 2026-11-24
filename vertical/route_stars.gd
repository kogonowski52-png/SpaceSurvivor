extends Control

const STAR_SIZE := 17.0
const GAP := 5.0

var grade := 0
var accent := Color("#ffe0a0")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(STAR_SIZE * 3.0 + GAP * 2.0, 20.0)
	accessibility_name = "Gwiazdy %d z 3" % grade


func _draw() -> void:
	var points := PackedVector2Array()
	for index in 3:
		points.clear()
		var center := Vector2(STAR_SIZE * 0.5 + index * (STAR_SIZE + GAP), size.y * 0.5)
		for corner in 10:
			var radius := STAR_SIZE * (0.49 if corner % 2 == 0 else 0.23)
			points.append(center + Vector2.from_angle(corner * TAU / 10.0 - PI * 0.5) * radius)
		draw_colored_polygon(points, accent if index < grade else Color("#23354a"))
		points.append(points[0])
		draw_polyline(points, Color(accent, 0.94) if index < grade else Color("#5c7389"), 1.0, true)
