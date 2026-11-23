extends SceneTree
## Compare the same collision workload, scene entry and renderer across revisions.

const Arena := preload("res://combat/arena.gd")
const SHOTS := 9000
const RENDER_SAMPLE_US := 4_000_000


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var start := Time.get_ticks_usec()
	var template := load("res://main.tscn") as PackedScene
	var game := template.instantiate()
	game.progression.save_path = "user://qa-perf"
	game.progression.legacy_path = ""
	root.add_child(game)
	await process_frame
	print("PERF menu_ms=%.3f" % _ms_since(start))
	var starts := PackedFloat64Array()
	for repeat in 7:
		start = Time.get_ticks_usec()
		game._start_mission()
		starts.append(_ms_since(start))
		game.arena.set_physics_process(false)
		await process_frame
	print("PERF first_arena_ms=%.3f" % starts[0])
	starts.remove_at(0)
	starts.sort()
	print("PERF restart_median_ms=%.3f" % _median(starts))
	var arena: Arena = game.arena
	_exercise_collisions(arena)
	if OS.get_cmdline_user_args().has("--render"):
		await _exercise_renderer(arena)
	quit()


func _exercise_collisions(arena: Arena) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 886316
	while arena._enemies.size() < Arena.MAX_ENEMIES:
		var index := arena._enemies.size()
		var position := Vector2(rng.randf_range(-1200, 1200), rng.randf_range(-1450, 1450))
		arena._spawn_enemy(index % Arena.EnemyKind.size(), position)
	var starts := PackedVector2Array()
	var finishes := PackedVector2Array()
	for index in SHOTS:
		var point := Vector2(rng.randf_range(-1200, 1200), rng.randf_range(-1450, 1450))
		var extent := 600.0 if index % 11 == 0 else 8.0
		starts.append(point)
		finishes.append(point + Vector2.from_angle(rng.randf_range(0, TAU)) * extent)
	var measurements := PackedFloat64Array()
	var hit_checksum := 0
	for batch in 6:
		var start := Time.get_ticks_usec()
		hit_checksum = 0
		for index in SHOTS:
			hit_checksum += 1 + arena._target_along_segment(starts[index], finishes[index], 6.0)
		if batch > 0:
			measurements.append(_ms_since(start))
	measurements.sort()
	print("PERF collision_queries=%d enemies=%d collision_median_ms=%.3f hit_checksum=%d" %
		[SHOTS, arena._enemies.size(), _median(measurements), hit_checksum])


func _exercise_renderer(arena: Arena) -> void:
	for index in arena._enemies.size():
		var origin := Vector2(float(index % 8) * 57.0 - 199.5, float(index / 8) * 90.0 - 310.0)
		arena._enemies[index].position = origin
	for index in 110:
		var origin := Vector2(float(index % 10) * 45.0 - 202.5, float(index / 10) * 65.0 - 330.0)
		arena._launch_shot(Arena.ShotKind.PULSE, origin, Vector2.UP * 500.0, 1, 3)
	for index in 10:
		arena._fx.ring(Vector2(index * 43.0 - 193.5, 60.0), Color("#a385f0"), 68.0, 0.7)
		arena._fx._rings.back().life = 0.35
	for index in 120:
		arena.queue_redraw()
		await process_frame
	var times := PackedFloat64Array()
	var rendered := Time.get_ticks_usec()
	while Time.get_ticks_usec() - rendered < RENDER_SAMPLE_US:
		arena.queue_redraw()
		var frame_start := Time.get_ticks_usec()
		await process_frame
		times.append(_ms_since(frame_start))
	var fps := float(times.size()) / (_ms_since(rendered) / 1000.0)
	times.sort()
	var p95 := times[floori(float(times.size() - 1) * 0.95)]
	print("PERF synthetic_render_fps=%.2f p95_ms=%.3f view=%s" % [fps, p95, str(root.size)])


func _ms_since(start: int) -> float:
	return (Time.get_ticks_usec() - start) / 1000.0


func _median(values: PackedFloat64Array) -> float:
	return (values[(values.size() - 1) >> 1] + values[values.size() >> 1]) * 0.5
