extends SceneTree
func _init() -> void:
	for m in ["veh_berline", "veh_pickup", "veh_camion", "veh_zem"]:
		var s := load("res://assets/models/%s.glb" % m) as PackedScene
		var n := s.instantiate()
		var noms := {}
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			for i in (mi as MeshInstance3D).mesh.get_surface_count():
				var mat := (mi as MeshInstance3D).mesh.surface_get_material(i)
				noms[mat.resource_name if mat else "?"] = true
		print(m, " : ", noms.keys())
		n.free()
	quit()
