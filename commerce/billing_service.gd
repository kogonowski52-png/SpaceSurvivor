extends Node
## Orchestrates requests. An adapter proves each receipt before the profile may grant it.

signal status_changed(state: String, message: String)

const Offers := preload("res://data/store/commerce_catalog.gd")
const Profile := preload("res://data/pilot_progression.gd")
const Adapter := preload("res://commerce/billing_adapter.gd")
const MESSAGES := {
	"cancelled": "Zakup anulowany. Saldo pozostaje bez zmian.",
	"network_error": "Błąd sieci w symulacji. Spróbuj ponownie lub przywróć zakupy.",
	"error": "Zakup nie został zatwierdzony.",
	"unavailable": "Google Play Billing jest niedostępny w tej konfiguracji.",
	"storage_error": "Nie udało się zapisać zamówienia testowego.",
	"pending": "Oczekujące zamówienie testowe. Nagroda pojawi się po zatwierdzeniu.",
}

var adapter: Adapter
var _profile: Profile
var _request := ""
var _expected_sku := ""
var _busy := false


func configure(profile: Profile, provider: Adapter) -> void:
	_profile = profile
	adapter = provider
	add_child(provider)
	provider.answered.connect(_received)


func busy() -> bool:
	return _busy


func pending(id: String) -> bool:
	var offer: Dictionary = Offers.OFFERS.get(id, {})
	return adapter.has_pending(offer.get("sku", ""))


func buy(id: String) -> void:
	if _busy:
		return
	var offer: Dictionary = Offers.OFFERS.get(id, {})
	if offer.get("kind") != "play":
		status_changed.emit("error", "Ten produkt nie należy do katalogu Google Play.")
		return
	if Offers.owns_offer(_profile.snapshot().profile, id):
		status_changed.emit("duplicate", "Produkt jest już na koncie.")
		return
	if pending(id):
		status_changed.emit("pending", MESSAGES.pending)
		return
	_start(offer.sku, "Otwieranie zakupu testowego…")
	adapter.begin_purchase(_request, _expected_sku)


func restore(complete_pending: bool = false) -> void:
	if _busy:
		return
	_start("", "Sprawdzanie zamówień testowych…")
	adapter.restore(_request, complete_pending)


func _start(sku: String, message: String) -> void:
	_expected_sku = sku
	_request = Crypto.new().generate_random_bytes(12).hex_encode()
	_busy = true
	get_tree().create_timer(35.0).timeout.connect(_expire.bind(_request))
	status_changed.emit("loading", message)


func _expire(id: String) -> void:
	if id == _request:
		_received(id, "network_error", [])


func _received(id: String, state: String, receipts: Array) -> void:
	if not _busy or id != _request:
		return
	var expected := _expected_sku
	_busy = false
	_request = ""
	if state not in ["success", "restored"]:
		status_changed.emit(state, MESSAGES.get(state, MESSAGES.error))
		return
	if state == "success" and receipts.is_empty():
		status_changed.emit("error", "Brakuje potwierdzenia zakupu.")
		return
	var applied := 0
	var awaiting := 0
	var duplicate := 0
	var rejected := 0
	var detail := ""
	for value: Variant in receipts:
		if not value is Dictionary or (not expected.is_empty() and value.get("sku") != expected):
			rejected += 1
			continue
		if value.get("stage") == "pending":
			awaiting += 1
			continue
		var offer := Offers.from_sku(str(value.get("sku", "")))
		if offer.is_empty() or not adapter.is_test() or not adapter.verify_receipt(value):
			rejected += 1
			continue
		var outcome := _profile.redeem_test_order(offer, value.token)
		detail = outcome.message
		if not outcome.ok:
			rejected += 1
		elif outcome.state == "duplicate":
			duplicate += 1
		else:
			applied += 1
	if state == "restored":
		var code := "error" if rejected > 0 else "restored"
		status_changed.emit(code, "Rozliczono %d nowych · %d wcześniej · %d oczekuje · %d odrzucono." %
			[applied, duplicate, awaiting, rejected])
	elif rejected > 0:
		status_changed.emit("error", detail if not detail.is_empty() else "Nie udało się zweryfikować zakupu.")
	elif awaiting > 0:
		status_changed.emit("pending", MESSAGES.pending)
	else:
		status_changed.emit("duplicate" if duplicate else "success", detail)
