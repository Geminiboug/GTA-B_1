extends SceneTree
## Capture des commandes tactiles (lancement : godot --path godot --script res://tests/capture_tactile.gd -- <dossier> --tactile)
var frame := 0
var scene: Node
var out := ""
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		var t := scene.get_node("Tactile")
		t.call("_placer_joy", Vector2(260, 760))
		t.set("_joy_centre", Vector2(220, 780))
		t.call("_placer_joy", Vector2(270, 740))
		(t.get("_base") as Control).visible = true
		(t.get("_bouton_joy") as Control).visible = true
	if frame == 90:
		root.get_viewport().get_texture().get_image().save_png(out.path_join("tactile.png"))
		quit()
		return true
	return false
