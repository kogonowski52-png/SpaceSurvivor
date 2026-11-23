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
const BattleFX := preload("res://combat/battle_fx.gd")
const Catalog := preload("res://data/progression_catalog.gd")
const Store := preload("res://data/store/commerce_catalog.gd")
const BOSS_ART := preload("res://assets/art/vertical/asterion.webp")
const PICKUP_ART := preload("res://assets/art/modules/reactor.webp")
const DRONE_ART := preload("res://assets/art/drone.png")
const Body := preload("res://assets/fonts/Barlow-Medium.ttf")

const SIZE := Vector2(540.0, 960.0)
const PLAY_AREA := Rect2(Vector2.ZERO, SIZE)
const FLIGHT_MIN := Vector2(33.0, 517.0)
const FLIGHT_MAX := Vector2(507.0, 861.0)
const PLAYER_RADIUS := 16.5
const MAX_ENEMIES := 36
const MAX_SHOTS := 196
const MAX_FRIENDLY := 88
const IDLE := -1
const MOUSE := -2

class Pickup:
	var id := "core"
	var position := Vector2.ZERO
	var age := 0.0

var player_position := Vector2(270.0, 813.0)
var gear := Ordnance.new()
var fx := BattleFX.new()
var boss: Commander
var boss_phases_fired := 0
var revive_offer_enabled := true
var viewport_field := Rect2()

var _stage_id := "echo"
var _stage: Dictionary = Campaign.STAGES.echo
var _threat := 1
var _duration := Campaign.DEFAULT_TIME_LIMIT
var _ship: Dictionary = Catalog.SHIPS.peregrine
var _stats: Dictionary = Catalog.BASE_STATS
var _skin: Dictionary = {}
var _hull: Texture2D
var _hull_frame := Rect2()
var _sky: Texture2D
var _boss_frame := Rect2()
var _stars := PackedVector2Array()
var _fighter_frames: Array[Rect2] = []
var _pointer := IDLE
var _pointer_offset := Vector2.ZERO
var _pointer_goal := player_position
var _bank := 0.0
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
var _next_in := 2.3
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
	_duration = Campaign.time_limit(_stage)
	_ship = Catalog.SHIPS.get(sortie.get("ship_id", "peregrine"), Catalog.SHIPS.peregrine)
	_stats = sortie.get("stats", Catalog.BASE_STATS)
	_skin = Store.SKINS.get(sortie.get("skin_id", ""), {})
	gear.reset(_stage.power, _stats)
	_max_hp = float(_stats.max_hp)
	_hp = _max_hp


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_hull = load(_ship.sprite)
	_hull_frame = _texture_frame(_hull, 86.0)
	_sky = load(_stage.sky)
	_boss_frame = _texture_frame(BOSS_ART, 324.0)
	for index in Squadron.ART.size():
		_fighter_frames.append(_texture_frame(Squadron.ART[index], Squadron.SIZE[index]))
	fx.prepare()
	fx._rng.seed = 210_707 + _threat
	var rng := RandomNumberGenerator.new()
	rng.seed = 726_571
	for index in 49:
		_stars.append(Vector2(rng.randf_range(0, SIZE.x), rng.randf_range(0, 1_265.0)))
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
	_move_pilot(delta)
	fx.step(delta)
	_step_director(delta)
	if _ended:
		return
	if boss != null:
		boss.step(self, delta)
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


