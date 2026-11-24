extends SceneTree
## Run once under the 1.2.0 checkout, then under this checkout with the same isolated data directory.

const Profile := preload("res://data/pilot_progression.gd")
const SAVE := "user://play_debug_progress"
const FINGERPRINT := "user://play-update-fixture.sha256"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var pilot := Profile.new()
	pilot.save_path = SAVE
	pilot.legacy_path = ""
	pilot.date_override = "2026-11-24"
	pilot.load_profile()
	var version := str(ProjectSettings.get_setting("application/config/version"))
	var writing := OS.get_cmdline_user_args().has("--write-baseline")
	if writing:
		if version != "1.2.0" or not _create_baseline(pilot):
			printerr("FAIL: 1.2.0 baseline profile could not be committed")
			quit(1)
			return
		# Use 1.2.0's canonical on-disk reading, including normalized default ranks.
		pilot.load_profile()
		var file := FileAccess.open(FINGERPRINT, FileAccess.WRITE)
		file.store_string(_state_digest(pilot))
		file.close()
		print("PASS: a real 1.2.0 process committed the original Android debug save path")
	else:
		var expected := FileAccess.get_file_as_string(FINGERPRINT).strip_edges()
		var data: Dictionary = pilot.snapshot().profile
		var preserved := version == "1.3.0-rc1" and expected.length() == 64 and _state_digest(pilot) == expected
		preserved = preserved and data.campaign.size() == 2 and "season_helion" in data.commerce.entitlements
		if not preserved:
			printerr("FAIL: 1.3.0-rc1 update changed original profile fields")
			quit(1)
			return
		print("PASS: 1.3.0-rc1 reads the same balances, records, upgrades, items, receipts and Helion rights")
	quit(0)


func _create_baseline(pilot: Profile) -> bool:
	for id in ["echo", "prism"]:
		var result := {"stage": id, "won": true, "score": 58930, "seconds": 140, "kills": 220,
			"hull_ratio": 0.83, "reward": 65}
		if not pilot.credit_mission(result, "peryhelium", "update-fixture-" + id).ok:
			return false
	return pilot.apply("upgrade", "hull").ok and pilot.shop_buy("equipment_patrol").ok \
		and pilot.redeem_test_order("season_helion", "gs-test-update-fixture-helion").ok and pilot.claim_season("free_1").ok


func _state_digest(pilot: Profile) -> String:
	var data: Dictionary = pilot.snapshot().profile
	var verified := {"coins": data.coins, "materials": data.materials, "crystals": data.crystals,
		"records": data.campaign, "equipment": data.inventory, "levels": data.levels,
		"currency_receipts": data.commerce.receipts, "entitlements": data.commerce.entitlements,
		"season_claims": data.commerce.season, "wins": data.wins}
	return JSON.stringify(verified).sha256_text()
