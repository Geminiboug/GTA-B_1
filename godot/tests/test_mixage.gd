extends SceneTree
## Mixage (phase 19) : bus par categorie (vehicules, ambiance, effets), sources sonores rangees, volumes des options,
## reverberation dans l'Ararat et l'aerogare.
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
func _process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		for b in ["Vehicules", "Ambiance", "Effets", "Interieur"]:
			_check(AudioServer.get_bus_index(b) >= 0, "bus %s" % b)
		var z: Node = scene.get_node("Zem")
		var buses := {}
		for p in z.find_children("*", "AudioStreamPlayer3D", true, false):
			buses[String(p.bus)] = true
		_check(buses.has("Vehicules"), "moteur du zem dans le bus Vehicules (%s)" % buses.keys())
		var amb := 0
		for p in scene.get_node("Ambiance").find_children("*", "", true, false):
			if String(p.get("bus")) == "Ambiance":
				amb += 1
		_check(amb > 0, "ambiance dans le bus Ambiance (%d sources)" % amb)
		var P := root.get_node("Partie")
		P.options["vol_vehicules"] = 0.5
		P.appliquer_options()
		_check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Vehicules")) - linear_to_db(0.5)) < 0.1, "volume des vehicules regle")
		var lieux := scene.get_node("Lieux")
		_check(lieux.get_node_or_null("Reverb_ararat") != null and lieux.get_node_or_null("Reverb_terminal") != null, "reverberation dans l'Ararat et l'aerogare")
		print("RESULTAT test_mixage : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
