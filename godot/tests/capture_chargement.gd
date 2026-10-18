extends SceneTree
## Capture : ecran de chargement a plusieurs tailles d'ecran (PC 16:9, Full HD, telephone 20:9, 4:3), pendant le vrai
## chargement de la zone. Lancement : godot --path . -s tests/capture_chargement.gd -- <dossier>
const TAILLES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2400, 1080), Vector2i(1024, 768)]
var frame := 0
var ch: Node
var out := ""
var i := 0
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	ch = (load("res://scenes/chargement.tscn") as PackedScene).instantiate()
	ch.duree_diapo = 2.0
	root.add_child(ch)
	current_scene = ch
func _process(_d: float) -> bool:
	frame += 1
	if frame % 40 == 1 and i < TAILLES.size():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(TAILLES[i])
	if frame % 40 == 30 and i < TAILLES.size():
		var t: Vector2i = TAILLES[i]
		root.get_viewport().get_texture().get_image().save_png(out.path_join("chargement_%dx%d.png" % [t.x, t.y]))
		i += 1
	if i >= TAILLES.size() or not is_instance_valid(ch):
		quit()
		return true
	return false
