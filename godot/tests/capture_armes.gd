extends SceneTree
## Captures de controle des armes : visee au pistolet (camera par-dessus l'epaule, reticule), machette en main,
## fusil a pompe. Lancement (avec fenetre) : godot --path godot --script res://tests/capture_armes.gd -- <dossier>

var frame := 0
var scene: Node
var out := ""
var player: Node3D
var armes: Node


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("capture ", name)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		player = scene.get_node("Player")
		armes = scene.get_node("Armes")
		var P := root.get_node("Partie")
		P.nouvelle_partie()
		scene.get_node("JourNuit").set("hour", 10.0)
		for n in ["Pistolet", "Machette", "Fusil à pompe"]:
			P.ajouter(n)
		P.ajouter("Balles 9 mm", 24)
		P.ajouter("Cartouches", 12)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		armes.equiper("Pistolet")
		Input.action_press("garde")
		(player.get("cam_pivot") as Node3D).rotation.x = -0.05
	if frame == 90:
		_shot("arme_1_visee_pistolet")
		Input.action_release("garde")
		armes.equiper("Machette")
		var pv: Node3D = player.get("cam_pivot")
		pv.rotation.y = float(player.get("_facing")) + 2.4
	if frame == 150:
		_shot("arme_2_machette")
		armes.equiper("Fusil à pompe")
		Input.action_press("garde")
	if frame == 220:
		_shot("arme_3_pompe")
		quit()
		return true
	return false
