extends Node3D
## Pietons et vendeurs :
## - pietons animes (character_anim.gd) sur les trottoirs / bas-cotes des rues (graphe des carrefours, voir
##   scripts/carte.gd), jamais au milieu de la chaussee : chaque pas est verifie sur le masque des chaussees ;
##   ils ne traversent qu'aux carrefours (ou pour changer de trottoir), droit et d'un pas plus vif, et les
##   vehicules s'arretent pour eux ; d'autres flanent sur la promenade du front de mer ;
## - tenues variees, certains portent une bassine sur la tete ; ils s'arretent si le joueur est juste devant ;
## - vendeurs / clients assis aux etals, kpayos et maquis (poses fixes fusionnees, MultiMesh : tres leger).
## Les pietons lointains sont caches et ne sont plus animes (performances).

@export var walker_count := 36
@export var promenade_share := 0.25
@export var props_path: NodePath = ^"../Props"
@export var player_path: NodePath = ^"../Player"
@export var seed_value := 4242
@export var lod_distance := 140.0

const ANIM := preload("res://scripts/character_anim.gd")
const GROUND_Y := 0.02
const CURB := 1.1          # distance du bord de chaussee au milieu du trottoir

var _rng := RandomNumberGenerator.new()
var _carte: Carte
var _promenade := PackedVector2Array()
var _walkers: Array = []
var _player: Node3D
var _lod_timer := 0.0
var _tick := 0


func _ready() -> void:
	_rng.seed = seed_value
	_player = get_node_or_null(player_path)
	_carte = Carte.zone()
	for p in _carte.data.get("promenade", []):
		_promenade.append(Vector2(float(p[0]), float(p[1])))
	for i in walker_count:
		_spawn_walker()
	var props = get_node_or_null(props_path)
	if props:
		if not props.placed:
			await props.placement_done
		_seat_vendors(props.vendor_spots)
	print("Pietons : %d marcheurs, %d assis" % [_walkers.size(), props.vendor_spots.size() if props else 0])


# ------------------------------------------------------------ marcheurs
func _spawn_walker() -> void:
	var genre := PnjUtil.random_genre(_rng)
	var ch := PnjUtil.make(genre)
	ch.set_script(ANIM)
	ch.set_meta("genre", genre)
	add_child(ch)
	PnjUtil.dress_random(ch, _rng)
	# a Cotonou, ce sont surtout les femmes qui portent la bassine sur la tete
	if _rng.randf() < (0.4 if genre == "femme" else 0.06):
		_head_basin(ch)
	PnjUtil.bake_groups(ch)
	var w := {"node": ch, "speed": _rng.randf_range(1.1, 1.6), "pause": 0.0, "cross": false,
		"jitter": _rng.randf_range(-0.3, 0.4), "yaw": 0.0,
		"prom": _promenade.size() > 2 and _rng.randf() < promenade_share}
	if w["prom"]:
		_place_promenade(w)
	else:
		_place(w)
	ch.global_position = w["pos"]
	_walkers.append(w)


func _set_edge(w: Dictionary, e: int, from: int, side: float) -> void:
	w["edge"] = e
	w["from"] = from
	w["to"] = _carte.other_end(e, from)
	w["pts"] = _carte.edge_pts_from(e, from)
	w["i"] = 0
	w["s"] = 0.0
	w["side"] = side
	w["off"] = _carte.edges[e]["width"] / 2.0 + CURB + w["jitter"]


func _walk_point(w: Dictionary, ahead := 0.0) -> Vector2:
	## Point du trottoir a la position courante (+ 'ahead' metres), du cote 'side' (1 = droite du sens de marche).
	var pts: PackedVector2Array = w["pts"]
	var i: int = w["i"]
	var s: float = w["s"] + ahead
	while i < pts.size() - 2 and s > pts[i].distance_to(pts[i + 1]):
		s -= pts[i].distance_to(pts[i + 1])
		i += 1
	var d := pts[i + 1] - pts[i]
	var f := d / maxf(d.length(), 0.01)
	return pts[i] + f * s + Vector2(-f.y, f.x) * w["off"] * w["side"]


func _edge_len(w: Dictionary) -> float:
	return _carte.edges[w["edge"]]["len"]


func _dist_done(w: Dictionary) -> float:
	var pts: PackedVector2Array = w["pts"]
	var done: float = w["s"]
	for j in w["i"]:
		done += pts[j].distance_to(pts[j + 1])
	return done


