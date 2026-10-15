extends SceneTree
## Captures des personnages en jeu : une passante, un passant, des vendeuses assises, le joueur (homme puis femme).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_pnj.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var peds: Node
var out_dir := "user://"
var step := 0
var shots := ["vendeurs", "femme", "homme", "joueur_homme", "joueur_femme"]
var cam: Camera3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	peds = scene.get_node("Pietons")
	cam = Camera3D.new()
	cam.fov = 50.0
	scene.add_child(cam)


func _look_at_point(target: Vector3, dist: float, side_angle: float, h := 1.4) -> void:
	## Camera independante face a la cible (le joueur est mis a l'ecart pour ne pas boucher la vue).
	var dir := Vector3(-sin(side_angle), 0, -cos(side_angle))
	player.global_position = target + Vector3(30, 1, 30)
	player.reset_physics_interpolation()
	cam.global_position = target + dir * dist + Vector3(0, h, 0)
	cam.look_at(target + Vector3(0, h * 0.75, 0), Vector3.UP)
	cam.current = true


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	var local := frame - 60 - step * 50
	if local == 0:
		var name: String = shots[step]
		if name == "femme" or name == "homme":
			for w in peds._walkers:
				var ch: Node3D = w["node"]
				if ch.get_meta("genre", "") == name and not w["prom"]:
					w["pause"] = 30.0
					_look_at_point(ch.global_position, 3.2, ch.global_rotation.y)
					break
		elif name == "vendeurs":
			var props: Node = scene.get_node("Props")
			var t: Transform3D = props.vendor_spots[3]
			var fwd := -t.basis.z
			_look_at_point(t.origin, 3.6, atan2(-fwd.x, -fwd.z) + 1.7, 1.5)
		elif name == "joueur_homme":
			(player.get_node("CamPivot/SpringArm3D/Camera3D") as Camera3D).current = true
			player.global_position = Vector3(43.7, 1, 10.2)
			player.reset_physics_interpolation()
			player.cam_pivot.rotation = Vector3(-0.1, PI, 0)
			player.spring_arm.spring_length = 2.4
		elif name == "joueur_femme":
			player.set_genre("femme")
	elif local == 40:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("pnj_%s.png" % shots[step]))
		print("capture ", shots[step])
		step += 1
		if step >= shots.size():
			return true
	return false
