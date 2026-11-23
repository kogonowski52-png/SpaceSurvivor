extends Node
## Serializes platform requests and applies only verified local or server receipts.

signal status_changed(state: String, message: String)
signal catalog_changed
signal account_changed

const Offers := preload("res://data/store/commerce_catalog.gd")
const Profile := preload("res://data/pilot_progression.gd")
const Adapter := preload("res://commerce/billing_adapter.gd")
const MESSAGES := {
	"cancelled": "Zakup anulowany. Saldo pozostaje bez zmian.",
	"network_error": "Błąd sieci. Spróbuj ponownie lub przywróć zakupy.",
	"error": "Zakup nie został zatwierdzony.",
	"unavailable": "Google Play Billing jest niedostępny w tej konfiguracji.",
	"storage_error": "Nie udało się zapisać zamówienia testowego.",
	"pending": "Zamówienie oczekuje na potwierdzenie płatności.",
	"busy": "Zakończ poprzednie zamówienie w Google Play.",
	"owned_on_play": "Google Play już widzi to zamówienie. Sprawdzamy rozliczenie.",
	"verification_unavailable": "Zweryfikuj konto gracza, aby rozliczać zakupy Google Play.",
	"server_unavailable": "Serwer zakupów jest niedostępny. Przywróć zakupy po odzyskaniu połączenia.",
	"session_required": "Zweryfikuj konto gracza, aby rozliczać zakupy Google Play.",
	"wrong_account": "Zamówienie jest przypisane do innego konta gry.",
	"wrong_purchase_environment": "Zamówienie pochodzi z innego środowiska Google Play.",
	"payments_disabled": "Płatności są zablokowane w tej wersji. Zakupy licencyjne wymagają konfiguracji testowej.",
	"purchase_voided": "Google Play anulował lub zwrócił zamówienie.",
	"insufficient_funds": "Na koncie brakuje Crystals.",
	"account_offline": "Wydatki z konta wymagają połączenia. Zdobyta waluta jest dostępna lokalnie.",
}

var adapter: Adapter
var _profile: Profile
var _request := ""
var _expected_sku := ""
var _busy := false
var _refresh_pending := false
var _account := {"known": false, "online": false, "crystals": 0, "debt": 0, "revision": 0, "offers": []}


func configure(profile: Profile, provider: Adapter) -> void:
	_profile = profile
	adapter = provider
	provider.answered.connect(_received)
	provider.catalog_changed.connect(catalog_changed.emit)
	provider.inventory_changed.connect(_refresh_inventory)
	add_child(provider)


func busy() -> bool:
	return _busy


func pending(id: String) -> bool:
	var offer: Dictionary = Offers.OFFERS.get(id, {})
	var sku: String = offer.get("sku", "")
	return not sku.is_empty() and adapter.has_pending(sku)


func account() -> Dictionary:
	return _account.duplicate(true)


func buy(id: String) -> void:
	if _busy:
		return
	var blocked := _profile.save_block_reason()
	if not blocked.is_empty():
		status_changed.emit("save", blocked)
		return
	var offer: Dictionary = Offers.OFFERS.get(id, {})
	if offer.get("kind") != "play":
		status_changed.emit("error", "Ten produkt nie należy do katalogu Google Play.")
		return
	if not adapter.checkout_available():
		status_changed.emit("payments_disabled", MESSAGES.payments_disabled)
		return
	if Offers.owns_offer(_profile.snapshot().profile, id):
		status_changed.emit("duplicate", "Produkt jest już na koncie.")
		return
	if pending(id):
		status_changed.emit("pending", MESSAGES.pending)
		return
	_start(offer.sku, "Otwieranie zakupu testowego…" if adapter.is_test() else "Otwieranie Google Play…")
	adapter.begin_purchase(_request, _expected_sku)


func restore(complete_pending: bool = false) -> void:
	if _busy:
		return
	_start("", "Sprawdzanie zamówień testowych…" if adapter.is_test() else "Sprawdzanie zakupów Google Play…")
	adapter.restore(_request, complete_pending and adapter.is_test())


