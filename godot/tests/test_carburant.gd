extends SceneTree
## Carburant : reservoir et consommation des vehicules, panne seche, stations-service Bon Plein (pompes, pompiste),
## plein paye au litre, bouteille du kpayo versee dans le reservoir.
## Lancement : godot --headless --path godot --script res://tests/test_carburant.gd

var frame := 0
var scene: Node
var fails := 0
var st: Node
var car: Node3D
var etape := 0
var t0 := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _fin() -> bool:
	print("RESULTAT test_carburant : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true


func _physics_process(_d: float) -> bool:
	frame += 1
	var partie := root.get_node("Partie")
	var player := scene.get_node("Player") as CharacterBody3D
	if frame < 150:
		return false
	if etape == 0:
		partie.nouvelle_partie()
		st = scene.get_node("Stations")
		_check(st.stations.size() >= 5, "stations posees : %d" % st.stations.size())
		var libres := true
		for s in st.stations:
			var p: Vector3 = s["pos"]
			if Carte.zone().in_building(Vector2(p.x, p.z)):
				libres = false
		_check(libres, "aucune station dans un batiment")
		# voiture a la pompe de la premiere station
		var s0: Dictionary = st.stations[0]
		var pompe: Vector3 = s0["pompes"][0]
		player.global_position = pompe + Vector3(6, 1, 0)
		player.reset_physics_interpolation()
		etape = 1
		t0 = frame
		return false
	if etape == 1 and frame - t0 == 120:
		var s0: Dictionary = st.stations[0]
		var pompe: Vector3 = s0["pompes"][0]
		car = Vehicules.create("veh_berline", Color(0.6, 0.1, 0.1))
		scene.add_child(car)
		car.global_position = pompe + Vector3(0, 0.4, 2.6)
		car.set("carburant", 5.0)
		car.call("set_rider", true)
		partie.argent = 20000
		player.set("vehicle", car)
		player.set_physics_process(false)
		st._pompistes(pompe)
		_check(s0["pompiste"] != null, "un pompiste est la quand on arrive")
		st._plein = {"veh": car, "litres": 0.0, "paye": 0, "station": s0}
		etape = 2
		t0 = frame
		return false
	if etape == 2 and frame - t0 == 60 * 8:
		var plein: float = car.get("carburant")
		_check(plein > 12.0, "le plein monte (%.1f L apres 8 s)" % plein)
		_check(partie.argent < 20000, "plein paye au litre (%d F)" % (20000 - partie.argent))
		_check(20000 - partie.argent == int(round(plein - 5.0)) * 650 or absi((20000 - partie.argent) - int((plein - 5.0)) * 650) <= 650, "prix coherent avec les litres")
		st._plein = {}
		# panne seche : presque vide, on accelere
		car.set("carburant", 0.02)
		car.set("moteur", true)
		Input.action_press("accelerate")
		etape = 3
		t0 = frame
		return false
	if etape == 3 and frame - t0 == 60 * 14:
		Input.action_release("accelerate")
		_check(car.get("carburant") == 0.0 and not car.get("moteur"), "panne seche : moteur coupe a zero litre")
		var lit: float = car.call("faire_le_plein", 10.0)
		_check(is_equal_approx(lit, 10.0) and car.get("carburant") > 9.9, "faire_le_plein ajoute les litres")
		return _fin()
	return false
