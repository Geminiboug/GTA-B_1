extends SceneTree
## On peut frapper tout le monde : un passant, un motard (zem), un automobiliste, un agent de police a pied.
## Un motard / automobiliste frappe s'arrete ; au 3e coup il est jete a terre (vehicule prenable) ; la police l'apprend.

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
	if frame < 240:
		return false
	var traf := scene.get_node("Circulation")
	var peds := scene.get_node("Pietons")
	var pol := scene.get_node("Police")
	var pl := scene.get_node("Player") as Node3D
	var dir := Vector3(0, 0, -1)
	var o := Vector3(0, 0.5, 0)
	# 1. motard (zem) et 2. automobiliste
	for genre in ["zem", "voiture"]:
		var cible := {}
		var idx := -1
		for i in traf._agents.size():
			var a: Dictionary = traf._agents[i]
			if (a["kind"] == "voiture") == (genre == "voiture") and a.get("active", true):
				cible = a
				idx = i
				break
		_check(idx >= 0, "un %s existe dans la circulation" % genre)
		cible["vis_pos"] = Vector3(0, 0.0, -1.6)
		cible["speed"] = 6.0
		var ok1: bool = traf.player_attack(o, dir, 0, 25.0, 1.6, false)
		_check(ok1, "%s : un coup de poing le touche" % genre)
		_check(float(cible.get("stunned", 0.0)) > 0.0, "%s : le vehicule s'arrete (conducteur sonne)" % genre)
		cible["vis_pos"] = Vector3(0, 0.0, -1.6)
		var ok3: bool = traf.player_attack(o, dir, 2, 50.0, 1.6, false)
		_check(ok3 and not cible.get("active", true), "%s : au 3e coup le conducteur est jete a terre (vehicule libre)" % genre)
	# 3. passant
	var w: Dictionary = {}
	for c in peds._walkers:
		if c["state"] == "walk" and not c.get("far", false):
			w = c
			break
	w["pos"] = Vector3(0, 0, -1.2)
	_check(peds.player_attack(o, dir, 0, 25.0, 1.6, false), "un passant est touche")
	# 4. agent de police a pied
	var offi := Node3D.new()
	scene.add_child(offi)
	offi.global_position = Vector3(0, 0, -1.2)
	pol.units.append({"car": null, "officer": offi, "state": "pied", "kind": "pied"})
	_check(pol.player_attack(o, dir, 0, 25.0, 1.6, false), "un agent de police a pied est touche")
	print("RESULTAT test_frapper_tous : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
