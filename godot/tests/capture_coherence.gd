extends SceneTree
## Captures de controle de la coherence : vues du dessus (carrefours, terre-plein, rues qui arrivent sur la
## promenade) et vues au niveau du joueur (pieds sur la route, zem, voitures garees).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_coherence.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var cam: Camera3D
var out_dir := "user://"
# [nom, centre (x, z), hauteur ou null pour la vue joueur, taille ortho / rotation camera]
var shots := [
	["dessus_jonction", Vector2(220, 25), 60.0, 24.0],
	["dessus_ararat", Vector2(617, 102), 200.0, 175.0],
	["dessus_terminal", Vector2(378, -378), 200.0, 150.0],
	["dessus_maison", Vector2(315, 112), 80.0, 50.0],
	["dessus_ville", Vector2(420, 60), 260.0, 230.0],
	["dessus_aeroport", Vector2(470, -280), 200.0, 170.0],
	["dessus_terre_plein", Vector2(200, 40), 120.0, 90.0],
	["dessus_promenade", Vector2(-90, 140), 120.0, 80.0],
	["sol_joueur", Vector2(43.7, 10.2), -1.0, Vector2(-0.18, 1.45)],
	["rue_garees", Vector2(420, -20), -1.0, Vector2(-0.15, 0.6)],
	["jonction_sol", Vector2(222, 34), -1.0, Vector2(-0.25, 0.0)],
]
var idx := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.far = 1000.0
	scene.add_child(cam)


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame < 40:
		return false
	var s = shots[idx]
	var local := frame - 40 - idx * 70
	if local == 0:
		var c: Vector2 = s[1]
		if float(s[2]) > 0.0:
			cam.size = float(s[3])
			cam.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(c.x, float(s[2]), c.y))
			cam.current = true
			player.global_position = Vector3(c.x, 1.0, c.y)
		else:
			cam.current = false
			(player.get_node("CamPivot/SpringArm3D/Camera3D") as Camera3D).current = true
			player.global_position = Vector3(c.x, 1.0, c.y)
			player.velocity = Vector3.ZERO
			player.reset_physics_interpolation()
			player.cam_pivot.rotation = Vector3(s[3].x, s[3].y, 0)
			player.spring_arm.spring_length = 3.5
		if s[0] == "sol_joueur":
			var zem: Node3D = scene.get_node("Zem")
			zem.global_position = Vector3(c.x + 1.8, 0.5, c.y - 0.5)
	elif local == 60:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("coh_%s.png" % s[0]))
		print("capture ", s[0])
		idx += 1
		if idx >= shots.size():
			return true
	return false
