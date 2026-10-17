extends Node
## Journal de partie automatique (Phase 11), pour equilibrer sur des chiffres. Cree par l'autoload Partie
## (Partie.journal). Une partie (Nouvelle partie, ou Continuer au lancement) = deux fichiers dans user://logs/ :
## - partie_<date>.jsonl : un evenement par ligne, ecrit et vide sur disque au fil de l'eau (rien de perdu si le jeu
##   plante). t = secondes de jeu hors pause. Evenements : debut, chargement, mission_debut, etape, mission_reussie,
##   mission_echouee, argent, delit, recherche, police_semee, arrestations, contraventions, morts (malaise),
##   courses_zem, perdu, pos (position toutes les 10 s), fin ;
## - resume_<date>.json : bilan (temps par mission et par etape, tentatives et raisons des echecs, morts,
##   arrestations, argent gagne et depense par raison, endroits ou le joueur se perd, zones ou il passe le plus de
##   temps), reecrit toutes les 30 s et en quittant.
## "Perdu" : un objectif est affiche et le joueur ne s'en rapproche pas de 15 m en 60 s de jeu.
## Inactif sans fenetre (tests), sauf si un test le met a actif = true (et change dossier).

@export var actif := true
@export var periode_position := 10.0     # s de jeu entre deux positions notees
@export var periode_resume := 30.0       # s entre deux ecritures du bilan
@export var delai_perdu := 60.0          # s sans se rapprocher de l'objectif
@export var progres_min := 15.0          # m gagnes vers l'objectif pour remettre le compteur a zero
@export var taille_case := 50.0          # m, cases du temps passe par zone
var dossier := "user://logs"

var temps := 0.0                         # secondes de jeu (hors pause)
var resume := {}
var fichier_evenements := ""
var fichier_resume := ""
var _f: FileAccess
var _t_reel0 := 0
var _mission := ""
var _mission_t0 := 0.0
var _etape_cle := ""
var _etape_t0 := 0.0
var _pos_t := 0.0
var _resume_t := 0.0
var _obj := Vector3.INF
var _obj_best := INF
var _obj_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		actif = false


func _exit_tree() -> void:
	_fermer()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_fermer()


# ------------------------------------------------------------------ debut et fin d'une partie
func debut(mode: String) -> void:
	## mode : "nouvelle_partie" (toujours un nouveau fichier) ou "chargement" (nouveau fichier seulement si aucune
	## partie n'est en cours depuis le lancement, sinon simple evenement).
	if not actif:
		return
	if _f and mode == "chargement":
		if _mission != "":
			mission_fin(false, "chargement d'une sauvegarde")
		evt("chargement", {"chapitre": Partie.chapitre, "argent": Partie.argent})
		return
	_fermer()
	DirAccess.make_dir_recursive_absolute(dossier)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	fichier_evenements = dossier.path_join("partie_%s.jsonl" % stamp)
	fichier_resume = dossier.path_join("resume_%s.json" % stamp)
	_f = FileAccess.open(fichier_evenements, FileAccess.WRITE)
	if _f == null:
		push_warning("Journal : impossible d'ecrire %s" % fichier_evenements)
		return
	temps = 0.0
	_t_reel0 = Time.get_ticks_msec()
	_mission = ""
	_etape_cle = ""
	_pos_t = 0.0
	_resume_t = 0.0
	_obj = Vector3.INF
	resume = {
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"debut": Time.get_datetime_string_from_system(), "mode": mode,
		"qualite": int(Partie.options.get("qualite", 2)),
		"temps_jeu_s": 0.0, "temps_reel_s": 0.0,
		"missions": {}, "morts": 0, "arrestations": 0, "amendes_fcfa": 0, "contraventions": 0,
		"delits": {}, "recherche_max": 0, "police_semee": 0, "courses_zem": 0,
		"argent": {"depart": Partie.argent, "actuel": Partie.argent, "gagne": 0, "depense": 0, "par_raison": {}},
		"perdu": [], "zones": {},
	}
	evt("debut", {"mode": mode, "chapitre": Partie.chapitre, "mission": int(Partie.drapeaux.get("mission", 0)),
		"argent": Partie.argent})


