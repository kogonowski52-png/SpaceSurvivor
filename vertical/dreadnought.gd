extends "res://vertical/commander.gd"
## Vesperon's gimbals and Nadir's three modules share collision and damage rules.
## Attack schedules stay tied to each ship's own sequence.

const VESPERON := {
	"name": "VESPERON", "max_hp": 2_675.0, "points": 7_400,
	"phases": [
		["SALWY GIMBALOWE", "sentry", Color("#b8e9ac")],
		["PRZECINAJĄCE SZYNY", "lance", Color("#97edee")],
		["BOMBY ORBITALNE", "torpedoes", Color("#ffc499")],
	],
	"modules": [
		[Vector2(-104, 27), "vesperon_rail", 232.0, 25.0],
		[Vector2(104, 27), "vesperon_rail", 232.0, 25.0],
	],
}

const NADIR := {
	"name": "NADIR", "max_hp": 3_450.0, "points": 12_500,
	"phases": [
		["PRÓG SINGULARNOŚCI", "gate", Color("#98f3e8")],
		["SKRZYŻOWANE OGNISKA", "crossfire", Color("#ff9f83")],
		["MINY GRAWITACYJNE", "gravity", Color("#cca7ff")],
		["ZAĆMIENIE", "eclipse", Color("#fff1b7")],
	],
	"modules": [
		[Vector2(-96, 19), "nadir_rail", 292.0, 25.0],
		[Vector2(96, 19), "nadir_rail", 292.0, 25.0],
		[Vector2(0, 45), "nadir_core", 351.0, 28.0],
	],
}

const MODULE_ART := {
	"vesperon_rail": preload("res://assets/art/chapter_one/modules/vesperon_rail.webp"),
	"nadir_rail": preload("res://assets/art/chapter_one/modules/nadir_rail.webp"),
	"nadir_core": preload("res://assets/art/chapter_one/modules/nadir_core.webp"),
}

class Turret:
	var mount := Vector2.ZERO
	var hp := 0.0
	var full := 0.0
	var radius := 24.0
	var flash := 0.0
	var sprite: Texture2D

var _spec: Dictionary
var _turrets: Array[Turret] = []
var _volley_left := 0.0
var _shots_left := 0
var _attack := ""
var _warning_span := 1.38
var _gap := 270.0
var _fixture_target := Vector2.ZERO
var _offset_clock := 0.0


func _init(hull_id := "vesperon") -> void:
	_spec = NADIR if hull_id == "nadir" else VESPERON
	hp = health_capacity()
	position = Vector2(270.0, -211.0)
	timer = 2.15
	for spec: Array in _spec.modules:
		var part := Turret.new()
		part.mount = spec[0]
		part.sprite = MODULE_ART[spec[1]]
		part.full = float(spec[2])
		part.hp = part.full
		part.radius = float(spec[3])
		_turrets.append(part)


func encounter_name() -> String:
	return _spec.name


func health_capacity() -> float:
	return _spec.max_hp


func phase_total() -> int:
	return _spec.phases.size()


func phase_tone() -> Color:
	return _spec.phases[phase - 1][2]


func modules_left() -> int:
	var count := 0
	for part in _turrets:
		count += int(part.hp > 0.0)
	return count


func score_value() -> int:
	return _spec.points


func aim_point(from: Vector2) -> Vector2:
	for part in _turrets:
		var target := position + part.mount
		if part.hp > 0.0 and absf(target.x - from.x) < 54.0:
			return target
	return position + Vector2(0.0, 39.0)


func step(field: Node2D, delta: float) -> void:
	age += delta
	timer -= delta
	_offset_clock -= delta
	flash = maxf(0.0, flash - delta)
	for part in _turrets:
		part.flash = maxf(0.0, part.flash - delta)
	if phase > 1 and _offset_clock <= 0.0:
		_offset_clock = 0.51
		var spark := position + Vector2(sin(7.1 * age) * 93.0, 38.0 + cos(3.5 * age) * 39.0)
		field.fx.burst(spark, phase_tone(), 3, 110.0)
	match state:
		"entry":
			var progress := clampf(age / 2.15, 0.0, 1.0)
			position.y = lerpf(-211.0, 229.0, 1.0 - pow(1.0 - progress, 2.4))
			if timer <= 0.0:
				_warn(field)
		"warning":
			if timer <= 0.0:
				_fire(field)
		"fire":
			_volley_left -= delta
			if _shots_left > 0 and _volley_left <= 0.0:
				_emit_volley(field, _shots_left)
				_shots_left -= 1
				_volley_left = 0.24
			if timer <= 0.0:
				state = "recover"
				timer = 1.25
		"recover":
			if phase < phase_total() and hp <= _floor():
				phase += 1
				phase_fired = false
				field.fx.ring(position, phase_tone(), 162.0, 0.63)
				field.fx.blast(position + Vector2(0, 38), 100.0, true, 0.45)
				field.sound_requested.emit("frontier_shift")
				_warn(field)
			elif timer <= 0.0:
				_warn(field)
			else:
				var steering := 270.0 + sin(age * 0.71) * (38.0 + phase * 7.0)
				position.x = move_toward(position.x, steering, delta * 65.0)


