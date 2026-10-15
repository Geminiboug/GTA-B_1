extends SceneTree
## Studio : chaque personnage seul, eclairage neutre, vues de face, trois quarts et profil (une image par modele).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_studio.gd -- <dossier> [chr_homme ...]

const VIEWS := [0.0, 0.7, PI / 2]
var frame := 0
var out_dir := ""
var models: Array = []
var idx := 0
var view := 0
var cam: Camera3D
var current: Node3D
var shots: Array[Image] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	models = Array(args.slice(1)) if args.size() > 1 else ["chr_homme", "chr_homme_fort", "chr_femme", "chr_femme_ronde", "chr_garcon", "chr_fille"]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.74, 0.76)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.78)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	floor_mi.mesh = pm
	root.add_child(floor_mi)
	cam = Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true


func _process(_d: float) -> bool:
	frame += 1
	if frame % 6 != 0:
		return false
	if current == null:
		if idx >= models.size():
			return true
		current = PnjUtil.make(String(models[idx]).trim_prefix("chr_"))
		root.add_child(current)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + idx                       # tenue tiree comme en jeu (une seule tenue visible)
		PnjUtil.dress_random(current, rng)
		current.scale = Vector3.ONE
		view = 0
		shots.clear()
		return false
	if view > 0:
		shots.append(root.get_viewport().get_texture().get_image())
	if view >= VIEWS.size():
		# planche : les trois vues cote a cote
		var w := shots[0].get_width()
		var h := shots[0].get_height()
		var sheet := Image.create(w * shots.size(), h, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
		sheet.save_png(out_dir.path_join("studio_%s.png" % models[idx]))
		print("capture studio_", models[idx])
		current.queue_free()
		current = null
		idx += 1
		return false
	var a: float = VIEWS[view]
	cam.position = Vector3(sin(a) * 4.2, 1.0, -cos(a) * 4.2)
	cam.look_at(Vector3(0, 0.88, 0), Vector3.UP)
	view += 1
	return false
