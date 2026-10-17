extends SceneTree
## Armes (phase 14) : machette achetee a la quincaillerie, coup qui fait tomber un passant ; le Gaou ne vend que la
## nuit ; pistolet : visee (haut du corps), tir qui touche le passant vise, munitions, rechargement, 2 etoiles,
## les passants fuient ; Tab change d'arme ; une biere laisse une bouteille.

var frame := 0
var scene: Node
var player: CharacterBody3D
var armes: Node
var peds: Node
var fails := 0
var w: Dictionary
var mark := {}


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _devant(dist: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for x in peds._walkers:
		var d: float = (x["pos"] as Vector3).distance_to(player.global_position)
		if x["state"] == "walk" and d < bd:
			bd = d
			best = x
	var f: float = player.get("_facing")
	best["pos"] = player.global_position + Vector3(-sin(f), 0, -cos(f)) * dist
	best["pos"].y = peds.GROUND_Y
	best["state"] = "angry"
	best["state_t"] = 0.0
	best["pv"] = 100.0
	best["caractere"] = "peureux"
	return best


func _physics_process(_d: float) -> bool:
	frame += 1
	var P := root.get_node("Partie")
	if frame == 30:
		player = scene.get_node("Player")
		armes = scene.get_node("Armes")
		peds = scene.get_node("Pietons")
		P.nouvelle_partie()
		P.argent = 400000
		scene.get_node("Police").set("arrestation", false)
		scene.get_node("JourNuit").set("hour", 11.0)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var com := scene.get_node("Commerce")
		_check(com.buy("quincaillerie", 1) and P.a("Machette"), "machette achetee a la quincaillerie")
		var g := false
		for s in com.spots:
			if s["kind"] == "gaou":
				g = true
				_check(com.nearest(s["pos"]).is_empty(), "le Gaou ne vend pas en plein jour")
		_check(g, "le Gaou est place pres de la plage")
		_check(com.buy("maquis", 3) and P.a("Bouteille"), "une biere bue laisse une bouteille")
	if frame == 60:
		Input.action_press("arme_suivante")
	if frame == 62:
		Input.action_release("arme_suivante")
		_check(armes.arme != "", "Tab : arme en main (%s)" % armes.arme)
		armes.equiper("Machette")
		_check(player.get("arme") == "Machette" and armes.get("_modele") != null, "machette dans la main droite")
		w = _devant(1.2)
		Input.action_press("attaque")
	if frame == 64:
		Input.action_release("attaque")
	if frame == 110:
		_check(w["state"] == "down" and float(w["pv"]) < 100.0, "coup de machette : le passant tombe (%.0f pv, %s)" % [w["pv"], w["state"]])
		_check(P.recherche >= 2, "arme blanche : 2 etoiles (%d)" % P.recherche)
		P.set_recherche(0)
		# pistolet
		P.ajouter("Pistolet")
		P.ajouter("Balles 9 mm", 24)
		armes.equiper("Pistolet")
		_check(int(armes.chargeur["Pistolet"]) == 12 and int(P.inventaire["Balles 9 mm"]) == 12, "chargeur plein (12), 12 en reserve")
		w = _devant(8.0)
		for x in peds._walkers:          # la foule hors de la ligne de tir (elle prendrait la balle a la place)
			if x != w and (x["pos"] as Vector3).distance_to(player.global_position) < 40.0:
				x["pos"] += Vector3(0, 0, 80)
		for x in peds._walkers:
			if x != w and x["state"] == "walk":
				var ff: float = player.get("_facing")
				x["pos"] = player.global_position + Vector3(cos(ff), 0, -sin(ff)) * 12.0   # sur le cote, hors de la ligne de tir
				x["pos"].y = peds.GROUND_Y
				mark["temoin"] = x
				break
		Input.action_press("garde")
	if frame == 140:
		_check(player.get("visee") and float(player.get("anim").get("visee")) > 0.5, "clic droit : visee (bras en position de tir)")
		var cam := root.get_viewport().get_camera_3d()
		var c: Vector3 = (w["pos"] as Vector3) + Vector3(0, 1.1, 0)
		# on vise le passant : la camera regarde vers lui
		var to := c - cam.global_position
		var pv: Node3D = player.get("cam_pivot")
		pv.rotation.y = atan2(-to.x, -to.z)
		pv.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	if frame == 150:
		armes.cible = w            # verrouillage (manette)
		var cam2 := root.get_viewport().get_camera_3d()
		var c2: Vector3 = (w["pos"] as Vector3) + Vector3(0, 1.1, 0)
		print("   vise : ecart %.2f rad, etat %s, dist %.1f" % [(-cam2.global_transform.basis.z).angle_to(c2 - cam2.global_position), w["state"], c2.distance_to(player.global_position)])
		Input.action_press("attaque")
	if frame == 152:
		Input.action_release("attaque")
		_check(int(armes.chargeur["Pistolet"]) == 11, "une balle tiree (%d dans le chargeur)" % armes.chargeur["Pistolet"])
	# une voiture qui passe peut arreter la balle : on retire au besoin (deux fois de plus)
	if (frame == 165 or frame == 180) and w["state"] != "down":
		armes.cible = w
		armes.set("_cd", 0.0)
		Input.action_press("attaque")
	if frame == 167 or frame == 182:
		Input.action_release("attaque")
	if frame == 205:
		_check(w["state"] == "down", "le passant vise est touche et tombe (%s, %.0f pv)" % [w["state"], w["pv"]])
		_check(P.recherche >= 2, "tir : la police est appelee (%d etoiles)" % P.recherche)
		var fuient := 0
		for x in peds._walkers:
			if x["state"] == "flee" and (x["pos"] as Vector3).distance_to(player.global_position) < 45.0:
				fuient += 1
		_check(fuient >= 1 and mark["temoin"]["state"] == "flee", "les passants fuient le coup de feu (%d, temoin : %s)" % [fuient, mark["temoin"]["state"]])
		Input.action_release("garde")
		armes.chargeur["Pistolet"] = 3
		P.inventaire["Balles 9 mm"] = 12
		Input.action_press("recharger")
	if frame == 207:
		Input.action_release("recharger")
	if frame == 300:
		_check(int(armes.chargeur["Pistolet"]) == 12 and int(P.inventaire.get("Balles 9 mm", 0)) == 3, "R recharge (12, reste %d)" % P.inventaire.get("Balles 9 mm", 0))
		print("RESULTAT test_armes : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
