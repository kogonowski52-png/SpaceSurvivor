extends Node
## The SDK bridge may report rewarded only after the platform's earned-reward callback.

signal answered(request_id: String, state: String)
signal privacy_changed(required: bool, message: String)


func show_rewarded(request_id: String, _placement: String) -> void:
	answered.emit(request_id, "unavailable")


func is_test() -> bool:
	return false


func uses_sample_ads() -> bool:
	return false


func show_privacy() -> void:
	pass
