extends SceneTree
## Monument aux Amazones : present dans la carte, a l'emplacement de l'esplanade (x 2890, z 109), avec collisions et hauteur.

var frame := 0
var scene: Node
var fails := 0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 120:
		return false
	var a := scene.get_node_or_null("Monuments/Amazone")
	_check(a != null, "le monument aux Amazones existe")
	if a:
		var p: Vector3 = a.global_position
		_check(absf(p.x - 2890.0) < 30.0 and absf(p.z - 109.0) < 30.0, "emplacement de l'esplanade (%.0f, %.0f)" % [p.x, p.z])
		var cols := a.find_children("*", "CollisionShape3D", true, false)
		_check(cols.size() >= 6, "il a des collisions (%d)" % cols.size())
		var haut := 0.0
		for mi in a.find_children("*", "MeshInstance3D", true, false):
			haut = maxf(haut, (mi as MeshInstance3D).global_position.y + (mi as MeshInstance3D).get_aabb().size.y * 0.5)
		_check(haut > 25.0, "statue monumentale (%.0f m)" % haut)
	print("RESULTAT test_amazone : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
