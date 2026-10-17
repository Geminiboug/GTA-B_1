extends SceneTree
## Finition (phase 24) : trois emplacements de sauvegarde, succes gardes et affiches, touches reaffectees, taille de
## l'interface, aide a la visee.

var frame := 0
var scene: Node
var fails := 0


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	var P := root.get_node("Partie")
	if frame == 40:
		P.save_path = "user://test_finition.json"
		for i in range(1, 4):
			DirAccess.remove_absolute(P.chemin_emplacement(i))
		P.nouvelle_partie()
		P.argent = 1111
		_check(P.sauver_emplacement(scene, 2), "sauvegarde dans l'emplacement 2")
		P.argent = 2222
		P.sauver_emplacement(scene, 3)
		_check(P.emplacements_occupes() == [2, 3], "emplacements occupes : %s" % [P.emplacements_occupes()])
		_check(P.resume_emplacement(2).contains("1 111") and P.resume_emplacement(1) == "Vide", "resumes : %s / %s" % [P.resume_emplacement(1), P.resume_emplacement(2)])
		P.charger_emplacement(scene, 2)
		_check(P.argent == 1111, "chargement de l'emplacement 2 (%d F)" % P.argent)
		# succes
		var sc := scene.get_node("Succes")
		_check(sc.FICHIER == "user://test_succes.cfg", "les tests n'ecrivent pas dans les succes du joueur")
		DirAccess.remove_absolute(sc.FICHIER)
		sc.obtenus = {}
		P.stats["courses"] = 1
	if frame == 80:
		var sc := scene.get_node("Succes")
		_check(sc.obtenus.has("premiere_course"), "succes debloque : Zemidjan")
		var c := ConfigFile.new()
		_check(c.load(sc.FICHIER) == OK and c.has_section_key("succes", "premiere_course"), "succes enregistre sur le disque")
		var menus := scene.get_node("Menus")
		menus.call("_show_succes")
		_check(String(menus.get("_page")) == "succes", "page des succes dans le menu")
		# touches
		P.options["touches"] = {"jump": KEY_J}
		P.appliquer_options()
		var j := false
		for ev in InputMap.action_get_events("jump"):
			if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_J:
				j = true
		_check(j, "sauter reaffecte sur J")
		P.options["touches"] = {}
		menus.call("_show_touches")
		P.options["taille_interface"] = 1.3
		P.appliquer_options()
		_check(is_equal_approx(root.content_scale_factor, 1.3), "taille de l'interface 1,3")
		P.options["taille_interface"] = 1.0
		P.appliquer_options()
		_check(scene.get_node("Armes").get("aide_visee") == true, "aide a la visee active par defaut")
		print("RESULTAT test_finition : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
