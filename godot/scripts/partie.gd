extends Node
## Etat de la partie (autoload "Partie") : argent en FCFA, inventaire, avancement de l'histoire et des missions,
## niveau de recherche de la police, options. Sauvegarde et chargement en JSON (user://sauvegarde.json),
## options dans user://options.cfg.

signal argent_change(total: int, delta: int)
signal inventaire_change
signal notification(texte: String)
signal recherche_change(niveau: int)

var save_path := "user://sauvegarde.json"   # les tests ecrivent ailleurs
const OPTIONS := "user://options.cfg"

@export var argent_depart := 3000             # FCFA en poche au debut (de quoi manger et payer un zem)
@export var amende_par_niveau := 5000         # FCFA par niveau de recherche a l'arrestation
@export var frais_hopital := 4000             # FCFA quand on se reveille a l'hopital

var argent := 0
var inventaire := {}          # article -> quantite
const INVENTAIRE_DEPART := {"Smartphone": 1, "Torche": 1}   # dans les poches au debut de chaque partie
var missions_faites: Array = []
var chapitre := "prologue"     # prologue, acte1, fin_acte1
var drapeaux := {}             # etapes de l'histoire, rencontres...
var recherche := 0             # niveau de recherche (0 a 6 etoiles, comme San Andreas), pas sauvegarde
var points_recherche := 0.0     # "chaleur" accumulee par les delits (police.gd crime) : elle fixe le nombre d etoiles
var recherche_clignote := false # la police a perdu la trace du joueur : les etoiles clignotent avant de disparaitre
const SEUILS_RECHERCHE := [1.0, 50.0, 120.0, 230.0, 400.0, 650.0]   # points pour 1 a 6 etoiles
var police_voit := false       # un agent voit le joueur (les etoiles clignotent)
var sante := 100.0             # 0 : le joueur s'evanouit et se reveille a l'hopital
signal sante_change(valeur: float)
var armure := 0.0              # blouson de moto renforce (Ararat) : absorbe une part des coups et des chutes
signal armure_change(valeur: float)
@export var armure_absorbe := 0.6              # part des degats prise par l'armure tant qu'il en reste
signal evanoui
var stats := {"courses": 0, "livraisons": 0, "amendes": 0, "distance_zem": 0.0}
var tenue := {}                # tenue du joueur (scripts/personnalisation.gd) : style, couleurs, coiffure, chaussures
var perso := {}                # progression du personnage (scripts/stats.gd) : endurance, muscles, poids, competences

var options := {"volume": 0.8, "musique": 0.6, "sensibilite": 1.0, "effets_camera": true, "qualite": 2, "plein_ecran": false,
	"violence_reduite": false, "sous_titres": true, "taille_sous_titres": 26, "vol_vehicules": 1.0, "vol_ambiance": 1.0,
	"vol_effets": 1.0, "taille_interface": 1.0, "aide_visee": true, "touches": {}, "langue": "auto", "daltonisme": false}
# actions reaffectables au clavier (menu Options > Touches)
## Commandes reaffectables (clavier et boutons de souris ; la manette garde ses boutons) : [action, libelle, touche par
## defaut pour les actions creees par le code]. Options > Touches du clavier.
const TOUCHES_REGLABLES := [["move_forward", "Avancer"], ["move_back", "Reculer"], ["move_left", "Gauche"],
	["move_right", "Droite"], ["jump", "Sauter / escalader"], ["sprint", "Courir"], ["walk", "Marcher lentement"],
	["crouch", "S'accroupir"], ["interact", "Monter / descendre d'un véhicule"], ["parler", "Parler / acheter"],
	["attaque", "Frapper / tirer"], ["garde", "Viser / se protéger"], ["arme_suivante", "Arme suivante"],
	["recharger", "Recharger"], ["map", "Carte"], ["map_pin", "Repère sur la carte"], ["camera_vue", "Changer de vue"],
	["inventaire", "Inventaire", KEY_I], ["telephone", "Téléphone", KEY_P], ["torche", "Torche", KEY_L],
	["photo", "Mode photo", KEY_F12], ["accelerate", "Accélérer"], ["brake", "Freiner / reculer"], ["handbrake", "Frein à main"],
	["horn", "Klaxon"], ["limiteur", "Limiteur de vitesse"], ["bande", "Appeler la bande"], ["heler", "Héler un zem", KEY_H], ["lacet_g", "Avion : palonnier gauche", KEY_Z], ["lacet_d", "Avion : palonnier droit", KEY_X]]
