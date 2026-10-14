extends SceneTree
## Debug : trajectoire du joueur pendant les 60 premieres images, sans aucune commande.

var frame := 0
var player: CharacterBody3D


func _initialize() -> void:
	var scene: Node = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	var bodies := []
	for n in player.find_children("*", "CollisionObject3D", true, false):
		bodies.append(n.get_path())
	print("DBG corps physiques sous le joueur : ", bodies)


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame % 6 == 0:
		var c := player.get_last_slide_collision()
		print("DBG f%d pos %s vel %s %s" % [frame, player.global_position.snapped(Vector3.ONE * 0.01), player.velocity.snapped(Vector3.ONE * 0.01),
			(str(c.get_collider().get_path()) + " n=" + str(c.get_normal().snapped(Vector3.ONE * 0.01))) if c else ""])
	return frame >= 60
