extends Node

## Lecteur de musique de fond, a mettre en autoload.

const TRACK_PATH := "res://vehicle/audio/music/bgm_ambiance.ogg"

@export var volume_db := -12.0
@export var fade_in := 2.0

var _player: AudioStreamPlayer


func _ready() -> void:
	if not ResourceLoader.exists(TRACK_PATH):
		push_error("MusicPlayer : fichier introuvable a %s" % TRACK_PATH)
		print("[Music] ECHEC : aucun fichier a ", TRACK_PATH)
		return

	var track: AudioStream = load(TRACK_PATH)
	if track == null:
		print("[Music] ECHEC : le fichier existe mais ne charge pas")
		return

	if track is AudioStreamOggVorbis:
		track.loop = true

	_player = AudioStreamPlayer.new()
	_player.stream = track
	_player.bus = &"Master"
	# On regle le volume final tout de suite. Si le fondu echoue pour une
	# raison quelconque, le son est quand meme audible.
	_player.volume_db = volume_db
	add_child(_player)
	_player.play()

	if fade_in > 0.0:
		_player.volume_db = -40.0
		create_tween().tween_property(_player, "volume_db", volume_db, fade_in)

	print("[Music] ok : %s, %.1f s, volume %.1f dB" % [TRACK_PATH, track.get_length(), volume_db])


func fade_to(target_db: float, duration := 1.0) -> void:
	if _player != null:
		create_tween().tween_property(_player, "volume_db", target_db, duration)


func stop(duration := 1.0) -> void:
	if _player == null:
		return
	var tw := create_tween()
	tw.tween_property(_player, "volume_db", -80.0, duration)
	tw.tween_callback(_player.stop)
