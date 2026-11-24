extends Node2D
## Scroll flight, input, pooled combat, and delivery of a single mission result.

signal telemetry(data: Dictionary)
signal mission_ended(result: Dictionary)
signal sound_requested(event: String)
signal revive_offered

const Campaign := preload("res://vertical/campaign.gd")
const Squadron := preload("res://vertical/squadron.gd")
const Ordnance := preload("res://vertical/ordnance.gd")
const Commander := preload("res://vertical/commander.gd")
const Dreadnought := preload("res://vertical/dreadnought.gd")
const FlightHazards := preload("res://vertical/flight_hazards.gd")
const FlightFX := preload("res://vertical/flight_fx.gd")
const PilotArt := preload("res://vertical/flight_art.gd")
const FlightSky := preload("res://vertical/flight_sky.gd")
const Catalog := preload("res://data/progression_catalog.gd")
const Store := preload("res://data/store/commerce_catalog.gd")
const BOSS_ART := preload("res://assets/art/premium/enemies/asterion.webp")
const TORPEDO_ART := preload("res://assets/art/chapter_one/modules/torpedo.webp")
const CAPITAL_PATHS := {
	"vesperon": "res://assets/art/chapter_one/enemies/vesperon.webp",
	"nadir": "res://assets/art/chapter_one/enemies/nadir.webp",
}
const DRONE_ART := preload("res://assets/art/drone.png")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")

const SIZE := Vector2(540.0, 960.0)
const PLAY_AREA := Rect2(Vector2.ZERO, SIZE)
const SHOT_BOUNDS := Rect2(-96.0, -96.0, 732.0, 1_152.0)
const FLIGHT_MIN := Vector2(33.0, 517.0)
const FLIGHT_MAX := Vector2(507.0, 861.0)
const PLAYER_RADIUS := 16.5
const MAX_ENEMIES := 36
const MAX_SHOTS := 196
const MAX_FRIENDLY := 88
const IDLE := -1
const MOUSE := -2
const BOSS_BREAK_SPAN := 2.48
const BREAK_PULSES := [
	[0.28, Vector2(-103, 23), 108.0], [0.56, Vector2(104, 23), 122.0],
	[0.90, Vector2(-61, -61), 93.0], [1.18, Vector2(72, -51), 101.0],
	[1.49, Vector2(0, 15), 230.0],
]

class Pickup:
	var id := "core"
	var position := Vector2.ZERO
	var age := 0.0

var player_position := Vector2(270.0, 813.0)
var gear := Ordnance.new()
var fx := FlightFX.new()
var hazards := FlightHazards.new()
var boss: Commander
var boss_phases_fired := 0
var seen_fighters := 0
var modules_destroyed := 0
var revive_offer_enabled := true
var viewport_field := Rect2()

var _stage_id := "echo"
var _stage: Dictionary = Campaign.STAGES.echo
var _threat := 1
var _duration := Campaign.DEFAULT_TIME_LIMIT
var _ship_id := "peregrine"
var _ship_art: Dictionary = PilotArt.HULLS.peregrine
var _stats: Dictionary = Catalog.BASE_STATS
var _skin: Dictionary = {}
var _hull: Texture2D
var _hull_frame := Rect2()
var _sky := FlightSky.new()
var _storm_light := 0.0
var _events: Array = []
var _event_index := 0
var _boss_id := ""
var _boss_texture: Texture2D = BOSS_ART
var _boss_frame := Rect2()
var _fighter_frames: Array[Rect2] = []
var _pointer := IDLE
var _pointer_offset := Vector2.ZERO
var _pointer_goal := player_position
var _bank := 0.0
var _thrust := 0.0
var _charge_fx := 0.0
var _seconds := 0.0
var _hp := 100.0
var _max_hp := 100.0
var _invulnerable := 0.0
var _hull_flash := 0.0
var muzzle_flash := 0.0
var _drone_cooldown := 0.0
var _report_in := 0.0
var _wave_index := -1
var _wave_age := 0.0
var _waves_cleared := 0
var _next_in := 0.28
var _intro_core_sent := false
var _plan: Array[Dictionary] = []
var _spawn_index := 0
var _enemies: Array[Squadron.Fighter] = []
var _enemy_pool: Array[Squadron.Fighter] = []
var _shots: Array[Ordnance.Shot] = []
var _shot_pool: Array[Ordnance.Shot] = []
var _friendly := 0
var _pickups: Array[Pickup] = []
var _power_notice := ""
var _power_notice_left := 0.0
var _power_tone := Color.WHITE
var _kills := 0
var _escaped := 0
var _score := 0
var _boss_break := 0.0
var _break_span := BOSS_BREAK_SPAN
var _break_tone := Color("#ffbd8b")
var _wreck_point := Vector2.ZERO
var _explosion_step := 0
var _boss_defeated := false
var _suspended := false
var _ended := false
var _revive_pending := false
var _revived := false


