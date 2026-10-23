extends SceneTree
## Une voiture de la circulation arretee derriere un vehicule en panne le contourne (voie libre) puis reprend sa voie ;
## si la voie voisine est occupee, elle attend sans le percuter.

var frame := 0
var scene: Node
var fails := 0
var traf: Node
var a: Dictionary
var obst: Node3D
var fwd := Vector2.ZERO
var depart := Vector2.ZERO
var lat_max := 0.0
var t_fin := -1
var lat_fin := 99.0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 200:
		return false
	traf = scene.get_node("Circulation")
	var carte := Carte.zone()
	if frame == 200:
		for b in traf._agents:
			b["active"] = false
		var best := -1
		for e in carte.edges.size():
			var ed: Dictionary = carte.edges[e]
			if not ed["oneway"] and float(ed["len"]) > 120.0 and float(ed["width"]) >= 7.0 and ed["kind"] != "track" and (ed["pts"] as PackedVector2Array).size() == 2:
				best = e
				break
		_check(best >= 0, "une rue droite a double sens assez large existe")
		if best < 0:
			quit(1)
			return true
		for b in traf._agents:
			if b["kind"] == "voiture":
				a = b
				break
		a["active"] = true
		traf._set_edge(a, best, carte.edges[best]["a"])
		a["i"] = 0
		a["s"] = 10.0
		var p: Vector2 = traf._lane_point(a)
		a["vis_pos"] = Vector3(p.x, 0.02, p.y)
		var pts: PackedVector2Array = a["pts"]
		var d := (pts[1] - pts[0]).normalized()
		a["vis_yaw"] = atan2(-d.x, -d.y)
		a["speed"] = 0.0
		fwd = d
		depart = p
		obst = Vehicules.create("veh_berline", Color(0.6, 0.1, 0.1))
		var q := p + d * 28.0 + Vector2(-d.y, d.x) * 0.0
		obst.transform = Transform3D(Basis(Vector3.UP, a["vis_yaw"]), Vector3(q.x, 0.3, q.y))
		scene.add_child(obst)
		# le joueur est loin : seul le vehicule de la circulation compte
		scene.get_node("Player").global_position = Vector3(p.x, 1.0, p.y + 90.0)
		return false
	if frame > 200 and frame < 200 + 60 * 40:
		var vp: Vector3 = a["vis_pos"]
		var rel := Vector2(vp.x, vp.z) - depart
		var along := rel.dot(fwd)
		var lat := absf(rel.dot(Vector2(-fwd.y, fwd.x)))
		if t_fin < 0:
			lat_max = maxf(lat_max, lat)
		if frame % 40 == 0:
			print("f%d along %.1f lat %.2f detour %.2f cible %.2f speed %.1f edge %d s %.1f" % [frame, along, rel.dot(Vector2(-fwd.y, fwd.x)), a.get("detour", 0.0), a.get("detour_cible", 0.0), a["speed"], a["edge"], a["s"]])
		if along > 28.0 + 7.0 and t_fin < 0:
			t_fin = frame
		if t_fin > 0 and frame == t_fin + 150:
			lat_fin = lat
		return false
	_check(t_fin > 0, "la voiture a double le vehicule en panne")
	_check(lat_max > 1.5, "decalage lateral pendant le contournement (%.1f m)" % lat_max)
	_check(lat_fin < 1.2, "elle a repris sa voie ensuite (ecart %.1f m)" % lat_fin)
	print("RESULTAT test_contournement : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
