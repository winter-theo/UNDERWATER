class_name Vehicle
extends CharacterBody3D

## Vitesse a laquelle le vehicule s'aligne sur la normale du sol.
## Haut = colle aux rampes tout de suite. Trop haut = saccade sur les aretes.
@export var ground_align_speed := 18.0

## Vitesse a laquelle le vehicule se remet a plat en l'air.
@export var air_align_speed := 3.0

## Fraction du controle de direction conservee en l'air (0 = aucun).
@export var air_steer_factor := 0.35

## Inclinaison visuelle max (degres) quand le vehicule tourne a fond.
@export var visual_bank_angle_deg := 20.0

## Sensibilite : multiplie la vitesse de rotation (rad/s) pour obtenir l'angle cible.
@export var visual_bank_factor := 0.3

## Vitesse de lissage de l'inclinaison visuelle.
@export var visual_bank_speed := 6.0

var _controller: VehicleController

@onready var steering: VehicleSteering = $Components/VehicleSteering
@onready var engine: VehicleEngine = $Components/VehicleEngine
@onready var airborne: VehicleAirborne = $Components/VehicleAirborne

@onready var visual_player = $Player
@onready var visual_scooter = $Scooter


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

	steering.update(delta, _controller.steer_axis)
	engine.update(delta, _controller.throttle_axis)

	var yaw := steering.get_yaw_delta(delta, engine.speed, engine.max_speed)
	if is_on_floor():
		_drive_grounded(delta, yaw)
	else:
		_drive_airborne(delta, yaw)
	
	_update_visuals(yaw, delta)
	_resolve_motion()


## Au sol : on suit la pente et on garde la vitesse de decollage a jour.
func _drive_grounded(delta: float, yaw: float) -> void:
	rotate_y(yaw)
	_align_to(get_floor_normal(), ground_align_speed, delta)
	# Composante verticale du vecteur de conduite. C'est CA qui te lance
	# quand tu quittes la rampe : on la garde a jour tant qu'on est au sol,
	# donc au moment du decollage elle est deja bonne.
	airborne.sync_launch(-global_basis.z.y * engine.speed)


## En l'air : direction attenuee, on se remet a plat et la gravite reprend.
func _drive_airborne(delta: float, yaw: float) -> void:
	rotate_y(yaw * air_steer_factor)
	_align_to(Vector3.UP, air_align_speed, delta)
	airborne.apply_gravity(delta, get_gravity().y)


## Compose la velocite finale depuis le cap et la vitesse verticale, puis bouge.
func _resolve_motion() -> void:
	var drive := -global_basis.z * engine.speed
	velocity = Vector3(drive.x, airborne.vertical_speed, drive.z)
	
	if is_on_floor() and airborne.vertical_speed <= 0.0:
		velocity.y -= airborne.ground_stick
	
	_apply_wall_impact()
	move_and_slide()


## Freine le moteur quand on percute un mur de face, proportionnellement a
## l'angle d'incidence : un frottement rasant ne coute presque rien.
func _apply_wall_impact() -> void:
	if not is_on_wall():
		return
	var head_on := -(-global_basis.z).dot(get_wall_normal())
	if head_on > 0.9:
		engine.speed *= 1.0 - head_on


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


## Incline le mesh (pas le corps physique) vers l'interieur du virage.
## yaw est un delta par frame (deja multiplie par delta) : on divise pour
## retrouver une vitesse de rotation stable, sinon l'angle est ridiculement petit.
func _update_visuals(yaw: float, delta: float) -> void:
	var yaw_rate := yaw / delta
	var max_bank := deg_to_rad(visual_bank_angle_deg)
	var target := clampf(-yaw_rate * visual_bank_factor, -max_bank, max_bank)
	var weight := 1.0 - exp(-visual_bank_speed * delta)
	visual_player.rotation.z = lerp_angle(visual_player.rotation.z, target, weight)
	visual_scooter.rotation.z = lerp_angle(visual_scooter.rotation.z, target, weight / 2)
