extends SceneTree
## Sante, armure, hopital (phase 14) : le blouson renforce de l'Ararat absorbe 60 % des coups ; a zero de sante, le
## joueur se reveille devant le Centre de sante Gbekpo (fictif) et paie les soins ; armure gardee dans la sauvegarde.

var frame := 0
var scene: Node
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
		P.nouvelle_partie()
		P.argent = 20000
		var com := scene.get_node("Commerce")
		var idx := -1
		for i in com.ARTICLES["rayon_vrac"].size():
			if com.ARTICLES["rayon_vrac"][i][0] == "Blouson de moto renforcé":
				idx = i
		_check(idx >= 0 and com.buy("rayon_vrac", idx), "blouson renforce achete a l'Ararat")
		_check(P.armure == 100.0 and P.argent == 8000, "armure 100, 12 000 F payes (%.0f, %d F)" % [P.armure, P.argent])
		P.blesser(50.0)
		_check(is_equal_approx(P.sante, 80.0) and is_equal_approx(P.armure, 70.0), "coup de 50 : sante %.0f, armure %.0f" % [P.sante, P.armure])
		var hud := scene.get_node("HUDJeu")
		_check((hud.get("_armure") as ProgressBar).visible, "barre d'armure affichee")
		mark["argent"] = P.argent
		P.armure = 0.0
		P.blesser(500.0)
	if frame == 30 + 60 * 6:
		var pl: Node3D = scene.get_node("Player")
		var h: Vector3 = scene.get_node("Police").call("_hopital_rue")
		_check(pl.global_position.distance_to(h) < 6.0, "reveil devant le centre de sante (%.1f m)" % pl.global_position.distance_to(h))
		_check(P.sante == 100.0 and P.argent == int(mark["argent"]) - P.frais_hopital, "soigne, %d F de soins payes" % P.frais_hopital)
		_check(scene.get_node("Police").get_node_or_null("CentreSante") != null, "croix et enseigne du centre de sante")
		print("RESULTAT test_sante : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
