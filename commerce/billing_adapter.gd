extends Node
## Platform boundary. Report all responses on the main thread with the original request ID.

signal answered(request_id: String, state: String, receipts: Array)
signal catalog_changed
signal inventory_changed


func begin_purchase(request_id: String, _sku: String) -> void:
	answered.emit(request_id, "unavailable", [])


func restore(request_id: String, _complete_pending: bool) -> void:
	answered.emit(request_id, "unavailable", [])


func has_pending(_sku: String) -> bool:
	return false


func verify_receipt(_receipt: Dictionary) -> bool:
	# A live adapter must use server verification. Unknown adapters grant nothing.
	return false


func is_test() -> bool:
	return false


func catalog() -> Dictionary:
	return {}


func refresh_catalog() -> void:
	pass


func online_ready() -> bool:
	return false


func checkout_available() -> bool:
	return is_test()


func preview_available() -> bool:
	return is_test()


func can_connect_account() -> bool:
	return false


func connect_account(_token: String) -> Dictionary:
	return {"ok": false, "error": "session_required"}


func authorize(_receipt: Dictionary) -> Dictionary:
	return {"ok": false, "error": "server_unavailable"}


func account_wallet() -> Dictionary:
	return {"ok": false, "error": "server_unavailable"}


func spend_account(_offer: String, _request_id: String) -> Dictionary:
	return {"ok": false, "error": "server_unavailable"}


func mark_received(_delivery: String) -> Dictionary:
	return {"ok": false, "error": "server_unavailable"}
