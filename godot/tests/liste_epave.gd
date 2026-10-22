extends SceneTree
## Liste les maillages et materiaux de l'epave de la plage dans zone_aeroport_reperes.glb.
func _initialize() -> void:
	var n := (load("res://assets/models/zone_aeroport_reperes.glb") as PackedScene).instantiate()
	for g in n.find_children("rep_epave*", "Node3D", true, false):
		print("NOEUD ", g.name, " ", g.get_class(), " enfants ", g.get_child_count())
		for m in g.find_children("*", "MeshInstance3D", true, false):
			var mats := []
			for s in (m as MeshInstance3D).mesh.get_surface_count():
				var mt := (m as MeshInstance3D).mesh.surface_get_material(s)
				mats.append(mt.resource_name if mt else "-")
			print("  ", m.name, " ", mats)
	quit()
