extends SceneTree
## Conduite realiste (demande d'Olympe du 17/10/2026), sur la piste de l'aeroport, pour chaque modele : 0-80 km/h,
## vitesse de pointe calculee par le modele (moteur, boite, trainee), passages de rapports, plongee de la caisse au freinage puis retour
## (suspension), caisse immobile et roues au sol a l'arret.

const MODELES := {
	# [0-80 km/h min, max (s), pointe min, max (km/h)]
	"veh_berline": [6.0, 12.0, 150.0, 175.0],
	"veh_4x4": [6.0, 13.0, 130.0, 160.0],
	"veh_minibus": [9.0, 20.0, 100.0, 125.0],
	"veh_pickup": [7.0, 15.0, 120.0, 150.0],
}

var frame := 0
var scene: Node
var car: Node3D
var fails := 0
var ids: Array = MODELES.keys()
var idx := 0
var step := 0
var t0 := 0
var max_rapport := 0
var min_pitch := 0.0
var mark := {}


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _kmh() -> float:
	return float(car.get("speed")) * 3.6


func _spawn() -> void:
	var rw: Array = Carte.zone().data["runways"][0]
	var a := Vector2(float(rw[1][0]), float(rw[1][1]))
	var b := Vector2(float(rw[2][0]), float(rw[2][1]))
	var dir := (b - a).normalized()
	car = Vehicules.create(ids[idx], Color(0.7, 0.7, 0.7))
	car.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(a.x, 0.3, a.y))
	scene.add_child(car)
	car.call("set_rider", true)
	max_rapport = 0
	min_pitch = 0.0


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		scene.get_node("Player").global_position = Vector3(0, -50, 0)
		scene.get_node("Player").set_physics_process(false)
		_spawn()
		step = 0
		t0 = frame
	if frame <= 60 or car == null:
		return false
	var id: String = ids[idx]
	var lim: Array = MODELES[id]
	max_rapport = maxi(max_rapport, int(car.get("rapport")))
	match step:
		0:
			# au repos : caisse et roues immobiles
			if frame - t0 == 90:
				var sq: Vector3 = car.get("_sq")
				_check(absf(sq.y) < 0.005 and absf(sq.z) < 0.005, "%s a l'arret : caisse a plat (tangage %.1f, roulis %.1f degres)" % [id, rad_to_deg(sq.y), rad_to_deg(sq.z)])
				var vp := minf(float(car.call("vitesse_pointe")), float(car.get("max_speed"))) * 3.6
				_check(vp >= lim[2] and vp <= lim[3], "%s vitesse de pointe %.0f km/h (attendu %.0f a %.0f)" % [id, vp, lim[2], lim[3]])
				Input.action_press("accelerate")
				t0 = frame
				step = 1
		1:
			if _kmh() >= 80.0 or frame - t0 > 60 * 30:
				var t := (frame - t0) / 60.0
				_check(_kmh() >= 80.0 and t >= lim[0] and t <= lim[1], "%s 0-80 km/h en %.1f s (attendu %.0f a %.0f s)" % [id, t, lim[0], lim[1]])
				mark["t80"] = frame
				step = 2
		2:
			if frame - mark["t80"] > 60 * 12:
				_check(max_rapport >= 3, "%s boite : %d rapports passes a %.0f km/h" % [id, max_rapport + 1, _kmh()])
				Input.action_release("accelerate")
				Input.action_press("brake")
				mark["tb"] = frame
				step = 3
		3:
			min_pitch = minf(min_pitch, float(car.get("_pitch")))
			if _kmh() < 1.0:
				Input.action_release("brake")
				_check(min_pitch < -0.015, "%s freinage : la caisse plonge (%.1f degres)" % [id, rad_to_deg(min_pitch)])
				mark["ts"] = frame
				step = 4
		4:
			if frame - mark["ts"] == 150:
				_check(absf(float(car.get("_pitch"))) < 0.01, "%s apres l'arret : la caisse revient (%.1f degres)" % [id, rad_to_deg(float(car.get("_pitch")))])
				car.queue_free()
				car = null
				idx += 1
				if idx >= ids.size():
					print("RESULTAT test_conduite : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
					quit(1 if fails else 0)
					return true
				_spawn()
				t0 = frame
				step = 0
	if frame > 60 * 60 * 8:
		print("ECHEC delai depasse")
		quit(1)
		return true
	return false
