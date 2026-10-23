extends SceneTree
## Arret apres la course : le personnage ne glisse pas vers l'arriere ni ne repart (pas d'aller-retour), et s'immobilise vite.

var frame := 0
var scene: Node
var fails := 0
var pl: Node
var fwd := Vector2.ZERO
var pmax := -1e9
var recul := 0.0
var t_stop := -1
var p_rel := 0.0
var etat := 0
var t0 := 0
var p0 := Vector3.ZERO


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	if pl == null:
		pl = scene.get_node("Player")
		pl.set("attente_geste", Vector2(999.0, 999.0))
	var p := (pl as Node3D).global_position
	if etat == 0:
		(pl.get("cam_pivot") as Node3D).rotation.y = float(pl.get("_facing"))
		fwd = Vector2(-sin(float(pl.get("_facing"))), -cos(float(pl.get("_facing"))))
		p0 = p
		Input.action_press("move_forward")
		Input.action_press("sprint")
		etat = 1
		t0 = frame
	elif etat == 1 and frame - t0 == 120:
		Input.action_release("move_forward")
		Input.action_release("sprint")
		etat = 2
		t0 = frame
		pmax = Vector2(p.x - p0.x, p.z - p0.z).dot(fwd)
	elif etat == 2:
		var d := Vector2(p.x - p0.x, p.z - p0.z).dot(fwd)
		pmax = maxf(pmax, d)
		recul = maxf(recul, pmax - d)
		if t_stop < 0 and Vector2(pl.velocity.x, pl.velocity.z).length() < 0.05:
			t_stop = frame - t0
		if frame - t0 == 120:
			var vit := Vector2(pl.velocity.x, pl.velocity.z).length()
			_check(vit < 0.05, "immobile 2 s apres le relachement (%.2f m/s)" % vit)
			_check(t_stop >= 0 and t_stop < 40, "arret en %d images (moins de 40)" % t_stop)
			_check(recul < 0.05, "aucun recul apres l'arret (%.3f m)" % recul)
			_check(pmax > 5.0 and pmax < 30.0, "il a bien couru puis s arrete (%.1f m parcourus)" % pmax)
			print("RESULTAT test_arret_perso : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
			quit(1 if fails else 0)
			return true
	return false
