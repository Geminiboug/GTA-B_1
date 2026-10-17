extends SceneTree
## Captures de controle des retours d'Olympe (phase 11) : aide aux commandes et objectif au debut du prologue,
## geste d'achat, police qui arrive (mini-carte), vol d'une voiture (geste Push).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_retours.gd -- <dossier>

var frame := 0
var scene: Node
var player: CharacterBody3D
var out := ""
var t_crime := -1


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 10.0)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("capture ", name)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		root.get_node("Partie").nouvelle_partie()
	if frame == 150:
		scene.get_node("Lieux")._spawn_home()
		scene.get_node("Histoire").commencer()
	if frame == 260:
		_shot("retour_1_debut")
	if frame == 280:
		# devant la vendeuse de pain : on achete (geste Interact)
		var h := scene.get_node("Histoire")
		h.step = -1
		var etal: Vector3 = h.points["etal"]
		var to := etal - player.global_position
		player.global_position = etal - (to * Vector3(1, 0, 1)).normalized() * 1.4 + Vector3(0, 0.1, 0)
		player.cam_pivot.rotation.y = atan2(-to.x, -to.z) + 0.9
	if frame == 330:
		scene.get_node("Commerce").buy("etal", 3)
	if frame == 345:
		_shot("retour_2_achat")
	if frame == 400:
		scene.get_node("Police").crime("vol", player.global_position)
		t_crime = frame
	if t_crime > 0 and frame == t_crime + 60 * 75:
		_shot("retour_3_police")
	if t_crime > 0 and frame == t_crime + 60 * 75 + 30:
		if player.get("vehicle"):
			player.exit_vehicle()
		scene.get_node("Histoire").active = false
	if t_crime > 0 and frame == t_crime + 60 * 76:
		root.get_node("Partie").set_recherche(0)
		# vol d'une voiture de la circulation : on se place a cote de la plus proche et E
		var trf := scene.get_node("Circulation")
		var best: Dictionary = {}
		var bd := INF
		for a in trf.get("_agents"):
			if a.get("kind") == "voiture" and a.get("active", true):
				var d: float = (a["body"] as Node3D).global_position.distance_to(player.global_position)
				if d < bd:
					bd = d
					best = a
		if not best.is_empty():
			var b: Node3D = best["body"]
			best["speed"] = 0.0
			player.global_position = b.global_position - b.global_transform.basis.x * 1.6 + Vector3(0, 0.2, 0)
			print("voiture a %.0f m, arretee" % bd)
			player.cam_pivot.rotation.y = atan2(b.global_transform.basis.x.x, b.global_transform.basis.x.z) + 2.4
		Input.action_press("interact")
	if t_crime > 0 and frame == t_crime + 60 * 76 + 2:
		Input.action_release("interact")
	if t_crime > 0 and frame == t_crime + 60 * 76 + 25:
		_shot("retour_4_vol")
	if t_crime > 0 and frame == t_crime + 60 * 76 + 50:
		_shot("retour_5_vol")
		return true
	return false
