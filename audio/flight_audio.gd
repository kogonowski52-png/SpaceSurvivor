extends Node
## Owns music transitions and sound-effect gain without changing system volume.

const SCORE := [
	preload("res://assets/audio/docking_bay.ogg"),
	preload("res://assets/audio/hostile_orbit.ogg"),
]
const MUSIC_LEVEL_DB := -9.0
const MUSIC_FADE_SECONDS := 0.75
const SILENT_DB := -80.0
const EFFECTS := {
	"shot": [preload("res://assets/audio/shot.wav"), -24.0, 0.08],
	"missile": [preload("res://assets/audio/missile.wav"), -18.0, 0.10],
	"nova": [preload("res://assets/audio/nova.wav"), -16.0, 0.20],
	"laser": [preload("res://assets/audio/laser.wav"), -19.0, 0.30],
	"tesla": [preload("res://assets/audio/tesla.wav"), -18.0, 0.25],
	"drone": [preload("res://assets/audio/drone.wav"), -26.0, 0.22],
	"hit": [preload("res://assets/audio/hit.wav"), -26.0, 0.135],
	"kill": [preload("res://assets/audio/kill.wav"), -20.0, 0.14],
	"hurt": [preload("res://assets/audio/hurt.wav"), -14.0, 0.25],
	"upgrade": [preload("res://assets/audio/upgrade.wav"), -13.0, 0.20],
	"pickup": [preload("res://assets/audio/pickup.wav"), -23.0, 0.13],
	"victory": [preload("res://assets/audio/victory.wav"), -10.0, 0.0],
	"defeat": [preload("res://assets/audio/defeat.wav"), -10.0, 0.0],
	"boss_warning": [preload("res://assets/audio/boss_warning.wav"), -12.0, 1.2],
	"boss_break": [preload("res://assets/audio/boss_break.wav"), -9.0, 0.8],
	"navigation": [preload("res://assets/audio/navigation.wav"), -22.0, 0.08],
	"equip": [preload("res://assets/audio/equip.wav"), -16.0, 0.11],
	"reward": [preload("res://assets/audio/reward.wav"), -15.0, 0.18],
	"crate": [preload("res://assets/audio/crate.wav"), -12.0, 0.25],
}
const VARIED_EVENTS := ["shot", "hit", "kill", "pickup", "drone"]
const VARIATION := [1.0, 0.97, 1.04, 1.01, 0.94, 1.07]

var _players: Dictionary[String, AudioStreamPlayer] = {}
var _last_played: Dictionary[String, float] = {}
var _music_players: Array[AudioStreamPlayer] = []
var _music_current := Vector2.ZERO
var _music_target := Vector2.ZERO
var _music_tween: Tween
var _requested_scene := "menu"
var _track := 0
var _master := 0.90
var _music := 0.65
var _effects := 0.80
var _variation_index := 0
var _has_audio_output := false


func _ready() -> void:
	# Movie Maker mixes into its recording even though it uses the Dummy driver.
	_has_audio_output = AudioServer.get_driver_name() != "Dummy" or "--write-movie" in OS.get_cmdline_args()
	if not _has_audio_output:
		return
	for cue in SCORE:
		var player := AudioStreamPlayer.new()
		var stream := cue.duplicate() as AudioStreamOggVorbis
		stream.loop = true
		player.stream = stream
		player.volume_db = SILENT_DB
		add_child(player)
		_music_players.append(player)
	set_scene(_requested_scene)


func set_mix(master: float, music: float, effects: float) -> void:
	_master = clampf(master, 0.0, 1.0)
	_music = clampf(music, 0.0, 1.0)
	_effects = clampf(effects, 0.0, 1.0)
	_apply_music_gain(_music_current)
	for event in _players:
		var base := float(EFFECTS[event][1])
		_players[event].volume_db = _volume_db(base, _master * _effects)


func set_scene(scene: String) -> void:
	_requested_scene = scene
	var strength := 1.0
	match scene:
		"combat":
			_track = 1
		"pause":
			_track = 1
			strength = 0.31
		"upgrade":
			_track = 1
			strength = 0.47
		"result":
			_track = 1
			strength = 0.17
		"settings":
			strength = 0.45
		_:
			_track = 0

	var target := Vector2(strength, 0.0) if _track == 0 else Vector2(0.0, strength)
	if _music_players.is_empty() or target.is_equal_approx(_music_target):
		return
	_music_target = target
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if not _music_players[_track].playing:
		_music_players[_track].volume_db = SILENT_DB
		_music_players[_track].play()
	_music_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_tween.tween_method(_apply_music_gain, _music_current, _music_target, MUSIC_FADE_SECONDS)
	_music_tween.tween_callback(_music_players[1 - _track].stop)


func play_event(event: String) -> void:
	if not _has_audio_output or _master <= 0.0 or _effects <= 0.0 or not EFFECTS.has(event):
		return
	var spec: Array = EFFECTS[event]
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_played.get(event, -1.0) < float(spec[2]):
		return
	if not _players.has(event):
		var player := AudioStreamPlayer.new()
		player.stream = spec[0]
		player.volume_db = _volume_db(float(spec[1]), _master * _effects)
		player.max_polyphony = 2 if event in ["pickup", "kill"] else 1
		add_child(player)
		_players[event] = player
	_last_played[event] = now
	var active := _players[event]
	if event in VARIED_EVENTS:
		active.pitch_scale = VARIATION[_variation_index % VARIATION.size()]
		_variation_index += 1
	active.play()


func _apply_music_gain(gains: Vector2) -> void:
	_music_current = gains
	for index in _music_players.size():
		_music_players[index].volume_db = _volume_db(MUSIC_LEVEL_DB, gains[index] * _master * _music)


func _volume_db(base: float, multiplier: float) -> float:
	return SILENT_DB if multiplier <= 0.0001 else maxf(SILENT_DB, base + linear_to_db(multiplier))
