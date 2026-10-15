extends SceneTree
## Planche des tenues : police fictive (homme, femme), agent de l'aeroport, zemidjan (casque), maillots de clubs
## fictifs, tenues au hasard (wax, boubou...). Vue de trois quarts, fond neutre.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_tenues.gd -- <dossier>

var frame := 0
var out_dir := ""
var cam: Camera3D
var current: Node3D
var idx := 0
var shots: Array[Image] = []
# [variante, tenue] ; tenue : uniforme, "zem", "maillot", ou "" (au hasard)
var cases := [["homme", "police"], ["femme", "police"], ["homme_fort", "agent_aeroport"], ["homme", "zem"],
	["homme_mince", "maillot"], ["garcon", "maillot"], ["femme_ronde", ""], ["homme_age", ""]]


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.74, 0.76)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	sun.light_energy = 1.5
	root.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true


func _process(_d: float) -> bool:
	frame += 1
	if frame == 1:
		cam.position = Vector3(1.6, 1.0, -3.4)
		cam.look_at(Vector3(0, 0.88, 0), Vector3.UP)
	if frame % 6 != 0:
		return false
	if current != null:
		shots.append(root.get_viewport().get_texture().get_image())
		current.queue_free()
		current = null
		idx += 1
	if idx >= cases.size():
		var w := shots[0].get_width()
		var h := shots[0].get_height()
		var sheet := Image.create(w * 4, h * 2, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 4) * w, (i / 4) * h))
		sheet.save_png(out_dir.path_join("tenues.png"))
		print("capture tenues")
		return true
	var c: Array = cases[idx]
	current = PnjUtil.make(c[0])
	root.add_child(current)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21 + idx * 5
	var genre: String = current.get_meta("genre")
	if c[1] in ["police", "agent_aeroport"]:
		PnjUtil.apply(current, PnjUtil.uniform_look(c[1], genre, rng))
	elif c[1] == "zem":
		var look := PnjUtil.random_look(current, rng, "zem")
		while not (look["show"] as Array).has("chr_casque"):
			look = PnjUtil.random_look(current, rng, "zem")
		PnjUtil.apply(current, look)
	elif c[1] == "maillot":
		var look := PnjUtil.random_look(current, rng)
		look["top"] = PnjUtil.jersey(idx, 0.76 if c[0] == "garcon" else 1.0)
		look["show"] = ["chr_haut", "chr_short", "chr_semelle", "chr_cheveux"]
		PnjUtil.apply(current, look)
	else:
		PnjUtil.dress_random(current, rng)
	current.scale = Vector3.ONE
	return false
