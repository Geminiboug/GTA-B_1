extends SceneTree
## Captures de l'explosion d'une voiture : feu naissant, boule de feu, epave qui fume.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_explosion.gd -- <dossier>
var frame := 0
var scene: Node
var car: Node3D
var cam: Camera3D
var out_dir := "user://"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _snap(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/expl_%s.png" % [out_dir, nom])


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 120:
		var pl := scene.get_node("Player") as Node3D
		car = Vehicules.create("veh_berline", Color(0.7, 0.1, 0.1))
		scene.add_child(car)
		car.global_position = Vector3(43.7, 0.5, 6.0)
		car.set("delai_explosion", 3.0)
		pl.global_position = Vector3(30, 1, 6)
		cam = Camera3D.new()
		scene.add_child(cam)
		cam.global_position = Vector3(36, 3.0, 12)
		cam.look_at(Vector3(43.7, 1.0, 6.0))
		cam.current = true
		car.call("damage", 90.0)
	if frame == 120 + 183:
		_snap("a183")
	if frame == 120 + 205:
		var ex := scene.get_node_or_null("Explosion")
		print("DBG explosion: ", ex)
		if ex:
			for c in ex.get_children():
				print("  ", c.name, " ", c.get_class(), " emitting ", c.get("emitting"), " pos ", (c as Node3D).global_position, " vis ", (c as Node3D).is_visible_in_tree())
		print("DBG voiture ", car.global_position, " epave ", car.get("epave"))
		_snap("boule")
	if frame == 120 + 192:
		_snap("a192")
	if frame == 120 + 260:
		quit()
		return true
	return false
