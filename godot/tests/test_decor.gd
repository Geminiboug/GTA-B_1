extends SceneTree
## Decor de la suite de l'audit Cotonou : le kit d'objets de rue, les chantiers, les inscriptions murales (jamais posees
## avant le 18/10/2026 : murs lus par segments de 0,5 m), les paraboles et les nouveaux arbres sont bien places ;
## aucun objet du kit sur une chaussee.
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
	if frame < 40:
		return false
	var props := scene.get_node("Props")
	if not props.get("placed"):
		if frame > 2000:
			_check(false, "le decor est place")
			return _fin()
		return false
	var c: Dictionary = props.get("counts")
	var kit := 0
	for k in ["rue_parasol", "rue_banc", "rue_gaz", "rue_bidons", "rue_casiers"]:
		kit += int(c.get(k, 0))
	_check(kit >= 60, "kit d'objets de rue devant les boutiques (%d)" % kit)
	_check(int(c.get("rue_sable", 0)) >= 5, "chantiers le long des murs (%d tas de sable)" % int(c.get("rue_sable", 0)))
	_check(int(c.get("inscription", 0)) >= 20, "inscriptions peintes sur les murs (%d)" % int(c.get("inscription", 0)))
	_check(int(c.get("toit_parabole", 0)) >= 50, "paraboles sur les toits (%d)" % int(c.get("toit_parabole", 0)))
	var carte := Carte.zone()
	var sur_route := 0
	for key in props.get("_chunks"):
		var ch: Dictionary = props.get("_chunks")[key]
		if String(ch["kind"]).begins_with("rue_"):
			for xf in ch["xf"]:
				var o: Vector3 = (xf as Transform3D).origin
				if carte.on_carriageway(Vector2(o.x, o.z), 0.3):
					sur_route += 1
	_check(sur_route == 0, "aucun objet du kit sur une chaussee (%d)" % sur_route)
	var veg: Dictionary = scene.get_node("Vegetation").get("_xforms")
	_check(veg["veg_badamier"].size() >= 50 and veg["veg_neem"].size() >= 50,
		"badamiers et neems a terre (%d, %d)" % [veg["veg_badamier"].size(), veg["veg_neem"].size()])
	return _fin()
func _fin() -> bool:
	print("RESULTAT test_decor : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
