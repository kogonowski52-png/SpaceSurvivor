extends RefCounted

const DEFAULT := Vector3(0.90, 0.65, 0.80)
const CHANNELS := ["master", "music", "effects"]

var path := "user://audio_settings.cfg"
var levels := DEFAULT


func load_settings() -> void:
	levels = DEFAULT
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	for axis in CHANNELS.size():
		var value: Variant = config.get_value("audio", CHANNELS[axis], DEFAULT[axis])
		if (value is int or value is float) and is_finite(float(value)):
			levels[axis] = clampf(float(value), 0.0, 1.0)


func save_settings(values: Vector3) -> bool:
	var config := ConfigFile.new()
	var next := values.clamp(Vector3.ZERO, Vector3.ONE)
	for axis in CHANNELS.size():
		config.set_value("audio", CHANNELS[axis], next[axis])
	var pending := path + ".tmp"
	if config.save(pending) != OK or DirAccess.rename_absolute(pending, path) != OK:
		return false
	levels = next
	return true