func _step_director(delta: float) -> void:
	if _boss_defeated:
		_boss_break -= delta
		if _explosion_step == 0 and _boss_break < 1.06:
			_explosion_step += 1
			fx.burst(_wreck_point + Vector2(-82, -18), Color("#ffaf6e"), 19, 168.0)
			fx.burst(_wreck_point + Vector2(86, -16), Color("#ffcaa0"), 19, 184.0)
		if _boss_break <= 0.0:
			_finish(true)
		return
	if _seconds >= _duration:
		_finish(false, true)
		return
	if boss != null:
		return
	if _next_in > 0.0:
		_next_in -= delta
		if _next_in > 0.0:
			return
		_wave_index += 1
		var waves: Array = _stage.waves
		if _wave_index == waves.size():
			if _stage.get("boss", false):
				_clear_hostile_rounds()
				boss = Commander.new()
				sound_requested.emit("boss_warning")
				publish_telemetry()
			else:
				_finish(true)
			return
		_plan = Squadron.plan(waves[_wave_index].groups)
		_spawn_index = 0
		_wave_age = 0.0
		publish_telemetry()
	_wave_age += delta
	while _spawn_index < _plan.size() and _plan[_spawn_index].at <= _wave_age and _enemies.size() < MAX_ENEMIES:
		var enemy: Squadron.Fighter = Squadron.Fighter.new() if _enemy_pool.is_empty() else _enemy_pool.pop_back()
		enemy.reset(_plan[_spawn_index], _threat, _stage.hold)
		_enemies.append(enemy)
		_spawn_index += 1
	if _spawn_index == _plan.size() and _enemies.is_empty():
		_waves_cleared += 1
		var drop: String = _stage.waves[_wave_index].get("drop", "")
		_next_in = 3.6 if not drop.is_empty() else 2.1
		if not drop.is_empty():
			_spawn_pickup(drop, Vector2(clampf(player_position.x, 108.0, 432.0), 584.0))
		publish_telemetry()


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
		if enemy.fire_in > 0.0 or enemy.position.y < 81.0 or enemy.position.y > 521.0:
			continue
		enemy.fire_in = Squadron.SHOT_INTERVAL[enemy.kind] * (1.12 - _threat * 0.11)
		var aim := (player_position - enemy.position).normalized()
		var muzzle := enemy.position + Vector2(0.0, 17.0)
		if enemy.kind == Squadron.Kind.SCOUT:
			hostile_round(muzzle, Vector2.DOWN, 184.0 + _threat * 16.0, 10.0)
		elif enemy.kind == Squadron.Kind.RAZOR:
			hostile_round(muzzle, aim, 248.0, 12.0)
		else:
			for lane in 3:
				hostile_round(muzzle, aim.rotated((lane - 1.0) * 0.25), 210.0, 13.0)


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
	_power_notice = spec.title
	_power_notice_left = 2.25
	_power_tone = spec.tone
	_score += 150
	fx.ring(player_position, spec.tone, 88.0, 0.62)
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
		if shot.time <= 0.0 or not PLAY_AREA.grow(96.0).has_point(shot.position):
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
	var point := boss.position if boss != null and boss.state != "entry" else Vector2.ZERO
	var best := from.distance_squared_to(point) if point != Vector2.ZERO else INF
	for enemy in _enemies:
		if enemy.position.y < 28.0:
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
			var point := Vector2(from.x, lerpf(from.y, 24.0, fraction) + 24.0)
			if point.y > contact.y:
				contact = point
			_damage_boss(damage, point)
	return contact


func _damage_enemy(index: int, amount: float, contact: Vector2) -> void:
	var enemy := _enemies[index]
	enemy.hp -= amount
	var tone: Color = Squadron.COLORS[enemy.kind]
	if enemy.hp <= 0.0:
		_score += roundi((100.0 + enemy.kind * 63.0) * float(_stats.get("xp_multiplier", 1.0)))
		_kills += 1
		fx.burst(enemy.position, tone, 12 + enemy.kind * 4, 151.0)
		fx.ring(enemy.position, tone, 45.0 + enemy.kind * 7.0, 0.39)
		_recycle_enemy(index)
		sound_requested.emit("kill")
	elif enemy.flash < 0.03:
		enemy.flash = 0.105
		fx.burst(contact, tone, 3, 98.0, Vector2.DOWN)
		sound_requested.emit("hit")


func _damage_boss(amount: float, contact: Vector2) -> void:
	if boss == null or boss.state == "entry":
		return
	if boss.flash < 0.04:
		fx.burst(contact, Color("#ffc18c"), 4, 121.0)
	if not boss.take_damage(amount):
		return
	_wreck_point = boss.position
	boss_phases_fired = boss.observed_phases
	boss = null
	_boss_defeated = true
	_boss_break = 1.62
	_score += 5_000
	_kills += 1
	fx.capital_break(BOSS_ART, _wreck_point, 0.0, _boss_frame, Color("#ffbd8b"))
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
		"boss_defeated": _boss_defeated, "timed_out": timed_out,
		"reward": int(_stage.reward) + int(_kills / 3.0) if won else int(_kills / 3.0)})


