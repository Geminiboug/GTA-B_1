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
var recherche := 0             # niveau de recherche (0 a 5), pas sauvegarde
var police_voit := false       # un agent voit le joueur (les etoiles clignotent)
var sante := 100.0             # 0 : le joueur s'evanouit et se reveille a l'hopital
signal sante_change(valeur: float)
signal evanoui
var stats := {"courses": 0, "livraisons": 0, "amendes": 0, "distance_zem": 0.0}

var options := {"volume": 0.8, "musique": 0.6, "sensibilite": 1.0, "effets_camera": true, "qualite": 2, "plein_ecran": false}
var journal: Node              # journal de partie automatique (scripts/journal.gd, user://logs/)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	journal = preload("res://scripts/journal.gd").new()
	journal.name = "Journal"
	add_child(journal)
	nouvelle_partie()
	charger_options()


func nouvelle_partie() -> void:
	argent = argent_depart
	inventaire = INVENTAIRE_DEPART.duplicate()
	missions_faites = []
	chapitre = "prologue"
	drapeaux = {}
	recherche = 0
	sante = 100.0
	stats = {"courses": 0, "livraisons": 0, "amendes": 0, "distance_zem": 0.0}
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
	sante = maxf(0.0, sante - n)
	sante_change.emit(sante)
	if sante <= 0.0:
		evanoui.emit()


func notifier(texte: String) -> void:
	notification.emit(texte)


func set_recherche(n: int) -> void:
	n = clampi(n, 0, 5)
	if n != recherche:
		recherche = n
		recherche_change.emit(n)
		journal.recherche(n)


# ------------------------------------------------------------------ sauvegarde
const SAVE_VERSION := 3


static func version_jeu() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.1.0"))


func existe_sauvegarde() -> bool:
	return FileAccess.file_exists(save_path)


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
		"missions": missions_faites, "chapitre": chapitre, "drapeaux": drapeaux, "stats": stats, "sante": sante,
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
	sante = float(d.get("sante", 100.0))
	sante_change.emit(sante)
	recherche = 0
	argent_change.emit(argent, 0)
	inventaire_change.emit()
	recherche_change.emit(0)
	var player := scene.get_node_or_null("Player") if scene else null
	if player and d.has("joueur"):
		var j: Dictionary = d["joueur"]
		if player.get("vehicle"):
			player.exit_vehicle()
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


func appliquer_options() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(options["volume"]), 0.0001)))
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if options["plein_ecran"] else DisplayServer.WINDOW_MODE_WINDOWED)
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := scene.get_node_or_null("Player")
	if player:
		player.set("mouse_sensitivity", 0.0025 * float(options["sensibilite"]))
		player.set("camera_effects", bool(options["effets_camera"]))
	Qualite.appliquer(scene, int(options["qualite"]))
