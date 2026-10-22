extends SceneTree
## Prologue joue comme un joueur : nouvelle partie a la maison, marcher jusqu'a la tante, T, suivre le GPS (route
## de scripts/hud_carte.gd) jusqu'a l'etal, T puis 4 (pain), revenir a la tante, T. Aucun deplacement force : le
## joueur marche avec les touches, la camera tournee vers le prochain point de l'itineraire. Echec si le joueur
## reste bloque 6 s ou si la mission n'est pas finie en 4 min de jeu.
## Lancement : godot --headless --path godot --script res://tests/test_prologue.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var histoire: Node
var hud: Node
var com: Node
var fails := 0
var phase := "init"
var t := 0.0
var stuck_t := 0.0
var best_d := INF
var cible := Vector3.INF
var last_pos := Vector3.INF
var hold := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)


func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


func _walk_to(p: Vector3, delta: float) -> float:
	## Marche vers p en suivant l'itineraire GPS ; renvoie la distance restante.
	var pos := player.global_position
	var aim := p
	var route: PackedVector2Array = hud.get("route")
	if route.size() > 1 and Vector2(pos.x - p.x, pos.z - p.z).length() > 6.0:
		# segment de la route le plus proche, puis le premier sommet suivant a plus de 2 m
		var p2 := Vector2(pos.x, pos.z)
		var bi := 0
		var bd := INF
		for i in route.size() - 1:
			var c := Geometry2D.get_closest_point_to_segment(p2, route[i], route[i + 1])
			if c.distance_to(p2) < bd:
				bd = c.distance_to(p2)
				bi = i
		for i in range(bi + 1, route.size()):
			if route[i].distance_to(p2) > 2.0:
				aim = Vector3(route[i].x, pos.y, route[i].y)
				break
	var dx := aim.x - pos.x
	var dz := aim.z - pos.z
	var cap := atan2(-dx, -dz)
	# un PNJ (corps solide) devant : on le contourne par la droite, comme un joueur
	var avant := Vector3(dx, 0, dz).normalized()
	var espace := player.get_world_3d().direct_space_state
	if not d_libre(espace, pos, avant, true) or (stuck_t > 1.0 and not d_libre(espace, pos, avant, false)):
		for dcap in [-0.6, 0.6, -1.2, 1.2, -1.8, 1.8]:      # cote libre (pas de moto, de mur...)
			if d_libre(espace, pos, avant.rotated(Vector3.UP, dcap), false):
				cap += dcap
				break
	(player.get_node("CamPivot") as Node3D).rotation.y = cap
	Input.action_press("move_forward")
	var d := Vector2(pos.x - p.x, pos.z - p.z).length()
	# bloque : moins de 1 m parcouru en 6 s (les detours du GPS eloignent parfois de la cible)
	if last_pos == Vector3.INF or pos.distance_to(last_pos) > 1.0:
		last_pos = pos
		stuck_t = 0.0
	else:
		stuck_t += delta
	return d


func d_libre(espace: PhysicsDirectSpaceState3D, pos: Vector3, dv: Vector3, pnj_seul: bool) -> bool:
	## Rien devant sur 1.5 m (PNJ seulement, ou tout obstacle) a hauteur de genou et de buste.
	for h in [0.3, 1.0]:
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, h, 0), pos + Vector3(0, h, 0) + dv * 1.5, PnjUtil.PNJ_LAYER if pnj_seul else 0xFFFFFFFF)
		q.exclude = [player.get_rid()]
		if espace.intersect_ray(q):
			return false
	return true


func _stop() -> void:
	Input.action_release("move_forward")
	last_pos = Vector3.INF
	stuck_t = 0.0


