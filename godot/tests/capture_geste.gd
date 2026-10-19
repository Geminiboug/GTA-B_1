extends SceneTree
## Capture image par image d'un geste joue par le vrai controleur (anim_ctrl.gd), cadre sur le buste et les mains :
## planche de vignettes (une toutes les `pas` s). Sert a voir les defauts de peau (poignets, mains) d'un clip.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_geste.gd -- <dossier> [variante] [clip] [duree] [graine] [reduction] [amplitude]

var frame := 0
var out_dir := ""
var cam: Camera3D
var ch: Node3D
var clip := "Idle_Talking"
var duree := 4.0
var pas := 0.15
var images: Array[Image] = []
var t := 0.0
var lance := false
var reduction := 3
var amplitude := 1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	var variante := args[1] if args.size() > 1 else "femme"
	if args.size() > 2:
		clip = args[2]
	if args.size() > 3:
		duree = float(args[3])
	if args.size() > 5:
		reduction = int(args[5])
	if args.size() > 6:
		amplitude = float(args[6])
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.74, 0.76)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.87)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(30), 0)
	root.add_child(sun)
	ch = PnjUtil.make(variante)
	ch.set_script(preload("res://scripts/anim_ctrl.gd"))
	ch.set("anim_lod", false)
	root.add_child(ch)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[4]) if args.size() > 4 else 1     # tenue fixe (5e argument : autre graine)
	PnjUtil.dress_random(ch, rng)
	var portes := []
	for m in ch.find_children("chr_*", "MeshInstance3D", true, false):
		if (m as Node3D).visible:
			portes.append(m.name)
	print("tenue : ", portes)
	ch.scale = Vector3.ONE
	cam = Camera3D.new()
	cam.fov = 26.0
	root.add_child(cam)
	cam.current = true


func _process(delta: float) -> bool:
	frame += 1
	if frame == 2:
		cam.position = Vector3(0.7, 1.2, -1.9)     # de trois quarts face (le personnage regarde -Z)
		cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	if frame < 40:
		return false
	if not lance:
		ch.call("play_clips", [[clip, 0.0]], true, 1.0, amplitude)
		lance = true
		t = 0.0
		return false
	t += delta
	if images.size() < int(duree / pas) and t >= images.size() * pas:
		var im := root.get_viewport().get_texture().get_image()
		im.resize(im.get_width() / reduction, im.get_height() / reduction)
		images.append(im)
		return false
	if images.size() < int(duree / pas):
		return false
	# planche : 8 vignettes par ligne
	var w := images[0].get_width()
	var h := images[0].get_height()
	var cols := 8
	var lignes := (images.size() + cols - 1) / cols
	var planche := Image.create(w * cols, h * lignes, false, images[0].get_format())
	for i in images.size():
		planche.blit_rect(images[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	planche.save_png(out_dir.path_join("geste_%s.png" % clip))
	print("planche ", images.size(), " images")
	return true
