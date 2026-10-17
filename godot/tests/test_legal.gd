extends SceneTree
## Verification legale automatique (phase 13, docs/LEGAL.md) : aucun nom reel du tableau de correspondance, aucune
## marque ni "GTA" dans ce que voit le joueur (textes des scripts hors commentaires, donnees de la zone, credits,
## fichier de traduction). Les commentaires du code peuvent citer les lieux reels (documentation).

const INTERDITS := ["Gantin", "Erevan Hypermarket", "Banque Atlantique", "Société Générale", "Societe Generale",
	"Dream Beach", "Maquis de la Playa", "Code Bar", "Wellness Fitness", "Nico's Hair", "Nico s Hair", "FADOUL", "Fadoul",
	"JNP", "Route des Pêches", "Route des Peches", "Pape Jean-Paul", "Jean-Paul II", "Haie Vive", "Cadjehoun", "GTA",
	"Grand Theft", "Rockstar", "MTN", "Moov Africa", "Celtiis", "Coca-Cola", "TotalEnergies", "Air France", "ASKY",
	"Ethiopian", "Brussels Airlines"]

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "ECHEC ") + what)
	if not ok:
		fails += 1


func _visible_lines(path: String, code: bool) -> PackedStringArray:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var l := line.strip_edges()
		if code:
			if l.begins_with("#") or l.begins_with("@export_group"):   # groupes de reglages : editeur seulement
				continue
			var i := line.find(" # ")
			line = line.substr(0, i) if i >= 0 else line
			# seulement le texte entre guillemets
			var parts := line.split("\"")
			var s := ""
			for k in range(1, parts.size(), 2):
				s += parts[k] + "\" "
			line = s
		out.append(line.replace("Sweet Dream Beach", "SDB"))   # nom fictif (docs/LEGAL.md)
	return out


func _initialize() -> void:
	var files: Array = []
	var d := DirAccess.open("res://scripts")
	for f in d.get_files():
		if f.ends_with(".gd"):
			files.append(["res://scripts/" + f, true])
	files.append(["res://assets/data/zone_aeroport.json", false])
	files.append(["res://assets/data/credits.txt", false])
	files.append(["res://i18n/gtb.pot", false])
	var found := {}
	for e in files:
		var n := 0
		for line in _visible_lines(e[0], e[1]):
			n += 1
			for w in INTERDITS:
				if line.contains(w) and not found.has(w):
					found[w] = "%s:%d" % [e[0], n]
	for w in found:
		_check(false, "nom reel ou marque \"%s\" visible : %s" % [w, found[w]])
	_check(found.is_empty(), "aucun nom reel ni marque dans %d fichiers" % files.size())
	var cr := FileAccess.get_file_as_string("res://assets/data/credits.txt")
	_check(cr.contains("OpenStreetMap") and cr.contains("ODbL"), "mention OSM obligatoire dans les credits")
	print("RESULTAT test_legal : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
