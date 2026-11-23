extends Control
## A small sector projection for product cards, with the game's own hull art when available.

const Palette := preload("res://ui/palette.gd")
const HangarGlyph := preload("res://ui/hangar_glyph.gd")
const Hulls := preload("res://data/progression_catalog.gd")
const CRYSTAL_ART := [
	preload("res://assets/art/crystals/zasobnik.webp"),
	preload("res://assets/art/crystals/kontener.webp"),
	preload("res://assets/art/crystals/rdzen.webp"),
]

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
	if motif == "crystals":
		var extent: Array[Vector2] = [Vector2(123, 116), Vector2(170, 124), Vector2(193, 151)]
		var index := clampi(rank - 1, 0, CRYSTAL_ART.size() - 1)
		custom_minimum_size = extent[index]
		_object(CRYSTAL_ART[index], Color.WHITE, 3.0)
	elif Hulls.SHIPS.has(motif):
		var path := "res://assets/art/ship_peregrine_preview.png" if motif == "peregrine" else str(Hulls.SHIPS[motif].sprite)
		_object(load(path), tint, 10.0)
	elif motif == "gear":
		for index in items.size():
			var item: Dictionary = Hulls.ITEMS[items[index]]
			var color := Palette.VIOLET if item.rarity == "epic" else Palette.CYAN
			_glimmer(item.slot, color, Vector2(-19, -15) if index == 0 else Vector2(17, 14), 53)
	elif motif == "season":
		_glimmer("reactor", accent, Vector2.ZERO, 80, true)


func _object(texture: Texture2D, color: Color, margin: float) -> void:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.modulate = color
	add_child(sprite)
	sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sprite.offset_left = margin
	sprite.offset_right = -margin
	sprite.offset_top = 4
	sprite.offset_bottom = -4


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
	if motif == "crystals":
		var shelf := size.y - 12.0
		draw_line(Vector2(9, shelf), Vector2(size.x - 9, shelf), Color(accent, 0.42), 1.2, true)
		if rank == 1:
			draw_line(Vector2(10, 22), Vector2(10, shelf), Color(accent, 0.25), 1.0)
			return
		if rank == 2:
			draw_line(Vector2(14, 18), Vector2(size.x - 18, 18), Color(accent, 0.18), 1.0)
			return
		draw_set_transform(center + Vector2(0, 10), 0.0, Vector2(1.0, 0.67))
		draw_arc(Vector2.ZERO, 78, -2.83, -0.2, 28, Color(accent, 0.33), 1.4, true)
		draw_set_transform(Vector2.ZERO)
		return
	for index in 3:
		draw_arc(center, 36.0 + index * 6.0, 0.32 + index * 0.43, 5.41 + index * 0.5, 36,
			Color(accent, 0.23 - index * 0.06), 1.0, true)
	for index in 8:
		var angle := TAU * float(index) / 8.0 + 0.15
		var axis := Vector2.from_angle(angle)
		draw_line(center + axis * 46.0, center + axis * 50.0, Color(accent, 0.4), 1.0, true)
