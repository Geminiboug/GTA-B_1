extends SceneTree
## Options : chaque reglage du menu s'applique tout de suite (volume, qualite, daltonisme), sans "Appliquer" ni relance.
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
	current_scene = scene
func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		var P := root.get_node("Partie")
		P.save_path = "user://test_options.json"
		var m := scene.get_node("Menus")
		m.call("_open", "pause")
		m.call("_show_options")
		# volume : le curseur agit sur le bus principal tout de suite
		var o: Dictionary = P.options
		o["volume"] = 0.25
		m.call("_apercu")
		_check(absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.25) < 0.01, "volume applique en direct")
		# daltonisme : couleur de l'argent et du syndicat rouge sans relancer
		var hud := scene.get_node("HUDJeu") if scene.has_node("HUDJeu") else get_first_node_in_group("hud_jeu")
		var avant: Color = hud.get("_argent").get_theme_color("font_color")
		o["daltonisme"] = not bool(o.get("daltonisme", false))
		m.call("_apercu")
		var apres: Color = hud.get("_argent").get_theme_color("font_color")
		_check(avant != apres, "daltonisme : couleur de l'argent changee en direct")
		var ter := get_first_node_in_group("options") if not scene.has_node("Territoires") else scene.get_node("Territoires")
		_check(ter.SYNDICATS["szu"]["couleur"] == (Color(1.0, 0.55, 0.0) if o["daltonisme"] else Color(0.85, 0.2, 0.15)), "daltonisme : couleur du syndicat changee en direct")
		# qualite : l'echelle de rendu suit
		o["qualite"] = 0
		m.call("_apercu")
		var q0: float = scene.get_viewport().scaling_3d_scale
		o["qualite"] = 2
		m.call("_apercu")
		_check(scene.get_viewport().scaling_3d_scale != q0 or Qualite.PRESETS[0][4] == Qualite.PRESETS[2][4], "qualite appliquee en direct")
		o["daltonisme"] = false
		o["volume"] = 0.8
		m.call("_apercu")
		print("RESULTAT test_options_direct : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
