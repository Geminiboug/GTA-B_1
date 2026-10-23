extends SceneTree
## Parc de vehicules : voitures de plusieurs types, motos de particuliers (pas des zems), velos, camions, autobus.

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
	var modeles := {}
	for a in scene.get_node("Circulation")._agents:
		modeles[a["model"]] = int(modeles.get(a["model"], 0)) + 1
	print("modeles : ", modeles)
	_check(modeles.size() >= 8, "au moins 8 modeles differents en circulation (%d)" % modeles.size())
	_check(int(modeles.get("moto", 0)) >= 5, "motos de particuliers presentes (%d)" % int(modeles.get("moto", 0)))
	_check(int(modeles.get("velo", 0)) >= 3, "velos presents (%d)" % int(modeles.get("velo", 0)))
	_check(int(modeles.get("zem", 0)) > int(modeles.get("moto", 0)), "les zems restent les plus nombreux")
	_check(modeles.has("veh_camion") or modeles.has("veh_plateau") or modeles.has("veh_bus"), "poids lourds presents")
	for m in ["veh_hatch", "veh_monospace", "veh_plateau", "veh_bus", "veh_camion"]:
		var t: Dictionary = Vehicules.TUNING.get(m, {})
		_check(not t.is_empty() and float(t["masse"]) > 900.0, "%s : reglages de conduite (masse %.0f kg)" % [m, float(t.get("masse", 0))])
	var v := Vehicules.create("veh_bus", Color.WHITE)
	_check(v != null and v.get("model_name") == "veh_bus", "l'autobus est conduisible")
	print("RESULTAT test_parc_vehicules : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
