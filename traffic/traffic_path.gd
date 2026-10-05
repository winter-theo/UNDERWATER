@tool
class_name TrafficPath
extends Path3D

## Trajet de vehicules PNJ. Dessine la courbe avec les outils Path3D, les
## vehicules s'affichent aussi dans l'editeur.
## Pas sous Terrain : son echelle x24 s'appliquerait aux vehicules.

const VEHICLE := preload("res://traffic/traffic_vehicle.tscn")

@export_range(1, 20) var vehicle_count := 1:
	set(v):
		vehicle_count = v
		_spawn()

## m/s
@export var speed := 12.0

## Decoche = aller-retour. En boucle, ferme la courbe.
@export var loop := true:
	set(v):
		loop = v
		_spawn()

var _cars: Array[Node3D] = []
var _dist: Array[float] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		curve_changed.connect(_spawn)
	_spawn()


func _physics_process(delta: float) -> void:
	for i in _cars.size():
		_dist[i] += speed * delta
		_cars[i].transform = _transform_at(_dist[i])


func _spawn() -> void:
	if not is_node_ready():
		return # setters appeles au chargement de la scene

	# owner null = nos vehicules, meme apres un rechargement du script
	for c in get_children(true):
		if c.owner == null:
			c.queue_free()
	_cars.clear()
	_dist.clear()

	var length := curve.get_baked_length() if curve else 0.0
	if length == 0.0:
		return

	for i in vehicle_count:
		var car: Node3D = VEHICLE.instantiate()
		_dist.append(length * i / vehicle_count)
		# avant add_child, sinon sync_to_physics le laisse une frame en (0, 0, 0)
		car.transform = _transform_at(_dist[i])
		# interne : invisible dans l'arbre de scene et jamais sauvegarde
		add_child(car, false, INTERNAL_MODE_BACK)
		_cars.append(car)


func _transform_at(dist: float) -> Transform3D:
	var length := curve.get_baked_length()
	var offset := fposmod(dist, length) if loop else pingpong(dist, length)
	var t := curve.sample_baked_with_rotation(offset)
	if not loop and fposmod(dist, 2.0 * length) > length:
		t = t.rotated_local(Vector3.UP, PI) # trajet retour
	return t