func publish_telemetry() -> void:
	_report_in = 0.08
	var waves: Array = _stage.waves
	var briefing := "PRZECIĄGNIJ STATEK · OGIEŃ AUTOMATYCZNY" if _stage_id == "echo" and _wave_index < 0 else ""
	if _wave_index >= 0 and _wave_index < waves.size():
		briefing = str(waves[_wave_index].name).to_upper() if _wave_age < 2.8 else ""
	if _next_in > 0.0 and _wave_index >= 0 and not _pickups.is_empty():
		briefing = "PRZECHWYĆ ŁADUNEK"
	if _boss_defeated:
		briefing = "ASTERION ZNISZCZONY"
	telemetry.emit({"title": _stage.title, "track": _threat, "waves": waves.size(), "wave": mini(_wave_index + 1, waves.size()),
		"hp": _hp, "max_hp": _max_hp, "score": _score, "power": gear.rank, "weapon": Ordnance.MODES[gear.mode].title,
		"power_notice": _power_notice if _power_notice_left > 0.0 else "", "power_color": _power_tone,
		"briefing": briefing, "boss_hp": boss.hp if boss != null else -1.0, "boss_max": Commander.MAX_HP,
		"boss_phase": boss.phase if boss != null else 0, "danger": boss.warning() if boss != null else ""})


func _texture_frame(texture: Texture2D, longest: float) -> Rect2:
	var dimensions := texture.get_size()
	var scaled := dimensions * longest / maxf(dimensions.x, dimensions.y)
	return Rect2(-scaled * 0.5, scaled)


func _draw() -> void:
	if _hull == null:
		return
	_draw_sky()
	var visible := PLAY_AREA.grow(24.0)
	fx.render_capital_breaks(self, Vector2.ZERO, visible, player_position)
	fx.render(self, Vector2.ZERO, visible, player_position)
	for enemy in _enemies:
		if visible.has_point(enemy.position):
			_draw_fighter(enemy)
	if boss != null:
		draw_set_transform(boss.position)
		var tint := Color.WHITE.lerp(Color("#ffe0b5"), boss.flash * 5.0)
		draw_texture_rect(BOSS_ART, _boss_frame, false, tint)
		draw_set_transform(Vector2.ZERO)
	if gear.beam_left > 0.0:
		var emitter := gear.beam_start(player_position)
		var fade := minf(1.0, gear.beam_left / 0.09)
		fx.laser(self, emitter, Vector2(emitter.x, 12.0), gear.beam_age, fade)
		if gear.contact_left > 0.0:
			fx.laser_contact(self, gear.beam_contact, 32.0, minf(1.0, gear.contact_left / 0.06))
	for shot in _shots:
		if visible.has_point(shot.position):
			_draw_round(shot)
	for item in _pickups:
		_draw_pickup(item)
	if boss != null:
		boss.draw_signals(self)
	if not _ended or _hp > 0.0:
		_draw_pilot()


func _draw_sky() -> void:
	var ratio := maxf(scale.x, 0.01)
	var inner := get_viewport_rect().size / ratio
	var gutter := (inner - SIZE) * 0.5
	var view := Rect2(-gutter, inner)
	draw_rect(view, Color("#040814"))
	var scroll := fposmod(_seconds * 23.0, SIZE.y * 2.0)
	for index in range(-3, 2):
		var top := scroll + index * SIZE.y
		if top > view.end.y or top + SIZE.y < view.position.y:
			continue
		var reflected := posmod(index, 2) == 1
		var flip := -1.0 if reflected else 1.0
		draw_set_transform(Vector2(0.0, top + SIZE.y if reflected else top), 0.0, Vector2(1.0, flip))
		draw_texture_rect(_sky, PLAY_AREA, false, Color("#a1b4cf"))
	draw_set_transform(Vector2.ZERO)
	for index in _stars.size():
		var point := _stars[index]
		point.y = fposmod(point.y + _seconds * (99.0 if index % 3 == 0 else 45.0), 1_265.0) - 152.0
		var sight := 0.24 + 0.09 * sin(index * 2.6 + _seconds * 2.0)
		if index % 3 == 0:
			draw_line(point, point - Vector2(0, 9), Color("#8ac7ef", sight), 1.15, true)
		else:
			draw_circle(point, 1.25, Color("#d8eeff", sight + 0.17), true, -1.0, true)
	if gutter.y > 0.5:
		draw_rect(Rect2(0, -gutter.y, SIZE.x, gutter.y), Color("#05091278"))
		draw_rect(Rect2(0, SIZE.y, SIZE.x, gutter.y), Color("#05091278"))
		draw_line(Vector2.ZERO, Vector2(SIZE.x, 0), Color(_stage.tone, 0.22), 1.0)
		draw_line(Vector2(0, SIZE.y), SIZE, Color(_stage.tone, 0.22), 1.0)