func _place(w: Dictionary) -> void:
	var ppos := Vector2(1e9, 1e9)
	if _player:
		ppos = Vector2(_player.global_position.x, _player.global_position.z)
	for attempt in 80:
		var e := _rng.randi() % _carte.edges.size()
		var ed: Dictionary = _carte.edges[e]
		_set_edge(w, e, ed["a"] if _rng.randf() < 0.5 else ed["b"], 1.0 if _rng.randf() < 0.5 else -1.0)
		var pts: PackedVector2Array = w["pts"]
		w["i"] = _rng.randi() % (pts.size() - 1)
		w["s"] = _rng.randf_range(0.0, pts[w["i"]].distance_to(pts[w["i"] + 1]))
		var p := _walk_point(w)
		if not _carte.walkable(p):
			continue
		if p.distance_to(ppos) < 20.0 and attempt < 70:
			continue
		w["pos"] = Vector3(p.x, GROUND_Y, p.y)
		return
	w["pos"] = Vector3(0, GROUND_Y, 0)


func _place_promenade(w: Dictionary) -> void:
	var total := 0.0
	for i in _promenade.size() - 1:
		total += _promenade[i].distance_to(_promenade[i + 1])
	# seulement la partie de la promenade dans la zone de jeu
	for attempt in 40:
		w["t"] = _rng.randf_range(0.0, total)
		w["dir"] = 1.0 if _rng.randf() < 0.5 else -1.0
		w["lat"] = _rng.randf_range(-3.0, 3.0)
		w["total"] = total
		var p := _prom_point(w)
		if _carte.in_bounds(p):
			w["pos"] = Vector3(p.x, GROUND_Y, p.y)
			return
	w["prom"] = false
	_place(w)


func _prom_point(w: Dictionary) -> Vector2:
	var t: float = w["t"]
	for i in _promenade.size() - 1:
		var L := _promenade[i].distance_to(_promenade[i + 1])
		if t <= L or i == _promenade.size() - 2:
			var f := (_promenade[i + 1] - _promenade[i]) / maxf(L, 0.01)
			return _promenade[i] + f * minf(t, L) + Vector2(-f.y, f.x) * w["lat"]
		t -= L
	return _promenade[0]


