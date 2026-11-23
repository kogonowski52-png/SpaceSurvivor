extends RefCounted
## Formation choreography runs in the 540 × 960 flight field.

enum Kind { SCOUT, RAZOR, WARDEN }

const ART := [
	preload("res://assets/art/enemy_scout_flight.png"),
	preload("res://assets/art/enemy_razor_flight.png"),
	preload("res://assets/art/enemy_elite_flight.png"),
]
const COLORS := [Color("#ffba76"), Color("#80ecd7"), Color("#f09cc4")]
const SIZE := [55.0, 63.0, 83.0]
const HP := [23.0, 35.0, 64.0]
const RADIUS := [17.0, 19.0, 25.0]
const SHOT_INTERVAL := [3.35, 2.65, 2.85]

class Fighter:
	var kind := 0
	var position := Vector2.ZERO
	var anchor := Vector2.ZERO
	var form := ""
	var offset := 0.0
	var age := 0.0
	var deadline := 16.0
	var entry := 1.25
	var hp := 0.0
	var flash := 0.0
	var fire_in := 0.0
	var heading := PI
	var departed := false

	func reset(spec: Dictionary, threat: int, hold: float) -> void:
		kind = spec.kind
		form = spec.form
		anchor = spec.anchor
		offset = spec.phase
		deadline = hold + spec.phase * 0.3
		entry = 1.16 + kind * 0.16
		position = Vector2(spec.left, -70.0)
		age = 0.0
		hp = HP[kind] * (1.0 + (threat - 1) * 0.22)
		flash = 0.0
		fire_in = 1.15 + spec.phase * 0.41
		heading = PI
		departed = false

	func advance(delta: float) -> void:
		age += delta
		flash = maxf(0.0, flash - delta)
		var prior := position
		var swing := sin(age * (1.15 + kind * 0.16) + offset)
		if age < entry:
			var lift := 1.0 - pow(1.0 - age / entry, 2.45)
			position.y = lerpf(-70.0, anchor.y, lift)
			position.x = move_toward(position.x, anchor.x, delta * 380.0)
		elif form == "raid":
			var bank_in := smoothstep(entry, entry + 0.42, age)
			position = Vector2(anchor.x + swing * 83.0 * bank_in, anchor.y + (age - entry) * (130.0 + kind * 12.0))
		elif age > deadline:
			position.y += delta * 191.0
			position.x = move_toward(position.x, anchor.x + 85.0 * signf(anchor.x - 270.0), delta * 52.0)
		elif form == "spiral":
			var angle := offset + (age - entry) * 1.85
			var flare := smoothstep(entry, entry + 0.82, age)
			position = anchor + Vector2(cos(angle) * 138.0, sin(angle) * 73.0) * flare
		else:
			var drift_in := smoothstep(entry, entry + 0.36, age)
			position = anchor + Vector2(swing * (23.0 + kind * 8.0), sin(age * 1.2 + offset) * 13.0) * drift_in
		position.x = clampf(position.x, 30.0, 510.0)
		var bank := clampf((position.x - prior.x) / maxf(delta * 290.0, 0.1), -0.6, 0.6)
		heading = lerp_angle(heading, PI - bank, minf(1.0, delta * 12.0))
		departed = position.y > 1_040.0


static func plan(groups: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for group: Array in groups:
		var form: String = group[0]
		var count: int = group[2]
		for index in count:
			var spread := float(index) / maxf(1.0, count - 1.0) * 2.0 - 1.0
			var x := 270.0 + spread * 187.0
			var y: float = group[4]
			var phase := float(index) * 0.59
			match form:
				"wedge": y += 72.0 * (1.0 - absf(spread))
				"arc": y += 68.0 * spread * spread
				"spiral":
					var angle := TAU * index / count
					x = 270.0 + cos(angle) * 79.0
					y += sin(angle) * 49.0
					phase = angle
				"raid": x = 270.0 + float(index % 2 * 2 - 1) * (93.0 + 8.0 * (index % 3))
			var spacing := 0.32 if form == "raid" else (0.17 if form == "spiral" else 0.045)
			entries.append({"at": float(group[3]) + index * spacing, "form": form, "kind": int(group[1]),
				"phase": phase, "left": x if form == "line" else clampf(x + 48.0 * spread, 34.0, 506.0),
				"anchor": Vector2(x, y)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at < b.at)
	return entries
