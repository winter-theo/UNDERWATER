class_name Act
extends Resource

@export var title: String

@export_file("*.tscn") var chef_scene_path: String
@export_file("*.tscn") var mission_scene_path: String
@export_file("*.tscn") var client_scene_path: String
@export_file("*.tscn") var reward_scene_path: String


func get_scenes() -> Array[String]:
	return [chef_scene_path, mission_scene_path, client_scene_path, reward_scene_path]
