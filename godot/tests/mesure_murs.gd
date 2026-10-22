extends SceneTree
## Ecart entre le contour des batiments (donnees, ou props.gd pose enseignes et inscriptions) et la vraie face du mur
## (lancer de rayon horizontal vers la facade) : decalage > 0 = la facade est devant le contour, < 0 = derriere (le panneau flotte).
## Lancement : godot --headless --path godot -s res://tests/mesure_murs.gd
var frame := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 150:
		return false
	var carte := Carte.zone()
	var p: Vector3 = scene.get_node("Player").global_position
	var space := (root.get_world_3d() as World3D).direct_space_state
	var offs: Array = []
	var rates := 0
	for b in carte.data["buildings"]:
		if String(b.get("roof", "")) == "abri" or float(b.get("h", 0.0)) < 2.9:
			continue
		var pts: Array = b["pts"]
		var c := Vector2.ZERO
		for q in pts:
			c += Vector2(float(q[0]), float(q[1]))
		c /= pts.size()
		if Vector2(p.x, p.z).distance_to(c) > 250.0:
			continue
		for i in pts.size():
			var a := Vector2(float(pts[i][0]), float(pts[i][1]))
			var e := Vector2(float(pts[(i + 1) % pts.size()][0]), float(pts[(i + 1) % pts.size()][1]))
			if a.distance_to(e) < 3.0:
				continue
			var mid := (a + e) / 2.0
			var n := Vector2(-(e - a).y, (e - a).x).normalized()
			if n.dot(mid - c) < 0.0:
				n = -n
			var from := mid + n * 1.5
			var to := mid - n * 1.5
			var r := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(from.x, 1.3, from.y), Vector3(to.x, 1.3, to.y)))
			if r.is_empty():
				rates += 1
				continue
			var hp := Vector2(r["position"].x, r["position"].z)
			offs.append((hp - mid).dot(n))
			break
	offs.sort()
	var n_o := offs.size()
	if n_o == 0:
		print("RESULTAT mesure_murs : aucun mur touche (%d rates)" % rates)
	else:
		var moy := 0.0
		for o in offs:
			moy += o
		print("RESULTAT mesure_murs : %d batiments, decalage mur/contour moyen %.3f m, min %.3f, median %.3f, max %.3f (%d rayons rates)" % [
			n_o, moy / n_o, offs[0], offs[n_o / 2], offs[n_o - 1], rates])
	quit()
	return true
