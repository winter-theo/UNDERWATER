extends Node3D

const VEHICLE_SCENE := preload("res://vehicle/vehicle.tscn")

@onready var _spawn: Marker3D = $SpawnPoint
@onready var _readout: Label = $HUD/Readout

var _vehicle: Vehicle

# Mesure de saut
var _airborne := false
var _air_time := 0.0
var _launch := Vector3.ZERO
var _peak := 0.0
var _last_jump := ""
var _best_dist := 0.0


func _ready() -> void:
	_respawn()


func _respawn() -> void:
	if is_instance_valid(_vehicle):
		_vehicle.queue_free()
	_vehicle = VEHICLE_SCENE.instantiate()
	add_child(_vehicle)
	_vehicle.global_position = _spawn.global_position
	_vehicle.global_basis = _spawn.global_basis
	_airborne = false
	_air_time = 0.0


func _unhandled_input(event: InputEvent) -> void:
	# has_action() evite de spammer le debogueur tant que l'action n'est pas
	# encore dans project.godot.
	if InputMap.has_action(&"reset") and event.is_action_pressed(&"reset"):
		_respawn()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_vehicle):
		return
	_measure_jump(delta)
	_draw_hud()


## Chronometre chaque passage en l'air. C'est l'outil qui te permet de tuner
## les rampes en 2 minutes au lieu de 20 : tu lis la portee reelle, tu ajustes.
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


func _draw_hud() -> void:
	var speed: float = _vehicle.engine.speed
	var etat := "AIR  %.2f s" % _air_time if _airborne else "sol"

	_readout.text = "\n".join([
		"vitesse   %6.1f m/s   (%.0f km/h)" % [speed, speed * 3.6],
		"etat      %s" % etat,
		"altitude  %6.1f m" % _vehicle.global_position.y,
		"",
		"dernier saut   %s" % (_last_jump if _last_jump != "" else "-"),
		"record         %s" % ("%.1f m" % _best_dist if _best_dist > 0.0 else "-"),
		"",
		"[R] reset",
	])
