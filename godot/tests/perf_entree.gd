extends SceneTree
## A-coups en arrivant dans les grands lieux (retour d'Olympe du 17/10/2026) : le joueur s'approche de l'Ararat puis du
## terminal a 7 m/s depuis 220 m et entre ; on note la pire image et le nombre d'images de plus de 33 ms.
## Lancement : godot --path godot --resolution 1600x900 --script res://tests/perf_entree.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var cibles := [["ararat", Vector3(621, 1, 73)], ["terminal", Vector3(399, 1, -344)]]
var idx := 0
var t := 0.0
var pire := 0.0
var lents := 0
var depart := Vector3.ZERO
var fails := 0
var _sans_pnj := false


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	if "sans_pnj" in OS.get_cmdline_user_args():
		for n in scene.get_tree().get_nodes_in_group("pnj_interieur") if scene.is_inside_tree() else []:
			n.process_mode = Node.PROCESS_MODE_DISABLED
		_sans_pnj = true


func _process(delta: float) -> bool:
	frame += 1
	if frame == 3:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("off="):
				for nm in a.trim_prefix("off=").split(","):
					var nd := scene.get_node_or_null(nm)
					if nd:
						nd.process_mode = Node.PROCESS_MODE_DISABLED
	if frame == 2 and _sans_pnj:
		for n in get_nodes_in_group("pnj_interieur"):
			n.process_mode = Node.PROCESS_MODE_DISABLED
	if frame < 600:              # laisse finir la fabrication du chargement
		return false
	var c: Vector3 = cibles[idx][1]
	if t == 0.0:
		depart = c + Vector3(220, 0, 0)
		pire = 0.0
		lents = 0
	t += delta
	var k := minf(t * 7.0 / 220.0, 1.0)
	player.global_position = depart.lerp(c, k)
	player.velocity = Vector3.ZERO
	if t > 0.5:
		pire = maxf(pire, delta * 1000.0)
		if delta > 0.0333:
			lents += 1
			if false:
				print("   lente %.0f ms a %.0f m : process %.1f ms, physique %.1f ms, compilations %d, objets %d" % [delta * 1000.0, (1.0 - k) * 220.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	if k >= 1.0 and t > 220.0 / 7.0 + 3.0:
		print("ENTREE %s : pire image %.0f ms, %d images de plus de 33 ms" % [cibles[idx][0], pire, lents])
		if pire > 80.0 or lents > 10:
			fails += 1
		idx += 1
		t = 0.0
		if idx >= cibles.size():
			print("RESULTAT perf_entree : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
			quit(1 if fails else 0)
			return true
	return false
