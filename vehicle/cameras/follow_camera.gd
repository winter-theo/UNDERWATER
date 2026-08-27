extends Camera3D

## Distance horizontale derriere le vehicule.
@export var distance := 8.0

## Hauteur au-dessus du vehicule.
@export var height := 3.0

## Point vise devant le vehicule. Plus c'est haut, plus tu vois loin en virage.
@export var look_ahead := 4.0

## Hauteur du point vise, pour ne pas regarder dans le plancher.
@export var look_height := 1.0

## Rattrapage de la position. Bas = camera molle et cinematique.
@export var follow_speed := 6.0

## Rattrapage de la visee. Garde-le plus haut que follow_speed.
@export var aim_speed := 10.0

## Distance maximale toleree derriere le vehicule, en multiples de `distance`.
## C'est un plafond dur : peu importe la vitesse, la camera ne traine jamais
## plus loin que ca. Sans cette borne, le lissage laisse un retard
## proportionnel a la vitesse (environ vitesse / follow_speed metres).
@export var max_lag := 1.4

## FOV de repos. 70 cadre bien ; au-dela de 80 tout parait lointain.
@export var fov_base := 70.0

## Ouverture supplementaire a vitesse max, en degres. Garde-le sous 10.
@export var fov_speed_boost := 8.0

var _pivot: Node3D
var _vehicle: Vehicle
var _aim := Vector3.ZERO
var _base_fov := 75.0


func _ready() -> void:
	# NOTE: capture ici et pas a la declaration de la variable. Un initialiseur
	# de membre s'execute avant que la scene applique ses proprietes, donc
	# _base_fov prenait la valeur par defaut du moteur, pas celle de la scene.
	_base_fov = fov_base
	fov = fov_base
	_pivot = get_parent() as Node3D
	_vehicle = _pivot.get_parent() as Vehicle
	top_level = true
	_snap()


## Replace la camera instantanement. Utilise au spawn et apres un respawn.
func _snap() -> void:
	if _pivot == null:
		return
	global_position = _desired_position()
	_aim = _look_target()
	_aim_at(_aim)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_pivot):
		return

	var goal := _desired_position()

	# Respawn ou teleport : on colle direct au lieu de traverser la map.
	if global_position.distance_to(goal) > distance * 4.0:
		_snap()
		return

	global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	_clamp_lag()
	_aim = _aim.lerp(_look_target(), 1.0 - exp(-aim_speed * delta))
	_aim_at(_aim)

	if _vehicle != null and _vehicle.engine != null:
		var ratio := clampf(absf(_vehicle.engine.speed) / maxf(_vehicle.engine.max_speed, 0.001), 0.0, 1.0)
		fov = lerpf(fov, _base_fov + ratio * fov_speed_boost, 1.0 - exp(-4.0 * delta))


## Ramene la camera si le lissage l'a laissee decrocher.
func _clamp_lag() -> void:
	var offset := global_position - _pivot.global_position
	var flat := Vector2(offset.x, offset.z)
	var limit := distance * max_lag
	if flat.length() <= limit:
		return
	flat = flat.normalized() * limit
	global_position = _pivot.global_position + Vector3(flat.x, offset.y, flat.y)


## Cap du vehicule, aplati sur le plan horizontal.
## L'aplatissement empeche la camera de plonger dans le sol quand le
## vehicule pitche sur une rampe.
func _flat_forward() -> Vector3:
	var f := -_pivot.global_basis.z
	f.y = 0.0

	# Vehicule quasi vertical (nez en l'air sur une rampe raide) :
	# son axe Y projete pointe alors dans la direction de marche.
	if f.length_squared() < 0.0001:
		f = _pivot.global_basis.y
		f.y = 0.0

	if f.length_squared() < 0.0001:
		return Vector3.FORWARD

	return f.normalized()


func _desired_position() -> Vector3:
	return _pivot.global_position - _flat_forward() * distance + Vector3.UP * height


func _look_target() -> Vector3:
	return _pivot.global_position + _flat_forward() * look_ahead + Vector3.UP * look_height


## look_at() plante si la direction de visee est parallele a Vector3.UP.
## On vise toujours un point devant le vehicule, donc ca ne devrait jamais
## arriver, mais le garde-fou coute une ligne.
func _aim_at(point: Vector3) -> void:
	var dir := point - global_position
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return
	look_at(point, Vector3.UP)
