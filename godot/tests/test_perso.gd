extends SceneTree
## Personnalisation et proprietes (phase 16) : boubou du tailleur, maillot, coiffure, tenue gardee dans la sauvegarde ;
## garage : reparation et peinture qui seme la police ; propriete achetee ou l'on dort et sauvegarde, vehicule gare
## garde ; cache au marche.

var frame := 0
var scene: Node
var player: CharacterBody3D
var pe: Node
var com: Node
var fails := 0


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _visible(prefix: String) -> bool:
	for mi in player.get_node("Body/Model").find_children(prefix + "*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).visible:
			return true
	return false


func _physics_process(_d: float) -> bool:
	frame += 1
	var P := root.get_node("Partie")
	if frame == 30:
		player = scene.get_node("Player")
		pe = scene.get_node("Personnalisation")
		com = scene.get_node("Commerce")
		P.save_path = "user://test_perso.json"
		P.nouvelle_partie()
		P.argent = 2000000
		scene.get_node("Police").set("arrestation", false)
		for k in ["tailleur", "garage", "agence", "coiffeur", "maillots", "friperie"]:
			var ok := false
			for s in com.spots:
				ok = ok or s["kind"] == k
			_check(ok, "%s place dans le quartier" % k)
		_check(com.buy("tailleur", 1) and P.tenue.get("style") == "boubou" and _visible("chr_boubou"), "boubou en wax du tailleur porte")
		_check(com.buy("coiffeur", 1) and _visible("chr_afro"), "coupe afro chez le coiffeur")
		_check(com.buy("maillots", 2) and P.tenue.get("style") == "maillot", "maillot de l'Atlantique FC")
		# tenue changee sans policier en vue : une etoile de moins
		P.set_recherche(2)
		P.police_voit = false
		com.buy("friperie", 0)
		_check(P.recherche == 1, "nouvelle tenue hors de vue : une etoile de moins (%d)" % P.recherche)
		P.set_recherche(0)
		# garage
		var car := Vehicules.create("veh_berline", Color(0.9, 0.9, 0.9))
		scene.add_child(car)
		car.global_position = pe._points["garage"] + Vector3(2, 0.3, 0)
		car.damage(60.0)
		var a0: int = P.argent
		_check(com.buy("garage", 0) and is_equal_approx(float(car.get("health")), 100.0) and P.argent == a0 - 15000, "reparation au garage (15 000 F)")
		P.set_recherche(3)
		P.police_voit = false
		_check(com.buy("garage", 1) and P.recherche == 0, "peinture neuve hors de vue : la police perd la trace")
		car.global_position = Vector3(5000, 0, 5000)
		var a1: int = P.argent
		_check(not com.buy("garage", 0) and P.argent == a1, "sans vehicule devant le garage : rien n'est facture")
		# propriete
		_check(com.buy("agence", 0) and (P.drapeaux["proprietes"] as Array).has("chambre"), "chambre a Cadjehoue achetee")
		var car2 := Vehicules.create("veh_4x4", Color(0.1, 0.5, 0.2))
		scene.add_child(car2)
		car2.set_meta("couleur", Color(0.1, 0.5, 0.2))
		car2.global_position = pe._points["prop_chambre"] + Vector3(-2, 0.3, 0)
		pe._dormir("chambre")
		_check(P.drapeaux.has("garage_chambre") and FileAccess.file_exists(P.save_path), "dormir a la chambre : sauvegarde et 4x4 garde")
		P.tenue = {}
		P.charger(scene)
		_check(P.tenue.get("style") == "tshirt" and P.tenue.get("coiffure") == "chr_afro", "tenue rechargee depuis la sauvegarde (%s)" % P.tenue)
		# marche
		var pol := scene.get_node("Police")
		var marche := false
		for s in com.spots:
			if s["kind"] == "etal" and pol._au_marche(s["pos"]):
				marche = true
				break
		_check(marche, "au milieu des etals : cachette du marche")
		print("RESULTAT test_perso : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
