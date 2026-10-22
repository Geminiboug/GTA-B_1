extends SceneTree
## Portes articulees : chaque modele de voiture a ses portes (porte_g0 / d0, plus les portes arriere), qui pivotent a
## l'ouverture et reviennent a la fermeture ; le joueur ouvre la portiere en montant et la referme une fois assis.
## Lancement : godot --headless --path godot --script res://tests/test_portes.gd

var frame := 0
var scene: Node
var fails := 0
var voitures: Array = []
var etape := 0
var t0 := 0
var modeles := ["veh_berline", "veh_4x4", "veh_minibus", "veh_pickup", "veh_pejo", "veh_mersede"]


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _fin() -> bool:
	print("RESULTAT test_portes : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 120:
		return false
	var player := scene.get_node("Player") as CharacterBody3D
	if etape == 0:
		var x := 0.0
		for m in modeles:
			var c := Vehicules.create(m, Color(0.6, 0.6, 0.6))
			scene.add_child(c)
			c.global_position = Vector3(-3200.0 + x, 0.5, -900.0)
			x += 7.0
			voitures.append(c)
			_check(c.call("a_portes"), "%s a des portes articulees" % m)
			_check(c.get("_portes").has("porte_g0") and c.get("_portes").has("porte_d0"), "%s : portes avant gauche et droite" % m)
			c.remove_from_group("vehicules")   # hors tuile chargee, monde.gd fige les vehicules (et leurs tweens)
			c.call("ouvrir_porte", "porte_g0", true, 0.1)
		etape = 1
		t0 = frame
		return false
	if etape == 1 and (frame - t0 == 600 or (frame - t0 > 20 and float(voitures[-1].get("_portes")["porte_g0"]["angle"]) < -1.0)):
		for c in voitures:
			var n: Node3D = c.get("_portes")["porte_g0"]["node"]
			var base: Transform3D = c.get("_portes")["porte_g0"]["base"]
			var ang := absf((base.basis.inverse() * n.transform.basis).get_euler().y)
			_check(ang > 0.8, "%s : la portiere conducteur est ouverte (%.0f degres, angle %.2f, ouverte %s)" % [c.get("model_name"), rad_to_deg(ang), float(c.get("_portes")["porte_g0"]["angle"]), str(c.get("_portes")["porte_g0"]["ouverte"])])
			c.call("ouvrir_porte", "porte_g0", false, 0.1)
		etape = 2
		t0 = frame
		return false
	if etape == 2 and (frame - t0 == 600 or (frame - t0 > 20 and absf(float(voitures[-1].get("_portes")["porte_g0"]["angle"])) < 0.02)):
		for c in voitures:
			var n: Node3D = c.get("_portes")["porte_g0"]["node"]
			var base: Transform3D = c.get("_portes")["porte_g0"]["base"]
			var ang := absf((base.basis.inverse() * n.transform.basis).get_euler().y)
			_check(ang < 0.05, "%s : refermee" % c.get("model_name"))
		# le joueur monte : la portiere s'ouvre pendant le geste puis se ferme une fois assis
		var c0: Node3D = voitures[0]
		player.global_position = c0.entry_point() + Vector3(-0.5, 0.3, 0.0)
		player.reset_physics_interpolation()
		player.call("_start_pre", c0)
		etape = 3
		t0 = frame
		return false
	if etape == 3 and frame - t0 == 20:
		var c0: Node3D = voitures[0]
		_check(bool(c0.get("_portes")["porte_g0"]["ouverte"]), "la portiere s'ouvre quand le joueur monte")
		etape = 4
		t0 = frame
		return false
	if etape == 4 and frame - t0 == 120:
		var c0: Node3D = voitures[0]
		_check(player.vehicle == c0, "le joueur est assis")
		_check(not bool(c0.get("_portes")["porte_g0"]["ouverte"]), "la portiere est refermee une fois assis")
		return _fin()
	return false
