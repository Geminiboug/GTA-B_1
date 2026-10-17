extends SceneTree
## Captures du corps a corps (phase 14) : crochet du joueur, passant en garde qui riposte, garde du joueur.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_combat.gd -- <dossier>

var frame := 0
var scene: Node
var player: CharacterBody3D
var peds: Node
var out := ""
var w: Dictionary


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("capture ", name)


func _press(a: String, frames := 2) -> void:
	Input.action_press(a)
	for i in frames:
		await process_frame
	Input.action_release(a)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		peds = scene.get_node("Pietons")
		root.get_node("Partie").nouvelle_partie()
		scene.get_node("JourNuit").set("hour", 16.0)
		player.global_position = Vector3(300, 0.5, 120)
		player.reset_physics_interpolation()
	if frame == 100:
		var bd := INF
		for x in peds._walkers:
			var d: float = (x["pos"] as Vector3).distance_to(player.global_position)
			if d < bd:
				bd = d
				w = x
		var fwd := Vector3(-sin(player.get("_facing")), 0, -cos(player.get("_facing")))
		w["pos"] = player.global_position + fwd * 1.0
		w["pos"].y = peds.GROUND_Y
		w["caractere"] = "bagarreur"
		w["state"] = "fight"
		w["state_t"] = 0.0
		w["pv"] = 400.0
		player.cam_pivot.rotation.y = player.get("_facing") + 1.2
	if frame == 130:
		_press("attaque")
	if frame == 150:
		_shot("combat_1_direct")
	if frame == 155:
		_press("attaque")
	if frame == 180:
		_press("attaque")
	if frame == 196:
		_shot("combat_2_crochet")
	if frame == 300:
		Input.action_press("garde")
	if frame == 330:
		_shot("combat_3_garde")
	if frame == 420:
		_shot("combat_4_riposte")
		Input.action_release("garde")
		return true
	return false
