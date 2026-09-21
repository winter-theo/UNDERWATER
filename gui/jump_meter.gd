extends CanvasLayer

## Outil de tuning (dev) : chronometre chaque passage en l'air du joueur et
## affiche portee / duree / apex, plus le record de la session.
##
## C'est l'outil qui permet de regler les rampes en 2 minutes au lieu de 20 : tu
## lis la portee reelle, tu ajustes. Il n'a rien a faire dans le jeu final, donc
## il reste separe du HUD de jeu : c'est un noeud autonome qu'on depose dans une
## scene de test (voir dev_room.tscn) et qu'on retire ensuite.
##
## Comme le HUD, il trouve le joueur tout seul via le groupe "player" : aucun
## cablage cote scene, on le pose et il marche.

@onready var _readout: Label = $Readout

var _vehicle: Vehicle

# Etat de la mesure en cours.
var _airborne := false
var _air_time := 0.0
var _launch := Vector3.ZERO
var _peak := 0.0

# Resultats affiches, conserves entre les respawns.
var _last_jump := ""
var _best_dist := 0.0


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_vehicle):
		_vehicle = get_tree().get_first_node_in_group(&"player") as Vehicle
		# Nouveau vehicule (spawn / respawn) : on repart d'une mesure vierge,
		# mais on garde le record de la session.
		_airborne = false

	if not is_instance_valid(_vehicle):
		_readout.text = ""
		return

	_measure_jump(delta)
	_refresh()


## Detecte chaque decollage/atterrissage et en tire la portee au sol.
func _measure_jump(delta: float) -> void:
	var pos := _vehicle.global_position

	if not _vehicle.is_on_floor():
		if not _airborne:
			_airborne = true
			_air_time = 0.0
			_launch = pos
			_peak = pos.y
		_air_time += delta
		_peak = maxf(_peak, pos.y)
		return

	if _airborne:
		_airborne = false
		# Les sauts de moins de 0.15 s sont juste du bruit sur les bosses.
		if _air_time < 0.15:
			return
		var flat := Vector2(pos.x - _launch.x, pos.z - _launch.z).length()
		_best_dist = maxf(_best_dist, flat)
		_last_jump = "%.1f m  /  %.2f s  /  apex %.1f m" % [flat, _air_time, _peak - _launch.y]


func _refresh() -> void:
	_readout.text = "\n".join([
		"dernier saut   %s" % (_last_jump if _last_jump != "" else "-"),
		"record         %s" % ("%.1f m" % _best_dist if _best_dist > 0.0 else "-"),
	])
