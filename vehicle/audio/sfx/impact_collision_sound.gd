# Joue le son de collision cartoon.
# Collision1 = son principal, Collision2 = variante plus rare.
extends Node3D

## En dessous de cette force : aucun son (évite les micro-contacts)
@export var min_strength := 0.1
## Probabilité de jouer Collision2 au lieu de Collision1 (0.25 = 1 fois sur 4)
@export_range(0.0, 1.0, 0.05) var alt_chance := 0.25
## Volume du son (constant, style cartoon)
@export var volume_db := 0.0
## Variation de pitch aléatoire (0.05 = ±5 %) pour éviter la répétition
@export var pitch_variation := 0.10
## Délai minimum entre deux sons (en millisecondes)
@export var cooldown_ms := 150

@onready var _main: AudioStreamPlayer3D = $Collision1
@onready var _alt: AudioStreamPlayer3D = $Collision2

var _last_play_time := -100000


func _ready() -> void:
	# Permet à deux chocs rapprochés de se superposer sans se couper
	_main.max_polyphony = 2
	_alt.max_polyphony = 2


func play_impact(strength: float) -> void:
	# Choc trop faible : on ignore
	if strength < min_strength:
		return

	# Anti "mitraillette" : pas deux sons trop rapprochés
	var now := Time.get_ticks_msec()
	if now - _last_play_time < cooldown_ms:
		return
	_last_play_time = now

	# Tirage au sort : la variante ne sort que de temps en temps
	var player := _alt if randf() < alt_chance else _main

	player.volume_db = volume_db
	# Légère variation de hauteur à chaque choc
	player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	player.play()
