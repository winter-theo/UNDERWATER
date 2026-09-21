extends CanvasLayer

## Affichage tete haute du joueur.
##
## A instancier dans les scenes de conduite (map, dev_room...) -- et nulle part
## ailleurs : le menu principal, la fin de mission ou les dialogues auront leur
## propre UI, differente. Ce n'est donc PAS un autoload : le HUD n'existe que la
## ou il a un sens.
##
## Une fois pose dans une scene, il ne demande aucun cablage : il va chercher le
## vehicule du joueur tout seul via le groupe "player", dans lequel le vehicule
## s'inscrit quand il est pilote par un PlayerController (voir vehicle.gd). Un
## vehicule PNJ n'entre pas dans ce groupe, donc pas de HUD pour lui. Apres un
## respawn, l'ancien vehicule devient invalide et on re-acquiert le nouveau.
##
## S'il n'y a pas encore de joueur (frame de spawn, respawn), le HUD se masque.

@onready var _readout: Label = $Readout

var _vehicle: Vehicle


func _process(_delta: float) -> void:
	if not is_instance_valid(_vehicle):
		_vehicle = get_tree().get_first_node_in_group(&"player") as Vehicle

	visible = is_instance_valid(_vehicle)
	if visible:
		_readout.text = _format(_vehicle)


## Toute la mise en forme de la telemetrie vit ici, et nulle part ailleurs.
func _format(vehicle: Vehicle) -> String:
	var speed: float = vehicle.engine.drive_speed
	var pos := vehicle.global_position

	return "\n".join([
		"vitesse   %6.1f m/s   (%.0f km/h)" % [speed, speed * 3.6],
		"etat      %s" % ("sol" if vehicle.is_on_floor() else "AIR"),
		"position  %.0f, %.0f, %.0f" % [pos.x, pos.y, pos.z],
		"",
		"[R] reset",
	])
