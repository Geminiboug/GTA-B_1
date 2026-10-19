extends SceneTree
## Chargement par morceaux (etape 2, docs/chargement_par_morceaux.md) : la zone est faite des tuiles de
## assets/models/tuiles/ ; toutes sont posees au lancement, le sol a des collisions partout ou la zone en avait, et le
## decor se pose comme avant (meme nombre de poteaux, d'arbres et d'objets du kit de rue).
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
	if frame < 40 or not scene.get_node("Props").get("placed"):
		if frame > 3000:
			_check(false, "le decor est place")
			return _fin()
		return false
	var monde := scene.get_node("zone_aeroport")
	var tuiles: Dictionary = monde.get("tuiles")
	var posees := 0
	for cle in tuiles:
		if tuiles[cle]["noeud"] != null:
			posees += 1
	_check(tuiles.size() >= 12 and posees == tuiles.size(), "toutes les tuiles posees (%d / %d)" % [posees, tuiles.size()])
	var space: PhysicsDirectSpaceState3D = scene.get_viewport().world_3d.direct_space_state
	var trous := 0
	for p in [Vector2(300, 120), Vector2(420, -20), Vector2(43, 10), Vector2(528, -301), Vector2(-400, -900), Vector2(150, 200)]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 50, p.y), Vector3(p.x, -5, p.y))
		q.collision_mask = 1
		if space.intersect_ray(q).is_empty():
			trous += 1
	_check(trous == 0, "sol avec collisions aux points de controle (%d trous)" % trous)
	var c: Dictionary = scene.get_node("Props").get("counts")
	_check(int(c.get("prop_poteau", 0)) > 500 and int(c.get("rue_parasol", 0)) > 30, "decor pose (%d poteaux, %d parasols)" % [int(c.get("prop_poteau", 0)), int(c.get("rue_parasol", 0))])
	return _fin()
func _fin() -> bool:
	print("RESULTAT test_tuiles : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
