class_name Vehicle
extends CharacterBody3D

## Vitesse a laquelle le vehicule s'aligne sur la normale du sol.
## Haut = colle aux rampes tout de suite. Trop haut = saccade sur les aretes.
@export var ground_align_speed := 18.0

## Vitesse a laquelle le vehicule se remet a plat en l'air.
@export var air_align_speed := 3.0

## Fraction du controle de direction conservee en l'air (0 = aucun).
@export var air_steer_factor := 0.35

## Force qui colle le vehicule au sol dans les descentes. Trop haut = pas de saut.
@export var ground_stick := 4.0

## Multiplicateur de gravite pendant la MONTEE d'un saut.
## Bas = tu flottes au sommet, ce qui laisse le temps de viser l'atterrissage.
@export var gravity_rise := 1.8

## Multiplicateur pendant la CHUTE. Plus haut que gravity_rise donne une
## retombee seche. C'est le reglage qui separe un saut arcade d'un saut lunaire.
## La gravite par defaut de Godot (9.8) est realiste, donc molle pour un jeu.
@export var gravity_fall := 2.8

var _controller: VehicleController
var _vertical_speed := 0.0

@onready var steering: VehicleSteering = $Components/VehicleSteering
@onready var engine: VehicleEngine = $Components/VehicleEngine
@onready var audio_engine: EngineAudio = $Audio/AudioEngine # ajouté par bastien

static func create(controller: VehicleController) -> Vehicle:
	var vehicle: Vehicle = preload("res://vehicle/vehicle.tscn").instantiate()
	vehicle._controller = controller
	# Le controller devient enfant du vehicule, donc il est libere avec lui.
	# Sans ca, un PlayerController.new() reste orphelin en memoire pour toujours.
	if controller.get_parent() == null:
		vehicle.add_child(controller)
	return vehicle


func _ready() -> void:
	# Si personne n'a injecte de controller, on en fabrique un.
	# instantiate() direct -> joueur. create() -> PNJ livreurs plus tard.
	if _controller == null:
		_controller = PlayerController.new()
		add_child(_controller)


func _physics_process(delta: float) -> void:
	_controller.poll()
	
	audio_engine.update(             # ajouté par bastien                  
		delta,
		_controller.throttle_axis,
		engine.speed / engine.max_speed
	)

	steering.update(delta, _controller.steer_axis)
	engine.update(delta, _controller.throttle_axis)
	
	var speed_ratio := engine.speed / (engine.max_speed if engine.speed >= 0.0 else engine.max_reverse_speed)
	audio_engine.update(delta, _controller.throttle_axis, speed_ratio)
	
	var grounded := is_on_floor()
	var yaw := steering.get_yaw_delta(delta, engine.speed, engine.max_speed)

	if grounded:
		rotate_y(yaw)
		_align_to(get_floor_normal(), ground_align_speed, delta)
		# Composante verticale du vecteur de conduite. C'est CA qui te lance
		# quand tu quittes la rampe : on la garde a jour tant qu'on est au sol,
		# donc au moment du decollage elle est deja bonne.
		_vertical_speed = -global_basis.z.y * engine.speed
	else:
		rotate_y(yaw * air_steer_factor)
		_align_to(Vector3.UP, air_align_speed, delta)
		var scale := gravity_rise if _vertical_speed > 0.0 else gravity_fall
		_vertical_speed += get_gravity().y * scale * delta

	var drive := -global_basis.z * engine.speed
	velocity = Vector3(drive.x, _vertical_speed, drive.z)

	if grounded and _vertical_speed <= 0.0:
		velocity.y -= ground_stick

	move_and_slide()


## Fait pivoter le vehicule pour que son axe Y suive `up`, en gardant le cap.
func _align_to(up: Vector3, speed: float, delta: float) -> void:
	var forward := -global_basis.z
	# Si on est quasi perpendiculaire, la projection degenere : on ne touche a rien.
	if absf(forward.dot(up)) > 0.99:
		return

	forward = (forward - up * forward.dot(up)).normalized()
	var right := forward.cross(up).normalized()
	var target := Basis(right, up, right.cross(up))

	var weight := 1.0 - exp(-speed * delta)
	global_basis = global_basis.slerp(target, weight).orthonormalized()
