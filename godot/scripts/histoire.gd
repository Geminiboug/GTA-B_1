extends Node
## Histoire "Le Dernier Vol" (docs/histoire.md) : prologue et acte 1, puis petits boulots de zem.
## Chaque mission commence en entrant dans le marqueur jaune de son donneur (tante, Vieux Codjo, le Commandant) ;
## ses etapes sont des donnees (parler, acheter, aller, client, deposer, photos, nuit, fuir...). Le GPS
## (scripts/hud_carte.gd) guide vers chaque objectif ; l'objectif s'affiche en bas (scripts/hud_jeu.gd).
## Une mission ratee (chrono) se recommence ; l'etape de l'histoire est sauvegardee (Partie.drapeaux["mission"]).
## Rien ne demarre tant que commencer() ou reprendre() n'a pas ete appele (ecran titre) : les tests sont tranquilles.

@export var player_path: NodePath = ^"../Player"
@export var rayon_marqueur := 1.6
@export var duree_replique := 2.8
@export var course_prix_base := 300          # FCFA, petits boulots de zem
@export var course_prix_km := 450             # FCFA par km (tarifs de zem a Cotonou : 200 a 1 000 F la course)

var points := {}                 # nom -> Vector3
var missions: Array = []
var idx := -1                     # mission en cours (ou a commencer)
var step := -1                    # -1 : en attente au marqueur du donneur
var active := false
var _player: Node3D
var _hud: Node
var _hudj: Node
var _npcs := {}
var _marker: Node3D
var _chrono := -1.0
var _dialog: Array = []
var _dialog_t := 0.0
var _photos: Array = []
var _passenger: Node3D
var _client_walker: Node3D
var _rng := RandomNumberGenerator.new()
var _fade: ColorRect
var _boulot := {}                # course de zem en cours (petits boulots)
@export var etal_decalage := 4.0        # m, vendeuse de pain a cote du portail de la maison
var _marker_pos := Vector3.INF
var _obj_text := ""
var messages: Array = []        # dernieres repliques entendues [qui, texte] (application Messages du telephone)
var _dist_t := 0.0


func _ready() -> void:
	add_to_group("histoire")
	_rng.randomize()
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null("../HUD")
	_setup.call_deferred()


func _hj() -> Node:
	if _hudj == null:
		_hudj = get_tree().get_first_node_in_group("hud_jeu")
	return _hudj


func _g(m: String, f: String) -> String:
	return f if String(_player.get("genre")) == "femme" else m


# ------------------------------------------------------------------ lieux
func _ground(x: float, z: float) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -10, z), 1)
	var hit := get_viewport().get_world_3d().direct_space_state.intersect_ray(q) if get_viewport() else {}
	return hit["position"] if not hit.is_empty() else Vector3(x, 0, z)


func _rue(x: float, z: float) -> Vector3:
	## Point de rue (reseau des routes, scripts/carte.gd) le plus proche : jamais sur un toit ni dans une cour fermee.
	var near: Dictionary = Carte.zone().nearest_on_network(Vector2(x, z)) if Carte.zone() else {}
	if near.is_empty():
		return _ground(x, z)
	var q: Vector2 = near["point"]
	return _ground(q.x, q.y)


func _nearest_shop(kind: String, from: Vector3, min_d := 0.0) -> Vector3:
	var com := get_node_or_null("../Commerce")
	var best := Vector3.INF
	var bd := INF
	if com:
		for s in com.spots:
			var d: float = (s["pos"] as Vector3).distance_to(from)
			if s["kind"] == kind and d < bd and d >= min_d:
				bd = d
				best = s["pos"]
	return best if best != Vector3.INF else from + Vector3(20, 0, 0)


