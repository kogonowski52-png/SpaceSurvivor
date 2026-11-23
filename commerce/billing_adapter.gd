extends Node
## Platform boundary. Report all responses on the main thread with the original request ID.

signal answered(request_id: String, state: String, receipts: Array)


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
