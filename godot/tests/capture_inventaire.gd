extends SceneTree
## Captures de controle : torche de nuit, inventaire ouvert, telephone ouvert.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_inventaire.gd -- <dossier>

var frame := 0
var scene: Node
var out := ""


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("capture ", name)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		root.get_node("Partie").nouvelle_partie()
		scene.get_node("JourNuit").set("hour", 21.5)
		var p := scene.get_node("Player")
		p.global_position = Vector3(300, 1, 120)
		p.reset_physics_interpolation()
		p.cam_pivot.rotation = Vector3(-0.2, 2.4, 0)
	if frame == 120:
		scene.get_node("Inventaire").torche(true)
	if frame == 200:
		_shot("inv_1_torche_nuit")
		scene.get_node("Inventaire").ouvrir(true)
	if frame == 220:
		_shot("inv_2_inventaire")
		scene.get_node("Telephone").ouvrir(true)
	if frame == 240:
		_shot("inv_3_telephone")
		scene.get_node("Telephone").app("Zem")
	if frame == 260:
		_shot("inv_4_telephone_zem")
		return true
	return false
