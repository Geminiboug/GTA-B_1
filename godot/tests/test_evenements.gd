extends SceneTree
## Evenements (phase 20) : cortege de funerailles a 16 h avec fanfare, qui avance ; l'accompagner donne du respect.
var frame := 0
var scene: Node
var ev: Node
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
		ev = scene.get_node("Evenements")
		ev.duree_accompagner = 3.0
		P.nouvelle_partie()
		scene.get_node("Player").global_position = Vector3(300, 0.5, 120)
		scene.get_node("JourNuit").set("hour", 16.1)
	if frame == 45:
		_check(not ev.cortege.is_empty(), "cortege de funerailles a 16 h")
		if ev.cortege.is_empty():
			print("RESULTAT test_evenements : 1 ECHEC(S)")
			quit(1)
			return true
		_check((ev.cortege["membres"] as Array).size() == 14 and ev.cortege["son"] is Node3D, "14 personnes (cortege silencieux)")
		mark["p"] = (ev.cortege["membres"][0] as Node3D).global_position
		mark["r"] = float(P.perso.get("respect", 0.0))
	if frame > 50 and frame < 500 and not ev.cortege.is_empty():
		var m: Node3D = ev.cortege["membres"][7]
		scene.get_node("Player").global_position = m.global_position + Vector3(2, 0.3, 0)
	if frame == 300:
		var d: float = (ev.cortege["membres"][0] as Node3D).global_position.distance_to(mark["p"])
		_check(d > 2.0, "le cortege avance (%.1f m)" % d)
	if frame == 500:
		_check(float(P.perso.get("respect", 0.0)) > float(mark["r"]), "accompagner le cortege : respect (%.0f)" % P.perso.get("respect", 0.0))
		print("RESULTAT test_evenements : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
