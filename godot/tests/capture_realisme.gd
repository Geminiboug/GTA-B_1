extends SceneTree
## Captures de controle du realisme : rue avec maisons, plage et mer, vue d'ensemble.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_realisme.gd -- <dossier_sortie>

var frame := 0
var player: CharacterBody3D
var out_dir := "user://"
# [nom, position du joueur, rotation de la camera (x, y), zoom]
var shots := [
	["route_peches", Vector3(43.7, 1, 10.2), Vector2(-0.1, 1.45), 5.0],
	["axe_principal", Vector3(528, 1, -301), Vector2(-0.1, 2.2), 6.0],
	["tarmac", Vector3(215, 1, -340), Vector2(-0.12, -0.62), 9.0],
	["terminal", Vector3(330, 1, -300), Vector2(-0.1, 0.4), 7.0],
	["rue", Vector3(420, 1, -20), Vector2(-0.12, 0.6), 6.0],
	["maisons", Vector3(300, 1, 120), Vector2(-0.25, 2.4), 9.0],
	["plage_mer", Vector3(0, 1, 330), Vector2(-0.15, PI), 6.0],
	["vue_haute", Vector3(150, 1, 200), Vector2(-0.55, 0.3), 12.0],
]
var idx := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	var scene: Node = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame < 30:
		return false
	var s = shots[idx]
	var local := frame - 30 - idx * 160
	if local == 0:
		player.global_position = s[1]
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(s[2].x, s[2].y, 0)
		player.spring_arm.spring_length = s[3]
	elif local == 150:   # apres la reception (le joueur est pose a 1 m du sol)
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("real_%s.png" % s[0]))
		print("capture ", s[0])
		idx += 1
		if idx >= shots.size():
			return true
	return false
