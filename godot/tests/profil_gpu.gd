extends SceneTree
## Temps de rendu CPU / GPU de la vue principale apres une teleportation (diagnostic de performance).
## Lancement (avec fenetre) : godot --path godot --script res://tests/profil_gpu.gd [-- x z]

var frame := 0
var scene: Node
var cpu := 0.0
var gpu := 0.0
var n := 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		var args := OS.get_cmdline_user_args()
		var pl: Node3D = scene.get_node("Player")
		pl.global_position = Vector3(float(args[0]), 1, float(args[1])) if args.size() > 1 else Vector3(300, 1, 120)
		pl.reset_physics_interpolation()
	if frame < 150:
		return false
	var vp := root.get_viewport_rid()
	cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	n += 1
	if n == 120:
		var pl: Node3D = scene.get_node("Player")
		print("rendu CPU %.1f ms  GPU %.1f ms  images/s %d  joueur %s au sol %s" % [cpu / n, gpu / n, Engine.get_frames_per_second(), pl.global_position.snapped(Vector3.ONE * 0.1), pl.is_on_floor()])
		return true
	return false