func configure(stage_id: String, sortie: Dictionary) -> void:
	_stage_id = stage_id
	_stage = Campaign.STAGES[stage_id]
	_threat = clampi(int(_stage.threat), 1, 6)
	_events = _stage.get("events", [])
	var encounter: Variant = _stage.get("boss", "")
	_boss_id = ("asterion" if encounter else "") if encounter is bool else str(encounter)
	if CAPITAL_PATHS.has(_boss_id):
		_boss_texture = load(CAPITAL_PATHS[_boss_id])
	_duration = Campaign.time_limit(_stage)
	_ship_id = str(sortie.get("ship_id", "peregrine"))
	if not PilotArt.HULLS.has(_ship_id):
		_ship_id = "peregrine"
	_ship_art = PilotArt.HULLS[_ship_id]
	_stats = sortie.get("stats", Catalog.BASE_STATS)
	_skin = Store.SKINS.get(sortie.get("skin_id", ""), {})
	gear.reset(_stage.power, _stats)
	_max_hp = float(_stats.max_hp)
	_hp = _max_hp


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_hull = PilotArt.hull(_ship_id)
	_hull_frame = PilotArt.frame(_hull, _ship_art.size)
	_sky.configure(_stage)
	var capital_size := 449.0 if _boss_id == "nadir" else (421.0 if _boss_id == "vesperon" else 403.0)
	_boss_frame = PilotArt.frame(_boss_texture, capital_size)
	for index in Squadron.ART.size():
		_fighter_frames.append(PilotArt.frame(Squadron.ART[index], Squadron.SIZE[index]))
	fx.prepare()
	fx._rng.seed = 210_707 + _threat
	get_viewport().size_changed.connect(_frame_view)
	_frame_view()
	publish_telemetry()


func _frame_view() -> void:
	var view := get_viewport_rect().size
	var ratio := minf(view.x / SIZE.x, view.y / SIZE.y)
	viewport_field = Rect2((view - SIZE * ratio) * 0.5, SIZE * ratio)
	position = viewport_field.position
	scale = Vector2.ONE * ratio
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _suspended or _ended or _revive_pending:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _pointer == IDLE and viewport_field.has_point(event.position):
			_grab(event.index, event.position)
		elif not event.pressed and _pointer == event.index:
			_pointer = IDLE
		else:
			return
	elif event is InputEventScreenDrag and event.index == _pointer:
		_pointer_goal = to_local(event.position) + _pointer_offset
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _pointer == IDLE and viewport_field.has_point(event.position):
			_grab(MOUSE, event.position)
		elif not event.pressed and _pointer == MOUSE:
			_pointer = IDLE
		else:
			return
	elif event is InputEventMouseMotion and _pointer == MOUSE:
		_pointer_goal = to_local(event.position) + _pointer_offset
	else:
		return
	get_viewport().set_input_as_handled()


func _grab(id: int, screen_point: Vector2) -> void:
	_pointer = id
	_pointer_offset = player_position - to_local(screen_point)
	_pointer_goal = player_position


func set_suspended(value: bool) -> void:
	_suspended = value
	_pointer = IDLE


func active_enemy_count() -> int:
	return _enemies.size() + int(boss != null)


func can_revive() -> bool:
	return _revive_pending and not _ended


func revive() -> void:
	if not can_revive():
		return
	_revive_pending = false
	_revived = true
	_hp = _max_hp * 0.5
	_invulnerable = 2.2
	_clear_hostile_rounds()
	hazards.clear()
	fx.ring(player_position, Color("#97f2e2"), 97.0, 0.65)
	publish_telemetry()


func decline_revive() -> void:
	if can_revive():
		_revive_pending = false
		_finish(false)


func _physics_process(delta: float) -> void:
	if _suspended or _revive_pending or _ended:
		return
	_seconds += delta
	_invulnerable = maxf(0.0, _invulnerable - delta)
	_hull_flash = maxf(0.0, _hull_flash - delta)
	muzzle_flash = maxf(0.0, muzzle_flash - delta)
	_power_notice_left = maxf(0.0, _power_notice_left - delta)
	_charge_fx = maxf(0.0, _charge_fx - delta)
	_storm_light = maxf(0.0, _storm_light - delta * 0.83)
	_move_pilot(delta)
	fx.step(delta)
	_step_director(delta)
	if _ended:
		return
	if boss != null:
		boss.step(self, delta)
	if not _boss_defeated:
		_step_weather()
		hazards.step(self, delta)
	_step_enemies(delta)
	_step_pickups(delta)
	if _boss_break <= 0.0 and not _revive_pending and not _ended:
		gear.step(self, delta)
		_step_escort(delta)
	_step_shots(delta)
	_report_in -= delta
	if _report_in <= 0.0:
		publish_telemetry()
	queue_redraw()


func _move_pilot(delta: float) -> void:
	var prior := player_position
	if _pointer == IDLE:
		var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		player_position += direction * delta * 422.0 * float(_stats.speed_multiplier)
	else:
		player_position = player_position.move_toward(_pointer_goal, delta * 1_405.0 * float(_stats.speed_multiplier))
	player_position = player_position.clamp(FLIGHT_MIN, FLIGHT_MAX)
	var lean := clampf((player_position.x - prior.x) / maxf(1.0, delta * 480.0), -1.0, 1.0) * 0.17
	_bank = lerpf(_bank, lean, minf(1.0, delta * 14.0))
	_thrust = lerpf(_thrust, minf(1.0, player_position.distance_to(prior) / maxf(1.0, delta * 435.0)), minf(1.0, delta * 8.0))


