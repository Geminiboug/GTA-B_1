extends SceneTree
## Les pietons marchent vraiment : pour quelques marcheurs proches du joueur, le pied gauche bouge par rapport au
## bassin pendant qu'ils avancent (pas de glissade d'un corps fige), et ils regardent dans le sens de la marche.
## Le cortege de funerailles (evenements.gd) est lance et verifie de la meme facon.
var frame := 0
var scene: Node
var fails := 0
var suivis: Array = []    # [noeud, pos depart, [ecarts du pied], pos precedente, alignements]
const IMAGES := 120


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _pied(n: Node3D) -> Vector3:
	var sk := n.find_child("*", true, false) as Skeleton3D
	for c in n.find_children("*", "Skeleton3D", true, false):
		sk = c
		break
	if sk == null:
		return Vector3.INF
	var pied := sk.find_bone("LeftFoot")
	var bassin := sk.find_bone("Hips")
	if pied < 0 or bassin < 0:
		return Vector3.INF
	return sk.get_bone_global_pose(pied).origin - sk.get_bone_global_pose(bassin).origin


func _suivre(noeuds: Array) -> void:
	suivis.clear()
	for n in noeuds:
		suivis.append([n, (n as Node3D).global_position, [], (n as Node3D).global_position, 0, 0])


func _mesurer() -> void:
	for s in suivis:
		var n: Node3D = s[0]
		if not is_instance_valid(n):
			continue
		var p := _pied(n)
		if p != Vector3.INF:
			s[2].append(p)
		var d: Vector3 = n.global_position - (s[3] as Vector3)
		d.y = 0.0
		if d.length() > 0.005:
			var avant := -n.global_transform.basis.z
			s[4] += 1 if avant.dot(d.normalized()) > 0.5 else 0
			s[5] += 1
		s[3] = n.global_position


func _bilan(nom: String) -> void:
	var animes := 0
	var marchent := 0
	var de_face := 0
	for s in suivis:
		var n: Node3D = s[0]
		if not is_instance_valid(n):
			continue
		var depl: float = (n.global_position - (s[1] as Vector3)).length()
		if depl < 0.5 or s[5] < 20:
			continue      # a peine bouge pendant la mesure (dernier rang du cortege encore au depart...)
		marchent += 1
		var pts: Array = s[2]
		var amp := 0.0
		for p in pts:
			amp = maxf(amp, (p as Vector3).distance_to(pts[0]))
		if amp > 0.12:
			animes += 1
		if s[5] > 0 and float(s[4]) / s[5] > 0.8:
			de_face += 1
		print("  %s : %.1f m parcourus, pied %.2f m d'amplitude, de face %d / %d" % [n.name, depl, amp, s[4], s[5]])
		if amp <= 0.12:
			var t: AnimationTree = n.get("_tree")
			print("    diag : physique %s, visible %s, vitesse %s, au sol %s, lod %s, clips %s, arbre %s, clip actif %s, assis %s" % [n.is_physics_processing(), n.is_visible_in_tree(), n.get("speed"), n.get("on_floor"), n.call("_lod_every"), n.get("loco_clips"), t.active if t else "aucun", n.get("_clip_actif"), n.get("seated")])
	_check(marchent >= 1, "%s : des marcheurs en mouvement (%d)" % [nom, marchent])
	_check(animes == marchent, "%s : les jambes bougent en marchant (%d / %d)" % [nom, animes, marchent])
	_check(de_face == marchent, "%s : ils avancent dans le sens ou ils regardent (%d / %d)" % [nom, de_face, marchent])


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 60 or not scene.get_node("Props").get("placed"):
		return frame > 6000 and _fin()
	var peds := scene.get_node("Pietons")
	var player := scene.get_node("Player") as Node3D
	if frame == 60 + 1 or (frame > 60 and frame < 100000 and suivis.is_empty() and frame % 60 == 0):
		# le joueur (et sa camera) va au milieu des marcheurs du premier pieton ; on suit ceux qui sont visibles a
		# moins de 25 m de la camera (plus loin : caches et non animes, c'est voulu)
		var ws: Array = peds.get("_walkers")
		if frame == 61:
			player.global_position = (ws[0]["node"] as Node3D).global_position + Vector3(2, 0.3, 2)
			return false
		var cam := root.get_viewport().get_camera_3d()
		var proches: Array = []
		for w in ws:
			var n: Node3D = w["node"]
			if n.visible and n.global_position.distance_to(cam.global_position) < 25.0:
				proches.append(n)
		if proches.size() >= 1 or frame > 1200:
			_suivre(proches.slice(0, 6))
			frame = 100000
		return false
	if frame < 100000 + IMAGES:
		_mesurer()
		return false
	if frame == 100000 + IMAGES:
		_bilan("pietons")
		var ev := scene.get_node_or_null("Evenements")
		if ev == null:
			return _fin()
		ev.call("lancer")
		var cortege: Dictionary = ev.get("cortege")
		if cortege.is_empty():
			_check(false, "cortege lance")
			return _fin()
		player.global_position = (cortege["membres"][0] as Node3D).global_position + Vector3(3, 0.3, 0)
		_suivre(cortege["membres"])
		return false
	if frame < 100000 + IMAGES * 3:
		_mesurer()
		return false
	_bilan("cortege")
	return _fin()


func _fin() -> bool:
	print("RESULTAT test_pietons_anim : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