var _touches_defaut := {}      # action -> evenements clavier / souris d'origine (pour "Touches par defaut")
var journal: Node              # journal de partie automatique (scripts/journal.gd, user://logs/)
## Mise en place etalee (ecran de chargement) : pendant le chargement, les scripts lourds confient leurs etapes a
## chantier() au lieu de tout construire dans _ready ; l'ecran de chargement les execute quelques ms par image.
## Hors chargement (tests, scene lancee directement), chantier() execute l'etape tout de suite.
var chantier_actif := false
var chantiers: Array[Callable] = []
## Hors chargement, travail de fond (decor d'une tuile qui arrive, monde.gd) : tache() le fait quelques ms par image.
var budget_fond_ms := 3.0
var _fond: Array = []          # [etape, image de physique ou elle a ete confiee]


# mixage (phase 19) : un bus par categorie, regle dans les options ; reverberation des grands interieurs (Lieux)
const BUS_SONS := {"Vehicules": ["voiture", "zem_audio", "traffic", "avion", "air_traffic", "police", "taxi"],
	"Ambiance": ["ambience", "weather", "day_night", "balisage"], "Effets": []}


func _buses() -> void:
	for nom in ["Vehicules", "Ambiance", "Effets", "Voix"]:
		if AudioServer.get_bus_index(nom) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, nom)
			AudioServer.set_bus_send(i, "Master")
	if AudioServer.get_bus_index("Interieur") < 0:
		AudioServer.add_bus()
		var r := AudioServer.bus_count - 1
		AudioServer.set_bus_name(r, "Interieur")
		AudioServer.set_bus_send(r, "Master")
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.75
		rev.damping = 0.35
		rev.wet = 0.45
		rev.dry = 0.0
		rev.spread = 0.8
		AudioServer.add_bus_effect(r, rev)
	get_tree().node_added.connect(_ranger_son)


func _ranger_son(n: Node) -> void:
	## Chaque source sonore va dans le bus de sa categorie, selon le script qui l'a creee.
	if not (n is AudioStreamPlayer3D or n is AudioStreamPlayer):
		return
	var p := n.get_parent()
	var nom := ""
	while p and nom == "":
		var sc: Script = p.get_script()
		if sc:
			nom = sc.resource_path.get_file().get_basename()
		p = p.get_parent()
	var bus := "Effets"
	for b in BUS_SONS:
		if nom in BUS_SONS[b]:
			bus = b
	n.set("bus", bus)


func chantier(etape: Callable) -> void:
	if chantier_actif:
		chantiers.append(etape)
	else:
		etape.call()


func chantier_differe(etape: Callable) -> void:
	## Comme call_deferred hors chargement ; pendant le chargement, une etape de la mise en place etalee.
	if chantier_actif:
		chantiers.append(etape)
	else:
		etape.call_deferred()


func tache(etape: Callable) -> void:
	## Etape de travail de fond : pendant le chargement, une etape de la mise en place ; sinon executee plus tard,
	## budget_fond_ms par image (au moins une etape par image), dans l'ordre.
	if chantier_actif:
		chantiers.append(etape)
	else:
		_fond.append([etape, Engine.get_physics_frames()])


func taches_en_attente() -> int:
	return _fond.size()


## Mesure des saccades apres l'ecran de chargement (journal en console) : images de plus de saccade_ms, sur suivi_s
@export var saccade_ms := 34.0
var _suivi := -1.0
var _saccades: Array = []


func noter_lent(quoi: String, us: int) -> void:
	## Pendant le suivi des saccades : une operation de plus de 20 ms est journalisee avec son nom.
	if _suivi > 0.0 and us > 20000:
		_saccades.append("[%s %d ms]" % [quoi, us / 1000])


