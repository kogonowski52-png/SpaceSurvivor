extends Control
## Audio previews live. Graphics and audio are saved together by the pilot shell.

signal mix_previewed(values: Vector3)
signal effects_sample_requested
signal confirmed(values: Vector3, graphics: Dictionary)
signal cancelled
signal privacy_requested
signal diagnostics_changed(enabled: bool)
signal diagnostics_export_requested

const Graphics := preload("res://data/graphics_preferences.gd")
const SafeLayout := preload("res://ui/safe_layout.gd")
const Palette := preload("res://ui/palette.gd")
const Display := preload("res://assets/fonts/Oxanium.ttf")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")

var initial_mix := Vector3(0.90, 0.65, 0.80)
var initial_graphics := Graphics.DEFAULT
var diagnostic_summary := ""
var privacy_required := false
var privacy_policy_url := ""
var diagnostics_available := false
var diagnostics_enabled := false
var _diagnostics_button: Button
var _values := Vector3.ZERO
var _feedback: Label
var _privacy_button: Button
var _display := FontVariation.new()
var _graphics: Dictionary
var _pages: Dictionary[String, VBoxContainer] = {}
var _tabs: Dictionary[String, Button] = {}
var _quality_buttons: Dictionary[String, Button] = {}
var _scroll: ScrollContainer
var _diagnostic_status: Label
var _safe: Control
var _sheet: PanelContainer
var _selected_page := "audio"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_values = initial_mix
	_graphics = Graphics.normalize(initial_graphics)
	_display.base_font = Display
	_display.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 650}

	var scrim := ColorRect.new()
	scrim.color = Color("#030711b5")
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_safe = Control.new()
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_safe)
	SafeLayout.fill(_safe, Vector2(24.0, 25.0))
	_safe.resized.connect(_fit_sheet)
	_sheet = PanelContainer.new()
	var surface := Palette.plate(Color("#0d1828"), Color("#405871"), 15, 18.0)
	surface.border_width_top = 2
	surface.shadow_color = Color("#00000080")
	surface.shadow_size = 18
	_sheet.add_theme_stylebox_override("panel", surface)
	_safe.add_child(_sheet)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_sheet.add_child(column)

	column.add_child(_label("Ustawienia", 37, Palette.TEXT, _display))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	var choices := {"audio": "DŹWIĘK", "graphics": "GRAFIKA"}
	if diagnostics_available:
		choices["diagnostics"] = "DIAGNOSTYKA"
	for id: String in choices:
		var tab := _button(tabs, "SettingsTab_" + id, choices[id], false, _show_page.bind(id))
		tab.toggle_mode = true
		tab.add_theme_font_size_override("font_size", 15)
		_tabs[id] = tab
	_scroll = ScrollContainer.new()
	_scroll.name = "SettingsScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	var rail := _scroll.get_v_scroll_bar()
	rail.add_theme_stylebox_override("scroll", Palette.panel(Palette.GRAPHITE, Color.TRANSPARENT, 3))
	for style in ["grabber", "grabber_highlight", "grabber_pressed"]:
		rail.add_theme_stylebox_override(style, Palette.panel(Palette.OUTLINE, Color.TRANSPARENT, 3))
	column.add_child(_scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pages)
	for id: String in choices:
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 10)
		pages.add_child(page)
		_pages[id] = page
	_audio_page(_pages.audio)
	_graphics_page(_pages.graphics)
	if diagnostics_available:
		_diagnostics_page(_pages.diagnostics)

	_feedback = _label("", 17, Palette.TEXT, Body)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.hide()
	column.add_child(_feedback)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_button(buttons, "SettingsCancel", "ANULUJ", false, cancelled.emit)
	_button(buttons, "SettingsDone", "ZAPISZ", true, func() -> void: confirmed.emit(_values, _graphics))
	_show_page("audio")
	_sheet.modulate.a = 0.0
	_sheet.create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(_sheet, "modulate:a", 1.0, 0.18)


func _audio_page(page: VBoxContainer) -> void:
	page.add_child(_label("Głośność gry", 23, Palette.TEXT, _display))
	_channel(page, "MasterVolume", "Głośność główna", 0)
	_channel(page, "MusicVolume", "Muzyka", 1)
	_channel(page, "EffectsVolume", "Efekty dźwiękowe", 2)
	_privacy_button = _button(page, "PrivacyOptionsButton", "OPCJE PRYWATNOŚCI REKLAM", false, privacy_requested.emit)
	_privacy_button.visible = privacy_required
	if privacy_policy_url.begins_with("https://"):
		_button(page, "PrivacyPolicyButton", "POLITYKA PRYWATNOŚCI", false, _open_privacy_policy)


func _graphics_page(page: VBoxContainer) -> void:
	page.add_child(_label("Jakość grafiki", 23, Palette.TEXT, _display))
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	page.add_child(presets)
	for id: String in Graphics.LABELS:
		var option := _button(presets, "Quality_" + id, Graphics.LABELS[id], false, _choose_quality.bind(id))
		option.toggle_mode = true
		option.add_theme_font_size_override("font_size", 16)
		_quality_buttons[id] = option
	_choose_quality(_graphics.quality)
	_visual_slider(page, "EffectsIntensity", "Intensywność efektów", "effects")
	_visual_slider(page, "ParticleDensity", "Cząsteczki", "particles")
	_graphics_toggle(page, "Limit30Button", "Limit 30 FPS", "limit_30")
	_graphics_toggle(page, "PowerSaverButton", "Oszczędzanie energii", "saver")
	var info := _label("Oszczędzanie energii ogranicza FPS do 30 oraz zmniejsza liczbę gwiazd i cząsteczek.", 18, Palette.MUTED, Body)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(info)


