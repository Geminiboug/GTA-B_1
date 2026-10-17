extends Node
## Succes (phase 24) : gardes pour tout le jeu (user://succes.cfg, toutes parties confondues), annonce a l'obtention,
## liste dans le menu pause. Verifies deux fois par seconde a partir de l'etat de la partie.

var FICHIER := "user://succes.cfg"      # les tests (scene lancee par un script) ecrivent ailleurs
const LISTE := [
	["prologue", "Retour au quartier", "Finir le prologue"],
	["premiere_course", "Zemidjan", "Faire une première course de zem"],
	["dix_courses", "Le métier rentre", "Faire 10 courses de zem"],
	["course_nuit", "Roi de la nuit", "Gagner une course de zems de nuit"],
	["fresques", "Œil du quartier", "Photographier toutes les fresques"],
	["stationnements", "Patron des carrefours", "Tenir 3 stationnements de zems"],
	["proprio", "Chez soi", "Acheter un logement"],
	["muscles", "Costaud", "Atteindre 60 en muscles"],
	["endurance", "Infatigable", "Atteindre 60 en endurance"],
	["cinq_etoiles", "Ennemi public", "Être recherché au niveau 5"],
	["seme", "Évaporé", "Semer la police à 3 étoiles ou plus"],
	["acte1", "Le Dernier Vol, première partie", "Finir l'acte 1"],
	["riche", "Grand patron", "Avoir 1 000 000 F en poche"],
]

var obtenus := {}
var _t := 0.0
var _recherche_max := 0


func _ready() -> void:
	if get_tree().current_scene == null:
		FICHIER = "user://test_succes.cfg"
	var c := ConfigFile.new()
	if c.load(FICHIER) == OK:
		for k in c.get_section_keys("succes") if c.has_section("succes") else []:
			obtenus[k] = c.get_value("succes", k)
	Partie.recherche_change.connect(func(n: int) -> void:
		if n >= 5:
			debloquer("cinq_etoiles")
		if n > 0:
			_recherche_max = maxi(_recherche_max, n))
	Partie.notification.connect(func(t: String) -> void:
		if t.begins_with("Tu as semé la police") and _recherche_max >= 3:
			debloquer("seme")
		if t.begins_with("Tu as semé la police") or t.begins_with("Partie chargée"):
			_recherche_max = 0)


func debloquer(id: String) -> void:
	if obtenus.has(id):
		return
	obtenus[id] = Time.get_datetime_string_from_system()
	var c := ConfigFile.new()
	c.load(FICHIER)
	c.set_value("succes", id, obtenus[id])
	c.save(FICHIER)
	for e in LISTE:
		if e[0] == id:
			var hj := get_tree().get_first_node_in_group("hud_jeu")
			if hj and hj.has_method("annonce"):
				hj.annonce(tr("SUCCÈS"), tr(e[1]), 3.0)
			Partie.notifier(tr("Succès : %s") % tr(e[1]))


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	var st := Partie.stats
	if Partie.chapitre != "prologue" or Partie.missions_faites.size() >= 1:
		debloquer("prologue")
	if int(st.get("courses", 0)) >= 1:
		debloquer("premiere_course")
	if int(st.get("courses", 0)) >= 10:
		debloquer("dix_courses")
	if int(Partie.drapeaux.get("courses_gagnees", 0)) >= 1:
		debloquer("course_nuit")
	if (Partie.drapeaux.get("fresques", []) as Array).size() >= 15:
		debloquer("fresques")
	var te := get_node_or_null("../Territoires")
	if te and (te.tenus() as Array).size() >= 3:
		debloquer("stationnements")
	if not (Partie.drapeaux.get("proprietes", []) as Array).is_empty():
		debloquer("proprio")
	if float(Partie.perso.get("muscles", 0.0)) >= 60.0:
		debloquer("muscles")
	if float(Partie.perso.get("endurance", 0.0)) >= 60.0:
		debloquer("endurance")
	if Partie.chapitre == "fin_acte1":
		debloquer("acte1")
	if Partie.argent >= 1000000:
		debloquer("riche")
