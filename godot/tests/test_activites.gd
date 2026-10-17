extends SceneTree
## Activites secondaires (phase 20) : fresques placees et photographiees, pari au maquis resolu a l'heure suivante,
## course de zems de nuit (points de passage, rivaux, recompense), taux de completion.

var frame := 0
var scene: Node
var player: CharacterBody3D
var ac: Node
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
		ac = scene.get_node("Activites")
		P.nouvelle_partie()
		P.argent = 50000
		scene.get_node("Police").set("arrestation", false)
		_check(ac._fresques.size() >= 10, "%d fresques peintes sur les murs" % ac._fresques.size())
		# photo : camera face a la premiere fresque
		var f: Node3D = ac._fresques[0]["node"]
		var cam := Camera3D.new()
		scene.add_child(cam)
		cam.global_position = f.global_position + f.global_transform.basis.z * 6.0 + Vector3(0, 0.3, 0)
		cam.look_at(f.global_position, Vector3.UP)
		cam.current = true
		mark["a"] = P.argent
		ac._photo(cam)
		_check(ac.fresques_trouvees().size() == 1 and P.argent == int(mark["a"]) + 1000, "fresque photographiee : 1 / %d, 1 000 F" % ac.NB_FRESQUES)
		ac._photo(cam)
		_check(ac.fresques_trouvees().size() == 1, "la meme fresque ne compte qu'une fois")
		# pari
		var com := scene.get_node("Commerce")
		_check(com.buy("paris", 2) and (P.drapeaux["paris"] as Array).size() == 1, "pari place sur l'Atlantique FC")
		var day := scene.get_node("JourNuit")
		day.set("hour", 21.0)
	if frame == 45:
		_check((P.drapeaux.get("paris", []) as Array).is_empty(), "match joue a l'heure suivante, pari regle")
		# course de nuit
		var z: Node3D = scene.get_node("Zem")
		z.global_position = ac._depart + Vector3(0, 0.3, 0)
		player.enter_vehicle(z)
		ac.lancer_course()
		_check((ac.course["points"] as Array).size() == 8 and (ac.course["rivaux"] as Array).size() == 2, "course : 8 points de passage, 2 rivaux")
		mark["a2"] = P.argent
	if frame > 50 and frame < 600 and not ac.course.is_empty():
		# le joueur passe chaque point (teleporte), les rivaux roulent pour de vrai
		var z: Node3D = scene.get_node("Zem")
		if frame % 10 == 0:
			var pts: Array = ac.course["points"]
			z.global_position = (pts[mini(int(ac.course["i"]), pts.size() - 1)] as Vector3) + Vector3(0, 0.3, 0)
	if frame == 300:
		mark["riv"] = (ac.course.get("rivaux", [{}])[0] as Dictionary).get("i", -1)
	if frame == 620:
		_check(ac.course.is_empty() and P.argent >= int(mark["a2"]) + 3000, "course terminee et payee (%d F)" % (P.argent - int(mark["a2"])))
		_check(int(P.drapeaux.get("courses_gagnees", 0)) == 1, "course gagnee comptee")
		var c: float = ac.completion()
		_check(c > 0.0 and c < 100.0, "taux de completion : %.1f %%" % c)
		print("RESULTAT test_activites : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
