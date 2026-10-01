extends Node3D
class_name Cutscene


@export var lines: Array[DialogueLine] = []
@export var speaker_cameras: Dictionary[String, Camera3D]

@onready var _dialogue_box: DialogueBox = $DialogueBox


func _ready() -> void:
	_dialogue_box.line_started.connect(_on_line_started)
	_dialogue_box.start(lines)
	await _dialogue_box.finished
	# TODO : fin de la cinematique (scene suivante, retour au jeu...).


func _on_line_started(line: DialogueLine) -> void:
	if line.speaker in speaker_cameras:
		speaker_cameras[line.speaker].make_current()
