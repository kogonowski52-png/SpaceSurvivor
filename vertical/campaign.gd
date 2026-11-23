extends RefCounted
## Stable stage IDs tie authored formations to persistent campaign records.

const ROUTE: Array[String] = ["echo", "prism", "helion"]
const DEFAULT_TIME_LIMIT := 204.0
const STAGES := {
	"echo": {
		"title": "Echo pasa", "subtitle": "Przechwyć patrol i zbierz pierwszy rdzeń.",
		"sector": "peryhelium", "tone": Color("#6fe5f2"), "sky": "res://assets/art/vertical/echo.jpg",
		"power": 1, "threat": 1, "hold": 15.0, "reward": 28,
		"waves": [
			{"name": "Patrol zewnętrzny", "drop": "core", "groups": [["line", 0, 5, 0.0, 177.0]]},
			{"name": "Klin przechwytujący", "drop": "plasma", "groups": [["wedge", 0, 7, 0.0, 181.0]]},
			{"name": "Łuk ogniowy", "drop": "core", "groups": [["arc", 1, 5, 0.0, 161.0], ["line", 0, 4, 1.2, 246.0]]},
			{"name": "Nalot zewnętrzny", "groups": [["raid", 0, 8, 0.0, 155.0], ["wedge", 1, 5, 2.0, 216.0]]},
		],
	},
	"prism": {
		"title": "Załamanie Pryzmatu", "subtitle": "Rozbij spiralę i przejmij rakiety naprowadzane.",
		"sector": "umbra", "tone": Color("#beabff"), "sky": "res://assets/art/vertical/prism.jpg",
		"power": 2, "threat": 2, "hold": 16.5, "reward": 55,
		"waves": [
			{"name": "Front załamania", "drop": "rockets", "groups": [["arc", 1, 7, 0.0, 162.0], ["line", 0, 5, 1.1, 244.0]]},
			{"name": "Spirala przechwytu", "drop": "core", "groups": [["spiral", 1, 9, 0.0, 203.0]]},
			{"name": "Zasadzka w pyle", "drop": "repair", "groups": [["raid", 0, 8, 0.0, 148.0], ["line", 2, 4, 1.2, 237.0]]},
			{"name": "Przejście dyfrakcyjne", "drop": "beam", "groups": [["wedge", 1, 7, 0.0, 168.0], ["arc", 2, 5, 1.8, 250.0]]},
			{"name": "Ostatnia eskorta", "groups": [["spiral", 1, 9, 0.0, 169.0], ["raid", 0, 8, 2.1, 231.0]]},
		],
	},
	"helion": {
		"title": "Próg Helionu", "subtitle": "Przetrwaj eskortę i zniszcz Asteriona.",
		"sector": "zenith", "tone": Color("#ffbc86"), "sky": "res://assets/art/vertical/helion.jpg",
		"power": 3, "threat": 3, "hold": 17.0, "reward": 95, "boss": true,
		"waves": [
			{"name": "Kurtyna graniczna", "drop": "plasma", "groups": [["line", 2, 6, 0.0, 151.0], ["wedge", 0, 7, 1.25, 236.0]]},
			{"name": "Zbierająca się burza", "drop": "rockets", "groups": [["spiral", 1, 9, 0.0, 174.0], ["arc", 2, 5, 1.4, 254.0]]},
			{"name": "Nalot reaktora", "drop": "repair", "groups": [["raid", 1, 10, 0.0, 164.0], ["wedge", 2, 5, 2.0, 234.0]]},
			{"name": "Pierścień eskorty", "drop": "beam", "groups": [["arc", 2, 7, 0.0, 161.0], ["spiral", 1, 9, 1.6, 245.0]]},
			{"name": "Osłona Asteriona", "drop": "core", "groups": [["line", 2, 6, 0.0, 167.0], ["raid", 1, 10, 1.5, 230.0]]},
		],
	},
}


static func time_limit(stage: Dictionary) -> float:
	return float(stage.get("time_limit", DEFAULT_TIME_LIMIT))


static func access(records: Dictionary, id: String) -> bool:
	var index := ROUTE.find(id)
	return index == 0 or (index > 0 and bool(records.get(ROUTE[index - 1], {}).get("cleared", false)))


static func next(id: String) -> String:
	var index := ROUTE.find(id)
	return ROUTE[index + 1] if index >= 0 and index + 1 < ROUTE.size() else ""
