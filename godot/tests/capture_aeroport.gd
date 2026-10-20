extends SceneTree
## Vue aerienne de l'aeroport (piste, voies de circulation, aire de stationnement) pour comparer au vrai plan.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_aeroport.gd -- <fichier.png> [x z hauteur]
var frame := 0
var scene: Node
var cam: Camera3D
var out := "user://aeroport.png"
var centre := Vector3(0, 0, -570)
var haut := 1400.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 3:
		centre = Vector3(float(args[1]), 0, float(args[2]))
		haut = float(args[3])
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 6000.0
	scene.add_child(cam)
	scene.get_node("JourNuit").set("hour", 12.0)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		(scene.get_node("Player") as Node3D).global_position = centre + Vector3(0, 1, 0)
	if frame > 30:
		cam.global_position = centre + Vector3(0, haut, 1.0)
		cam.look_at(centre, Vector3.UP)
		cam.current = true
	if frame == 900:
		root.get_viewport().get_texture().get_image().save_png(out)
		print("capture aeroport")
		return true
	return false
