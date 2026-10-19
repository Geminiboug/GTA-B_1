extends SceneTree
## Captures de la porte avant gauche et du poste de pilotage d'un avion gare (exterieur, de trois quarts avant et de
## dessus) : rien ne doit depasser de la carlingue (cloisons, planchers).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_avion_porte.gd -- <dossier_sortie>
var frame := 0
var scene: Node
var cam: Camera3D
var out_dir := "user://"
var plane: Node3D
var vues := [["porte", Vector3(-9.0, 4.0, -11.0), Vector3(-1.9, 3.4, -16.5)],
	["nez", Vector3(-7.0, 6.0, -26.0), Vector3(0.0, 3.5, -18.0)],
	["dessus", Vector3(-4.0, 11.0, -17.0), Vector3(0.0, 3.0, -17.5)],
	["droite", Vector3(8.0, 4.0, -13.0), Vector3(1.9, 3.4, -17.0)]]
var vi := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	cam = Camera3D.new()
	cam.fov = 45.0
	scene.add_child(cam)
	scene.get_node("JourNuit").set("hour", 10.0)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	if plane == null:
		for s in scene.get_node("TraficAerien").stands:
			if s["plane"] != null:
				plane = s["plane"]
				break
		if plane == null:
			return frame > 600
	var k := frame - 60
	if k % 40 == 0:
		var v: Array = vues[vi]
		var xf := plane.global_transform
		cam.global_position = xf * (v[1] as Vector3)
		cam.look_at(xf * (v[2] as Vector3), Vector3.UP)
		cam.current = true
	elif k % 40 == 30:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("porte_%s.png" % vues[vi][0]))
		print("capture ", vues[vi][0])
		vi += 1
		if vi >= vues.size():
			return true
	return false
