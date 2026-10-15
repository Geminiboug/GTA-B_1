extends SceneTree
## Chaque morphologie en passager de zem (derriere un conducteur), vue de profil : assise, pieds, contact.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_morphos_zem.gd -- <dossier>

const ZEM := preload("res://assets/models/veh_zem.glb")
const VARIANTS := ["homme", "homme_mince", "homme_fort", "homme_age", "femme", "femme_mince", "femme_ronde", "femme_agee",
	"garcon", "fille"]
var frame := 0
var out_dir := ""
var cam: Camera3D
var asm: Node3D
var idx := 0
var shots: Array[Image] = []


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.74, 0.76)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(60), 0)
	root.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 32.0
	cam.position = Vector3(3.6, 1.0, 0.25)
	root.add_child(cam)

	cam.current = true


func _process(_d: float) -> bool:
	frame += 1
	if frame == 1:
		cam.look_at(Vector3(0, 0.85, 0.25), Vector3.UP)
	if frame % 8 != 0:
		return false
	if asm != null:
		shots.append(root.get_viewport().get_texture().get_image())
		asm.queue_free()
		asm = null
		idx += 1
	if idx >= VARIANTS.size():
		var w := shots[0].get_width()
		var h := shots[0].get_height()
		var sheet := Image.create(w * 5, h * 2, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 5) * w, (i / 5) * h))
		sheet.save_png(out_dir.path_join("morphos_zem.png"))
		print("capture morphos_zem")
		return true
	# meme montage que traffic.gd (_build_meshes)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + idx
	asm = Node3D.new()
	root.add_child(asm)
	asm.add_child(ZEM.instantiate())
	var driver := PnjUtil.make("homme")
	asm.add_child(driver)
	PnjUtil.dress_random(driver, rng, "zem")
	driver.scale = Vector3.ONE
	PnjUtil.pose_seated(driver)
	driver.position = Vector3(0, -0.05, 0.12)
	var v: String = VARIANTS[idx]
	var pas := PnjUtil.make(v)
	asm.add_child(pas)
	PnjUtil.dress_random(pas, rng)
	pas.scale = Vector3.ONE
	PnjUtil.pose_passenger(pas)
	pas.position = Vector3(0, -0.02 + (0.04 if pas.get_meta("genre") == "femme" else 0.0), 0.48)
	return false
