extends SceneTree
## Captures de controle des voitures (realisme) : choc avant (tole enfoncee, pare-brise etoile, phare casse, feu
## moteur), derapage sur le goudron (fumee et traces de pneus), poussiere sur la laterite.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_degats.gd -- <dossier>

var frame := 0
var scene: Node
var out := ""
var cam: Camera3D
var car: Node3D
var a := Vector2.ZERO
var dir := Vector2.ZERO


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("capture ", name)


func _car(id: String, pos: Vector3, yaw: float) -> Node3D:
	var c := Vehicules.create(id, Color(0.75, 0.12, 0.1))
	c.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	scene.add_child(c)
	return c


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		scene.get_node("JourNuit").set("hour", 17.0)
		(scene.get_node("HUDJeu") as CanvasLayer).visible = false
		(scene.get_node("HUD") as CanvasLayer).visible = false
		scene.get_node("Player").global_position = Vector3(0, -50, 0)
		scene.get_node("Player").set_physics_process(false)
		cam = Camera3D.new()
		scene.add_child(cam)
		cam.current = true
		var rw: Array = Carte.zone().data["runways"][0]
		a = Vector2(float(rw[1][0]), float(rw[1][1]))
		var b := Vector2(float(rw[2][0]), float(rw[2][1]))
		dir = (b - a).normalized()
		a += dir * 400.0
		# 1. choc avant : on enfonce l'avant gauche et on met la voiture a 10 % (feu moteur)
		car = _car("veh_berline", Vector3(a.x, 0.3, a.y), atan2(-dir.x, -dir.y))
	if frame == 40:
		var front: Vector3 = car.global_transform * Vector3(-0.5, 0.6, -2.3)
		var n: Vector3 = car.global_transform.basis * Vector3(0.2, 0, 1).normalized()
		car.enfoncer(front, n, 16.0)
		car.damage(92.0)
		var p: Vector3 = car.global_transform * Vector3(-2.2, 1.3, -4.2)
		cam.global_position = p
		cam.look_at(car.global_transform * Vector3(0, 0.6, -1.0), Vector3.UP)
	if frame == 100:
		_shot("degats_1_choc_avant")
	# 2. derapage au frein a main sur le goudron
	if frame == 110:
		car.queue_free()
		car = _car("veh_berline", Vector3(a.x, 0.3, a.y), atan2(-dir.x, -dir.y))
		car.call("set_rider", true)
		Input.action_press("accelerate")
	if frame > 110 and frame < 400 and car.get("speed") * 3.6 > 70.0 and not Input.is_action_pressed("handbrake"):
		Input.action_release("accelerate")
		Input.action_press("handbrake")
		Input.action_press("move_left")
	if frame == 260:
		var p: Vector3 = car.global_position
		cam.global_position = p + Vector3(dir.x, 0, dir.y) * -9.0 + Vector3(5, 3.5, 0)
		cam.look_at(p + Vector3(0, 0.5, 0), Vector3.UP)
	if frame == 262:
		_shot("degats_2_derapage")
		for ac in ["accelerate", "handbrake", "move_left"]:
			Input.action_release(ac)
	# 3. poussiere : le pick-up sur la piste en terre la plus proche
	if frame == 300:
		car.queue_free()
		var best := Vector3.ZERO
		var bd := INF
		for mi in scene.find_children("route_*_terre*", "MeshInstance3D", true, false):
			var c: Vector3 = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb().get_center()
			var d := c.distance_to(Vector3(a.x, 0, a.y))
			if d < bd:
				bd = d
				best = c
		print("piste en terre a ", best)
		car = _car("veh_pickup", Vector3(best.x, 0.4, best.z), 0.0)
		car.call("set_rider", true)
		Input.action_press("accelerate")
	if frame > 300 and frame < 420:
		var p: Vector3 = car.global_position
		cam.global_position = p + car.global_transform.basis.z * 9.0 + Vector3(2, 3.0, 0)
		cam.look_at(p + Vector3(0, 0.6, 0), Vector3.UP)
	if frame == 420:
		print("surface ", car.get("surface"), " ", car.get("speed") * 3.6, " km/h")
		_shot("degats_3_poussiere")
		quit()
		return true
	return false
