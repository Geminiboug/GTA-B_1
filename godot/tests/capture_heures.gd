extends SceneTree
## Captures a plusieurs heures de la journee depuis la Route des Peches (cycle jour / nuit, delestage).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_heures.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var dn: Node
var out_dir := "user://"
var shots := [["07h", 7.0, false], ["12h", 12.0, false], ["18h20", 18.35, false], ["21h", 21.0, false], ["21h_delestage", 21.0, true]]
var idx := 0


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	dn = scene.get_node("JourNuit")
	dn.minutes_per_game_day = 100000.0  # temps fige pendant la capture
	dn.power_cut_chance_per_hour = 0.0


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 20:
		player.global_position = Vector3(60, 1, 8)
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(-0.05, 1.45, 0)
		player.spring_arm.spring_length = 5.0
	if frame < 40:
		return false
	var local := frame - 40 - idx * 45
	var s = shots[idx]
	if local == 0:
		dn.hour = s[1]
		dn._cut_left = 999.0 if s[2] else 0.0
		dn._flicker = 0.0
		dn._next_cut_check = 999.0
	elif local == 40:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("heure_%s.png" % s[0]))
		print("capture ", s[0])
		idx += 1
		if idx >= shots.size():
			return true
	return false
