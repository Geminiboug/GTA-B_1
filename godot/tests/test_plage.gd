extends SceneTree
## Plage : le joueur a pied descend l'estran jusque dans l'eau. Ni blocage ni a-coups ni lenteur
## (retour d'Olympe du 17/10/2026 : tout se bloque et sursaute des qu'on arrive sur la plage ; le sable n'avait pas
## de collision, on tombait sur le fond marin des limites du monde).

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var c := Vector3.ZERO
var mer := Vector3(0, 0, 1)
var depart := Vector3.ZERO
var phys := {"ville": 0.0, "plage": 0.0}
var somme := {"ville": [0.0, 0], "plage": [0.0, 0]}
var car: Node3D
var jumps := 0
var last := Vector3.ZERO


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _walk() -> void:
	player.set("_facing", atan2(-mer.x, -mer.z))
	var p := player.global_position
	if last != Vector3.ZERO and p.distance_to(last) > 1.0:
		jumps += 1
	last = p


func _physics_process(_d: float) -> bool:
	frame += 1
	var ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	if frame == 30:
		player = scene.get_node("Player")
		root.get_node("Partie").nouvelle_partie()
		for q in Carte.zone().data["coast"]:
			if absf(float(q[0])) < 40.0:
				c = Vector3(float(q[0]), 0, float(q[1]))
		print("cote ", c)
	# reference : 6 s de marche en ville, loin de la plage
	if frame == 40:
		player.global_position = c - mer * 300.0 + Vector3(0, 1.0, 0)
		player.reset_physics_interpolation()
		Input.action_press("move_forward")
	if frame > 100 and frame < 400:
		phys["ville"] = maxf(phys["ville"], ms)
		somme["ville"][0] += ms
		somme["ville"][1] += 1
	# plage : depart a 60 m du trait de cote, 24 s de marche vers la mer
	if frame == 400:
		depart = c - mer * 60.0 + Vector3(0, 1.0, 0)
		player.global_position = depart
		player.reset_physics_interpolation()
		last = Vector3.ZERO
	if frame > 400 and frame < 400 + 60 * 24:
		_walk()
		if frame > 460:
			phys["plage"] = maxf(phys["plage"], ms)
			somme["plage"][0] += ms
			somme["plage"][1] += 1
		if frame % 120 == 0:
			print("  t=%d s  pos %s  phys %.1f ms" % [(frame - 400) / 60, player.global_position.snapped(Vector3.ONE * 0.1), ms])
	if frame == 400 + 60 * 12:
		var d := (player.global_position - depart).dot(mer)
		_check(d > 30.0, "a pied : le joueur avance sur la plage (%.0f m vers la mer)" % d)
	if frame == 400 + 60 * 24:
		Input.action_release("move_forward")
	if frame == 400 + 60 * 24 + 1:
		var d := (player.global_position - depart).dot(mer)
		_check(d > 65.0, "a pied : le joueur entre dans l'eau (%.0f m vers la mer, y %.1f)" % [d, player.global_position.y])
		var mp: float = somme["plage"][0] / maxf(1.0, somme["plage"][1])
		var mv: float = somme["ville"][0] / maxf(1.0, somme["ville"][1])
		_check(mp < mv * 1.4 + 2.0, "physique comparable a la ville (moyenne %.1f ms, %.1f en ville ; pire %.1f / %.1f)" % [mp, mv, phys["plage"], phys["ville"]])
		_check(jumps == 0, "a pied : aucun a-coup (%d)" % jumps)
		# en voiture : de la rue jusque dans l'eau
		car = Vehicules.create("veh_berline", Color(0.7, 0.1, 0.1))
		scene.add_child(car)
		car.global_transform = Transform3D(Basis(Vector3.UP, atan2(-mer.x, -mer.z)), depart + Vector3(3, 0.5, 0))
		car.set("_yaw", atan2(-mer.x, -mer.z))
		player.enter_vehicle(car)
		jumps = 0
		last = Vector3.ZERO
		Input.action_press("accelerate", 0.6)
	if frame > 400 + 60 * 25 and frame < 400 + 60 * 37:
		var p := car.global_position
		if last != Vector3.ZERO and p.distance_to(last) > 2.0:
			jumps += 1
		last = p
		if frame % 120 == 0:
			print("  voiture t=%d s  pos %s  %.0f km/h" % [(frame - 400 - 1500) / 60, p.snapped(Vector3.ONE * 0.1), float(car.get("speed")) * 3.6])
	if frame == 400 + 60 * 37:
		Input.action_release("accelerate")
		var d := (car.global_position - depart).dot(mer)
		_check(d > 55.0 and car.global_position.y < -0.5, "en voiture : on descend la plage jusqu'a l'eau (%.0f m, y %.1f)" % [d, car.global_position.y])
		_check(jumps == 0, "en voiture : aucun a-coup (%d)" % jumps)
	if frame == 400 + 60 * 37:
		print("RESULTAT test_plage : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
