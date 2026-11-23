extends RefCounted
## Profile mutations are applied to a draft. PilotProgression commits the receipt and the grant together.

const Offers := preload("res://data/store/commerce_catalog.gd")
const VALUES := ["coins", "crystals", "materials", "crates"]


static func empty_state() -> Dictionary:
	return {
		"receipts": {}, "entitlements": [], "skins": [], "equipped_skins": {}, "season": [],
		"bonus_day": "", "flight": {},
	}


static func buy(draft: Dictionary, id: String) -> Dictionary:
	var offer: Dictionary = Offers.OFFERS.get(id, {})
	if offer.get("kind") != "wallet":
		return failure("invalid", "Nie ma takiej oferty za walutę gry.")
	if Offers.owns_offer(draft, id):
		return failure("owned", "Zawartość tej oferty jest już w kolekcji.")
	var currency: String = offer.currency
	if int(draft[currency]) < int(offer.price):
		return failure("funds", "Brakuje %s." % ("Credits" if currency == "coins" else "Crystals"))
	draft[currency] -= int(offer.price)
	draft.commerce.entitlements.append(id)
	_grant(draft, offer)
	return success("Zakupiono · %s" % offer.title)


static func redeem_play(draft: Dictionary, id: String, token: String) -> Dictionary:
	var offer: Dictionary = Offers.OFFERS.get(id, {})
	if offer.get("kind") != "play" or not token.begins_with("gs-test-") or token.length() > 128:
		return failure("invalid", "Potwierdzenie zakupu jest nieprawidłowe.")
	var key := "test:" + token.sha256_text()
	if draft.commerce.receipts.has(key):
		if draft.commerce.receipts[key] != id:
			return failure("invalid", "Potwierdzenie należy do innego produktu.")
		return {"ok": true, "changed": false, "state": "duplicate", "message": "Ten zakup został już rozliczony."}
	draft.commerce.receipts[key] = id
	if offer.product_type == "non_consumable":
		if id in draft.commerce.entitlements:
			return {"ok": true, "changed": true, "state": "duplicate", "message": "Produkt jest już na koncie."}
		draft.commerce.entitlements.append(id)
	_grant(draft, offer)
	return success("Zakup testowy rozliczony · %s" % offer.title)


static func set_skin(draft: Dictionary, id: String, unlocked: Array) -> Dictionary:
	var spec: Dictionary = Offers.SKINS.get(id, {})
	if spec.is_empty() or id not in draft.commerce.skins:
		return failure("invalid", "Ta skórka nie jest jeszcze dostępna.")
	if spec.ship not in unlocked:
		return failure("locked", "Najpierw odblokuj ten statek w hangarze.")
	if draft.commerce.equipped_skins.get(spec.ship, "") == id:
		draft.commerce.equipped_skins.erase(spec.ship)
		return success("Przywrócono standardowe poszycie.")
	draft.commerce.equipped_skins[spec.ship] = id
	return success("Założono · %s" % spec.title)


static func claim_season(draft: Dictionary, id: String) -> Dictionary:
	var reward: Dictionary = Offers.SEASON.get(id, {})
	if reward.is_empty() or id in draft.commerce.season:
		return failure("claimed", "Ta nagroda została już odebrana lub jest niedostępna.")
	if draft.totals.flights < reward.goal:
		return failure("locked", "Ukończ więcej lotów, aby odebrać nagrodę.")
	if reward.get("pass", false) and "season_helion" not in draft.commerce.entitlements:
		return failure("locked", "Ten tor wymaga przepustki Helion.")
	draft.commerce.season.append(id)
	_grant(draft, reward)
	return success("Odebrano nagrodę Helionu.")


static func ad_eligible(profile: Dictionary, placement: String, scope: String, today: String) -> bool:
	match placement:
		"bonus":
			return scope == today and profile.commerce.bonus_day < today
		"double":
			var flight: Dictionary = profile.commerce.flight
			return not scope.is_empty() and flight.get("id", "") == scope and not flight.get("doubled", false)
		"revive":
			return not scope.is_empty() and not profile.commerce.receipts.has("revive:" + scope)
	return false


static func claim_ad(draft: Dictionary, placement: String, scope: String, today: String) -> Dictionary:
	if not ad_eligible(draft, placement, scope, today):
		return failure("claimed", "Nagroda jest już odebrana lub wygasła.")
	match placement:
		"bonus":
			draft.commerce.bonus_day = today
			draft.coins += Offers.DAILY_AD_CREDITS
			return success("Odebrano +%d Credits." % Offers.DAILY_AD_CREDITS)
		"double":
			var flight: Dictionary = draft.commerce.flight
			_grant(draft, flight)
			flight.doubled = true
			return success("Nagrody z lotu podwojone.")
		"revive":
			draft.commerce.receipts["revive:" + scope] = "revive"
			return success("Statek gotowy do powrotu.")
	return failure("invalid", "Nieznana nagroda.")


static func _grant(draft: Dictionary, award: Dictionary) -> void:
	for currency in VALUES:
		draft[currency] += int(award.get(currency, 0))
	for item: String in award.get("items", []):
		if item not in draft.inventory:
			draft.inventory.append(item)
	var skin: String = award.get("skin", "")
	if not skin.is_empty() and skin not in draft.commerce.skins:
		draft.commerce.skins.append(skin)


static func success(message: String) -> Dictionary:
	return {"ok": true, "changed": true, "state": "success", "message": message}


static func failure(state: String, message: String) -> Dictionary:
	return {"ok": false, "changed": false, "state": state, "message": message}
