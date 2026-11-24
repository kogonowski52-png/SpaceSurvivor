extends RefCounted
## Render budgets affect decorative passes only. Physics and combat data stay on their existing path.

const DEFAULT := {"quality": "standard", "effects": 1.0, "particles": 1.0, "limit_30": false, "saver": false}
const LABELS := {"low": "Niska", "standard": "Standardowa", "high": "Wysoka"}
const PRESETS := {
	"low": {"sparks": 0.52, "stars": 30, "circle": 24, "extra_ring": false, "debris": false},
	"standard": {"sparks": 1.0, "stars": 60, "circle": 36, "extra_ring": true, "debris": true},
	"high": {"sparks": 1.22, "stars": 78, "circle": 40, "extra_ring": true, "debris": true},
}


static func normalize(data: Dictionary) -> Dictionary:
	var quality: Variant = data.get("quality")
	return {
		"quality": quality if quality is String and PRESETS.has(quality) else DEFAULT.quality,
		"effects": _strength(data.get("effects")),
		"particles": _strength(data.get("particles")),
		"limit_30": data.get("limit_30") == true,
		"saver": data.get("saver") == true,
	}


static func tuning(data: Dictionary) -> Dictionary:
	var settings := normalize(data)
	var selected: Dictionary = PRESETS[settings.quality]
	var saving: bool = settings.saver
	return {
		"sparks": float(selected.sparks) * float(settings.particles) * (0.68 if saving else 1.0),
		"stars": mini(int(selected.stars), 30) if saving else int(selected.stars),
		"circle": mini(int(selected.circle), 24) if saving else int(selected.circle),
		"extra_ring": selected.extra_ring and not saving,
		"debris": selected.debris and not saving,
		"intensity": float(settings.effects),
		"fps_cap": 30 if settings.limit_30 or saving else 60,
	}


static func _strength(value: Variant) -> float:
	return clampf(float(value), 0.25, 1.0) if (value is int or value is float) and is_finite(float(value)) else 1.0
