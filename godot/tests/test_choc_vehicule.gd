extends SceneTree
## Choc entre vehicules : conservation de la quantite de mouvement (masses reelles), le vehicule percute est projete et tourne,
## les degats viennent de la variation de vitesse (pas d'une baisse differee), et le percute finit par s'arreter.

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
	var traf := scene.get_node("Circulation")
	var cible := {}
	for a in traf._agents:
		if a["kind"] == "voiture":
			cible = a
			break
	for b in traf._agents:
		if not is_same(b, cible):
			b["active"] = false
	var m2: float = traf.MASSES.get(cible["model"], 1200.0)
	cible["speed"] = 0.0
	cible["knock"] = Vector2.ZERO
	var centre: Vector3 = cible["vis_pos"]
	var joueur := Vehicules.create("veh_4x4", Color.WHITE)
	scene.add_child(joueur)
	joueur.global_position = centre + Vector3(0, 0, 4.5)
	var m1: float = float(joueur.get("masse"))
	var v0 := Vector2(0, -12.0)                 # 12 m/s vers le nord (-Z), contre la cible
	joueur.set("_vel", v0)
	var n2 := Vector2(0, 1)                    # normale : de l'obstacle vers le joueur
	var pv0: float = float(cible.get("pv", 100.0))
	var contact := centre + Vector3(0.8, 0.5, 2.0)    # contact decentre : la cible doit tourner
	traf.choc_vehicule(joueur, cible["body"], n2, v0, contact, 12.0)
	var k: Vector2 = cible["knock"]
	var dv2 := k.length()
	var dv1: float = ((joueur.get("_vel") as Vector2) - v0).length()
	_check(k.y < -1.0, "le percute est projete vers l'avant du choc (%.1f m/s)" % k.length())
	_check(absf(float(cible.get("spin", 0.0))) > 0.05, "le percute tourne selon le point d'impact (%.2f rad/s)" % float(cible.get("spin", 0.0)))
	_check(absf(m1 * dv1 - m2 * dv2) < 0.05 * m1 * dv1 + 1.0, "quantite de mouvement conservee (%.0f contre %.0f kg.m/s)" % [m1 * dv1, m2 * dv2])
	_check(float(cible.get("pv", 100.0)) < pv0, "le percute est abime tout de suite (%.0f -> %.0f)" % [pv0, float(cible.get("pv", 100.0))])
	_check(float(cible.get("knock_t", 0.0)) > 0.0, "il passe en mode projete")
	var depart := (cible["vis_pos"] as Vector3)
	for i in 600:
		if float(cible.get("knock_t", 0.0)) <= 0.0:
			break
		traf._knock_step(cible, 1.0 / 60.0)
	var fin := (cible["vis_pos"] as Vector3)
	_check(fin.distance_to(depart) > 0.5, "il a glisse de %.1f m avant de s'arreter" % fin.distance_to(depart))
	_check(float(cible.get("knock_t", 0.0)) <= 0.0, "la projection se termine")
	print("RESULTAT test_choc_vehicule : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
