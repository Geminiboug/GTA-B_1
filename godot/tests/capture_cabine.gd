extends SceneTree
## Captures : cabine d'un avion gare (vue vers l'arriere depuis la porte avant), porte ouverte et escalier vus
## de l'exterieur, cabine de l'epave de la plage.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_cabine.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var cam: Camera3D
var out_dir := "user://"
var shots: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 10.0)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.05
	scene.add_child(cam)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		var plane: Node3D = null
		for s in scene.get_node("TraficAerien").stands:
			if s["plane"] != null:
				plane = s["plane"]
				break
		var xf := plane.global_transform
		shots.append(["cabine", xf * Vector3(0.0, 4.1, -15.2), xf * Vector3(0.0, 3.5, 0.0)])
		shots.append(["porte_escalier", xf * Vector3(-14.0, 4.0, -24.0), xf * Vector3(-2.0, 3.0, -15.75)])
		shots.append(["poste_pilotage", xf * Vector3(0.0, 4.2, -16.6), xf * Vector3(0.0, 3.6, -19.0)])
		var pal := scene.find_child("escalier_palier", true, false) as MeshInstance3D
		var c := pal.global_transform * pal.mesh.get_aabb().get_center()
		var m0 := scene.find_child("escalier_marche_0", true, false) as MeshInstance3D
		var c0 := m0.global_transform * m0.mesh.get_aabb().get_center()
		var inward := (c - c0) * Vector3(1, 0, 1)
		inward = inward.normalized()
		var aft := inward.cross(Vector3.UP)
		shots.append(["epave_cabine", c + inward * 1.6 + Vector3(0, 1.5, 0) + aft * 0.3, c + inward * 1.6 + aft * 8.0 + Vector3(0, 1.0, 0)])
		shots.append(["epave_escalier", c0 - inward * 7.0 + Vector3(0, 2.0, 0) + aft * 4.0, c + Vector3(0, 0.8, 0)])
	var i := (frame - 90) / 30
	if frame >= 90 and i < shots.size():
		var s: Array = shots[i]
		if (frame - 90) % 30 == 0:
			cam.global_position = s[1]
			cam.look_at(s[2], Vector3.UP)
			cam.current = true
		elif (frame - 90) % 30 == 20:
			root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("avion_%s.png" % s[0]))
			print("capture ", s[0])
	return frame > 90 + 30 * maxi(shots.size(), 1)
