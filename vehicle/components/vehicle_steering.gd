class_name VehicleSteering
extends Node

@export var _max_steering_angle_deg := 30.0
@export var _steering_speed_deg := 190.0
@export var _return_speed_deg := 180.0

@onready var _max_steering_angle := deg_to_rad(_max_steering_angle_deg)
@onready var _steering_speed := deg_to_rad(_steering_speed_deg)
@onready var _return_speed := deg_to_rad(_return_speed_deg)

@onready var _steering_angle := 0.0


func update(delta: float, axis: float) -> void:
	var target := clampf(axis, -1.0, 1.0) * _max_steering_angle
	var rate := _steering_speed if not is_zero_approx(axis) else _return_speed
	_steering_angle = move_toward(_steering_angle, target, rate * delta)


func get_yaw_delta(delta: float, speed: float, max_speed: float) -> float:
	return _steering_angle * (3 * PI) * (speed / max_speed) * delta