func weapon_socket(lane: float) -> Vector2:
	var socket := Vector2(lane * _hull_frame.size.x * 0.115, -_hull_frame.size.y * 0.42 + absf(lane) * 7.7)
	return player_position + socket.rotated(_bank)


func _step_director(delta: float) -> void:
	if _boss_defeated:
		_boss_break -= delta
		if _explosion_step < BREAK_PULSES.size() and _break_span - _boss_break >= float(BREAK_PULSES[_explosion_step][0]) * (_break_span / BOSS_BREAK_SPAN):
			var pulse: Array = BREAK_PULSES[_explosion_step]
			_explosion_step += 1
			var impact: Vector2 = _wreck_point + pulse[1]
			fx.blast(impact, float(pulse[2]) * (1.20 if _boss_id == "nadir" else 1.0), _boss_id == "nadir" and _explosion_step % 2 == 1, 0.71)
			fx.burst(impact, _break_tone, 22, 228.0)
			fx.ring(impact, _break_tone.lightened(0.21), float(pulse[2]) * 0.86, 0.72)
			if _explosion_step == BREAK_PULSES.size():
				sound_requested.emit("boss_break")
		if _boss_break <= 0.0:
			_finish(true)
		return
	if _seconds >= _duration:
		_finish(false, true)
		return
	if boss != null:
		return
	if _stage_id == "echo" and not _intro_core_sent and (_kills > 0 or _seconds >= 3.9):
		_intro_core_sent = true
		_spawn_pickup("core", Vector2(clampf(player_position.x, 79.0, 461.0), 674.0))
	if _next_in > 0.0:
		_next_in -= delta
		if _next_in > 0.0:
			return
		_wave_index += 1
		var waves: Array = _stage.waves
		if _wave_index == waves.size():
			if not _boss_id.is_empty():
				_clear_hostile_rounds()
				hazards.clear()
				boss = Commander.new() if _boss_id == "asterion" else Dreadnought.new(_boss_id)
				sound_requested.emit("boss_warning")
				publish_telemetry()
			else:
				_finish(true)
			return
		_plan = Squadron.plan(waves[_wave_index].groups)
		for mark: Array in waves[_wave_index].get("salvo", []):
			var warning := float(mark[2])
			hazards.blast(Vector2(mark[0], mark[1]), 65.0, warning, 22.0, Color("#ffad80"), "SEKWENCJA ZAPŁONU")
		_spawn_index = 0
		_wave_age = 0.0
		publish_telemetry()
	_wave_age += delta
	while _spawn_index < _plan.size() and _plan[_spawn_index].at <= _wave_age and _enemies.size() < MAX_ENEMIES:
		var enemy: Squadron.Fighter = Squadron.Fighter.new() if _enemy_pool.is_empty() else _enemy_pool.pop_back()
		enemy.reset(_plan[_spawn_index], _threat, _stage.hold)
		seen_fighters |= 1 << enemy.kind
		_enemies.append(enemy)
		_spawn_index += 1
	if _spawn_index == _plan.size() and _enemies.is_empty():
		_waves_cleared += 1
		var drop: String = _stage.waves[_wave_index].get("drop", "")
		_next_in = 0.85 if not drop.is_empty() else 0.67
		if not drop.is_empty():
			_spawn_pickup(drop, Vector2(clampf(player_position.x, 85.0, 455.0), 602.0))
		publish_telemetry()


func _step_weather() -> void:
	while _event_index < _events.size() and float(_events[_event_index][0]) <= _seconds:
		var spec: Array = _events[_event_index]
		_event_index += 1
		var x := float(spec[2])
		match spec[1]:
			"debris":
				hazards.debris(x, 1.08, float(spec[3]), int(spec[4]), Color("#ffba90"))
			"surge":
				_storm_light = 0.76
				hazards.beam(Vector2(x, 153), Vector2(x + float(spec[3]), 963), 50.0, 1.37, 0.39,
					20.0, Color("#9ee9eb"), "WYŁADOWANIE · ZMIEŃ PAS")
				sound_requested.emit("frontier_shift")
			"flare":
				_storm_light = 0.66
				hazards.blast(Vector2(x, float(spec[3])), 68.0, 1.17, 21.0, Color("#ffc090"), "ROZBŁYSK · OPUŚĆ POLE")


