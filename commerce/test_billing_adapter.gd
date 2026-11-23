extends "res://commerce/billing_adapter.gd"
## Durable simulated provider, separate from the game wallet. It never contacts Play.

var ledger_path := "user://test_play_orders.cfg"
var scenario := "success"
var response_delay := 0.36
var _orders: Dictionary = {}
var _usable := true


func _ready() -> void:
	var storage := ConfigFile.new()
	var status := storage.load(ledger_path)
	if status == OK:
		var rows: Variant = storage.get_value("test_provider", "orders", {})
		if rows is Dictionary:
			_orders = rows
		else:
			_usable = false
	elif status != ERR_FILE_NOT_FOUND:
		_usable = false


func is_test() -> bool:
	return true


func begin_purchase(request_id: String, sku: String) -> void:
	_deliver_purchase.call_deferred(request_id, sku, scenario)


func _deliver_purchase(request_id: String, sku: String, outcome: String) -> void:
	if response_delay > 0:
		await get_tree().create_timer(response_delay).timeout
	if not _usable:
		answered.emit(request_id, "storage_error", [])
		return
	if outcome in ["cancelled", "network_error", "error", "unavailable"]:
		answered.emit(request_id, outcome, [])
		return
	if outcome not in ["success", "pending", "repeat"]:
		answered.emit(request_id, "error", [])
		return
	if has_pending(sku):
		answered.emit(request_id, "pending", [])
		return
	var token := "gs-test-" + Crypto.new().generate_random_bytes(16).hex_encode()
	var receipt := {"sku": sku, "token": token, "stage": "pending" if outcome == "pending" else "purchased"}
	var draft := _orders.duplicate(true)
	draft[token] = receipt
	if not _save_provider(draft):
		answered.emit(request_id, "storage_error", [])
		return
	var state := "pending" if outcome == "pending" else "success"
	answered.emit(request_id, state, [receipt.duplicate()])
	if outcome == "repeat":
		answered.emit(request_id, state, [receipt.duplicate()])


func restore(request_id: String, complete_pending: bool) -> void:
	_deliver_restore.call_deferred(request_id, complete_pending, scenario)


func _deliver_restore(request_id: String, complete_pending: bool, outcome: String) -> void:
	if response_delay > 0:
		await get_tree().create_timer(response_delay).timeout
	if not _usable:
		answered.emit(request_id, "storage_error", [])
		return
	if outcome in ["network_error", "unavailable", "error"]:
		answered.emit(request_id, outcome, [])
		return
	if complete_pending:
		var draft := _orders.duplicate(true)
		for row: Variant in draft.values():
			if row is Dictionary and row.get("stage") == "pending":
				row.stage = "purchased"
		if not _save_provider(draft):
			answered.emit(request_id, "storage_error", [])
			return
	answered.emit(request_id, "restored", _orders.values().duplicate(true))


func verify_receipt(receipt: Dictionary) -> bool:
	var token: Variant = receipt.get("token")
	if not token is String or not token.begins_with("gs-test-"):
		return false
	var original: Variant = _orders.get(token)
	return original is Dictionary and original == receipt and receipt.get("stage") == "purchased"


func has_pending(sku: String) -> bool:
	for row: Variant in _orders.values():
		if row is Dictionary and row.get("sku") == sku and row.get("stage") == "pending":
			return true
	return false


func _save_provider(draft: Dictionary) -> bool:
	var store := ConfigFile.new()
	store.set_value("test_provider", "orders", draft)
	var partial := ledger_path + ".tmp"
	if store.save(partial) != OK or DirAccess.rename_absolute(partial, ledger_path) != OK:
		return false
	_orders = draft
	return true
