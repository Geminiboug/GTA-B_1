extends Node3D
## Stations-service fictives "Bon Plein" (demande d'Olympe du 21/10/2026 : carburant, stations, pompistes PNJ).
## - Stations posees le long des grands axes (auvent, deux pompes, kiosque, enseigne), plus une pres de chaque lieu connu ;
## - un pompiste PNJ (gilet rouge) apparait quand le joueur approche ;
## - en vehicule, arret pres d'une pompe : T fait le plein (prix du litre, paye au fur et a mesure) ;
## - a pied pres de son vehicule avec une bouteille d'essence du kpayo : T verse le litre dans le reservoir.
## Les vehicules ont un reservoir et une consommation (voiture.gd, zem.gd) ; panne seche = moteur coupe.

const ANIM := preload("res://scripts/anim_ctrl.gd")

@export var nombre := 8
@export var prix_litre := 650            # FCFA (prix a la pompe, comme le kpayo)
@export var debit := 2.0                 # L/s a la pompe
@export var distance_pompiste := 110.0   # m : le pompiste existe quand le joueur est plus pres que ca
@export var seed_value := 4321

var stations: Array = []                 # {pos, yaw, noeud, pompes: [Vector3], pompiste: Node3D}
var _carte: Carte
var _player: Node3D
var _hud: Node
var _rng := RandomNumberGenerator.new()
var _plein := {}                         # remplissage en cours : {veh, litres, paye, station}
var _tick := 0

const ANCRES := [Vector2(430, -250), Vector2(600, 150), Vector2(-150, 240), Vector2(-150, -840), Vector2(550, -1080),
	Vector2(1800, -700), Vector2(-1500, -300), Vector2(-2800, -340)]


func _ready() -> void:
	_rng.seed = seed_value
	_player = get_node_or_null("../Player")
	_hud = get_node_or_null("../HUD")
	_carte = Carte.zone()
	Partie.chantier(_placer)


func _placer() -> void:
	if _carte == null:
		return
	var candidats: Array = []
	for e in _carte.edges.size():
		var ed: Dictionary = _carte.edges[e]
		if ed["major"] and ed["kind"] != "track" and float(ed["len"]) > 70.0:
			candidats.append(e)
	for ancre in ANCRES:
		if stations.size() >= nombre:
			break
		var nr := _carte.nearest_on_network(ancre)
		if not nr.is_empty():
			_essayer(int(nr["edge"]), float(nr["along"]), 300.0)
	var essais := 0
	while stations.size() < nombre and essais < 400 and not candidats.is_empty():
		essais += 1
		var e: int = candidats[_rng.randi() % candidats.size()]
		_essayer(e, _rng.randf_range(20.0, maxf(21.0, float(_carte.edges[e]["len"]) - 20.0)), 700.0)


func _essayer(e: int, along: float, ecart_mini: float) -> void:
	var ed: Dictionary = _carte.edges[e]
	if ed["kind"] == "track":
		return
	var pts: PackedVector2Array = _carte.edge_pts_from(e, ed["a"])
	var acc := 0.0
	var i := 0
	while i < pts.size() - 2 and acc + pts[i].distance_to(pts[i + 1]) < along:
		acc += pts[i].distance_to(pts[i + 1])
		i += 1
	var d := (pts[i + 1] - pts[i]).normalized()
	var c := pts[i] + d * (along - acc)
	var n := Vector2(-d.y, d.x)
	for cote in [1.0, -1.0]:
		var centre: Vector2 = c + n * cote * (float(ed["width"]) * 0.5 + 9.0)
		var ok := true
		for s in stations:
			if Vector2((s["pos"] as Vector3).x, (s["pos"] as Vector3).z).distance_to(centre) < ecart_mini:
				ok = false
		if not ok:
			return
		# emprise de 16 x 12 m libre de batiments et hors de la chaussee
		for dx in [-8.0, 0.0, 8.0]:
			for dz in [-6.0, 0.0, 6.0]:
				var q: Vector2 = centre + d * float(dx) + n * float(dz)
				if _carte.in_building(q) or not _carte.in_bounds(q) or _carte.on_carriageway(q, 1.0):
					ok = false
		if not ok:
			continue
		_poser(centre, atan2(-d.x, -d.y), -cote * n)
		return


