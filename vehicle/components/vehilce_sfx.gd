# vehicle_sfx.gd (racine de vehicle_sfx.tscn)
extends Node3D

@onready var _impact := $ImpactCollisionSound
@onready var _klaxon := $KlaxonSound

func play_impact(impact_speed: float) -> void:
	_impact.play_impact(impact_speed)

func play_klaxon() -> void:
	_klaxon.play()
