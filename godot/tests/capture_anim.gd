extends SceneTree
## Capture des poses du personnage (idle, marche, course, saut) en PNG.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_anim.gd -- <dossier_sortie>

var frame := 0
var model: Node
var cam: Camera3D
var out_dir := "user://"
var states := [
	["idle", 0.0, true, 0.0],
	["marche", 4.0, true, 0.0],
	["course", 8.5, true, 0.0],
	["saut", 3.0, false, 2.0],
]
var idx := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.85, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	ground.mesh = pm
	world.add_child(ground)
	model = load("res://assets/models/chr_joueur.glb").instantiate()
	model.set_script(load("res://scripts/character_anim.gd"))
	world.add_child(model)
	cam = Camera3D.new()
	world.add_child(cam)
	# vue de 3/4 cote droit : l'avant du personnage (-Z) part vers la gauche de l'image
	cam.look_at_from_position(Vector3(3.2, 1.2, -0.8), Vector3(0, 0.9, 0))
	cam.current = true


func _process(_delta: float) -> bool:
	frame += 1
	var st = states[idx]
	model.speed = st[1]
	model.on_floor = st[2]
	model.vertical_speed = st[3]
	if frame == 50:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join("pose_%s.png" % st[0]))
		print("capture ", st[0])
		idx += 1
		frame = 0
		if idx >= states.size():
			return true
	return false
