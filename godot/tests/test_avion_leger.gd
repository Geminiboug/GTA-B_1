extends SceneTree
## Avion leger pilotable : au sol sur ses roues, decollage sur la piste (rotation a ~30 m/s, montee), virage en roulis,
## atterrissage doux sur la piste, arret et sortie du pilote.
## Lancement : godot --headless --path godot --script res://tests/test_avion_leger.gd

var frame := 0
var scene: Node
var av: CharacterBody3D
var player: CharacterBody3D
var fails := 0
var etape := 0
var t0 := 0
var pos0 := Vector3.ZERO
var cap0 := 0.0
var alt_max := 0.0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	Engine.time_scale = 3.0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _fin() -> bool:
	Input.action_release("accelerate")
	Input.action_release("move_back")
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Engine.time_scale = 1.0
	print("RESULTAT test_avion_leger : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true


func _cap() -> float:
	var f := -av.global_transform.basis.z
	return atan2(f.x, -f.z)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 200:
		return false
	player = scene.get_node("Player") as CharacterBody3D
	av = scene.get_node("AvionLeger") as CharacterBody3D
	if etape == 0:
		_check(av != null and av.get("kind") == "avion", "avion leger present")
		_check(bool(av.get("_au_sol")), "il repose sur ses roues (altitude %.2f m)" % float(av.get("altitude")))
		_check(float(av.get("health")) == 100.0, "intact")
		# on l'amene sur l'axe de la piste, pres du seuil 06 (a son poste il est a cote de la piste)
		av.set("piste_t", 80.0)
		av.set("piste_s", 0.0)
		av.call("_placer_sur_aeroport")
		av.set("_v", Vector3.ZERO)
		# le joueur monte
		player.global_position = av.entry_point() + Vector3(0.3, 0.3, 0.0)
		player.reset_physics_interpolation()
		player.enter_vehicle(av)
		etape = 1
		t0 = frame
		return false
	if etape == 1 and frame - t0 == 120:
		_check(player.vehicle == av, "le pilote est installe")
		pos0 = av.global_position
		cap0 = _cap()
		Input.action_press("accelerate")
		etape = 2
		t0 = frame
		return false
	if etape == 2:
		var v: float = float(av.get("speed"))
		if (frame - t0) % 60 == 0 and (frame - t0) < 60 * 25:
			print("  t=%d vit %.1f gaz %.2f alt %.1f sol %s pos %s v %s sante %.0f tangage %.1f %s" % [(frame - t0) / 60, v, float(av.get("gaz")), float(av.get("altitude")), av.get("_au_sol"), av.global_position, av.get("_v"), float(av.get("health")), rad_to_deg(asin(clampf(-av.global_transform.basis.z.y, -1.0, 1.0))), av.get("derniere_collision")])
		var tangage := rad_to_deg(asin(clampf(-av.global_transform.basis.z.y, -1.0, 1.0)))
		if v >= 30.0:
			Input.action_press("move_back", clampf((9.0 - tangage) / 6.0, 0.0, 1.0))      # cabrer jusqu'a ~9 degres
		else:
			Input.action_release("move_back")
		if float(av.get("altitude")) > alt_max:
			alt_max = float(av.get("altitude"))
		if float(av.get("altitude")) > 40.0:
			var d: float = Vector2(av.global_position.x - pos0.x, av.global_position.z - pos0.z).length()
			_check(d < 1300.0, "decollage : 40 m de hauteur apres %.0f m de roulage et de montee" % d)
			Input.action_release("move_back")
			etape = 3
			t0 = frame
		elif frame - t0 > 60 * 70:
			_check(false, "pas de decollage (vitesse %.1f m/s, altitude max %.1f m, au sol %s, cap %.1f)" % [v, alt_max, av.get("_au_sol"), rad_to_deg(_cap())])
			return _fin()
		return false
	if etape == 3:
		# en l'air : virage a droite en roulis pendant 4 s
		if (frame - t0) % 12 == 0 and (frame - t0) > 55:
			print("  d ", av.get("dbg"), " alt %.0f vit %.0f" % [float(av.get("altitude")), float(av.get("speed"))])
		if (frame - t0) % 60 == 0:
			var roulis := rad_to_deg(atan2(av.global_transform.basis.x.y, av.global_transform.basis.y.y))
			print("  vol t=%d cap %.0f roulis %.0f alt %.0f vit %.0f sante %.0f %s" % [(frame - t0) / 60, rad_to_deg(_cap()), roulis, float(av.get("altitude")), float(av.get("speed")), float(av.get("health")), av.get("derniere_collision")])
		if frame - t0 == 60:
			cap0 = _cap()
			Input.action_press("move_right")
		if frame - t0 == 60 * 4:
			Input.action_release("move_right")
			var dcap := absf(rad_to_deg(angle_difference(cap0, _cap())))
			_check(dcap > 15.0, "virage en roulis : cap change de %.0f degres" % dcap)
			_check(not bool(av.get("en_decrochage")), "pas de decrochage en virage")
			_check(float(av.get("health")) == 100.0, "intact en vol")
			# approche sur la piste : on replace l'avion en finale, cap de la piste, 40 m, 31 m/s
			av.set("piste_t", 250.0)
			av.set("piste_s", 0.0)
			av.call("_placer_sur_aeroport")
			av.global_position.y += 40.0
			av.set("_v", -av.global_transform.basis.z * 31.0)
			etape = 4
			t0 = frame
		return false
	if etape == 4:
		# approche : gaz reduits, pente de descente d'environ 2,5 m/s tenue au manche, arrondi a 6 m
		var vy: float = (av.get("_v") as Vector3).y
		var alt: float = float(av.get("altitude"))
		var cible_vy := -2.5 if alt > 8.0 else -0.8
		av.set("gaz", 0.12 if alt > 8.0 else 0.0)
		Input.action_release("accelerate")
		var ecart := cible_vy - vy
		if ecart > 0.2:
			Input.action_press("move_back", clampf(ecart / 3.0, 0.0, 1.0))
			Input.action_release("move_forward")
		elif ecart < -0.2:
			Input.action_press("move_forward", clampf(-ecart / 3.0, 0.0, 1.0))
			Input.action_release("move_back")
		else:
			Input.action_release("move_back")
			Input.action_release("move_forward")
		if (frame - t0) % 20 == 0 and alt < 40.0:
			print("  appr alt %.1f vy %.1f vit %.1f gaz %.2f sante %.0f sol %s %s" % [alt, vy, float(av.get("speed")), float(av.get("gaz")), float(av.get("health")), av.get("_au_sol"), av.get("dbg")])
		if bool(av.get("_au_sol")) and frame - t0 > 60:
			print("  touche: ", av.get("derniere_collision"))
			_check(float(av.get("health")) > 40.0, "atterrissage sans casse (sante %.0f)" % float(av.get("health")))
			Input.action_release("move_forward")
			Input.action_release("move_back")
			etape = 5
			t0 = frame
		elif frame - t0 > 60 * 120:
			_check(false, "pas d'atterrissage (altitude %.0f)" % float(av.get("altitude")))
			return _fin()
		return false
	if etape == 5 and frame - t0 == 60 * 30:
		Input.action_press("handbrake")
		etape = 6
		t0 = frame
		return false
	if etape == 6 and frame - t0 == 60 * 20:
		Input.action_release("handbrake")
		_check(float((av.get("_v") as Vector3).length()) < 3.0, "arret complet (%.1f m/s)" % float((av.get("_v") as Vector3).length()))
		return _fin()
	return false