func _junction(w: Dictionary, here: Vector2) -> void:
	## Arrive au carrefour : choisir une rue (plutot tout droit), puis traverser jusqu'au premier point de
	## trottoir libre de cette rue. Impasse : demi-tour sur le meme trottoir.
	var n: int = w["to"]
	var pts: PackedVector2Array = w["pts"]
	var in_dir := (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	var options: Array = []
	for e in _carte.node_edges[n]:
		if e == w["edge"]:
			continue
		var p2 := _carte.edge_pts_from(e, n)
		var straight := in_dir.dot((p2[1] - p2[0]).normalized())
		for k in int(1 + 3 * maxf(straight, 0.0)):
			options.append(e)
	options.shuffle()
	for e in options:
		var side: float = w["side"]
		var saved := w.duplicate()
		_set_edge(w, e, n, side)
		var L := _edge_len(w)
		var s := 0.0
		while s < minf(L, 22.0):
			for off in _offsets(w):
				w["off"] = off
				var p := _walk_point(w, s)
				if _carte.walkable(p) and _carte.walkable(_walk_point(w, s + 2.0)) and p.distance_to(here) < 24.0:
					_advance_to(w, s)
					_start_cross(w, here, p)
					return
			s += 1.0
		# rien de libre de ce cote : on remet l'etat et on essaie la rue suivante
		for key in saved:
			w[key] = saved[key]
	_turn_back(w)


func _advance_to(w: Dictionary, dist: float) -> void:
	w["i"] = 0
	w["s"] = dist
	var pts: PackedVector2Array = w["pts"]
	while w["i"] < pts.size() - 2 and w["s"] > pts[w["i"]].distance_to(pts[w["i"] + 1]):
		w["s"] -= pts[w["i"]].distance_to(pts[w["i"] + 1])
		w["i"] += 1


func _turn_back(w: Dictionary) -> void:
	## Demi-tour en restant sur le meme trottoir.
	var done := _dist_done(w)
	var L := _edge_len(w)
	_set_edge(w, w["edge"], w["to"], -w["side"])
	_advance_to(w, clampf(L - done, 0.0, L))
	w["pause"] = _rng.randf_range(0.5, 2.5)


func _start_cross(w: Dictionary, from: Vector2, to: Vector2) -> void:
	if from.distance_to(to) < 1.2:
		return
	w["cross"] = true
	w["cross_to"] = to
	(w["node"] as Node).add_to_group("obstacles_route")


func _physics_process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var cpos := cam.global_position if cam else Vector3.ZERO
	var ppos := _player.global_position if _player else Vector3(1e9, 0, 1e9)
	_lod_timer -= delta
	var do_lod := _lod_timer <= 0.0
	if do_lod:
		_lod_timer = 0.5
	_tick += 1
	for k in _walkers.size():
		var w: Dictionary = _walkers[k]
		var ch: Node3D = w["node"]
		if do_lod:
			var far: bool = (w["pos"] as Vector3).distance_to(cpos) > lod_distance
			ch.visible = not far
			ch.set_physics_process(not far)
			w["far"] = far
		# les pietons lointains (invisibles) ne sont mis a jour qu'une image sur 4
		if w.get("far", false):
			if (_tick + k) % 4 == 0:
				_walk(w, delta * 4.0, ppos)
		else:
			_walk(w, delta, ppos)


func _walk(w: Dictionary, delta: float, ppos: Vector3) -> void:
	var speed: float = w["speed"]
	if w["pause"] > 0.0:
		w["pause"] -= delta
		speed = 0.0
	var me: Vector3 = w["pos"]
	var me2 := Vector2(me.x, me.z)
	var dp := ppos - me
	var heading := Vector3(-sin(w["yaw"]), 0, -cos(w["yaw"]))
	if dp.length() < 1.6 and dp.dot(heading) > 0.0:
		speed = 0.0  # le joueur est juste devant
	var target := me2
	var face := Vector2.ZERO
	if w["prom"]:
		w["t"] += speed * delta * w["dir"]
		if w["t"] < 0.0 or w["t"] > w["total"] or not _carte.in_bounds(_prom_point(w)):
			w["dir"] = -w["dir"]
			w["t"] = clampf(w["t"], 0.0, w["total"])
			w["pause"] = _rng.randf_range(2.0, 8.0)  # regarde la mer un moment
		target = _prom_point(w)
		me2 = me2.lerp(target, 1.0 - exp(-4.0 * delta))
		face = target - Vector2(me.x, me.z)
	elif w["cross"]:
		# traversee : droit vers le trottoir d'en face, d'un pas plus vif
		var to: Vector2 = w["cross_to"]
		var d := to - me2
		var step := speed * 1.3 * delta
		face = d
		if d.length() <= step:
			me2 = to
			w["cross"] = false
			(w["node"] as Node).remove_from_group("obstacles_route")
		else:
			me2 += d.normalized() * step
	else:
		w["s"] += speed * delta
		var pts: PackedVector2Array = w["pts"]
		var guard := 0
		while guard < 6 and w["s"] >= pts[w["i"]].distance_to(pts[w["i"] + 1]):
			guard += 1
			if w["i"] >= pts.size() - 2:
				_junction(w, me2)
				break
			w["s"] -= pts[w["i"]].distance_to(pts[w["i"] + 1])
			w["i"] += 1
		if not w["cross"]:
			# le trottoir devant passe sur une chaussee (carrefour) ou dans un mur : on longe le bord de la rue
			# si c'est possible (pas de trottoir en dur a Cotonou), sinon on decide maintenant
			var ahead := _walk_point(w, 1.5)
			if not (_carte.walkable(ahead) and _carte.walkable(_walk_point(w))) and not _retarget_offset(w):
				var left := _edge_len(w) - _dist_done(w)
				if left < 30.0:
					_junction(w, me2)
				else:
					_switch_side_or_turn(w, me2)
			elif (_tick + int(w["jitter"] * 100.0)) % 40 == 0:
				_back_to_preferred(w)
			if not w["cross"]:
				target = _walk_point(w)
				if target.distance_to(me2) > 2.0:
					_start_cross(w, me2, target)
				else:
					var prev := me2
					me2 = me2.lerp(target, 1.0 - exp(-5.0 * delta))
					face = me2 - prev
	if face.length() > 0.001:
		w["yaw"] = lerp_angle(w["yaw"], atan2(-face.x, -face.y), 1.0 - exp(-6.0 * delta))
	w["pos"] = Vector3(me2.x, GROUND_Y, me2.y)
	var ch: Node3D = w["node"]
	ch.global_transform = Transform3D(Basis(Vector3.UP, w["yaw"]), w["pos"])
	ch.set("speed", speed * (1.3 if w["cross"] else 1.0))
	ch.set("on_floor", true)


func _offsets(w: Dictionary) -> Array:
	var base: float = _carte.edges[w["edge"]]["width"] / 2.0
	return [base + CURB + w["jitter"], base + 0.6, base + 1.7, base + 2.5, base + 3.3]


func _clear_ahead(w: Dictionary) -> bool:
	return _carte.walkable(_walk_point(w)) and _carte.walkable(_walk_point(w, 1.5)) and _carte.walkable(_walk_point(w, 4.0))


func _retarget_offset(w: Dictionary) -> bool:
	## Trouver une autre distance au bord de la rue ou le chemin est libre (on contourne la maison ou l'etal).
	var cur: float = w["off"]
	for off in _offsets(w):
		if absf(off - cur) < 0.05:
			continue
		w["off"] = off
		if _clear_ahead(w):
			return true
	w["off"] = cur
	return false


func _back_to_preferred(w: Dictionary) -> void:
	var cur: float = w["off"]
	var pref: float = _offsets(w)[0]
	if absf(cur - pref) < 0.05:
		return
	w["off"] = pref
	if not _clear_ahead(w):
		w["off"] = cur


func _switch_side_or_turn(w: Dictionary, here: Vector2) -> void:
	## Trottoir bloque (maison au bord de la rue, terre-plein) : passer en face si c'est libre, sinon demi-tour.
	var cur_off: float = w["off"]
	w["side"] = -w["side"]
	for off in _offsets(w):
		w["off"] = off
		var p := _walk_point(w, 2.0)
		if _carte.walkable(p) and _carte.walkable(_walk_point(w, 6.0)):
			_advance_to(w, _dist_done(w) + 2.0)
			_start_cross(w, here, p)
			return
	w["side"] = -w["side"]
	w["off"] = cur_off
	_turn_back(w)

func _head_basin(ch: Node3D) -> void:
	## Bassine en plastique portee sur la tete (marchandises : fruits, sachets d'eau, pain...).
	var head := ch.find_child("piv_tete", true, false) as Node3D
	if head == null:
		return
	var basin := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.2
	cm.height = 0.13
	var m := StandardMaterial3D.new()
	m.albedo_color = [Color(0.15, 0.35, 0.75), Color(0.75, 0.12, 0.1), Color(0.15, 0.55, 0.25), Color(0.9, 0.9, 0.88)][_rng.randi() % 4]
	m.roughness = 0.5
	cm.material = m
	basin.mesh = cm
	basin.position = Vector3(0, 0.36, 0)
	head.add_child(basin)
	var goods := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.22
	var gm := StandardMaterial3D.new()
	gm.albedo_color = [Color(0.95, 0.6, 0.1), Color(0.95, 0.85, 0.3), Color(0.8, 0.85, 0.9), Color(0.85, 0.3, 0.15)][_rng.randi() % 4]
	sm.material = gm
	goods.mesh = sm
	goods.position = Vector3(0, 0.44, 0)
	head.add_child(goods)
	# un bras leve pour tenir la bassine
	var arm := ch.find_child("piv_epaule_D", true, false) as Node3D
	if arm:
		arm.set_meta("tient_bassine", true)


# ------------------------------------------------------------ vendeurs assis
func _seat_vendors(spots: Array) -> void:
	if spots.is_empty():
		return
	# quelques tenues differentes, chacune fusionnee en un mesh fixe, puis repartie en MultiMesh
	# decoupes par quartiers de 64 m : la distance d'affichage se mesure depuis le centre de chaque groupe
	# (un groupe etale sur toute la carte disparaissait des qu'on s'eloignait du centre de la carte)
	var variants := 10
	var meshes := []
	for v in variants:
		var asm := Node3D.new()
		add_child(asm)
		# vendeuses surtout (marches et etals de Cotonou), quelques vendeurs
		var genre := PnjUtil.random_genre(_rng, 0.75)
		var ch := PnjUtil.make(genre)
		asm.add_child(ch)
		PnjUtil.dress_random(ch, _rng)
		ch.scale = Vector3.ONE
		PnjUtil.pose_vendor(ch, _rng)
		# bassin a ~0,45 m : assis sur un tabouret (la femme a le bassin un peu plus bas)
		ch.position = Vector3(0, -0.5 + (0.04 if genre == "femme" else 0.0), 0)
		meshes.append(PnjUtil.merge(asm))
		asm.queue_free()
	var groups := {}
	for t in spots:
		var o: Vector3 = (t as Transform3D).origin
		var key := "%d|%d|%d" % [_rng.randi() % variants, floori(o.x / 64.0), floori(o.z / 64.0)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(t)
	for key in groups:
		var list: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[int(String(key).get_slice("|", 0))]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 160.0
		mmi.visibility_range_end_margin = 20.0
		add_child(mmi)
