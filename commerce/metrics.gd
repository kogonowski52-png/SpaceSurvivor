extends RefCounted
## Session-local telemetry. A future provider can consume sanitized events after privacy review.

signal recorded(event: Dictionary)

const Campaign := preload("res://vertical/campaign.gd")
const Catalog := preload("res://data/progression_catalog.gd")
const Offers := preload("res://data/store/commerce_catalog.gd")
const CAPACITY := 256
const FIELDS := {
	"level_start": ["level", "ship"], "level_complete": ["level", "stars", "seconds", "saved"],
	"level_fail": ["level", "seconds", "saved"], "store_open": ["source"],
	"offer_view": ["offer"], "purchase_start": ["offer", "source"],
	"purchase_result": ["offer", "source", "state"],
	"rewarded_request": ["placement", "source"], "rewarded_availability": ["placement", "source", "state"],
	"rewarded_complete": ["placement", "source"], "reward_granted": ["placement", "source", "coins", "materials", "crystals", "crates"],
	"ship_upgrade": ["ship", "track", "rank"],
}
const CODES := {
	"source": ["menu", "hangar", "local", "account", "simulator", "play_license", "admob_sample", "admob"],
	"state": ["success", "error", "cancelled", "pending", "duplicate", "restored", "network_error", "unavailable",
		"storage_error", "timeout", "owned_on_play", "available", "consent", "busy", "funds", "owned", "save",
		"payments_disabled", "account_offline", "insufficient_funds"],
	"track": ["hull", "drive", "output"],
}
const COUNTS := {"stars": 3, "seconds": 1800, "rank": 5, "coins": 99999,
	"materials": 99999, "crystals": 99999, "crates": 99999}

var _started := Time.get_ticks_msec()
var _events: Array[Dictionary] = []


func record(name: String, fields: Dictionary) -> void:
	if not FIELDS.has(name):
		return
	var event := {"event": name, "ms": Time.get_ticks_msec() - _started}
	for field: String in FIELDS[name]:
		var value: Variant = fields.get(field)
		if value is int and COUNTS.has(field):
			event[field] = clampi(value, 0, COUNTS[field])
		elif value is bool and field == "saved":
			event[field] = value
		elif value is String and _valid_code(field, value):
			event[field] = value
	if _events.size() == CAPACITY:
		_events.pop_front()
	_events.append(event)
	recorded.emit(event.duplicate())


func snapshot() -> Array[Dictionary]:
	return _events.duplicate(true)


func _valid_code(field: String, value: String) -> bool:
	match field:
		"level": return Campaign.STAGES.has(value) or Catalog.SECTORS.has(value)
		"ship": return Catalog.SHIPS.has(value)
		"placement": return Offers.ADS.has(value)
		"offer": return Offers.OFFERS.has(value) or value == "restore"
		_: return value in CODES.get(field, [])
