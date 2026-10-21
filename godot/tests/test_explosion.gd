extends SceneTree
## Degats, feu puis explosion des vehicules : une voiture et une moto tres abimees prennent feu, explosent apres le delai,
## blessent le joueur proche, deviennent des epaves qu'on ne peut plus prendre ; la reparation les remet en etat.
## Lancement : godot --headless --path godot --script res://tests/test_explosion.gd

var frame := 0
var scene: Node
var fails := 0
var car: Node3D
var zem: Node3D
var player: Node3D
var etape := 0
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
	if frame < 90:
		return false
	var partie := root.get_node("Partie")
	player = scene.get_node("Player")
	if etape == 0:
		for v in get_nodes_in_group("vehicules"):
			if v.get("kind") == "zem" and zem == null and not v.get("has_rider"):
				zem = v
		# les voitures de la rue sont des agents : on en fabrique une, comme le fait le jeu quand on en prend une
		car = Vehicules.create("veh_berline", Color(0.7, 0.1, 0.1))
		scene.add_child(car)
		_check(car != null, "une voiture est disponible")
		_check(zem != null, "une moto est disponible")
		if car == null or zem == null:
			return _fin()
		car.global_position = Vector3(-3100, 0.5, -800)
		zem.global_position = Vector3(-3100, 0.5, -820)
		car.set("delai_explosion", 4.0)
		zem.set("delai_explosion", 4.0)
		player.global_position = Vector3(-3097, 0.5, -800)
		player.reset_physics_interpolation()
		partie.sante = 100.0
		car.call("damage", 90.0)
		zem.call("damage", 90.0)
		_check(car.get_node_or_null("FeuVehicule") != null, "la voiture prend feu sous 15 % de sante")
		_check(zem.get_node_or_null("FeuVehicule") != null, "la moto prend feu sous 15 % de sante")
		_check(not car.get("epave") and not zem.get("epave"), "pas encore explosees")
		etape = 1
		t0 = frame
		return false
	if etape == 1 and frame - t0 == 60 * 6:
		_check(car.get("epave") and zem.get("epave"), "les deux explosent apres le delai")
		_check(scene.get_node_or_null("Explosion") != null, "boule de feu et detonation dans la scene")
		_check(float(partie.sante) < 100.0, "le joueur proche est blesse par le souffle (sante %.0f)" % float(partie.sante))
		_check(car.get("health") == 0.0, "sante a zero")
		var near: Node3D = player._nearest_vehicle()
		_check(near != car and near != zem, "on ne peut plus monter dans une epave")
		car.call("reparer")
		_check(not car.get("epave") and car.get("health") == 100.0, "la reparation remet la voiture en etat")
		return _fin()
	return false


func _fin() -> bool:
	print("RESULTAT test_explosion : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