func _floor() -> float:
	return health_capacity() * (1.0 - float(phase) / phase_total())


func take_damage(amount: float) -> bool:
	if state == "entry" or hp <= 0.0:
		return false
	var floor_hp := maxf(_floor(), 1.0 if not phase_fired else 0.0)
	hp = maxf(floor_hp, hp - amount)
	flash = 0.11
	return hp <= 0.0


func damage_at(amount: float, contact: Vector2, field: Node2D) -> bool:
	for part in _turrets:
		var slot := position + part.mount
		if part.hp <= 0.0 or slot.distance_squared_to(contact) > pow(part.radius + 8.0, 2.0):
			continue
		part.hp = maxf(0.0, part.hp - amount)
		part.flash = 0.16
		if part.hp == 0.0:
			field.boss_module_destroyed(part.sprite, slot, phase_tone())
		return false
	return take_damage(amount)


func _trace(from: Vector2, axis: Vector2, squared: float, point: Vector2, radius: float) -> float:
	var progress := clampf((point - from).dot(axis) / squared, 0.0, 1.0)
	return progress if point.distance_squared_to(from + axis * progress) < radius * radius else 2.0


func hit_fraction(from: Vector2, to: Vector2, pad: float) -> float:
	var axis := to - from
	var squared := axis.length_squared()
	if squared < 0.001 or state == "entry":
		return 2.0
	var nearest := 2.0
	for part in _turrets:
		if part.hp > 0.0:
			nearest = minf(nearest, _trace(from, axis, squared, position + part.mount, part.radius + pad))
	if nearest <= 1.0:
		return nearest
	for zone: Vector3 in [Vector3(0, 10, 77), Vector3(-116, -14, 63), Vector3(116, -14, 63), Vector3(0, 74, 51)]:
		nearest = minf(nearest, _trace(from, axis, squared, position + Vector2(zone.x, zone.y), zone.z + pad))
	return nearest


func warning() -> String:
	if state == "entry":
		return encounter_name() + " · OKRĘT KAPITALNY"
	if state == "warning":
		var cue := "ZMIENIAJ WYSOKOŚĆ" if _attack in ["torpedoes", "gravity"] else "SZUKAJ PRZEJŚCIA"
		return "%s · %s" % [_spec.phases[phase - 1][0], cue]
	return ""


func _warn(field: Node2D) -> void:
	_attack = str(_spec.phases[phase - 1][1])
	state = "warning"
	_warning_span = 1.43 if _attack in ["crossfire", "gravity", "eclipse"] else 1.19
	_fixture_target = field.player_position
	_gap = clampf(_fixture_target.x + (89.0 if attack_count % 2 == 0 else -89.0), 106.0, 434.0)
	var tone := phase_tone()
	match _attack:
		"lance":
			for side: int in [-1, 1]:
				var source := position + Vector2(side * 95.0, 51.0)
				var exit := Vector2(clampf(_fixture_target.x + side * 148.0, 32.0, 508.0), 972.0)
				field.hazards.beam(source, exit, 49.0, _warning_span, 0.39, 22.0, tone)
		"crossfire":
			for side: int in [-1, 1]:
				var source := position + Vector2(side * 137.0, 37.0)
				field.hazards.beam(source, Vector2(270.0 - side * 235.0, 946.0), 46.0, _warning_span, 0.43, 26.0, tone)
		"torpedoes":
			for offset: float in [-116.0, 0.0, 116.0]:
				var target := Vector2(clampf(_fixture_target.x + offset, 64.0, 476.0), clampf(_fixture_target.y, 592.0, 837.0))
				field.hazards.blast(target, 57.0, _warning_span, 22.0, tone)
		"gravity":
			for mark in 3:
				var target := Vector2(95.0 + mark * 174.0, 635.0 if (mark + attack_count) % 2 == 0 else 813.0)
				field.hazards.blast(target, 70.0, _warning_span + mark * 0.24, 24.0, tone)
		"eclipse":
			for side: int in [-1, 1]:
				var slit := clampf(_gap + side * 108, 35.0, 505.0)
				field.hazards.beam(Vector2(slit, 325), Vector2(slit, 967), 57.0,
					_warning_span + (0.22 if side == 1 else 0.0), 0.46, 27.0, tone)
	timer = _warning_span
	field.sound_requested.emit("boss_warning")
	field.publish_telemetry()