func _setup() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	var com := get_node_or_null("../Commerce")
	for _i in 600:
		if com == null or com.spots.any(func(s: Dictionary) -> bool: return s["kind"] == "etal"):
			break
		await get_tree().physics_frame      # etals et maquis connus du commerce (scripts/commerce.gd)
	var lieux := get_node_or_null("../Lieux")
	var home: Vector3 = lieux.home_position() if lieux else _player.global_position
	points["maison"] = home
	var sp := lieux.get_node_or_null("Lieu_maison").find_child("spawn_joueur", true, false) as Node3D if lieux and lieux.get_node_or_null("Lieu_maison") else null
	var fwd := Vector3.FORWARD
	if sp:
		var yaw := sp.global_rotation.y + PI
		fwd = Vector3(-sin(yaw), 0, -cos(yaw))
	points["tante"] = home + fwd * 2.2 + fwd.cross(Vector3.UP) * 1.2
	_vendeuse_de_pain(lieux)
	points["etal"] = _nearest_shop("etal", home)
	points["caisse"] = _nearest_shop("caisse", home)
	points["codjo"] = _nearest_shop("maquis", home) + Vector3(1.6, 0, 1.0)
	points["colis"] = _nearest_shop("etal", home, 250.0)
	points["aerogare"] = _ground(397, -300)
	points["plage"] = _rue(622, 292)              # devant Sweet Dream Beach, sur la rue (le point exact est un toit)
	points["epave"] = _ground(-177, 247)
	points["commandant"] = _nearest_shop("maquis", points["epave"]) + Vector3(1.4, 0, 1.2)
	points["haie_verte"] = _rue(-150, -840)
	points["patronne"] = _nearest_shop("maquis", points["haie_verte"]) + Vector3(1.4, 0, 1.0)
	var air := get_node_or_null("../TraficAerien")
	var stands: Array = air.get("stands") if air else []
	for i in 3:
		var sp2: Vector2 = stands[i]["pos"] if i < stands.size() else Vector2(300 + 40 * i, -380)
		points["poste_%d" % i] = _ground(sp2.x, sp2.y)
	_build_missions()


func _vendeuse_de_pain(lieux: Node) -> void:
	## Vendeuse de pain installee devant le portail de la maison (prologue : le pain a quelques pas, comme au coin
	## de chaque rue de Cotonou). Etal de scripts/props.gd, vendeuse assise, point d'achat du commerce.
	var exits: Array = lieux.sortie(lieux.home_position()) if lieux and lieux.has_method("sortie") else []
	var props := get_node_or_null("../Props")
	var com := get_node_or_null("../Commerce")
	if exits.size() < 2 or props == null or com == null:
		return
	var out: Vector3 = (exits[1] - exits[0]).normalized()
	var side := out.cross(Vector3.UP)
	var pos: Vector3 = _ground(exits[1].x + side.x * etal_decalage + out.x * 0.5, exits[1].z + side.z * etal_decalage + out.z * 0.5)
	var xf := Transform3D(Basis.looking_at(out, Vector3.UP), pos)   # avant (-Z) vers la rue, vendeuse derriere
	var mesh: Mesh = (props.get("_meshes") as Dictionary).get("prop_etal_jaune")
	if mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		add_child(mi)
		mi.global_transform = xf
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.8, 0.8)
	cs.shape = box
	cs.position.y = 0.4
	body.add_child(cs)
	add_child(body)
	body.global_transform = xf
	var v := PnjUtil.make("femme")
	add_child(v)
	PnjUtil.dress_random(v, _rng)
	PnjUtil.pose_vendor(v, _rng)
	v.global_transform = xf * Transform3D(Basis.IDENTITY, Vector3(0.3, 0, 0.45))
	com.spots.append({"pos": pos, "kind": "etal"})


