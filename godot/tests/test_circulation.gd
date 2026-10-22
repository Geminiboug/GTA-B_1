extends SceneTree
## Test de la circulation et des pietons : apres 20 s de simulation, combien roulent / marchent, a quelle vitesse,
## distance parcourue, vehicules hors des routes ? Puis : un vehicule s'arrete-t-il devant le joueur ?
## Lancement : godot --headless --path godot --script res://tests/test_circulation.gd

var frame := 0
var scene: Node
var traffic: Node
var peds: Node
var start_cars: Array = []
var start_peds: Array = []
var target_index := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	traffic = scene.get_node("Circulation")
	peds = scene.get_node("Pietons")


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 60:
		for a in traffic._agents:
			start_cars.append(a["vis_pos"])
		for w in peds._walkers:
			start_peds.append(w["pos"])
	if frame == 60 + 20 * 60:
		var moving := 0
		var total_speed := 0.0
		var dist := 0.0
		var max_y := 0.0
		for k in traffic._agents.size():
			var a: Dictionary = traffic._agents[k]
			total_speed += a["speed"]
			if a["speed"] > 1.0:
				moving += 1
			dist += (a["vis_pos"] as Vector3).distance_to(start_cars[k])
			max_y = max(max_y, abs((a["vis_pos"] as Vector3).y - 0.02))
		var n: int = traffic._agents.size()
		print("TEST vehicules : %d / %d roulent, vitesse moyenne %.1f km/h, distance moyenne en 20 s : %.0f m, ecart vertical max %.2f m" % [moving, n, total_speed / n * 3.6, dist / n, max_y])
		var wdist := 0.0
		var nw := mini(peds._walkers.size(), start_peds.size())      # les vendeurs des tuiles s'ajoutent a la liste apres le depart
		for k in nw:
			wdist += (peds._walkers[k]["pos"] as Vector3).distance_to(start_peds[k])
		print("TEST pietons : distance moyenne en 20 s : %.1f m (%d marcheurs)" % [wdist / nw, nw])
		# le joueur se met devant un vehicule en mouvement
		for k in traffic._agents.size():
			if traffic._agents[k]["speed"] > 5.0 and traffic._remaining(traffic._agents[k]) > 28.0:
				target_index = k
				break
		var a: Dictionary = traffic._agents[target_index]
		var fwd: Vector3 = -(a["body"] as Node3D).global_transform.basis.z
		var p: Node3D = scene.get_node("Player")
		p.global_position = (a["vis_pos"] as Vector3) + fwd * 14.0 + Vector3(0, 1, 0)
		p.reset_physics_interpolation()
		print("TEST joueur place 14 m devant le vehicule %d a %.1f km/h (carrefour suivant a %.0f m)" % [target_index, a["speed"] * 3.6, traffic._remaining(a)])
	if frame == 60 + 23 * 60:
		var a: Dictionary = traffic._agents[target_index]
		var p: Node3D = scene.get_node("Player")
		print("TEST apres 3 s : vitesse du vehicule %.1f km/h, distance au joueur %.1f m, klaxon %s" % [a["speed"] * 3.6, (a["vis_pos"] as Vector3).distance_to(p.global_position), (a["horn"] as AudioStreamPlayer3D).playing or a["honk_cd"] > 0.0])
		return true
	return false
