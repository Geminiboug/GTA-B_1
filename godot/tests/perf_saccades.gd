extends SceneTree
## Cherche les chutes brutales d'images : le joueur avance a 9 m/s le long de la route principale pendant 80 s et chaque
## image de plus de 33 ms est notee avec la position, les taches de chargement en attente et le nombre d'objets.
## Lancement (avec fenetre) : godot --path godot --resolution 1600x900 --script res://tests/perf_saccades.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var t_prec := 0
var pics := 0
var pire := 0.0
var pos0 := Vector3(60, 1, 8)


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	for n in OS.get_cmdline_user_args():
		if scene.has_node(n):
			scene.get_node(n).queue_free()


func _process(delta: float) -> bool:
	frame += 1
	if frame == 200:
		player.global_position = pos0
		player.reset_physics_interpolation()
		t_prec = Time.get_ticks_usec()
		return false
	if frame < 200:
		return false
	var t := Time.get_ticks_usec()
	var ms := (t - t_prec) / 1000.0
	t_prec = t
	if frame > 260:
		player.global_position += Vector3(9.0 * delta, 0.0, 0.0)
		player.velocity = Vector3.ZERO
	if ms > 33.0 and frame > 260:
		pics += 1
		pire = maxf(pire, ms)
		print("SACCADE %.0f ms a x=%.0f z=%.0f (taches %d, objets %d, noeuds %d)" % [ms, player.global_position.x, player.global_position.z,
			int(root.get_node("Partie").call("taches_en_attente")), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))]
			+ " proc %.0f phys %.0f nav %.0f" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0])
	if frame > 200 + 60 * 80:
		print("RESULTAT saccades : %d images > 33 ms, pire %.0f ms" % [pics, pire])
		quit(0)
		return true
	return false
