class_name VehicleEngine
extends Node

@export var acceleration := 20.0
@export var deceleration := 30.0
@export var engine_drag := 6.0
@export var max_speed := 100.0
@export var max_reverse_speed := 20.0

## Vitesse a laquelle le bonus de boost se dissipe une fois le maintien termine.
## Haut = retour a la normale sec ; bas = longue trainee de vitesse.
@export var boost_fade := 60.0

@onready var speed := 0.0

## Bonus de vitesse fourni par les boosts, additionne a `speed`.
## Il n'est pas cape par max_speed : c'est CA qui te propulse au-dela de la
## vitesse normale, puis qui se dissipe pour revenir a la normale.
var boost_speed := 0.0

## Temps de maintien restant avant que le bonus commence a se dissiper.
## Chaque boost pris le repousse (voir `boost`), donc enchainer des boosts
## alignes garde le vehicule a la vitesse max boostee, facon Mario Kart.
var _boost_hold := 0.0

## Vitesse reellement transmise au vehicule : moteur + boost.
var drive_speed: float:
	get:
		return speed + boost_speed


func update(delta: float, axis: float) -> void:
	_update_boost(delta)

	if is_zero_approx(axis):
		speed = move_toward(speed, 0.0, engine_drag * delta)
	elif not is_zero_approx(speed) and signf(axis) != signf(speed):
		speed = move_toward(speed, 0.0, deceleration * delta)
	else:
		var target := max_speed if axis > 0.0 else -max_reverse_speed
		speed = move_toward(speed, target, acceleration * delta)


## Applique un boost : `bonus` s'ajoute a la vitesse tout de suite, maintenu
## pendant `duration`. On garde le plus fort des bonus et on repousse le
## maintien, donc passer sur plusieurs boosts alignes te laisse a fond.
func boost(bonus: float, duration: float) -> void:
	boost_speed = maxf(boost_speed, bonus)
	_boost_hold = maxf(_boost_hold, duration)


## Coupe net le boost (ex : impact frontal contre un mur).
func cancel_boost() -> void:
	boost_speed = 0.0
	_boost_hold = 0.0


## Maintient le bonus tant que le timer tourne, puis le dissipe en douceur.
func _update_boost(delta: float) -> void:
	if _boost_hold > 0.0:
		_boost_hold -= delta
	else:
		boost_speed = move_toward(boost_speed, 0.0, boost_fade * delta)
