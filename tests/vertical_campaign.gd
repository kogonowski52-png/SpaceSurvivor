extends "res://tests/smoke.gd"
## Runs the normal campaign entry point. Rendering mode uses isolated repeatable scene fixtures.

const Campaign := preload("res://vertical/campaign.gd")
const Flight := preload("res://vertical/field.gd")
const Squadron := preload("res://vertical/squadron.gd")
const Weapons := preload("res://vertical/ordnance.gd")
const Commander := preload("res://vertical/commander.gd")
const Pilot := preload("res://data/pilot_progression.gd")

var profile_path := "user://qa-vertical-" + str(Time.get_ticks_usec())


func _run() -> void:
	if capture_dir.is_empty():
		_test_profile()
		_test_ordnance()
	var entry := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	if not _check(entry != null, "default campaign scene loads"):
		quit(1)
		return
	game = entry.instantiate()
	game.progression.save_path = profile_path
	game.progression.legacy_path = ""
	root.add_child(game)
	game.test_ads.response_delay = 0.0
	await _frames(12)
	await _capture("00-menu")
	if not await _click("LaunchButton") or not _check(game.phase == "campaign", "title opens the campaign map"):
		quit(1)
		return
	_check(_button("LaunchStage_echo") != null and _button("LaunchStage_prism") == null and _button("LaunchStage_helion") == null,
		"new pilots have only the opening lot available")
	await _capture("01-kampania")
	if not await _click("LaunchStage_echo"):
		quit(1)
		return
	if capture_dir.is_empty():
		await _test_navigation_and_flights()
	else:
		await _capture_action()
	print("QA vertical campaign: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _test_profile() -> void:
	var prior := Pilot.new()
	prior.save_path = profile_path + "-migration"
	prior.legacy_path = ""
	var seed := prior._fresh()
	seed.erase("campaign")
	seed.coins = 620
	seed.crystals = 22
	seed.commerce.skins.append("peregrine_ion")
	seed.levels.peregrine = {"hull": 2}
	seed.equipped.peregrine = {"weapon": "pulse_coil"}
	var payload := JSON.stringify({"version": 3, "revision": 19, "data": seed})
	var slot := FileAccess.open(prior.save_path + ".1.json", FileAccess.WRITE)
	slot.store_string(JSON.stringify({"payload": payload, "sha256": payload.sha256_text()}))
	slot.close()
	prior.load_profile()
	var before: Dictionary = prior.snapshot().profile
	_check(before.coins == 620 and before.crystals == 22 and before.levels.peregrine.hull == 2
		and before.equipped.peregrine.weapon == "pulse_coil" and "peregrine_ion" in before.commerce.skins,
		"v3 migration retains currency, purchased skin, fitted equipment and upgrades")
	_check(not prior.credit_mission(_victory("prism"), "umbra", "locked").ok, "profile rejects a settlement for a locked campaign stage")
	_check(prior.credit_mission(_victory("echo"), "peryhelium", "flight").ok, "campaign clear and reward commit together")
	_check(not prior.credit_mission(_victory("echo"), "peryhelium", "flight").ok, "repeated result does not pay twice")
	prior.load_profile()
	var after: Dictionary = prior.snapshot().profile
	_check(after.campaign.echo.best == 2500 and Campaign.access(after.campaign, "prism") and after.coins > before.coins,
		"record and unlock survive a new load of the committed profile")
	_check(seed.coins == 620 and after.crystals == 26 and "peregrine_ion" in after.commerce.skins,
		"migration and settlement preserve wallet state")


func _test_ordnance() -> void:
	var craft := Flight.new()
	craft.configure("echo", {})
	root.add_child(craft)
	craft.set_physics_process(false)
	for index in Weapons.EMITTERS.size():
		craft.gear.rank = index + 1
		craft.gear._volley = 0
		craft.gear.fire(craft)
		_check(craft._shots.size() == Weapons.EMITTERS[index], "rank %d uses the declared emitter count" % [index + 1])
		for slot in range(craft._shots.size() - 1, -1, -1):
			craft._recycle_shot(slot)
	craft.gear.rank = 6
	craft.gear._volley = 2
	craft.gear.fire(craft)
	_check(craft._shots.size() == 9 and craft._shots.back().kind == Weapons.Kind.ROCKET, "rank six unlocks guided flanking fire")
	craft.gear.rank = 7
	craft.gear._volley = 3
	craft.gear.fire(craft)
	_check(craft.gear.beam_left > 0.0, "rank seven alternates a piercing beam")
	for slot in range(craft._shots.size() - 1, -1, -1):
		craft._recycle_shot(slot)
	craft.gear.rank = 1
	for id in ["core", "plasma", "rockets", "beam", "repair"]:
		craft._hp = 35.0
		var rank: int = craft.gear.rank
		craft._spawn_pickup(id, craft.player_position)
		craft._step_pickups(0.017)
		_check(craft._pickups.is_empty() and craft._power_notice == Weapons.DROPS[id].title, "collect and announce " + id)
		if id == "repair":
			_check(craft._hp > 35.0 and craft.gear.rank == rank, "repair restores HP")
		else:
			_check(craft.gear.rank == rank + 1 and (id == "core" or craft.gear.mode == id), "pickup changes the flight loadout for " + id)
	var front := _target(craft, Vector2(270, 340))
	var rear := _target(craft, Vector2(270, 240))
	var offset := _target(craft, Vector2(309, 325))
	craft.spawn_shot(Vector2(270, 500), Vector2.UP * 1_500.0, Weapons.Kind.PULSE, 17.0, 2.0, 0.0, Color.CYAN)
	craft._step_shots(0.19)
	_check(front.hp == 83.0 and rear.hp == 100.0 and craft._shots.is_empty(), "swept laser round hits only the first hull")
	craft.spawn_shot(Vector2(270, 480), Vector2.UP * 920.0, Weapons.Kind.PLASMA, 14.0, 2.0, 0.0, Color.VIOLET)
	offset.position.x = 298.0
	craft._step_shots(0.16)
	_check(front.hp < 83.0 and offset.hp < 100.0, "plasma hits a second nearby hull through splash")
	var near_hp := front.hp
	var mark := craft.beam_damage(Vector2(270, 780), 17.0)
	_check(mark.y > front.position.y and front.hp < near_hp and rear.hp == 83.0, "beam damages aligned targets and records its first contact")
	craft.spawn_shot(Vector2(118, 600), Vector2.UP * 420.0, Weapons.Kind.ROCKET, 13.0, 2.0, 0.0, Color.ORANGE)
	craft._step_shots(0.12)
	_check(craft._shots.back().velocity.x > 0.0, "rocket changes heading toward a real target")
	craft._hp = 100.0
	craft.hostile_round(craft.player_position - Vector2(0, 36), Vector2.DOWN, 480.0, 17.0)
	craft._step_shots(0.15)
	_check(craft._hp == 83.0, "hostile shot intersects the pilot between frames")
	craft.free()


func _target(craft: Flight, at: Vector2) -> Squadron.Fighter:
	var enemy := Squadron.Fighter.new()
	enemy.hp = 100.0
	enemy.position = at
	craft._enemies.append(enemy)
	return enemy


func _test_navigation_and_flights() -> void:
	if not _check(game.phase == "combat" and is_instance_valid(game.flight), "first lot opens a vertical field"):
		return
	var opening: Flight = game.flight
	await _step_to(opening, 1.06)
	_check(opening._enemies.any(func(enemy: Squadron.Fighter) -> bool: return enemy.position.y > 16.0)
		and opening._friendly > 0, "opening flight has enemies and friendly fire within 1.1 seconds")
	await _step_to(opening, 4.05)
	_check(opening._intro_core_sent and (not opening._pickups.is_empty() or opening.gear.rank > 1),
		"first fire core is in reach within four seconds even if the pilot misses")
	await _test_controls()
	await _click("PauseButton")
	var old: Flight = game.flight
	var paused_at := old._seconds
	await _steps(18)
	_check(game.phase == "pause" and is_equal_approx(paused_at, old._seconds), "pause stops the scrolling simulation")
	await _click("ResumeButton")
	await _steps(10)
	_check(game.phase == "combat" and old._seconds > paused_at, "resume continues the same flight")
	await _click("PauseButton")
	await _click("RestartButton")
	_check(game.phase == "combat" and game.flight != old and game.flight.gear.rank == 1, "restart creates a fresh flight")
	for id in Campaign.ROUTE:
		if not _check(game.phase == "combat" and game.selected_stage == id, "playing normal stage entry " + id):
			return
		await _pilot_to_result()
		if not _check(game.phase == "result" and game._result.get("won", false), "autopilot wins " + id + " using ordinary input and hit detection"):
			return
		_check(game._result.waves == Campaign.STAGES[id].waves.size(), "all waves resolved for " + id)
		_check(game._result.seconds >= 120.0 and game._result.seconds <= 240.0, "sortie meets the two to four minute pacing target: " + id)
		_check(game._result.coins > 0 and game.progression.snapshot().profile.campaign[id].cleared, "result pays and unlocks " + id)
		print("PLAYTHROUGH %s %s" % [id, str(game._result)])
		if id == "echo":
			var payout: int = game._result.coins
			var balance: int = game.progression.snapshot().profile.coins
			await _click("DoubleRewardButton")
			_check(game._result.coins == payout * 2 and game.progression.snapshot().profile.coins == balance + payout,
				"campaign result can still settle a simulated rewarded double")
		if id == "helion":
			_check(game.flight.boss_phases_fired == 7 and game._result.boss_defeated, "Asterion releases all three batteries before destruction")
		else:
			await _click("NextStageButton")
	await _click("CampaignButton")
	_check(game.phase == "campaign" and _button("LaunchStage_echo") != null, "completed stages remain replayable")
	await _click("CampaignBackButton")
	await _click("HangarButton")
	_check(game.phase == "hangar" and _button("HangarLaunchButton") != null, "shared hangar opens from the campaign")
	await _click("HangarLaunchButton")
	_check(game.phase == "campaign", "hangar launch returns to campaign selection")
	await _click("LaunchStage_echo")
	game.flight.hit_player(2_000.0)
	_check(game.phase == "revive", "campaign defeat exposes existing rewarded revive")
	await _click("ReviveAdButton")
	_check(game.phase == "combat" and game.flight._revived and game.flight._hp == game.flight._max_hp * 0.5,
		"campaign can continue on a simulated rewarded revive")
	game.flight._invulnerable = 0.0
	game.flight.hit_player(2_000.0)
	_check(game.phase == "result" and not game._result.won, "the same flight offers only one revive")
	await _click("RestartButton")
	game.flight.hit_player(2_000.0)
	await _click("DeclineReviveButton")
	_check(game.phase == "result" and not game._result.won, "declining revive reaches a real defeat result")


func _test_controls() -> void:
	var craft: Flight = game.flight
	var start := craft.player_position
	var finger := craft.to_global(start + Vector2(30, 57))
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.pressed = true
	press.position = finger
	root.push_input(press, true)
	await _steps(4)
	_check(craft.player_position.distance_to(start) < 1.0, "touch grab retains the finger offset")
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.pressed = true
	second.position = finger - Vector2(58.0, 0.0)
	root.push_input(second, true)
	_check(craft._pointer == 0, "a second finger does not take control of the ship")
	second.pressed = false
	root.push_input(second, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = finger + Vector2(106, -42)
	drag.relative = Vector2(106, -42)
	root.push_input(drag, true)
	await _steps(12)
	_check(craft.player_position.x > start.x + 85 and craft.player_position.y < start.y - 26, "drag moves without snapping the hull under the finger")
	press.pressed = false
	press.position = drag.position
	root.push_input(press, true)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = craft.to_global(craft.player_position + Vector2(15.0, 24.0))
	root.push_input(mouse, true)
	var before_mouse := craft.player_position
	var motion := InputEventMouseMotion.new()
	motion.position = mouse.position + Vector2(-58.0, 16.0)
	motion.relative = Vector2(-58.0, 16.0)
	root.push_input(motion, true)
	await _steps(8)
	_check(craft.player_position.x < before_mouse.x - 46.0, "mouse drag moves the ship through the game viewport")
	mouse.pressed = false
	mouse.position = motion.position
	root.push_input(mouse, true)
	Input.action_press("move_up")
	await _steps(62)
	Input.action_release("move_up")
	_check(craft.player_position.y >= Flight.FLIGHT_MIN.y and is_equal_approx(craft.player_position.y, Flight.FLIGHT_MIN.y), "keyboard respects the lower flight corridor")
	_check(is_equal_approx(craft.viewport_field.size.aspect(), 9.0 / 16.0), "combat field keeps its design ratio")


func _pilot_to_result() -> void:
	var craft: Flight = game.flight
	for tick in 3_300:
		if game.phase == "revive":
			_release_actions()
			await _click("ReviveAdButton")
		elif game.phase != "combat":
			break
		else:
			_pilot_input(craft)
			await _steps(6)
	_release_actions()


func _pilot_input(craft: Flight) -> void:
	var target := craft.player_position
	var pickup := not craft._pickups.is_empty()
	if pickup:
		target = craft._pickups.front().position
		target.y = clampf(target.y + 29.0, 625.0, 825.0)
	else:
		var prey := craft._nearest_target(craft.player_position)
		target.x = prey.x if prey != Vector2.ZERO else 270.0
		target.y = 802.0

	var lowest := INF
	var lane := target.x
	for candidate in range(42, 500, 20):
		var risk := absf(candidate - target.x) + absf(candidate - craft.player_position.x) * 0.24
		if craft.boss != null and craft.boss.phase == 2 and craft.boss.state in ["warning", "fire"]:
			for laser_lane: float in craft.boss.lanes:
				if absf(laser_lane - candidate) < 37.0:
					risk += 270.0
		for shot in craft._shots:
			if not shot.hostile() or shot.velocity.y < 28.0:
				continue
			var travel := (target.y - shot.position.y) / shot.velocity.y
			if travel >= -0.10 and travel < 0.78:
				var cross := shot.position.x + shot.velocity.x * travel
				risk += maxf(0.0, 49.0 - absf(cross - candidate)) * (4.1 - travel * 2.6)
		if risk < lowest:
			lane = candidate
			lowest = risk
	var direction := Vector2(lane - craft.player_position.x, target.y - craft.player_position.y)
	_release_actions()
	if absf(direction.x) >= 9.0:
		Input.action_press("move_left" if direction.x < 0.0 else "move_right", clampf(absf(direction.x) / 41.0, 0.3, 1.0))
	if absf(direction.y) >= 13.0:
		Input.action_press("move_up" if direction.y < 0.0 else "move_down", clampf(absf(direction.y) / 58.0, 0.3, 1.0))


func _capture_action() -> void:
	var craft: Flight = game.flight
	_check(is_equal_approx(craft.viewport_field.size.aspect(), 9.0 / 16.0), "portraits preserve the flight rectangle")
	await _step_to(craft, 4.6)
	await _capture("02-lot-echo")
	for tick in 280:
		if not craft._pickups.is_empty():
			break
		_pilot_input(craft)
		await _steps(5)
	_release_actions()
	await _capture("03-rdzen")
	await _leave_for_fixture("echo")
	await _click("LaunchStage_prism")
	craft = game.flight
	_peek_wave(craft, 1, "rockets")
	await _step_to(craft, 3.1)
	await _capture("04-lot-prism")
	await _leave_for_fixture("prism")
	await _click("LaunchStage_helion")
	craft = game.flight
	_peek_wave(craft, 1, "plasma")
	await _step_to(craft, 3.1)
	await _capture("05-lot-helion")
	# Speed the evidence setup to the last transition and let the live commander play its phases.
	craft._enemies.clear()
	craft._wave_index = craft._stage.waves.size() - 1
	craft._next_in = 0.02
	await _step_to(craft, 5.3)
	await _capture("06-asterion-wjazd")
	await _wait_battery(craft, 1)
	craft._damage_boss(Commander.MAX_HP, craft.boss.position)
	await _wait_phase(craft, 2)
	await _capture("07-asterion-kurtyna")
	await _wait_battery(craft, 2)
	craft._damage_boss(Commander.MAX_HP, craft.boss.position)
	await _wait_phase(craft, 3)
	if not _check(craft.boss != null, "phase three is active before the beam fixture"):
		return
	# Keep enough armor in the render fixture to show both the weapon and the spiral.
	craft.boss.hp = Commander.MAX_HP / 3.0
	craft._spawn_pickup("beam", craft.player_position)
	for tick in 30:
		if craft.gear.beam_left > 0.2:
			break
		await physics_frame
	_check(craft.gear.mode == "beam" and craft.gear.beam_left > 0.2, "collected Energy Beam fires during the live boss fight")
	await _capture("11-energy-beam")
	await _wait_battery(craft, 3)
	await _frames(11)
	await _capture("08-asterion-wir")
	if craft.boss != null:
		craft._damage_boss(Commander.MAX_HP, craft.boss.position)
	await _step_to(craft, craft._seconds + 0.21)
	await _capture("09-asterion-eksplozja")
	await _step_to(craft, craft._seconds + 2.65)
	_check(game.phase == "result" and game._result.boss_defeated, "live commander destruction reaches the actual result screen")
	await _capture("10-wynik")


func _peek_wave(craft: Flight, index: int, pickup: String) -> void:
	craft._wave_index = index - 1
	craft._next_in = 0.03
	craft._spawn_pickup(pickup, craft.player_position)


func _leave_for_fixture(id: String) -> void:
	await _click("PauseButton")
	await _click("MenuButton")
	game.progression.credit_mission(_victory(id), Campaign.STAGES[id].sector, "fixture-" + id)
	await _click("LaunchButton")


func _step_to(craft: Flight, target: float) -> void:
	for tick in 380:
		if craft._seconds >= target or game.phase != "combat":
			return
		await physics_frame


func _wait_phase(craft: Flight, phase_number: int) -> void:
	for tick in 275:
		if craft.boss == null:
			break
		if craft.boss.phase == phase_number:
			return
		await physics_frame
	_check(false, "boss enters phase %d" % phase_number)


func _wait_battery(craft: Flight, phase_number: int) -> void:
	for tick in 275:
		if craft.boss == null:
			break
		if craft.boss.phase == phase_number and craft.boss.phase_fired:
			return
		await physics_frame
	_check(false, "boss fires battery %d" % phase_number)


func _victory(id: String) -> Dictionary:
	return {"stage": id, "won": true, "seconds": 69.0, "kills": 21, "score": 2500, "reward": 21}
