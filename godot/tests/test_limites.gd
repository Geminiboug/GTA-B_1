extends SceneTree
## Test des limites du monde : bord ouest (mur invisible), mer (fond praticable), chute sous la carte (retour).
## Lancement : godot --headless --path godot --script res://tests/test_limites.gd

var frame := 0
var player: CharacterBody3D
var report: Array[String] = []


func _initialize() -> void:
	var scene: Node = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")


func _tp(p: Vector3) -> void:
	player.global_position = p
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		40:
			# bord ouest : on court vers l'ouest pendant 4 s depuis 10 m du bord
			_tp(Vector3(-665, 1, 0))
			player.cam_pivot.rotation.y = 0.0
			Input.action_press("move_left")
			Input.action_press("sprint")
		280:
			report.append("bord ouest : x = %.1f (limite -677), au sol %s, y = %.2f" % [player.global_position.x, player.is_on_floor(), player.global_position.y])
			Input.action_release("move_left")
			Input.action_release("sprint")
			# la mer : on part de la plage et on marche 6 s vers le large (sud = +Z)
			_tp(Vector3(0, 1, 460))
			Input.action_press("move_back")
		640:
			report.append("dans la mer : z = %.1f, y = %.2f (fond -1.2), au sol %s" % [player.global_position.z, player.global_position.y, player.is_on_floor()])
			Input.action_release("move_back")
			# chute volontaire sous la carte : doit revenir au dernier point sur
			_tp(Vector3(0, -30, 0))
		700:
			report.append("apres chute sous la carte : y = %.2f, pos %s" % [player.global_position.y, player.global_position.snapped(Vector3.ONE * 0.1)])
			for l in report:
				print("TEST ", l)
			return true
	return false