func _fermer() -> void:
	if _f == null:
		return
	_fin_etape()
	evt("fin", {})
	_ecrire_resume()
	_f.close()
	_f = null


# ------------------------------------------------------------------ evenements
func evt(e: String, data: Dictionary) -> void:
	if _f == null:
		return
	var d := {"t": snappedf(temps, 0.1), "e": e}
	d.merge(data)
	_f.store_line(JSON.stringify(d))
	_f.flush()


func mission_debut(titre: String) -> void:
	if _f == null:
		return
	if _mission != "":
		mission_fin(false, "nouvelle mission")
	_mission = titre
	_mission_t0 = temps
	var m := _m(titre)
	m["tentatives"] = int(m["tentatives"]) + 1
	evt("mission_debut", {"mission": titre, "tentative": m["tentatives"]})


func etape(n: int, type: String, objectif: String) -> void:
	if _f == null or _mission == "":
		return
	_fin_etape()
	_etape_cle = "%d. %s" % [n + 1, objectif if objectif != "" else type]
	_etape_t0 = temps
	evt("etape", {"mission": _mission, "etape": n + 1, "type": type, "objectif": objectif})


func mission_fin(ok: bool, raison := "") -> void:
	if _f == null or _mission == "":
		return
	_fin_etape()
	var m := _m(_mission)
	var duree := temps - _mission_t0
	m["temps_total_s"] = snappedf(float(m["temps_total_s"]) + duree, 0.1)
	if ok:
		m["reussie"] = true
		m["temps_reussite_s"] = snappedf(duree, 0.1)
		evt("mission_reussie", {"mission": _mission, "duree_s": snappedf(duree, 0.1)})
	else:
		(m["echecs"] as Array).append(raison)
		evt("mission_echouee", {"mission": _mission, "raison": raison, "duree_s": snappedf(duree, 0.1)})
	_mission = ""


func argent(delta: int, raison: String) -> void:
	if _f == null or delta == 0:
		return
	var a: Dictionary = resume["argent"]
	if delta > 0:
		a["gagne"] = int(a["gagne"]) + delta
	else:
		a["depense"] = int(a["depense"]) - delta
	var r := raison if raison != "" else "?"
	a["par_raison"][r] = int(a["par_raison"].get(r, 0)) + delta
	a["actuel"] = Partie.argent
	evt("argent", {"delta": delta, "raison": r, "total": Partie.argent})


func delit(kind: String, temoin: bool) -> void:
	if _f == null:
		return
	resume["delits"][kind] = int(resume["delits"].get(kind, 0)) + 1
	evt("delit", {"type": kind, "temoin": temoin, "pos": _xz(_pos())})


func recherche(n: int) -> void:
	if _f == null:
		return
	resume["recherche_max"] = maxi(int(resume["recherche_max"]), n)
	evt("recherche", {"niveau": n})


func compter(cle: String, n := 1, data := {}) -> void:
	## Compteur du bilan (morts, arrestations, contraventions, police_semee, courses_zem) + evenement.
	if _f == null:
		return
	resume[cle] = int(resume.get(cle, 0)) + n
	var d := {"pos": _xz(_pos())}
	d.merge(data)
	evt(cle, d)


func amende(n: int) -> void:
	if _f:
		resume["amendes_fcfa"] = int(resume["amendes_fcfa"]) + n


# ------------------------------------------------------------------ boucle
func _process(delta: float) -> void:
	if _f == null or get_tree().paused:
		return
	temps += delta
	var p := _pos()
	_pos_t += delta
	if _pos_t >= periode_position and p != Vector3.INF:
		_pos_t = 0.0
		evt("pos", {"pos": _xz(p), "vehicule": _vehicule()})
		var cle := "%d,%d" % [int(floor(p.x / taille_case) * taille_case + taille_case * 0.5),
			int(floor(p.z / taille_case) * taille_case + taille_case * 0.5)]
		resume["zones"][cle] = float(resume["zones"].get(cle, 0.0)) + periode_position
	_perdu(delta, p)
	_resume_t += delta
	if _resume_t >= periode_resume:
		_resume_t = 0.0
		_ecrire_resume()