func _step_enemies(delta: float) -> void:
	for index in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[index]
		enemy.advance(delta)
		if enemy.departed:
			_escaped += 1
			_recycle_enemy(index)
			continue
		var distance := float(Squadron.RADIUS[enemy.kind]) + PLAYER_RADIUS
		if enemy.position.distance_squared_to(player_position) < distance * distance:
			hit_player(15.0 + enemy.kind * 4.0)
			continue
		enemy.fire_in -= delta
		if enemy.kind in [Squadron.Kind.BOMBER, Squadron.Kind.PHANTOM] and not enemy.signalled and enemy.fire_in < 0.48 and enemy.position.y > 80.0 and enemy.position.y < 510.0:
			enemy.signalled = true
			fx.ring(enemy.position, Squadron.COLORS[enemy.kind], 26.0, 0.40)
			sound_requested.emit("frontier_contact")
		if enemy.fire_in > 0.0 or enemy.position.y < 81.0 or enemy.position.y > 521.0:
			continue
		enemy.signalled = false
		enemy.fire_in = Squadron.SHOT_INTERVAL[enemy.kind] * (1.20 - _threat * 0.112)
		var aim := (player_position - enemy.position).normalized()
		var muzzle := enemy.position + Vector2(0.0, 17.0)
		match enemy.kind:
			Squadron.Kind.SCOUT:
				hostile_round(muzzle, Vector2.DOWN, 193.0 + _threat * 14.0, 8.0 + _threat)
			Squadron.Kind.RAZOR:
				hostile_round(muzzle, aim, 238.0 + _threat * 7.0, 10.0 + _threat)
			Squadron.Kind.WARDEN:
				for lane in 3:
					hostile_round(muzzle + Vector2((lane - 1.0) * 10.0, 0.0), aim.rotated((lane - 1.0) * 0.24), 218.0, 11.0 + _threat)
			Squadron.Kind.INTERCEPTOR:
				for side: int in [-1, 1]:
					hostile_round(muzzle + Vector2(side * 9.0, 0.0), aim.rotated(side * 0.08), 319.0, 12.0)
			Squadron.Kind.CARRIER:
				hostile_round(muzzle, Vector2.DOWN.rotated(0.26 * signf(270.0 - muzzle.x)), 183.0, 13.0, 0.33)
			Squadron.Kind.BOMBER:
				launch_bomb(muzzle, player_position)
			Squadron.Kind.PHANTOM:
				for side: int in [-1, 1]:
					hostile_round(muzzle + Vector2(side * 16.0, 0.0), aim.rotated(side * 0.30), 249.0, 15.0, -side * 0.46)


func _step_escort(delta: float) -> void:
	var rank := int(_stats.get("drone_rank", 0))
	if rank <= 0:
		return
	_drone_cooldown -= delta
	if _drone_cooldown > 0.0:
		return
	_drone_cooldown = maxf(0.43, 0.86 - 0.08 * rank)
	var damage := (5.7 + rank * 0.8) * float(_stats.get("drone_damage_multiplier", 1.0))
	for side: int in [-1, 1]:
		spawn_shot(player_position + Vector2(side * 52.0, 15.0), Vector2.UP * 685.0, Ordnance.Kind.PULSE,
			damage, 2.0, 0.0, Color("#ffe4a7"))
	sound_requested.emit("drone")


func _spawn_pickup(id: String, at: Vector2) -> void:
	var item := Pickup.new()
	item.id = id
	item.position = at
	_pickups.append(item)
	fx.ring(at, Ordnance.DROPS[id].tone, 51.0, 0.53)


func _step_pickups(delta: float) -> void:
	for index in range(_pickups.size() - 1, -1, -1):
		var item := _pickups[index]
		item.age += delta
		var magnet := 63.0 + float(_stats.get("magnet_bonus", 0.0))
		var distance := item.position.distance_squared_to(player_position)
		if distance < 32.0 * 32.0:
			_collect(item.id)
			_pickups.remove_at(index)
		elif item.age > 9.5:
			_pickups.remove_at(index)
		elif distance < magnet * magnet:
			item.position = item.position.move_toward(player_position, delta * 266.0)
		else:
			item.position.y = move_toward(item.position.y, 846.0, delta * 115.0)


func _collect(id: String) -> void:
	var spec: Dictionary = Ordnance.DROPS[id]
	if id == "repair":
		_hp = minf(_max_hp, _hp + _max_hp * 0.32)
	else:
		gear.power_up(id)
		_charge_fx = 0.66
	_power_notice = spec.title
	_power_notice_left = 2.25
	_power_tone = spec.tone
	_score += 150
	fx.ring(player_position, spec.tone, 88.0, 0.62)
	fx.ring(player_position, spec.tone.lightened(0.3), 55.0, 0.34)
	fx.burst(player_position + Vector2(0, -28), spec.tone, 15, 170.0, Vector2.UP)
	sound_requested.emit("pickup" if id == "repair" else "upgrade")
	publish_telemetry()


func spawn_shot(at: Vector2, velocity: Vector2, kind: int, damage: float, lifetime: float, turn: float, tint: Color) -> void:
	var friendly := kind < Ordnance.Kind.HOSTILE
	if _shots.size() >= MAX_SHOTS or (friendly and _friendly >= MAX_FRIENDLY):
		return
	var shot: Ordnance.Shot = Ordnance.Shot.new() if _shot_pool.is_empty() else _shot_pool.pop_back()
	shot.kind = kind
	shot.position = at
	shot.velocity = velocity
	shot.damage = damage
	shot.time = lifetime
	shot.turn = turn
	shot.tint = tint
	_shots.append(shot)
	_friendly += int(friendly)


