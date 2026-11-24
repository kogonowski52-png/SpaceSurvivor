extends Control
## Product illustrations with the same hull textures and livery treatment as the flight field.

const Palette := preload("res://ui/palette.gd")
const FlightArt := preload("res://vertical/flight_art.gd")
const Hulls := preload("res://data/progression_catalog.gd")
const CRYSTAL_ART := [
	preload("res://assets/art/crystals/zasobnik.webp"),
	preload("res://assets/art/crystals/kontener.webp"),
	preload("res://assets/art/crystals/rdzen.webp"),
]
const ILLUSTRATIONS := {
	"arsenal": preload("res://assets/art/store/arsenal.webp"),
	"supply": preload("res://assets/art/store/supply.webp"),
	"prism": preload("res://assets/art/store/prism.webp"),
	"season": preload("res://assets/art/store/helion.webp"),
	"salvage": preload("res://assets/art/store/salvage.webp"),
}
const SEALED_ARSENAL := preload("res://assets/art/store/arsenal_sealed.webp")
const MODULES := {
	"weapon": preload("res://assets/art/modules/weapon.webp"),
	"armor": preload("res://assets/art/modules/armor.webp"),
	"engine": preload("res://assets/art/modules/engine.webp"),
	"reactor": preload("res://assets/art/modules/reactor.webp"),
	"drone": preload("res://assets/art/modules/drone.webp"),
}

var motif := ""
var tint := Color.WHITE
var accent := Palette.CYAN
var extent := Vector2(172, 120)
var rank := 1
var items: Array = []
var opening := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = extent
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_contents = true
	if ILLUSTRATIONS.has(motif):
		var bounds := Rect2(Vector2.ZERO, Vector2.ONE)
		_image(ILLUSTRATIONS[motif], bounds, true)
		if motif == "arsenal" and opening:
			var cover := _image(SEALED_ARSENAL, bounds, true)
			var reveal := cover.create_tween().set_trans(Tween.TRANS_SINE)
			reveal.tween_interval(0.23)
			reveal.tween_property(cover, "modulate:a", 0.0, 0.37)
			reveal.tween_callback(cover.queue_free)
	elif motif == "crystals":
		_image(CRYSTAL_ART[clampi(rank - 1, 0, CRYSTAL_ART.size() - 1)], Rect2(0.05, 0.025, 0.90, 0.95))
	elif FlightArt.HULLS.has(motif):
		_image(FlightArt.hull(motif), Rect2(0.02, 0.01, 0.96, 0.96)).modulate = tint
	elif motif == "gear":
		for index in items.size():
			var module: Dictionary = Hulls.ITEMS[items[index]]
			var origin := Vector2(0.03, 0.04) if index == 0 else Vector2(0.37, 0.26)
			_image(MODULES[module.slot], Rect2(origin, Vector2(0.60, 0.67)))
	resized.connect(queue_redraw)


func _image(texture: Texture2D, area: Rect2, cover := false) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = texture
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(sprite)
	sprite.anchor_left = area.position.x
	sprite.anchor_top = area.position.y
	sprite.anchor_right = area.end.x
	sprite.anchor_bottom = area.end.y
	return sprite


func _draw() -> void:
	var low := Color("#081321")
	draw_style_box(Palette.panel(low, Color(accent, 0.22), 8), Rect2(Vector2.ZERO, size))
	if ILLUSTRATIONS.has(motif):
		return
	var baseline := size.y - 9.0
	draw_line(Vector2(12, baseline), Vector2(size.x - 12, baseline), Color(accent, 0.24), 1.0, true)
