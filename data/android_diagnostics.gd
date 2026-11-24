extends RefCounted
## Fixed report fields. No raw SDK messages, profile data, purchase identifiers or URLs are accepted.

const FRAME_LIMIT := 360
const EVENT_LIMIT := 28
const Placements := preload("res://data/store/commerce_catalog.gd")
const Campaign := preload("res://vertical/campaign.gd")
const Graphics := preload("res://data/graphics_preferences.gd")
const WORDS := {
	"sdk_idle": "czeka na pierwszą reklamę", "sdk_simulator": "symulator stacjonarny",
	"sdk_initializing": "inicjalizacja", "sdk_ready": "gotowe", "sdk_unavailable": "most niedostępny",
	"consent_unknown": "oczekiwanie", "consent_check": "sprawdzanie UMP",
	"consent_available": "SDK może żądać reklam", "consent_blocked": "SDK blokuje reklamy",
	"consent_error": "błąd odczytu", "privacy_open": "otwarty formularz",
	"privacy_saved": "zapisano wybór", "privacy_error": "błąd formularza",
	"idle": "czeka na wybór", "requested": "prośba gracza", "loading": "ładowanie",
	"ready": "gotowa", "showing": "wyświetlana", "earned": "SDK potwierdziło ukończenie",
	"closed": "zamknięta", "rewarded": "ukończona", "granted": "nagroda przyznana",
	"save_error": "nie udało się zapisać nagrody", "unavailable": "niedostępna",
	"network_error": "błąd połączenia", "timeout": "upłynął czas oczekiwania",
	"background": "przerwano po przejściu do tła", "consent": "brak uprawnienia UMP",
	"cancelled": "anulowana", "error": "błąd", "busy": "trwa poprzednia reklama",
}

var _since_usec := Time.get_ticks_usec()
var _events: Array[Dictionary] = []
var _frames := PackedFloat32Array()
var _slot := 0
var _sdk := "sdk_idle"
var _consent := "consent_unknown"
var _ad := "idle"
var _setup := {}
var _engine_bytes := 0
var _pss_kib := 0
var _peak_pss := 0
var _peak_enemies := 0
var _peak_shots := 0


func record_ad(state: String, placement: String) -> bool:
	if not WORDS.has(state) or (not placement.is_empty() and not Placements.ADS.has(placement)):
		return false
	if state.begins_with("sdk_"):
		_sdk = state
	elif state.begins_with("consent_") or state.begins_with("privacy_"):
		_consent = state
	else:
		_ad = state
	if _events.size() == EVENT_LIMIT:
		_events.pop_front()
	_events.append({"ms": int((Time.get_ticks_usec() - _since_usec) / 1000.0), "state": state, "placement": placement})
	return true


func status() -> String:
	return "SDK · %s\nPrywatność · %s\nRewarded · %s" % [WORDS[_sdk], WORDS[_consent], WORDS[_ad]]


func note_setup(level: String, elapsed_usec: int) -> void:
	if level == "menu" or Campaign.STAGES.has(level):
		_setup[level] = maxf(0.0, snappedf(elapsed_usec / 1000.0, 0.1))


func note_frame(elapsed_usec: int, enemies: int = 0, shots: int = 0) -> void:
	var duration := clampf(elapsed_usec / 1000.0, 0.001, 5000.0)
	if _frames.size() < FRAME_LIMIT:
		_frames.append(duration)
	else:
		_frames[_slot] = duration
		_slot = (_slot + 1) % FRAME_LIMIT
	_peak_enemies = maxi(_peak_enemies, enemies)
	_peak_shots = maxi(_peak_shots, shots)


func memory(bridge: Object) -> void:
	_engine_bytes = OS.get_static_memory_usage()
	if bridge != null:
		_pss_kib = int(bridge.diagnosticPssKib())
		_peak_pss = maxi(_peak_pss, _pss_kib)


func frame_stats() -> Dictionary:
	if _frames.is_empty():
		return {"samples": 0}
	var ordered := _frames.duplicate()
	ordered.sort()
	var sum := 0.0
	for duration in ordered:
		sum += duration
	return {"samples": ordered.size(), "mean_ms": snappedf(sum / ordered.size(), 0.01),
		"p95_ms": snappedf(ordered[ceili(ordered.size() * 0.95) - 1], 0.01), "max_ms": snappedf(ordered[-1], 0.01)}


func report(graphics: Dictionary, dimensions: Vector2i, bridge: Object) -> Dictionary:
	memory(bridge)
	return {"schema": 1, "version": str(ProjectSettings.get_setting("application/config/version")),
		"platform": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"resolution": [dimensions.x, dimensions.y], "graphics": Graphics.normalize(graphics),
		"frame_window": frame_stats(), "scene_setup_ms": _setup.duplicate(),
		"memory_kib": {"godot": _engine_bytes / 1024, "android_pss": _pss_kib, "android_sampled_peak_pss": _peak_pss},
		"peaks": {"enemies": _peak_enemies, "shots": _peak_shots}, "ad_events": _events.duplicate(true)}


func memory_label() -> String:
	if _pss_kib > 0:
		return "PSS %.1f MiB" % (_pss_kib / 1024.0)
	return "GODOT %.1f MiB" % (_engine_bytes / 1048576.0)
