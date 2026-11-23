extends SceneTree
## Bake the flight-scale keyline into the original artwork once. No per-enemy shader pass.

const ART := "res://assets/art/"
const MARGIN := 13
const HULLS := {
	"enemy_scout": Color("#eec192"),
	"enemy_razor": Color("#9ee3d0"),
	"enemy_elite": Color("#e3a9cd"),
}


func _initialize() -> void:
	var failed := false
	for name: String in HULLS:
		var source := Image.load_from_file(ProjectSettings.globalize_path(ART + name + ".png"))
		if source == null:
			failed = true
			continue
		var result := _bake(source, HULLS[name])
		failed = result.save_png(ART + name + "_flight.png") != OK or failed
	quit(1 if failed else 0)


func _bake(source: Image, rim: Color) -> Image:
	var area := Rect2i(Vector2i.ZERO, source.get_size())
	var out := Image.create_empty(area.size.x + MARGIN * 2, area.size.y + MARGIN * 2, false, Image.FORMAT_RGBA8)
	var keyline := _kernel(4.8)
	var backing := _kernel(12.3)
	for y in out.get_height():
		for x in out.get_width():
			var point := Vector2i(x - MARGIN, y - MARGIN)
			var hull := source.get_pixelv(point) if area.has_point(point) else Color.TRANSPARENT
			if hull.a > 0.995:
				out.set_pixel(x, y, _lift(hull, rim))
				continue
			var edge := smoothstep(0.21, 0.92, _coverage(source, area, point, keyline))
			var shadow := smoothstep(0.29, 0.97, _coverage(source, area, point, backing))
			var pixel := Color(0.016, 0.025, 0.050, shadow * 0.68)
			pixel = pixel.blend(Color(rim, edge * 0.50))
			out.set_pixel(x, y, pixel.blend(_lift(hull, rim)))
	return out


func _kernel(radius: float) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = [Vector2i.ZERO]
	for index in 14:
		var direction := Vector2.from_angle(TAU * index / 14.0)
		offsets.append(Vector2i((direction * radius).round()))
	return offsets


func _coverage(source: Image, area: Rect2i, point: Vector2i, offsets: Array[Vector2i]) -> float:
	var strongest := 0.0
	for offset in offsets:
		var sample := point + offset
		if area.has_point(sample):
			strongest = maxf(strongest, source.get_pixelv(sample).a)
			if strongest >= 0.995:
				break
	return strongest


func _lift(hull: Color, rim: Color) -> Color:
	var luma := hull.get_luminance()
	var light := smoothstep(0.05, 0.64, luma)
	var metal := (hull * (1.10 + 0.10 * light)).lerp(rim, 0.055 * light)
	return Color(metal.clamp(), hull.a)
