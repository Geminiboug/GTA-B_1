extends SceneTree
## Profil d'une vue (phase 11) : coupe tour a tour chaque enfant de la scene (et de Lieux) et mesure ce qu'il coute.
## Mode "rendu" (defaut) : groupe cache -> primitives et objets dessines. Mode "cpu" : groupe en pause -> temps des
## scripts et de la physique. Lancement :
## godot --path godot --resolution 1600x900 --script res://tests/profil_vue.gd -- <x> <y> <z> <cap> [qualite] [cpu|rendu] [noeud]
## (noeud : ne profiler que les enfants de ce noeud de la scene, ex. Horizon)

var frame := 0
var scene: Node
var player: CharacterBody3D
var groups: Array[Node] = []
var gi := -1
var base := {}
var acc: Array = []
var cpu := false


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	var a := OS.get_cmdline_user_args()
	Qualite.appliquer(scene, int(a[4]) if a.size() > 4 else 2)
	cpu = a.size() > 5 and a[5] == "cpu"


func _measure() -> Dictionary:
	var m := {"fps": 0.0, "prim": 0.0, "obj": 0.0, "proc": 0.0, "phys": 0.0, "gpu": 0.0}
	for x in acc:
		for k in m:
			m[k] += x[k] / acc.size()
	return m


func _toggle(n: Node, on: bool) -> void:
	if cpu:
		n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	else:
		(n as Node3D).visible = on


func _process(_d: float) -> bool:
	frame += 1
	if frame == 150:
		var a := OS.get_cmdline_user_args()
		player.global_position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(-0.15, float(a[3]), 0)
		var only := scene.get_node_or_null(a[6]) if a.size() > 6 else null
		for c in (only if only else scene).get_children():
			if c != player and (cpu or c is Node3D):
				groups.append(c)
		var lieux := null if only else scene.get_node_or_null("Lieux")
		if lieux:
			for c in lieux.get_children():
				if cpu or c is Node3D:
					groups.append(c)
	if frame < 250:
		return false
	var local := (frame - 250) % 120
	if local > 40 and local % 10 == 0:
		acc.append({"fps": Engine.get_frames_per_second(),
			"prim": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0,
			"obj": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"proc": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"phys": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"gpu": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())})
	if local == 119:
		var m := _measure()
		acc.clear()
		if gi < 0:
			base = m
			print("BASE %.0f img/s, %dk prim, %d obj, GPU %.1f ms, scripts %.1f ms, physique %.1f ms" % [m["fps"], m["prim"], m["obj"], m["gpu"], m["proc"], m["phys"]])
		else:
			_toggle(groups[gi], true)
			print("%-24s -%dk prim  -%d obj  GPU -%.1f ms  scripts -%.1f ms  physique -%.1f ms" % [groups[gi].name, base["prim"] - m["prim"],
				base["obj"] - m["obj"], base["gpu"] - m["gpu"], base["proc"] - m["proc"], base["phys"] - m["phys"]])
		gi += 1
		if gi >= groups.size():
			return true
		_toggle(groups[gi], false)
	return false
