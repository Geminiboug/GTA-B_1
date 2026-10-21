extends SceneTree
## Vendeurs assis : de vrais personnages poses sur les places des etals des tuiles chargees (jamais assis dans le
## vide), qui reagissent quand on les frappe (se levent : chute, fuite, riposte ou appel), puis retournent s'asseoir,
## et qui partent avec leur tuile quand elle est dechargee.
var frame := 0
var scene: Node
var fails := 0
var peds: Node
var cible: Dictionary = {}
var etape := 0
var t0 := 0


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _assis() -> Array:
	return peds.get("_walkers").filter(func(w: Dictionary) -> bool: return w.has("chaise"))


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame > 60 * 240:
		_check(false, "delai depasse (etape %d)" % etape)
		return _fin()
	if frame < 60:
		return false
	peds = scene.get_node("Pietons")
	var props: Node = scene.get_node("Props")
	var monde: Node = scene.get_node("zone_aeroport")
	if etape == 0:
		if not props.get("placed") or int(root.get_node("Partie").call("taches_en_attente")) > 0 or _assis().is_empty():
			return false
		var vs := _assis()
		var dans_tuile := 0
		var sur_place := 0
		for w in vs:
			var c: Transform3D = w["chaise"]
			for cle in monde.get("tuiles"):
				var tu: Dictionary = monde.get("tuiles")[cle]
				if tu["noeud"] != null and (tu["rect"] as Rect2).grow(0.05).has_point(Vector2(c.origin.x, c.origin.z)):
					dans_tuile += 1
					break
			for s in props.get("vendor_spots"):
				if (s as Transform3D).origin.distance_to(c.origin) < 0.05:
					sur_place += 1
					break
		_check(vs.size() >= 5, "vendeurs assis (%d)" % vs.size())
		_check(dans_tuile == vs.size(), "tous sur une tuile chargee (%d / %d)" % [dans_tuile, vs.size()])
		_check(sur_place == vs.size(), "tous sur une place d'etal (tabouret ou chaise) (%d / %d)" % [sur_place, vs.size()])
		var assis_ok := 0
		for w in vs:
			assis_ok += 1 if w["state"] == "assis" and (w["node"] as Node).get("seated") else 0
		_check(assis_ok == vs.size(), "pose assise (%d / %d)" % [assis_ok, vs.size()])
		# on frappe le premier vendeur
		cible = vs[0]
		# le joueur a cote (les personnages lointains ne sont pas animes : il ne se releverait pas)
		(scene.get_node("Player") as Node3D).global_position = (cible["pos"] as Vector3) + Vector3(0, 0.3, 1.6)
		var p: Vector3 = cible["pos"]
		var origin := p + Vector3(0, 0, 1.0)
		var touche: bool = peds.call("player_attack", origin, (p - origin).normalized(), 2)
		_check(touche, "le coup touche le vendeur")
		etape = 1
		t0 = frame
		return false
	if etape == 1 and frame - t0 == 10:
		_check(cible["state"] != "assis" and not (cible["node"] as Node).get("seated"), "le vendeur reagit au coup (etat %s)" % cible["state"])
		etape = 2
		t0 = frame
		return false
	if etape == 2:
		if cible["state"] == "assis":
			_check(true, "il retourne s'asseoir a son etal")
			# depart de la tuile : on emmene le joueur tres loin, les vendeurs de depart partent avec leurs tuiles
			var player: Node3D = scene.get_node("Player")
			player.global_position = Vector3(-2800, 3, 120)
			etape = 3
			t0 = frame
		elif frame - t0 > 60 * 60:
			_check(false, "il retourne s'asseoir (etat %s)" % cible["state"])
			return _fin()
		return false
	if etape == 3 and frame - t0 > 60 * 20:
		_check(not is_instance_valid(cible["node"]) or (cible["node"] as Node).is_queued_for_deletion() or not _assis().has(cible), "le vendeur part avec sa tuile")
		return _fin()
	return false


func _fin() -> bool:
	print("RESULTAT test_vendeurs : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
