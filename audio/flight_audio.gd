extends Node

const EFFECTS := {
	"shot": [preload("res://assets/audio/shot.wav"), -22.0, 0.05],
	"missile": [preload("res://assets/audio/missile.wav"), -18.0, 0.10],
	"nova": [preload("res://assets/audio/nova.wav"), -14.0, 0.20],
	"laser": [preload("res://assets/audio/laser.wav"), -17.0, 0.37],
	"tesla": [preload("res://assets/audio/tesla.wav"), -17.0, 0.25],
	"drone": [preload("res://assets/audio/drone.wav"), -24.0, 0.18],
	"kill": [preload("res://assets/audio/kill.wav"), -18.0, 0.12],
	"hurt": [preload("res://assets/audio/hurt.wav"), -12.0, 0.25],
	"upgrade": [preload("res://assets/audio/upgrade.wav"), -12.0, 0.20],
	"pickup": [preload("res://assets/audio/pickup.wav"), -20.0, 0.09],
	"victory": [preload("res://assets/audio/victory.wav"), -12.0, 0.0],
	"defeat": [preload("res://assets/audio/defeat.wav"), -12.0, 0.0],
}

var _players: Dictionary[String, AudioStreamPlayer] = {}
var _last_played: Dictionary[String, float] = {}
var _has_audio_output: bool


func _ready() -> void:
	_has_audio_output = AudioServer.get_driver_name() != "Dummy"


func play_event(event: String) -> void:
	if not _has_audio_output or not EFFECTS.has(event):
		return
	var spec: Array = EFFECTS[event]
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_played.get(event, -1.0) < float(spec[2]):
		return
	if not _players.has(event):
		var player := AudioStreamPlayer.new()
		player.stream = spec[0]
		player.volume_db = spec[1]
		player.max_polyphony = 2
		add_child(player)
		_players[event] = player
	_last_played[event] = now
	_players[event].play()
