extends Node
## Each completion is bound to an explicitly requested placement and its immutable context.

signal status_changed(state: String, message: String)
signal reward_ready(placement: String, scope: String)

const Adapter := preload("res://commerce/ad_adapter.gd")
const MESSAGES := {
	"cancelled": "Reklama testowa zamknięta przed końcem. Nagroda nie została przyznana.",
	"network_error": "Błąd sieci w symulacji reklamy. Spróbuj ponownie.",
	"error": "Nie udało się ukończyć reklamy.",
	"unavailable": "Reklama jest niedostępna. Możesz kontynuować bez niej.",
}

var adapter: Adapter
var _request := ""
var _placement := ""
var _scope := ""


func configure(provider: Adapter) -> void:
	adapter = provider
	add_child(provider)
	provider.answered.connect(_received)


func busy() -> bool:
	return not _request.is_empty()


func request(placement: String, scope: String) -> void:
	if busy() or placement not in ["double", "revive", "bonus"] or scope.is_empty():
		return
	_placement = placement
	_scope = scope
	_request = Crypto.new().generate_random_bytes(12).hex_encode()
	get_tree().create_timer(35.0).timeout.connect(_expire.bind(_request))
	status_changed.emit("loading", "Symulacja reklamy · poczekaj na potwierdzenie…")
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