# ------------------------------------------------------------------ missions
func _build_missions() -> void:
	missions = [
		{"titre": "Bonne arrivée", "donneur": "tante", "rec": 0, "etapes": [
			{"t": "parler", "qui": "tante", "obj": "Parle à tante Mireille", "lignes": [
				["tante", "Ah, %s ! Bonne arrivée à la maison !" % _g("mon fils", "ma fille")],
				["tante", "Va m'acheter du pain chez la vendeuse, au bout de la rue. Tiens, prends de quoi payer."],
				["joueur", "J'y vais, tantie."]]},
			{"t": "acheter", "article": "Pain", "ou": "etal", "obj": "Suis la flèche jaune jusqu'à l'étal, puis T pour acheter du pain"},
			{"t": "aller", "ou": "tante", "r": 2.5, "obj": "Rapporte le pain à tante Mireille", "avec": "Pain"},
			{"t": "parler", "qui": "tante", "obj": "Donne le pain (T)", "retirer": ["Pain"], "argent": 5000, "lignes": [
				["tante", "Merci ! Ton père aurait été fier de te voir revenu."],
				["tante", "Son vieux zem est devant la maison. Il roule encore, prends-le."],
				["tante", "Tiens, 5 000 francs : va me chercher un sac de riz à l'Ararat."]]}]},
		{"titre": "Le zem de papa", "donneur": "tante", "rec": 500, "etapes": [
			{"t": "monter", "obj": "Monte sur le zem de ton père (E)"},
			{"t": "acheter", "article": "Sac de riz (5 kg)", "ou": "caisse", "obj": "Achète un sac de riz à l'Ararat Hypermarket"},
			{"t": "aller", "ou": "tante", "r": 3.0, "obj": "Rapporte le riz à la maison", "avec": "Sac de riz (5 kg)"},
			{"t": "parler", "qui": "tante", "obj": "Donne le riz (T)", "retirer": ["Sac de riz (5 kg)"], "lignes": [
				["tante", "Bien ! Va voir Vieux Codjo au maquis du coin, il cherche quelqu'un pour des livraisons."]]}]},
		{"titre": "Livraison en zem", "donneur": "codjo", "rec": 2000, "etapes": [
			{"t": "parler", "qui": "codjo", "obj": "Parle à Vieux Codjo", "lignes": [
				["codjo", "C'est toi l'enfant de Basile ? Ton père réparait tout ce qui roule et tout ce qui vole."],
				["codjo", "Tiens ce colis. Livre-le à l'étal là-bas, en moins de trois minutes. Le client n'attend pas !"]],
				"donner": "Colis"},
			{"t": "aller", "ou": "colis", "r": 4.0, "obj": "Livre le colis", "avec": "Colis", "chrono": 180.0},
			{"t": "fin", "retirer": ["Colis"]}]},
		{"titre": "Course client", "donneur": "codjo", "rec": 2500, "etapes": [
			{"t": "parler", "qui": "codjo", "obj": "Parle à Vieux Codjo", "lignes": [
				["codjo", "Un voyageur attend devant l'aérogare. Il veut aller à Sweet Dream Beach. Fais vite !"]]},
			{"t": "client", "ou": "aerogare", "obj": "Va chercher le client devant l'aérogare (en zem)"},
			{"t": "deposer", "ou": "plage", "r": 8.0, "obj": "Dépose le client à Sweet Dream Beach", "chrono": 240.0},
			{"t": "fin", "lignes": [["client", "Merci, %s ! Bonne route." % _g("tonton", "tantie")]], "drapeau": "boulots"}]},
		{"titre": "Au marché", "donneur": "tante", "rec": 0, "etapes": [
			{"t": "parler", "qui": "tante", "obj": "Parle à tante Mireille", "argent": 2000, "lignes": [
				["tante", "Il me faut de l'huile et une boîte de tomate pour la sauce. Va à l'Ararat."],
				["tante", "Voilà 2 000 francs pour les courses."]]},
			{"t": "acheter", "article": "Huile (1 litre)", "ou": "caisse", "obj": "Achète de l'huile"},
			{"t": "acheter", "article": "Boîte de tomate", "ou": "caisse", "obj": "Achète une boîte de tomate"},
			{"t": "aller", "ou": "tante", "r": 3.0, "obj": "Rentre à la maison", "avec": "Boîte de tomate"},
			{"t": "parler", "qui": "tante", "obj": "Donne les courses (T)", "retirer": ["Huile (1 litre)", "Boîte de tomate"], "lignes": [
				["tante", "Merci. Écoute... j'ai gardé quelque chose de ton père."],
				["tante", "Son carnet. Il a écrit un mot la veille du dernier vol : « Épave, cabine, rangée 12 »."],
				["joueur", "L'épave de la plage ? Papa y était ?"],
				["tante", "Je ne sais pas. Mais sois prudent. La nuit, la police patrouille sur la plage."]], "donner": "Carnet de Basile"}]},
		{"titre": "L'Épave Volante", "donneur": "tante", "rec": 0, "etapes": [
			{"t": "nuit", "obj": "Le soir tombe..."},
			{"t": "aller", "ou": "epave", "r": 9.0, "obj": "Va à l'épave, sur la plage"},
			{"t": "photos", "pts": ["epave"], "r": 9.0, "obj": "Fouille la cabine, rangée 12 (T)"},
			{"t": "fin", "lignes": [["joueur", "Une plaque d'avion arrachée... et un nom gravé : « Cdt Hounkpè »."]],
				"donner": "Plaque du cargo", "recherche": 1},
			{"t": "fuir", "obj": "Une patrouille ! Échappe à la police"}]},
		{"titre": "Le Commandant", "donneur": "commandant", "rec": 1000, "etapes": [
			{"t": "parler", "qui": "commandant", "obj": "Parle au Commandant Hounkpè", "lignes": [
				["commandant", "Dossou... Tu as les yeux de Basile."],
				["commandant", "Ce cargo ne transportait pas que du coton. Ton père avait pris des photos du chargement."],
				["commandant", "Il les a cachées au bord du tarmac, près des postes de stationnement. Va voir, de nuit."]]}]},
		{"titre": "Le hangar", "donneur": "commandant", "rec": 5000, "etapes": [
			{"t": "nuit", "obj": "La nuit tombe sur l'aéroport..."},
			{"t": "photos", "pts": ["poste_0", "poste_1", "poste_2"], "r": 10.0, "obj": "Fouille les trois postes du tarmac (T)"},
			{"t": "fin", "lignes": [["joueur", "Des photos de caisses... et le logo d'une société inconnue."]], "recherche": 2},
			{"t": "fuir", "obj": "L'alerte est donnée ! Échappe à la police"},
			{"t": "fin", "annonce": ["FIN DE L'ACTE 1", "Quelqu'un, à l'aéroport, savait. À suivre."], "chapitre": "fin_acte1"}]},
		# missions secondaires du quartier nord (phase 9)
		{"titre": "Ravitaillement", "donneur": "patronne", "rec": 3000, "etapes": [
			{"t": "parler", "qui": "patronne", "obj": "Parle à Maman Fifi, la patronne du maquis", "argent": 2000, "lignes": [
				["patronne", "C'est toi le petit de Codjo ? Le maquis ouvre ce soir et je n'ai plus d'huile ni d'eau !"],
				["patronne", "Voilà 2 000 francs pour les courses. File à l'Ararat et reviens vite, je te paierai bien."]]},
			{"t": "acheter", "article": "Huile (1 litre)", "ou": "caisse", "obj": "Achète de l'huile à l'Ararat"},
			{"t": "acheter", "article": "Eau minérale (1,5 l)", "ou": "caisse", "obj": "Achète de l'eau minérale"},
			{"t": "aller", "ou": "patronne", "r": 3.0, "obj": "Rapporte les courses au maquis de Haie Verte", "avec": "Huile (1 litre)"},
			{"t": "parler", "qui": "patronne", "obj": "Donne les courses (T)", "retirer": ["Huile (1 litre)", "Eau minérale (1,5 l)"], "lignes": [
				["patronne", "Ah, tu es rapide ! Reviens quand tu veux, il y a toujours du travail ici."]]}]},
		{"titre": "Le grand tour", "donneur": "patronne", "rec": 4000, "etapes": [
			{"t": "parler", "qui": "patronne", "obj": "Parle à Maman Fifi", "lignes": [
				["patronne", "Deux clients arrivent par l'avion du soir. Va les chercher à l'aérogare, l'un après l'autre."]]},
			{"t": "client", "ou": "aerogare", "obj": "Premier client : devant l'aérogare (en zem)"},
			{"t": "deposer", "ou": "haie_verte", "r": 10.0, "obj": "Dépose-le à Haie Verte", "chrono": 300.0},
			{"t": "fin", "lignes": [["client", "Merci ! Bonne soirée."]]},
			{"t": "client", "ou": "aerogare", "obj": "Second client : retourne à l'aérogare"},
			{"t": "deposer", "ou": "patronne", "r": 10.0, "obj": "Dépose-le au maquis de Maman Fifi", "chrono": 300.0},
			{"t": "fin", "lignes": [["client", "On m'a dit que c'était le meilleur maquis du quartier !"]]}]},
	]


