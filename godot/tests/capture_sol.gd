extends SceneTree
## Captures rapprochees vues de dessus de points precis (controle des sols).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_sol.gd -- <dossier> x z [x z ...]

var frame := 0
var out_dir := "user://"
var points: Array[Vector2] = []
var cam: Camera3D
var idx := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	for i in range(1, args.size() - 1, 2):
		points.append(Vector2(float(args[i]), float(args[i + 1])))
	var scene: Node = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	cam = Camera3D.new()
	scene.add_child(cam)
	cam.current = true


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 20:
		return false
	var p := points[idx]
	var local := frame - 20 - idx * 20
	if local == 0:
		cam.look_at_from_position(Vector3(p.x, 6, p.y + 4), Vector3(p.x, 0, p.y))
	elif local == 15:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("sol_%d.png" % idx))
		print("capture sol ", idx, " ", p)
		idx += 1
		if idx >= points.size():
			return true
	return false
