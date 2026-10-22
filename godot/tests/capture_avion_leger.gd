extends SceneTree
## Captures de l'avion leger : au parking (exterieur), pilote assis (porte ouverte), puis en vol vu de derriere.
var frame := 0
var scene: Node
var av: CharacterBody3D
var player: CharacterBody3D
var out_dir := "user://"
var cam: Camera3D


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _snap(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/avl_%s.png" % [out_dir, nom])


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 150:
		av = scene.get_node("AvionLeger")
		player = scene.get_node("Player")
		player.global_position = av.entry_point() + Vector3(0.5, 0.3, 0.0)
		player.reset_physics_interpolation()
		cam = Camera3D.new()
		scene.add_child(cam)
		cam.global_position = av.global_position + Vector3(9, 3.2, 7)
		cam.look_at(av.global_position + Vector3(0, 1.3, 0))
		cam.current = true
	if frame == 190:
		_snap("parking")
		av.call("ouvrir_porte", "porte_g0", true, 0.3)
	if frame == 240:
		_snap("porte")
		player.enter_vehicle(av)
	if frame == 330:
		cam.global_position = av.global_position + Vector3(-5.5, 2.4, 1.5)
		cam.look_at(av.global_position + Vector3(0, 1.3, 0.2))
		_snap("pilote")
		cam.current = false
		(av.get_node("CamRig") as Node3D).call("activate", true)
		av.global_position.y += 120.0
		av.set("_v", -av.global_transform.basis.z * 45.0)
		av.set("gaz", 0.7)
	if frame == 420:
		_snap("vol")
	if frame == 440:
		quit()
		return true
	return false