func commencer() -> void:
	Partie.drapeaux["mission"] = 0
	Partie.chapitre = "prologue"
	active = true
	Partie.journal.debut("nouvelle_partie")
	_wait(0)
	if _hj():
		_hj().annonce("LE DERNIER VOL", "Cotonou, près de l'aéroport", 4.0)


func reprendre() -> void:
	active = true
	Partie.journal.debut("chargement")
	_clear_mission()
	_wait(int(Partie.drapeaux.get("mission", 0)))


func _wait(i: int) -> void:
	## Mission i : marqueur jaune au donneur, en attendant que le joueur y entre.
	idx = i
	step = -1
	_chrono = -1.0
	if idx >= missions.size():
		_objective("Petits boulots : sur le zem, T pour chercher un client" if Partie.drapeaux.get("boulots") else "")
		_set_marker(Vector3.INF)
		return
	var m: Dictionary = missions[idx]
	_spawn_npc(m["donneur"])
	_set_marker(points[m["donneur"]])
	_waypoint(points[m["donneur"]])
	_objective("Nouvelle mission : « %s » (va dans le cercle jaune)" % m["titre"])


func _start_mission() -> void:
	step = 0
	var m: Dictionary = missions[idx]
	Partie.journal.mission_debut(m["titre"])
	if _hj():
		_hj().annonce(m["titre"], "", 2.5)
	_enter_step()


