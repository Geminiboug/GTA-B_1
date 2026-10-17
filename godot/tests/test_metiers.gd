extends SceneTree
## Metiers et defis (phase 20) : ligne de minibus (arrets, passagers qui paient, prime), saut acrobatique paye,
## cauris caches ramasses.
var frame := 0
var scene: Node
var player: CharacterBody3D
var me: Node
var bus: Node3D
var fails := 0
var mark := {}
func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1
func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _physics_process(_d: float) -> bool:
	frame += 1
	var P := root.get_node("Partie")
	if frame == 40:
		player = scene.get_node("Player")
		me = scene.get_node("Metiers")
		P.nouvelle_partie()
		scene.get_node("Police").set("arrestation", false)
		_check(me._cauris.size() >= 15, "%d sacs de cauris caches" % me._cauris.size())
		bus = Vehicules.create("veh_minibus", Color(0.95, 0.8, 0.2))
		scene.add_child(bus)
		bus.global_position = Vector3(300, 0.4, 120)
		player.enter_vehicle(bus)
		me.lancer_ligne(bus)
		_check((me.ligne["arrets"] as Array).size() == 6, "ligne de 6 arrets")
		mark["a"] = P.argent
	if frame > 50 and frame < 1200 and not me.ligne.is_empty() and frame % 20 == 0:
		var a: Vector3 = me.ligne["arrets"][me.ligne["i"]]
		bus.global_position = a + Vector3(0, 0.4, 0)
		bus.set("_vel", Vector2.ZERO)
	if frame == 1200:
		_check(me.ligne.is_empty() and P.argent > int(mark["a"]) + 3000, "ligne terminee : %d F gagnes" % (P.argent - int(mark["a"])))
		var a0: int = P.argent
		me.saut_reussi(22.0, 1.6)
		_check(P.argent > a0 and int(P.stats.get("sauts", 0)) == 1, "saut acrobatique paye (%d F)" % (P.argent - a0))
		player.exit_vehicle()
	if frame == 1230:
		var c: Dictionary = me._cauris[0]
		player.global_position = (c["pos"] as Vector3) + Vector3(0, 0.3, 0)
		mark["c"] = P.argent
	if frame == 1240:
		_check((P.drapeaux.get("cauris", []) as Array).size() == 1 and P.argent == int(mark["c"]) + 500, "sac de cauris ramasse (500 F)")
		print("RESULTAT test_metiers : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