func suivre_saccades(duree: float) -> void:
	_suivi = duree
	_saccades.clear()
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _process(d: float) -> void:
	if _suivi > 0.0:
		_suivi -= d
		if d * 1000.0 > saccade_ms:
			var vp := get_viewport().get_viewport_rid()
			_saccades.append("%.1fs:%dms(f%d,cpu%.0f,gpu%.0f,cam%s)" % [Time.get_ticks_msec() / 1000.0, int(d * 1000.0), _fond.size(),
				RenderingServer.viewport_get_measured_render_time_cpu(vp), RenderingServer.viewport_get_measured_render_time_gpu(vp),
				get_viewport().get_camera_3d().name if get_viewport().get_camera_3d() else "-"])
		if _suivi <= 0.0:
			print("Apres chargement : %d saccades > %d ms : %s" % [_saccades.size(), int(saccade_ms), " ".join(PackedStringArray(_saccades.slice(0, 40)))])
	if _fond.is_empty():
		return
	var t := Time.get_ticks_usec()
	while not _fond.is_empty():
		# deux pas de physique au moins apres la mise en file : les collisions d'une tuile qui vient d'arriver sont
		# enregistrees avant les lancers de rayons du decor
		if Engine.get_physics_frames() < int(_fond[0][1]) + 2:
			break
		var c: Callable = _fond.pop_front()[0]
		if c.is_valid():
			var t1 := Time.get_ticks_usec()
			c.call()
			noter_lent("tache %s.%s" % [c.get_object().name if c.get_object() is Node else "?", c.get_method()], Time.get_ticks_usec() - t1)
		if Time.get_ticks_usec() - t > budget_fond_ms * 1000.0:
			break


func respirer() -> void:
	## A attendre (await) dans un long _ready : pendant le chargement, rend la main a l'ecran (une image) ; sinon rien.
	if chantier_actif:
		await get_tree().process_frame


func file_videe() -> void:
	## A attendre (await) : rend la main quand toutes les etapes deja confiees sont faites (tout de suite hors chargement).
	if not chantier_actif:
		return
	var fait := [false]
	chantiers.append(func() -> void: fait[0] = true)
	while not fait[0]:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buses()
	journal = preload("res://scripts/journal.gd").new()
	journal.name = "Journal"
	add_child(journal)
	nouvelle_partie()
	charger_options()
	preload("res://scripts/manette.gd").appliquer()      # disposition PlayStation par defaut de la manette


func nouvelle_partie() -> void:
	argent = argent_depart
	inventaire = INVENTAIRE_DEPART.duplicate()
	missions_faites = []
	chapitre = "prologue"
	drapeaux = {}
	recherche = 0
	sante = 100.0
	armure = 0.0
	armure_change.emit(armure)
	stats = {"courses": 0, "livraisons": 0, "amendes": 0, "distance_zem": 0.0}
	perso = {}
	tenue = {}
	argent_change.emit(argent, 0)
	inventaire_change.emit()


# ------------------------------------------------------------------ argent et inventaire
static func fcfa(n: int) -> String:
	## 12500 -> "12 500 F"
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out + " F"


func gagner(n: int, raison := "") -> void:
	argent += n
	argent_change.emit(argent, n)
	journal.argent(n, raison)
	if raison != "":
		notification.emit("+%s : %s" % [fcfa(n), tr(raison)])


func payer(n: int, raison := "") -> bool:
	## Faux (et rien n'est preleve) si l'on n'a pas assez.
	if n > argent:
		notification.emit("Pas assez d'argent (%s)" % fcfa(n))
		return false
	argent -= n
	argent_change.emit(argent, -n)
	journal.argent(-n, raison)
	if raison != "":
		notification.emit("-%s : %s" % [fcfa(n), tr(raison)])
	return true


func prelever(n: int, raison := "") -> void:
	## Prelevement force (amende, soins) : l'argent ne descend pas sous zero.
	var m := mini(n, argent)
	argent -= m
	argent_change.emit(argent, -m)
	journal.argent(-m, raison)
	if raison != "":
		notification.emit("-%s : %s" % [fcfa(m), tr(raison)])


func ajouter(article: String, n := 1) -> void:
	inventaire[article] = int(inventaire.get(article, 0)) + n
	inventaire_change.emit()


func retirer(article: String, n := 1) -> bool:
	if int(inventaire.get(article, 0)) < n:
		return false
	inventaire[article] = int(inventaire[article]) - n
	if inventaire[article] <= 0:
		inventaire.erase(article)
	inventaire_change.emit()
	return true


func a(article: String, n := 1) -> bool:
	return int(inventaire.get(article, 0)) >= n


func soigner(n: float) -> void:
	sante = minf(100.0, sante + n)
	sante_change.emit(sante)


func blesser(n: float) -> void:
	if sante <= 0.0:
		return
	if armure > 0.0:
		var pris := minf(armure, n * armure_absorbe)
		armure -= pris
		n -= pris
		armure_change.emit(armure)
	sante = maxf(0.0, sante - n)
	sante_change.emit(sante)
	if sante <= 0.0:
		evanoui.emit()


func equiper_armure(n: float) -> void:
	armure = minf(100.0, armure + n)
	armure_change.emit(armure)


func notifier(texte: String) -> void:
	notification.emit(texte)


