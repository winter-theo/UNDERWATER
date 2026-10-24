extends Node

@export_file("*.tscn") var main_menu_scene: String
@export var acts: Array[Act] = []

@onready var _loader: SceneLoader = $SceneLoader

var _act_index := 0
var _step_index := 0


func _ready() -> void:
	new_game.call_deferred()


func new_game() -> void:
	_act_index = 0
	_step_index = 0
	_load_step()


func _load_step() -> void:
	var path: String = acts[_act_index].get_scenes()[_step_index]
	var packed := await _loader.load_scene(path)
	if packed == null:
		return
	
	var step := packed.instantiate()
	step.connect(&"finished", _on_step_finished, CONNECT_ONE_SHOT)
	get_tree().change_scene_to_node(step)


func _on_step_finished() -> void:
	_step_index += 1

	if _step_index >= acts[_act_index].get_scenes().size():
		_act_index += 1
		_step_index = 0
	
	_load_step()
