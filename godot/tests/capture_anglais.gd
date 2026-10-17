extends SceneTree
## Capture : menu pause et HUD en anglais (i18n/en.po).
var frame := 0
var scene: Node
var out := ""
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		TranslationServer.set_locale("en")
		var m := scene.get_node("Menus")
		m.call("_open", "pause")
	if frame == 60:
		root.get_viewport().get_texture().get_image().save_png(out.path_join("anglais.png"))
		quit()
		return true
	return false
