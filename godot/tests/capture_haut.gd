extends SceneTree
## Planche : le haut (tee-shirt) vu de dos en plongee (comme la camera du jeu), de trois quarts et de profil,
## homme et femme, au repos et en marche. Sert a reperer les defauts aux epaules et au col.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_haut.gd -- <fichier.png>

var frame := 0
var out := "user://haut.png"
var cam: Camera3D
var chars: Array[Node3D] = []
var shots: Array[Image] = []
const VIEWS := [[Vector3(0.0, 2.1, 1.3), 0], [Vector3(-1.1, 1.7, -1.1), 0], [Vector3(1.6, 1.4, 0.0), 0],
	[Vector3(0.0, 1.4, -1.6), 0], [Vector3(0.9, 1.3, -0.3), 0], [Vector3(0.5, 1.0, -1.2), 0]]
var idx := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.62, 0.7)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	root.add_child(sun)
	for i in 2:
		var ch := PnjUtil.make("homme" if i == 0 else "femme")
		ch.set_script(load("res://scripts/anim_ctrl.gd"))
		ch.set("anim_lod", false)
		root.add_child(ch)
		var col := Color(0.1, 0.5, 0.55)
		PnjUtil.apply(ch, {"skin": PnjUtil.SKINS[0], "top": PnjUtil.plain(col), "legs": PnjUtil.plain(Color(0.2, 0.3, 0.48)),
			"cloth": PnjUtil.plain(Color(0.2, 0.3, 0.48)), "show": ["chr_haut", "chr_pantalon", "chr_chaussures", "chr_cheveux"]})
		ch.position = Vector3(i * 30.0, 0, 0)
		chars.append(ch)
	cam = Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 40:
		return false
	var k := frame - 40
	if k % 12 == 0 and idx < VIEWS.size():
		var v: Array = VIEWS[idx]
		var c: Node3D = chars[v[1]]
		# le personnage regarde -Z (demi-tour de PnjUtil.make) : la camera en +Z le voit de dos
		cam.global_position = c.global_position + v[0]
		cam.look_at(c.global_position + Vector3(0, 1.3, 0), Vector3.UP)
	if k % 12 == 6 and idx < VIEWS.size():
		shots.append(root.get_viewport().get_texture().get_image())
		idx += 1
	if idx == VIEWS.size():
		var wd := shots[0].get_width()
		var ht := shots[0].get_height()
		var sheet := Image.create(wd * 3, ht * 2, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, wd, ht), Vector2i(wd * (i % 3), ht * (i / 3)))
		sheet.resize(wd * 3 / 2, ht)
		sheet.save_png(out)
		print("capture haut")
		return true
	return frame > 1200
