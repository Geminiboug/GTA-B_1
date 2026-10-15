extends SceneTree
## Captures en jeu des modeles refaits : berline, 4x4, minibus (garees cote a cote, conducteur assis), epave de la plage.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_modeles.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var cam: Camera3D
var out_dir := "user://"
var shots := [
	["voitures", Vector3(-9.0, 2.2, 7.5), Vector3(0, 0.8, 0)],
	["voitures_arriere", Vector3(8.0, 2.0, -8.0), Vector3(0, 0.8, 0)],
	["epave", Vector3(-177 + 30, 7, 247 - 32), Vector3(-177, 3, 247)],
	["epave_pres", Vector3(-177 + 3, 2.2, 247 - 16), Vector3(-177 - 4, 2.5, 247)],
]
var base := Vector3(0, 0, 322)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 10.0)
	cam = Camera3D.new()
	cam.fov = 50.0
	scene.add_child(cam)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		var k := 0
		for m in ["veh_berline", "veh_4x4", "veh_minibus"]:
			var car := Vehicules.create(m, [Color(0.75, 0.1, 0.08), Color(0.9, 0.9, 0.88), Color(0.95, 0.75, 0.1)][k])
			car.transform = Transform3D(Basis(Vector3.UP, 0.4), base + Vector3(k * 3.0 - 3.0, 0.2, 0))
			scene.add_child(car)
			k += 1
	var i := (frame - 90) / 30
	if frame >= 90 and i < shots.size():
		var s: Array = shots[i]
		var off := base if i < 2 else Vector3.ZERO
		if (frame - 90) % 30 == 0:
			cam.global_position = off + s[1]
			cam.look_at(off + s[2], Vector3.UP)
			cam.current = true
		elif (frame - 90) % 30 == 20:
			root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("modele_%s.png" % s[0]))
			print("capture ", s[0])
	return frame > 90 + 30 * shots.size()
