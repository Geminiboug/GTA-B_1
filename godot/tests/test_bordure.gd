extends SceneTree
## Bordures : une berline franchit une bordure de 15 cm a 40 km/h sans choc ni degats (les roues montent), mais un
## muret de 1,2 m reste un vrai choc (degats).
var frame := 0
var scene: Node
var car: Node3D
var fails := 0
var phase := "bordure"
var t := 0.0
var h0 := 0.0
var v_min := 999.0
func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1
func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _obstacle(hauteur: float, dist: float) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, hauteur, 0.4)
	cs.shape = box
	b.add_child(cs)
	scene.add_child(b)
	var fwd := -car.global_transform.basis.z
	b.global_transform = Transform3D(car.global_transform.basis, Vector3(car.global_position.x, hauteur / 2.0, car.global_position.z) + fwd * dist)
func _spawn() -> void:
	var rw: Array = Carte.zone().data["runways"][0]
	var a := Vector2(float(rw[1][0]), float(rw[1][1]))
	var b := Vector2(float(rw[2][0]), float(rw[2][1]))
	var dir := (b - a).normalized()
	car = Vehicules.create("veh_berline", Color(0.7, 0.7, 0.7))
	car.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(a.x, 0.3, a.y))
	scene.add_child(car)
	car.call("set_rider", true)
func _physics_process(d: float) -> bool:
	frame += 1
	if frame == 60:
		scene.get_node("Player").global_position = Vector3(0, -50, 0)
		scene.get_node("Player").set_physics_process(false)
		_spawn()
		_obstacle(0.15, 60.0)
		_obstacle(1.2, 160.0)
		car.set("max_speed", 11.2)          # ~40 km/h
		h0 = float(car.get("health"))
		Input.action_press("accelerate")
	if frame < 61:
		return false
	t += d
	var kmh: float = float(car.get("speed")) * 3.6
	if phase == "bordure":
		if t > 4.0:
			v_min = minf(v_min, kmh)
		var p: Vector3 = car.global_position
		if t > 9.0:
			_check(float(car.get("health")) >= h0, "bordure de 15 cm : pas de degats (sante %.0f)" % float(car.get("health")))
			_check(v_min > 25.0, "bordure : la voiture continue (%.0f km/h au plus bas)" % v_min)
			phase = "muret"
			t = 0.0
	elif phase == "muret":
		if t > 14.0:
			_check(float(car.get("health")) < h0, "muret de 1,2 m : vrai choc (sante %.0f)" % float(car.get("health")))
			Input.action_release("accelerate")
			print("RESULTAT test_bordure : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
			quit(1 if fails else 0)
			return true
	return false
