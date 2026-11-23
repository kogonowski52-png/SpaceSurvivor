extends PanelContainer
## Optional debug display. PSS is sampled sparingly because Android computes it on demand.

const Palette := preload("res://ui/palette.gd")
const ReadoutFont := preload("res://assets/fonts/Barlow-Medium.ttf")

var arena_provider: Callable
var _readout: Label
var _bridge: Object
var _sample_in := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", Palette.panel(Color("#0b1826ee"), Palette.OUTLINE, 8, 9.0))
	_readout = Label.new()
	_readout.name = "DebugFlightReadout"
	_readout.add_theme_font_override("font", ReadoutFont)
	_readout.add_theme_font_size_override("font_size", 18)
	_readout.add_theme_color_override("font_color", Palette.TEXT)
	add_child(_readout)
	if Engine.has_singleton("GalaxyCommerce"):
		_bridge = Engine.get_singleton("GalaxyCommerce")
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 20.0
	offset_right = 250.0
	var bottom_inset := 0.0
	if OS.has_feature("android"):
		var safe := DisplayServer.get_display_safe_area()
		var height := DisplayServer.screen_get_size().y
		if safe.has_area() and height > 0:
			bottom_inset = (height - safe.end.y) * get_viewport_rect().size.y / height
	offset_top = -155.0 - bottom_inset
	offset_bottom = -90.0 - bottom_inset


func _process(delta: float) -> void:
	var arena: Node = arena_provider.call()
	visible = is_instance_valid(arena)
	if not visible:
		_sample_in = 0.0
		return
	_sample_in -= delta
	if _sample_in > 0.0:
		return
	_sample_in = 2.0
	var bytes := OS.get_static_memory_usage()
	var source := "GODOT"
	if _bridge != null:
		bytes = int(_bridge.diagnosticPssKib()) * 1024
		source = "PSS"
	var memory := "%.1f MiB" % (bytes / 1048576.0) if bytes > 0 else "n/d"
	_readout.text = "%d FPS   ·   %d WROGÓW\n%s   %s" % [Engine.get_frames_per_second(), arena.active_enemy_count(), source, memory]
