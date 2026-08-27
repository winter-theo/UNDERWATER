class_name VehicleAudio
extends Node3D

## Son moteur a deux couches. Un seul echantillon etire sur toute la plage de
## vitesse sonne comme un jouet : a bas regime il devient un bourdon, a haut
## regime il siffle. Deux boucles enregistrees a des regimes differents,
## melangees selon la vitesse, evitent ca. Chaque couche n'est etiree que de
## plus ou moins 25 %, ce qui reste dans la zone ou le pitch-shift ne
## s'entend pas.

@export var low_loop: AudioStream
@export var high_loop: AudioStream

@export_group("Regime")
## Pitch de la couche basse a l'arret et a mi-regime.
@export var low_pitch_min := 0.70
@export var low_pitch_max := 1.30
## Pitch de la couche haute a mi-regime et a fond.
@export var high_pitch_min := 0.78
@export var high_pitch_max := 1.28

@export_group("Melange")
## Debut et fin du fondu entre les deux couches, en fraction de vitesse max.
@export var blend_start := 0.30
@export var blend_end := 0.70

@export_group("Niveaux")
@export var volume_db := -6.0
## Attenuation quand tu laches les gaz. Le moteur ne se tait pas, il se retient.
@export var coast_db := -7.0
## Portee du son. Grand = peu d'attenuation avec la distance camera.
@export var unit_size := 14.0

@export_group("Reactivite")
## Lissage du regime. Bas = le moteur met du temps a repondre.
@export var rev_speed := 5.0
## Regime pris en l'air, roues libres. 0 pour desactiver.
@export var air_rev := 0.25

var _low: AudioStreamPlayer3D
var _high: AudioStreamPlayer3D
var _vehicle: Vehicle
var _rev := 0.0


func _ready() -> void:
	_vehicle = get_parent() as Vehicle
	if _vehicle == null:
		push_error("VehicleAudio doit etre enfant d'un Vehicle")
		set_physics_process(false)
		return

	_low = _make_player(low_loop)
	_high = _make_player(high_loop)


func _make_player(stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = unit_size
	p.max_db = 0.0
	p.volume_db = -80.0
	add_child(p)
	if stream != null:
		# Les .ogg ont besoin qu'on active la boucle explicitement, sinon
		# le son joue une fois et s'arrete.
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		p.play()
	return p


func _physics_process(delta: float) -> void:
	if _vehicle == null or _vehicle.engine == null:
		return

	var target := clampf(absf(_vehicle.engine.speed) / maxf(_vehicle.engine.max_speed, 0.001), 0.0, 1.0)

	# En l'air les roues ne freinent plus rien : le moteur s'emballe.
	if air_rev > 0.0 and not _vehicle.is_on_floor():
		target = minf(target + air_rev, 1.0)

	_rev = lerpf(_rev, target, 1.0 - exp(-rev_speed * delta))

	var mix := smoothstep(blend_start, blend_end, _rev)
	var load_db := lerpf(coast_db, 0.0, absf(_vehicle._controller.throttle_axis))

	_apply(_low, remap(_rev, 0.0, blend_end, low_pitch_min, low_pitch_max), 1.0 - mix, load_db)
	_apply(_high, remap(_rev, blend_start, 1.0, high_pitch_min, high_pitch_max), mix, load_db)


func _apply(player: AudioStreamPlayer3D, pitch: float, gain: float, load_db: float) -> void:
	if player == null or player.stream == null:
		return
	player.pitch_scale = clampf(pitch, 0.4, 2.0)
	# Sous -55 dB c'est inaudible : on coupe pour ne pas melanger deux couches
	# dont l'une n'apporte que de la boue dans le grave.
	player.volume_db = -80.0 if gain < 0.01 else volume_db + load_db + linear_to_db(gain)
