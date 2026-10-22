extends SceneTree
## Une capture depuis un point de vue donne (revue des textures et des modeles).
## Lancement (avec fenetre) : godot --path godot --resolution 1280x720 --script res://tests/capture_vue.gd -- <fichier.png> <x> <y> <z> <cx> <cy> <cz>
var frame := 0
var scene: Node
var cam: Camera3D
var args := OS.get_cmdline_user_args()


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	var p := Vector3(float(args[1]), float(args[2]), float(args[3]))
	var c := Vector3(float(args[4]), float(args[5]), float(args[6]))
	if frame == 30 and args.size() > 7:
		var jn := scene.get_node("JourNuit")
		jn.set("hour", float(args[7]))
		jn.set("minutes_per_game_day", 100000.0)
	if frame == 60:
		cam = Camera3D.new()
		cam.far = 3000.0
		scene.add_child(cam)
		(scene.get_node("Player") as Node3D).global_position = Vector3(p.x, 1.0, p.z)
	if frame > 60:
		for n in scene.get_children():
			if n is CanvasLayer:
				n.visible = false
		cam.global_position = p
		cam.look_at(c)
		cam.current = true
		(scene.get_node("Player") as Node3D).global_position = Vector3(p.x, 1.0, p.z)
	if frame == 260:
		root.get_viewport().get_texture().get_image().save_png(args[0])
		quit()
		return true
	return false
