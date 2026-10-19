extends SceneTree
## Circuler dans les avions a pied (retour d'Olympe du 16/10/2026 : on ne pouvait ni marcher dans l'allee, ni entrer
## dans le poste de pilotage, ni ressortir). Pour l'epave de la plage puis pour un avion gare au poste : monter
## l'escalier, entrer par la porte avant gauche, descendre l'allee sur 12 m, revenir, entrer dans le poste de
## pilotage, ressortir et redescendre l'escalier jusqu'au sol. Le joueur marche avec les touches, camera tournee
## vers le point suivant ; echec s'il reste bloque 4 s.
## Lancement : godot --headless --path godot --script res://tests/test_cabine.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var avions: Array = []        # [nom, [points...], hauteur du sol au pied de l'escalier]
var ai := -1
var wi := 0
var last := Vector3.INF
var stuck := 0.0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _center(n: Node3D) -> Vector3:
	var mi := n as MeshInstance3D
	if mi == null:
		mi = n.find_child("*", true, false) as MeshInstance3D
	return mi.global_transform * mi.mesh.get_aabb().get_center() if mi else n.global_position


func _parcours(bottom: Vector3, landing: Vector3, n: Vector3, allee: float, axe: float, poste: float) -> Array:
	## bottom : pied de l'escalier ; landing : palier ; n : vers le nez ; allee / axe : distance de la porte a
	## l'allee et a l'axe du fuselage ; poste : distance (vers le nez) de la porte au fond du poste de pilotage.
	var d := ((landing - bottom) * Vector3(1, 0, 1)).normalized()       # de la porte vers l'interieur
	var fl := landing + Vector3(0, 0.1, 0)
	var dans := fl + d * 1.0
	var a0 := fl + d * allee
	return [["palier", fl - d * 0.3], ["porte", dans], ["allee", a0], ["allee 12 m", a0 - n * 12.0], ["retour", a0],
		["porte du poste", fl + d * axe + n * (poste - 1.2)], ["poste de pilotage", fl + d * axe + n * poste],
		["porte du poste (retour)", fl + d * axe + n * (poste - 1.2)], ["devant le poste", fl + d * axe + n * 0.3],
		# passages en biais (retour d'Olympe du 19/10/2026 : en ratant la porte, on restait coince dans l'encadrement)
		["vers la porte en biais", dans + n * 0.6], ["sortie en biais", fl - d * 0.4 - n * 0.45],
		["entree en biais", dans - n * 0.6], ["sortie en biais (autre cote)", fl - d * 0.4 + n * 0.45],
		["retour porte", dans], ["sortie", fl - d * 0.3], ["pied de l'escalier", bottom]]


func _physics_process(delta: float) -> bool:
	frame += 1
	if frame == 60:
		player = scene.get_node("Player")
		# epave de la plage (scripts : blender/tools/build_epave.py) : palier a 0,5 m de la porte : allee gauche a 2,05 m, axe a 3,47 m
		var m0 := scene.find_child("escalier_marche_0", true, false) as Node3D
		var pal := scene.find_child("escalier_palier", true, false) as Node3D
		var fus := scene.find_child("avion_fuselage*", true, false) as Node3D
		_check(m0 != null and pal != null and fus != null, "epave : escalier et carlingue trouves")
		if m0 and pal and fus:
			var b := _center(m0)
			var l := _center(pal)
			var c := _center(fus)
			var d := ((l - b) * Vector3(1, 0, 1)).normalized()
			var n := Vector3(-d.z, 0, d.x)
			if (l - c).dot(n) < 0.0:
				n = -n                     # la porte avant est du cote du nez
			avions.append(["epave", _parcours(b, l, n, 2.05, 3.47, 3.4), b.y])
		var air := scene.get_node("TraficAerien")
		for s in air.stands:
			if s["plane"] != null:
				var xf: Transform3D = (s["plane"] as Node3D).global_transform
				var b2 := xf * Vector3(-8.6, 0.1, -15.75)
				var l2 := xf * Vector3(-2.55, 2.72, -15.75)
				avions.append(["avion au poste", _parcours(b2, l2, -xf.basis.z.normalized(), 2.55, 2.55, 2.3), b2.y])
				break
		_check(avions.size() == 2, "un avion gare au poste")
		ai = 0
		_start()
	if ai < 0 or player == null:
		return false
	if ai >= avions.size():
		Input.action_release("move_forward")
		print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
		quit(1 if fails else 0)
		return true
	var pts: Array = avions[ai][1]
	var goal: Vector3 = pts[wi][1]
	var to := goal - player.global_position
	player.cam_pivot.rotation.y = atan2(-to.x, -to.z)
	Input.action_press("move_forward")
	if Vector2(to.x, to.z).length() < 0.45:
		wi += 1
		stuck = 0.0
		last = Vector3.INF
		if wi >= pts.size():
			_check(player.global_position.y < float(avions[ai][2]) + 0.8, "%s : circuit complet, redescendu au sol (%.2f m)" % [avions[ai][0], player.global_position.y])
			ai += 1
			if ai < avions.size():
				_start()
		return false
	if stuck > 3.0 and stuck < 3.3:
		print("    t %.2f pos %s vel %s mur %s climb %s" % [stuck, player.global_position.snapped(Vector3.ONE * 0.001), player.velocity.snapped(Vector3.ONE * 0.01), player.is_on_wall(), not (player.get("_climb") as Dictionary).is_empty()])
	if last == Vector3.INF or player.global_position.distance_to(last) > 0.3:
		last = player.global_position
		stuck = 0.0
	else:
		stuck += delta
	if stuck > 4.0:
		var probe := KinematicCollision3D.new()
		for h in [0.05, 0.3, 0.9, 1.6]:
			if player.test_move(player.global_transform.translated(Vector3.UP * h), (to * Vector3(1, 0, 1)).normalized() * 0.4, probe):
				print("    devant a +%.2f m : %s/%s point %s normale %s" % [h, probe.get_collider().get_parent().name, probe.get_collider().name, probe.get_position().snapped(Vector3.ONE * 0.01), probe.get_normal().snapped(Vector3.ONE * 0.01)])
		print("    vitesse %s  sur le sol %s  contacts %d" % [player.velocity.snapped(Vector3.ONE * 0.01), player.is_on_floor(), player.get_slide_collision_count()])
		for k in player.get_slide_collision_count():
			var ck := player.get_slide_collision(k)
			print("      %s/%s %s n %s" % [ck.get_collider().get_parent().name, ck.get_collider().name, ck.get_position().snapped(Vector3.ONE * 0.01), ck.get_normal().snapped(Vector3.ONE * 0.01)])
		var c := player.get_last_slide_collision()
		_check(false, "%s : bloque avant « %s » a %s (%s)" % [avions[ai][0], pts[wi][0], player.global_position.snapped(Vector3.ONE * 0.01),
			("%s/%s au point %s normale %s, but %s" % [c.get_collider().get_parent().name, c.get_collider().name, c.get_position().snapped(Vector3.ONE * 0.01), c.get_normal().snapped(Vector3.ONE * 0.01), (pts[wi][1] as Vector3).snapped(Vector3.ONE * 0.01)]) if c else "aucun contact"])
		ai += 1
		if ai < avions.size():
			_start()
	return frame > 60 * 120


func _start() -> void:
	var pts: Array = avions[ai][1]
	var bottom: Vector3 = (pts[pts.size() - 1][1] as Vector3)
	player.global_position = bottom + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	Input.action_press("walk")
	wi = 0
	stuck = 0.0
	last = Vector3.INF
