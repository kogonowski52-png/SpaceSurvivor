extends SceneTree

const Adapter := preload("res://commerce/billing_adapter.gd")
const Billing := preload("res://commerce/billing_service.gd")
const Profile := preload("res://data/pilot_progression.gd")

class VerifiedFixture extends Adapter:
	var proof: Dictionary = {}
	var batch: Array = []
	var deliveries: Array = []
	var confirmations: Array[String] = []

	func online_ready() -> bool:
		return true

	func begin_purchase(id: String, _sku: String) -> void:
		answered.emit(id, "success", batch)

	func restore(id: String, _complete: bool) -> void:
		answered.emit(id, "restored", batch)

	func authorize(_receipt: Dictionary) -> Dictionary:
		return proof

	func outstanding() -> Dictionary:
		return {"ok": true, "orders": deliveries}

	func mark_received(delivery: String) -> Dictionary:
		confirmations.append(delivery)
		return {"ok": true}

var _failures := 0
var _state := ""
var _profile: Profile
var _provider: VerifiedFixture
var _billing: Billing


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_profile = Profile.new()
	var unmodified := "user://play-delivery-qa-%d" % Time.get_ticks_usec()
	_profile.save_path = unmodified
	_profile.legacy_path = unmodified + "-unused"
	_profile.load_profile()
	_provider = VerifiedFixture.new()
	_billing = Billing.new()
	root.add_child(_billing)
	_billing.configure(_profile, _provider)
	_billing.status_changed.connect(func(state: String, _message: String) -> void: _state = state)

	var sku := "gs_crystals_100"
	var delivery := "1".repeat(64)
	_provider.batch = [{"sku": sku, "token": "play-token", "stage": "pending"}]
	_billing.buy("crystals_100")
	_check(_state == "pending" and _crystals() == 0, "pending Google Play order grants nothing")
	_provider.batch[0].stage = "purchased"
	_provider.proof = {"ok": false, "error": "server_unavailable"}
	_billing.buy("crystals_100")
	_check(_state == "error" and _crystals() == 0 and _provider.confirmations.is_empty(), "no server verification means no grant")

	_provider.proof = {"ok": true, "sku": sku, "delivery_id": delivery, "mode": "deliver"}
	_profile.save_path = unmodified + "/not-a-directory/profile"
	_billing.buy("crystals_100")
	_check(_state == "error" and _crystals() == 0 and _provider.confirmations.is_empty(), "a failed save never confirms delivery")
	_profile.save_path = unmodified
	_provider.batch = []
	_provider.deliveries = [_provider.proof]
	_billing.restore()
	_check(_state == "restored" and _crystals() == 100 and delivery in _provider.confirmations, "restore recovers a server delivery without a Play callback")
	_profile.load_profile()
	_billing.restore()
	_check(_crystals() == 100, "replayed server delivery stays idempotent after restart")

	_provider.deliveries = []
	_provider.batch = [{"sku": "gs_starter_v1", "token": "permanent-token", "stage": "purchased"}]
	_provider.proof = {"ok": true, "sku": "gs_starter_v1", "delivery_id": "2".repeat(64), "mode": "restore"}
	_billing.restore()
	var current: Dictionary = _profile.snapshot().profile
	_check("starter" in current.commerce.entitlements and "peregrine_ion" in current.commerce.skins
		and current.crystals == 100 and current.coins == 420, "restored starter gives persistent rights once without replaying currency")
	_check(_provider.confirmations.back() == delivery, "restore of an entitlement does not confirm a new currency delivery")

	print("QA Play delivery: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)


func _crystals() -> int:
	return _profile.snapshot().profile.crystals


func _check(ok: bool, detail: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + detail)
	if not ok:
		_failures += 1
