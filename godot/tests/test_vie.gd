extends SceneTree
## Animations de vie : le joueur s'arrete en marquant le pas apres une course et fait un geste d'attente quand il
## reste immobile ; les passants s'arretent un moment ou discutent a deux (gestes captes), puis repartent.
var frame := 0
var scene: Node
var fails := 0
var pl: Node
var vu_arret := false
var vu_geste := false
var vu_pause := false
var vu_causette := false
var repartis := false
func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1
func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 40:
		pl = scene.get_node("Player")
		pl.set("attente_geste", Vector2(1.5, 2.0))
		pl.set("_prochain_geste", 1.5)
		var pe := scene.get_node("Pietons")
		pe.set("pause_chance", 0.0)
		pe.set("causette_chance", 0.9)
		Input.action_press("move_forward")
		Input.action_press("sprint")
	if frame == 160:
		Input.action_release("move_forward")
		Input.action_release("sprint")
	if frame > 160 and frame < 200:
		var an: Node = pl.get("anim")
		if an.call("playing_clip"):
			vu_arret = true
	if frame > 260 and frame < 700:
		var an: Node = pl.get("anim")
		if an.call("playing_clip"):
			vu_geste = true
		for w in scene.get_node("Pietons").get("_walkers"):
			if w["state"] == "pause":
				vu_pause = true
			if w["state"] == "causette":
				vu_causette = true
	if frame == 170:
		# le joueur va pres des deux marcheurs les plus proches l'un de l'autre (hors de portee, ils sont caches et ne
		# vivent pas leur vie de quartier)
		var ws: Array = scene.get_node("Pietons").get("_walkers")
		var best: Vector3 = ws[0]["pos"]
		var bd := INF
		var un: Dictionary = ws[0]
		var autre: Dictionary = ws[1]
		for a in ws:
			for b in ws:
				var d: float = (a["pos"] as Vector3).distance_to(b["pos"])
				if a != b and d < bd:
					bd = d
					best = a["pos"]
					un = a
					autre = b
		print("  joueur pres de deux marcheurs a %.1f m l'un de l'autre" % bd)
		if bd > 4.0 and not un["prom"]:
			# peu de marcheurs : l'autre reprend le chemin du premier, 2 m derriere (causette a moins de 6 m)
			for cle in un:
				if not cle in ["node", "partner", "speed"]:
					autre[cle] = un[cle].duplicate() if un[cle] is PackedVector2Array else un[cle]
			autre["s"] = maxf(0.0, float(un["s"]) - 2.0)
		(pl as Node3D).global_position = best + Vector3(2, 0.3, 2)
	if frame == 400:
		var n := 0
		for w in scene.get_node("Pietons").get("_walkers"):
			n += 0 if w.get("far", false) else 1
		print("  marcheurs proches : %d" % n)
	if frame == 450:
		scene.get_node("Pietons").set("causette_chance", 0.0)
		scene.get_node("Pietons").set("pause_chance", 0.3)
	if frame == 700:
		scene.get_node("Pietons").set("pause_chance", 0.0)
		scene.get_node("Pietons").set("causette_chance", 0.0)
	if frame == 1500:
		var arretes := 0
		for w in scene.get_node("Pietons").get("_walkers"):
			if w["state"] in ["pause", "causette"]:
				arretes += 1
		_check(vu_arret, "arret marque apres la course (MX_Arret)")
		_check(vu_geste, "geste d'attente quand le joueur reste immobile")
		_check(vu_pause, "des passants s'arretent un moment")
		_check(vu_causette, "des passants discutent a deux")
		_check(arretes == 0, "tous repartent ensuite (%d encore arretes)" % arretes)
		print("RESULTAT test_vie : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
