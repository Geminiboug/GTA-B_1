extends SceneTree
## Planche du jeu : ecran titre, HUD en jeu (argent, sante, etoiles, objectif, notification), achat a un etal,
## patrouille de police avec gyrophare, menu pause.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_jeu.gd -- <fichier.png>

var frame := 0
var scene: Node
var out := "user://jeu.png"
var shots: Array[Image] = []
var player: Node3D
var car: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene          # ecran titre comme au vrai lancement
	scene.get_node("JourNuit").set("hour", 17.0)


func _shot() -> void:
	shots.append(root.get_viewport().get_texture().get_image())


func _process(_d: float) -> bool:
	frame += 1
	var menus := scene.get_node("Menus")
	if frame == 90:
		_shot()                                    # ecran titre
		menus.call("_close")
		root.get_node("Partie").nouvelle_partie()
		scene.get_node("Histoire").commencer()
		player = scene.get_node("Player")
	if frame == 200:
		root.get_node("Partie").gagner(2500, "Course de zem")
		root.get_node("Partie").set_recherche(2)
		root.get_node("Partie").blesser(35.0)
	if frame == 215:
		_shot()                                    # HUD
	if frame == 220:
		var com := scene.get_node("Commerce")
		var s: Dictionary = {}
		for sp in com.spots:
			if sp["kind"] == "etal_pain":
				s = sp
				break
		# rue degagee (teleportation 2 du mode debug), panneau d'achat ouvert comme devant un etal
		scene.get_node("Debug").teleport(2)
	if frame == 240:
		var com := scene.get_node("Commerce")
		com.set("_near", {"pos": player.global_position, "kind": "etal_pain"})
		com.set("spots", [{"pos": player.global_position, "kind": "etal_pain"}])
		com.call("_show", "etal_pain")
	if frame == 300:
		_shot()                                    # achat
		scene.get_node("Commerce").call("_close")
		var police := scene.get_node("Police")
		car = police.call("_make_car", player.global_position + Vector3(5, 0, 0), 0.6)
		car.set("ai_input", Vector3(0, 1, 0))
	if frame == 320:
		var cam := Camera3D.new()
		scene.add_child(cam)
		cam.global_position = car.global_position + Vector3(-3.5, 1.8, 4.5)
		cam.look_at(car.global_position + Vector3(0, 0.8, 0), Vector3.UP)
		cam.current = true
	if frame == 340:
		_shot()                                    # patrouille
		menus.call("_open", "pause")
	if frame == 360:
		_shot()                                    # pause
		var wd := shots[0].get_width()
		var ht := shots[0].get_height()
		var sheet := Image.create(wd * 3, ht * 2, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, wd, ht), Vector2i(wd * (i % 3), ht * (i / 3)))
		sheet.resize(wd * 3 / 2, ht)
		sheet.save_png(out)
		print("capture jeu")
		return true
	return frame > 1500
