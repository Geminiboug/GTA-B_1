extends SceneTree
## Jeu (phases 7 et 8) : argent et achats, sauvegarde / chargement, premiere mission de l'histoire (parler a la
## tante, acheter le pain, le rapporter), police (delit -> etoile, patrouille qui arrive, arrestation et amende),
## malaise (reveil a la maison, frais de soins).
## Lancement : godot --headless --path godot --script res://tests/test_jeu.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var partie: Node
var histoire: Node
var police: Node
var t0 := 0
var money0 := 0
var police_spawned := false
var arrive_d := INF
const FIN := 10800           # images (60 par s) : delai d'appel (1 min) + trajet depuis le commissariat + arrestation


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _tap(action: String) -> void:
	Input.action_press(action)
	await process_frame
	await physics_frame
	Input.action_release(action)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		partie = root.get_node("Partie")
		player = scene.get_node("Player")
		histoire = scene.get_node("Histoire")
		police = scene.get_node("Police")
		partie.save_path = "user://test_sauvegarde.json"
		partie.nouvelle_partie()
	if frame == 60:
		# argent et achat
		money0 = partie.argent
		var com := scene.get_node("Commerce")
		_check(com.spots.size() > 10, "commerces trouves : %d" % com.spots.size())
		var ok: bool = com.buy("caisse", 1)
		_check(ok and partie.argent == money0 - 1500 and partie.a("Huile (1 litre)"), "achat : %s en poche, huile dans l'inventaire" % partie.fcfa(partie.argent))
		partie.argent = 100
		_check(not com.buy("maquis", 0) and partie.argent == 100, "pas assez d'argent : achat refuse")
		partie.argent = 7000
		# sauvegarde / chargement
		var p0: Vector3 = player.global_position
		_check(partie.sauver(scene), "sauvegarde ecrite")
		partie.argent = 1
		player.global_position = p0 + Vector3(30, 0, 0)
		_check(partie.charger(scene) and partie.argent == 7000 and player.global_position.distance_to(p0) < 0.5,
			"chargement : argent %s, position retrouvee" % partie.fcfa(partie.argent))
		# histoire : premiere mission
		histoire.commencer()
	if frame == 70:
		var tante: Vector3 = histoire.points["tante"]
		player.global_position = tante + Vector3(1.2, 0.2, 0)
		player.reset_physics_interpolation()
	if frame == 90:
		_check(histoire.step == 0, "mission « Bonne arrivée » commencee au marqueur")
		_tap("parler")
	if frame == 260:
		_check(histoire.step == 1, "etape 2 : acheter le pain (etape %d)" % histoire.step)
		scene.get_node("Commerce").buy("etal", 3)
	if frame == 650:
		_check(partie.a("Pain"), "pain garde pour la tante (pas mange)")
		_check(histoire.step >= 2, "etape 3 : rapporter le pain (etape %d)" % histoire.step)
		player.global_position = histoire.points["tante"] + Vector3(1.0, 0.2, 0.4)
		player.reset_physics_interpolation()
	if frame == 670:
		_tap("parler")
	if frame == 900:
		_check(not partie.a("Pain") and histoire.idx == 1, "mission reussie, pain donne, mission suivante : %d" % histoire.idx)
		# police
		histoire.active = false
		police.crime("vol", player.global_position)
		_check(partie.recherche == 1, "vol de vehicule : 1 etoile")
		_check(absf(police.appel_t - police.delai_appel) < 0.1, "sans policier temoin : police appelee, depart dans %.0f s" % police.appel_t)
		t0 = frame
	if t0 > 0 and frame == t0 + int(police.delai_appel * 60.0) - 120:
		_check(police.units.is_empty(), "aucune patrouille avant la fin du delai d'appel")
	if t0 > 0 and frame > t0 and frame < t0 + FIN and partie.recherche > 0:
		if police.units.size() > 0:
			var car: Node3D = police.units[0]["car"]
			if not police_spawned:
				_check(car.global_position.distance_to(player.global_position) > 120.0, "patrouille partie de loin (%.0f m), pas sur place" % car.global_position.distance_to(player.global_position))
			police_spawned = true
			arrive_d = minf(arrive_d, car.global_position.distance_to(player.global_position))
	if t0 > 0 and frame == t0 + FIN:
		_check(police_spawned, "patrouille envoyee")
		_check(arrive_d < 25.0, "la patrouille arrive pres du joueur (%.0f m)" % arrive_d)
		_check(partie.recherche == 0 and int(partie.stats["amendes"]) >= 1, "arrete et mis a l'amende (%s restant)" % partie.fcfa(partie.argent))
		partie.blesser(200.0)
	if t0 > 0 and frame == t0 + FIN + 300:
		var home: Vector3 = scene.get_node("Lieux").home_position()
		_check(partie.sante == 100.0 and player.global_position.distance_to(home) < 5.0, "malaise : reveil a la maison, soigne")
		print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
		return true
	return frame > 15000
