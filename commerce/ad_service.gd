extends Node
## Each completion is bound to an explicitly requested placement and its immutable context.

signal status_changed(state: String, message: String)
signal reward_ready(placement: String, scope: String)
signal privacy_changed(required: bool, message: String)

const Adapter := preload("res://commerce/ad_adapter.gd")
const MESSAGES := {
	"cancelled": "Reklama zamknięta przed końcem. Nagroda nie została przyznana.",
	"network_error": "Błąd połączenia z reklamą. Spróbuj ponownie.",
	"error": "Nie udało się ukończyć reklamy.",
	"unavailable": "Reklama jest niedostępna. Możesz kontynuować bez niej.",
	"consent": "Reklamy są niedostępne przy bieżących ustawieniach prywatności. Możesz kontynuować grę.",
	"busy": "Zakończ poprzednią reklamę.",
	"timeout": "Nie udało się uzyskać odpowiedzi od reklamy.",
}

var adapter: Adapter
var _request := ""
var _placement := ""
var _scope := ""
var privacy_required := false


func configure(provider: Adapter) -> void:
	adapter = provider
	provider.answered.connect(_received)
	provider.privacy_changed.connect(_on_privacy)
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


func _on_privacy(required: bool, message: String) -> void:
	privacy_required = required
	privacy_changed.emit(required, message)


func request(placement: String, scope: String) -> void:
	if busy() or placement not in ["double", "revive", "bonus"] or scope.is_empty():
		return
	_placement = placement
	_scope = scope
	_request = Crypto.new().generate_random_bytes(12).hex_encode()
	var timeout := 35.0 if adapter.is_test() else 180.0
	get_tree().create_timer(timeout).timeout.connect(_expire.bind(_request))
	status_changed.emit("loading", "Symulacja reklamy…" if adapter.is_test() else "Ładowanie reklamy…")
	adapter.show_rewarded(_request, placement)


func _expire(id: String) -> void:
	if id == _request:
		_received(id, "network_error")


func _received(id: String, state: String) -> void:
	if not busy() or id != _request:
		return
	_request = ""
	var placement := _placement
	var scope := _scope
	_placement = ""
	_scope = ""
	if state == "rewarded":
		reward_ready.emit(placement, scope)
	else:
		status_changed.emit(state, MESSAGES.get(state, MESSAGES.error))
