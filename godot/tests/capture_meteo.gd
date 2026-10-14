extends SceneTree
## Captures meteo : meme rue par temps sec, sous l'orage de jour, sous la pluie de nuit.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_meteo.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var dn: Node
var meteo: Node
var out_dir := "user://"
var shots := [["sec_15h", 15.0, 0.0], ["orage_15h", 15.0, 1.0], ["pluie_20h", 20.0, 1.0]]
var idx := 0


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	dn = scene.get_node("JourNuit")
	meteo = scene.get_node("Meteo")
	dn.minutes_per_game_day = 100000.0
	dn.power_cut_chance_per_hour = 0.0
	meteo.min_episode = 100000.0
	meteo.max_episode = 100000.0
	meteo._episode = 100000.0


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 20:
		player.global_position = Vector3(300, 1, 120)
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(-0.2, 2.4, 0)
		player.spring_arm.spring_length = 8.0
	if frame < 40:
		return false
	var local := frame - 40 - idx * 60
	var s = shots[idx]
	if local == 0:
		dn.hour = s[1]
		var k: float = s[2]
		meteo._target_storm = k
		meteo._target_rain = k
		meteo.storm = k
		meteo.rain = k
		meteo.wet = k
		meteo._thunder = false
	elif local == 55:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("meteo_%s.png" % s[0]))
		print("capture ", s[0])
		idx += 1
		if idx >= shots.size():
			return true
	return false
