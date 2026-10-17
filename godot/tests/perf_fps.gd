extends SceneTree
## Mesure des images par seconde en rendu reel (fenetre, synchro verticale coupee) depuis plusieurs points de vue.
## Lancement : godot --path godot --resolution 1600x900 --script res://tests/perf_fps.gd [-- <qualite 0 a 2>]
## Test de fluidite (phase 11) : budget d'Olympe, moyenne d'au moins 70 images/s dehors et 60 en interieur ;
## resultat OK / ECHEC et code de sortie 1 en cas d'echec (tests/perf.sh lance les trois qualites).
## Fermer l'editeur Godot, Blender et les logiciels lourds avant de mesurer.

var frame := 0
var scene: Node
var player: CharacterBody3D
var views := [["quartier", Vector3(300, 1, 120), 2.4], ["route des peches", Vector3(60, 1, 8), 1.45],
	["vue d'ensemble", Vector3(150, 1, 200), 0.3], ["aeroport", Vector3(260, 1, -330), -0.6],
	["ararat (interieur)", Vector3(621, 1, 73), PI], ["terminal (hall)", Vector3(399, 1, -344), 0.0],
	["haie vive (nord)", Vector3(150, 1, -900), 0.8]]
var idx := 0
var samples: Array[float] = []
var budget_dehors := 70.0
var budget_interieur := 60.0
var fails := 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	# -- <qualite 0 a 2> : mesure d'un prereglage graphique (scripts/qualite.gd ; Bas = PC modeste)
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		Qualite.appliquer(scene, int(args[0]))
		print("Qualite : ", Qualite.NOMS[int(args[0])])


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 200:
		return false
	var local := frame - 200 - idx * 400
	var v = views[idx]
	if local == 0:
		player.global_position = v[1]
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(-0.15, v[2], 0)
		samples.clear()
	elif local > 100 and local % 20 == 0:
		samples.append(Engine.get_frames_per_second())
	if local == 399:
		var s := 0.0
		for x in samples:
			s += x
		print("FPS %s : %.0f images/s (min %.0f) | objets dessines %d, primitives %dk" % [v[0], s / samples.size(), samples.min(),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
		var interieur: bool = String(v[0]).contains("interieur") or String(v[0]).contains("hall")
		var budget := budget_interieur if interieur else budget_dehors
		if s / samples.size() < budget:
			fails += 1
			print("ECHEC %s sous le budget de %.0f images/s" % [v[0], budget])
		idx += 1
		if idx >= views.size():
			print("RESULTAT perf : %s" % ("OK" if fails == 0 else "%d vue(s) sous le budget" % fails))
			quit(1 if fails else 0)
			return true
	return false
