extends RefCounted
## Stable route IDs preserve the pilot's scores and unlocks across campaign revisions.

const ROUTE: Array[String] = ["echo", "prism", "helion"]
const DEFAULT_TIME_LIMIT := 320.0
# Group entries describe shape, fighter class, count, arrival time, depth, and horizontal bias.
const STAGES := {
	"echo": {
		"title": "Echo pasa", "subtitle": "Przechwyć patrol i przejmij moduły floty.",
		"region": "PIERŚCIEŃ KALLISTO", "sector": "peryhelium", "tone": Color("#77e9ee"),
		"sky": "res://assets/art/premium/sky/echo.jpg", "planet": "res://assets/art/premium/sky/echo.webp",
		"planet_offset": Vector2(46, 267), "power": 1, "threat": 1, "hold": 8.6, "reward": 28,
		"waves": [
			{"name": "Pierwszy kontakt", "groups": [["line", 0, 4, 0.0, 160], ["group", 0, 4, 3.5, 194, -61], ["wedge", 0, 5, 7.2, 161, 34]]},
			{"name": "Ogień skrzyżowany", "drop": "plasma", "groups": [["arc", 0, 5, 0.0, 150], ["raid", 0, 5, 3.6, 157, 51], ["wedge", 1, 5, 7.4, 175], ["group", 0, 4, 10.4, 162, -48]]},
			{"name": "Patrol pierścienia", "groups": [["group", 1, 4, 0.0, 198, 54], ["line", 0, 5, 3.1, 169, -17], ["raid", 0, 4, 6.3, 150, -50], ["arc", 0, 5, 9.8, 169]]},
			{"name": "Krzywizna orbity", "drop": "core", "groups": [["spiral", 0, 6, 0.0, 185], ["group", 0, 4, 3.7, 209, 60], ["arc", 1, 5, 6.7, 152, -31], ["wedge", 0, 5, 10.5, 164]]},
			{"name": "Przecięcie kursu", "groups": [["raid", 1, 5, 0.0, 155, -50], ["arc", 0, 6, 3.2, 159], ["group", 1, 5, 6.7, 183, 47], ["wedge", 0, 5, 10.2, 180, -25]]},
			{"name": "Dywizjon przedni", "drop": "repair", "groups": [["wedge", 1, 5, 0.0, 163], ["group", 0, 4, 3.8, 206, -41], ["line", 0, 5, 6.7, 172], ["arc", 2, 3, 10.3, 151, 26]]},
			{"name": "Przejście między skałami", "groups": [["arc", 0, 5, 0.0, 173, 37], ["raid", 1, 5, 3.5, 151, -54], ["wedge", 0, 6, 7.3, 158], ["group", 0, 4, 10.9, 183, 58]]},
			{"name": "Szyk obronny", "drop": "rockets", "groups": [["group", 2, 4, 0.0, 177], ["wedge", 0, 5, 3.6, 153, 38], ["arc", 1, 5, 7.3, 186, -31], ["raid", 0, 4, 10.1, 142]]},
			{"name": "Ostatni przechwyt", "groups": [["line", 1, 5, 0.0, 153], ["spiral", 0, 6, 3.5, 193, -26], ["group", 0, 4, 7.3, 168, 56], ["wedge", 2, 3, 10.5, 151]]},
			{"name": "Wyjście z pierścienia", "groups": [["arc", 1, 6, 0.0, 173], ["group", 2, 4, 3.8, 196, -27], ["raid", 0, 6, 7.5, 155, 45], ["wedge", 1, 5, 10.6, 156]]},
		],
	},
	"prism": {
		"title": "Załamanie Pryzmatu", "subtitle": "Rozbij szyk przechwytujący w obszarze mgławicy.",
		"region": "MGŁAWICA UMBRA", "sector": "umbra", "tone": Color("#c3a9ff"),
		"sky": "res://assets/art/premium/sky/prism.jpg", "planet": "res://assets/art/premium/sky/prism.webp",
		"planet_offset": Vector2(462, 248), "power": 2, "threat": 2, "hold": 9.1, "reward": 55,
		"waves": [
			{"name": "Front załamania", "drop": "rockets", "groups": [["arc", 1, 5, 0.0, 157], ["line", 0, 5, 3.8, 222], ["group", 1, 5, 7.4, 181, -44], ["raid", 1, 4, 10.4, 153, 49]]},
			{"name": "Spirala przechwytu", "drop": "core", "groups": [["spiral", 1, 7, 0.0, 193], ["raid", 0, 4, 3.7, 147, -50], ["arc", 2, 4, 7.4, 153, 42], ["wedge", 1, 5, 10.6, 178]]},
			{"name": "Zasadzka w pyle", "groups": [["raid", 1, 6, 0.0, 141, -41], ["group", 2, 4, 3.4, 204, 34], ["wedge", 0, 6, 7.4, 177], ["line", 1, 4, 10.4, 163, -22]]},
			{"name": "Przejście dyfrakcyjne", "drop": "beam", "groups": [["wedge", 1, 6, 0.0, 165], ["arc", 2, 4, 3.8, 174, -23], ["group", 1, 5, 7.7, 213, 55], ["spiral", 0, 6, 11.0, 182]]},
			{"name": "Dywizjon osłonowy", "drop": "repair", "groups": [["group", 2, 4, 0.0, 168], ["arc", 1, 5, 3.8, 200, -31], ["raid", 1, 5, 7.6, 159, 47], ["wedge", 2, 3, 10.6, 157]]},
			{"name": "Podwójne ostrze", "groups": [["wedge", 1, 5, 0.0, 164, -58], ["wedge", 1, 5, 3.0, 193, 55], ["group", 0, 6, 7.1, 176, -37], ["arc", 2, 4, 10.7, 183]]},
			{"name": "Linia cienia", "drop": "core", "groups": [["line", 2, 4, 0.0, 166], ["raid", 1, 6, 3.5, 145, -43], ["spiral", 0, 7, 7.5, 201, 33], ["group", 1, 5, 11.0, 164, 23]]},
			{"name": "Dryf mgławicy", "groups": [["spiral", 1, 6, 0.0, 179, 40], ["arc", 2, 4, 3.6, 151, -30], ["wedge", 1, 5, 7.4, 183], ["raid", 0, 6, 10.8, 150, -53]]},
			{"name": "Tunel pryzmatu", "drop": "plasma", "groups": [["arc", 1, 6, 0.0, 182], ["group", 2, 4, 3.8, 196, -49], ["raid", 1, 5, 7.6, 153, 55], ["line", 2, 4, 11.1, 188]]},
			{"name": "Ostatnia eskorta", "groups": [["spiral", 1, 7, 0.0, 184], ["group", 2, 4, 3.6, 206, 43], ["raid", 0, 6, 7.4, 151, -34], ["wedge", 2, 4, 11.2, 173]]},
		],
	},
	"helion": {
		"title": "Próg Helionu", "subtitle": "Przebij się przez eskortę i zniszcz Asteriona.",
		"region": "ORBITY ZENITHU", "sector": "zenith", "tone": Color("#ffb783"),
		"sky": "res://assets/art/premium/sky/helion.jpg", "planet": "res://assets/art/premium/sky/helion.webp",
		"planet_offset": Vector2(464, 303), "power": 3, "threat": 3, "hold": 9.6, "reward": 95, "boss": true,
		"waves": [
			{"name": "Kurtyna graniczna", "drop": "plasma", "groups": [["line", 2, 5, 0.0, 154], ["wedge", 0, 6, 3.4, 201], ["raid", 1, 5, 7.4, 154, -48], ["group", 2, 4, 10.8, 180, 50]]},
			{"name": "Zbierająca się burza", "drop": "rockets", "groups": [["spiral", 1, 7, 0.0, 181], ["arc", 2, 4, 3.7, 194, 40], ["raid", 1, 6, 7.5, 155, -44], ["wedge", 2, 5, 10.9, 157]]},
			{"name": "Nalot reaktora", "drop": "repair", "groups": [["raid", 1, 6, 0.0, 151, -48], ["wedge", 2, 4, 3.9, 173, 42], ["group", 1, 5, 7.6, 195, -32], ["line", 2, 4, 11.2, 176]]},
			{"name": "Pierścień eskorty", "drop": "beam", "groups": [["arc", 2, 5, 0.0, 156], ["spiral", 1, 7, 3.6, 195, -30], ["raid", 1, 5, 7.4, 142, 48], ["group", 2, 4, 10.7, 167]]},
			{"name": "Pancerne skrzydło", "drop": "core", "groups": [["group", 2, 4, 0.0, 168, -47], ["arc", 1, 6, 3.6, 173, 30], ["wedge", 2, 5, 7.3, 193], ["raid", 0, 6, 11.1, 150, 33]]},
			{"name": "Łuk graniczny", "groups": [["arc", 2, 5, 0.0, 166, 37], ["spiral", 1, 8, 3.8, 192, -27], ["group", 2, 4, 7.8, 179, 42], ["wedge", 1, 5, 11.5, 179]]},
			{"name": "Natarcie Helionu", "drop": "repair", "groups": [["raid", 1, 6, 0.0, 150, 42], ["line", 2, 5, 3.8, 165], ["wedge", 0, 6, 7.2, 206, -32], ["group", 2, 4, 11.0, 171, -48]]},
			{"name": "Żelazny zagon", "groups": [["wedge", 2, 5, 0.0, 169], ["group", 1, 5, 3.7, 192, 43], ["spiral", 1, 7, 7.5, 185, -34], ["raid", 2, 4, 11.0, 151]]},
			{"name": "Konwój dowodzenia", "drop": "core", "groups": [["group", 2, 5, 0.0, 173, -45], ["raid", 1, 6, 3.7, 161, 43], ["arc", 2, 5, 7.4, 164], ["spiral", 1, 6, 11.0, 201, -27]]},
			{"name": "Osłona Asteriona", "groups": [["line", 2, 5, 0.0, 159], ["wedge", 1, 6, 3.8, 174, -35], ["arc", 2, 5, 7.7, 166, 32], ["group", 2, 6, 11.5, 189]]},
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