func _enter_step() -> void:
	var m: Dictionary = missions[idx]
	if step >= m["etapes"].size():
		_complete()
		return
	var e: Dictionary = m["etapes"][step]
	Partie.journal.etape(step, e["t"], e.get("obj", ""))
	if e.has("chrono"):
		_chrono = float(e["chrono"])
	for a in e.get("retirer", []) if e["t"] != "parler" else []:
		Partie.retirer(a)
	_objective(e.get("obj", ""))
	_set_marker(Vector3.INF)
	match e["t"]:
		"parler":
			_spawn_npc(e["qui"])
			_set_marker(points[e["qui"]])
			_waypoint(points[e["qui"]])
		"acheter":
			var garder: Array = Partie.drapeaux.get("garder", [])
			if not garder.has(e["article"]):
				garder.append(e["article"])
			Partie.drapeaux["garder"] = garder
			var p := _nearest_shop(e["ou"], _player.global_position)
			_set_marker(p)
			_waypoint(p)
		"aller", "deposer":
			_set_marker(points[e["ou"]])
			_waypoint(points[e["ou"]])
		"client":
			_client_walker = _make_npc("homme", "", points[e["ou"]], 0.0)
			_set_marker(points[e["ou"]])
			_waypoint(points[e["ou"]])
		"photos":
			_photos = (e["pts"] as Array).duplicate()
			_next_photo()
		"nuit":
			_night()
		"fuir":
			pass
		"fin":
			if e.has("donner"):
				Partie.ajouter(e["donner"])
			if e.has("lignes"):
				_say_lines(e["lignes"])
			if e.has("recherche"):
				Partie.set_recherche(int(e["recherche"]))
			if e.has("drapeau"):
				Partie.drapeaux[e["drapeau"]] = true
			if e.has("chapitre"):
				Partie.chapitre = e["chapitre"]
			if e.has("annonce") and _hj():
				_hj().annonce(e["annonce"][0], e["annonce"][1], 6.0)
			if e.get("chapitre", "") == "fin_acte1":
				get_tree().create_timer(6.5).timeout.connect(func() -> void: get_tree().call_group("menus", "fin_demo"))
			_drop_passenger()
			step += 1
			_enter_step()


func _advance() -> void:
	var e: Dictionary = missions[idx]["etapes"][step]
	if e.has("donner") and e["t"] == "parler":
		Partie.ajouter(e["donner"])
	if e["t"] == "parler":
		for a in e.get("retirer", []):
			Partie.retirer(a)
	if e.has("argent"):
		Partie.gagner(int(e["argent"]), "Argent des courses")   # le donneur avance l argent des achats demandes
	if e.has("chrono") or e["t"] == "deposer":
		_chrono = -1.0
	step += 1
	_enter_step()


func _complete() -> void:
	var m: Dictionary = missions[idx]
	Partie.journal.mission_fin(true)
	if int(m["rec"]) > 0:
		Partie.gagner(int(m["rec"]), m["titre"])
	if _hj():
		_hj().annonce("MISSION RÉUSSIE", m["titre"], 3.5)
	Partie.missions_faites.append(m["titre"])
	if idx == 1:
		Partie.chapitre = "acte1"
	_set_marker(Vector3.INF)
	_clear_waypoint()
	Partie.drapeaux["mission"] = idx + 1
	_wait(idx + 1)


func _fail(reason: String) -> void:
	Partie.journal.mission_fin(false, reason)
	if _hj():
		_hj().annonce("MISSION ÉCHOUÉE", reason, 3.5)
	_clear_mission()
	_wait(idx)


func _clear_mission() -> void:
	_chrono = -1.0
	_drop_passenger()
	if _client_walker:
		_client_walker.queue_free()
		_client_walker = null
	for a in ["Colis"]:
		while Partie.retirer(a):
			pass


