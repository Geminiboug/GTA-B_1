extends SceneTree
## Cote piste : aucune voiture de la circulation, aucun passant ni vendeur ambulant ne se trouve dans la zone reservee ;
## elle existe bien (pistes et aires de stationnement des avions).

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
	Engine.time_scale = 3.0


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 600:
		return false
	var c := Carte.zone()
	var rw: Array = c.data["runways"][0]
	var milieu := (Vector2(float(rw[1][0]), float(rw[1][1])) + Vector2(float(rw[2][0]), float(rw[2][1]))) * 0.5
	_check(c.zone_reservee(milieu), "le milieu de la piste est en zone reservee")
	_check(not c.zone_reservee(Vector2(milieu.x + 3000.0, milieu.y)), "un point lointain ne l'est pas")
	var n_res := 0
	for e in c.edges.size():
		if c.arete_reservee(e):
			n_res += 1
	print("aretes en zone reservee : ", n_res, " sur ", c.edges.size())
	var v := 0
	for a in scene.get_node("Circulation")._agents:
		var p: Vector3 = a["vis_pos"]
		if absf(p.x) < 1e5 and c.zone_reservee(Vector2(p.x, p.z)) and a.get("active", true):
			v += 1
	_check(v == 0, "aucun vehicule civil en zone reservee (%d)" % v)
	var w_in := 0
	for w in scene.get_node("Pietons")._walkers:
		var p: Vector3 = w["pos"]
		if c.zone_reservee(Vector2(p.x, p.z)) and not w.has("chaise"):
			w_in += 1
	_check(w_in == 0, "aucun passant en zone reservee (%d)" % w_in)
	Engine.time_scale = 1.0
	print("RESULTAT test_aeroport_reserve : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
