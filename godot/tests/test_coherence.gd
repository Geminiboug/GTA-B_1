extends SceneTree
## Test de coherence du monde : rien d'incoherent sur les routes.
## - batiments : aucun sur une chaussee ; voitures garees : aucune sur une chaussee ;
## - vehicules en circulation : toujours sur une chaussee (ou dans un carrefour) ;
## - pietons : jamais sur la chaussee sauf pendant une traversee ;
## - joueur et zem : poses SUR le sol (pas dedans) ;
## - lieux a interieur : rien de gare ni de construit dedans, entrees degagees, porte automatique, PNJ, cour du joueur.
## Lancement : godot --headless --path godot --script res://tests/test_coherence.gd

var frame := 0
var scene: Node
var carte: Carte
var traffic: Node
var peds: Node
var props: Node
var off_road := 0
var car_samples := 0
var ped_on_road := 0
var ped_samples := 0
var ped_cross := 0
var start_peds: Array = []
var start_cars: Array = []
var fails := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	carte = Carte.zone()
	traffic = scene.get_node("Circulation")
	peds = scene.get_node("Pietons")
	props = scene.get_node("Props")


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _near_node(p: Vector2, r: float) -> bool:
	for n in carte.nodes:
		if n.distance_to(p) < r:
			return true
	return false


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame == 30:
		# batiments
		var bad := 0
		for b in carte.data["buildings"]:
			var c := Vector2.ZERO
			for q in b["pts"]:
				c += Vector2(float(q[0]), float(q[1]))
			c /= b["pts"].size()
			if carte.road_at(c) >= 0:
				bad += 1
		_check(bad == 0, "batiments sur une chaussee : %d / %d" % [bad, carte.data["buildings"].size()])
		print("      graphe : %d carrefours, %d troncons" % [carte.nodes.size(), carte.edges.size()])
	if frame == 60:
		# voitures garees
		var bad := 0
		for pk in props.parked:
			var xf: Transform3D = pk["xf"]
			var hl := 0.9 if pk["model"] == "zem" else 2.2
			var hw := 0.3 if pk["model"] == "zem" else 0.9
			for off in [Vector3.ZERO, Vector3(0, 0, hl), Vector3(0, 0, -hl), Vector3(hw, 0, 0), Vector3(-hw, 0, 0)]:
				var q: Vector3 = xf * off
				if carte.road_at(Vector2(q.x, q.z)) >= 0:
					bad += 1
					break
		_check(bad == 0, "voitures garees sur la chaussee : %d / %d" % [bad, props.parked.size()])
		for a in traffic._agents:
			start_cars.append(a["vis_pos"])
		for w in peds._walkers:
			start_peds.append(w["pos"])
	if frame > 60 and frame % 15 == 0 and frame < 60 + 30 * 60:
		for a in traffic._agents:
			var p := Vector2(a["vis_pos"].x, a["vis_pos"].z)
			car_samples += 1
			if carte.road_at(p) < 0 and not _near_node(p, 9.0):
				off_road += 1
		for w in peds._walkers:
			var p := Vector2(w["pos"].x, w["pos"].z)
			ped_samples += 1
			if w.get("state", "walk") != "walk":
				continue  # reaction en cours (accident, dispute...) : peut etre sur la chaussee, les vehicules s'arretent
			if w["cross"]:
				ped_cross += 1
			elif carte.road_at(p) >= 0:
				ped_on_road += 1
				if OS.get_cmdline_user_args().has("--detail") and ped_on_road <= 12:
					print("      pieton sur chaussee : ", p, " prom=", w["prom"], " far=", w.get("far"), " pause=%.1f" % w["pause"],
						" off=%.2f" % w.get("off", 0.0), " larg=", carte.edges[w["edge"]]["width"] if w.has("edge") else -1,
						" route=", carte.road_at(p), " arete=", w.get("edge"))
	if frame == 60 + 30 * 60:
		_check(off_road <= car_samples / 200, "vehicules hors chaussee : %d / %d mesures" % [off_road, car_samples])
		_check(ped_on_road <= ped_samples / 200, "pietons sur la chaussee hors traversee : %d / %d mesures (en traversee : %d)" % [ped_on_road, ped_samples, ped_cross])
		var moving := 0
		var dist := 0.0
		for k in traffic._agents.size():
			if traffic._agents[k]["speed"] > 1.0:
				moving += 1
			dist += (traffic._agents[k]["vis_pos"] as Vector3).distance_to(start_cars[k])
		var n: int = traffic._agents.size()
		_check(moving >= n / 2, "vehicules qui roulent : %d / %d, distance moyenne en 30 s : %.0f m" % [moving, n, dist / n])
		var wd := 0.0
		var nw := mini(peds._walkers.size(), start_peds.size())      # les vendeurs des tuiles s'ajoutent a la liste apres le depart
		for k in nw:
			wd += (peds._walkers[k]["pos"] as Vector3).distance_to(start_peds[k])
		_check(wd / nw > 15.0, "pietons : distance moyenne en 30 s : %.1f m" % (wd / nw))
		# joueur pose sur une route
		var e: Dictionary = carte.edges[0]
		var rp: Vector2 = (e["pts"] as PackedVector2Array)[0].lerp((e["pts"] as PackedVector2Array)[1], 0.5)
		var pl: CharacterBody3D = scene.get_node("Player")
		pl.global_position = Vector3(rp.x, 1.0, rp.y)
		pl.reset_physics_interpolation()
		var zem: Node3D = scene.get_node("Zem")
		zem.global_position = Vector3(rp.x + 3.0, 0.5, rp.y)
	if frame == 60 + 33 * 60:
		var pl: CharacterBody3D = scene.get_node("Player")
		var zem: CharacterBody3D = scene.get_node("Zem")
		_check(pl.is_on_floor() and absf(pl.global_position.y) < 0.03, "joueur sur la route : y = %.3f" % pl.global_position.y)
		_check(zem.is_on_floor() and absf(zem.global_position.y) < 0.05, "zem sur la route : y = %.3f" % zem.global_position.y)
		_check_lieux_static()
		# joueur juste a l'interieur de l'Ararat : porte ouverte, PNJ presents, nom du lieu
		var f := _door_frame("ararat")
		pl.global_position = (f[0] as Vector3) - (f[1] as Vector3) * 3.0 + Vector3(0, 0.3, 0)
		pl.reset_physics_interpolation()
	if frame == 60 + 33 * 60 + 150:
		var lieux: Node = scene.get_node("Lieux")
		var opened := 0
		for d in lieux.doors:
			if String((d["body"] as Node).get_parent().name).begins_with("porte_coulissante_ararat") and d["open"] > 0.9:
				opened += 1
		_check(opened == 2, "porte automatique de l'Ararat ouverte a l'approche : %d / 2 vantaux" % opened)
		var pn: Node = lieux.get_node("PNJ_ararat")
		_check(pn._statics.size() >= 8 and pn._walkers.size() >= 8, "Ararat : %d PNJ en poste, %d clients" % [pn._statics.size(), pn._walkers.size()])
		_check(lieux._current_zone == "ararat", "nom du lieu affiche en entrant : '%s'" % lieux._current_zone)
		var pl: CharacterBody3D = scene.get_node("Player")
		pl.global_position = lieux.home_position() + Vector3(0, 0.3, 0)
		pl.reset_physics_interpolation()
	if frame == 60 + 33 * 60 + 270:
		var pl: CharacterBody3D = scene.get_node("Player")
		var hp: Vector3 = scene.get_node("Lieux").home_position()
		_check(pl.is_on_floor() and absf(pl.global_position.y - 0.024) < 0.05 and Vector2(pl.global_position.x - hp.x, pl.global_position.z - hp.z).length() < 0.5,
			"joueur dans sa cour : y = %.3f, a %.2f m du point de depart" % [pl.global_position.y, Vector2(pl.global_position.x - hp.x, pl.global_position.z - hp.z).length()])
		print("RESULTAT : %s" % ("tout est coherent" if fails == 0 else "%d echec(s)" % fails))
		return true
	return false