# ------------------------------------------------------------------ boucle
func _physics_process(delta: float) -> void:
	if not active or _player == null or missions.is_empty():
		return
	_dialog_step(delta)
	var pv: Node3D = _player.get("vehicle")
	var ppos: Vector3 = pv.global_position if pv else _player.global_position
	if _chrono > 0.0:
		_chrono -= delta
		if _hj():
			_hj().objectif("%s   %d:%02d" % [missions[idx]["etapes"][step].get("obj", ""), int(_chrono) / 60, int(_chrono) % 60])
		if _chrono <= 0.0:
			_fail("Trop tard !")
			return
	if idx >= missions.size():
		_boulots(delta, pv, ppos)
		return
	if step < 0:
		if Vector2(ppos.x - points[missions[idx]["donneur"]].x, ppos.z - points[missions[idx]["donneur"]].z).length() < rayon_marqueur + (2.0 if pv else 0.0):
			_start_mission()
		return
	var e0: Dictionary = missions[idx]["etapes"][step]
	if not _dialog.is_empty() and e0["t"] == "parler":
		return
	var e: Dictionary = missions[idx]["etapes"][step]
	match e["t"]:
		"parler":
			var p: Vector3 = points[e["qui"]]
			if pv == null and _player.global_position.distance_to(p) < 2.6:
				if _hud and _hud.has_method("show_hint"):
					_hud.show_hint("T : parler")
				if Input.is_action_just_pressed("parler"):
					_say_lines(e["lignes"])
					_advance()
		"acheter":
			if Partie.a(e["article"]):
				_advance()
		"aller":
			if e.has("avec") and not Partie.a(e["avec"]):
				_fail("Tu as perdu %s." % e["avec"])
				return
			var p: Vector3 = points[e["ou"]]
			if Vector2(ppos.x - p.x, ppos.z - p.z).length() < float(e.get("r", 3.0)):
				_advance()
		"monter":
			if pv != null and pv.get("kind") == "zem":
				_advance()
		"client":
			var p: Vector3 = points[e["ou"]]
			if pv and pv.get("kind") == "zem" and ppos.distance_to(p) < 6.0 and absf(float(pv.get("speed"))) < 1.5:
				_pick_passenger(pv)
				_advance()
			elif pv and pv.get("kind") == "zem" and ppos.distance_to(p) < 12.0 and _hud:
				_hud.show_hint("Arrête-toi près du client")
		"deposer":
			var p: Vector3 = points[e["ou"]]
			if pv and Vector2(ppos.x - p.x, ppos.z - p.z).length() < float(e.get("r", 6.0)) and absf(float(pv.get("speed"))) < 1.5:
				_advance()
		"photos":
			if _photos.is_empty():
				_advance()
				return
			var p: Vector3 = points[_photos[0]]
			if pv == null and Vector2(ppos.x - p.x, ppos.z - p.z).length() < float(e.get("r", 6.0)):
				if _hud:
					_hud.show_hint("T : fouiller")
				if Input.is_action_just_pressed("parler"):
					_photos.pop_front()
					Partie.notifier("Trouvé ! (%d restant)" % _photos.size() if not _photos.is_empty() else "Trouvé !")
					_next_photo()
		"fuir":
			if Partie.recherche == 0:
				_advance()


func _next_photo() -> void:
	if _photos.is_empty():
		_set_marker(Vector3.INF)
		return
	_set_marker(points[_photos[0]])
	_waypoint(points[_photos[0]])


# ------------------------------------------------------------------ petits boulots (courses de zem)
func _boulots(_delta: float, pv: Node3D, ppos: Vector3) -> void:
	if not Partie.drapeaux.get("boulots", false):
		return
	if _boulot.is_empty():
		if pv and pv.get("kind") == "zem" and absf(float(pv.get("speed"))) < 1.0:
			if _hud:
				_hud.show_hint("T : chercher un client")
			if Input.is_action_just_pressed("parler"):
				var a := ppos + Vector3(_rng.randf_range(-60, 60), 0, _rng.randf_range(-60, 60))
				var from := _ground(a.x, a.z)
				var dest := _nearest_shop(["etal", "maquis", "caisse", "cabine"][_rng.randi() % 4], ppos, 300.0)
				_boulot = {"from": from, "to": dest, "picked": false}
				_client_walker = _make_npc(PnjUtil.random_genre(_rng), "", from, 0.0)
				_set_marker(from)
				_waypoint(from)
				_objective("Va chercher le client")
		return
	if not _boulot["picked"]:
		if pv and ppos.distance_to(_boulot["from"]) < 6.0 and absf(float(pv.get("speed"))) < 1.5:
			_pick_passenger(pv)
			_boulot["picked"] = true
			_boulot["start"] = ppos
			_set_marker(_boulot["to"])
			_waypoint(_boulot["to"])
			_objective("Dépose le client")
		elif pv == null and ppos.distance_to(_boulot["from"]) > 400.0:
			_end_boulot(false)
	else:
		var to: Vector3 = _boulot["to"]
		if pv and Vector2(ppos.x - to.x, ppos.z - to.z).length() < 8.0 and absf(float(pv.get("speed"))) < 1.5:
			var km: float = (_boulot["start"] as Vector3).distance_to(to) / 1000.0
			var prix := int(round((course_prix_base + course_prix_km * km) / 50.0)) * 50
			Partie.gagner(prix, "Course de zem")
			Partie.stats["courses"] = int(Partie.stats.get("courses", 0)) + 1
			Partie.journal.compter("courses_zem", 1, {"km": snappedf(km, 0.01), "prix": prix})
			_end_boulot(true)
		elif pv == null:
			Partie.notifier("Le client est descendu sans payer.")
			_end_boulot(false)


