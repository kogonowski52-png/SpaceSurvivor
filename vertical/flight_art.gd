extends RefCounted
## Sprite sockets are normalized against the visible art, independent of combat scale.

const PREFIX := "res://assets/art/premium/hulls/"
const HULLS := {
	"peregrine": {"size": 94.0, "ports": [Vector2(-0.09, 0.405), Vector2(0.093, 0.405)], "energy": Color("#6ee7ff")},
	"aegis": {"size": 99.0, "ports": [Vector2(-0.214, 0.465), Vector2(0.0, 0.457), Vector2(0.216, 0.465)], "energy": Color("#89e5e4")},
	"specter": {"size": 99.0, "ports": [Vector2(-0.109, 0.382), Vector2(0.11, 0.382)], "energy": Color("#c6a5ff")},
	"aurora": {"size": 103.0, "ports": [Vector2(-0.069, 0.379), Vector2(0.071, 0.379)], "energy": Color("#f9a8de")},
}


static func hull(id: String) -> Texture2D:
	return load(PREFIX + id + ".webp") as Texture2D


static func frame(texture: Texture2D, longest: float) -> Rect2:
	var dimensions := texture.get_size()
	var scaled := dimensions * longest / maxf(dimensions.x, dimensions.y)
	return Rect2(-scaled * 0.5, scaled)