func hostile_round(at: Vector2, direction: Vector2, speed: float, damage: float, turn := 0.0) -> void:
	spawn_shot(at, direction * speed, Ordnance.Kind.HOSTILE if is_zero_approx(turn) else Ordnance.Kind.ORBIT,
		damage, 4.7, turn, Color.WHITE)


func launch_bomb(at: Vector2, goal: Vector2) -> void:
	var destination := goal.clamp(Vector2(62, 583), Vector2(478, 846))
	const TRAVEL := 1.16
	spawn_shot(at, (destination - at) / TRAVEL, Ordnance.Kind.BOMB, 23.0, TRAVEL, 0.0, Color("#ffc08a"))


func _step_shots(delta: float) -> void:
	for index in range(_shots.size() - 1, -1, -1):
		if _revive_pending or _ended:
			return
		var shot := _shots[index]
		shot.time -= delta
		if shot.kind == Ordnance.Kind.ROCKET:
			var target := _nearest_target(shot.position)
			if target != Vector2.ZERO:
				var aim := shot.position.angle_to_point(target)
				shot.velocity = Vector2.from_angle(rotate_toward(shot.velocity.angle(), aim, delta * 3.9)) * 462.0
		elif shot.kind == Ordnance.Kind.ORBIT:
			shot.velocity = shot.velocity.rotated(delta * shot.turn)
		var from := shot.position
		shot.position += shot.velocity * delta
		if shot.kind == Ordnance.Kind.BOMB:
			if shot.time <= 0.0 and _boss_break <= 0.0:
				hazards.blast(shot.position, 53.0, 0.94, shot.damage, Color("#ffab8a"), "TORPEDA · OPUŚĆ POLE")
				_recycle_shot(index)
			elif _boss_break > 0.0 or not SHOT_BOUNDS.has_point(shot.position):
				_recycle_shot(index)
			continue
		if shot.time <= 0.0 or not SHOT_BOUNDS.has_point(shot.position):
			_recycle_shot(index)
		elif shot.hostile():
			if _boss_break > 0.0:
				_recycle_shot(index)
			elif Geometry2D.get_closest_point_to_segment(player_position, from, shot.position).distance_squared_to(player_position) < pow(PLAYER_RADIUS + 4.0, 2):
				hit_player(shot.damage)
				_recycle_shot(index)
		elif _hit_target(shot, from):
			_recycle_shot(index)


func _nearest_target(from: Vector2) -> Vector2:
	var point := boss.aim_point(from) if boss != null and boss.state != "entry" else Vector2.ZERO
	var best := from.distance_squared_to(point) if point != Vector2.ZERO else INF
	for enemy in _enemies:
		if enemy.position.y < 28.0 or enemy.cloaked():
			continue
		var squared := from.distance_squared_to(enemy.position)
		if squared < best:
			best = squared
			point = enemy.position
	return point


func _hit_target(shot: Ordnance.Shot, from: Vector2) -> bool:
	var end := shot.position
	var axis := end - from
	var squared := axis.length_squared()
	if squared < 0.001:
		return false
	var nearest := boss.hit_fraction(from, end, 4.0) if boss != null else 2.0
	var found := -1
	for index in _enemies.size():
		var enemy := _enemies[index]
		var reach := float(Squadron.RADIUS[enemy.kind]) + (6.0 if shot.kind == Ordnance.Kind.PLASMA else 3.0)
		if enemy.position.y < 18.0 or absf(from.y - enemy.position.y) > reach + absf(axis.y):
			continue
		var along := clampf((enemy.position - from).dot(axis) / squared, 0.0, 1.0)
		if along < nearest and (from + axis * along).distance_squared_to(enemy.position) < reach * reach:
			found = index
			nearest = along
	if found < 0 and nearest > 1.0:
		return false
	var contact := from + axis * nearest
	if found >= 0:
		_damage_enemy(found, shot.damage, contact)
	else:
		_damage_boss(shot.damage, contact)
	if shot.kind == Ordnance.Kind.PLASMA:
		fx.blast(contact, 49.0, true, 0.28)
		fx.ring(contact, Color("#d492ff"), 38.0, 0.28)
		for index in range(_enemies.size() - 1, -1, -1):
			if _enemies[index].position.distance_squared_to(contact) < 39.0 * 39.0:
				_damage_enemy(index, shot.damage * 0.31, contact)
	return true


func beam_damage(from: Vector2, damage: float) -> Vector2:
	var contact := Vector2.ZERO
	for index in range(_enemies.size() - 1, -1, -1):
		var enemy := _enemies[index]
		if enemy.position.y < from.y and enemy.position.y > 24.0 and absf(enemy.position.x - from.x) < float(Squadron.RADIUS[enemy.kind]) + 8.0:
			var point := Vector2(from.x, enemy.position.y + float(Squadron.RADIUS[enemy.kind]) * 0.66)
			if point.y > contact.y:
				contact = point
			_damage_enemy(index, damage, point)
	if boss != null:
		var fraction := boss.hit_fraction(from, Vector2(from.x, 24.0), 8.0)
		if fraction <= 1.0:
			var point := Vector2(from.x, lerpf(from.y, 24.0, fraction))
			if point.y > contact.y:
				contact = point
			_damage_boss(damage, point)
	return contact


