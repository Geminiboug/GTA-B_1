extends SceneTree
## Zem a heler : H (ici _hele) fait venir un zem par les rues jusqu'au joueur, on monte derriere, on choisit une
## destination, le trajet se fait en direct (aucun saut de position), on est depose a l'arrivee et le zem repart.
## Lancement : godot --headless --path godot --script res://tests/test_zem_taxi.gd

var frame := 0
var scene: Node
var zt: Node
var player: Node3D
var fails := 0
var etape := 0
var t0 := 0
var derniere := Vector3.INF
var saut_max := 0.0
var dist_trajet := 0.0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	Engine.time_scale = 3.0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _fin() -> bool:
	Engine.time_scale = 1.0
	print("RESULTAT test_zem_taxi : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true


func _physics_process(_d: float) -> bool:
	frame += 1
	var partie := root.get_node("Partie")
	if frame == 60:
		partie.nouvelle_partie()
		zt = scene.get_node("ZemTaxi")
		player = scene.get_node("Player")
		partie.argent = 20000
		var near: Dictionary = Carte.zone().nearest_on_network(Vector2(430.0, -250.0))
		var p: Vector2 = near["point"]
		player.global_position = Vector3(p.x + 3.0, 0.5, p.y)
		player.reset_physics_interpolation()
	if frame < 200:
		return false
	if etape == 0:
		zt._hele()
		_check(zt.etat == "arrive", "le zem est appele (etat %s)" % zt.etat)
		etape = 1
		t0 = frame
		return false
	if etape == 1:
		if zt.etat == "pret":
			var d: float = player.global_position.distance_to(zt._zem.global_position)
			_check(d < 10.0, "le zem s'arrete pres du joueur (%.1f m)" % d)
			player.global_position = zt._zem.global_position + Vector3(1.2, 0.3, 0)
			zt._monter()
			_check(player.vehicle == zt._zem and player.pillion, "le joueur est monte derriere en passager")
			_check(zt.etat == "choix", "menu des destinations ouvert")
			etape = 2
			t0 = frame
		elif frame - t0 > 60 * 150:
			_check(false, "le zem n'arrive pas (etat %s, reste %d points)" % [zt.etat, zt._route.size()])
			return _fin()
		return false
	if etape == 2 and frame - t0 > 90:
		# destination : la station "Ararat Hypermarket" (index 2 de DESTINATIONS, sans mission en cours)
		var idx := 0
		for i in zt._choix.size():
			if String(zt._choix[i][0]).begins_with("Ararat"):
				idx = i
		var argent_avant: int = partie.argent
		zt._partir(idx)
		_check(zt.etat == "course", "course demarree (etat %s)" % zt.etat)
		_check(partie.argent < argent_avant, "course payee (%d F)" % (argent_avant - partie.argent))
		derniere = player.global_position
		etape = 3
		t0 = frame
		return false
	if etape == 3:
		var p: Vector3 = player.global_position
		var saut := p.distance_to(derniere)
		saut_max = maxf(saut_max, saut)
		dist_trajet += saut
		derniere = p
		if zt.etat in ["depose", "depart", "libre"]:
			_check(saut_max < 2.5, "trajet en direct : saut de position maxi %.2f m par image (aucune teleportation)" % saut_max)
			_check(dist_trajet > 100.0, "distance parcourue en zem : %.0f m" % dist_trajet)
			var but: Vector3 = zt._dest
			_check(Vector2(p.x - but.x, p.z - but.z).length() < 60.0, "arrive pres de la destination (%.0f m)" % Vector2(p.x - but.x, p.z - but.z).length())
			etape = 4
			t0 = frame
		elif frame - t0 > 60 * 400:
			_check(false, "trajet trop long (etat %s)" % zt.etat)
			return _fin()
		return false
	if etape == 4 and frame - t0 > 60 * 6:
		_check(player.vehicle == null, "le joueur a ete depose")
		_check(zt.etat in ["depart", "libre"], "le zem repart ou est retire (etat %s)" % zt.etat)
		return _fin()
	return false
