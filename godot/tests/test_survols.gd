extends SceneTree
## Trafic aerien visible : survols reguliers au-dessus de la zone (en altitude, feux allumes) et frequence des
## mouvements sur la piste relevee (densite), en plus du trafic de la piste.
var frame := 0
var scene: Node
var fails := 0
var at: Node
var p0 := Vector3.ZERO
func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1
func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		at = scene.get_node("TraficAerien")
		at.set("_t_survol", 9999.0)
		at.call("lancer_survol")
		var sv: Dictionary = at.get("_survols")[0]
		p0 = (sv["plane"] as Node3D).global_position
		_check(p0.y > 400.0, "survol en altitude (%.0f m)" % p0.y)
		_check(bool((sv["plane"] as Node).get("lights")["strobe"]), "feux de l'avion allumes")
		# frequence : attente moyenne a 18 h, densite comprise
		var s := 0.0
		for i in 200:
			s += float(at.call("_next_gap"))
		var gh: float = float(scene.get_node("JourNuit").get("minutes_per_game_day")) * 60.0 / 24.0
		_check(s / 200.0 < 80.0, "un mouvement sur la piste toutes les %.0f s en moyenne (heure de jeu = %.0f s)" % [s / 200.0, gh])
	if frame == 150:
		var sv: Dictionary = at.get("_survols")[0]
		var d := (sv["plane"] as Node3D).global_position.distance_to(p0)
		_check(d > 100.0, "l'avion avance (%.0f m en 2 s)" % d)
		print("RESULTAT test_survols : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
