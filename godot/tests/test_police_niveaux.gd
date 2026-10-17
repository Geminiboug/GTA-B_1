extends SceneTree
## Police a 5 niveaux (phase 14) : 1 agent a pied, 2 agent + patrouille, 3 barrage devant le joueur, 4 unite speciale
## (4x4), 5 motos de police qui roulent vers le joueur.

var frame := 0
var scene: Node
var pol: Node
var player: CharacterBody3D
var fails := 0
var mark := {}


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _kinds() -> Array:
	var out: Array = []
	for u in pol.units:
		out.append(u.get("kind", "berline"))
	return out


func _reste(u: Dictionary) -> float:
	## Longueur restante de l'itineraire de l'unite (les rues ne vont pas en ligne droite vers le joueur).
	var car: Node3D = u["car"]
	var prev := Vector2(car.global_position.x, car.global_position.z)
	var acc := 0.0
	for p in u.get("route", PackedVector2Array()):
		acc += prev.distance_to(p)
		prev = p
	return acc + prev.distance_to(Vector2(player.global_position.x, player.global_position.z))


func _level(n: int) -> void:
	root.get_node("Partie").set_recherche(n)
	pol.appel_t = 0.0
	pol.set("_spawn_cd", 0.0)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		pol = scene.get_node("Police")
		pol.arrestation = false
		root.get_node("Partie").nouvelle_partie()
		player.global_position = Vector3(300, 0.5, 120)
		player.reset_physics_interpolation()
		player.set_physics_process(false)
	if frame == 60:
		_level(1)
	if frame == 60 + 30:
		_check(_kinds() == ["pied"] and pol.units[0]["officer"] != null, "niveau 1 : un agent a pied (%s)" % [_kinds()])
		var o: Node3D = pol.units[0]["officer"]
		mark["d0"] = o.global_position.distance_to(player.global_position)
	if frame == 60 + 30 + 120:
		var o: Node3D = pol.units[0]["officer"]
		var d1: float = o.global_position.distance_to(player.global_position)
		_check(d1 < float(mark["d0"]) - 5.0, "l'agent arrive en courant (%.0f -> %.0f m)" % [mark["d0"], d1])
		_level(2)
	if frame == 60 + 30 + 120 + 300:
		_check("pied" in _kinds() and "berline" in _kinds(), "niveau 2 : agent + patrouille (%s)" % [_kinds()])
		_level(3)
	if frame == 60 + 30 + 120 + 300 + 600:
		var k := _kinds()
		_check(k.count("barrage") == 2, "niveau 3 : barrage de deux voitures (%s)" % [k])
		var ok := false
		for u in pol.units:
			if u.get("kind") == "barrage":
				var dd: float = (u["car"] as Node3D).global_position.distance_to(player.global_position)
				ok = dd > 60.0 and dd < 260.0
		_check(ok, "barrage devant le joueur, a distance")
		_check(k.count("berline") >= 2, "niveau 3 : deux patrouilles")
		_level(4)
	if frame == 60 + 30 + 120 + 300 + 600 + 900:
		var sp: Node3D = null
		for u in pol.units:
			if u.get("kind") == "special":
				sp = u["car"]
		_check(sp != null and String(sp.get("model_name")) == "veh_4x4", "niveau 4 : unite speciale en 4x4 (%s)" % [_kinds()])
		_level(5)
	if frame == 60 + 30 + 120 + 300 + 600 + 900 + 600:
		var moto: Node3D = null
		for u in pol.units:
			if u.get("kind") == "moto":
				moto = u["car"]
				mark["u"] = u
		_check(moto != null and moto.get("ai"), "niveau 5 : moto de police (%s)" % [_kinds()])
		if moto:
			mark["m0"] = moto.global_position.distance_to(player.global_position)
			mark["moto"] = moto
			mark["r0"] = _reste(mark["u"])
	if frame == 60 + 30 + 120 + 300 + 600 + 900 + 600 + 480:
		if mark.has("moto") and is_instance_valid(mark["moto"]):
			var d: float = (mark["moto"] as Node3D).global_position.distance_to(player.global_position)
			var r1 := _reste(mark["u"])
			_check(d < float(mark["m0"]) - 20.0 or d < 25.0 or r1 < float(mark["r0"]) - 40.0,
				"la moto roule vers le joueur (%.0f -> %.0f m, itineraire %.0f -> %.0f m)" % [mark["m0"], d, mark["r0"], r1])
		root.get_node("Partie").set_recherche(0)
	if frame == 60 + 30 + 120 + 300 + 600 + 900 + 600 + 500:
		_check(pol.units.is_empty(), "plus recherche : toutes les unites rentrent")
		print("RESULTAT test_police_niveaux : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