func _mat(c: Color, rugueux := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugueux
	return m


func _boite(parent: Node3D, taille: Vector3, pos: Vector3, mat: Material, collision := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collision:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		sb.add_child(cs)
		sb.position = pos
		parent.add_child(sb)
	return mi


func _poser(centre: Vector2, yaw: float, vers_rue: Vector2) -> void:
	var racine := Node3D.new()
	racine.name = "Station_%d" % stations.size()
	add_child(racine)
	racine.global_position = Vector3(centre.x, 0.0, centre.y)
	racine.rotation.y = yaw
	var gris := _mat(Color(0.2, 0.2, 0.22))
	var blanc := _mat(Color(0.93, 0.93, 0.9))
	var rouge := _mat(Color(0.75, 0.08, 0.08), 0.5)
	var vert := _mat(Color(0.1, 0.5, 0.25))
	# dalle de beton, auvent sur 4 poteaux, deux pompes, kiosque
	_boite(racine, Vector3(16.0, 0.06, 12.0), Vector3(0, 0.03, 0), _mat(Color(0.55, 0.55, 0.52), 0.95))
	_boite(racine, Vector3(9.0, 0.35, 6.0), Vector3(0, 4.6, 0), blanc)
	_boite(racine, Vector3(9.0, 0.12, 6.0), Vector3(0, 4.38, 0), rouge)
	for px in [-4.0, 4.0]:
		for pz in [-2.6, 2.6]:
			_boite(racine, Vector3(0.3, 4.4, 0.3), Vector3(px, 2.2, pz), blanc, true)
	var pompes: Array = []
	for px in [-2.0, 2.0]:
		_boite(racine, Vector3(1.1, 0.25, 0.8), Vector3(px, 0.15, 0), gris)          # ilot
		_boite(racine, Vector3(0.5, 1.5, 0.4), Vector3(px, 0.9, 0), rouge, true)
		_boite(racine, Vector3(0.52, 0.35, 0.42), Vector3(px, 1.55, 0), blanc)
		_boite(racine, Vector3(0.36, 0.2, 0.02), Vector3(px, 1.25, -0.21), _mat(Color(0.03, 0.05, 0.03))).name = "ecran"
		var l := Label3D.new()
		l.text = "%d F/L" % prix_litre
		l.font_size = 40
		l.pixel_size = 0.0025
		l.modulate = Color(0.4, 1.0, 0.45)
		l.shaded = false
		l.position = Vector3(px, 1.25, -0.225)
		l.rotation.y = PI
		racine.add_child(l)
		var l2 := Label3D.new()
		l2.text = "%d F/L" % prix_litre
		l2.font_size = 40
		l2.pixel_size = 0.0025
		l2.modulate = Color(0.4, 1.0, 0.45)
		l2.shaded = false
		l2.position = Vector3(px, 1.25, 0.225)
		racine.add_child(l2)
		# la voiture s'arrete le long de l'ilot, du cote de la rue ou de l'autre (le plus proche compte)
		pompes.append(racine.global_transform * Vector3(px, 0.0, 0.0))
	_boite(racine, Vector3(3.5, 2.6, 3.0), Vector3(-6.5 * 1.0, 1.3, -4.5), blanc, true)    # kiosque
	_boite(racine, Vector3(3.7, 0.3, 3.2), Vector3(-6.5, 2.75, -4.5), vert)
	# enseigne sur mat : "STATION BON PLEIN"
	_boite(racine, Vector3(0.25, 7.0, 0.25), Vector3(7.2, 3.5, 4.5), gris, true)
	var panneau := _boite(racine, Vector3(3.2, 1.4, 0.2), Vector3(7.2, 7.1, 4.5), vert)
	for sens in [1.0, -1.0]:
		var t := Label3D.new()
		t.text = "STATION\nBON PLEIN"
		t.font_size = 72
		t.pixel_size = 0.0075
		t.modulate = Color(1.0, 0.85, 0.15)
		t.outline_size = 0
		t.shaded = false
		t.position = panneau.position + Vector3(0, 0, 0.11 * sens)
		t.rotation.y = 0.0 if sens > 0.0 else PI
		racine.add_child(t)
	# repere orange sur la mini-carte (meme groupe que les stationnements de zems)
	var rep := Node3D.new()
	rep.add_to_group("carte_repere")
	rep.set_meta("couleur", Color(0.95, 0.5, 0.1))
	racine.add_child(rep)
	stations.append({"pos": racine.global_position, "yaw": yaw, "noeud": racine, "pompes": pompes, "pompiste": null})


# ------------------------------------------------------------------ jeu
func _physics_process(delta: float) -> void:
	if _player == null or _carte == null:
		return
	_tick += 1
	var pv: Node3D = _player.get("vehicle")
	var ppos: Vector3 = pv.global_position if pv else _player.global_position
	if _tick % 30 == 0:
		_pompistes(ppos)
	if not _plein.is_empty():
		_remplir(delta)
		return
	if pv:
		_en_vehicule(pv)
	else:
		_a_pied()


func _pompistes(ppos: Vector3) -> void:
	for s in stations:
		var d: float = (s["pos"] as Vector3).distance_to(ppos)
		var p: Node3D = s["pompiste"]
		if d < distance_pompiste and (p == null or not is_instance_valid(p)):
			p = PnjUtil.make("homme", false)
			p.set_script(ANIM)
			add_child(p)
			var look := {"skin": PnjUtil.SKINS[_rng.randi() % PnjUtil.SKINS.size()], "top": PnjUtil.plain(Color(0.8, 0.1, 0.1)),
				"legs": PnjUtil.plain(Color(0.12, 0.12, 0.14)), "cloth": PnjUtil.plain(Color(0.12, 0.12, 0.14)),
				"show": ["chr_haut", "chr_pantalon", "chr_chaussures", "chr_cheveux"], "face": PnjUtil.random_face(_rng)}
			PnjUtil.apply(p, look)
			var pompes: Array = s["pompes"]
			var base: Vector3 = (pompes[0] as Vector3 + pompes[1] as Vector3) * 0.5
			var node: Node3D = s["noeud"]
			p.global_position = node.global_transform * Vector3(0.0, 0.0, 1.5)
			p.rotation.y = node.rotation.y + PI
			s["pompiste"] = p
		elif d > distance_pompiste * 1.4 and p != null and is_instance_valid(p):
			p.queue_free()
			s["pompiste"] = null


func _station_proche(pos: Vector3, rayon: float) -> Dictionary:
	for s in stations:
		for q in s["pompes"]:
			if Vector2(pos.x - (q as Vector3).x, pos.z - (q as Vector3).z).length() < rayon:
				return s
	return {}


func _en_vehicule(pv: Node3D) -> void:
	if pv.get("carburant") == null or bool(_player.get("pillion")):
		return
	var s := _station_proche(pv.global_position, 5.2)
	if s.is_empty() or absf(float(pv.get("speed"))) > 1.5:
		return
	var manque: float = float(pv.get("reservoir")) - float(pv.get("carburant"))
	if manque < 0.5:
		if _hud and _hud.has_method("show_hint"):
			_hud.show_hint(tr("Le réservoir est plein."))
		return
	if _hud and _hud.has_method("show_hint"):
		_hud.show_hint("%s : faire le plein (%d F/L)" % [Partie.nom_touche("parler"), prix_litre])
	if Input.is_action_just_pressed("parler"):
		_plein = {"veh": pv, "litres": 0.0, "paye": 0, "station": s}
		_dire(s, tr("Je vous fais le plein, chef !"))


func _remplir(delta: float) -> void:
	var pv: Node3D = _plein["veh"]
	var s: Dictionary = _plein["station"]
	if not is_instance_valid(pv) or absf(float(pv.get("speed"))) > 2.0 or _player.get("vehicle") != pv:
		_fin_plein(false)
		return
	var avant: float = _plein["litres"]
	var ajoute: float = pv.call("faire_le_plein", debit * delta)
	_plein["litres"] = avant + ajoute
	# paye au fur et a mesure : un litre a la fois
	while int(_plein["litres"]) > int(_plein["paye"] / float(prix_litre)):
		if not Partie.payer(prix_litre, "Essence (station)"):
			pv.set("carburant", pv.get("carburant") - (float(_plein["litres"]) - floorf(float(_plein["paye"]) / prix_litre)))
			_fin_plein(true)
			return
		_plein["paye"] = int(_plein["paye"]) + prix_litre
	if _hud and _hud.has_method("show_hint"):
		_hud.show_hint("%s : arrêter   (%.0f L, %d F)" % [Partie.nom_touche("parler"), float(_plein["litres"]), int(_plein["paye"])])
	if ajoute <= 0.0 or Input.is_action_just_pressed("parler"):
		_fin_plein(false)


func _fin_plein(sans_argent: bool) -> void:
	var s: Dictionary = _plein["station"]
	var l: float = _plein["litres"]
	if sans_argent:
		Partie.notifier(tr("Pas assez d'argent pour le reste du plein."))
	if l > 0.2:
		Partie.notifier(tr("Plein : %.0f L pour %s.") % [l, Partie.fcfa(int(_plein["paye"]))])
		_dire(s, tr("Merci, bonne route !"))
	_plein = {}


func _dire(s: Dictionary, texte: String) -> void:
	var p: Node3D = s["pompiste"]
	if p and is_instance_valid(p):
		Bulle.say(p, texte, 2.4, 2.05)


func _a_pied() -> void:
	# bouteille d'essence du kpayo versee dans le reservoir du vehicule le plus proche (pas pres d'un vendeur)
	if not Partie.a("Essence (1 litre)"):
		return
	var com := get_node_or_null("../Commerce")
	if com and not (com.get("_near") as Dictionary).is_empty():
		return
	var best: Node3D = null
	var bd := 3.2
	for v in get_tree().get_nodes_in_group("vehicules"):
		if v.get("carburant") == null or v.get("has_rider"):
			continue
		var d := _player.global_position.distance_to(v.global_position)
		if d < bd and float(v.get("reservoir")) - float(v.get("carburant")) >= 1.0:
			bd = d
			best = v
	if best == null:
		return
	if _hud and _hud.has_method("show_hint"):
		_hud.show_hint("%s : verser l'essence dans le réservoir" % Partie.nom_touche("parler"))
	if Input.is_action_just_pressed("parler"):
		if Partie.retirer("Essence (1 litre)"):
			best.call("faire_le_plein", 1.0)
			Partie.notifier(tr("1 litre versé dans le réservoir."))
