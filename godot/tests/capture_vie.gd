extends SceneTree
## Captures de la ville vivante (circulation, pietons, vendeurs) apres quelques secondes de simulation.
## Le joueur est place au bord d'un axe, la camera regarde le long de la route.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_vie.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var out_dir := "user://"
var shots := []
var idx := 0


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")


func _view_near_busy_road() -> Array:
	## Trouve l'endroit ou il y a le plus de vehicules et de pietons dans un rayon de 40 m.
	var traffic: Node = scene.get_node("Circulation")
	var best := Vector3.ZERO
	var best_n := -1
	for a in traffic._agents:
		var p: Vector3 = a["vis_pos"]
		var n := 0
		for b in traffic._agents:
			if (b["vis_pos"] as Vector3).distance_to(p) < 40.0:
				n += 1
		if n > best_n:
			best_n = n
			best = p
	return [best, best_n]


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame < 480:
		return false
	var local := frame - 480 - idx * 90
	if local == 0:
		var r := _view_near_busy_road()
		var p: Vector3 = r[0]
		player.global_position = p + Vector3(6, 1, 6)
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(-0.12, atan2(6, 6) + idx * 0.8, 0)
		player.spring_arm.spring_length = 7.0
		print("vue ", idx, " pres de ", p, " (", r[1], " vehicules)")
	elif local == 80:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("vie_%d.png" % idx))
		print("capture vie ", idx)
		idx += 1
		if idx >= 3:
			return true
	return false