func niveau_pour_points(p: float) -> int:
	var n := 0
	for s in SEUILS_RECHERCHE:
		if p >= float(s):
			n += 1
	return n


func ajouter_points(p: float) -> void:
	## Un delit ajoute de la chaleur ; les etoiles montent par paliers (plusieurs petits delits valent un gros).
	points_recherche += p
	recherche_clignote = false
	set_recherche(maxi(niveau_pour_points(points_recherche), recherche))


func set_recherche(n: int) -> void:
	n = clampi(n, 0, 6)
	if n == 0:
		points_recherche = 0.0
		recherche_clignote = false
	elif niveau_pour_points(points_recherche) != n:
		points_recherche = float(SEUILS_RECHERCHE[n - 1])
	if n != recherche:
		recherche = n
		recherche_change.emit(n)
		journal.recherche(n)


# ------------------------------------------------------------------ sauvegarde
const SAVE_VERSION := 3


static func version_jeu() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.1.0"))


func existe_sauvegarde() -> bool:
	return FileAccess.file_exists(save_path) or not emplacements_occupes().is_empty()


# ------------------------------------------------------------------ emplacements (phase 24) : 3 sauvegardes
const EMPLACEMENTS := 3


func chemin_emplacement(i: int) -> String:
	## Emplacement 1 = l'ancien fichier (les sauvegardes existantes restent lisibles) ; 2 et 3 a cote.
	var base := save_path.get_basename()          # "user://sauvegarde" (ou un fichier de test)
	if base.length() > 2 and base[-2] == "_" and base[-1].is_valid_int():
		base = base.left(-2)                       # emplacement en cours : on retrouve la base
	return base + ".json" if i == 1 else base + "_%d.json" % i


func emplacements_occupes() -> Array:
	var out: Array = []
	for i in range(1, EMPLACEMENTS + 1):
		if FileAccess.file_exists(chemin_emplacement(i)):
			out.append(i)
	return out


func resume_emplacement(i: int) -> String:
	## "Chapitre - argent - date" pour les menus, ou "Vide".
	var p := chemin_emplacement(i)
	if not FileAccess.file_exists(p):
		return tr("Vide")
	var raw = JSON.parse_string(FileAccess.get_file_as_string(p))
	if typeof(raw) != TYPE_DICTIONARY:
		return tr("Illisible")
	return "%s · %d missions · %s · %s" % [String(raw.get("chapitre", "prologue")).capitalize(), (raw.get("missions", []) as Array).size(),
		fcfa(int(raw.get("argent", 0))), String(raw.get("date", "")).replace("T", " ").left(16)]


func dernier_emplacement() -> int:
	var best := 1
	var bt := -1
	for i in emplacements_occupes():
		var t := FileAccess.get_modified_time(chemin_emplacement(i))
		if t > bt:
			bt = t
			best = i
	return best


func sauver_emplacement(scene: Node, i: int) -> bool:
	## L'emplacement choisi devient l'emplacement en cours (le lit et les proprietes y sauvegardent ensuite).
	save_path = chemin_emplacement(i)
	return sauver(scene)


func charger_emplacement(scene: Node, i: int) -> bool:
	save_path = chemin_emplacement(i)
	return charger(scene)


static func convertir_sauvegarde(d: Dictionary) -> Dictionary:
	## Convertit une ancienne sauvegarde vers le format actuel (SAVE_VERSION) pour qu'une sauvegarde de la demo v0.1
	## se charge sans perte en v0.2 et apres.
	var out := d.duplicate(true)
	var v := int(out.get("version", 0))
	if v < 1:
		out["chapitre"] = out.get("chapitre", "prologue")
		out["missions"] = out.get("missions", [])
		out["drapeaux"] = out.get("drapeaux", {})
		out["inventaire"] = out.get("inventaire", {})
		out["stats"] = out.get("stats", {})
		out["sante"] = float(out.get("sante", 100.0))
		v = 1
	if v < 2:
		if not out.has("version_jeu"):
			out["version_jeu"] = "0.1.0"
		var st: Dictionary = out.get("stats", {}) if typeof(out.get("stats")) == TYPE_DICTIONARY else {}
		for k in ["courses", "livraisons", "amendes"]:
			st[k] = int(st.get(k, 0))
		st["distance_zem"] = float(st.get("distance_zem", 0.0))
		out["stats"] = st
		var dr: Dictionary = out.get("drapeaux", {}) if typeof(out.get("drapeaux")) == TYPE_DICTIONARY else {}
		if not dr.has("mission") and out.get("missions") is Array:
			dr["mission"] = (out["missions"] as Array).size()
		out["drapeaux"] = dr
		v = 2
	if v < 3:
		# version 3 (inventaire du joueur) : torche et smartphone dans les poches
		var inv: Dictionary = out.get("inventaire", {}) if typeof(out.get("inventaire")) == TYPE_DICTIONARY else {}
		for k in INVENTAIRE_DEPART:
			inv[k] = maxi(int(inv.get(k, 0)), int(INVENTAIRE_DEPART[k]))
		out["inventaire"] = inv
		v = 3
	out["version"] = SAVE_VERSION
	return out


