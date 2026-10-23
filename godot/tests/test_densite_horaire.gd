extends SceneTree
## La circulation varie avec l'heure de jeu : creuse la nuit, pleine aux heures de pointe, sans toucher aux vehicules visibles.

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


func _actifs(traf: Node) -> int:
	var n := 0
	for a in traf._agents:
		if a.get("active", true):
			n += 1
	return n


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 200:
		return false
	var traf := scene.get_node("Circulation")
	var jn := scene.get_node("JourNuit")
	var total: int = traf._agents.size()
	var loin := Vector3(1e6, 0, 1e6)    # le joueur est suppose tres loin : seul le champ de la camera protege les vehicules
	_check(absf(traf.part_circulation(8.0) - 1.0) < 0.01, "part 1.0 a 8 h")
	_check(traf.part_circulation(3.0) < 0.4, "part < 0.4 a 3 h")
	jn.hour = 3.0
	traf._densite_horaire(loin)
	var nuit := _actifs(traf)
	_check(nuit < total * 0.55, "nuit : %d / %d vehicules en circulation" % [nuit, total])
	jn.hour = 8.0
	traf._densite_horaire(loin)
	var pointe := _actifs(traf)
	_check(pointe >= total - 3, "pointe : %d / %d vehicules en circulation" % [pointe, total])
	print("RESULTAT test_densite_horaire : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
