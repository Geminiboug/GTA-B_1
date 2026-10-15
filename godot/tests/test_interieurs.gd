extends SceneTree
## Reactions des PNJ des interieurs (supermarche, aerogare) : un client frappe tombe puis s'enfuit,
## les clients proches s'enfuient aussi, le vigile intervient a la voix.
## Lancement : godot --headless --path godot --script res://tests/test_interieurs.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var pnj: Node
var target: Dictionary
var key_i := 0
const PLACES := [[5, "ararat"], [4, "terminal"]]


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _physics_process(_d: float) -> bool:
	frame += 1
	var k := frame - key_i * 900
	if frame == 30:
		player = scene.get_node("Player")
	if frame < 30:
		return false
	if key_i >= PLACES.size():
		print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
		return true
	var place: Array = PLACES[key_i]
	if k == 40:
		scene.get_node("Debug").teleport(place[0])
	if k == 400:
		pnj = null
		for n in get_nodes_in_group("pnj_interieur"):
			if n._key == place[1]:
				pnj = n
		_check(pnj != null and pnj._active and pnj._walkers.size() > 2, "%s : clients actifs (%d)" % [place[1], pnj._walkers.size() if pnj else 0])
		if pnj == null or pnj._walkers.is_empty():
			key_i += 1
			return false
		target = pnj._walkers[0]
		var tp: Vector3 = (target["node"] as Node3D).global_position
		target["pause"] = 10.0
		var dir := Vector3(1, 0, 0)
		pnj.player_attack(tp - dir * 0.8, dir)
		_check(target["state"] == "down", "%s : client frappe au sol" % place[1])
		var fled := 0
		for w in pnj._walkers:
			if w != target and w.get("state", "walk") == "flee":
				fled += 1
		_check(fled > 0 or pnj._walkers.size() < 3, "%s : %d client(s) proches s'enfuient" % [place[1], fled])
	if k == 400 + 460 and pnj:
		_check(target.get("state") == "flee", "%s : le client frappe se releve et s'enfuit" % place[1])
		key_i += 1
	return false
