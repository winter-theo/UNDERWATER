extends Node3D

## Position de depart. Ajoute un Marker3D nomme "SpawnPoint" dans world.tscn,
## sinon on retombe sur une valeur par defaut au-dessus du sol.
const FALLBACK_SPAWN := Vector3(0, 2, 0)

var vehicle: Vehicle


func _ready() -> void:
	spawn_vehicle()


func spawn_vehicle() -> void:
	if is_instance_valid(vehicle):
		vehicle.queue_free()

	# create() adopte maintenant le controller comme enfant, donc plus de fuite.
	vehicle = Vehicle.create(PlayerController.new())
	add_child(vehicle)

	var marker := get_node_or_null("SpawnPoint") as Node3D
	if marker != null:
		vehicle.global_transform = marker.global_transform
	else:
		# NOTE: sans ca le vehicule apparait a (0,0,0), donc a moitie enterre
		# dans le plan du sol.
		vehicle.global_position = FALLBACK_SPAWN


func _unhandled_input(event: InputEvent) -> void:
	# has_action() evite de spammer le debogueur tant que l'action n'est pas
	# encore dans project.godot.
	if InputMap.has_action(&"reset") and event.is_action_pressed(&"reset"):
		spawn_vehicle()
