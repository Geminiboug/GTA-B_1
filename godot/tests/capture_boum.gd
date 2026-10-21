extends SceneTree
## Capture directe de Explosion.boum (sans voiture) : 10, 30 et 60 images apres.
var frame := 0
var scene: Node
var out_dir := "user://"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 120:
		(scene.get_node("Player") as Node3D).global_position = Vector3(30, 1, 6)
		var cam := Camera3D.new()
		scene.add_child(cam)
		cam.global_position = Vector3(36, 3.0, 12)
		cam.look_at(Vector3(43.7, 2.0, 6.0))
		cam.current = true
		Explosion.boum(scene, Vector3(43.7, 1.0, 6.0), 9.0, null)
	for k in [10, 30, 60]:
		if frame == 120 + k:
			root.get_viewport().get_texture().get_image().save_png("%s/boum_%d.png" % [out_dir, k])
	if frame == 200:
		quit()
		return true
	return false