func _damage_enemy(index: int, amount: float, contact: Vector2) -> void:
	var enemy := _enemies[index]
	if enemy.cloaked():
		amount *= 0.38
	if enemy.kind != Squadron.Kind.CARRIER:
		amount = _absorb_with_shield(enemy.position, amount, contact)
	enemy.hp -= amount
	var tone: Color = Squadron.COLORS[enemy.kind]
	if enemy.hp <= 0.0:
		_score += roundi((100.0 + enemy.kind * 63.0) * float(_stats.get("xp_multiplier", 1.0)))
		_kills += 1
		var weight := clampi(roundi(float(Squadron.SIZE[enemy.kind]) * 0.12), 6, 14)
		fx.burst(enemy.position, tone, 9 + weight, 151.0)
		fx.shatter(Squadron.ART[enemy.kind], enemy.position, _fighter_frames[enemy.kind], enemy.heading)
		fx.blast(enemy.position, float(Squadron.SIZE[enemy.kind]) * 0.79)
		fx.ring(enemy.position, tone, float(Squadron.SIZE[enemy.kind]) * 0.78, 0.39)
		_recycle_enemy(index)
		sound_requested.emit("kill")
	elif enemy.flash < 0.03:
		enemy.flash = 0.105
		fx.burst(contact, tone, 3, 98.0, Vector2.DOWN)
		sound_requested.emit("hit")


func _absorb_with_shield(position_hit: Vector2, amount: float, contact: Vector2) -> float:
	for carrier in _enemies:
		if carrier.shield <= 0.0 or carrier.position.distance_squared_to(position_hit) > Squadron.SHIELD_RADIUS * Squadron.SHIELD_RADIUS:
			continue
		var absorbed := minf(amount * 0.76, carrier.shield)
		carrier.shield -= absorbed
		if carrier.shield_flash < 0.05:
			carrier.shield_flash = 0.19
			fx.ring(contact, Color("#80d8fa"), 29.0, 0.29)
			sound_requested.emit("frontier_shield")
		if carrier.shield <= 0.0:
			fx.blast(carrier.position, 76.0, true, 0.46)
		return amount - absorbed
	return amount


func boss_module_destroyed(art: Texture2D, at: Vector2, tone: Color) -> void:
	modules_destroyed += 1
	_score += 875
	fx.shatter(art, at, PilotArt.frame(art, 61.0), 0.0)
	fx.blast(at, 86.0, false, 0.57)
	fx.ring(at, tone, 75.0, 0.52)
	fx.burst(at, tone, 18, 180.0)
	sound_requested.emit("frontier_module")
	publish_telemetry()


func _damage_boss(amount: float, contact: Vector2) -> void:
	if boss == null or boss.state == "entry":
		return
	if boss.flash < 0.04:
		fx.burst(contact, Color("#ffc18c"), 4, 121.0)
	if not boss.damage_at(amount, contact, self):
		return
	_wreck_point = boss.position
	boss_phases_fired = boss.observed_phases
	_break_tone = boss.phase_tone()
	_score += boss.score_value()
	boss = null
	_boss_defeated = true
	_break_span = 3.58 if _boss_id == "nadir" else (3.02 if _boss_id == "vesperon" else BOSS_BREAK_SPAN)
	_boss_break = _break_span
	_kills += 1
	hazards.clear()
	gear.beam_left = 0.0
	fx.capital_break(_boss_texture, _wreck_point, 0.0, _boss_frame, _break_tone)
	fx.blast(_wreck_point + Vector2(0.0, -22.0), 143.0, false, 0.66)
	fx.ring(_wreck_point, Color("#fff1b9"), 215.0, 1.1)
	sound_requested.emit("boss_break")
	publish_telemetry()


func hit_player(amount: float) -> void:
	if _invulnerable > 0.0 or _revive_pending or _ended or _boss_defeated:
		return
	_hp = maxf(0.0, _hp - amount * float(_stats.damage_taken_multiplier))
	_invulnerable = 0.84
	_hull_flash = 0.37
	fx.burst(player_position, Color("#ffa095"), 14, 161.0)
	sound_requested.emit("hurt")
	publish_telemetry()
	if _hp > 0.0:
		return
	if revive_offer_enabled and not _revived:
		_revive_pending = true
		_pointer = IDLE
		revive_offered.emit()
	else:
		_finish(false)


func _recycle_shot(index: int) -> void:
	var shot := _shots[index]
	_friendly -= int(not shot.hostile())
	_shot_pool.append(shot)
	_shots[index] = _shots.back()
	_shots.pop_back()


func _clear_hostile_rounds() -> void:
	for index in range(_shots.size() - 1, -1, -1):
		if _shots[index].hostile():
			_recycle_shot(index)


func _recycle_enemy(index: int) -> void:
	_enemy_pool.append(_enemies[index])
	_enemies[index] = _enemies.back()
	_enemies.pop_back()


