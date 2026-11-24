extends PanelContainer
## Readout stays outside the touch path. PSS is sampled sparingly.

const Palette := preload("res://ui/palette.gd")
const SafeLayout := preload("res://ui/safe_layout.gd")
const ReadoutFont := preload("res://assets/fonts/Barlow-Medium.ttf")
const Report := preload("res://data/android_diagnostics.gd")

var arena_provider: Callable
var live_frame: Callable
var diagnostics: Report
var _readout: Label
var _bridge: Object
var _sample_in := 0.0
var _last_frame := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", Palette.panel(Color("#0b1826ee"), Palette.OUTLINE, 8, 9.0))
	_readout = Label.new()
	_readout.name = "DebugFlightReadout"
	_readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout.add_theme_font_override("font", ReadoutFont)
	_readout.add_theme_font_size_override("font_size", 17)
	_readout.add_theme_color_override("font_color", Palette.TEXT)
	add_child(_readout)
	if Engine.has_singleton("GalaxyCommerce"):
		_bridge = Engine.get_singleton("GalaxyCommerce")
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_place()
	get_viewport().size_changed.connect(_place)


func _place() -> void:
	var safe := SafeLayout.insets(self)
	offset_left = 20.0 + safe.x
	offset_right = 284.0 + safe.x
	offset_top = 327.0 + safe.y
	offset_bottom = 393.0 + safe.y


func _process(delta: float) -> void:
	var arena: Node = arena_provider.call()
	visible = is_instance_valid(arena)
	var now := Time.get_ticks_usec()
	if visible and live_frame.call():
		if _last_frame > 0:
			var count: int = arena.active_shot_count() if arena.has_method("active_shot_count") else 0
			diagnostics.note_frame(now - _last_frame, arena.active_enemy_count(), count)
		_last_frame = now
	else:
		_last_frame = 0
	if not visible:
		_sample_in = 0.0
		return
	_sample_in -= delta
	if _sample_in > 0.0:
		return
	_sample_in = 2.0
	diagnostics.memory(_bridge)
	var frame := str(diagnostics.frame_stats().get("p95_ms", "—"))
	_readout.text = "%d FPS · P95 %s ms\n%d WROGÓW · %s" % [
		Engine.get_frames_per_second(), frame, arena.active_enemy_count(), diagnostics.memory_label()]
