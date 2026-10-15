extends SceneTree
## Planche de visages : 8 tirages (traits, peau, coiffure, tenue) d'une morphologie, cadres sur la tete, trois quarts.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_visages.gd -- <dossier> [variante]

const N := 8
var frame := 0
var out_dir := ""
var variant := "homme"
var cam: Camera3D
var current: Node3D
var idx := 0
var shots: Array[Image] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	if args.size() > 1:
		variant = args[1]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.7, 0.72, 0.74)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-30), deg_to_rad(-25), 0)
	sun.light_energy = 1.5
	root.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 22.0
	root.add_child(cam)
	cam.current = true


func _process(_d: float) -> bool:
	frame += 1
	if frame % 6 != 0:
		return false
	if current != null:
		shots.append(root.get_viewport().get_texture().get_image())
		current.queue_free()
		current = null
		idx += 1
	if idx >= N:
		var w := shots[0].get_width()
		var h := shots[0].get_height()
		var sheet := Image.create(w * 4, h * 2, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * w, (i / 4) * h))
		sheet.save_png(out_dir.path_join("visages_%s.png" % variant))
		print("capture visages_", variant)
		return true
	current = PnjUtil.make(variant)
	root.add_child(current)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + idx * 7
	PnjUtil.dress_random(current, rng)
	current.scale = Vector3.ONE
	# cadrage sur la tete (sommet du corps)
	var body := current.find_child("chr_corps", true, false) as MeshInstance3D
	var top := body.mesh.get_aabb().end.y
	var head := Vector3(0, top - 0.12, 0.02)
	cam.position = head + Vector3(0.45, 0.04, -0.75)
	cam.look_at(head, Vector3.UP)
	return false
