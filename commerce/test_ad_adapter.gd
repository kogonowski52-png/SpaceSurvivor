extends "res://commerce/ad_adapter.gd"
## Time and outcomes are simulated locally. There is no ad SDK or ad impression.

var scenario := "rewarded"
var response_delay := 0.55


func is_test() -> bool:
	return true


func show_rewarded(request_id: String, _placement: String) -> void:
	_deliver.call_deferred(request_id, scenario)


func _deliver(id: String, outcome: String) -> void:
	if response_delay > 0:
		await get_tree().create_timer(response_delay).timeout
	answered.emit(id, "rewarded" if outcome == "repeat" else outcome)
	if outcome == "repeat":
		answered.emit(id, "rewarded")
