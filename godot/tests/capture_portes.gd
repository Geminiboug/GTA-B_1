extends SceneTree
## Capture des portes articulees : voiture portes fermees, portiere conducteur ouverte, puis toutes les portes ouvertes.
var frame := 0
var scene: Node
var car: Node3D
var out_dir := "user://"
var model := "veh_berline"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	if a.size() > 1:
		model = a[1]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _snap(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/porte_%s_%s.png" % [out_dir, model, nom])


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 120:
		(scene.get_node("Player") as Node3D).global_position = Vector3(30, 1, 6)
		car = Vehicules.create(model, Color(0.7, 0.1, 0.1))
		scene.add_child(car)
		car.global_position = Vector3(43.7, 0.4, 6.0)
		var cam := Camera3D.new()
		scene.add_child(cam)
		cam.global_position = Vector3(43.7 - 4.2, 2.2, 6.0 + 2.2)
		cam.look_at(Vector3(43.7, 0.9, 6.0))
		cam.current = true
	if frame == 160:
		print("DBG portes: ", car.get("_portes").keys(), " enfants: ", car.get_node("Visual").get_children().map(func(n): return n.name))
		_snap("fermees")
		car.call("ouvrir_porte", "porte_g0", true, 0.3)
	if frame == 220:
		_snap("g0")
		car.call("ouvrir_porte", "porte_g1", true, 0.3)
		car.call("ouvrir_porte", "porte_d0", true, 0.3)
	if frame == 280:
		_snap("toutes")
		quit()
		return true
	return false
