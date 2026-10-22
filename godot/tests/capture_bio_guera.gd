extends SceneTree
## Captures du monument Bio Guera (rond-point Erevan).
var frame := 0
var scene: Node
var out_dir := "user://"


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _snap(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/bio_%s.png" % [out_dir, nom])


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 120:
		(scene.get_node("Player") as Node3D).global_position = Vector3(679, 1, -45)
		var cam := Camera3D.new()
		scene.add_child(cam)
		cam.global_position = Vector3(679 + 9, 4.0, -30 - 14)
		cam.look_at(Vector3(679, 7.0, -30))
		cam.current = true
	if frame == 200:
		_snap("face")
	if frame == 205:
		quit()
		return true
	return false
