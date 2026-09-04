extends Node3D

## Scene de jeu principale : la vraie map, chargee depuis map_test.glb.
##
## Le GLB sorti de Blender n'a ni materiau ni collision, et son depliage UV est
## trop irregulier pour poser une grille dessus (la densite de texels varie d'un
## facteur 12 selon les faces). Ce script s'occupe des deux au demarrage :
##   - materiau en triplanar monde, donc totalement independant des UV du GLB
##   - collision ConcavePolygonShape3D generee a partir des triangles du mesh
##
## Consequence pratique : tu peux reexporter la map depuis Blender autant de
## fois que tu veux, il n'y a jamais rien a refaire cote Godot.

const VEHICLE_SCENE := preload("res://vehicle/vehicle.tscn")

## Materiau applique a toutes les surfaces de la map, en material_override.
@export var ground_material: Material

## Les rampes du GLB montent a 45.5 deg, soit juste au-dessus du floor_max_angle
## par defaut de CharacterBody3D (45 deg). Sans correction, is_on_floor() lache
## au milieu des rampes : le vehicule passe en mode "en l'air", arrete de
## s'aligner sur le sol et prend gravity_fall en pleine face.
## Mets 0 pour ne rien forcer et gerer la valeur directement dans vehicle.tscn.
@export_range(0.0, 80.0, 0.5) var floor_max_angle_deg := 60.0

## Longueur d'aimantation au sol. Le defaut de Godot (0.1 m) est calibre pour un
## personnage qui marche. A 50 m/s le vehicule avance de 0.83 m par tick, donc
## il decolle a chaque cassure de pente. 0 = ne pas toucher.
@export var floor_snap_length := 0.6

## Hauteur de largage au-dessus du marqueur, en metres monde.
@export var spawn_clearance := 1.5

## Sous cette altitude, on considere que le joueur est tombe de la map.
@export var fall_limit := -40.0

@onready var _terrain: Node3D = $Terrain
@onready var _spawn: Marker3D = $Terrain/SpawnPoint
@onready var _readout: Label = $HUD/Readout

var _vehicle: Vehicle


func _ready() -> void:
	_build_map()
	respawn()


# --- Construction de la map -------------------------------------------------


func _build_map() -> void:
	var body := StaticBody3D.new()
	body.name = "MapCollision"
	add_child(body)

	var meshes := _find_meshes(_terrain)
	if meshes.is_empty():
		push_error("map : aucun MeshInstance3D trouve sous Terrain.")
		return

	var tri_count := 0
	var bounds := AABB()
	var first := true

	for mi in meshes:
		if mi.mesh == null:
			continue

		if ground_material != null:
			mi.material_override = ground_material

		# get_faces() rend les triangles en espace local du mesh. On les
		# repasse en monde nous-memes plutot que de mettre le StaticBody3D a
		# l'echelle : une forme de collision scalee par un parent est une
		# source de bugs classique, et Jolt n'aime pas ca du tout.
		var xform := mi.global_transform
		var local_faces := mi.mesh.get_faces()
		var faces := PackedVector3Array()
		faces.resize(local_faces.size())
		for i in local_faces.size():
			faces[i] = xform * local_faces[i]

		var shape := ConcavePolygonShape3D.new()
		# backface_collision reste a false : le vehicule ne doit pas accrocher
		# la face cachee des rampes s'il passe dessous.
		shape.set_faces(faces)

		var cs := CollisionShape3D.new()
		cs.name = "%s_Shape" % mi.name
		cs.shape = shape
		body.add_child(cs)

		tri_count += faces.size() / 3
		var mesh_aabb := xform * mi.mesh.get_aabb()
		bounds = mesh_aabb if first else bounds.merge(mesh_aabb)
		first = false

	print("map : %d triangles de collision" % tri_count)
	print("map : emprise %.0f x %.0f m, hauteur %.0f m" % [
		bounds.size.x, bounds.size.z, bounds.size.y,
	])


func _find_meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			out.append(child)
		out.append_array(_find_meshes(child))
	return out


# --- Vehicule ---------------------------------------------------------------


func respawn() -> void:
	if is_instance_valid(_vehicle):
		_vehicle.queue_free()

	_vehicle = VEHICLE_SCENE.instantiate()
	add_child(_vehicle)

	_vehicle.global_position = _spawn.global_position + Vector3.UP * spawn_clearance
	# orthonormalized() enleve l'echelle heritee de Terrain. Sans ca le
	# vehicule sortirait a la meme echelle que la map.
	_vehicle.global_basis = _spawn.global_basis.orthonormalized()

	if floor_max_angle_deg > 0.0:
		_vehicle.floor_max_angle = deg_to_rad(floor_max_angle_deg)
	if floor_snap_length > 0.0:
		_vehicle.floor_snap_length = floor_snap_length


func _unhandled_input(event: InputEvent) -> void:
	# has_action() evite de spammer le debogueur tant que l'action n'est pas
	# encore dans project.godot.
	if InputMap.has_action(&"reset") and event.is_action_pressed(&"reset"):
		respawn()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_vehicle):
		return

	# La map n'a pas de garde-corps : sortir par un bord est le mode d'echec
	# le plus probable a 180 km/h.
	if _vehicle.global_position.y < fall_limit:
		respawn()
		return

	_draw_hud()


func _draw_hud() -> void:
	var speed: float = _vehicle.engine.speed
	var pos := _vehicle.global_position

	_readout.text = "\n".join([
		"vitesse   %6.1f m/s   (%.0f km/h)" % [speed, speed * 3.6],
		"etat      %s" % ("sol" if _vehicle.is_on_floor() else "AIR"),
		"position  %.0f, %.0f, %.0f" % [pos.x, pos.y, pos.z],
		"",
		"[R] reset",
	])
