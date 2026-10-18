extends SceneTree
## Armoire : a cote du lit de la maison, on remet gratuitement un vetement deja achete ou la tenue de depart.
var frame := 0
var scene: Node
var fails := 0
func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1
func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		var P := root.get_node("Partie")
		P.save_path = "user://test_armoire.json"
		var com := scene.get_node("Commerce")
		var perso := scene.get_node("Personnalisation")
		var arm := []
		for s in com.spots:
			if s["kind"] == "armoire":
				arm.append(s)
		_check(arm.size() >= 1, "une armoire dans la maison (%d)" % arm.size())
		var lit: Node3D = scene.get_node("Lieux").get("bed")
		_check(lit != null and (arm[0]["pos"] as Vector3).distance_to(lit.global_position) < 3.0, "l'armoire est a cote du lit")
		# deux achats a la friperie et au tailleur
		P.argent = 50000
		com.buy("friperie", 0)      # t-shirt rouge
		com.buy("tailleur", 1)      # boubou motif 2
		_check(String(P.tenue.get("style")) == "boubou", "le boubou achete est porte")
		var avant: int = P.argent
		perso.preparer("armoire")
		var items: Array = com.ARTICLES["armoire"]
		_check(items.size() == 3, "armoire : tenue de depart + 2 vetements achetes (%d)" % items.size())
		var i_tshirt := -1
		for i in items.size():
			if String(items[i][0]).begins_with("T-shirt"):
				i_tshirt = i
		com.buy("armoire", i_tshirt)
		_check(String(P.tenue.get("style")) == "tshirt", "on remet le t-shirt depuis l'armoire")
		_check(P.argent == avant, "l'armoire est gratuite")
		com.buy("armoire", 0)
		_check(P.tenue.is_empty(), "tenue de depart remise")
		print("RESULTAT test_armoire : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
