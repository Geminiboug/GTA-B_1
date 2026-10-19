extends SceneTree
## Captures pour l'ecran de chargement (assets/ui/chargement/) : quelques lieux du jeu en fin d'apres-midi, sans HUD,
## en 1920x1080. Lancement (avec fenetre) : godot --path godot --script res://tests/capture_ecran_chargement.gd -- <dossier> [sans_textures]

var frame := 0
var scene: Node
var player: CharacterBody3D
var cam: Camera3D
var out_dir := "user://"
var step := -1
var t_shot := 0
const PER_SHOT := 120


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	if "sans_textures" in args:      # comparaison avant / apres les textures de matiere
		scene.get_node("Realisme").set("textures_matieres", false)
	root.add_child(scene)
	player = scene.get_node("Player")
	cam = Camera3D.new()
	cam.fov = 60.0
	scene.add_child(cam)


func _marker(lieu: String, n: String) -> Node3D:
	return scene.get_node("Lieux/Lieu_" + lieu).find_child(n, true, false) as Node3D


func _porte(lieu: String) -> Array:
	var g := _marker(lieu, "porte_coulissante_%s_g" % lieu).global_position
	var d := _marker(lieu, "porte_coulissante_%s_d" % lieu).global_position
	var mid := (g + d) * 0.5
	var s := _marker(lieu, "texte_%s_enseigne" % lieu).global_position
	return [mid, Vector3(s.x - mid.x, 0, s.z - mid.z).normalized(), (d - g).normalized()]


func _sol(x: float, z: float) -> Vector3:
	var space := scene.get_viewport().world_3d.direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -10, z))
	q.collision_mask = 1
	var r := space.intersect_ray(q)
	return r["position"] if not r.is_empty() else Vector3(x, 0, z)


## [nom, heure, fonction qui place camera et joueur]
var shots := [
	["ararat", 16.8, func() -> void:
		var f := _porte("ararat")
		_vise(f[0] + f[1] * 22.0 + f[2] * 9.0 + Vector3(0, 2.2, 0), f[0] + Vector3(0, 4.5, 0), f[0] + f[1] * 7.0 + f[2] * 3.0)],
	["terminal", 17.2, func() -> void:
		var f := _porte("terminal")
		_vise(f[0] + f[1] * 24.0 + f[2] * 16.0 + Vector3(0, 2.2, 0), f[0] - f[2] * 6.0 + Vector3(0, 5.0, 0), f[0] + f[1] * 8.0 + f[2] * 5.0)],
	["route_peches", 17.6, func() -> void:
		var p := _sol(60, 8)
		_vise(p + Vector3(-3, 2.0, 4), p + Vector3(14, 1.2, -8), p + Vector3(2, 0, 0))],
	["quartier", 16.2, func() -> void:
		var p := _sol(300, 120)
		_vise(p + Vector3(5, 2.4, 5), p + Vector3(-12, 1.0, -10), p + Vector3(1, 0, 1))],
	["epave", 17.9, func() -> void:
		var p := Vector3(-177, 0.2, 247)
		_vise(p + Vector3(-22, 3.0, -20), p + Vector3(0, 3.0, 0), p + Vector3(-12, 0, -11))],
]


func _vise(from: Vector3, to: Vector3, joueur: Vector3) -> void:
	player.global_position = joueur + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(to.x, player.global_position.y, to.z), Vector3.UP)
	player.reset_physics_interpolation()
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	cam.current = true


func _physics_process(_d: float) -> bool:
	frame += 1
	for c in scene.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	if step < 0:
		if frame < 60 or not scene.get_node("Props").get("placed"):
			return frame > 6000
		step = 0
		t_shot = 0
	t_shot += 1
	if t_shot == 1:
		scene.get_node("JourNuit").set("hour", shots[step][1])
		(shots[step][2] as Callable).call()
	elif t_shot == PER_SHOT:
		var nom: String = shots[step][0]
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % nom))
		print("capture ", nom)
		step += 1
		t_shot = 0
		if step >= shots.size():
			return true
	return false
