extends RefCounted
## Three batteries cycle through a wind-up, attack and recovery.

const NAME := "ASTERION"
const MAX_HP := 2_180.0
const PHASE_NAMES := ["SALWA ROZWIDLONA", "KURTYNA SZYNOWA", "WIR NADPRZEWODZĄCY"]
const PHASE_COLORS := [Color("#ffbf8c"), Color("#ff8d77"), Color("#efa7ff")]
const DANGER := Color("#ff938b")
const HOT := Color("#ffe0b8")
const FIELD_WIDTH := 540.0
const ARMOR_FLOORS := [MAX_HP * 2.0 / 3.0, MAX_HP / 3.0, 0.0]
const HIT_ZONES := [
	Vector3(0.0, -7.0, 67.0), Vector3(-111.0, -17.0, 56.0), Vector3(111.0, -17.0, 56.0),
	Vector3(-84.0, 51.0, 39.0), Vector3(84.0, 51.0, 39.0), Vector3(0.0, 99.0, 36.0),
]

var position := Vector2(270, -190)
var hp := MAX_HP
var phase := 1
var state := "entry"
var timer := 2.0
var age := 0.0
var attack_count := 0
var phase_fired := false
var flash := 0.0
var lanes := PackedFloat32Array()
var observed_phases := 0

var _last_pulse := 0.0
var _next_arc := 0.0
var _windup_time := 1.42


func step(field: Node2D, delta: float) -> void:
	age += delta
	flash = maxf(0.0, flash - delta)
	timer -= delta
	_next_arc -= delta
	if phase == 3 and _next_arc <= 0.0:
		_next_arc = 0.43
		var split := Vector2(sin(age * 8.7) * 86.0, 38.0 + sin(age * 3.4) * 37.0)
		field.fx.burst(position + split, Color("#ffd1a6"), 4, 111.0)
	match state:
		"entry":
			var progress := clampf(age / 2.0, 0.0, 1.0)
			position.y = lerpf(-190.0, 224.0, 1.0 - pow(1.0 - progress, 2.4))
			if timer <= 0.0:
				_begin_warning(field)
		"warning":
			if timer <= 0.0:
				_release(field)
		"fire":
			_step_battery(field)
			if timer <= 0.0:
				state = "recover"
				timer = 1.16 if phase == 3 else 1.38
		"recover":
			if phase < 3 and hp <= ARMOR_FLOORS[phase - 1]:
				phase += 1
				phase_fired = false
				field.fx.ring(position, PHASE_COLORS[phase - 1], 131.0, 0.56)
				field.fx.blast(position + Vector2(0.0, 51.0), 72.0, phase == 3, 0.37)
				_begin_warning(field)
			elif timer <= 0.0:
				_begin_warning(field)
			else:
				var target := 270.0 + sin(age * 0.61) * (37.0 + phase * 6.0)
				position.x = move_toward(position.x, target, delta * 86.0)


func take_damage(amount: float) -> bool:
	if state == "entry" or hp <= 0.0:
		return false
	var floor_hp: float = ARMOR_FLOORS[phase - 1]
	if phase == 3:
		floor_hp = 1.0 if state in ["entry", "warning"] and not phase_fired else 0.0
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
		return "OKRĘT DOWODZENIA W ZASIĘGU"
	if state == "warning":
		return PHASE_NAMES[phase - 1] + "  ·  " + ("OPUŚĆ OZNACZONE PASY" if phase == 2 else "PRZYGOTUJ UNIK")
	return ""


func _mount(side: int) -> Vector2:
	return position + Vector2(side * 91.0, 77.0)


func _begin_warning(field: Node2D) -> void:
	state = "warning"
	_windup_time = 1.61 if phase == 2 else 1.40
	timer = _windup_time
	if phase == 2:
		var center := clampf(field.player_position.x, 53.0, FIELD_WIDTH - 53.0)
		var flank := 423.0 if center < 270.0 else 117.0
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
			timer = 0.70
			_last_pulse = 0.37
			_fan(field, false)
		2:
			timer = 0.37
			field.sound_requested.emit("laser")
		3:
			timer = 1.43
			_spiral(field, 0)
			_last_pulse = 1.24
	field.publish_telemetry()


func _step_battery(field: Node2D) -> void:
	match phase:
		1:
			if timer <= _last_pulse and _last_pulse > 0.0:
				_last_pulse = -1.0
				_fan(field, true)
		2:
			for lane: float in lanes:
				if absf(field.player_position.x - lane) < 26.0:
					field.hit_player(23.0)
		3:
			if timer <= _last_pulse:
				_spiral(field, int((1.44 - timer) * 7.5))
				_last_pulse -= 0.19


