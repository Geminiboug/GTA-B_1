extends SceneTree
## Captures du zem en jeu : a l'arret avec le pilote, puis en virage.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_zem.gd -- <dossier_sortie>

var frame := 0
var player: CharacterBody3D
var zem: CharacterBody3D
var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var scene: Node = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	zem = scene.get_node("Zem")


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("zem_jeu_%s.png" % name))
	print("capture ", name)


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		45:
			Input.action_press("interact")
		47:
			Input.action_release("interact")
		70:
			var rig := zem.get_node("CamRig")
			rig.rotation.y = zem.rotation.y + 1.2  # vue de 3/4 avant gauche
		90:
			_shot("arret")
			Input.action_press("accelerate")
		260:
			Input.action_press("move_left")
		330:
			_shot("virage")
			return true
	return false
