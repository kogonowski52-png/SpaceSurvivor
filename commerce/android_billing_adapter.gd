extends "res://commerce/billing_adapter.gd"

const Offers := preload("res://data/store/commerce_catalog.gd")
const Verifier := preload("res://commerce/play_verifier.gd")

var _bridge: Object
var _products: Dictionary = {}
var _pending: Dictionary = {}
var _verifier := Verifier.new()


func _ready() -> void:
	add_child(_verifier)
	if not Engine.has_singleton("GalaxyCommerce"):
		return
	_bridge = Engine.get_singleton("GalaxyCommerce")
	_verifier.setup(_bridge.billingEndpoint(), _bridge.playMode())
	_bridge.connect("billing_result", _on_billing_result)
	_bridge.connect("billing_catalog", _on_catalog)
	_bridge.connect("billing_inventory_changed", _on_inventory)
	var skus: Array[String] = []
	for offer: Dictionary in Offers.OFFERS.values():
		if offer.has("sku") and not offer.get("preview", false):
			skus.append(offer.sku)
	_bridge.initBilling(JSON.stringify(skus))


func catalog() -> Dictionary:
	return _products


func refresh_catalog() -> void:
	if _bridge != null:
		_bridge.queryProducts()


func online_ready() -> bool:
	return _bridge != null and _verifier.ready_to_verify()


func checkout_available() -> bool:
	return online_ready() and _bridge.licenseCheckoutEnabled()


func can_connect_account() -> bool:
	return _bridge != null and _verifier.endpoint_ready()


func connect_account(token: String) -> Dictionary:
	return await _verifier.connect_account(token)


func has_pending(sku: String) -> bool:
	return _pending.has(sku)


func begin_purchase(request_id: String, sku: String) -> void:
	if not checkout_available():
		answered.emit(request_id, "payments_disabled", [])
		return
	if sku not in _products:
		refresh_catalog()
		answered.emit(request_id, "unavailable", [])
		return
	var session := await _verifier.send("session")
	var account: Variant = session.get("obfuscated_account_id")
	if not session.ok or not account is String or account.length() != 64 or not account.is_valid_hex_number():
		answered.emit(request_id, "network_error" if session.get("error") == "server_unavailable" else "verification_unavailable", [])
		return
	if session.get("license_checkout") != true:
		answered.emit(request_id, "payments_disabled", [])
		return
	_bridge.startPurchase(request_id, sku, account)


func restore(request_id: String, _complete_pending: bool) -> void:
	if _bridge == null:
		answered.emit(request_id, "unavailable", [])
		return
	_bridge.queryPurchases(request_id)


func authorize(receipt: Dictionary) -> Dictionary:
	var offer := Offers.from_sku(str(receipt.get("sku", "")))
	if offer.is_empty() or Offers.OFFERS[offer].get("preview", false):
		return {"ok": false, "error": "payments_disabled"}
	return await _verifier.send("verify", {"sku": receipt.sku, "token": receipt.token})


func account_wallet() -> Dictionary:
	return await _verifier.send("wallet")


func spend_account(offer: String, request_id: String) -> Dictionary:
	return await _verifier.send("spend", {"offer": offer, "request_id": request_id})


func mark_received(delivery: String) -> Dictionary:
	return await _verifier.send("received", {"delivery_id": delivery})


func _on_billing_result(id: String, state: String, payload: String) -> void:
	var decoded: Variant = JSON.parse_string(payload)
	if not decoded is Array:
		answered.emit(id, "error", [])
		return
	if state == "restored":
		_pending.clear()
	for item: Variant in decoded:
		if not item is Dictionary or not item.get("sku") is String:
			continue
		if item.get("stage") == "pending":
			_pending[item.sku] = true
		elif item.get("stage") == "purchased":
			_pending.erase(item.sku)
	answered.emit(id, state, decoded)


func _on_catalog(payload: String) -> void:
	var products: Variant = JSON.parse_string(payload)
	if not products is Array:
		return
	_products.clear()
	for item: Variant in products:
		if item is Dictionary and item.get("sku") is String and item.get("price") is String and not item.price.is_empty():
			_products[item.sku] = item
	catalog_changed.emit()


func _on_inventory() -> void:
	inventory_changed.emit()