func _door_frame(lieu: String) -> Array:
	var r := scene.get_node("Lieux/Lieu_" + lieu)
	var g := (r.find_child("porte_coulissante_%s_g" % lieu, true, false) as Node3D).global_position
	var d := (r.find_child("porte_coulissante_%s_d" % lieu, true, false) as Node3D).global_position
	var s := (r.find_child("texte_%s_enseigne" % lieu, true, false) as Node3D).global_position
	var mid := (g + d) * 0.5
	return [mid, Vector3(s.x - mid.x, 0, s.z - mid.z).normalized()]


func _check_lieux_static() -> void:
	## Lieux a interieur : presents, rien de pose dedans (vehicules gares, batiments OSM), entree degagee.
	var lieux: Node = scene.get_node("Lieux")
	var polys := {}
	for k in carte.data["lieux"]:
		var poly := PackedVector2Array()
		for q in carte.data["lieux"][k]["pts"]:
			poly.append(Vector2(float(q[0]), float(q[1])))
		polys[k] = poly
		_check(lieux.has_node("Lieu_" + String(k)), "lieu '%s' charge" % k)
	var bad := 0
	for pk in props.parked:
		var p: Vector3 = (pk["xf"] as Transform3D).origin
		for k in polys:
			if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), polys[k]):
				bad += 1
	_check(bad == 0, "vehicules gares dans un lieu (maison, magasin, terminal) : %d" % bad)
	bad = 0
	for b in carte.data["buildings"]:
		if String(b.get("style", "")).begins_with("lieu_"):
			continue
		for q in b["pts"]:
			for k in polys:
				if Geometry2D.is_point_in_polygon(Vector2(float(q[0]), float(q[1])), polys[k]):
					bad += 1
	_check(bad == 0, "coins de batiments a l'interieur d'un lieu : %d" % bad)
	# devant chaque porte automatique : 6 m sans batiment
	for lieu in ["ararat", "terminal"]:
		var f := _door_frame(lieu)
		var blocked := 0
		for t in range(1, 13):
			var q: Vector3 = (f[0] as Vector3) + (f[1] as Vector3) * (t * 0.5)
			if carte.in_building(Vector2(q.x, q.z)) and t > 2:
				blocked += 1
		_check(blocked == 0, "entree de '%s' degagee sur 6 m" % lieu)
