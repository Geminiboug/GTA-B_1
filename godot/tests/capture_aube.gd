extends SceneTree
## Captures de l'aube sur Cotonou (ecran de chargement) a plusieurs instants de l'animation.
## Lancement (avec fenetre) : godot --path godot --resolution 1280x720 --script res://tests/capture_aube.gd -- <dossier>
var ch: Node
var out := ""
var instants := [1.0, 3.0, 4.8, 8.0]
var i := 0


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	ch = (load("res://scenes/chargement.tscn") as PackedScene).instantiate()
	root.add_child(ch)
	current_scene = ch


func _process(_d: float) -> bool:
	if not is_instance_valid(ch) or i >= instants.size():
		quit()
		return true
	var a: Node = ch.get("_aube")
	if a != null and float(a.get("t")) >= float(instants[i]):
		root.get_viewport().get_texture().get_image().save_png(out.path_join("aube_%d.png" % i))
		i += 1
	return false
