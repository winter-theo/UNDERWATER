@tool
extends CollisionShape3D

## Ajuste la boite de collision sur le mesh, directement dans l'editeur.
##
## Utilisation :
##   1. Attache ce script au CollisionShape3D de vehicle.tscn
##   2. Coche "Ajuster" dans l'inspecteur
##   3. Verifie le resultat, sauvegarde
##   4. Tu peux ensuite retirer le script, la forme reste dans la scene

## Le MeshInstance3D a epouser.
@export var mesh_node: NodePath = ^"../Body"

## Retrait par axe. Un collider legerement plus petit que le mesh evite
## d'accrocher les aretes des rampes avec les retroviseurs et le guidon.
@export var shrink := Vector3(0.75, 0.95, 0.95)

@export var ajuster := false:
	set(value):
		ajuster = false
		if value:
			_fit()


func _fit() -> void:
	var mi := get_node_or_null(mesh_node) as MeshInstance3D
	if mi == null or mi.mesh == null:
		push_error("fit_collision : pas de MeshInstance3D valide a %s" % mesh_node)
		return

	# AABB local du mesh, ramene dans l'espace du CharacterBody3D.
	# Il faut passer par la transform du MeshInstance parce que ton node Body
	# a une rotation de -90 degres en Y : sans ca, longueur et largeur
	# se retrouvent inversees.
	var bounds: AABB = mi.transform * mi.mesh.get_aabb()

	var box := BoxShape3D.new()
	box.size = bounds.size * shrink
	shape = box

	# On remet la rotation a zero : la boite est deja alignee sur les axes.
	transform = Transform3D(Basis(), bounds.get_center())

	print("fit_collision -> size %.2v  centre %.2v" % [box.size, bounds.get_center()])
	print("  bas du collider a y = %.2f" % (bounds.get_center().y - box.size.y * 0.5))
