extends SceneTree
## Portails battants : le battant s'ouvre en s'ecartant de celui qui arrive, qu'il soit dehors ou dedans.

var frame := 0
var scene: Node
var fails := 0
var porte := {}
var n3 := Vector3.ZERO
var etape := 0
var t0 := 0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _bout(d: Dictionary) -> Vector3:
	## centre du vantail, dans le repere du monde
	var body: Node3D = d["body"]
	var leaf := body.get_child(0) as MeshInstance3D
	return leaf.global_transform * leaf.mesh.get_aabb().get_center()


func _place(player: Node3D, p: Vector3) -> void:
	player.global_position = p
	player.reset_physics_interpolation()
	t0 = frame


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 200:
		return false
	var lieux := scene.get_node("Lieux")
	var player := scene.get_node("Player") as Node3D
	if porte.is_empty():
		for d in lieux.doors:
			if not d["sliding"] and String((d["body"] as Node).get_parent().name).contains("portail"):
				porte = d
				break
		_check(not porte.is_empty(), "un portail battant existe")
		if porte.is_empty():
			quit(1)
			return true
		n3 = ((porte["body"] as Node).get_parent() as Node3D).global_transform.basis.z
		_place(player, (porte["pos"] as Vector3) + n3 * 2.5 + Vector3(0, 0.2, 0))
		return false
	var centre: Vector3 = porte["pos"]
	var t := frame - t0
	match etape:
		0, 2:
			if t == 150:
				var cote := 1.0 if etape == 0 else -1.0
				var ecart := (_bout(porte) - centre).dot(n3)
				_check(float(porte["open"]) > 0.9, "portail ouvert cote %+.0f" % cote)
				_check(ecart * cote < 0.0, "le battant s'ecarte de la personne (decalage %+.2f m, cote %+.0f)" % [ecart, cote])
				etape += 1
				_place(player, centre + Vector3(0, 0.2, 60))
		1:
			if t == 200:
				_check(float(porte["open"]) < 0.05, "le portail se referme quand on s'eloigne")
				etape = 2
				_place(player, centre - n3 * 2.5 + Vector3(0, 0.2, 0))
		3:
			print("RESULTAT test_portail_sens : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
			quit(1 if fails else 0)
			return true
	return false