func _end_boulot(_ok: bool) -> void:
	_boulot = {}
	_drop_passenger()
	if _client_walker:
		_client_walker.queue_free()
		_client_walker = null
	_set_marker(Vector3.INF)
	_clear_waypoint()
	_objective("Petits boulots : sur le zem, T pour chercher un client")


# ------------------------------------------------------------------ personnages
func _make_npc(variant: String, kind: String, pos: Vector3, yaw: float) -> Node3D:
	var ch := PnjUtil.make(variant)
	ch.set_script(load("res://scripts/anim_ctrl.gd"))
	add_child(ch)
	PnjUtil.dress_random(ch, _rng, kind)
	ch.global_transform = Transform3D(Basis(Vector3.UP, yaw), pos)
	return ch


func _spawn_npc(key: String) -> void:
	if _npcs.has(key) and is_instance_valid(_npcs[key]):
		return
	var spec := {"tante": ["femme_ronde", ""], "codjo": ["homme_age", "zem"], "commandant": ["homme_age", ""], "patronne": ["femme_ronde", ""]}
	if not spec.has(key):
		return
	var p: Vector3 = points[key]
	var to_player := _player.global_position - p
	_npcs[key] = _make_npc(spec[key][0], spec[key][1], p, atan2(-to_player.x, -to_player.z))


func _speaker(key: String) -> Node3D:
	if key == "joueur":
		return _player
	if key == "client":
		return _passenger if _passenger else _player
	return _npcs.get(key, _player)


func _say_lines(lines: Array) -> void:
	_dialog.append_array(lines)
	_dialog_t = 0.0


const NOMS_PERSOS := {"joueur": "Sena", "tante": "Tante Mireille", "codjo": "Vieux Codjo", "commandant": "Cdt Hounkpè",
	"patronne": "Maman Fifi", "client": "Le client", "vendeuse": "La vendeuse"}
var _dernier_pnj: Node3D = null


func _cine() -> Node:
	return get_node_or_null("../Cinematique")


func _dialog_step(delta: float) -> void:
	if _dialog.is_empty():
		if _dialog_t > 0.0:
			_dialog_t -= delta
			if _dialog_t <= 0.0 and _cine() and _cine().en_cours:
				_cine().fin()
		return
	_dialog_t -= delta
	if _dialog_t <= 0.0:
		var l: Array = _dialog.pop_front()
		var who := _speaker(l[0])
		# cinematique de dialogue (a pied, a l'arret) : plan par-dessus l'epaule, sous-titre avec le nom
		var ci := _cine()
		if ci and is_instance_valid(who):
			if who != _player:
				_dernier_pnj = who
			var autre: Node3D = _player if who != _player else _dernier_pnj
			var arret: bool = _player.get("vehicle") == null and Vector2(_player.velocity.x, _player.velocity.z).length() < 0.6
			if arret and autre and is_instance_valid(autre) and autre != who:
				ci.cadrer(who, autre)
			ci.sous_titre(tr(NOMS_PERSOS.get(l[0], String(l[0]).capitalize())), tr(l[1]), duree_replique)
		if is_instance_valid(who):
			if not (ci and ci.en_cours):
				Bulle.say(who, l[1], duree_replique, 2.1, Color(1, 0.95, 0.75))
			messages.append([l[0], l[1]])
			if messages.size() > 20:
				messages.pop_front()
			# celui qui parle fait les gestes de la conversation (clip Idle_Talking)
			var an: Node = who.get("anim") if who == _player else who
			if an and an.has_method("play_clips") and (who != _player or _player.get("vehicle") == null):
				an.play_clips([["Idle_Talking", 0.0]], true)
		_dialog_t = duree_replique