func _finish(won: bool, timed_out := false) -> void:
	if _ended:
		return
	_ended = true
	_pointer = IDLE
	queue_redraw()
	mission_ended.emit({"won": won, "seconds": _seconds, "kills": _kills, "escaped": _escaped,
		"level": gear.rank, "score": _score, "waves": _waves_cleared, "stage": _stage_id,
		"hull_ratio": _hp / maxf(_max_hp, 1.0), "revived": _revived, "modules": modules_destroyed,
		"boss_defeated": _boss_defeated, "timed_out": timed_out,
		"reward": int(_stage.reward) + int(_kills / 3.0) if won else int(_kills / 3.0)})


func publish_telemetry() -> void:
	_report_in = 0.08
	var waves: Array = _stage.waves
	var briefing := ""
	if _wave_index >= 0 and _wave_index < waves.size() and _wave_age < 2.22:
		briefing = str(waves[_wave_index].name).to_upper()
	if _stage_id == "echo" and _seconds < 2.8:
		briefing = "PRZECIĄGNIJ STATEK"
	if not _pickups.is_empty() and _seconds < 9.0:
		briefing = "ZBIERZ RDZEŃ OGNIA"
	if _boss_defeated:
		briefing = "%s ZNISZCZONY" % ("ASTERION" if _boss_id == "asterion" else _boss_id.to_upper())
	var danger := boss.warning() if boss != null else ""
	if danger.is_empty():
		danger = hazards.urgent()
	telemetry.emit({"title": _stage.title, "track": _threat, "waves": waves.size(), "wave": mini(_wave_index + 1, waves.size()),
		"hp": _hp, "max_hp": _max_hp, "score": _score, "power": gear.rank, "weapon": Ordnance.MODES[gear.mode].title,
		"power_notice": _power_notice if _power_notice_left > 0.0 else "", "power_color": _power_tone,
		"briefing": briefing, "boss_hp": boss.hp if boss != null else -1.0, "boss_max": boss.health_capacity() if boss != null else 1.0,
		"boss_phase": boss.phase if boss != null else 0, "boss_phases": boss.phase_total() if boss != null else 0,
		"boss_name": boss.encounter_name() if boss != null else "", "boss_tone": boss.phase_tone() if boss != null else Color.WHITE,
		"boss_modules": boss.modules_left() if boss != null else -1, "danger": danger})


func _draw() -> void:
	if _hull == null:
		return
	var view_size := get_viewport_rect().size / maxf(scale.x, 0.01)
	var energy := maxf(_storm_light, maxf(_charge_fx * 0.76, minf(0.80, _boss_break * 0.43)))
	_sky.draw(self, Rect2((SIZE - view_size) * 0.5, view_size), _seconds, player_position.x, energy)
	var visible := PLAY_AREA.grow(24.0)
	fx.render_capital_breaks(self, Vector2.ZERO, visible, player_position)
	for enemy in _enemies:
		if visible.has_point(enemy.position):
			_draw_fighter(enemy)
	if boss != null:
		boss.draw_hull(self, _boss_texture, _boss_frame, fx)
	fx.draw_flares(self, visible, player_position)
	fx.render(self, Vector2.ZERO, visible, player_position)
	hazards.render(self, _seconds)
	if gear.beam_left > 0.0:
		var emitter := weapon_socket(0.0)
		var fade := minf(minf(1.0, gear.beam_age / 0.04), gear.beam_left / 0.09)
		fx.laser(self, emitter, Vector2(emitter.x, 13.0), gear.beam_age, fade)
		if gear.contact_left > 0.0:
			fx.laser_contact(self, gear.beam_contact, 34.0 + gear.rank * 1.4, minf(1.0, gear.contact_left / 0.06))
	for shot in _shots:
		if visible.has_point(shot.position) and (_boss_break <= 0.0 or not shot.hostile()):
			_draw_round(shot)
	for item in _pickups:
		_draw_pickup(item)
	if boss != null:
		boss.draw_signals(self)
	if not _ended or _hp > 0.0:
		_draw_pilot()


func _draw_fighter(enemy: Squadron.Fighter) -> void:
	var frame := _fighter_frames[enemy.kind]
	var tone: Color = Squadron.COLORS[enemy.kind]
	var veil := 0.19 + sin(_seconds * 9.0 + enemy.offset) * 0.055 if enemy.cloaked() else 1.0
	if enemy.shield > 0.0:
		var opacity := 0.24 + enemy.shield_flash * 2.0
		var angle := _seconds * 1.6
		draw_arc(enemy.position, Squadron.SHIELD_RADIUS, angle, angle + PI * 0.86, 24, Color(tone, opacity), 1.7, true)
		draw_arc(enemy.position, Squadron.SHIELD_RADIUS, angle + PI, angle + PI * 1.87, 24, Color(tone, opacity), 1.7, true)
	draw_set_transform(enemy.position, enemy.heading)
	if veil > 0.3:
		var drive := 38.0 if enemy.kind == Squadron.Kind.INTERCEPTOR else 14.0 + frame.size.y * 0.085
		fx.small_engine(self, Vector2(0.0, frame.size.y * 0.45), frame.size.x * 0.095, drive, tone, _seconds + enemy.offset)
	draw_texture_rect(Squadron.ART[enemy.kind], frame, false, Color(Color.WHITE.lerp(tone.lightened(0.46), enemy.flash * 5.5), veil))
	draw_set_transform(Vector2.ZERO)
	if enemy.fire_in < 0.34 and enemy.age > enemy.entry and enemy.position.y < 500.0:
		var charge := clampf(1.0 - enemy.fire_in / 0.34, 0.0, 1.0)
		fx.laser_contact(self, enemy.position + Vector2(0.0, 19.0), 11.0 + charge * 6.0, charge * 0.72)


