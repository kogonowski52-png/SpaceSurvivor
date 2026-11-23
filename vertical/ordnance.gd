extends RefCounted
## Automatic armament. Rank governs emitter count and unlocks auxiliary fire.

enum Kind { PULSE, PLASMA, ROCKET, HOSTILE, ORBIT }

const EMITTERS := [1, 2, 3, 5, 7, 7, 7]
const RANK_COLORS := [Color("#74e9f4"), Color("#95f4ff"), Color("#90bbff"), Color("#bda2ff"),
	Color("#f3a9ff"), Color("#ffc093"), Color("#fbf4cf")]
const MODES := {
	"laser": {"title": "Laser Cannon", "cycle": 0.245, "sound": "shot"},
	"plasma": {"title": "Plasma Spread", "cycle": 0.32, "sound": "nova"},
	"rockets": {"title": "Homing Rockets", "cycle": 0.37, "sound": "missile"},
	"beam": {"title": "Energy Beam", "cycle": 0.60, "sound": "laser"},
}
const DROPS := {
	"core": {"title": "RDZEŃ OGNIA", "tone": Color("#74e9f4")},
	"plasma": {"title": "PLASMA SPREAD", "tone": Color("#e2a0ff")},
	"rockets": {"title": "HOMING ROCKETS", "tone": Color("#ffc194")},
	"beam": {"title": "ENERGY BEAM", "tone": Color("#9bafff")},
	"repair": {"title": "NAPRAWA KADŁUBA", "tone": Color("#92e8c7")},
}

class Shot:
	var kind := 0
	var position := Vector2.ZERO
	var velocity := Vector2.ZERO
	var damage := 0.0
	var time := 0.0
	var turn := 0.0
	var tint := Color.WHITE

	func hostile() -> bool:
		return kind == Kind.HOSTILE or kind == Kind.ORBIT

var rank := 1
var mode := "laser"
var beam_left := 0.0
var beam_age := 0.0
var beam_contact := Vector2.ZERO
var contact_left := 0.0
var damage_scale := 1.0
var cycle_scale := 1.0
var _cycle_left := 0.0
var _beam_tick := 0.0
var _volley := 0


func reset(starting_rank: int, stats: Dictionary) -> void:
	rank = clampi(starting_rank, 1, EMITTERS.size())
	damage_scale = clampf(float(stats.get("weapon_damage_multiplier", 1.0)), 0.65, 2.5)
	cycle_scale = clampf(float(stats.get("pulse_interval_multiplier", 1.0)), 0.57, 1.55)


func power_up(id: String) -> void:
	if id == "repair" or not DROPS.has(id):
		return
	rank = mini(rank + 1, EMITTERS.size())
	if MODES.has(id):
		mode = id
	_cycle_left = minf(_cycle_left, 0.12)


func accent() -> Color:
	return RANK_COLORS[rank - 1]


func step(field: Node2D, delta: float) -> void:
	_cycle_left -= delta
	beam_left = maxf(0.0, beam_left - delta)
	contact_left = maxf(0.0, contact_left - delta)
	if _cycle_left <= 0.0:
		var spec: Dictionary = MODES[mode]
		_cycle_left += float(spec.cycle) * cycle_scale
		fire(field)
		field.sound_requested.emit(spec.sound)
	if beam_left > 0.0:
		beam_age += delta
		_beam_tick -= delta
		if _beam_tick <= 0.0:
			_beam_tick += 0.10
			var touch: Vector2 = field.beam_damage(beam_start(field.player_position), (11.0 + rank * 2.3) * damage_scale)
			if touch != Vector2.ZERO:
				beam_contact = touch
				contact_left = 0.10


func fire(field: Node2D) -> void:
	_volley += 1
	var count: int = EMITTERS[rank - 1]
	var kind := Kind.PULSE
	var speed := 765.0
	var spread := 0.24 if rank >= 4 else 0.10
	var damage := (13.5 + 0.72 * rank) * damage_scale
	match mode:
		"plasma":
			kind = Kind.PLASMA
			speed = 565.0
			spread = 0.34
			damage *= 1.08
		"rockets":
			kind = Kind.ROCKET
			speed = 440.0
			spread = 0.36
			damage *= 1.36
		"beam":
			var span := 0.54 if rank == 7 and _volley % 4 == 0 else 0.42
			start_beam(span * cycle_scale)
			damage *= 0.72
	for index in count:
		var lane := index - (count - 1) * 0.5
		if mode == "beam" and is_zero_approx(lane):
			continue
		var angle := lane / maxf(1.0, (count - 1) * 0.5) * spread
		var origin: Vector2 = field.player_position + Vector2(lane * 10.5, -27.0 + absf(lane) * 2.5)
		var tint := accent()
		if kind == Kind.PLASMA:
			tint = Color("#db8bfa").lerp(tint, 0.25)
		elif kind == Kind.ROCKET:
			tint = Color("#ffbd78").lerp(tint, 0.24)
		field.spawn_shot(origin, Vector2.UP.rotated(angle) * speed, kind, damage, 2.6, 0.0, tint)
	if rank >= 6 and _volley % 3 == 0:
		for side: int in [-1, 1]:
			field.spawn_shot(field.player_position + Vector2(side * 33.0, -7.0), Vector2.UP.rotated(side * 0.47) * 430.0,
				Kind.ROCKET, 21.0 * damage_scale, 2.7, 0.0, Color("#ffc194"))
	if rank == 7 and _volley % 4 == 0 and mode != "beam":
		start_beam(0.29)
	field.muzzle_flash = 0.09


func start_beam(duration: float) -> void:
	beam_left = duration
	beam_age = 0.0
	_beam_tick = 0.0


func beam_start(origin: Vector2) -> Vector2:
	return origin + Vector2(0.0, -31.0)
