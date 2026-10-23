extends SceneTree
## Capture d'un carrefour a feux (poteaux, passages pietons, lignes d'arret) et d'un STOP.
## Lancement (avec fenetre) : godot --path godot --resolution 1280x720 --script res://tests/capture_carrefour.gd -- <dossier>

var frame := 0
var scene: Node
var cam: Camera3D
var out_dir := "user://"
var cibles: Array = []
var i := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 10.0)
	cam = Camera3D.new()
	cam.fov = 60.0
	scene.add_child(cam)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 120:
		return false
	var sg = scene.get_node("Circulation")._signal
	var carte := Carte.zone()
	if cibles.is_empty():
		var feux: Array = sg._feux.keys()
		var stops: Array = sg._stops.keys()
		# les noeuds les plus proches du depart du joueur
		var p0 := Vector2(scene.get_node("Player").global_position.x, scene.get_node("Player").global_position.z)
		feux.sort_custom(func(x, y): return carte.nodes[x].distance_to(p0) < carte.nodes[y].distance_to(p0))
		stops.sort_custom(func(x, y): return carte.nodes[x].distance_to(p0) < carte.nodes[y].distance_to(p0))
		cibles = [carte.nodes[feux[0]], carte.nodes[stops[0]]]
	var k := (frame - 120) % 150
	if i >= cibles.size():
		return true
	var c: Vector2 = cibles[i]
	var pl := scene.get_node("Player") as Node3D
	if k == 0:
		pl.global_position = Vector3(c.x, 1.0, c.y + 14.0)
		pl.reset_physics_interpolation()
	elif k == 100:
		cam.global_position = Vector3(c.x + 9.0, 8.0, c.y + 20.0)
		cam.look_at(Vector3(c.x, 2.5, c.y), Vector3.UP)
		cam.current = true
	elif k == 140:
		root.get_viewport().get_texture().get_image().save_png("%s/carrefour_%d.png" % [out_dir, i])
		i += 1
	return false
