extends SceneTree
## Revue de la carte morceau par morceau (retour d'Olympe du 21/10/2026) : une vue du dessus par tuile de 500 m (routes qui
## s'arretent, batiments isoles, murs, vegetation), enregistrees dans le dossier donne. A assembler avec
## godot/tools/planche_tuiles.py. Lancement (avec fenetre) :
## godot --path godot --resolution 1280x720 --script res://tests/capture_carte_tuiles.gd -- <dossier> [premier] [dernier]
var frame := 0
var scene: Node
var out_dir := "user://"
var cles: Array = []
var i := 0
var debut := 0
var fin := 9999
var phase := 0
var cam: Camera3D
var attente := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	if a.size() > 1:
		debut = int(a[1])
	if a.size() > 2:
		fin = int(a[2])
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 120:
		return false
	var monde: Node = scene.get_node("zone_aeroport")
	if cles.is_empty():
		var t: Dictionary = monde.get("tuiles")
		for k in t:
			cles.append(k)
		cles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		i = debut
		cam = Camera3D.new()
		cam.fov = 55.0
		cam.far = 4000.0
		scene.add_child(cam)
		cam.current = true
		print("tuiles : ", cles.size())
	if i >= cles.size() or i > fin:
		quit()
		return true
	var cle: Vector2i = cles[i]
	var rect: Rect2 = monde.get("tuiles")[cle]["rect"]
	var c := rect.get_center()
	if phase == 0:
		(scene.get_node("Player") as Node3D).global_position = Vector3(c.x, 2.0, c.y)
		scene.get_node("Player").reset_physics_interpolation()
		cam.global_position = Vector3(c.x, 430.0, c.y)
		cam.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
		attente = frame
		phase = 1
	elif phase == 1 and frame - attente > 150:
		root.get_viewport().get_texture().get_image().save_png("%s/tuile_%03d_%d_%d.png" % [out_dir, i, cle.x, cle.y])
		i += 1
		phase = 0
	return false
