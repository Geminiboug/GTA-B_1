extends SceneTree
## Capture de controle : torche allumee dans la main, vue de cote et de pres, de nuit (orientation du corps de lampe).
var frame := 0
var scene: Node
var out := ""
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		scene.get_node("JourNuit").set("hour", 21.0)
		root.get_node("Partie").nouvelle_partie()
		scene.get_node("Inventaire").torche(true)
	if frame == 60:
		var p: Node3D = scene.get_node("Player")
		var cam := Camera3D.new()
		scene.add_child(cam)
		var f: float = p.get("_facing")
		var side := Vector3(cos(f), 0, -sin(f))
		var fwd := Vector3(-sin(f), 0, -cos(f))
		cam.global_position = p.global_position + side * 1.7 + fwd * 0.6 + Vector3(0, 1.2, 0)
		cam.look_at(p.global_position + Vector3(0, 1.0, 0) + fwd * 0.3, Vector3.UP)
		cam.current = true
		(scene.get_node("HUDJeu") as CanvasLayer).visible = false
		(scene.get_node("HUD") as CanvasLayer).visible = false
	if frame == 90:
		root.get_viewport().get_texture().get_image().save_png(out.path_join("torche_cote.png"))
		quit()
		return true
	return false
