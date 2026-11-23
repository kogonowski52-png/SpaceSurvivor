extends Control
## Audio controls use the active mix while editing. Closing with Cancel restores it.

signal mix_previewed(values: Vector3)
signal effects_sample_requested
signal confirmed(values: Vector3)
signal cancelled
signal privacy_requested

const Palette := preload("res://ui/palette.gd")
const Display := preload("res://assets/fonts/Oxanium.ttf")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")

var initial_mix := Vector3(0.90, 0.65, 0.80)
var privacy_required := false
var _values := Vector3.ZERO
var _feedback: Label
var _privacy_button: Button
var _display := FontVariation.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_values = initial_mix
	_display.base_font = Display
	_display.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}

	var scrim := ColorRect.new()
	scrim.color = Color("#030711ec")
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size.x = 470
	var surface := Palette.plate(Color("#0d1828"), Color("#405871"), 15, 24.0)
	surface.border_width_top = 2
	sheet.add_theme_stylebox_override("panel", surface)
	center.add_child(sheet)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 15)
	sheet.add_child(column)

	var mark := ColorRect.new()
	mark.color = Palette.CYAN
	mark.custom_minimum_size = Vector2(44, 2)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(mark)
	column.add_child(_label("Ustawienia", 39, Palette.TEXT, _display))
	column.add_child(_label("Głośność gry", 19, Palette.MUTED, Body))

	var master := _channel(column, "MasterVolume", "Głośność główna", 0)
	_channel(column, "MusicVolume", "Muzyka", 1)
	_channel(column, "EffectsVolume", "Efekty dźwiękowe", 2)
	_privacy_button = _button(column, "PrivacyOptionsButton", "OPCJE PRYWATNOŚCI REKLAM", false, privacy_requested.emit)
	_privacy_button.visible = privacy_required

	_feedback = _label("", 17, Palette.DANGER, Body)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.hide()
	column.add_child(_feedback)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_button(buttons, "SettingsCancel", "ANULUJ", false, cancelled.emit)
	_button(buttons, "SettingsDone", "ZAPISZ", true, func() -> void: confirmed.emit(_values))
	sheet.modulate.a = 0.0
	sheet.create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(sheet, "modulate:a", 1.0, 0.18)
	master.grab_focus.call_deferred()


func show_save_error() -> void:
	_feedback.text = "Nie udało się zapisać ustawień. Spróbuj ponownie."
	_feedback.show()


func update_privacy(required: bool, message: String) -> void:
	privacy_required = required
	_privacy_button.visible = required
	_feedback.text = message
	_feedback.visible = not message.is_empty()


func _channel(parent: VBoxContainer, id: String, title: String, axis: int) -> HSlider:
	var track := PanelContainer.new()
	track.add_theme_stylebox_override("panel", Palette.panel(Color("#132337"), Color("#2e4459"), 9, 13.0))
	parent.add_child(track)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	track.add_child(content)
	var line := HBoxContainer.new()
	content.add_child(line)
	var name_label := _label(title, 21, Palette.TEXT, Body)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name_label)
	var value_label := _label(_percent(_values[axis]), 21, Palette.CYAN, _display)
	line.add_child(value_label)

	var slider := HSlider.new()
	slider.name = id
	slider.accessibility_name = title
	slider.custom_minimum_size.y = 38
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = roundf(_values[axis] * 100.0)
	var rail := Palette.panel(Color("#283a4c"), Color("#283a4c"), 4)
	rail.content_margin_top = 3.0
	rail.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", Palette.panel(Palette.CYAN.darkened(0.24), Palette.CYAN, 4))
	slider.add_theme_stylebox_override("grabber_area_highlight", Palette.panel(Palette.CYAN, Palette.CYAN, 4))
	slider.add_theme_icon_override("grabber", _knob(Palette.CYAN))
	slider.add_theme_icon_override("grabber_highlight", _knob(Palette.TEXT))
	content.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		_values[axis] = value / 100.0
		value_label.text = _percent(_values[axis])
		mix_previewed.emit(_values)
	)
	if axis == 2:
		slider.drag_ended.connect(func(changed: bool) -> void:
			if changed:
				effects_sample_requested.emit()
		)
	return slider


func _button(parent: Container, id: String, title: String, primary: bool, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = title
	button.custom_minimum_size.y = 54.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _display)
	button.add_theme_font_size_override("font_size", 18)
	var fill := Palette.CYAN if primary else Palette.SURFACE
	var ink := Palette.NIGHT if primary else Palette.TEXT
	for state in ["normal", "hover", "pressed"]:
		var surface := fill
		if state == "hover":
			surface = fill.lightened(0.15)
		elif state == "pressed":
			surface = fill.darkened(0.14)
		button.add_theme_stylebox_override(state, Palette.plate(surface, fill.lightened(0.13), 9))
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(color, ink)
	var focus := Palette.panel(Color.TRANSPARENT, Palette.TEXT, 9)
	focus.draw_center = false
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _label(title: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _knob(color: Color) -> GradientTexture2D:
	var knob := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.68, 0.76, 0.92, 1.0])
	gradient.colors = PackedColorArray([color, color, Color(color, 0.36), Color(color, 0.10), Color(color, 0.0)])
	knob.width = 25
	knob.height = 25
	knob.fill = GradientTexture2D.FILL_RADIAL
	knob.fill_from = Vector2(0.5, 0.5)
	knob.fill_to = Vector2(1, 0.5)
	knob.gradient = gradient
	return knob


func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)
