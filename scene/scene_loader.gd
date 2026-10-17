class_name SceneLoader
extends Node

signal progress_changed(ratio: float)


func load_scene(path: String) -> PackedScene:
	ResourceLoader.load_threaded_request(path)

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(path, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		progress_changed.emit(progress[0])
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path, progress)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("SceneLoader : échec du chargement de %s" % path)
		return null
	
	return ResourceLoader.load_threaded_get(path)
