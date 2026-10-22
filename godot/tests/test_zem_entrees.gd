extends SceneTree
## Zem a heler avec les VRAIES touches (actions heler / interact) : H fait venir le zem, E pres de lui monte derriere en passager
## (sans voler le zem ni ejecter le pilote), menu de destination, course. Verifie aussi les cas limites : H loin d'une rue
## (refus), H deux fois (un seul zem), H pendant le menu et pendant la course (sans effet), E en roulant (on ne descend pas).
## Lancement : godot --headless --path godot -s res://tests/test_zem_entrees.gd
var frame := 0
var scene: Node
var zt: Node
var player: Node3D
var fails := 0
var etape := 0
var t0 := 0
var appuis := {}          # action -> images restantes avant relachement
var avant: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	Engine.time_scale = 3.0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _touche(action: String) -> void:
	Input.action_press(action)
	appuis[action] = 3


func _fin() -> bool:
	Engine.time_scale = 1.0
	print("RESULTAT test_zem_entrees : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true


func _suite(n: int) -> void:
	etape = n
	t0 = frame


func _physics_process(_d: float) -> bool:
	frame += 1
	for a in appuis.keys():
		appuis[a] -= 1
		if appuis[a] <= 0:
			Input.action_release(a)
			appuis.erase(a)
	var partie := root.get_node("Partie")
	if frame == 60:
		partie.nouvelle_partie()
		zt = scene.get_node("ZemTaxi")
		player = scene.get_node("Player")
		partie.argent = 20000
		player.global_position = Vector3(-500.0, 3.0, 900.0)       # loin de toute rue
		player.reset_physics_interpolation()
		_suite(0)
		return false
	if frame < 70:
		return false
	var d := frame - t0
	match etape:
		0:
			if d == 30:
				_touche("heler")
			elif d == 45:
				_check(zt.etat == "libre", "H loin d'une rue : refuse (etat %s)" % zt.etat)
				var near: Dictionary = Carte.zone().nearest_on_network(Vector2(430.0, -250.0))
				var p: Vector2 = near["point"]
				player.global_position = Vector3(p.x + 2.0, 0.5, p.y)
				player.reset_physics_interpolation()
				_suite(1)
		1:
			if d == 40:
				_touche("heler")
			elif d == 55:
				_check(zt.etat == "arrive", "H au bord de la rue : le zem arrive (etat %s)" % zt.etat)
				avant = zt._zem
				_touche("heler")
			elif d == 75:
				_check(zt._zem == avant, "H une 2e fois ne fabrique pas un 2e zem")
				_suite(2)
		2:
			if zt.etat == "pret":
				var z: Node3D = zt._zem
				player.global_position = z.global_position + z.global_transform.basis.x * 1.0 + Vector3(0, 0.3, 0)
				player.reset_physics_interpolation()
				_check(z.find_child("Pilote", true, false) != null, "le pilote est sur le zem")
				_touche("interact")
				_suite(3)
			elif d > 60 * 150:
				_check(false, "le zem n'arrive pas (etat %s)" % zt.etat)
				return _fin()
		3:
			if d == 25:
				var z: Node3D = zt._zem
				_check(player.vehicle == z, "E : le joueur est monte sur le zem du taxi")
				_check(player.pillion, "... en passager (pas conducteur)")
				_check(z.find_child("Pilote", true, false) != null, "... sans ejecter le pilote")
				_check(zt.etat == "choix", "menu des destinations (etat %s)" % zt.etat)
				avant = zt._zem
				_touche("heler")
			elif d == 45:
				_check(zt._zem == avant and zt.etat == "choix", "H pendant le menu : sans effet")
				zt._partir(0)
				_check(zt.etat == "course", "course demarree (etat %s)" % zt.etat)
				_suite(4)
		4:
			if d == 300:
				avant = zt._zem
				_touche("heler")
			elif d == 320:
				_check(zt._zem == avant, "H pendant la course : sans effet")
				_touche("interact")
			elif d == 340:
				_check(player.vehicle != null, "E en roulant : on ne saute pas du zem en marche")
				return _fin()
	return false
