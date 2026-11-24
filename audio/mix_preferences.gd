extends RefCounted

const DEFAULT := Vector3(0.90, 0.65, 0.80)
const CHANNELS := ["master", "music", "effects"]
const Graphics := preload("res://data/graphics_preferences.gd")

var path := "user://audio_settings.cfg"
var levels := DEFAULT
var graphics := Graphics.DEFAULT.duplicate()


func load_settings() -> void:
	levels = DEFAULT
	graphics = Graphics.DEFAULT.duplicate()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for axis in CHANNELS.size():
		var value: Variant = config.get_value("audio", CHANNELS[axis], DEFAULT[axis])
		if (value is int or value is float) and is_finite(float(value)):
			levels[axis] = clampf(float(value), 0.0, 1.0)
	var visual := {}
	for key: String in Graphics.DEFAULT:
		visual[key] = config.get_value("graphics", key, Graphics.DEFAULT[key])
	graphics = Graphics.normalize(visual)


func save_settings(values: Vector3, visual: Dictionary = {}) -> bool:
	var config := ConfigFile.new()
	var next := values.clamp(Vector3.ZERO, Vector3.ONE)
	var next_graphics := Graphics.normalize(graphics if visual.is_empty() else visual)
	for axis in CHANNELS.size():
		config.set_value("audio", CHANNELS[axis], next[axis])
	for key: String in next_graphics:
		config.set_value("graphics", key, next_graphics[key])
	var pending := path + ".tmp"
	if config.save(pending) != OK or DirAccess.rename_absolute(pending, path) != OK:
		return false
	levels = next
	graphics = next_graphics
	return true
