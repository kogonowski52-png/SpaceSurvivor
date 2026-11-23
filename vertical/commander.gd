extends RefCounted
## Asterion switches gun batteries at armor thresholds. Each battery fires at least once.

const NAME := "ASTERION"
const MAX_HP := 1_420.0
const PHASE_NAMES := ["SALWA ROZWIDLONA", "KURTYNA SZYNOWA", "WIR NADPRZEWODZĄCY"]
const DANGER := Color("#ff938b")
const HOT := Color("#ffd5b2")
const FIELD_WIDTH := 540.0
const ARMOR_FLOORS := [MAX_HP * 2.0 / 3.0, MAX_HP / 3.0, 0.0]
const HIT_ZONES := [Vector3(0.0, 0.0, 67.0), Vector3(-82.0, -9.0, 44.0), Vector3(82.0, -9.0, 44.0)]

var position := Vector2(270, -152)
var hp := MAX_HP
var phase := 1
var state := "entry"
var timer := 1.75
var age := 0.0
var attack_count := 0
var phase_fired := false
var flash := 0.0
var lanes := PackedFloat32Array()
var observed_phases := 0
var _last_pulse := 0.0


func step(field: Node2D, delta: float) -> void:
	age += delta
	flash = maxf(0.0, flash - delta)
	timer -= delta
	match state:
		"entry":
			position.y = move_toward(position.y, 222.0, delta * 255.0)
			if timer <= 0.0:
				_begin_warning(field)
		"warning":
			if timer <= 0.0:
				_release(field)
		"fire":
			if phase == 2:
				for lane: float in lanes:
					if absf(field.player_position.x - lane) < 24.0:
						field.hit_player(21.0)
			elif phase == 3 and timer <= _last_pulse:
				_spiral(field, int((1.2 - timer) * 9.0))
				_last_pulse -= 0.15
			if timer <= 0.0:
				state = "recover"
				timer = 1.26 if phase == 3 else 1.54
		"recover":
			if phase < 3 and hp <= ARMOR_FLOORS[phase - 1]:
				phase += 1
				phase_fired = false
				field.fx.ring(position, HOT, 124.0, 0.56)
				_begin_warning(field)
			elif timer <= 0.0:
				_begin_warning(field)
			else:
				position.x = move_toward(position.x, 270.0 + sin(age * 0.63) * (46.0 + phase * 13.0), delta * 82.0)


func take_damage(amount: float) -> bool:
	if state == "entry" or hp <= 0.0:
		return false
	var floor_hp: float = ARMOR_FLOORS[phase - 1]
	if phase == 3 and not phase_fired:
		floor_hp = 1.0
	flash = 0.105
	hp = maxf(floor_hp, hp - amount)
	return hp <= 0.0


func hit_fraction(from: Vector2, to: Vector2, pad: float) -> float:
	var axis := to - from
	var squared := axis.length_squared()
	if squared <= 0.001 or state == "entry":
		return 2.0
	var earliest := 2.0
	for part: Vector3 in HIT_ZONES:
		var center := position + Vector2(part.x, part.y)
		var progress := clampf((center - from).dot(axis) / squared, 0.0, 1.0)
		if center.distance_squared_to(from + axis * progress) < (part.z + pad) * (part.z + pad):
			earliest = minf(earliest, progress)
	return earliest


func warning() -> String:
	if state == "entry":
		return "SYGNAŁ KAPITALNY · ASTERION"
	if state == "warning":
		return PHASE_NAMES[phase - 1] + "  ·  " + ("ZMIEŃ PAS" if phase == 2 else "PRZYGOTUJ UNIK")
	return ""


func _begin_warning(field: Node2D) -> void:
	state = "warning"
	timer = 1.22 if phase != 2 else 1.58
	if phase == 2:
		var center := clampf(field.player_position.x, 62.0, FIELD_WIDTH - 62.0)
		var flank := 424.0 if center < 270.0 else 116.0
		lanes = PackedFloat32Array([center, flank])
	field.sound_requested.emit("boss_warning")
	field.publish_telemetry()


func _release(field: Node2D) -> void:
	state = "fire"
	attack_count += 1
	phase_fired = true
	observed_phases |= 1 << (phase - 1)
	match phase:
		1:
			timer = 0.22
			for side: int in [-1, 1]:
				var origin := position + Vector2(73.0 * side, 38.0)
				for lane in 7:
					field.hostile_round(origin, Vector2.DOWN.rotated((lane - 3.0) * 0.142 + side * 0.20), 225.0, 13.0)
		2:
			timer = 0.35
			field.sound_requested.emit("laser")
		3:
			timer = 1.20
			_spiral(field, 0)
			_last_pulse = 1.05
	field.publish_telemetry()


func _spiral(field: Node2D, pulse: int) -> void:
	for side: int in [-1, 1]:
		var origin := position + Vector2(64.0 * side, 31.0)
		for blade in 3:
			var angle := side * (0.32 + sin(pulse * 0.39 + blade * 0.89) * 0.62) + (blade - 1.0) * 0.41
			field.hostile_round(origin, Vector2.DOWN.rotated(angle), 212.0 + blade * 22.0, 14.0, side * 0.54)


func draw_signals(canvas: Node2D) -> void:
	if state == "entry" or state == "recover":
		return
	if phase == 2:
		for lane: float in lanes:
			var top := Vector2(lane, position.y + 58.0)
			if state == "warning":
				var opacity := 0.57 + 0.29 * sin(age * 17.0)
				canvas.draw_rect(Rect2(top - Vector2(24, 0), Vector2(48, 960 - top.y)), Color(DANGER, 0.11))
				for side: int in [-1, 1]:
					var edge := top + Vector2(side * 24.0, 0.0)
					canvas.draw_dashed_line(edge, Vector2(edge.x, 960), Color(HOT, opacity), 2.0, 16.0)
			else:
				canvas.draw_line(top, Vector2(lane, 960), Color(DANGER, 0.56), 45.0, true)
				canvas.draw_line(top, Vector2(lane, 960), Color(HOT, 0.88), 5.0, true)
	elif state == "warning":
		var pulse := 0.52 + 0.26 * sin(age * 18.0)
		for side: int in [-1, 1]:
			var mount := position + Vector2(side * 73.0, 38.0)
			if phase == 1:
				for ray in 3:
					var aim := Vector2.DOWN.rotated((ray - 1.0) * 0.426 + side * 0.20)
					canvas.draw_line(mount + aim * 11.0, mount + aim * 76.0, Color(DANGER, pulse), 2.0, true)
			else:
				canvas.draw_arc(mount, 30.0 + 9.0 * sin(age * 9.0), 0.3, PI - 0.3, 23, Color(HOT, pulse), 2.1, true)
