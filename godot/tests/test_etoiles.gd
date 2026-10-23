extends SceneTree
## Etoiles de police a la San Andreas : 6 niveaux par points de delit, les petits delits s'additionnent, clignotement quand la
## trace est perdue, remise a zero propre.

var frame := 0
var scene: Node
var fails := 0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 120:
		return false
	var partie := root.get_node("Partie")
	var pol := scene.get_node("Police")
	pol.set("arrestation", false)
	partie.set_recherche(0)
	partie.ajouter_points(20.0)
	_check(partie.recherche == 1, "un vol (20 points) : 1 etoile")
	partie.ajouter_points(30.0)
	_check(partie.recherche == 2, "50 points : 2 etoiles")
	partie.ajouter_points(80.0)
	_check(partie.recherche == 3, "130 points : 3 etoiles")
	partie.ajouter_points(1000.0)
	_check(partie.recherche == 6, "au-dela de 650 points : 6 etoiles au maximum (%d)" % partie.recherche)
	partie.set_recherche(0)
	_check(partie.points_recherche == 0.0 and not partie.recherche_clignote, "retour a zero : points et clignotement effaces")
	pol.crime("braquage", Vector3.ZERO)
	_check(partie.recherche == 3, "un braquage : 3 etoiles (%d)" % partie.recherche)
	pol.crime("tir_police", Vector3.ZERO)
	_check(partie.recherche >= 4, "puis un tir sur la police (280 points) : 4 etoiles ou plus (%d)" % partie.recherche)
	partie.set_recherche(2)
	pol.set("appel_t", 0.0)
	pol.units.clear()
	pol._arrivee = true
	pol.set("_hors_vue", 999.0)
	pol._physics_process(0.016)
	_check(partie.recherche_clignote, "police sans visuel : les etoiles clignotent")
	_check(partie.recherche == 2, "la recherche reste active pendant le clignotement")
	pol.set("_clignote_t", 0.01)
	pol._physics_process(0.5)
	_check(partie.recherche == 0, "fin du clignotement : plus de recherche")
	print("RESULTAT test_etoiles : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
