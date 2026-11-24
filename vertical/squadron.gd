extends RefCounted
## Timed squadrons share arrival paths and their initial fire cue.

enum Kind { SCOUT, RAZOR, WARDEN, INTERCEPTOR, CARRIER, BOMBER, PHANTOM }

const ART := [
	preload("res://assets/art/premium/enemies/scout.webp"),
	preload("res://assets/art/premium/enemies/razor.webp"),
	preload("res://assets/art/premium/enemies/warden.webp"),
	preload("res://assets/art/chapter_one/enemies/interceptor.webp"),
	preload("res://assets/art/chapter_one/enemies/carrier.webp"),
	preload("res://assets/art/chapter_one/enemies/bomber.webp"),
	preload("res://assets/art/chapter_one/enemies/phantom.webp"),
]
const COLORS := [
	Color("#ffb36f"), Color("#86e5ca"), Color("#f999ab"), Color("#ffdc8b"),
	Color("#8fd6ff"), Color("#ff9478"), Color("#d6b9ff"),
]
const SIZE := [54.0, 65.0, 83.0, 58.0, 88.0, 92.0, 72.0]
const HP := [21.0, 38.0, 72.0, 25.0, 67.0, 90.0, 39.0]
const RADIUS := [17.0, 19.0, 26.0, 18.0, 28.0, 31.0, 21.0]
const SHOT_INTERVAL := [4.35, 3.70, 4.1, 4.8, 5.3, 6.5, 5.7]
const SHIELD_RADIUS := 104.0
const SHIELD_CAPACITY := 88.0
const ENTRY_TIME := [0.96, 1.17, 1.49, 0.71, 1.55, 1.58, 1.06]

class Fighter:
	var kind := 0
	var position := Vector2.ZERO
	var origin := Vector2.ZERO
	var anchor := Vector2.ZERO
	var center := Vector2.ZERO
	var form := ""
	var offset := 0.0
	var delay := 0.0
	var sweep := 0.0
	var age := 0.0
	var deadline := 9.0
	var entry := 1.1
	var hp := 0.0
	var flash := 0.0
	var shield := 0.0
	var shield_flash := 0.0
	var signalled := false
	var fire_in := 0.0
	var heading := PI
	var departed := false

	func reset(spec: Dictionary, threat: int, hold: float) -> void:
		kind = spec.kind
		form = spec.form
		anchor = spec.anchor
		center = spec.center
		offset = spec.phase
		delay = spec.delay
		sweep = spec.sweep
		deadline = hold
		entry = ENTRY_TIME[kind]
		origin = spec.origin
		position = origin
		age = 0.0
		hp = HP[kind] * (1.0 + (threat - 1) * 0.19)
		flash = 0.0
		shield = SHIELD_CAPACITY if kind == Kind.CARRIER else 0.0
		shield_flash = 0.0
		signalled = false
		fire_in = float(spec.volley) - delay
		heading = PI
		departed = false

	func cloaked() -> bool:
		var phase := fposmod(age + offset * 0.34, 3.65)
		return kind == Kind.PHANTOM and age > entry + 0.37 and fire_in > 0.70 and phase >= 1.15 and phase < 2.46

	func advance(delta: float) -> void:
		age += delta
		flash = maxf(0.0, flash - delta)
		shield_flash = maxf(0.0, shield_flash - delta)
		var prior := position
		var elapsed := age - entry
		var wave_clock := elapsed + delay
		if elapsed < 0.0:
			var progress := age / entry
			var coast := 1.0 - pow(1.0 - progress, 2.18)
			position = origin.lerp(anchor, coast)
			position.x += sin(progress * PI) * sweep
		elif form in ["raid", "flank"]:
			var bank_in := smoothstep(0.0, 0.48, elapsed)
			var speed := 234.0 if kind == Kind.INTERCEPTOR else (132.0 + minf(3.0, kind) * 14.0)
			var reach := 139.0 if kind == Kind.INTERCEPTOR else 105.0
			position = Vector2(anchor.x + sin(elapsed * 1.84 + offset) * reach * bank_in, anchor.y + elapsed * speed)
		elif age > deadline:
			position.y += delta * (170.0 + kind * 14.0)
			position.x += signf(anchor.x - 270.0) * delta * 42.0
		elif form == "spiral":
			var theta := offset + elapsed * 1.12
			var orbit := 1.0 + 0.12 * sin(elapsed * 1.6)
			position = center + Vector2(cos(theta) * 128.0, sin(theta) * 74.0) * orbit
		else:
			var drift_in := smoothstep(0.0, 0.42, elapsed)
			var pace := 2.39 if kind == Kind.PHANTOM else 1.22
			var sway := sin(wave_clock * pace) * (48.0 if kind == Kind.PHANTOM else (37.0 if form == "group" else 24.0))
			position = anchor + Vector2(sway, sin(wave_clock + offset) * 10.0) * drift_in
		if elapsed >= 0.0:
			position.x = clampf(position.x, 25.0, 515.0)
		var bank := clampf((position.x - prior.x) / maxf(delta * 250.0, 0.1), -0.78, 0.78)
		heading = lerp_angle(heading, PI - bank, minf(1.0, delta * 11.0))
		departed = position.y > 1_030.0


static func plan(groups: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for group: Array in groups:
		var form: String = group[0]
		var count: int = group[2]
		var bias := float(group[5]) if group.size() > 5 else 0.0
		var middle := Vector2(270.0 + bias, float(group[4]))
		var spacing := 0.23 if form in ["raid", "spiral", "flank"] else 0.065
		for index in count:
			var spread := float(index) / maxf(1.0, count - 1.0) * 2.0 - 1.0
			var anchor := middle + Vector2(spread * (157.0 if absf(bias) > 30.0 else 180.0), 0.0)
			var phase := spread * 1.6
			var sweep := signf(spread) * 47.0
			match form:
				"wedge": anchor.y += 83.0 * (1.0 - absf(spread))
				"arc": anchor.y += 72.0 * spread * spread
				"spiral":
					phase = TAU * index / count
					anchor = middle + Vector2(cos(phase) * 128.0, sin(phase) * 74.0)
					sweep = -signf(cos(phase)) * 133.0
				"raid": anchor.x = middle.x + float(index % 2 * 2 - 1) * (98.0 + 12.0 * (index % 3))
				"flank":
					anchor = Vector2(270.0 + bias * 1.32 + spread * 79.0, middle.y + index * 15.0)
					sweep = -signf(bias) * 69.0
				"group":
					var side := -1.0 if index < ceili(count / 2.0) else 1.0
					anchor = middle + Vector2(side * 122.0 + float(index % 3 - 1) * 33.0, float(index % 3) * 34.0)
					sweep = side * 97.0
			var delay := index * spacing
			var start := Vector2(clampf(anchor.x + sweep * 0.84, 27.0, 513.0), -72.0)
			if form == "flank":
				start = Vector2(-62.0 if bias < 0.0 else 602.0, middle.y + index * 8.0)
			entries.append({"at": float(group[3]) + delay, "form": form, "kind": int(group[1]),
				"phase": phase, "delay": delay, "origin": start, "anchor": anchor, "center": middle,
				"sweep": sweep, "volley": 2.52 + (index * 0.11 if form == "raid" else 0.0)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.at < b.at)
	return entries
