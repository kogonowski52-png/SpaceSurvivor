extends "res://tests/chapter_one.gd"
## Store screenshots come from a start-to-finish run with ordinary firing and pilot input.

const BOSS_IMAGES := {
	"helion": [2, "03-asterion"],
	"guardian": [3, "04-vesperon"],
	"abyss": [4, "05-nadir"],
}
const IMAGES := [
	"01-combat", "02-weapons", "03-asterion", "04-vesperon", "05-nadir",
	"06-hangar", "07-campaign", "08-upgrades", "09-equipment",
]

var _captured := {}


func _run() -> void:
	if capture_dir.is_empty():
		printerr("A native capture directory is required.")
		quit(1)
		return
	await _load_chapter("-store-listing")
	await _click("LaunchButton")
	await _click("LaunchStage_echo")
	for stage: String in Campaign.ROUTE:
		if not _check(game.phase == "combat" and game.selected_stage == stage, "listing run starts " + stage):
			break
		var craft: Flight = game.flight
		craft.set_physics_process(false)
		craft.revive_offer_enabled = false
		await _fly_for_listing(craft)
		var cleared: bool = game.phase == "result" and game._result.get("won", false)
		print("LISTING route=%s won=%s seconds=%.2f rank=%d phases=%d" %
			[stage, cleared, craft._seconds, craft.gear.rank, craft.boss_phases_fired])
		if not _check(cleared, "listing run completes " + stage):
			break
		if stage == "guardian":
			_equip_for_frontier()
		if not Campaign.next(stage).is_empty():
			await _click("NextStageButton")
	if failures == 0:
		await _capture_hangar_and_route()
	for id: String in IMAGES:
		_check(_captured.has(id), "listing evidence includes " + id)
	print("QA Play listing capture: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)


func _fly_for_listing(craft: Flight) -> void:
	var limit := ceili((craft._duration + 4.5) * 10.0)
	for tick in limit:
		if craft._ended or craft._revive_pending:
			break
		_chapter_input(craft)
		for step in 6:
			craft._physics_process(1.0 / 60.0)
		var frame := _frame_to_capture(craft)
		if not frame.is_empty() and not _captured.has(frame):
			craft.publish_telemetry()
			await _keep_frame(frame)
		elif tick % 180 == 0:
			await process_frame
	_release_actions()


func _frame_to_capture(craft: Flight) -> String:
	if craft._ended or craft._hp <= 0.0:
		return ""
	if craft._stage_id == "strait" and craft._seconds > 8.0 and craft._enemies.size() >= 6 and craft.active_shot_count() >= 20:
		return "01-combat"
	if craft._stage_id in ["prism", "tempest", "starbreak"] and craft.gear.rank >= 5 and craft.gear.mode != "laser" \
			and craft._friendly >= 9 and craft._enemies.size() >= 2:
		return "02-weapons"
	if craft.boss != null and BOSS_IMAGES.has(craft._stage_id):
		var planned: Array = BOSS_IMAGES[craft._stage_id]
		if craft.boss.phase == planned[0] and craft.boss.state in ["warning", "fire"]:
			return planned[1]
	return ""


func _capture_hangar_and_route() -> void:
	await _click("CampaignButton")
	await _click("SectorJump_00")
	await _frames(18)
	await _keep_frame("07-campaign")
	await _click("CampaignBackButton")
	await _click("HangarButton")
	await _click("ShipButton_aurora")
	await _frames(15)
	await _keep_frame("06-hangar")
	await _click("WorkshopButton")
	await _click("UpgradeHullButton")
	await _keep_frame("08-upgrades")
	await _click("HangarTabInventory")
	await _keep_frame("09-equipment")


func _equip_for_frontier() -> void:
	_check(game.progression.apply("select_ship", "aegis").ok, "frontier pilot selects a hull unlocked during the run")
	for track in ["hull", "output", "hull", "drive", "hull"]:
		_check(game.progression.apply("upgrade", track).ok, "frontier upgrade uses earned Credits and materials")
	for item in ["pulse_coil", "titanium_plate", "trim_nozzle", "flux_cell", "escort_bay"]:
		_check(game.progression.apply("equip", item).ok, "frontier pilot equips an available module")


func _keep_frame(label: String) -> void:
	if await _capture(label):
		_captured[label] = true