func sauver(scene: Node) -> bool:
	## Position du joueur, heure, meteo, argent, inventaire, histoire. Pas en vehicule ni recherche par la police.
	var player := scene.get_node_or_null("Player") if scene else null
	var d := {"version": SAVE_VERSION, "version_jeu": version_jeu(), "argent": argent, "inventaire": inventaire,
		"missions": missions_faites, "chapitre": chapitre, "drapeaux": drapeaux, "stats": stats, "perso": perso, "tenue": tenue, "sante": sante, "armure": armure,
		"date": Time.get_datetime_string_from_system()}
	if player:
		var p: Vector3 = player.global_position
		d["joueur"] = {"pos": [p.x, p.y, p.z], "genre": player.get("genre"), "cap": float(player.get("_facing"))}
	var jn := scene.get_node_or_null("JourNuit") if scene else null
	if jn:
		d["heure"] = float(jn.get("hour"))
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t"))
	notification.emit("Partie sauvegardée")
	return true


func charger(scene: Node) -> bool:
	if not existe_sauvegarde():
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	var raw = JSON.parse_string(f.get_as_text())
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var d := convertir_sauvegarde(raw)
	argent = int(d.get("argent", argent_depart))
	inventaire = {}
	for k in d.get("inventaire", {}):
		inventaire[k] = int(d["inventaire"][k])
	missions_faites = d.get("missions", [])
	chapitre = d.get("chapitre", "prologue")
	drapeaux = d.get("drapeaux", {})
	stats.merge(d.get("stats", {}), true)
	perso = (d.get("perso", {}) as Dictionary).duplicate() if typeof(d.get("perso")) == TYPE_DICTIONARY else {}
	tenue = (d.get("tenue", {}) as Dictionary).duplicate() if typeof(d.get("tenue")) == TYPE_DICTIONARY else {}
	sante = float(d.get("sante", 100.0))
	sante_change.emit(sante)
	armure = float(d.get("armure", 0.0))
	armure_change.emit(armure)
	recherche = 0
	argent_change.emit(argent, 0)
	inventaire_change.emit()
	recherche_change.emit(0)
	var player := scene.get_node_or_null("Player") if scene else null
	if player and d.has("joueur"):
		var j: Dictionary = d["joueur"]
		if player.get("vehicle"):
			player.exit_vehicle(true)
		if String(j.get("genre", "homme")) != String(player.get("genre")):
			player.set_genre(j["genre"])
		player.global_position = Vector3(j["pos"][0], j["pos"][1], j["pos"][2])
		player.set("_facing", float(j.get("cap", 0.0)))
		player.reset_physics_interpolation()
	var jn := scene.get_node_or_null("JourNuit") if scene else null
	if jn and d.has("heure"):
		jn.set("hour", float(d["heure"]))
	notification.emit("Partie chargée")
	return true


# ------------------------------------------------------------------ options
func charger_options() -> void:
	var c := ConfigFile.new()
	if c.load(OPTIONS) == OK:
		for k in options:
			options[k] = c.get_value("options", k, options[k])
	appliquer_options()


func sauver_options() -> void:
	var c := ConfigFile.new()
	for k in options:
		c.set_value("options", k, options[k])
	c.save(OPTIONS)
	appliquer_options()


func appliquer_touches() -> void:
	## Cree les actions du jeu qui n'existent pas encore (touche par defaut), puis pose les touches choisies par le
	## joueur (options["touches"] : action -> code de touche, ou "souris:<bouton>"). Les boutons de manette restent.
	for e in TOUCHES_REGLABLES:
		if not InputMap.has_action(e[0]) and e.size() > 2:
			InputMap.add_action(e[0])
			var k := InputEventKey.new()
			k.physical_keycode = e[2]
			InputMap.action_add_event(e[0], k)
	var t: Dictionary = options.get("touches", {})
	for a in t:
		if not InputMap.has_action(a):
			continue
		if not _touches_defaut.has(a):
			_touches_defaut[a] = InputMap.action_get_events(a).filter(func(ev: InputEvent) -> bool: return ev is InputEventKey or ev is InputEventMouseButton)
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey or ev is InputEventMouseButton:
				InputMap.action_erase_event(a, ev)
		InputMap.action_add_event(a, evenement_touche(t[a]))