func _fan(field: Node2D, follow_up: bool) -> void:
	var shot_speed := 214.0 if follow_up else 249.0
	var sweep := 0.12 if follow_up else 0.0
	for side: int in [-1, 1]:
		for ray in 6:
			var angle := (ray - 2.5) * 0.156 + side * (0.22 + sweep)
			field.hostile_round(_mount(side), Vector2.DOWN.rotated(angle), shot_speed, 13.0)


func _spiral(field: Node2D, pulse: int) -> void:
	for side: int in [-1, 1]:
		for blade in 3:
			var angle := side * 0.28 + sin(pulse * 0.55 + blade * 1.07) * 0.60 + (blade - 1.0) * 0.29
			field.hostile_round(_mount(side), Vector2.DOWN.rotated(angle), 207.0 + blade * 25.0, 15.0, side * 0.62)


func draw_hull(canvas: Node2D, hull: Texture2D, frame: Rect2, fx: RefCounted) -> void:
	var wear := 1.0 - hp / MAX_HP
	var tone: Color = PHASE_COLORS[phase - 1]
	var metal := Color.WHITE.lerp(Color("#a58481"), wear * 0.51).lerp(HOT, flash * 3.9)
	var charge := 0.0
	if state == "warning":
		charge = clampf(1.0 - timer / _windup_time, 0.0, 1.0)
	elif state == "fire":
		charge = 0.80 + sin(age * 19.0) * 0.20
	canvas.draw_set_transform(position)
	canvas.draw_texture_rect(hull, frame, false, metal)
	var pixels := hull.get_size()
	for side: int in [-1, 1]:
		# Small transparent regions contain the two gun housings and ride on their respective rails.
		var normalized := Rect2(0.246 if side == -1 else 0.610, 0.472, 0.144, 0.213)
		var target := Rect2(frame.position + frame.size * normalized.position, frame.size * normalized.size)
		var shift := Vector2(side * charge * phase * 1.7, charge * (5.2 + phase * 1.8))
		target.position += shift
		canvas.draw_texture_rect_region(hull, target, Rect2(pixels * normalized.position, pixels * normalized.size),
			metal.lerp(tone, charge * 0.17))
	canvas.draw_set_transform(Vector2.ZERO)
	for side: int in [-1, 1]:
		var muzzle := _mount(side)
		fx.laser_contact(canvas, muzzle, 16.0 + charge * (23.0 + phase * 3.0), 0.12 + charge * 0.69)
		if state == "warning" and phase == 3:
			var rotation := age * 4.1 * side
			canvas.draw_arc(muzzle, 20.0 + charge * 17.0, rotation, rotation + PI * 1.25, 18, Color(tone, charge * 0.82), 2.0, true)
	if phase == 3:
		var flicker := sin(age * 14.4) * 0.13 + 0.25
		fx.laser_contact(canvas, position + Vector2(4.0, -51.0), 45.0, flicker)


func draw_signals(canvas: Node2D) -> void:
	if state == "entry" or state == "recover":
		return
	if phase == 2:
		for lane: float in lanes:
			var top := Vector2(lane, position.y + 106.0)
			var hazard := Rect2(top - Vector2(26.0, 0.0), Vector2(52.0, 960.0 - top.y))
			if state == "warning":
				var intensity := 0.52 + clampf(1.0 - timer / _windup_time, 0.0, 1.0) * 0.32
				canvas.draw_rect(hazard, Color(DANGER, 0.13))
				for side: int in [-1, 1]:
					var edge := top + Vector2(side * 26.0, 0.0)
					canvas.draw_dashed_line(edge, Vector2(edge.x, 960), Color(HOT, intensity), 2.1, 17.0)
				for index in 4:
					var point := Vector2(lane, top.y + 56.0 + index * 119.0 + sin(age * 10.0) * 6.0)
					canvas.draw_line(point - Vector2(7.0, 6.0), point, Color(DANGER, intensity), 2.1, true)
					canvas.draw_line(point, point + Vector2(7.0, -6.0), Color(DANGER, intensity), 2.1, true)
			else:
				canvas.draw_rect(hazard, Color(DANGER, 0.50))
				canvas.draw_line(top, Vector2(lane, 960), Color(HOT, 0.86), 8.0, true)
	elif state == "warning" and phase == 1:
		var pulse := 0.46 + 0.29 * sin(age * 15.0)
		for side: int in [-1, 1]:
			for ray in 3:
				var aim := Vector2.DOWN.rotated((ray - 1.0) * 0.36 + side * 0.22)
				var mount := _mount(side)
				canvas.draw_line(mount + aim * 15.0, mount + aim * 67.0, Color(DANGER, pulse), 2.2, true)
