extends SceneTree
## Test automatique du zem : monter (E), accelerer 6 s, tourner a gauche 2 s, freiner, descendre.
## Lancement : godot --headless --path godot --script res://tests/test_zem.gd

var frame := 0
var player: CharacterBody3D
var zem: CharacterBody3D
var start: Vector3
var report: Array[String] = []


func _initialize() -> void:
	var scene: Node = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	zem = scene.get_node("Zem")


func _log(msg: String) -> void:
	report.append(msg)


func _physics_process(_delta: float) -> bool:
	frame += 1
	match frame:
		30:
			_log("distance joueur-zem au depart : %.2f m" % player.global_position.distance_to(zem.global_position))
			Input.action_press("interact")
		32:
			Input.action_release("interact")
			_log("monte sur le zem : %s, collision joueur coupee : %s" % [player.vehicle != null, player.get_node("Collision").disabled])
			start = zem.global_position
			Input.action_press("move_forward")
		392:
			_log("apres 6 s de gaz : vitesse %.1f km/h, distance %.1f m" % [zem.speed * 3.6, start.distance_to(zem.global_position)])
			Input.action_press("move_left")
		420:
			_log("en virage : inclinaison %.0f deg, guidon %.0f deg" % [rad_to_deg(zem.get_node("Visual").rotation.z), rad_to_deg(zem._steer)])
		512:
			_log("apres 2 s a gauche : cap %.0f deg" % rad_to_deg(zem.rotation.y))
			Input.action_release("move_left")
			Input.action_release("move_forward")
			Input.action_press("move_back")
		632:
			_log("apres 2 s de frein : vitesse %.1f km/h" % (zem.speed * 3.6))
			Input.action_release("move_back")
			Input.action_press("interact")
		634:
			Input.action_release("interact")
		640:
			_log("descendu : %s, joueur au sol a %.2f m du zem" % [player.vehicle == null, player.global_position.distance_to(zem.global_position)])
		700:
			_log("joueur apres 1 s : au sol %s, hauteur %.2f" % [player.is_on_floor(), player.global_position.y])
			for l in report:
				print("TEST ", l)
			return true
	return false