func _draw_fighter(enemy: Squadron.Fighter) -> void:
	var frame := _fighter_frames[enemy.kind]
	var tone: Color = Squadron.COLORS[enemy.kind]
	draw_set_transform(enemy.position, enemy.heading)
	fx.small_engine(self, Vector2(0, frame.size.y * 0.42), frame.size.x * 0.085, 17.0 + enemy.kind * 7.0, tone, _seconds + enemy.offset)
	var flash := Color.WHITE.lerp(tone.lightened(0.35), enemy.flash * 6.0)
	draw_texture_rect(Squadron.ART[enemy.kind], frame, false, flash)
	draw_set_transform(Vector2.ZERO)


func _draw_round(shot: Ordnance.Shot) -> void:
	var tail := 28.0
	var width := 9.0
	match shot.kind:
		Ordnance.Kind.PLASMA:
			tail = 24.0
			width = 17.5
		Ordnance.Kind.ROCKET:
			tail = 43.0
			width = 12.0
		Ordnance.Kind.HOSTILE, Ordnance.Kind.ORBIT:
			tail = 20.0
			width = 12.0 if shot.kind == Ordnance.Kind.ORBIT else 10.0
	var tint := shot.tint
	if not shot.hostile() and shot.position.distance_squared_to(player_position) < 65.0 * 65.0:
		tint.a = 0.72
	fx.projectile(self, shot.position, shot.velocity.angle(), tail, width, tint, shot.hostile())


func _draw_pickup(item: Pickup) -> void:
	var info: Dictionary = Ordnance.DROPS[item.id]
	var tone: Color = info.tone
	var pulse := sin(_seconds * 5.5 + item.age)
	var center := item.position + Vector2(0, pulse * 3.0)
	draw_arc(center, 31.0, _seconds * 1.7, _seconds * 1.7 + 3.9, 24, Color(tone, 0.62 + pulse * 0.17), 1.8, true)
	draw_texture_rect(PICKUP_ART, Rect2(center - Vector2(22, 23), Vector2(44, 46)), false, tone.lightened(0.30))
	draw_string(Body, center + Vector2(-91.0, -39.0), info.title, HORIZONTAL_ALIGNMENT_CENTER, 182.0, 15, tone)


func _draw_pilot() -> void:
	if boss != null or _boss_break > 0.0:
		fx.pilot_backlight(self, player_position)
	if int(_stats.get("drone_rank", 0)) > 0:
		for side: int in [-1, 1]:
			var pos := player_position + Vector2(side * 52.0, 15.0 + sin(_seconds * 4.2 + side) * 4.0)
			draw_texture_rect(DRONE_ART, Rect2(pos - Vector2(13, 12), Vector2(26, 24)), false)
	draw_set_transform(player_position, _bank)
	var exhaust: Vector2 = _ship.exhaust
	var tone: Color = _ship.accent if _skin.is_empty() else _skin.accent
	var plume := gear.accent().lerp(tone, 0.48)
	for side: int in [-1, 1]:
		var nozzle := _hull_frame.size * Vector2(side * exhaust.x, exhaust.y)
		fx.small_engine(self, nozzle, 5.8, 26.0 + gear.rank * 2.6, plume, _seconds)
	var livery: Color = _skin.get("tint", Color.WHITE)
	livery = livery.lerp(Color("#ffb4a1"), _hull_flash * 1.25)
	draw_texture_rect(_hull, _hull_frame, false, livery)
	draw_set_transform(Vector2.ZERO)
	if muzzle_flash > 0.0:
		fx.laser_contact(self, player_position + Vector2(0.0, -36.0), 18.0, muzzle_flash * 7.2)