func evenement_touche(code: Variant) -> InputEvent:
	## Code enregistre -> evenement : entier = touche physique du clavier, "souris:N" = bouton de souris N.
	if code is String and String(code).begins_with("souris:"):
		var m := InputEventMouseButton.new()
		m.button_index = int(String(code).trim_prefix("souris:")) as MouseButton
		return m
	var k := InputEventKey.new()
	k.physical_keycode = int(code) as Key
	return k


func code_touche(ev: InputEvent) -> Variant:
	## Evenement -> code enregistre (inverse de evenement_touche), null si ce n'est ni une touche ni un bouton de souris.
	if ev is InputEventMouseButton:
		return "souris:%d" % (ev as InputEventMouseButton).button_index
	if ev is InputEventKey:
		var k := ev as InputEventKey
		return int(k.physical_keycode if k.physical_keycode != 0 else k.keycode)
	return null


func nom_touche(action: String) -> String:
	## Nom lisible de la touche (ou du bouton de souris) d'une action, pour les menus et l'aide a l'ecran.
	if not InputMap.has_action(action):
		return "?"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.physical_keycode if k.physical_keycode != 0 else k.keycode
			# touche physique -> lettre de la disposition du clavier du joueur (AZERTY : Z Q S D)
			var lettre := DisplayServer.keyboard_get_label_from_physical(code) if k.physical_keycode != 0 and DisplayServer.get_name() != "headless" else code
			return OS.get_keycode_string(lettre if lettre != KEY_NONE else code)
		if ev is InputEventMouseButton:
			match (ev as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return tr("Clic gauche")
				MOUSE_BUTTON_RIGHT: return tr("Clic droit")
				MOUSE_BUTTON_MIDDLE: return tr("Clic milieu")
				MOUSE_BUTTON_WHEEL_UP: return tr("Molette haut")
				MOUSE_BUTTON_WHEEL_DOWN: return tr("Molette bas")
				var b: return tr("Souris %d") % b
	return "—"


func touches_par_defaut() -> void:
	## Remet les touches d'origine (projet ou creees par le code) et oublie les choix du joueur.
	for a in _touches_defaut:
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey or ev is InputEventMouseButton:
				InputMap.action_erase_event(a, ev)
		for ev in _touches_defaut[a]:
			InputMap.action_add_event(a, ev)
	_touches_defaut.clear()
	options["touches"] = {}
	sauver_options()


func appliquer_options() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(options["volume"]), 0.0001)))
	for e in [["Vehicules", "vol_vehicules"], ["Ambiance", "vol_ambiance"], ["Effets", "vol_effets"]]:
		var i := AudioServer.get_bus_index(e[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(float(options.get(e[1], 1.0)), 0.0001)))
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if options["plein_ecran"] else DisplayServer.WINDOW_MODE_WINDOWED)
	# langue : francais (textes du jeu) ou anglais (i18n/en.po) ; "auto" suit la langue du systeme
	var lg := String(options.get("langue", "auto"))
	if lg == "auto" or DisplayServer.get_name() == "headless":
		lg = "fr" if OS.get_locale_language() == "fr" or DisplayServer.get_name() == "headless" else "en"
	TranslationServer.set_locale(lg)
	# accessibilite : taille de toute l'interface
	get_tree().root.content_scale_factor = clampf(float(options.get("taille_interface", 1.0)), 0.8, 1.6)
	# touches reaffectees (clavier seulement ; la manette garde ses boutons)
	# noeuds qui ont fige un reglage a leur creation (couleurs du daltonisme...) : mise a jour immediate
	get_tree().call_group("options", "options_changees")
	appliquer_touches()
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player")
	if player:
		player.set("mouse_sensitivity", 0.0025 * float(options["sensibilite"]))
		player.set("camera_effects", bool(options["effets_camera"]))
	var armes := scene.get_node_or_null("Armes")
	if armes:
		armes.set("violence_reduite", bool(options.get("violence_reduite", false)))
		armes.set("aide_visee", bool(options.get("aide_visee", true)))
	Qualite.appliquer(scene, int(options["qualite"]))
