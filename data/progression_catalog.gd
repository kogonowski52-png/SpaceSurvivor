extends RefCounted
## Shared definitions for combat, profile progression and the hangar.

const SLOTS: Array[String] = ["weapon", "armor", "engine", "reactor", "drone"]
const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]
const BASE_STATS := {
	"max_hp": 100.0,
	"speed_multiplier": 1.0,
	"damage_taken_multiplier": 1.0,
	"weapon_damage_multiplier": 1.0,
	"pulse_interval_multiplier": 1.0,
	"magnet_bonus": 0.0,
	"xp_multiplier": 1.0,
	"drone_rank": 0,
	"drone_damage_multiplier": 1.0,
}
const SHIPS := {
	"peregrine": {
		"title": "Peregrine",
		"description": "Zrównoważony myśliwiec dalekiego zasięgu. Gotowy do pierwszego lotu.",
		"sprite": "res://assets/art/player.png",
		"accent": Color("#65e9ff"),
		"exhaust": Vector2(0.073, 0.407),
		"unlock_wins": 0,
		"unlock_sector": "peryhelium",
		"stats": {},
	},
	"aegis": {
		"title": "Aegis",
		"description": "Ciężka jednostka. Kadłub +32, otrzymywane obrażenia −12%, prędkość −9%.",
		"sprite": "res://assets/art/ship_aegis.png",
		"accent": Color("#f0b96f"),
		"exhaust": Vector2(0.19, 0.45),
		"unlock_wins": 1,
		"unlock_sector": "peryhelium",
		"stats": {"max_hp": 32.0, "damage_taken_multiplier": -0.12, "speed_multiplier": -0.09},
	},
	"specter": {
		"title": "Specter",
		"description": "Lekki przechwytujący. Prędkość +20%, krótszy cykl działa −14%, kadłub −15.",
		"sprite": "res://assets/art/ship_specter.png",
		"accent": Color("#b394ff"),
		"exhaust": Vector2(0.07, 0.44),
		"unlock_wins": 3,
		"unlock_sector": "umbra",
		"stats": {"max_hp": -15.0, "speed_multiplier": 0.20, "pulse_interval_multiplier": -0.14},
	},
	"aurora": {
		"title": "Aurora",
		"description": "Lotniskowiec badawczy. Drony od startu, kadłub +8, doświadczenie +13%.",
		"sprite": "res://assets/art/ship_aurora.png",
		"accent": Color("#82edd1"),
		"exhaust": Vector2(0.10, 0.40),
		"unlock_wins": 7,
		"unlock_sector": "zenith",
		"stats": {"max_hp": 8.0, "xp_multiplier": 0.13, "drone_rank": 1, "magnet_bonus": 8.0},
	},
}
const ITEMS := {
	"pulse_coil": {
		"title": "Cewka impulsowa", "description": "Obrażenia wszystkich broni +9%.",
		"slot": "weapon", "rarity": "common", "stats": {"weapon_damage_multiplier": 0.09}
	},
	"rapid_feed": {
		"title": "Podajnik impulsowy", "description": "Obrażenia +10%, cykl działa krótszy o 9%.",
		"slot": "weapon", "rarity": "rare",
		"stats": {"weapon_damage_multiplier": 0.10, "pulse_interval_multiplier": -0.09}
	},
	"ion_driver": {
		"title": "Akcelerator jonowy", "description": "Obrażenia +15%, cykl działa krótszy o 14%.",
		"slot": "weapon", "rarity": "epic",
		"stats": {"weapon_damage_multiplier": 0.15, "pulse_interval_multiplier": -0.14}
	},
	"starbreaker": {
		"title": "Łamacz gwiazd", "description": "Obrażenia +25%, cykl działa krótszy o 18%.",
		"slot": "weapon", "rarity": "legendary",
		"stats": {"weapon_damage_multiplier": 0.25, "pulse_interval_multiplier": -0.18}
	},
	"titanium_plate": {
		"title": "Płyta tytanowa", "description": "Maksymalna wytrzymałość kadłuba +14 HP.",
		"slot": "armor", "rarity": "common", "stats": {"max_hp": 14.0}
	},
	"ceramic_shell": {
		"title": "Pancerz ceramiczny", "description": "Kadłub +18 HP, otrzymywane obrażenia −6%.",
		"slot": "armor", "rarity": "rare",
		"stats": {"max_hp": 18.0, "damage_taken_multiplier": -0.06}
	},
	"vector_weave": {
		"title": "Splot wektorowy", "description": "Kadłub +24 HP, otrzymywane obrażenia −10%.",
		"slot": "armor", "rarity": "epic",
		"stats": {"max_hp": 24.0, "damage_taken_multiplier": -0.10}
	},
	"aegis_matrix": {
		"title": "Matryca Aegis", "description": "Kadłub +34 HP, otrzymywane obrażenia −16%.",
		"slot": "armor", "rarity": "legendary",
		"stats": {"max_hp": 34.0, "damage_taken_multiplier": -0.16}
	},
	"trim_nozzle": {
		"title": "Dysza manewrowa", "description": "Prędkość lotu +8%.",
		"slot": "engine", "rarity": "common", "stats": {"speed_multiplier": 0.08}
	},
	"plasma_sprint": {
		"title": "Napęd plazmowy", "description": "Prędkość +12%, zasięg magnetyczny +6.",
		"slot": "engine", "rarity": "rare", "stats": {"speed_multiplier": 0.12, "magnet_bonus": 6.0}
	},
	"phase_rotor": {
		"title": "Wirnik fazowy", "description": "Prędkość +17%, zasięg magnetyczny +15.",
		"slot": "engine", "rarity": "epic", "stats": {"speed_multiplier": 0.17, "magnet_bonus": 15.0}
	},
	"quasar_drive": {
		"title": "Napęd kwazarowy", "description": "Prędkość +22%, zasięg magnetyczny +28.",
		"slot": "engine", "rarity": "legendary", "stats": {"speed_multiplier": 0.22, "magnet_bonus": 28.0}
	},
	"flux_cell": {
		"title": "Ogniwo strumieniowe", "description": "Doświadczenie z rdzeni +8%.",
		"slot": "reactor", "rarity": "common", "stats": {"xp_multiplier": 0.08}
	},
	"collector_core": {
		"title": "Rdzeń kolektora", "description": "Doświadczenie +12%, zasięg magnetyczny +15.",
		"slot": "reactor", "rarity": "rare", "stats": {"xp_multiplier": 0.12, "magnet_bonus": 15.0}
	},
	"dark_reactor": {
		"title": "Reaktor ciemnej materii", "description": "Doświadczenie +18%, obrażenia broni +10%.",
		"slot": "reactor", "rarity": "epic",
		"stats": {"xp_multiplier": 0.18, "weapon_damage_multiplier": 0.10}
	},
	"nova_core": {
		"title": "Rdzeń supernowej", "description": "Doświadczenie +22%, obrażenia +15%, zasięg magnetyczny +24.",
		"slot": "reactor", "rarity": "legendary",
		"stats": {"xp_multiplier": 0.22, "weapon_damage_multiplier": 0.15, "magnet_bonus": 24.0}
	},
	"escort_bay": {
		"title": "Dok eskorty", "description": "Odblokowuje od startu rój dronów na 1. randze.",
		"slot": "drone", "rarity": "common", "stats": {"drone_rank": 1}
	},
	"swarm_uplink": {
		"title": "Łącze roju", "description": "Ranga startowa dronów +1, obrażenia dronów +18%.",
		"slot": "drone", "rarity": "rare", "stats": {"drone_rank": 1, "drone_damage_multiplier": 0.18}
	},
	"wing_controller": {
		"title": "Kontroler skrzydła", "description": "Ranga startowa dronów +2, obrażenia dronów +22%.",
		"slot": "drone", "rarity": "epic", "stats": {"drone_rank": 2, "drone_damage_multiplier": 0.22}
	},
	"archon_bay": {
		"title": "Dok Archon", "description": "Ranga startowa dronów +3, obrażenia dronów +28%.",
		"slot": "drone", "rarity": "legendary", "stats": {"drone_rank": 3, "drone_damage_multiplier": 0.28}
	},
}
const SECTORS := {
	"peryhelium": {
		"title": "Peryhelium", "description": "Pierwszy kontakt z flotą Helionu na obrzeżach układu.",
		"unlock_wins": 0, "duration": 600.0,
		"enemy_hp_multiplier": 1.0, "enemy_damage_multiplier": 1.0,
		"enemy_speed_multiplier": 1.0, "spawn_interval_multiplier": 1.0,
		"sky_tint": Color.WHITE, "star_tint": Color("#65e9ff"),
		"boundary": Color("#38657b80"), "star_seed": 817229, "reward_multiplier": 1.0,
	},
	"umbra": {
		"title": "Umbra", "description": "Szybcy przechwytujący i rozległe pola minowe w cieniu mgławicy.",
		"unlock_wins": 1, "duration": 600.0,
		"enemy_hp_multiplier": 1.11, "enemy_damage_multiplier": 1.10,
		"enemy_speed_multiplier": 1.04, "spawn_interval_multiplier": 0.91,
		"sky_tint": Color(1.67, 0.71, 1.45), "star_tint": Color("#dda6ff"),
		"boundary": Color("#815cad80"), "star_seed": 726492, "reward_multiplier": 1.17,
	},
	"zenith": {
		"title": "Zenith", "description": "Ostatnia linia Helionu. Ciężkie kadłuby i gęste eskadry elit.",
		"unlock_wins": 4, "duration": 600.0,
		"enemy_hp_multiplier": 1.24, "enemy_damage_multiplier": 1.17,
		"enemy_speed_multiplier": 1.06, "spawn_interval_multiplier": 0.83,
		"sky_tint": Color(2.10, 1.35, 0.57), "star_tint": Color("#ffd3a5"),
		"boundary": Color("#9a704880"), "star_seed": 943487, "reward_multiplier": 1.38,
	},
}


static func build_stats(ship_id: String, levels: Dictionary, equipped: Dictionary) -> Dictionary:
	var stats := BASE_STATS.duplicate()
	var ship: Dictionary = SHIPS.get(ship_id, SHIPS["peregrine"])
	_apply(stats, ship["stats"])
	stats["max_hp"] += 8.0 * maxi(0, int(levels.get("hull", 0)))
	stats["speed_multiplier"] += 0.04 * maxi(0, int(levels.get("drive", 0)))
	stats["weapon_damage_multiplier"] += 0.08 * maxi(0, int(levels.get("output", 0)))
	for slot in SLOTS:
		var item_id := String(equipped.get(slot, ""))
		var item: Dictionary = ITEMS.get(item_id, {})
		if item.get("slot") == slot:
			_apply(stats, item["stats"])
	return stats


static func _apply(stats: Dictionary, additions: Dictionary) -> void:
	for metric: String in additions:
		stats[metric] += additions[metric]
