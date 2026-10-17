extends SceneTree
## Limiteur de vitesse (K) : plein gaz, la voiture puis le zem plafonnent a 50 km/h, sous la limite des contraventions ;
## coupe, on repart au-dela. Le compteur du HUD affiche la vitesse et l'etat du limiteur.

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var veh: Node3D
var vmax := 0.0


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _monter(id: String) -> void:
	## Sur la piste de l'aeroport (longue et droite), conducteur = joueur.
	if veh and id != "zem":
		veh.queue_free()
	var rw: Array = Carte.zone().data["runways"][0]
	var a := Vector2(float(rw[1][0]), float(rw[1][1]))
	var b := Vector2(float(rw[2][0]), float(rw[2][1]))
	var dir := (b - a).normalized()
	if id == "zem":
		if veh:
			veh.call("set_rider", false)
		veh = scene.get_node("Zem")
		veh.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(a.x, 0.3, a.y) + Vector3(dir.x, 0, dir.y) * 30.0)
		veh.set("has_rider", true)
	else:
		veh = Vehicules.create(id, Color(0.2, 0.3, 0.7))
		veh.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(a.x, 0.3, a.y))
		scene.add_child(veh)
		veh.call("set_rider", true)
	player.set("vehicle", veh)
	vmax = 0.0


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		root.get_node("Partie").nouvelle_partie()
		scene.get_node("Police").set("arrestation", false)
		Limiteur.actif = false
		player.global_position = Vector3(0, -50, 0)
		player.set_physics_process(false)
		_monter("veh_berline")
	if frame == 40:
		Input.action_press("limiteur")
	if frame == 42:
		Input.action_release("limiteur")
		_check(Limiteur.actif, "K active le limiteur")
		Input.action_press("accelerate")
	if frame > 42:
		vmax = maxf(vmax, absf(float(veh.get("speed"))) * 3.6)
	if frame == 42 + 60 * 14:
		_check(vmax < 53.0 and vmax > 45.0, "voiture plein gaz : plafonnee a 50 km/h (%.0f)" % vmax)
		var hud := scene.get_node("HUDJeu")
		var cpt: Label = hud.get("_compteur")
		_check(cpt.visible and "LIMITEUR" in cpt.text, "compteur : %s" % cpt.text.replace("\n", " / "))
		Limiteur.actif = false
		vmax = 0.0
	if frame == 42 + 60 * 22:
		_check(vmax > 60.0, "limiteur coupe : on repart au-dela (%.0f km/h)" % vmax)
		Input.action_release("accelerate")
		Limiteur.actif = true
		_monter("zem")
	if frame == 42 + 60 * 22 + 5:
		Input.action_press("accelerate")
	if frame == 42 + 60 * 34:
		_check(vmax < 53.0 and vmax > 40.0, "zem plein gaz : plafonne a 50 km/h (%.0f)" % vmax)
		Input.action_release("accelerate")
		print("RESULTAT test_limiteur : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
