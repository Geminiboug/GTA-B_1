extends SceneTree
## Capture : une fresque peinte (activites.gd) vue de la rue.
var frame := 0
var scene: Node
var out := ""
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _process(_d: float) -> bool:
	frame += 1
	if frame == 40:
		scene.get_node("JourNuit").set("hour", 10.0)
		var f: Node3D = scene.get_node("Activites")._fresques[3]["node"]
		var cam := Camera3D.new()
		scene.add_child(cam)
		cam.global_position = f.global_position + f.global_transform.basis.z * 7.0 + Vector3(2, -0.4, 0)
		cam.look_at(f.global_position, Vector3.UP)
		cam.current = true
		(scene.get_node("HUDJeu") as CanvasLayer).visible = false
		(scene.get_node("HUD") as CanvasLayer).visible = false
	if frame == 90:
		root.get_viewport().get_texture().get_image().save_png(out.path_join("fresque.png"))
		quit()
		return true
	return false
