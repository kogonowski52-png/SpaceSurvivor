extends SceneTree

const Adapter := preload("res://commerce/billing_adapter.gd")
const Billing := preload("res://commerce/billing_service.gd")
const Profile := preload("res://data/pilot_progression.gd")

class VerifiedFixture extends Adapter:
	var proof: Dictionary = {}
	var wallet_result: Dictionary = {}
	var spend_result: Dictionary = {}
	var batch: Array = []
	var confirmations: Array[String] = []
	var restore_state := "restored"
	var checkout := true
	var checkouts := 0
	var spends := 0

	func online_ready() -> bool:
		return true

	func checkout_available() -> bool:
		return checkout

	func begin_purchase(id: String, _sku: String) -> void:
		checkouts += 1
		answered.emit(id, "success", batch)

	func restore(id: String, _complete: bool) -> void:
		answered.emit(id, restore_state, batch)

	func authorize(_receipt: Dictionary) -> Dictionary:
		return proof

	func account_wallet() -> Dictionary:
		return wallet_result

	func spend_account(_offer: String, request_id: String) -> Dictionary:
		assert(request_id.length() == 32 and request_id.is_valid_hex_number())
		spends += 1
		return spend_result

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
	var unmodified := "user://play-wallet-qa-%d" % Time.get_ticks_usec()
	_profile.save_path = unmodified
	_profile.legacy_path = ""
	_profile.load_profile()
	_provider = VerifiedFixture.new()
	_billing = Billing.new()
	root.add_child(_billing)
	_billing.configure(_profile, _provider)
	_billing.status_changed.connect(func(state: String, _message: String) -> void: _state = state)

	_provider.checkout = false
	_billing.buy("crystals_100")
	_check(_state == "payments_disabled" and _provider.checkouts == 0, "closed checkout never opens the platform UI")
	_provider.checkout = true
	var sku := "gs_crystals_100"
	_provider.batch = [{"sku": sku, "token": "play-token", "stage": "pending"}]
	_billing.buy("crystals_100")
	_check(_state == "pending" and not _billing.account().known, "pending Google Play order does not credit a wallet")
	_provider.batch[0].stage = "purchased"
	_provider.proof = {"ok": false, "error": "server_unavailable"}
	_billing.buy("crystals_100")
	_check(_state == "error" and not _billing.account().known, "checkout requires server verification")

	_provider.proof = _wallet(100, 1)
	_provider.proof.merge({"sku": sku, "credited": true})
	_profile.save_path = unmodified + "/missing/profile"
	_billing.buy("crystals_100")
	_check(_state == "success" and _billing.account().crystals == 100 and _profile.snapshot().profile.crystals == 0,
		"paid Crystals remain on the account even if the local save cannot be written")
	_profile.save_path = unmodified

	_provider.batch = []
	_provider.restore_state = "network_error"
	_provider.wallet_result = _wallet(100, 1)
	_billing.restore()
	_check(_state == "restored" and _billing.account().crystals == 100,
		"account refresh works during a Google Play outage independently of checkout")
	_provider.restore_state = "restored"

	_provider.spend_result = _wallet(20, 2, ["equipment_signal"])
	_provider.spend_result.spent = true
	_billing.spend_paid("equipment_signal")
	_check(_state == "success" and _provider.spends == 1 and _billing.account().crystals == 20,
		"paid spending consumes the server response")
	_check(_profile.apply("equip", "dark_reactor").ok, "an account item can be selected and equipped")
	_billing.spend_paid("equipment_signal")
	_check(_provider.spends == 1, "known inventory avoids another spend request")

	var fresh := Profile.new()
	fresh.save_path = unmodified
	fresh.legacy_path = ""
	fresh.load_profile()
	var inventory: Array = fresh.snapshot().profile.inventory
	_check("dark_reactor" not in inventory and fresh.snapshot().profile.crystals == 0,
		"account entitlements and paid balances are never persisted as offline credits")
	fresh.set_account_offers(["equipment_signal"])
	_check(fresh.snapshot().profile.equipped.peregrine.reactor == "dark_reactor",
		"relinking the account restores the local equipment selection")

	_provider.wallet_result = {"ok": false, "error": "server_unavailable"}
	_billing.refresh_balance()
	_check(not _billing.account().online and _billing.account().crystals == 20, "offline mode labels the last known account balance")
	_billing.spend_paid("skin_ion")
	_check(_provider.spends == 1 and _state == "account_offline", "offline mode never spends paid currency")

	var bonus := "3".repeat(64)
	_provider.wallet_result = _wallet(140, 3, ["equipment_signal", "starter"])
	_provider.wallet_result.credits_deliveries = [bonus]
	_billing.refresh_balance()
	_check(_profile.shop_skin("peregrine_ion").ok and _provider.confirmations == [bonus] and _profile.snapshot().profile.coins == 1020,
		"paid starter keeps its skin and grants its separate local Credits bonus once")
	_billing.refresh_balance()
	_check(_profile.snapshot().profile.coins == 1020, "replayed Credits bonus cannot mint again")
	_provider.wallet_result = _wallet(20, 4, ["equipment_signal"])
	_billing.refresh_balance()
	_check(_profile.sortie().skin_id.is_empty() and "starter" not in _profile.snapshot().profile.commerce.entitlements,
		"refund removes account-issued rights and unequips their use without corrupting local progress")

	print("QA Play wallet: %d failure(s)" % _failures)
	quit(0 if _failures == 0 else 1)


func _wallet(crystals: int, revision: int, offers: Array = []) -> Dictionary:
	return {"ok": true, "wallet": {"crystals": crystals, "debt": 0, "revision": revision, "offers": offers}, "credits_deliveries": []}


func _check(ok: bool, detail: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + detail)
	if not ok:
		_failures += 1