func _physics_process(delta: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		histoire = scene.get_node("Histoire")
		hud = scene.get_node("HUD")
		com = scene.get_node("Commerce")
		root.get_node("Partie").nouvelle_partie()
	if frame < 150:
		return false
	if phase == "init":
		scene.get_node("Lieux")._spawn_home()
		histoire.set("secondes_par_caractere", 0.0)      # le test n'attend pas la lecture lente des repliques
		histoire.commencer()
		_check(com.spots.any(func(s: Dictionary) -> bool: return s["kind"] == "etal_pain"), "etals de pain connus du commerce")
		var etal: Vector3 = histoire.points["etal"]
		_check(etal.distance_to(histoire.points["maison"]) > 21.0 or etal.distance_to(histoire.points["maison"]) < 19.0,
			"etal reel (pas le point par defaut a 20 m de la maison) : %.0f m" % etal.distance_to(histoire.points["maison"]))
		phase = "vers_tante"
		return false
	t += delta
	if t > 240.0:
		_check(false, "prologue fini en 4 min (bloque en phase %s, joueur %s)" % [phase, player.global_position])
		return _end()
	if stuck_t > 6.0:
		_check(false, "joueur bloque en phase %s a %s (objectif %s)" % [phase, player.global_position, cible])
		var fwd := Vector3(cible.x - player.global_position.x, 0, cible.z - player.global_position.z).normalized()
		for h in [0.3, 1.0, 1.6]:
			var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, h, 0), player.global_position + Vector3(0, h, 0) + fwd * 1.5)
			q.exclude = [player.get_rid()]
			var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
			if hit:
				print("  obstacle a %.1f m de haut : %s a %s" % [h, (hit["collider"] as Node).get_path(), hit["position"]])
		var qp := PhysicsShapeQueryParameters3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 2.5
		qp.shape = sph
		qp.transform = Transform3D(Basis(), player.global_position + Vector3(0, 0.8, 0))
		qp.exclude = [player.get_rid()]
		for r in player.get_world_3d().direct_space_state.intersect_shape(qp, 16):
			print("  autour : ", (r["collider"] as Node).get_path())
		print("  sorties ", scene.get_node("Lieux").sorties, "
  route ", (hud.get("route") as PackedVector2Array).slice(0, 5))
		return _end()
	match phase:
		"vers_tante", "retour":
			cible = histoire.points["tante"]
			if _walk_to(cible, delta) < 1.4:
				_stop()
				phase = "parler" if phase == "vers_tante" else "donner"
		"parler", "donner":
			if histoire.step >= 0 and histoire.missions[histoire.idx]["etapes"][histoire.step]["t"] == "parler":
				_tap("parler")
				phase = "attente_etal" if phase == "parler" else "fin"
		"attente_etal":
			if histoire.missions[histoire.idx]["etapes"][histoire.step]["t"] == "acheter":
				cible = histoire.get("_marker_pos")
				_check(cible != Vector3.INF, "objectif du pain marque (fleche) a %.0f m" % player.global_position.distance_to(cible))
				_check(hud.get("has_waypoint") or player.global_position.distance_to(cible) < 12.0, "GPS vers l'etal (ou etal a moins de 12 m)")
				phase = "vers_etal"
		"vers_etal":
			var d := _walk_to(cible, delta)
			if not com.get("_near").is_empty() and com.get("_near")["kind"] == "etal_pain" and d < 2.0:
				_stop()
				_tap("parler")
				phase = "menu"
		"menu":
			if com.get("_open") == "etal_pain":
				_key(KEY_1, true)
				phase = "lacher"
		"lacher":
			hold += 1
			if hold < 6 or (hold < 60 and not root.get_node("Partie").a("Pain")):
				if hold % 10 == 0:
					_key(KEY_1, false)
				elif hold % 10 == 2:
					_key(KEY_1, true)
				return false
			_key(KEY_1, false)
			print("  argent ", root.get_node("Partie").argent, " inventaire ", root.get_node("Partie").inventaire, " menu ", com.get("_open"))
			_check(root.get_node("Partie").a("Pain"), "pain achete au clavier (T puis 1)")
			_tap("parler")
			phase = "retour"
		"fin":
			if int(root.get_node("Partie").drapeaux.get("mission", 0)) >= 1:
				_check(true, "prologue termine en %.0f s de jeu" % t)
				return _end()
	return false


func _end() -> bool:
	Input.action_release("move_forward")
	print("RESULTAT test_prologue : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
