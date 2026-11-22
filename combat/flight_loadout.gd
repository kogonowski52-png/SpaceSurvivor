extends RefCounted

const RARITY_WEIGHT := {"common": 1.0, "rare": 0.7, "epic": 0.46, "legendary": 0.3}
const WEAPONS := ["pulse_damage", "missiles", "laser", "nova", "tesla", "drones"]
const UPGRADES := {
	"pulse_damage": {
		"rarity": "common",
		"title": "Działo pulsacyjne", "description": "Impulsy zadają o 5 pkt. więcej obrażeń.",
		"tag": "Ulepszenie broni", "cap": 7, "weight": 1.5
	},
	"missiles": {
		"rarity": "rare",
		"title": "Rakiety Widmo", "description": "Samonaprowadzające rakiety rażą cele w obszarze wybuchu.",
		"repeat": "Rakiety są mocniejsze (+12) i szybciej gotowe do odpalenia.",
		"tag": "Nowa broń", "cap": 5, "weight": 1.05
	},
	"laser": {
		"rarity": "epic",
		"title": "Promień laserowy", "description": "Śledzi cel i wielokrotnie rani wrogów w linii.",
		"repeat": "Zwiększa zasięg i obrażenia każdego impulsu wiązki (+3).",
		"tag": "Nowa broń", "cap": 5, "weight": 1.05
	},
	"nova": {
		"rarity": "rare",
		"title": "Orbity plazmowe", "description": "Wokół kadłuba krążą kule plazmy, raniąc dotkniętych wrogów.",
		"repeat": "Kule plazmy zadają o 4 pkt. więcej obrażeń i krążą szybciej.",
		"tag": "Nowa broń", "cap": 5, "weight": 1.05
	},
	"tesla": {
		"rarity": "epic",
		"title": "Łańcuch Tesli", "description": "Wyładowanie przeskakuje z celu na kolejnych wrogów.",
		"repeat": "Łuk zadaje o 8 pkt. więcej obrażeń, a odstęp między atakami maleje.",
		"tag": "Nowa broń", "cap": 5, "weight": 1.05
	},
	"drones": {
		"rarity": "rare",
		"title": "Rój dronów", "description": "Eskorta krąży wokół statku i razi pobliskie cele.",
		"repeat": "Eskorta zadaje większe obrażenia (+4) i strzela częściej.",
		"tag": "Nowa broń", "cap": 5, "weight": 1.05
	},
	"pulse_crossfire": {
		"rarity": "legendary",
		"title": "Ogień krzyżowy", "description": "Co trzeci atak działa pokrywa cztery dodatkowe kierunki.",
		"tag": "Ewolucja działa", "cap": 1, "weight": 3.5, "requires": "pulse_damage"
	},
	"missile_cluster": {
		"rarity": "legendary",
		"title": "Głowica kasetowa", "description": "Wybuch rakiety wypuszcza pięć odłamków energetycznych.",
		"tag": "Ewolucja rakiet", "cap": 1, "weight": 3.5, "requires": "missiles"
	},
	"tesla_branch": {
		"rarity": "legendary",
		"title": "Rozgałęzienie Tesli", "description": "Pierwsze trafienie tworzy dwa dodatkowe odgałęzienia łuku.",
		"tag": "Ewolucja Tesli", "cap": 1, "weight": 3.5, "requires": "tesla"
	},
	"repair": {
		"rarity": "common",
		"title": "Pancerz adaptacyjny", "description": "Zwiększa maks. HP o 15 i naprawia 30 HP.",
		"tag": "Przeżycie", "cap": 0, "weight": 1.3
	},
	"tractor": {
		"rarity": "common",
		"title": "Wiązka grawitacyjna", "description": "Zasięg przyciągania rdzeni XP +30, prędkość statku +6%.",
		"tag": "Mobilność", "cap": 0, "weight": 1.0
	},
	"shield": {
		"rarity": "rare",
		"title": "Absorber kinetyczny", "description": "Redukuje pozostałe otrzymywane obrażenia o 12%.",
		"tag": "Przeżycie", "cap": 0, "weight": 1.0
	}
}

var ranks: Dictionary[String, int] = {}


func rank(id: String) -> int:
	return ranks.get(id, 0)


func eligible(id: String) -> bool:
	if not UPGRADES.has(id):
		return false
	var spec: Dictionary = UPGRADES[id]
	var prerequisite := String(spec.get("requires", ""))
	if not prerequisite.is_empty() and rank(prerequisite) < 3:
		return false
	var cap := int(spec["cap"])
	return cap == 0 or rank(id) < cap


func cards(rng: RandomNumberGenerator, level: int) -> Array[Dictionary]:
	var available: Array[String] = []
	var unlockable: Array[String] = []
	for id: String in UPGRADES:
		if eligible(id):
			available.append(id)
			if id != "pulse_damage" and id in WEAPONS and rank(id) == 0:
				unlockable.append(id)

	var selected: Array[String] = []
	if level == 2 and not unlockable.is_empty():
		var first := _pick_weighted(rng, unlockable)
		selected.append(first)
		available.erase(first)
	while selected.size() < 3:
		var id := _pick_weighted(rng, available)
		selected.append(id)
		available.erase(id)

	var result: Array[Dictionary] = []
	for id in selected:
		var spec: Dictionary = UPGRADES[id]
		var current := rank(id)
		var description := String(spec["description"])
		var tag := String(spec["tag"])
		if current > 0 and spec.has("repeat"):
			description = String(spec["repeat"])
			tag = "Ulepszenie broni"
		if id == "pulse_damage" and current % 2 == 0:
			description = "Dodaje pocisk do salwy. Każdy impuls zadaje +5 obrażeń."
		result.append({
			"id": id, "icon": id, "title": spec["title"], "description": description,
			"tag": tag, "rarity": spec["rarity"],
			"rank": current, "next_rank": current + 1, "is_evolution": spec.has("requires")
		})
	return result


func _pick_weighted(rng: RandomNumberGenerator, available: Array[String]) -> String:
	var total := 0.0
	for id in available:
		total += _weight(id)
	var roll := rng.randf() * total
	for id in available:
		roll -= _weight(id)
		if roll < 0.0:
			return id
	return available.back()


func _weight(id: String) -> float:
	var spec: Dictionary = UPGRADES[id]
	var base := float(spec["weight"]) * float(RARITY_WEIGHT[spec["rarity"]])
	if id != "pulse_damage" and id in WEAPONS:
		return base * (1.35 if rank(id) == 0 else 1.22)
	return base


func increment(id: String) -> bool:
	if not eligible(id):
		return false
	ranks[id] = rank(id) + 1
	return true


func speed_multiplier() -> float:
	return 1.0 + 0.06 * rank("tractor")


func magnet_range() -> float:
	return 142.0 + 30.0 * rank("tractor")


func damage_multiplier() -> float:
	return pow(0.88, rank("shield"))
