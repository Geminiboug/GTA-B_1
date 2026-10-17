extends SceneTree
## Comparaison A/B du temps GPU (phase 11) : depuis une vue, alterne toutes les 40 images le reglage de base et une
## variante (effet coupe, resolution reduite, groupe cache...), 6 fois chacune ; les ecarts restent justes meme si la
## machine chauffe pendant la mesure. Lancement :
## godot --path godot --resolution 1600x900 --script res://tests/ab_gpu.gd -- <x> <y> <z> <cap> [qualite] [noeud : comparer ses enfants | cpu]

var frame := 0
var scene: Node
var we: WorldEnvironment
var sun: DirectionalLight3D
var vi := 0
var rep := 0
var sums := [0.0, 0.0]
var counts := [0, 0]
var variants: Array = []
var cpu := false                  # -- ... cpu : groupes mis en pause, mesure de la duree d'image


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	var a := OS.get_cmdline_user_args()
	Qualite.appliquer(scene, int(a[4]) if a.size() > 4 else 2)
	we = scene.get_node("WorldEnvironment")
	sun = scene.get_node("Sun")
	var e := we.environment
	var vp: Viewport = root
	variants = [
		["ssao coupe", func(on): e.ssao_enabled = not on],
		["ssil coupe", func(on): e.ssil_enabled = false if on else Qualite.PRESETS[int(a[4]) if a.size() > 4 else 2][2]],
		["halo coupe", func(on): e.glow_enabled = not on],
		["brouillard coupe", func(on): e.fog_enabled = not on],
		["resolution 3D 0,5", func(on): vp.scaling_3d_scale = 0.5 if on else Qualite.PRESETS[int(a[4]) if a.size() > 4 else 2][4]],
		["ombre soleil coupee", func(on): sun.shadow_enabled = not on],
		["LOD seuil 8", func(on): vp.mesh_lod_threshold = 8.0 if on else Qualite.PRESETS[int(a[4]) if a.size() > 4 else 2][5]],
	]



func _process(d: float) -> bool:
	frame += 1
	if frame == 150:
		var a := OS.get_cmdline_user_args()
		var p := scene.get_node("Player")
		p.global_position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		p.reset_physics_interpolation()
		p.cam_pivot.rotation = Vector3(-0.15, float(a[3]), 0)
		cpu = a.size() > 5 and a[5] == "cpu"
		if cpu:
			variants.clear()
			for c in scene.get_children():
				if c != p and c.get_child_count() + int(c.get_script() != null) > 0:
					variants.append([String(c.name) + " en pause", func(on): c.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT])
		elif a.size() > 5:
			variants.clear()
			for c in scene.get_node(a[5]).get_children():
				if c is Node3D:
					variants.append([String(c.name) + " cache", func(on): c.visible = not on])
		else:
			for n in ["zone_aeroport", "Vegetation", "Props", "Concessions", "Realisme", "Horizon", "Lieux", "Pietons", "Circulation", "Balisage"]:
				var node := scene.get_node_or_null(n) as Node3D
				if node:
					variants.append([n + " cache", func(on): node.visible = not on])
	if frame < 250:
		return false
	var local := (frame - 250) % 40
	var side := rep % 2              # 0 = base, 1 = variante
	if local > 15:
		sums[side] += d * 1000.0 if cpu else RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		counts[side] += 1
	if local == 39:
		rep += 1
		if rep >= 12:
			var b: float = sums[0] / counts[0]
			var v: float = sums[1] / counts[1]
			print("%-26s %s %.1f -> %.1f ms (%+.1f)" % [variants[vi][0], "image" if cpu else "GPU", b, v, v - b])
			variants[vi][1].call(false)
			vi += 1
			rep = 0
			sums = [0.0, 0.0]
			counts = [0, 0]
			if vi >= variants.size():
				return true
		variants[vi][1].call(rep % 2 == 1)
	return false
