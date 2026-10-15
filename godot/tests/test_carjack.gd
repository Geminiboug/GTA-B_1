extends SceneTree
## Vol d'un zem de la circulation : le conducteur ejecte garde ses habits (chemise jaune, casque),
## il poursuit le joueur, le sort du zem arrete et repart avec dans la circulation.
## Lancement : godot --headless --path godot --script res://tests/test_carjack.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var traffic: Node
var peds: Node
var fails := 0
var agent: Dictionary
var v: Node3D


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 240:
		player = scene.get_node("Player")
		traffic = scene.get_node("Circulation")
		peds = scene.get_node("Pietons")
		for a in traffic._agents:
			if a["model"] == "zem" and a.get("active", true):
				agent = a
				break
		_check(not agent.is_empty(), "un zem dans la circulation")
		if agent.is_empty():
			return true
		var body: Node3D = agent["body"]
		player.global_position = body.global_position - body.global_transform.basis.x * 0.8 + Vector3(0, 0.2, 0)
		player.reset_physics_interpolation()
		v = traffic.take_over(agent["id"], player)
		player.enter_vehicle(v)
		var owner: Dictionary = {}
		for w in peds._walkers:
			if w.get("carjacked", false) and w.get("driver", false):
				owner = w
		_check(not owner.is_empty(), "le conducteur est ejecte")
		if not owner.is_empty():
			var look: Dictionary = (owner["node"] as Node).get_meta("look", {})
			_check(look == agent["riders"][0][2], "le conducteur ejecte garde sa tenue de zemidjan")
	if frame > 240 and frame < 240 + 60 * 15 and agent.size() > 0 and not is_instance_valid(v):
		_check(player.get("vehicle") == null, "le proprietaire a sorti le joueur du zem")
		_check(agent.get("active", false), "le zem est reparti dans la circulation")
		print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
		return true
	if frame > 240 and frame % 60 == 0 and is_instance_valid(v):
		for w in peds._walkers:
			if w.get("carjacked", false) and w.get("driver", false):
				print("  etat %s  distance %.1f  stolen %s" % [w["state"], Vector2(w["pos"].x - v.global_position.x, w["pos"].z - v.global_position.z).length(), w.has("stolen")])
	if frame == 240 + 60 * 15:
		_check(false, "le proprietaire n'a pas repris son zem en 15 s")
		print("RESULTAT : %d echec(s)" % fails)
		return true
	return false
