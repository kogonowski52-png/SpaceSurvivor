extends Control
## A small sector projection for product cards, with the game's own hull art when available.

const Palette := preload("res://ui/palette.gd")
const HangarGlyph := preload("res://ui/hangar_glyph.gd")
const Hulls := preload("res://data/progression_catalog.gd")

var motif := ""
var tint := Color.WHITE
var accent := Palette.CYAN
var rank := 1
var items: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(112, 105)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)
	if Hulls.SHIPS.has(motif):
		var sprite := TextureRect.new()
		var path := "res://assets/art/ship_peregrine_preview.png" if motif == "peregrine" else str(Hulls.SHIPS[motif].sprite)
		sprite.texture = load(path)
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.modulate = tint
		add_child(sprite)
		sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sprite.offset_left = 11
		sprite.offset_right = -11
		sprite.offset_top = 4
		sprite.offset_bottom = -4
	elif motif == "gear":
		for index in items.size():
			var item: Dictionary = Hulls.ITEMS[items[index]]
			var color := Palette.VIOLET if item.rarity == "epic" else Palette.CYAN
			_glimmer(item.slot, color, Vector2(-19, -15) if index == 0 else Vector2(17, 14), 53)
	elif motif == "season":
		_glimmer("reactor", accent, Vector2.ZERO, 80, true)


func _glimmer(kind: String, color: Color, center_offset: Vector2, extent: float, animated := false) -> void:
	var glyph := HangarGlyph.new()
	glyph.kind = kind
	glyph.tint = color
	glyph.legendary = animated
	add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var radius := extent * 0.5
	glyph.offset_left = center_offset.x - radius
	glyph.offset_right = center_offset.x + radius
	glyph.offset_top = center_offset.y - radius
	glyph.offset_bottom = center_offset.y + radius


func _draw() -> void:
	var center := size * Vector2(0.5, 0.5)
	for index in 3:
		draw_arc(center, 36.0 + index * 6.0, 0.32 + index * 0.43, 5.41 + index * 0.5, 36,
			Color(accent, 0.23 - index * 0.06), 1.0, true)
	for index in 8:
		var angle := TAU * float(index) / 8.0 + 0.15
		var axis := Vector2.from_angle(angle)
		draw_line(center + axis * 46.0, center + axis * 50.0, Color(accent, 0.4), 1.0, true)
	if motif == "crystals":
		if rank == 3:
			_crystal(center + Vector2(-35, -2), 0.57, -0.48)
			_crystal(center + Vector2(31, -12), 0.68, 0.42)
		if rank >= 2:
			_crystal(center + Vector2(-22, 10), 0.66, -0.28)
			_crystal(center + Vector2(24, 11), 0.69, 0.31)
		_crystal(center - Vector2(0, 3), 1.04, 0.06)


func _crystal(center: Vector2, scale_factor: float, angle: float) -> void:
	draw_set_transform(center, angle, Vector2.ONE * scale_factor)
	var top := Vector2(0, -38)
	var left := Vector2(-16, -18)
	var right := Vector2(16, -15)
	var bottom := Vector2(0, 32)
	var lower_left := Vector2(-12, 13)
	var lower_right := Vector2(14, 12)
	var core := Vector2(3, -12)
	draw_colored_polygon(PackedVector2Array([top, left, lower_left, bottom, lower_right, right]), Color("#20254e"))
	draw_colored_polygon(PackedVector2Array([top, left, lower_left, bottom, core]), Color("#5658b0"))
	draw_colored_polygon(PackedVector2Array([top, right, lower_right, bottom, core]), Color("#926ce2"))
	draw_colored_polygon(PackedVector2Array([top, right, core]), Color("#d7c6ff"))
	draw_polyline(PackedVector2Array([top, left, lower_left, bottom, lower_right, right, top]), Color("#a99cff"), 1.5, true)
	draw_polyline(PackedVector2Array([top, core, bottom]), Color("#d0c5ff"), 1.3, true)
	draw_line(left, right, Color("#f2e6ff70"), 1.1, true)
	draw_line(lower_left, right, Color("#eee0ff56"), 1.0, true)
	draw_set_transform(Vector2.ZERO)
