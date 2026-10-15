extends SceneTree
## Captures de la mini-carte et de la grande carte, avec une destination et un itineraire.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_carte.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var hud: Node
var out_dir := "user://"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	hud = scene.get_node("HUD")


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		player.global_position = Vector3(300, 1, 60)
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(-0.25, 0.8, 0)
		hud.toggle_pin(Vector2(420, 150), 1.0)
		hud.set_waypoint(Vector2(560, -250))
		print("itineraire : %d points, %.0f m" % [hud.route.size(), hud.route_length])
	elif frame == 90:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("carte_mini.png"))
		print("capture mini")
		hud.open_map(true)
	elif frame == 130:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("carte_grande.png"))
		print("capture grande")
		hud.open_map(false)
		hud.toggle_pin(Vector2(420, 150), 1.0)
		return true
	return false
