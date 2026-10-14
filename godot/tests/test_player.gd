extends SceneTree
## Test automatique du joueur dans la zone (sans fenetre).
## Lancement : godot --headless --path godot --script res://tests/test_player.gd

var frame := 0
var player: CharacterBody3D
var start: Vector3
var report: Array[String] = []


func _initialize() -> void:
	var scene: Node = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 60:
		start = player.global_position
		report.append("apres chute : pos %s, au sol %s" % [start.snapped(Vector3.ONE * 0.01), player.is_on_floor()])
		Input.action_press("move_forward")
	elif frame > 60 and frame < 420 and frame != 240 and frame % 30 == 0:
		var c := player.get_last_slide_collision()
		report.append("f%d pos %s vel %s collision %s" % [frame, player.global_position.snapped(Vector3.ONE * 0.01), player.velocity.snapped(Vector3.ONE * 0.01), (c.get_collider().get_parent().name + "/" + c.get_collider().name + " normale " + str(c.get_normal().snapped(Vector3.ONE * 0.01))) if c else "aucune"])
	elif frame == 240:
		var p := player.global_position
		report.append("apres 3 s de marche : distance %.2f m, au sol %s" % [start.distance_to(p), player.is_on_floor()])
		Input.action_press("sprint")
	elif frame == 420:
		report.append("apres 3 s de course : distance totale %.2f m" % start.distance_to(player.global_position))
		Input.action_release("move_forward")
		Input.action_release("sprint")
	elif frame == 450:
		Input.action_press("jump")
	elif frame == 465:
		report.append("pendant le saut : hauteur %.2f m, au sol %s" % [player.global_position.y, player.is_on_floor()])
		Input.action_release("jump")
	elif frame == 560:
		report.append("apres le saut : hauteur %.2f m, au sol %s" % [player.global_position.y, player.is_on_floor()])
		for line in report:
			print("TEST ", line)
		return true
	return false