func _draw_round(shot: Ordnance.Shot) -> void:
	var direction := shot.velocity.angle()
	if shot.kind == Ordnance.Kind.BOMB:
		draw_set_transform(shot.position, direction + PI * 0.5)
		fx.small_engine(self, Vector2(0, 8), 4.9, 18.0, shot.tint, _seconds)
		draw_set_transform(shot.position, direction - PI * 0.5)
		draw_texture_rect(TORPEDO_ART, Rect2(-10.0, -16.0, 20.0, 32.0), false)
		draw_set_transform(Vector2.ZERO)
		return
	if shot.kind == Ordnance.Kind.ROCKET:
		fx.missile(self, shot.position, direction, shot.tint, _seconds)
		return
	var tail := 32.0
	var width := 9.0
	if shot.kind == Ordnance.Kind.PLASMA:
		tail = 21.0
		width = 18.0
	elif shot.hostile():
		tail = 18.0
		width = 13.0 if shot.kind == Ordnance.Kind.ORBIT else 11.0
	var tint := shot.tint
	if not shot.hostile() and shot.position.distance_squared_to(player_position) < 62.0 * 62.0:
		tint.a = 0.76
	fx.projectile(self, shot.position, direction, tail, width, tint, shot.hostile())
	if shot.kind == Ordnance.Kind.PLASMA:
		var nucleus := 7.4 + sin(_seconds * 16.0 + shot.position.y * 0.043) * 1.3
		fx.laser_contact(self, shot.position, nucleus * 2.0, tint.a * 0.62)
	elif shot.hostile():
		draw_line(shot.position - shot.velocity.normalized() * 5.6, shot.position, Color("#ffc083"), 2.2, true)


func _draw_pickup(item: Pickup) -> void:
	var info: Dictionary = Ordnance.DROPS[item.id]
	var tone: Color = info.tone
	var pulse := sin(_seconds * 5.5 + item.age)
	var center := item.position + Vector2(0.0, pulse * 3.0)
	var enter := smoothstep(0.0, 0.32, item.age)
	var alpha := enter * (1.0 - smoothstep(8.9, 9.5, item.age))
	var texture: Texture2D = info.art
	var frame := PilotArt.frame(texture, (47.0 + pulse * 1.7) * lerpf(0.63, 1.0, enter))
	draw_arc(center, 33.0, _seconds * 1.7, _seconds * 1.7 + 3.4, 19, Color(tone, alpha * 0.48), 1.5, true)
	draw_arc(center, 33.0, _seconds * 1.7 + PI * 1.3, _seconds * 1.7 + PI * 1.82, 8, Color(tone, alpha * 0.64), 1.5, true)
	draw_texture_rect(texture, Rect2(center + frame.position, frame.size), false, Color(1.0, 1.0, 1.0, alpha))
	draw_string(Body, center + Vector2(-91.0, -39.0), info.title, HORIZONTAL_ALIGNMENT_CENTER, 182.0, 16, Color(tone, alpha))


func _draw_pilot() -> void:
	if boss != null or _boss_break > 0.0:
		fx.pilot_backlight(self, player_position)
	if int(_stats.get("drone_rank", 0)) > 0:
		for side: int in [-1, 1]:
			var pos := player_position + Vector2(side * 52.0, 15.0 + sin(_seconds * 4.2 + side) * 4.0)
			draw_texture_rect(DRONE_ART, Rect2(pos - Vector2(13, 12), Vector2(26, 24)), false)
	draw_set_transform(player_position, _bank)
	var tone: Color = _ship_art.energy if _skin.is_empty() else _skin.accent
	var plume := gear.accent().lerp(tone, 0.73)
	for anchor: Vector2 in _ship_art.ports:
		var nozzle := _hull_frame.size * anchor
		fx.small_engine(self, nozzle, 5.6, 21.0 + _thrust * 16.0 + gear.rank * 1.9 + _charge_fx * 22.0, plume, _seconds + anchor.x)
	var livery: Color = _skin.get("tint", Color.WHITE)
	livery = livery.lerp(Color("#ffad9b"), _hull_flash * 1.36)
	var recoil := muzzle_flash * (12.0 + gear.rank * 2.5)
	draw_texture_rect(_hull, Rect2(_hull_frame.position + Vector2(0.0, recoil), _hull_frame.size), false, livery)
	draw_set_transform(Vector2.ZERO)
	if muzzle_flash > 0.0:
		var count: int = Ordnance.EMITTERS[gear.rank - 1]
		var opacity := minf(0.67, muzzle_flash * (7.0 if count > 3 else 10.0))
		for index in count:
			var lane := index - (count - 1) * 0.5
			fx.laser_contact(self, weapon_socket(lane), 11.0 + gear.rank * 1.4, opacity)
