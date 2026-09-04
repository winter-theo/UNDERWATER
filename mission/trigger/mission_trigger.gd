extends Area3D

@onready var _mission: Mission = get_parent()

func _on_body_entered(body) -> void:
	if body is Vehicle:
		_mission.finish()
