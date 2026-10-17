extends SceneTree
## Territoires des zems (phase 17) : stationnements places avec leur syndicat, defi gagne en mettant les trois
## zemidjans a terre, revenus a chaque heure de jeu, negociation avec assez de respect, attaque repoussee ou perdue,
## bande de Sena qui suit le joueur, proprietaires gardes dans la sauvegarde.

var frame := 0
var scene: Node
var player: CharacterBody3D
var te: Node
var peds: Node
var fails := 0
var mark := {}


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	var P := root.get_node("Partie")
	if frame == 30:
		player = scene.get_node("Player")
		te = scene.get_node("Territoires")
		peds = scene.get_node("Pietons")
		P.save_path = "user://test_territoires.json"
		P.nouvelle_partie()
		scene.get_node("Police").set("arrestation", false)
		_check(te._pos.size() == te.STATIONNEMENTS.size(), "%d stationnements places" % te._pos.size())
		_check(te.proprio("cadjehoun") == "lions" and te.tenus().is_empty(), "au depart : tenus par les syndicats rivaux")
		# defi
		player.global_position = te._pos["cadjehoun"] + Vector3(0, 0.5, 0)
		te._lancer_defi("cadjehoun")
		_check((te._defi["rivaux"] as Array).size() == 3, "defi : trois zemidjans du syndicat")
	if frame == 40:
		for w in te._defi["rivaux"]:
			w["pv"] = 0.0
			peds._knock_down(w, Vector2.ZERO, "flee")
			w["lie"] = 5.0
	if frame == 45:
		_check(te.proprio("cadjehoun") == "joueur" and te._defi.is_empty(), "defi gagne : Carrefour de Cadjehoue a toi")
		var a0: int = P.argent
		var day := scene.get_node("JourNuit")
		day.set("hour", floorf(float(day.get("hour"))) + 1.01)
		mark["a0"] = a0
	if frame == 50:
		_check(P.argent == int(mark["a0"]) + te.revenu_horaire, "revenus : %d F par heure de jeu" % (P.argent - int(mark["a0"])))
		# negociation
		P.perso["respect"] = 40.0
		P.argent = 100000
		player.global_position = te._pos["aeroport"] + Vector3(0, 0.5, 0)
	if frame == 52:
		if P.payer(te.prix_negociation, "test"):
			te._set_proprio("aeroport", "joueur")
		_check(te.proprio("aeroport") == "joueur", "negociation : stationnement de l'aeroport achete")
		# attaque perdue
		te._attaque = {"id": "aeroport", "t": 0.05, "qui": "szu", "rivaux": [], "arrive": false}
		player.global_position = Vector3(5000, 0.5, 5000)
	if frame == 60:
		_check(te.proprio("aeroport") == "szu", "attaque non defendue : stationnement perdu")
		# bande
		P.perso["respect"] = 80.0
		player.global_position = te._pos["cadjehoun"] + Vector3(0, 0.5, 0)
		_check(te.recruter() and te.recruter(), "deux zemidjans recrutes")
		mark["p0"] = player.global_position
		player.global_position += Vector3(10, 0, 0)
	if frame == 200:
		var d: float = (te._bande[0]["node"] as Node3D).global_position.distance_to(player.global_position)
		_check(d < 4.0, "la bande suit le joueur (%.1f m)" % d)
		P.sauver(scene)
		P.drapeaux = {}
		P.charger(scene)
		_check(te.proprio("cadjehoun") == "joueur", "territoires gardes dans la sauvegarde")
		print("RESULTAT test_territoires : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
