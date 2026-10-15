extends SceneTree
## Voitures de la circulation vues de cote : conducteur visible a travers les vitres.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_conducteurs.gd -- <dossier>

var frame := 0
var scene: Node
var cam: Camera3D
var out_dir := ""
var shots := 0
var zems: Array = []


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 10.5)
	cam = Camera3D.new()
	cam.fov = 40.0
	scene.add_child(cam)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		for a in scene.get_node("Circulation").get("_agents"):
			if a["kind"] == "voiture":
				zems.append(a)
		print("zems : ", zems.size())
	if frame >= 60 and frame % 20 == 0 and shots < 4 and shots < zems.size():
		var a: Dictionary = zems[shots * 3 % zems.size()]
		var body: Node3D = a["body"]
		var xf := body.global_transform
		var back := xf.basis.z.normalized()
		cam.global_position = body.global_position + back * (2.5 if shots % 2 else -2.5) - xf.basis.x * 3.2 + Vector3(0, 1.6, 0)
		cam.look_at(body.global_position + Vector3(0, 1.05, 0), Vector3.UP)
		cam.current = true
	if frame >= 60 and frame % 20 == 10 and shots < 4 and shots < zems.size():
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("conducteur_%d.png" % shots))
		print("capture conducteur_", shots)
		shots += 1
	return shots >= 4 or frame > 400
