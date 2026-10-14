extends SceneTree
## Debug : liste les objets de la zone et le materiau applique ; dit quelle surface est sous un point donne.

var frame := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		var zone := scene.get_node("zone_aeroport")
		for mi in zone.find_children("*", "MeshInstance3D", true, false):
			var m: Material = mi.get_surface_override_material(0)
			var info := "aucun"
			if m is ShaderMaterial:
				info = "%s mode=%s" % [(m as ShaderMaterial).shader.resource_path.get_file(), (m as ShaderMaterial).get_shader_parameter("mode")]
			print("MAT %s -> %s" % [mi.name, info])
		# quelles surfaces visuelles sous le point (300, 120) ? lancer de rayon sur les AABB
		var p := Vector3(300, 0, 120)
		for mi in zone.find_children("*", "MeshInstance3D", true, false):
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			if aabb.has_point(Vector3(p.x, aabb.get_center().y, p.z)):
				print("SOUS LE POINT (AABB) : ", mi.name)
		return true
	return false
