extends SceneTree
## Zones jaunes des missions : chaque objectif dehors est hors des batiments, au sol, sans objet dessus, et reste libre
## quand le joueur s'approche et que le decor de sa tuile est charge (retour d'Olympe du 21/10/2026).
## Lancement : godot --headless --path godot --script res://tests/test_zones_missions.gd

var frame := 0
var scene: Node
var histoire: Node
var fails := 0
var cles: Array = []
var i := 0
var t0 := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 40:
		root.get_node("Partie").nouvelle_partie()
		histoire = scene.get_node("Histoire")
		scene.get_node("Lieux")._spawn_home()
		histoire.commencer()
	if frame < 200:
		return false
	if cles.is_empty():
		for k in histoire.POINTS_VERIFIES:
			if histoire.points.has(k):
				cles.append(k)
		_check(cles.size() >= 8, "objectifs a verifier : %d" % cles.size())
		t0 = frame
		return false
	if i >= cles.size():
		print("RESULTAT test_zones_missions : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	var k: String = cles[i]
	var p: Vector3 = histoire.points[k]
	if frame == t0 + 1:
		var c := Carte.zone()
		_check(not c.in_building(Vector2(p.x, p.z)), "%s : hors des batiments (%.0f, %.0f)" % [k, p.x, p.z])
		# le joueur s'approche : le decor de la tuile se charge
		(scene.get_node("Player") as Node3D).global_position = p + Vector3(12, 1.0, 0)
		scene.get_node("Player").reset_physics_interpolation()
	if frame == t0 + 240:
		var p2: Vector3 = histoire._degager(p)
		_check(histoire._libre(p) or p2.distance_to(p) < 0.4, "%s : libre quand le decor est charge (%.1f m de recalage)" % [k, p2.distance_to(p)])
		i += 1
		t0 = frame
	return false
