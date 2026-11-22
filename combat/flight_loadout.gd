extends RefCounted

const UPGRADES := {
	"pulse_damage": {"title": "Wzmocnienie pulsu", "description": "Pociski lancy zadają o 5 pkt. więcej obrażeń.", "tag": "Lanca pulsacyjna"},
	"pulse_cadence": {"title": "Szybki cykl", "description": "Lanca pulsacyjna strzela o 15% częściej.", "tag": "Lanca pulsacyjna"},
	"repair": {"title": "Pancerz adaptacyjny", "description": "Zwiększa maks. HP o 15 i naprawia 30 HP.", "tag": "Przeżycie"},
	"thruster": {"title": "Dopalacz wektorowy", "description": "Zwiększa prędkość statku o 12%.", "tag": "Mobilność"},
	"tractor": {"title": "Wiązka grawitacyjna", "description": "Przyciąga rdzenie XP z większej odległości (+45).", "tag": "Doświadczenie"},
	"missiles": {"title": "Rakiety Widmo", "description": "Wystrzeliwują samonaprowadzające rakiety z trafieniem obszarowym.", "tag": "Nowa broń"},
	"nova": {"title": "Pierścień jonowy", "description": "Wyzwala falę jonową, która razi pobliskich przeciwników.", "tag": "Nowa broń"},
	"shield": {"title": "Absorber kinetyczny", "description": "Zmniejsza otrzymywane obrażenia o 14 punktów procentowych.", "tag": "Przeżycie"}
}
const MAX_RANK := {
	"pulse_damage": 8, "pulse_cadence": 5, "repair": 12, "thruster": 4,
	"tractor": 4, "missiles": 5, "nova": 5, "shield": 4
}

var ranks: Dictionary[String, int] = {}


func rank(id: String) -> int:
	return ranks.get(id, 0)


func cards(rng: RandomNumberGenerator, level: int) -> Array[Dictionary]:
	var available: Array[String] = []
	for id: String in UPGRADES:
		if rank(id) < int(MAX_RANK[id]):
			available.append(id)

	var selected: Array[String] = []
	if level == 2:
		selected.append("missiles")
		selected.append("nova")
		available.erase("missiles")
		available.erase("nova")

	while selected.size() < 3 and not available.is_empty():
		var index := rng.randi_range(0, available.size() - 1)
		selected.append(available[index])
		available.remove_at(index)

	var result: Array[Dictionary] = []
	for id in selected:
		var card: Dictionary = UPGRADES[id].duplicate()
		card["id"] = id
		if rank(id) > 0:
			match id:
				"missiles":
					card["tag"] = "Rakiety Widmo"
					card["description"] = "Rakiety zadają o 12 pkt. więcej obrażeń i startują częściej."
				"nova":
					card["tag"] = "Pierścień jonowy"
					card["description"] = "Fala zadaje o 15 pkt. więcej obrażeń i ma większy zasięg."
		result.append(card)
	return result


func increment(id: String) -> void:
	ranks[id] = rank(id) + 1


func speed_multiplier() -> float:
	return 1.0 + 0.12 * rank("thruster")


func magnet_range() -> float:
	return 142.0 + 45.0 * rank("tractor")


func damage_multiplier() -> float:
	return 1.0 - 0.14 * rank("shield")