func connect_account(token: String) -> void:
	if _busy or not adapter.can_connect_account():
		return
	_busy = true
	status_changed.emit("loading", "Łączenie konta Google Play z profilem pilota…")
	var result := await adapter.connect_account(token)
	if not result.ok:
		_finish("error", MESSAGES.get(result.get("error"), "Nie udało się zapisać połączenia konta."))
		return
	_finish("success", "Konto zakupów zostało połączone.")
	_refresh_inventory.call_deferred()


func refresh_balance() -> void:
	if _busy or not adapter.online_ready() or adapter.is_test():
		return
	_busy = true
	var result := await adapter.account_wallet()
	if not result.get("ok", false):
		_mark_account_offline()
		_finish("error", MESSAGES.get(result.get("error"), MESSAGES.server_unavailable))
		return
	var synced := await _apply_account(result)
	_finish(synced.state, synced.message if not synced.ok else "Saldo konta odświeżone.")


func spend_paid(id: String) -> void:
	if _busy:
		return
	var blocked := _profile.save_block_reason()
	if not blocked.is_empty():
		status_changed.emit("save", blocked)
		return
	var offer: Dictionary = Offers.OFFERS.get(id, {})
	if offer.get("kind") != "wallet" or offer.get("currency") != "crystals":
		status_changed.emit("error", MESSAGES.error)
		return
	if adapter.is_test() or not adapter.online_ready() or not _account.online:
		status_changed.emit("account_offline", MESSAGES.account_offline)
		return
	if Offers.owns_offer(_profile.snapshot().profile, id):
		status_changed.emit("duplicate", "Przedmiot jest już w kolekcji.")
		return
	_busy = true
	status_changed.emit("loading", "Rozliczanie Crystals z konta…")
	var operation := Crypto.new().generate_random_bytes(16).hex_encode()
	var receipt := await adapter.spend_account(id, operation)
	if not receipt.get("ok", false):
		if receipt.get("error") != "insufficient_funds":
			_mark_account_offline()
		_finish("error", MESSAGES.get(receipt.get("error"), MESSAGES.server_unavailable))
		return
	var settled := await _apply_account(receipt)
	if not settled.ok:
		_finish(settled.state, settled.message)
		return
	_finish("success" if receipt.get("spent", false) else "duplicate", "Przedmiot jest w kolekcji · " + String(offer.title))


func _refresh_inventory() -> void:
	if _busy:
		_refresh_pending = true
	else:
		restore()


func _start(sku: String, message: String) -> void:
	_expected_sku = sku
	_request = Crypto.new().generate_random_bytes(12).hex_encode()
	_busy = true
	var timeout := 35.0 if adapter.is_test() else 180.0
	get_tree().create_timer(timeout).timeout.connect(_expire.bind(_request))
	status_changed.emit("loading", message)


func _expire(id: String) -> void:
	if id == _request:
		_received(id, "network_error", [])


func _finish(state: String, message: String) -> void:
	_busy = false
	status_changed.emit(state, message)
	if _refresh_pending:
		_refresh_pending = false
		_refresh_inventory.call_deferred()


