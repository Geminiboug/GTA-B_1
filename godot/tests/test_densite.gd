extends SceneTree
## Densite : meme loin du depart, des passants et des vehicules sont recycles autour du joueur (la carte fait 7 km de long).
## Lancement : godot --headless --path godot --script res://tests/test_densite.gd

var frame := 0
var scene: Node
var fails := 0
var lieux: Array = [Vector3(2500, 1, -600), Vector3(-2400, 1, -300), Vector3(1200, 1, 400)]
var i := 0
var t0 := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	Engine.time_scale = 4.0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 120:
		return false
	var player := scene.get_node("Player") as Node3D
	if frame == 120 or frame == t0 + 60 * 40:
		if frame != 120:
			var n_p := 0
			for w in scene.get_node("Pietons")._walkers:
				if not w.has("chaise") and (w["pos"] as Vector3).distance_to(player.global_position) < 220.0:
					n_p += 1
			var n_v := 0
			for a in scene.get_node("Circulation")._agents:
				if (a["vis_pos"] as Vector3).distance_to(player.global_position) < 220.0:
					n_v += 1
			_check(n_p >= 8, "%s : %d passants dans les 220 m" % [lieux[i - 1], n_p])
			_check(n_v >= 8, "%s : %d vehicules dans les 220 m" % [lieux[i - 1], n_v])
		if i >= lieux.size():
			Engine.time_scale = 1.0
			print("RESULTAT test_densite : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
			quit(1 if fails else 0)
			return true
		player.global_position = lieux[i]
		player.reset_physics_interpolation()
		i += 1
		t0 = frame
	return false
