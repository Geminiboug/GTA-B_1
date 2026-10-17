extends SceneTree
## Captures de controle de la phase 12 : estran en pente avec sable mouille et ressac, usure des facades (coulures,
## affiches dechirees). Lancement (avec fenetre) : godot --path godot --script res://tests/capture_plage.gd -- <dossier>

var frame := 0
var scene: Node
var out := ""
var cam: Camera3D


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("capture ", name)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		scene.get_node("JourNuit").set("hour", 10.0)
		(scene.get_node("HUDJeu") as CanvasLayer).visible = false
		(scene.get_node("HUD") as CanvasLayer).visible = false
		cam = Camera3D.new()
		scene.add_child(cam)
		cam.current = true
	if frame == 30:
		var coast: Array = Carte.zone().data["coast"]
		var c := Vector3(0, 0, 0)
		for q in coast:
			if absf(float(q[0])) < 40.0:
				c = Vector3(float(q[0]), 0, float(q[1]))
		cam.global_position = c + Vector3(-30, 3.0, -45)
		cam.look_at(c + Vector3(10, -0.8, 5), Vector3.UP)
	if frame == 150:
		_shot("plage_estran")
		cam.global_position = Vector3(312, 1.7, 100)
		cam.look_at(Vector3(300, 1.6, 96), Vector3.UP)
	if frame == 200:
		_shot("facades_usure_1")
		cam.global_position = Vector3(250, 1.7, 60)
		cam.look_at(Vector3(260, 1.4, 75), Vector3.UP)
	if frame == 250:
		_shot("facades_usure_2")
		return true
	return false