func _received(id: String, state: String, receipts: Array) -> void:
	if not _busy or id != _request:
		return
	var expected := _expected_sku
	_request = ""
	var platform_failed := state not in ["success", "restored"]
	var query_deliveries := expected.is_empty() and not adapter.is_test() and adapter.online_ready()
	if platform_failed and not query_deliveries:
		_finish(state, MESSAGES.get(state, MESSAGES.error))
		return
	if state == "success" and receipts.is_empty():
		_finish("error", "Brakuje potwierdzenia zakupu.")
		return
	var applied := 0
	var awaiting := 0
	var duplicate := 0
	var rejected := 0
	var detail := ""
	var outcomes: Array[Dictionary] = []
	for value: Variant in ([] if platform_failed else receipts):
		if not value is Dictionary or (not expected.is_empty() and value.get("sku") != expected):
			rejected += 1
			continue
		if value.get("stage") == "pending":
			awaiting += 1
			continue
		outcomes.append(await _fulfill(value))
	if query_deliveries:
		var backlog := await adapter.account_wallet()
		if not backlog.get("ok", false):
			_mark_account_offline()
			rejected += 1
			detail = MESSAGES.get(backlog.get("error"), MESSAGES.error)
		else:
			outcomes.append(await _apply_account(backlog))
	for outcome in outcomes:
		if not outcome.get("ok", false):
			rejected += 1
			detail = outcome.message
		elif outcome.get("state") == "duplicate":
			duplicate += 1
		else:
			applied += 1
			if detail.is_empty():
				detail = outcome.message
	if platform_failed:
		if applied > 0 and rejected == 0:
			_finish("restored", "Odświeżono konto mimo niedostępności Google Play.")
		else:
			_finish(state, detail if not detail.is_empty() else MESSAGES.get(state, MESSAGES.error))
	elif state == "restored":
		if rejected > 0 and not detail.is_empty():
			_finish("error", detail)
		else:
			_finish("error" if rejected > 0 else "restored", "Rozliczono %d nowych · %d wcześniej · %d oczekuje · %d odrzucono." %
				[applied, duplicate, awaiting, rejected])
	elif rejected > 0:
		_finish("error", detail if not detail.is_empty() else "Nie udało się zweryfikować zakupu.")
	elif awaiting > 0:
		_finish("pending", MESSAGES.pending)
	else:
		_finish("duplicate" if duplicate else "success", detail)


func _fulfill(receipt: Dictionary) -> Dictionary:
	var sku := str(receipt.get("sku", ""))
	var offer := Offers.from_sku(sku)
	if offer.is_empty() or receipt.get("stage") != "purchased" or not receipt.get("token") is String:
		return _failure("invalid_purchase")
	if adapter.is_test():
		if adapter.verify_receipt(receipt):
			return _profile.redeem_test_order(offer, receipt.token)
		return _failure("invalid_purchase")
	var proof := await adapter.authorize(receipt)
	if not proof.get("ok", false):
		return _failure(proof.get("error", "invalid_purchase"))
	if proof.get("sku") != sku:
		return _failure("wrong_product")
	var synced := await _apply_account(proof)
	if not synced.ok:
		return synced
	return {"ok": true, "state": "success" if proof.get("credited", false) else "duplicate",
		"message": "Saldo i uprawnienia zaktualizowano na koncie."}


func _apply_account(response: Dictionary) -> Dictionary:
	var wallet: Variant = response.get("wallet")
	if not wallet is Dictionary or not wallet.get("offers") is Array:
		_mark_account_offline()
		return _failure("invalid_purchase")
	for field in ["crystals", "debt", "revision"]:
		var value: Variant = wallet.get(field)
		if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > 9e15 or float(int(value)) != float(value):
			_mark_account_offline()
			return _failure("invalid_purchase")
	if int(wallet.revision) < _account.revision:
		_mark_account_offline()
		return _failure("invalid_purchase")
	var ids: Array[String] = []
	for id: Variant in wallet.offers:
		if id is String and Offers.OFFERS.has(id) and id not in ids:
			ids.append(id)
	_account = {"known": true, "online": true, "crystals": int(wallet.crystals), "debt": int(wallet.debt),
		"revision": int(wallet.revision), "offers": ids}
	_profile.set_account_offers(ids)
	account_changed.emit()
	var bonuses: Variant = response.get("credits_deliveries", [])
	if bonuses is Array:
		for delivery: Variant in bonuses:
			if delivery is String and _profile.redeem_starter_credits(delivery).ok:
				await adapter.mark_received(delivery)
	return {"ok": true, "state": "success", "message": "Saldo konta odświeżone."}


func _mark_account_offline() -> void:
	_account.online = false
	account_changed.emit()


func _failure(code: Variant) -> Dictionary:
	return {"ok": false, "state": "error", "message": MESSAGES.get(code, "Nie udało się zweryfikować zamówienia Google Play.")}
