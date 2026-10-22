extends SceneTree
## Parcours complet du zem a heler avec captures et detection de glitches : appel, arrivee, arret, montee, trajet, depose, depart.
## Journal : sauts de position ou de hauteur, rotations brusques, marche arriere, arret prolonge. Images dans <dossier>.
## Lancement (avec fenetre) : godot --path godot --resolution 1280x720 --script res://tests/capture_zem.gd -- <dossier> [x z]
var frame := 0
var scene: Node
var zt: Node
var player: Node3D
var cam: Camera3D
var out_dir := "user://"
var etat_prec := ""
var n_img := 0
var prec_pos := Vector3.INF
var prec_yaw := 0.0
var arret_t := 0.0
var glitches: Array = []
var debut := 0
var x0 := 430.0
var z0 := -250.0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	if a.size() > 2 and a[1] != "nuit":
		x0 = float(a[1])
		z0 = float(a[2])
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	Engine.time_scale = 2.0


func _img(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/zem_%02d_%s.png" % [out_dir, n_img, nom])
	n_img += 1


func _cam_sur(cible: Vector3, regard: Vector3, dist: float, haut: float, angle: float) -> void:
	var dir := Basis(Vector3.UP, deg_to_rad(angle)) * Vector3(regard.x, 0, regard.z).normalized()
	cam.global_position = cible + dir * dist + Vector3(0, haut, 0)
	cam.look_at(cible + Vector3(0, 0.9, 0))
	cam.current = true


func _physics_process(_d: float) -> bool:
	frame += 1
	var partie := root.get_node("Partie")
	if frame == 60:
		partie.nouvelle_partie()
		zt = scene.get_node("ZemTaxi")
		player = scene.get_node("Player")
		partie.argent = 20000
		cam = Camera3D.new()
		cam.fov = 55.0
		if OS.get_cmdline_user_args().has("nuit"):
			var jn := scene.get_node("JourNuit")
			jn.set("hour", 21.5)
			jn.set("minutes_per_game_day", 100000.0)
		scene.add_child(cam)
		var near: Dictionary = Carte.zone().nearest_on_network(Vector2(x0, z0))
		var p: Vector2 = near["point"]
		player.global_position = Vector3(p.x + 3.0, 0.5, p.y)
		player.reset_physics_interpolation()
		for n in scene.get_children():
			if n is CanvasLayer:
				n.visible = true
	if frame < 200:
		return false
	if frame == 200:
		zt._hele()
		print("hele : joueur ", player.global_position, " recherche ", partie.recherche, " vehicule ", player.get("vehicle"))
		debut = frame
		print("etat apres appel : ", zt.etat)
	var z: Node3D = zt._zem
	if z and frame % 480 == 0 and zt.etat == "course" and z.get("_phare") != null:
		var ph: SpotLight3D = z.get("_phare")
		print("  phare : energie %.1f portee %.0f visible %s pos relative %s dir %s" % [ph.light_energy, ph.spot_range, ph.is_visible_in_tree(), z.to_local(ph.global_position), z.global_transform.basis.inverse() * (-ph.global_transform.basis.z)])
	if z and frame % 240 == 0 and zt.etat in ["arrive", "course"]:
		print("  [%d] %s zem (%.0f, %.0f) a %.0f m du joueur, route %d pts, t=%.0f" % [frame, zt.etat, z.global_position.x, z.global_position.z, z.global_position.distance_to(player.global_position), zt._route.size(), zt._t])
	if z and frame % 240 == 0 and zt.etat == "arrive" and prec_pos != Vector3.INF and z.global_position.distance_to(prec_pos) < 0.05:
		var yw: float = float(z.get("_yaw"))
		var fw := Vector3(-sin(yw), 0, -cos(yw))
		var dep := z.global_position + Vector3(0, 0.6, 0) + fw * 1.2
		var hh := z.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(dep, dep + fw * 16.0, 1, [z.get_rid()]))
		print("    obstacle : ", hh.get("collider"), " a ", dep.distance_to(hh["position"]) if not hh.is_empty() else -1.0, " vitesse ", z.get("speed"), " entree ", z.get("ai_input"))
		_cam_sur(z.global_position, fw, 6.0, 2.5, 150.0)
		_img("bloque")
	# chaque etat : une capture a l entree, de cote
	if zt.etat != etat_prec:
		print("[%d] etat %s -> %s" % [frame, etat_prec, zt.etat])
		etat_prec = zt.etat
		arret_t = 0.0
		if z:
			_cam_sur(z.global_position, -z.global_transform.basis.z, 4.5, 1.6, 90.0)
			await_frames = 3
			pending = "etat_" + zt.etat
	if z:
		_cam_sur(z.global_position, -z.global_transform.basis.z, 4.5, 1.6, 90.0)
		var p := z.global_position
		var yaw := z.global_rotation.y
		if prec_pos != Vector3.INF:
			var saut := p.distance_to(prec_pos)
			var dy := absf(angle_difference(prec_yaw, yaw))
			if saut > 2.5:
				glitches.append("[%d] saut de position %.1f m (etat %s)" % [frame, saut, zt.etat])
			if absf(p.y - prec_pos.y) > 0.5:
				glitches.append("[%d] saut de hauteur %.2f m (etat %s)" % [frame, p.y - prec_pos.y, zt.etat])
			if dy > deg_to_rad(25.0):
				glitches.append("[%d] rotation brusque %.0f deg (etat %s)" % [frame, rad_to_deg(dy), zt.etat])
			var avance := (p - prec_pos).dot(-z.global_transform.basis.z)
			if avance < -0.05 and zt.etat in ["arrive", "course", "depart"]:
				glitches.append("[%d] marche arriere %.2f m (etat %s)" % [frame, avance, zt.etat])
			if saut < 0.01 and zt.etat in ["arrive", "course"]:
				arret_t += 1.0 / 60.0
				if arret_t > 4.0:
					glitches.append("[%d] arret de plus de 4 s en route (etat %s) a (%.0f, %.0f)" % [frame, zt.etat, p.x, p.z])
					arret_t = -100.0
			else:
				arret_t = maxf(arret_t, 0.0) if saut < 0.01 else 0.0
		prec_pos = p
		prec_yaw = yaw
	if await_frames > 0:
		await_frames -= 1
		if await_frames == 0:
			_img(pending)
	# etats : appui virtuel sur les actions
	if zt.etat == "pret" and frame % 40 == 0 and z:
		player.global_position = z.global_position + z.global_transform.basis.x * 1.2 + Vector3(0, 0.3, 0)
		zt._monter()
	if zt.etat == "choix" and frame % 90 == 0:
		var idx := 0
		for i in zt._choix.size():
			if String(zt._choix[i][0]).begins_with("Ararat"):
				idx = i
		zt._partir(idx)
	if zt.etat == "course" and frame % 400 == 0 and z:
		_img("course")
	if frame - debut > 60 * 500 or (etat_prec == "depart" and frame % 200 == 0 and n_img > 8) or zt.etat == "libre" and frame > 400 and etat_prec == "depart":
		return _fin()
	return false


var await_frames := 0
var pending := ""


func _fin() -> bool:
	Engine.time_scale = 1.0
	print("fin a l image %d (debut %d, etat %s, precedent %s)" % [frame, debut, zt.etat, etat_prec])
	print("GLITCHES : %d" % glitches.size())
	for g in glitches.slice(0, 60):
		print("  ", g)
	print("RESULTAT capture_zem : %d images" % n_img)
	quit()
	return true
