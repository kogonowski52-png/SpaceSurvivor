extends Node
## Each completion is bound to an explicitly requested placement and its immutable context.

signal status_changed(state: String, message: String)
signal reward_ready(placement: String, scope: String)
signal privacy_changed(required: bool, message: String)
signal activity(event: String, fields: Dictionary)
signal diagnostic_changed(state: String, placement: String)
signal fullscreen_changed(showing: bool)

const Adapter := preload("res://commerce/ad_adapter.gd")
const Offers := preload("res://data/store/commerce_catalog.gd")
const MESSAGES := {
	"cancelled": "Reklama zamknięta przed końcem. Nagroda nie została przyznana.",
	"network_error": "Błąd połączenia z reklamą. Spróbuj ponownie.",
	"error": "Nie udało się ukończyć reklamy.",
	"unavailable": "Reklama jest niedostępna. Możesz kontynuować bez niej.",
	"consent": "Reklamy są niedostępne przy bieżących ustawieniach prywatności. Możesz kontynuować grę.",
	"busy": "Zakończ poprzednią reklamę.",
	"timeout": "Nie udało się uzyskać odpowiedzi od reklamy.",
	"background": "Przerwano ładowanie po przejściu do tła. Możesz kontynuować grę.",
}

var adapter: Adapter
var _request := ""
var _placement := ""
var _scope := ""
var privacy_required := false
var _fullscreen := false


func configure(provider: Adapter) -> void:
	adapter = provider
	provider.answered.connect(_received)
	provider.privacy_changed.connect(_on_privacy)
	provider.diagnostic.connect(_on_diagnostic)
	add_child(provider)


func busy() -> bool:
	return not _request.is_empty()


func show_privacy() -> void:
	if not busy() and privacy_required:
		adapter.show_privacy()


func label() -> String:
	if adapter.is_test():
		return "REKLAMA TESTOWA"
	return "TEST ADMOB" if adapter.uses_sample_ads() else "REKLAMA"


func source() -> String:
	if adapter.is_test():
		return "simulator"
	return "admob_sample" if adapter.uses_sample_ads() else "admob"


func _on_privacy(required: bool, message: String) -> void:
	privacy_required = required
	privacy_changed.emit(required, message)


func _on_diagnostic(id: String, state: String) -> void:
	if id.is_empty():
		if state.begins_with("sdk_") or state.begins_with("consent_") or state.begins_with("privacy_"):
			diagnostic_changed.emit(state, "")
	elif id == _request:
		diagnostic_changed.emit(state, _placement)
		if state == "showing":
			_set_fullscreen(true)
		elif state == "closed":
			_set_fullscreen(false)


func _set_fullscreen(value: bool) -> void:
	if value != _fullscreen:
		_fullscreen = value
		fullscreen_changed.emit(value)


func request(placement: String, scope: String) -> void:
	if busy() or not Offers.ADS.has(placement) or scope.is_empty():
		return
	_placement = placement
	_scope = scope
	_request = Crypto.new().generate_random_bytes(12).hex_encode()
	var timeout := 35.0 if adapter.is_test() else 180.0
	get_tree().create_timer(timeout).timeout.connect(_expire.bind(_request))
	activity.emit("rewarded_request", {"placement": placement, "source": source()})
	diagnostic_changed.emit("requested", placement)
	status_changed.emit("loading", "Symulacja reklamy…" if adapter.is_test() else "Ładowanie reklamy…")
	adapter.show_rewarded(_request, placement)


func _expire(id: String) -> void:
	if id == _request:
		_received(id, "timeout")


func _received(id: String, state: String) -> void:
	if not busy() or id != _request:
		return
	_request = ""
	var placement := _placement
	var scope := _scope
	_placement = ""
	_scope = ""
	_set_fullscreen(false)
	diagnostic_changed.emit(state, placement)
	var fields := {"placement": placement, "source": source()}
	var availability := "available" if state in ["rewarded", "cancelled"] else state
	activity.emit("rewarded_availability", fields.merged({"state": availability}))
	if state == "rewarded":
		activity.emit("rewarded_complete", fields)
		reward_ready.emit(placement, scope)
	else:
		status_changed.emit(state, MESSAGES.get(state, MESSAGES.error))
