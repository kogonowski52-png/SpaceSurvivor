extends RefCounted
## Stable offer IDs and SKUs. Play prices must come from ProductDetails in a live adapter.

const TABS := {
	"featured": "OFERTY", "crystals": "CRYSTALS", "skins": "STATKI I SKÓRKI",
	"gear": "WYPOSAŻENIE", "season": "HELION", "free": "DARMOWE",
}
const SKINS := {
	"peregrine_ion": {"title": "Peregrine · Ion", "ship": "peregrine", "tint": Color("#adbfff"), "accent": Color("#aaa1ff")},
	"peregrine_sol": {"title": "Peregrine · Sol", "ship": "peregrine", "tint": Color("#ffcc89"), "accent": Color("#ffbb68")},
	"aegis_frost": {"title": "Aegis · Frost", "ship": "aegis", "tint": Color("#a7dcff"), "accent": Color("#83e4ff")},
	"peregrine_helion": {"title": "Peregrine · Helion", "ship": "peregrine", "tint": Color("#ffc1cf"), "accent": Color("#ff88a9")},
	"specter_noctis": {"title": "Specter · Noctis", "ship": "specter", "tint": Color("#a5a2ff"), "accent": Color("#bca2ff")},
	"aurora_vesper": {"title": "Aurora · Vesper", "ship": "aurora", "tint": Color("#caffca"), "accent": Color("#a2ffc7")},
}
const EFFECTS := {
	"pilot_fx_prism": {"title": "Prism", "plume": Color("#d59aff"), "shot": Color("#98b5ff")},
}
const ADS := {
	"bonus": {"coins": 150}, "materials": {"materials": 45}, "boss": {"materials": 35},
	"double": {}, "revive": {},
}
const OFFERS := {
	"starter": {
		"tab": "featured", "title": "Pakiet startowy", "subtitle": "Wyposażenie pilota",
		"description": "600 Credits, 120 Crystals i skórka Peregrine · Ion.",
		"sku": "gs_starter_v1", "art": "peregrine", "kind": "play", "test_price": "14,99 zł",
		"product_type": "non_consumable", "coins": 600, "crystals": 120, "skin": "peregrine_ion",
	},
	"arsenal_pilot": {
		"tab": "featured", "title": "Pakiet uzbrojenia", "subtitle": "Dwa moduły Rare",
		"description": "Podajnik impulsowy i rdzeń kolektora. Zawartość jest stała.",
		"sku": "gs_arsenal_v1", "product_type": "non_consumable", "kind": "play", "preview": true,
		"art": "arsenal", "items": ["rapid_feed", "collector_core"], "test_price": "14,99 zł",
	},
	"hangar_supply": {
		"tab": "featured", "title": "Zaopatrzenie hangaru", "subtitle": "Pakiet materiałów",
		"description": "480 Credits i 140 materiałów do ulepszeń statku.",
		"sku": "gs_hangar_supply_v1", "product_type": "non_consumable", "kind": "play", "preview": true,
		"art": "supply", "coins": 480, "materials": 140, "test_price": "11,99 zł",
	},
	"crystals_100": {
		"tab": "crystals", "title": "100 Crystals", "subtitle": "Zasobnik", "description": "Dodaje 100 Crystals do portfela.",
		"sku": "gs_crystals_100", "art": "crystals", "art_rank": 1, "kind": "play", "product_type": "consumable", "crystals": 100, "test_price": "7,99 zł",
	},
	"crystals_350": {
		"tab": "crystals", "title": "350 Crystals", "subtitle": "Kontener", "description": "Dodaje 350 Crystals do portfela.",
		"sku": "gs_crystals_350", "art": "crystals", "art_rank": 2, "kind": "play", "product_type": "consumable", "crystals": 350, "test_price": "19,99 zł",
	},
	"crystals_900": {
		"tab": "crystals", "title": "900 Crystals", "subtitle": "Magazyn", "description": "Dodaje 900 Crystals do portfela.",
		"sku": "gs_crystals_900", "art": "crystals", "art_rank": 3, "kind": "play", "product_type": "consumable", "crystals": 900, "test_price": "39,99 zł",
	},
	"skin_ion": {
		"tab": "skins", "title": "Peregrine · Ion", "subtitle": "Fioletowe poszycie", "description": "Skórka dla Peregrine. Bez zmian parametrów lotu.",
		"kind": "wallet", "currency": "crystals", "price": 45, "skin": "peregrine_ion", "art": "peregrine",
	},
	"skin_sol": {
		"tab": "skins", "title": "Peregrine · Sol", "subtitle": "Złote poszycie", "description": "Skórka dla Peregrine. Bez zmian parametrów lotu.",
		"kind": "wallet", "currency": "coins", "price": 950, "skin": "peregrine_sol", "art": "peregrine",
	},
	"skin_frost": {
		"tab": "skins", "title": "Aegis · Frost", "subtitle": "Lodowe poszycie", "description": "Skórka dla Aegis. Bez zmian parametrów lotu.",
		"kind": "wallet", "currency": "crystals", "price": 55, "skin": "aegis_frost", "art": "aegis",
	},
	"skin_specter_noctis": {
		"tab": "skins", "title": "Specter · Noctis", "subtitle": "Skórka Spectera",
		"description": "Fioletowe poszycie i światła silników Spectera. Parametry lotu pozostają takie same.",
		"sku": "gs_skin_specter_noctis_v1", "product_type": "non_consumable", "kind": "play", "preview": true,
		"art": "specter", "skin": "specter_noctis", "test_price": "11,99 zł",
	},
	"skin_aurora_vesper": {
		"tab": "skins", "title": "Aurora · Vesper", "subtitle": "Skórka Aurory",
		"description": "Miętowe poszycie i światła silników Aurory. Parametry lotu pozostają takie same.",
		"sku": "gs_skin_aurora_vesper_v1", "product_type": "non_consumable", "kind": "play", "preview": true,
		"art": "aurora", "skin": "aurora_vesper", "test_price": "11,99 zł",
	},
	"pilot_fx_prism": {
		"tab": "skins", "title": "Prism", "subtitle": "Efekty lotu",
		"description": "Fioletowe smugi silników i opalizujące pociski dla wszystkich statków.",
		"sku": "gs_pilot_fx_prism_v1", "product_type": "non_consumable", "kind": "play", "preview": true,
		"art": "prism", "effect": "pilot_fx_prism", "test_price": "9,99 zł",
	},
	"equipment_patrol": {
		"tab": "gear", "title": "Zestaw patrolowy", "subtitle": "Dwa moduły Rare",
		"description": "Pancerz ceramiczny i napęd plazmowy. Zawartość jest stała.",
		"kind": "wallet", "currency": "coins", "price": 720, "art": "gear",
		"items": ["ceramic_shell", "plasma_sprint"],
	},
	"equipment_signal": {
		"tab": "gear", "title": "Zestaw orbitalny", "subtitle": "Dwa moduły Epic",
		"description": "Reaktor ciemnej materii i kontroler skrzydła. Zawartość jest stała.",
		"kind": "wallet", "currency": "crystals", "price": 80, "art": "gear",
		"items": ["dark_reactor", "wing_controller"],
	},
	"season_helion": {
		"tab": "season", "title": "Przepustka Helion", "subtitle": "Archiwum sezonu",
		"description": "Bezterminowy dostęp do dodatkowych nagród za 1, 3 i 6 rozegranych lotów.",
		"sku": "gs_helion_pass_v1", "product_type": "non_consumable", "kind": "play", "art": "season", "test_price": "19,99 zł",
	},
}
const SEASON := {
	"free_1": {"goal": 1, "crystals": 8}, "free_3": {"goal": 3, "crystals": 12},
	"free_6": {"goal": 6, "crystals": 20},
	"pass_1": {"goal": 1, "coins": 400, "pass": true}, "pass_3": {"goal": 3, "crystals": 30, "pass": true},
	"pass_6": {"goal": 6, "skin": "peregrine_helion", "pass": true},
}


static func from_sku(sku: String) -> String:
	for id: String in OFFERS:
		if OFFERS[id].get("sku", "") == sku and not sku.is_empty():
			return id
	return ""


static func owns_offer(profile: Dictionary, id: String) -> bool:
	var offer: Dictionary = OFFERS.get(id, {})
	if id in profile.commerce.entitlements:
		return true
	if offer.get("kind") != "wallet":
		return false
	if offer.has("skin"):
		return offer.skin in profile.commerce.skins
	if offer.has("items"):
		return offer.items.all(func(item: String) -> bool: return item in profile.inventory)
	return false


static func format_cost(offer: Dictionary) -> String:
	return "%d %s" % [offer.price, "Credits" if offer.currency == "coins" else "Crystals"]
