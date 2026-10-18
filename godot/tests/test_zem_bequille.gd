extends SceneTree
## Zem : bequille posee a l'arret sans conducteur, relevee des qu'on roule, reposee quand on descend a l'arret ;
## motos de la circulation bequille relevee ; le passager (client) penche avec la moto.
var frame := 0
var scene: Node
var fails := 0
var zem: Node3D
func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1
func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 40:
		zem = Vehicules.create("zem", Color.WHITE)
		scene.add_child(zem)
		zem.global_position = Vector3(0, 0.3, 0) + scene.get_node("Player").global_position + Vector3(5, 0, 0)
	if frame == 60:
		var bq := zem.find_child("piv_bequille", true, false) as Node3D
		_check(bq != null, "bequille centrale animable dans le modele")
		_check(bq != null and absf(bq.rotation.x) < 0.01, "a l'arret sans conducteur : bequille posee")
		zem.set_rider(true)
		Input.action_press("accelerate")
	if frame == 120:
		Input.action_release("accelerate")
		var bq := zem.find_child("piv_bequille", true, false) as Node3D
		_check(float(zem.get("speed")) > 1.0 and bq.rotation.x < -1.3, "en roulant : bequille relevee (%.2f rad)" % bq.rotation.x)
		# passager rattache a la partie qui s'incline
		var h := scene.get_node("Histoire")
		h.call("_pick_passenger", zem)
		var pas: Node3D = h.get("_passenger")
		_check(pas.get_parent() == zem.get_node("Visual"), "le passager est porte par la partie inclinable de la moto")
		Input.action_press("move_left")
		Input.action_press("accelerate")
	if frame == 200:
		var pas: Node3D = scene.get_node("Histoire").get("_passenger")
		var penche := absf(pas.global_transform.basis.y.angle_to(Vector3.UP))
		_check(penche > 0.05, "en virage, le passager penche avec la moto (%.2f rad)" % penche)
		Input.action_release("move_left")
		Input.action_release("accelerate")
		Input.action_press("brake")
	if frame > 200 and frame < 700 and absf(float(zem.get("speed"))) < 0.3 and zem.has_rider:
		Input.action_release("brake")
		zem.set_rider(false)
	if frame == 760:
		var bq := zem.find_child("piv_bequille", true, false) as Node3D
		_check(absf(bq.rotation.x) < 0.05, "a l'arret, conducteur descendu : bequille reposee (%.2f)" % bq.rotation.x)
		print("RESULTAT test_zem_bequille : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
