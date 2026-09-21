extends Node3D

const VEHICLE_SCENE := preload("res://vehicle/vehicle.tscn")

@onready var _spawn: Marker3D = $SpawnPoint

var _vehicle: Vehicle


func _ready() -> void:
	_respawn()


func _respawn() -> void:
	if is_instance_valid(_vehicle):
		_vehicle.queue_free()
	_vehicle = VEHICLE_SCENE.instantiate()
	add_child(_vehicle)
	_vehicle.global_position = _spawn.global_position
	_vehicle.global_basis = _spawn.global_basis


func _unhandled_input(event: InputEvent) -> void:
	# has_action() evite de spammer le debogueur tant que l'action n'est pas
	# encore dans project.godot.
	if InputMap.has_action(&"reset") and event.is_action_pressed(&"reset"):
		_respawn()