func _fire(field: Node2D) -> void:
	state = "fire"
	phase_fired = true
	observed_phases |= 1 << (phase - 1)
	attack_count += 1
	_shots_left = 4 if _attack in ["gate", "eclipse", "sentry"] else 2
	_volley_left = 0.0
	timer = 1.26
	field.publish_telemetry()


func _emit_volley(field: Node2D, beat: int) -> void:
	var invader: Vector2
	var band := 280.0 + (4 - beat) * 15.0
	if _attack in ["gate", "eclipse"]:
		for lane in 12:
			var origin := Vector2(24.0 + lane * 44.4, position.y + 125.0)
			if absf(origin.x - _gap) < (57.0 if _attack == "gate" else 69.0):
				continue
			field.hostile_round(origin, Vector2.DOWN.rotated(sin(origin.x * 0.015) * 0.09), band, 13.0)
		return
	var muzzles: Array[Vector2] = []
	for part in _turrets:
		if part.hp > 0.0:
			muzzles.append(position + part.mount + Vector2(0.0, 18.0))
	if muzzles.is_empty():
		muzzles.append(position + Vector2(0.0, 95.0))
	for source in muzzles:
		invader = (_fixture_target + Vector2((beat - 2.5) * 26.0, 37.0) - source).normalized()
		var rays := 3 if _attack in ["sentry", "crossfire"] else 2
		for ray in rays:
			var angle := (ray - (rays - 1) * 0.5) * 0.20
			field.hostile_round(source, invader.rotated(angle), band * 0.85, 14.0)


func draw_hull(canvas: Node2D, hull: Texture2D, frame: Rect2, fx: RefCounted) -> void:
	var wear := 1.0 - hp / health_capacity()
	var tone := phase_tone()
	var base := Color.WHITE.lerp(Color("#868c92"), wear * 0.62).lerp(tone, flash * 2.9)
	var charge := clampf(1.0 - timer / _warning_span, 0.0, 1.0) if state == "warning" else 0.27
	canvas.draw_texture_rect(hull, Rect2(position + frame.position, frame.size), false, base)
	for part in _turrets:
		var at := position + part.mount
		if part.hp <= 0.0:
			fx.laser_contact(canvas, at, part.radius * 1.5, 0.13 + 0.10 * sin(age * 20.0))
			continue
		var extent := part.sprite.get_size().normalized() * part.radius * 2.8
		var rotation := clampf((at.x - _fixture_target.x) * .0021, -0.52, 0.52) * charge
		var shade := Color.WHITE.lerp(tone, charge * 0.20 + part.flash * 4.2)
		canvas.draw_set_transform(at + Vector2(0.0, 4.4 * charge), rotation)
		canvas.draw_texture_rect(part.sprite, Rect2(-extent * 0.5, extent), false, shade)
		canvas.draw_set_transform(Vector2.ZERO)
		var fraction := part.hp / part.full
		if fraction < 0.99:
			var rail := at + Vector2(-21.0, -part.radius - 3.0)
			canvas.draw_line(rail, rail + Vector2(42.0, 0.0), Color("#090e19fa"), 4.0, true)
			canvas.draw_line(rail, rail + Vector2(42.0 * fraction, 0.0), tone, 2.2, true)
		if state in ["warning", "fire"]:
			fx.laser_contact(canvas, at + Vector2(0, 22).rotated(rotation), 15.0 + charge * 19.0, charge * 0.63)
	if phase >= 2:
		var center := position + Vector2(0.0, -23.0)
		var rotation := age * (1.42 + phase * 0.63)
		canvas.draw_arc(center, 34.0, rotation, rotation + PI * 0.74, 15, Color(tone, .65), 2.0, true)
		canvas.draw_arc(center, 41.0, -rotation, -rotation + PI * 0.43, 13, Color(tone, .44), 1.5, true)


func draw_signals(canvas: Node2D) -> void:
	if state != "warning" or _attack not in ["gate", "eclipse"]:
		return
	var tone := Color(phase_tone(), 0.78)
	for side: int in [-1, 1]:
		var corner := Vector2(_gap + side * 53.0, 494.0)
		canvas.draw_line(corner, corner + Vector2(0, 30), tone, 2.2, true)
		canvas.draw_line(corner, corner + Vector2(-side * 13, 0), tone, 2.2, true)