func _perdu(delta: float, p: Vector3) -> void:
	var h := get_tree().get_first_node_in_group("histoire")
	var obj: Vector3 = h.get("_marker_pos") if h else Vector3.INF
	if obj != _obj:
		_obj = obj
		_obj_best = INF
		_obj_t = 0.0
	if obj == Vector3.INF or p == Vector3.INF:
		return
	var d := Vector2(p.x - obj.x, p.z - obj.z).length()
	if d < _obj_best - progres_min or _obj_best == INF:
		_obj_best = d
		_obj_t = 0.0
		return
	_obj_t += delta
	if _obj_t < delai_perdu:
		return
	_obj_t = 0.0
	_obj_best = d
	var info := {"mission": _mission, "objectif": str(h.get("_obj_text")), "pos": _xz(p), "rue": _rue(p),
		"distance_m": int(d), "vehicule": _vehicule()}
	(resume["perdu"] as Array).append(info.merged({"t": snappedf(temps, 0.1)}))
	evt("perdu", info)


# ------------------------------------------------------------------ outils
func _m(titre: String) -> Dictionary:
	var ms: Dictionary = resume["missions"]
	if not ms.has(titre):
		ms[titre] = {"tentatives": 0, "reussie": false, "temps_reussite_s": -1.0, "temps_total_s": 0.0,
			"echecs": [], "etapes_s": {}}
	return ms[titre]


func _fin_etape() -> void:
	if _etape_cle == "" or _mission == "":
		_etape_cle = ""
		return
	var es: Dictionary = _m(_mission)["etapes_s"]
	es[_etape_cle] = snappedf(float(es.get(_etape_cle, 0.0)) + temps - _etape_t0, 0.1)
	_etape_cle = ""


func _joueur() -> Node3D:
	var h := get_tree().get_first_node_in_group("histoire")
	return h.get("_player") if h else null


func _pos() -> Vector3:
	var pl := _joueur()
	if pl == null:
		return Vector3.INF
	var pv: Node3D = pl.get("vehicle")
	return pv.global_position if pv else pl.global_position


func _vehicule() -> String:
	var pl := _joueur()
	var pv: Node3D = pl.get("vehicle") if pl else null
	return str(pv.get("kind")) if pv else ""


func _rue(p: Vector3) -> String:
	var pl := _joueur()
	var hud := pl.get_node_or_null("../HUD") if pl else null
	return hud.call("_street_name", Vector2(p.x, p.z)) if hud and hud.has_method("_street_name") else ""


static func _xz(p: Vector3) -> Array:
	return [] if p == Vector3.INF else [roundi(p.x), roundi(p.z)]


func _ecrire_resume() -> void:
	if resume.is_empty() or fichier_resume == "":
		return
	resume["temps_jeu_s"] = snappedf(temps, 0.1)
	resume["temps_reel_s"] = snappedf((Time.get_ticks_msec() - _t_reel0) / 1000.0, 0.1)
	resume["argent"]["actuel"] = Partie.argent
	resume["chapitre"] = Partie.chapitre
	resume["missions_faites"] = Partie.missions_faites.size()
	# zones les plus frequentees d'abord (20 premieres)
	var zs: Array = []
	for k in resume["zones"]:
		zs.append([k, resume["zones"][k]])
	zs.sort_custom(func(a, b) -> bool: return a[1] > b[1])
	var out := resume.duplicate(true)
	out["zones"] = zs.slice(0, 20).map(func(z) -> Dictionary: return {"case": z[0], "s": z[1]})
	var f := FileAccess.open(fichier_resume, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t", false))
