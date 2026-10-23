extends SceneTree
## Marche arriere (retour d'Olympe : les vehicules derapaient en reculant) : en reculant avec le volant braque,
## la derive de la caisse reste faible et la voiture se controle (vitesse de recul bornee, trajectoire en arc).

var frame := 0
var scene: Node
var car: Node3D
var fails := 0
var derive_max := 0.0
var recul_max := 0.0
var cap0 := 0.0


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	var rw: Array = Carte.zone().data["runways"][0]
	var a := Vector2(float(rw[1][0]), float(rw[1][1]))
	var b := Vector2(float(rw[2][0]), float(rw[2][1]))
	var dir := (b - a).normalized()
	if frame == 60:
		var cote := a + Vector2(-dir.y, dir.x) * 40.0
		scene.get_node("Player").global_position = Vector3(cote.x, 1.0, cote.y)
		scene.get_node("Player").set_physics_process(false)
	if frame == 400:
		car = Vehicules.create("veh_berline", Color(0.7, 0.7, 0.7))
		var mid := a + dir * 300.0
		car.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(mid.x, 0.3, mid.y))
		scene.add_child(car)
		car.call("set_rider", true)
	if car == null or frame < 460:
		return false
	var t := frame - 460
	if t == 0:
		cap0 = car.rotation.y
		Input.action_press("brake")
		Input.action_press("move_left")
	if t > 0 and t < 300:
		derive_max = maxf(derive_max, absf(float(car.get("derive"))))
		recul_max = maxf(recul_max, -float(car.get("speed")))
	if t == 300:
		Input.action_release("brake")
		Input.action_release("move_left")
		var rot := absf(angle_difference(cap0, car.rotation.y))
		_check(recul_max > 2.0, "la voiture recule (%.1f m/s au plus)" % recul_max)
		_check(recul_max <= 6.5, "recul borne (%.1f m/s)" % recul_max)
		_check(derive_max < 0.12, "derive faible en reculant (%.3f rad au plus)" % derive_max)
		_check(rot > 0.3, "le volant braque fait tourner la voiture en reculant (%.0f degres)" % rad_to_deg(rot))
		print("RESULTAT test_marche_arriere : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
