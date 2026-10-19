extends SceneTree
## Chargement par morceaux (docs/chargement_par_morceaux.md) : au lancement, seules les tuiles autour du joueur sont
## posees (sol avec collisions, decor). Le joueur est ensuite envoye a Fidjrosse, a l'autre bout de la carte : la tuile
## sous lui arrive tout de suite (il ne tombe pas), son decor est pose en travail de fond, et les tuiles du depart
## (a plus de rayon_libere) sont liberees avec leur decor.
var frame := 0
var scene: Node
var monde: Node
var player: CharacterBody3D
var fails := 0
var phase := "depart"
var t_phase := 0
const LOIN := Vector3(-2800, 3.0, 120)
const DEPART := Vector3(300, 0, 120)


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _posees() -> int:
	var n := 0
	var tuiles: Dictionary = monde.get("tuiles")
	for cle in tuiles:
		if tuiles[cle]["noeud"] != null:
			n += 1
	return n


func _sol(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 50, p.z), Vector3(p.x, -5, p.z))
	q.collision_mask = 1
	return not scene.get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty()


func _physics_process(_d: float) -> bool:
	frame += 1
	t_phase += 1
	match phase:
		"depart":
			if frame < 40 or not scene.get_node("Props").get("placed"):
				if frame > 3000:
					_check(false, "le decor est place")
					return _fin()
				return false
			monde = scene.get_node("zone_aeroport")
			player = scene.get_node("Player")
			var total: int = (monde.get("tuiles") as Dictionary).size()
			var n := _posees()
			_check(total >= 30 and n >= 4 and n < total, "tuiles posees autour du joueur seulement (%d / %d)" % [n, total])
			var trous := 0
			for p in [Vector3(300, 0, 120), Vector3(420, 0, -20), Vector3(43, 0, 10), Vector3(150, 0, 200)]:
				if not _sol(p):
					trous += 1
			_check(trous == 0, "sol avec collisions autour du depart (%d trous)" % trous)
			var c: Dictionary = scene.get_node("Props").get("counts")
			_check(int(c.get("prop_poteau", 0)) > 200, "decor pose (%d poteaux)" % int(c.get("prop_poteau", 0)))
			player.global_position = LOIN
			player.velocity = Vector3.ZERO
			phase = "voyage"
			t_phase = 0
		"voyage":
			if t_phase == 3:
				_check(monde.call("chargee", LOIN), "tuile sous le joueur posee tout de suite apres la teleportation")
			if t_phase < 1200 and root.get_node("Partie").taches_en_attente() > 0:
				return false
			if t_phase < 60:
				return false
			_check(player.global_position.y > -1.0, "le joueur ne tombe pas (y = %.1f)" % player.global_position.y)
			_check(_sol(LOIN), "sol avec collisions a Fidjrosse")
			_check(not monde.call("chargee", DEPART), "tuiles du depart liberees")
			var props := scene.get_node("Props")
			var decor_loin := false
			for cle in props.get("_par_tuile"):
				var r: Rect2 = props.get("_par_tuile")[cle]["rect"]
				if r.has_point(Vector2(LOIN.x, LOIN.z)):
					decor_loin = true
			_check(decor_loin, "decor de la tuile de Fidjrosse en place")
			_check(not (props.get("_par_tuile") as Dictionary).keys().any(func(k: Vector2i) -> bool:
				return (props.get("_par_tuile")[k]["rect"] as Rect2).has_point(Vector2(DEPART.x, DEPART.z))), "decor du depart libere")
			return _fin()
	return false


func _fin() -> bool:
	print("RESULTAT test_tuiles : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
