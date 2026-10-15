extends SceneTree
## Capture du mode debug (infos + chemins) au carrefour principal.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_debug.gd -- <fichier.png>

var frame := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	var dbg := scene.get_node("Debug")
	if frame == 30:
		dbg.mode = 2
		dbg._apply()
		dbg.teleport(0)
	if frame == 150:
		root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		print("capture debug")
		return true
	return false
