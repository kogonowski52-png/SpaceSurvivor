extends "res://commerce/ad_adapter.gd"

var _bridge: Object


func _ready() -> void:
	if not Engine.has_singleton("GalaxyCommerce"):
		diagnostic.emit("", "sdk_unavailable")
		return
	_bridge = Engine.get_singleton("GalaxyCommerce")
	_bridge.connect("ad_result", _on_ad_result)
	_bridge.connect("ad_privacy", _on_privacy)
	_bridge.connect("ad_diagnostic", diagnostic.emit)
	_bridge.initAds()


func show_rewarded(request_id: String, placement: String) -> void:
	if _bridge == null:
		answered.emit(request_id, "unavailable")
		return
	_bridge.showRewarded(request_id, placement)


func uses_sample_ads() -> bool:
	return _bridge != null and _bridge.testAds()


func show_privacy() -> void:
	if _bridge != null:
		_bridge.showAdPrivacy()


func _on_ad_result(id: String, state: String) -> void:
	answered.emit(id, state)


func _on_privacy(required: bool, code: String) -> void:
	var messages := {
		"privacy_error": "Opcje prywatności są chwilowo niedostępne.",
		"privacy_saved": "Zapisano wybór prywatności.",
		"consent_error": "Nie udało się odczytać ustawień prywatności reklam.",
	}
	privacy_changed.emit(required, messages.get(code, ""))
