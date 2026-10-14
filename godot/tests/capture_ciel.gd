extends SceneTree
## Captures du ciel depuis la plage, a 10 s d'intervalle, pour voir les nuages deriver.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_ciel.gd -- <dossier_sortie>

var frame := 0
var player: CharacterBody3D
var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var scene: Node = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")


func _shot(tag: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("ciel_%s.png" % tag))
	print("capture ", tag)


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		10:
			# regard vers le nord (la ville), camera un peu levee vers le ciel
			player.cam_pivot.rotation = Vector3(0.25, 0.0, 0.0)
		90:
			_shot("t0")
		690:
			_shot("t10")
			player.cam_pivot.rotation = Vector3(0.1, PI, 0.0)  # vers la mer
		760:
			_shot("mer")
			return true
	return false
