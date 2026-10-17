extends SceneTree
## Corps a corps (phase 14) : enchainement direct / croise / crochet au clic, passant bagarreur qui se met en garde
## et rend les coups (degats au joueur), garde qui pare, roulade qui esquive, K.-O. a zero point de vie, passant
## qui appelle la police au telephone.

var frame := 0
var scene: Node
var player: CharacterBody3D
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


func _click() -> void:
	Input.action_press("attaque")
	await process_frame
	await process_frame
	Input.action_release("attaque")


func _walker_in_front(caractere: String) -> Dictionary:
	## Le passant le plus proche, place devant le joueur avec le caractere voulu.
	var best: Dictionary = {}
	var bd := INF
	for x in peds._walkers:
		var d: float = (x["pos"] as Vector3).distance_to(player.global_position)
		if x["state"] == "walk" and d < bd:
			bd = d
			best = x
	var fwd := Vector3(-sin(player.get("_facing")), 0, -cos(player.get("_facing")))
	best["pos"] = player.global_position + fwd * 1.0
	best["pos"].y = peds.GROUND_Y
	best["caractere"] = caractere
	best["pv"] = 100.0
	best["state"] = "angry"        # immobile face au joueur (la marche le replacerait sur son trajet)
	best["state_t"] = 0.0
	return best


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		peds = scene.get_node("Pietons")
		root.get_node("Partie").nouvelle_partie()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if frame == 120:
		w = _walker_in_front("bagarreur")
		_click()
	if frame == 145:
		_click()
	if frame == 170:
		_click()
	if frame == 172:
		_check(int(player.get("combo")) == 2, "enchainement : 3e coup = crochet (combo %d)" % player.get("combo"))
	if frame == 200:
		_check(float(w["pv"]) < 100.0 and w["state"] in ["down", "stagger", "fight"], "le passant encaisse (%.0f pv, etat %s)" % [w["pv"], w["state"]])
		mark["sante"] = float(root.get_node("Partie").sante)
	if frame == 200 + 60 * 8:
		# le bagarreur s'est releve et rend les coups
		_check(w["state"] == "fight" or float(root.get_node("Partie").sante) < mark["sante"], "le bagarreur se bat (etat %s, sante %.0f -> %.0f)" % [w["state"], mark["sante"], root.get_node("Partie").sante])
		# garde : on fait face et on pare
		var to: Vector3 = w["pos"] - player.global_position
		player.set("_facing", atan2(-to.x, -to.z))
		Input.action_press("garde")
	if frame == 200 + 60 * 8 + 5:
		var s0: float = root.get_node("Partie").sante
		player.hurt(10.0, w["pos"])
		var s1: float = root.get_node("Partie").sante
		_check(player.get("garde") and s0 - s1 < 2.0, "garde : coup pare (%.1f pv perdus)" % (s0 - s1))
		Input.action_press("jump")
	if frame == 200 + 60 * 8 + 7:
		Input.action_release("jump")
		var s0: float = root.get_node("Partie").sante
		player.hurt(10.0, w["pos"])
		_check(float(player.get("_roll_t")) > 0.0 and root.get_node("Partie").sante == s0, "roulade : coup esquive")
		Input.action_release("garde")
	if frame == 200 + 60 * 10:
		# K.-O. : plus de points de vie, il reste a terre
		w["pv"] = 5.0
		w["state"] = "fight"
		var to: Vector3 = w["pos"] - player.global_position
		peds.player_attack(w["pos"] - to.normalized() * 0.8, to.normalized(), 0)
		_check(w["state"] == "down" and float(w["lie"]) >= 4.0, "K.-O. a zero point de vie (a terre %.1f s)" % w["lie"])
	if frame == 200 + 60 * 11:
		# un autre passant appelle la police
		root.get_node("Partie").set_recherche(0)
		var w2 := _walker_in_front("telephone")
		mark["w2"] = w2
		var fwd := Vector3(-sin(player.get("_facing")), 0, -cos(player.get("_facing")))
		w2["pos"] = player.global_position + fwd * 1.0
		peds.player_attack(player.global_position, fwd, 0)
	if frame == 200 + 60 * 11 + 60 * 9:
		var w2: Dictionary = mark["w2"]
		_check(w2.get("called", false) or w2["state"] in ["phone", "resume", "walk"], "passant au telephone : appelle la police (etat %s)" % w2["state"])
		var pol := scene.get_node("Police")
		_check(int(pol.get("appel_t") if pol.get("appel_t") != null else 0) != 0 or root.get_node("Partie").recherche > 0 or pol.get("_arrivee") != null,
			"police prevenue")
		print("RESULTAT test_combat : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
