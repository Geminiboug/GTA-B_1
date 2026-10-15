extends SceneTree
## Regard du joueur : camera de jeu tournee de 60 degres, le joueur est filme de face (tete et buste tournes).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_regard.gd -- <fichier.png>

var frame := 0
var scene: Node
var player: CharacterBody3D
var cam: Camera3D


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		player = scene.get_node("Player")
		scene.get_node("Debug").teleport(2)
	if frame > 20 and player:
		player.cam_pivot.rotation.y = player.get("_facing") + 1.05
		player.set("_cam_idle", 0.0)
	if frame == 60:
		cam = Camera3D.new()
		cam.fov = 35.0
		scene.add_child(cam)
		var f: float = player.get("_facing")
		var fwd := Vector3(-sin(f), 0, -cos(f))
		cam.global_position = player.global_position + fwd * 3.0 + Vector3(0, 1.6, 0)
		cam.look_at(player.global_position + Vector3(0, 1.45, 0), Vector3.UP)
		cam.current = true
	if frame == 90:
		print("regard : ", player.anim.get("_look"))
		root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		print("capture regard")
		return true
	return false
