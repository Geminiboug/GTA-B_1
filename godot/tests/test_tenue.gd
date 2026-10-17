extends SceneTree
## Tenue de route (modele de pneus) : pour chaque voiture, sur la piste de l'aeroport :
## 1. virage braque a fond a 60 km/h : acceleration laterale proche de l'adherence, pas de tete-a-queue ;
## 2. frein a main a 55 km/h en braquant : l'arriere decroche (derive nette) ;
## 3. ligne droite volant lache : la voiture reste droite (stable) ;
## 4. sur le sable de la plage, l'adherence chute.

const IDS := ["veh_berline", "veh_4x4", "veh_minibus", "veh_pickup"]

var frame := 0
var scene: Node
var fails := 0
var car: Node3D
var idx := 0
var step := 0
var t0 := 0
var lat_max := 0.0
var der_max := 0.0
var yaw0 := 0.0
var a := Vector2.ZERO
var dir := Vector2.ZERO


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _spawn() -> void:
	if car:
		car.queue_free()
	car = Vehicules.create(IDS[idx], Color(0.7, 0.7, 0.7))
	car.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(a.x, 0.3, a.y))
	scene.add_child(car)
	car.call("set_rider", true)
	step = 0
	t0 = frame


func _kmh() -> float:
	return absf(float(car.get("speed"))) * 3.6


func _release_all() -> void:
	for ac in ["accelerate", "brake", "move_left", "move_right", "handbrake"]:
		Input.action_release(ac)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		scene.get_node("Player").global_position = Vector3(0, -50, 0)
		scene.get_node("Player").set_physics_process(false)
		var rw: Array = Carte.zone().data["runways"][0]
		a = Vector2(float(rw[1][0]), float(rw[1][1]))
		var b := Vector2(float(rw[2][0]), float(rw[2][1]))
		dir = (b - a).normalized()
		a += dir * 300.0
		_spawn()
	if frame <= 60 or car == null:
		return false
	var id: String = IDS[mini(idx, IDS.size() - 1)]
	var t := frame - t0
	match step:
		0:   # elan jusqu'a 60 km/h
			Input.action_press("accelerate")
			if _kmh() >= 60.0:
				Input.action_release("accelerate")
				Input.action_press("accelerate", 0.35)
				Input.action_press("move_left")
				step = 1
				t0 = frame
				lat_max = 0.0
				der_max = 0.0
		1:   # virage a fond 4 s
			if t > 180:
				lat_max += absf(float(car.get("speed")) * float(car.get("_yaw_rate"))) / 9.8 / 60.0   # moyenne sur la derniere seconde
			if t > 60:
				der_max = maxf(der_max, absf(float(car.get("derive"))))
			if t == 240:
				var mu: float = float(car.get("grip"))
				_check(lat_max > 0.4 * mu and lat_max < 1.15 * mu, "%s virage a fond : %.2f g lateral (adherence du goudron %.2f)" % [id, lat_max, mu])
				_check(rad_to_deg(der_max) < 14.0, "%s virage a fond : pas de tete-a-queue (derive max %.0f deg)" % [id, rad_to_deg(der_max)])
				_release_all()
				step = 2
				t0 = frame
		2:   # se remet droit et reprend de l'elan
			Input.action_press("accelerate")
			if t > 30 and _kmh() >= 55.0:
				Input.action_release("accelerate")
				Input.action_press("handbrake")
				Input.action_press("move_right")
				step = 3
				t0 = frame
				der_max = 0.0
		3:   # frein a main en braquant : derapage
			der_max = maxf(der_max, absf(float(car.get("derive"))))
			if t == 90:
				_check(rad_to_deg(der_max) > 12.0, "%s frein a main : l'arriere decroche (derive %.0f deg)" % [id, rad_to_deg(der_max)])
				_release_all()
				step = 4
				t0 = frame
		4:   # arret, puis ligne droite volant lache
			Input.action_press("brake")
			if (car.get("_vel") as Vector2).length() < 0.3 and t > 30:
				car.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(a.x, 0.3, a.y))
				car.set("_yaw", atan2(-dir.x, -dir.y))
				car.set("_yaw_rate", 0.0)
				_release_all()
				Input.action_press("accelerate")
				yaw0 = float(car.get("_yaw"))
				step = 5
				t0 = frame
		5:
			if t == 240:
				var dy := rad_to_deg(absf(wrapf(float(car.get("_yaw")) - yaw0, -PI, PI)))
				_check(dy < 3.0, "%s ligne droite volant lache : cap tenu (%.1f deg)" % [id, dy])
				_release_all()
				idx += 1
				if idx >= IDS.size():
					step = 6
					t0 = frame
				else:
					_spawn()
		6:   # sable : la berline sur la plage
			if t == 1:
				var coast: Array = Carte.zone().data["coast"]
				var c := Vector3.ZERO
				for q in coast:
					if absf(float(q[0])) < 40.0:
						c = Vector3(float(q[0]), 0, float(q[1]))
				car.queue_free()
				car = Vehicules.create("veh_berline", Color(0.7, 0.7, 0.7))
				car.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), c + Vector3(0, 0.3, -25))
				scene.add_child(car)
				car.call("set_rider", true)
			if t == 40:
				_check(car.get("surface") == "plage" and float(car.get("adherence")) < 0.7, "sur le sable : surface %s, adherence %.2f" % [car.get("surface"), car.get("adherence")])
				print("RESULTAT test_tenue : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
				quit(1 if fails else 0)
				return true
	return false
