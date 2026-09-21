class_name Boost
extends Area3D

## Plateforme de boost facon Mario Kart : le vehicule qui passe dessus gagne un
## surplus de vitesse, maintenu un court instant puis dissipe en douceur.
## Enchainer plusieurs boosts alignes garde le vehicule a la vitesse max boostee.
##
## Comme il n'y a pas encore de modele, seule la collision compte ici : une
## Area3D carree (voir boost.tscn) qui detecte le Vehicle, exactement comme le
## trigger des missions.

## Surplus de vitesse ajoute a la vitesse du vehicule pendant le boost.
@export var boost_speed := 30.0

## Duree (s) pendant laquelle le surplus est maintenu avant de se dissiper.
@export var boost_duration := 1.0


func _on_body_entered(body: Node3D) -> void:
	if body is Vehicle:
		(body as Vehicle).boost(boost_speed, boost_duration)