func _diagnostics_page(page: VBoxContainer) -> void:
	page.add_child(_label("Diagnostyka Androida", 23, Palette.TEXT, _display))
	_diagnostic_status = _label(diagnostic_summary, 20, Palette.TEXT, Body)
	_diagnostic_status.name = "AdDiagnosticStatus"
	_diagnostic_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_diagnostic_status)
	_diagnostics_button = _button(page, "DiagnosticsButton", _diagnostics_label(), false, _toggle_diagnostics)
	_button(page, "ExportDiagnosticsButton", "EKSPORTUJ RAPORT", true, diagnostics_export_requested.emit)


func _show_page(selected: String) -> void:
	_selected_page = selected
	for id: String in _pages:
		_pages[id].visible = id == selected
		_tabs[id].set_pressed_no_signal(id == selected)
		_button_surface(_tabs[id], id == selected)
	_scroll.set_deferred("scroll_vertical", 0)
	_fit_sheet()


func _fit_sheet() -> void:
	if not is_instance_valid(_sheet):
		return
	var preferred := {"audio": 615.0, "graphics": 738.0, "diagnostics": 473.0}
	var height := minf(_safe.size.y, float(preferred[_selected_page]) + (55.0 if _selected_page == "audio" and privacy_required else 0.0))
	_sheet.offset_top = floorf((_safe.size.y - height) * 0.5)
	_sheet.offset_bottom = _sheet.offset_top + height


func _choose_quality(id: String) -> void:
	_graphics.quality = id
	for key: String in _quality_buttons:
		_quality_buttons[key].set_pressed_no_signal(key == id)
		_button_surface(_quality_buttons[key], key == id)


func _visual_slider(parent: VBoxContainer, id: String, title: String, key: String) -> void:
	var control := _slider_card(parent, id, title, _graphics[key])
	var slider: HSlider = control.slider
	slider.min_value = 25.0
	slider.step = 5.0
	slider.value = roundf(float(_graphics[key]) * 100.0)
	slider.value_changed.connect(func(value: float) -> void:
		_graphics[key] = value / 100.0
		control.value.text = _percent(_graphics[key])
	)


func _graphics_toggle(page: VBoxContainer, id: String, title: String, key: String) -> void:
	var button := _button(page, id, title, false, func() -> void: pass)
	button.toggle_mode = true
	button.set_pressed_no_signal(bool(_graphics[key]))
	button.text = title + (" · WŁ." if button.button_pressed else " · WYŁ.")
	_button_surface(button, button.button_pressed)
	button.toggled.connect(func(enabled: bool) -> void:
		_graphics[key] = enabled
		button.text = title + (" · WŁ." if enabled else " · WYŁ.")
		_button_surface(button, enabled)
	)


func update_diagnostics(summary: String) -> void:
	diagnostic_summary = summary
	if is_instance_valid(_diagnostic_status):
		_diagnostic_status.text = summary


func show_export_status(message: String) -> void:
	_feedback.text = message
	_feedback.show()


func show_save_error() -> void:
	_feedback.text = "Nie udało się zapisać ustawień. Spróbuj ponownie."
	_feedback.show()


func update_privacy(required: bool, message: String) -> void:
	privacy_required = required
	_privacy_button.visible = required
	_feedback.text = message
	_feedback.visible = not message.is_empty()
	_fit_sheet()


func _open_privacy_policy() -> void:
	if OS.shell_open(privacy_policy_url) != OK:
		_feedback.text = "Nie udało się otworzyć polityki prywatności."
		_feedback.show()


func _toggle_diagnostics() -> void:
	diagnostics_enabled = not diagnostics_enabled
	_diagnostics_button.text = _diagnostics_label()
	diagnostics_changed.emit(diagnostics_enabled)


func _diagnostics_label() -> String:
	return "DIAGNOSTYKA · WŁ." if diagnostics_enabled else "DIAGNOSTYKA · WYŁ."


func _slider_card(parent: VBoxContainer, id: String, title: String, initial: float) -> Dictionary:
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
	var value_label := _label(_percent(initial), 21, Palette.CYAN, _display)
	line.add_child(value_label)

	var slider := HSlider.new()
	slider.name = id
	slider.accessibility_name = title
	slider.custom_minimum_size.y = 38
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = roundf(initial * 100.0)
	var rail := Palette.panel(Color("#283a4c"), Color("#283a4c"), 4)
	rail.content_margin_top = 3.0
	rail.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", Palette.panel(Palette.CYAN.darkened(0.24), Palette.CYAN, 4))
	slider.add_theme_stylebox_override("grabber_area_highlight", Palette.panel(Palette.CYAN, Palette.CYAN, 4))
	slider.add_theme_icon_override("grabber", _knob(Palette.CYAN))
	slider.add_theme_icon_override("grabber_highlight", _knob(Palette.TEXT))
	content.add_child(slider)
	return {"slider": slider, "value": value_label}


func _channel(parent: VBoxContainer, id: String, title: String, axis: int) -> void:
	var control := _slider_card(parent, id, title, _values[axis])
	var slider: HSlider = control.slider
	slider.value_changed.connect(func(value: float) -> void:
		_values[axis] = value / 100.0
		control.value.text = _percent(_values[axis])
		mix_previewed.emit(_values)
	)
	if axis == 2:
		slider.drag_ended.connect(func(changed: bool) -> void:
			if changed:
				effects_sample_requested.emit()
		)


func _button(parent: Container, id: String, title: String, primary: bool, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = title
	button.custom_minimum_size.y = 54.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _display)
	button.add_theme_font_size_override("font_size", 18)
	_button_surface(button, primary)
	var focus := Palette.panel(Color.TRANSPARENT, Palette.TEXT, 9)
	focus.draw_center = false
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _button_surface(button: Button, primary: bool) -> void:
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
