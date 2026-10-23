extends SceneTree
## Feux tricolores et STOP : les deux axes ne sont jamais verts en meme temps, des vehicules s'arretent aux feux,
## et la circulation continue de rouler (pas de carrefour fige).

var frame := 0
var scene: Node
var fails := 0
var arrets_vus := 0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	Engine.time_scale = 4.0


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 240:
		return false
	var traf := scene.get_node("Circulation")
	var sg: Signalisation = traf._signal
	if frame == 240:
		_check(sg._feux.size() > 20, "%d carrefours a feux" % sg._feux.size())
		_check(sg._stops.size() > 20, "%d carrefours a STOP" % sg._stops.size())
	if frame % 30 == 0:
		var conflit := 0
		for n in sg._feux.keys():
			var e0: int = sg._etat_axe(n, 0)
			var e1: int = sg._etat_axe(n, 1)
			if e0 != 2 and e1 != 2:
				conflit += 1
		if conflit > 0:
			_check(false, "deux axes non rouges en meme temps (%d carrefours)" % conflit)
		for a in traf._agents:
			if a.get("au_feu", false) and float(a["speed"]) < 0.5:
				arrets_vus += 1
	if frame < 240 + 60 * 60:
		return false
	var roule := 0
	for a in traf._agents:
		if absf(float(a["speed"])) > 1.0:
			roule += 1
	_check(roule >= 20, "%d vehicules roulent apres 60 s (x4)" % roule)
	_check(arrets_vus > 0, "des vehicules se sont arretes a un feu ou un STOP (%d relevés)" % arrets_vus)
	Engine.time_scale = 1.0
	print("RESULTAT test_feux : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
