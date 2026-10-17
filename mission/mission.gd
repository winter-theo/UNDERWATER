extends Node3D
class_name Mission

signal finished

func finish() -> void:
	finished.emit()
