extends RefCounted
## Convert physical app insets to the Godot canvas before placing interactive controls.

static func logical_insets(canvas: Vector2, window: Rect2i, display_safe: Rect2i) -> Vector4:
	var visible := window.intersection(display_safe)
	if not visible.has_area():
		return Vector4.ZERO
	var scale := canvas / Vector2(window.size)
	var leading := Vector2(visible.position - window.position) * scale
	var trailing := Vector2(window.end - visible.end) * scale
	return Vector4(leading.x, leading.y, trailing.x, trailing.y)


static func insets(control: Control) -> Vector4:
	if not OS.has_feature("android"):
		return Vector4.ZERO
	var bounds := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	return logical_insets(control.get_viewport_rect().size, bounds, DisplayServer.get_display_safe_area())


static func fill(control: Control, margins: Vector2) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := func() -> void:
		var safe := insets(control)
		control.offset_left = margins.x + safe.x
		control.offset_top = margins.y + safe.y
		control.offset_right = -margins.x - safe.z
		control.offset_bottom = -margins.y - safe.w
	layout.call()
	var parent := control.get_parent_control()
	if parent != null:
		parent.resized.connect(layout)
