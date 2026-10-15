extends SceneTree
## Mesure de la pose assise du joueur sur chaque vehicule : bassin, pieds, mains par rapport au siege (pt_conducteur)
## et au guidon / volant. Lancement : godot --headless --path godot --script res://tests/mesure_assis.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var models := ["zem", "veh_berline", "veh_4x4", "veh_minibus"]
var idx := 0
var v: Node3D


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _bone(skel: Skeleton3D, n: String) -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(n)).origin


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	player = scene.get_node("Player")
	var k := (frame - 60) % 90
	if k == 0:
		if idx >= models.size():
			return true
		if player.vehicle:
			player.exit_vehicle()
		v = Vehicules.create(models[idx], Color.RED)
		v.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 320 + idx * 8))
		scene.add_child(v)
	elif k == 30:
		player.enter_vehicle(v)
	elif k == 89:
		var skel := Squelette.find(player.get_node("Body/Model"))
		var inv := v.global_transform.affine_inverse()
		var seat: Transform3D = v.seat_transform()
		print("%s : siege %s | bassin %s | pied G %s | main G %s | tete %s" % [models[idx], (inv * seat.origin).snapped(Vector3.ONE * 0.01),
			(inv * _bone(skel, "Hips")).snapped(Vector3.ONE * 0.01), (inv * _bone(skel, "LeftFoot")).snapped(Vector3.ONE * 0.01),
			(inv * _bone(skel, "LeftHand")).snapped(Vector3.ONE * 0.01), (inv * _bone(skel, "Head")).snapped(Vector3.ONE * 0.01)])
		idx += 1
	return false
