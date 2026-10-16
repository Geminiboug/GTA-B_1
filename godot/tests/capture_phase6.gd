extends SceneTree
## Planche phase 6 : concessions (murs d'enceinte et portails) dans une rue de quartier, vue d'ensemble, puis la meme
## vue sous l'harmattan (brume seche ocre).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_phase6.gd -- <fichier.png>

var frame := 0
var scene: Node
var out := "user://phase6.png"
var shots: Array[Image] = []
var cam: Camera3D
const VIEWS := [[Vector3(300, 3.0, 128), Vector3(285, 1.0, 110)], [Vector3(330, 60, 200), Vector3(300, 0, 110)]]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 10.0)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 4000.0
	scene.add_child(cam)


func _view(i: int) -> void:
	cam.global_position = VIEWS[i][0]
	cam.look_at(VIEWS[i][1], Vector3.UP)
	cam.current = true


func _process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		print("concessions : ", scene.get_node("Concessions").get("count"))
		_view(0)
	if frame == 90:
		shots.append(root.get_viewport().get_texture().get_image())
		_view(1)
	if frame == 120:
		shots.append(root.get_viewport().get_texture().get_image())
		var w := scene.get_node("Meteo")
		w.call("_set_episode", "harmattan")
		w.set("_target_harmattan", 1.0)
		w.set("harmattan", 1.0)
		_view(0)
	if frame == 150:
		shots.append(root.get_viewport().get_texture().get_image())
		_view(1)
	if frame == 180:
		shots.append(root.get_viewport().get_texture().get_image())
		var wd := shots[0].get_width()
		var ht := shots[0].get_height()
		var sheet := Image.create(wd * 2, ht * 2, false, shots[0].get_format())
		for i in 4:
			sheet.blit_rect(shots[i], Rect2i(0, 0, wd, ht), Vector2i(wd * (i % 2), ht * (i / 2)))
		sheet.resize(wd, ht)
		sheet.save_png(out)
		print("capture phase 6")
		return true
	return frame > 1500
