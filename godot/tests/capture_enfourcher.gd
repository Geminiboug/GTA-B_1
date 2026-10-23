extends SceneTree
## Sequence de montee sur un zem (6 images pendant l'enfourchement). Lancement (avec fenetre) :
## godot --path godot --resolution 1280x720 --script res://tests/capture_enfourcher.gd -- <dossier>

var frame := 0
var scene: Node
var cam: Camera3D
var out_dir := "user://"
var v: Node3D
var n := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 11.0)
	cam = Camera3D.new()
	cam.fov = 40.0
	scene.add_child(cam)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 90:
		return false
	var pl := scene.get_node("Player") as CharacterBody3D
	if frame == 90:
		v = Vehicules.create("zem", Color(0.75, 0.15, 0.1))
		v.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 320))
		scene.add_child(v)
		pl.global_position = Vector3(-1.3, 0.3, 320.3)
		pl.set("_facing", -PI / 2.0 * -1.0)
	if frame == 110:
		pl.enter_vehicle(v)
	if frame >= 110 and frame < 110 + 40 and (frame - 110) % 5 == 0 and n < 6:
		var c := v.global_position + Vector3(-0.3, 1.0, 0)
		cam.global_position = c + Vector3(-3.0, 0.4, 0.8)
		cam.look_at(c, Vector3.UP)
		cam.current = true
		root.get_viewport().get_texture().get_image().save_png("%s/enfourche_%d.png" % [out_dir, n])
		n += 1
	return frame > 160
