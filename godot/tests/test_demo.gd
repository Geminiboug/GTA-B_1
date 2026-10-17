extends SceneTree
## Phase 13 : credits lisibles (fichier exporte), ecran de fin de demo, mode photo (HUD cache, jeu fige, camera
## libre bornee autour du joueur, retour a l'etat d'avant).

var frame := 0
var scene: Node
var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "ECHEC ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		var f := FileAccess.open("res://assets/data/credits.txt", FileAccess.READ)
		var t := f.get_as_text() if f else ""
		_check(t.contains("OpenStreetMap") and t.contains("CC BY 4.0") and t.contains("Quaternius") and t.contains("Sentinel-2"), "credits : OSM, Open Buildings, Quaternius, Sentinel-2")
		var exp := FileAccess.get_file_as_string("res://export_presets.cfg")
		_check(exp.contains("assets/data/*.txt"), "credits inclus dans l'export")
		var pot := FileAccess.get_file_as_string("res://i18n/gtb.pot")
		_check(pot.contains("msgid \"Nouvelle partie\"") and pot.contains("msgid \"MISSION RÉUSSIE\""), "fichier de traduction i18n/gtb.pot (tools/extraire_textes.py)")
		var menus := scene.get_node("Menus")
		menus.fin_demo()
		_check(not paused, "fin de demo ignoree hors du vrai jeu (tests)")
		var photo := scene.get_node("ModePhoto")
		var hud := scene.get_node("HUDJeu") as CanvasLayer
		var cam0 := root.get_viewport().get_camera_3d()
		photo.entrer()
		_check(photo.actif and paused, "mode photo : jeu fige")
		_check(not hud.visible, "mode photo : HUD cache")
		_check(root.get_viewport().get_camera_3d() != cam0, "mode photo : camera libre")
	if frame == 90:
		var photo := scene.get_node("ModePhoto")
		Input.action_press("move_forward")
	if frame == 400:
		Input.action_release("move_forward")
		var photo := scene.get_node("ModePhoto")
		var p := scene.get_node("Player") as Node3D
		var d: float = root.get_viewport().get_camera_3d().global_position.distance_to(p.global_position)
		_check(d <= photo.portee + 1.0, "camera bornee autour du joueur (%.0f m)" % d)
		var cam_photo := root.get_viewport().get_camera_3d()
		photo.sortir()
		_check(not paused and (scene.get_node("HUDJeu") as CanvasLayer).visible, "sortie : jeu repris, HUD revenu")
		_check(root.get_viewport().get_camera_3d() != cam_photo, "sortie : camera du joueur")
		print("RESULTAT test_demo : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
