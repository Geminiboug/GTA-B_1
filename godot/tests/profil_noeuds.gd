extends SceneTree
## Cherche le systeme qui ralentit une image : apres une teleportation, desactive tour a tour chaque noeud principal
## de la scene et mesure le temps de traitement moyen (process + physique).
## Lancement (avec fenetre) : godot --path godot --script res://tests/profil_noeuds.gd [-- x z]

var frame := 0
var scene: Node
var names: Array = []
var idx := -1
var acc := 0.0
var n := 0
var base := 0.0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		var args := OS.get_cmdline_user_args()
		var at := Vector3(float(args[0]), 1, float(args[1])) if args.size() > 1 else Vector3(300, 1, 120)
		var pl: Node3D = scene.get_node("Player")
		pl.global_position = at
		pl.reset_physics_interpolation()
		for c in scene.get_children():
			if c.name in ["Player", "Pietons", "Circulation", "Lieux", "HUD"]:
				names.append(c.name)
	if frame < 120:
		return false
	acc += Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	n += 1
	if n == 60:
		var ms := acc / n * 1000.0
		if idx < 0:
			base = ms
			print("reference : %.1f ms" % ms)
		else:
			print("sans %-22s : %.1f ms (%+.1f)" % [names[idx], ms, ms - base])
			scene.get_node(String(names[idx])).process_mode = Node.PROCESS_MODE_INHERIT
		idx += 1
		acc = 0.0
		n = 0
		if idx >= names.size():
			return true
		scene.get_node(String(names[idx])).process_mode = Node.PROCESS_MODE_DISABLED
	return false