func _pick_passenger(pv: Node3D) -> void:
	## Le client monte derriere : modele pose (sans animation), rattache au zem.
	var genre := "homme"
	if _client_walker:
		genre = String(_client_walker.get_meta("genre", "homme"))
		_client_walker.queue_free()
		_client_walker = null
	var pas := PnjUtil.make(PnjUtil.random_variant(_rng, genre))
	pv.add_child(pas)
	PnjUtil.dress_random(pas, _rng)
	PnjUtil.pose_passenger(pas)
	pas.position = Vector3(0, -0.02 + (0.04 if genre == "femme" else 0.0), 0.48)
	_passenger = pas


func _drop_passenger() -> void:
	if _passenger and is_instance_valid(_passenger):
		_passenger.queue_free()
	_passenger = null


# ------------------------------------------------------------------ marqueurs, GPS, nuit
func _set_marker(p: Vector3) -> void:
	if _marker == null:
		_marker = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.9
		cm.bottom_radius = 0.9
		cm.height = 2.4
		cm.cap_top = false
		cm.cap_bottom = false
		_marker.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 0.85, 0.15, 0.35)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_marker.material_override = mat
		_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marker)
		# fleche qui flotte au-dessus de l'objectif (la colonne de lumiere est celle du GPS, scripts/hud_carte.gd)
		var arrow := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.7, 0.7, 0.15)
		arrow.mesh = pm
		var amat := StandardMaterial3D.new()
		amat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		amat.albedo_color = Color(1, 0.8, 0.1)
		arrow.material_override = amat
		arrow.rotation.z = PI          # pointe vers le bas
		arrow.position.y = 1.9
		arrow.name = "Fleche"
		_marker.add_child(arrow)
	_marker.visible = p != Vector3.INF
	_marker_pos = p
	if p != Vector3.INF:
		_marker.global_position = p + Vector3(0, 1.2, 0)


func _waypoint(p: Vector3) -> void:
	if _hud and _hud.has_method("set_waypoint"):
		_hud.set_waypoint(Vector2(p.x, p.z))


func _clear_waypoint() -> void:
	if _hud and _hud.has_method("clear_waypoint"):
		_hud.clear_waypoint()


func objectif_actuel() -> String:
	return _obj_text


func _objective(t: String) -> void:
	_obj_text = t
	if _hj():
		_hj().objectif(t)


func _process(delta: float) -> void:
	## Fleche qui tourne et flotte, distance a l'objectif ajoutee au texte (hors chrono, qui reecrit le texte).
	if _marker == null or not _marker.visible:
		return
	var f := _marker.get_node("Fleche") as Node3D
	f.rotation.y += delta * 2.0
	f.position.y = 1.9 + sin(Time.get_ticks_msec() * 0.004) * 0.15
	_dist_t -= delta
	if _dist_t > 0.0 or _chrono > 0.0 or _obj_text == "" or _player == null or not _hj():
		return
	_dist_t = 0.25
	var pv: Node3D = _player.get("vehicle")
	var pp: Vector3 = pv.global_position if pv else _player.global_position
	var d := Vector2(pp.x - _marker_pos.x, pp.z - _marker_pos.z).length()
	_hj().objectif("%s   (%d m)" % [tr(_obj_text), int(d)] if d > 4.0 else _obj_text)


func _night() -> void:
	## Fondu : on passe a 21 h (sauf s'il fait deja nuit), puis l'etape suivante.
	var jn := get_node_or_null("../JourNuit")
	var h: float = float(jn.get("hour")) if jn else 21.0
	if h >= 20.0 or h < 4.5:
		step += 1
		_enter_step.call_deferred()
		return
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 1.0)
	tw.tween_callback(func() -> void:
		if jn:
			jn.set("hour", 21.0)
		if _hud and _hud.has_method("show_place"):
			_hud.show_place("Plus tard, dans la nuit..."))
	tw.tween_interval(1.2)
	tw.tween_property(_fade, "color:a", 0.0, 1.2)
	tw.tween_callback(func() -> void:
		step += 1
		_enter_step())
