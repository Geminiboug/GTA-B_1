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
@export var chase_owner_time := 25.0   # s pendant lesquelles un conducteur vole poursuit le joueur
@export var owner_punch_push := 4.0    # m/s : coup du proprietaire sur le joueur a pied

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
	var traffic := get_node_or_null("../Circulation")
	if traffic and traffic.has_signal("driver_ejected"):
		traffic.driver_ejected.connect(_on_driver_ejected)
	var props = get_node_or_null(props_path)
	if props:
		if not props.placed:
			await props.placement_done
		_seat_vendors(props.vendor_spots)
	print("Pietons : %d marcheurs, %d assis" % [_walkers.size(), props.vendor_spots.size() if props else 0])


# ------------------------------------------------------------ marcheurs
func _spawn_walker() -> void:
	_new_walker(PnjUtil.random_genre(_rng))


func _new_walker(genre: String, at := Vector2.INF, variant := "", look := {}) -> Dictionary:
	# quelques enfants (souvent en uniforme d'ecole), sinon des adultes de morphologies variees
	var ch := PnjUtil.make(variant if variant != "" else PnjUtil.random_variant(_rng, genre, 0.12 if at == Vector2.INF else 0.0))
	var metas := {"genre": ch.get_meta("genre"), "age": ch.get_meta("age"), "variante": ch.get_meta("variante")}
	ch.set_script(ANIM)
	for m in metas:
		ch.set_meta(m, metas[m])
	add_child(ch)
	if look.is_empty():
		PnjUtil.dress_random(ch, _rng)
	else:
		PnjUtil.apply(ch, look)   # meme tenue que sur le vehicule (zem ejecte)
		ch.set_meta("look", look)
	var basin: Node3D = null
	# a Cotonou, ce sont surtout les femmes qui portent la bassine sur la tete
	if at == Vector2.INF and _rng.randf() < (0.4 if genre == "femme" else 0.06):
		basin = _head_basin(ch)
	elif at == Vector2.INF and _rng.randf() < 0.3:
		_hand_item(ch, "sac" if _rng.randf() < 0.7 else "telephone")
	PnjUtil.bake_groups(ch)
	_add_body(ch)
	var kid: bool = ch.get_meta("age") == "enfant"
	var w := {"node": ch, "speed": _rng.randf_range(1.2, 1.8) if kid else _rng.randf_range(1.1, 1.6), "pause": 0.0, "cross": false,
		"jitter": _rng.randf_range(-0.3, 0.4), "yaw": 0.0, "state": "walk", "state_t": 0.0,
		"talk_cd": _rng.randf_range(0.0, 8.0), "prom": at == Vector2.INF and _promenade.size() > 2 and _rng.randf() < promenade_share}
	if basin:
		w["basin_node"] = basin
		ch.set("carry_head", true)             # buste droit, main qui stabilise la charge
		w["speed"] *= 0.9
	if ch.get_meta("vieux", false):
		w["speed"] *= 0.75                      # personne agee : pas plus lent et dos voute
		ch.set("posture", 0.16)
	w["rain_shy"] = _rng.randf() < 0.7          # se protege de la pluie
	if at != Vector2.INF:
		w["pos"] = Vector3(at.x, GROUND_Y, at.y)
		_resnap(w)
		w["pos"] = Vector3(at.x, GROUND_Y, at.y)
	elif w["prom"]:
		_place_promenade(w)
	else:
		_place(w)
	ch.global_position = w["pos"]
	_walkers.append(w)
	return w


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
	_greet_cd = maxf(0.0, _greet_cd - delta)
	_incident_cd = maxf(0.0, _incident_cd - delta)
	for key in _vendor_cd.keys():
		_vendor_cd[key] -= delta
	var pv: Node3D = _player.get("vehicle") if _player else null
	if pv and absf(float(pv.get("speed"))) < 0.5:
		pv = null
	if _tick % 10 == 0:
		_vendor_calls(ppos, pv)
	for k in _walkers.size():
		var w: Dictionary = _walkers[k]
		var ch: Node3D = w["node"]
		if do_lod:
			var far: bool = (w["pos"] as Vector3).distance_to(cpos) > lod_distance
			ch.visible = not far
			ch.set_physics_process(not far)
			w["far"] = far
		# les pietons lointains (invisibles) ne sont mis a jour qu'une image sur 4
		var dt := delta
		if w.get("far", false):
			if (_tick + k) % 4 != 0:
				continue
			dt = delta * 4.0
		if w["state"] == "walk":
			_walk(w, dt, ppos)
		else:
			_react(w, dt, ppos)
		_triggers(w, dt, ppos, pv)


var _meteo: Node = null


func _rain_now() -> float:
	if _meteo == null:
		_meteo = get_parent().get_node_or_null("Meteo")
	return float(_meteo.get("rain")) if _meteo and _meteo.get("rain") != null else 0.0


func _walk(w: Dictionary, delta: float, ppos: Vector3) -> void:
	var speed: float = w["speed"] * (1.25 if _rain_now() > 0.5 else 1.0)   # sous l'averse on presse le pas
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
	ch.set("rain_cover", 1.0 if w.get("rain_shy", false) and _rain_now() > 0.5 else 0.0)


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

func _head_basin(ch: Node3D) -> Node3D:
	## Bassine en plastique portee sur la tete (marchandises : fruits, sachets d'eau, pain...).
	var head0: Node3D = ch.find_child("piv_tete", true, false) as Node3D
	var skel := Squelette.find(ch)
	if skel:
		# corps a squelette : la bassine suit l'os de la tete
		var ba := BoneAttachment3D.new()
		ba.bone_name = Squelette.bone_name(skel, "piv_tete")
		skel.add_child(ba)
		head0 = ba
	if head0 == null:
		return null
	var head := Node3D.new()
	head.name = "Bassine"
	head0.add_child(head)
	# charge : bassine en plastique (55 %), plateau en aluminium avec pyramide (30 %), glaciere (15 %)
	var roll := _rng.randf()
	if roll < 0.55:
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
	elif roll < 0.85:
		# plateau rond en aluminium : oranges pelees ou pains en pyramide
		var tray := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.34
		tm.bottom_radius = 0.32
		tm.height = 0.03
		var am := StandardMaterial3D.new()
		am.albedo_color = Color(0.75, 0.76, 0.78)
		am.metallic = 0.8
		am.roughness = 0.35
		tm.material = am
		tray.mesh = tm
		tray.position = Vector3(0, 0.32, 0)
		head.add_child(tray)
		var bread := _rng.randf() < 0.4
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.82, 0.6, 0.3) if bread else Color(0.98, 0.72, 0.22)
		var unit: Mesh
		if bread:
			var cap := CapsuleMesh.new()
			cap.radius = 0.035
			cap.height = 0.28
			unit = cap
		else:
			var sp := SphereMesh.new()
			sp.radius = 0.04
			sp.height = 0.08
			unit = sp
		unit.surface_set_material(0, pm)
		var layer := 0
		for rr: float in [0.22, 0.13, 0.05]:
			var n := maxi(1, int(rr * 40.0))
			for i in n:
				var it := MeshInstance3D.new()
				it.mesh = unit
				var a := TAU * i / n
				it.position = Vector3(cos(a) * rr, 0.37 + layer * 0.065, sin(a) * rr)
				if bread:
					it.rotation = Vector3(PI / 2, a, 0)
				head.add_child(it)
			layer += 1
	else:
		# glaciere (sachets d'eau, boissons fraiches)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.46, 0.3, 0.32)
		var cm2 := StandardMaterial3D.new()
		cm2.albedo_color = [Color(0.92, 0.92, 0.9), Color(0.2, 0.45, 0.8), Color(0.85, 0.2, 0.15)][_rng.randi() % 3]
		cm2.roughness = 0.4
		bm.material = cm2
		box.mesh = bm
		box.position = Vector3(0, 0.46, 0)
		head.add_child(box)
	# un bras leve pour tenir la bassine
	var arm := ch.find_child("piv_epaule_D", true, false) as Node3D
	if arm:
		arm.set_meta("tient_bassine", true)
	return head


func _hand_item(ch: Node3D, what: String) -> void:
	## Objet tenu a la main droite : sac (plastique noir des courses ou sac a main) ou telephone.
	var skel := Squelette.find(ch)
	if skel == null:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = Squelette.bone_name(skel, "piv_main_D")
	skel.add_child(ba)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var m := StandardMaterial3D.new()
	if what == "sac":
		bm.size = Vector3(0.1, 0.28, 0.26)
		m.albedo_color = [Color(0.06, 0.06, 0.07), Color(0.06, 0.06, 0.07), Color(0.45, 0.25, 0.12), Color(0.75, 0.15, 0.2)][_rng.randi() % 4]
		m.roughness = 0.35
		mi.position = Vector3(0, -0.2, 0)
	else:
		bm.size = Vector3(0.012, 0.15, 0.075)
		m.albedo_color = Color(0.05, 0.05, 0.06)
		m.roughness = 0.2
		mi.position = Vector3(0, -0.06, 0.02)
	bm.material = m
	mi.mesh = bm
	ba.add_child(mi)


# ------------------------------------------------------------ vendeurs assis
func _seat_vendors(spots: Array) -> void:
	if spots.is_empty():
		return
	# quelques tenues differentes, chacune fusionnee en un mesh fixe, puis repartie en MultiMesh
	# decoupes par quartiers de 64 m : la distance d'affichage se mesure depuis le centre de chaque groupe
	# (un groupe etale sur toute la carte disparaissait des qu'on s'eloignait du centre de la carte)
	var variants := 10
	var meshes := []
	var assemblies := []
	for v in variants:
		var asm := Node3D.new()
		add_child(asm)
		# vendeuses surtout (marches et etals de Cotonou), quelques vendeurs
		var genre := PnjUtil.random_genre(_rng, 0.75)
		var ch := PnjUtil.make(PnjUtil.random_variant(_rng, genre))
		asm.add_child(ch)
		PnjUtil.dress_random(ch, _rng)
		ch.scale = Vector3.ONE
		PnjUtil.pose_vendor(ch, _rng)
		# assis sur un tabouret de ~0,42 m : articulation de la hanche a ~0,5 m du sol, pieds au sol
		ch.position = Vector3(0, -0.38 + (0.04 if genre == "femme" else 0.0), 0)
		assemblies.append(asm)
	# la pose du squelette n'est appliquee au maillage qu'a l'image suivante
	await get_tree().process_frame
	await get_tree().process_frame
	for asm in assemblies:
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


# ------------------------------------------------------------ reactions (comme de vrais passants a Cotonou)
## Etats d'un pieton : walk (sa route), down (renverse / pousse : tombe, reste a terre, se releve),
## stagger (bouscule : recule d'un pas), angry (fait face au joueur, gesticule, l'engueule),
## chase (court apres le joueur, le bouscule s'il le rattrape), flee (s'enfuit en courant),
## gather (vient voir un accident et reste autour), resume (rejoint sa route).

const PNJ_LAYER := 1 << 4          # couche 5 : corps des pietons (le joueur les heurte, pas les vehicules)
const REACT_STATES := ["down", "stagger", "angry", "chase", "flee", "gather", "resume"]

var _greet_cd := 0.0
var _vendor_cd := {}
var _incident_cd := 0.0
var _hour_node: Node


func _player_genre() -> String:
	return _player.get("genre") if _player and _player.get("genre") != null else "homme"


func _hour() -> float:
	if _hour_node == null:
		_hour_node = get_node_or_null("../JourNuit")
	return float(_hour_node.get("hour")) if _hour_node and _hour_node.get("hour") != null else 12.0


func _add_body(ch: Node3D) -> void:
	var body := AnimatableBody3D.new()
	body.name = "Corps"
	body.sync_to_physics = false
	body.collision_layer = PNJ_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.24
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.82, 0)
	body.add_child(cs)
	ch.add_child(body)
	ch.add_to_group("pnj")


func _speak(w: Dictionary, cat: String, voice := false) -> void:
	var ch: Node3D = w["node"]
	if w.get("far", false) or not ch.visible:
		return
	Bulle.say(ch, Dialogues.pick(cat, _rng, _player_genre()), 2.8, 2.05 if w.get("state") != "down" else 0.7)
	w["talk_cd"] = 6.0
	if voice:
		var p: AudioStreamPlayer3D = w.get("voice")
		if p == null:
			p = AudioStreamPlayer3D.new()
			p.unit_size = 5.0
			p.max_distance = 45.0
			p.position = Vector3(0, 1.6, 0)
			ch.add_child(p)
			w["voice"] = p
		var femme: bool = ch.get_meta("genre", "homme") == "femme"
		p.stream = AudioSynth.cri(_rng.randf_range(210.0, 260.0) if femme else _rng.randf_range(115.0, 150.0), 0.35)
		p.play()


func _set_state(w: Dictionary, st: String, t := 0.0) -> void:
	w["state"] = st
	w["state_t"] = t
	if w["cross"]:
		w["cross"] = false
		(w["node"] as Node).remove_from_group("obstacles_route")


func _knock_down(w: Dictionary, push: Vector2, after: String) -> void:
	## Tombe dans la direction de la poussee, glisse un peu, reste a terre puis se releve et enchaine 'after'.
	_set_state(w, "down", 0.0)
	w["push"] = push
	w["after"] = after
	w["lie"] = _rng.randf_range(2.5, 5.0) if push.length() > 4.0 else _rng.randf_range(1.2, 2.2)
	# tombe sur le dos si on le pousse de face, sur le ventre si on le pousse de dos
	var fwd := Vector2(-sin(w["yaw"]), -cos(w["yaw"]))
	w["fall_sign"] = 1.0 if push.dot(fwd) < 0.0 else -1.0
	if w.get("basin_node"):
		_drop_basin(w)


func _drop_basin(w: Dictionary) -> void:
	## La bassine tombe et la marchandise s'eparpille par terre.
	var b: Node3D = w["basin_node"]
	w.erase("basin_node")
	var p: Vector3 = b.global_position
	var spill := Node3D.new()
	add_child(spill)
	spill.global_position = Vector3(p.x, GROUND_Y, p.z) + Vector3(_rng.randf_range(-0.6, 0.6), 0, _rng.randf_range(-0.6, 0.6))
	for c in b.get_children():
		if c is MeshInstance3D:
			var m := MeshInstance3D.new()
			m.mesh = (c as MeshInstance3D).mesh
			spill.add_child(m)
			m.position = Vector3(_rng.randf_range(-0.3, 0.3), 0.06, _rng.randf_range(-0.3, 0.3))
			m.rotation = Vector3(_rng.randf_range(1.2, 1.9), _rng.randf() * TAU, 0)
	b.queue_free()
	var tw := spill.create_tween()
	tw.tween_interval(60.0)
	tw.tween_callback(spill.queue_free)


func _react(w: Dictionary, delta: float, ppos: Vector3) -> void:
	var ch: Node3D = w["node"]
	var me: Vector3 = w["pos"]
	var me2 := Vector2(me.x, me.z)
	var p2 := Vector2(ppos.x, ppos.z)
	var st: String = w["state"]
	w["state_t"] += delta
	var t: float = w["state_t"]
	var speed := 0.0
	var face := Vector2.ZERO
	var tilt := 0.0
	match st:
		"down":
			var push: Vector2 = w["push"]
			if t < 0.45:
				tilt = smoothstep(0.0, 0.45, t)
				me2 += push * delta * (1.0 - t / 0.45)
			elif t < 0.45 + w["lie"]:
				tilt = 1.0
			elif t < 1.35 + w["lie"]:
				tilt = 1.0 - smoothstep(0.45 + w["lie"], 1.35 + w["lie"], t)
			else:
				var nxt: String = w["after"]
				_set_state(w, nxt)
				match nxt:
					"angry":
						_speak(w, w.get("line_after", "bouscule"), true)
					"chase":
						_speak(w, w.get("line_after", "frappe"), true)
					"flee":
						_speak(w, "fuite", true)
						w["flee_from"] = p2
		"stagger":
			var push: Vector2 = w["push"]
			me2 += push * delta * maxf(0.0, 1.0 - t / 0.5)
			face = -push
			if t > 0.7:
				_set_state(w, w.get("after", "walk") if w.get("after", "walk") != "walk" else "resume")
		"angry":
			face = p2 - me2
			ch.set("gesture", 1.0)
			if t > 1.2 and t < 1.3 and w["talk_cd"] <= 0.0:
				_speak(w, w.get("line_after", "bouscule"))
			if t > 4.5:
				ch.set("gesture", 0.0)
				_set_state(w, "resume")
		"chase":
			var target := p2
			var pv = _player.get("vehicle") if _player else null
			if pv:
				target = Vector2((pv as Node3D).global_position.x, (pv as Node3D).global_position.z)
			var d := target - me2
			face = d
			var owner: bool = w.get("carjacked", false) and w.get("driver", false)
			if owner and pv and not w.has("stolen"):
				w["stolen"] = pv
			var stolen: Node3D = w.get("stolen") if is_instance_valid(w.get("stolen")) else null
			if owner and stolen:
				# le proprietaire ne lache pas : il court au vehicule tant qu'il est a portee
				target = Vector2(stolen.global_position.x, stolen.global_position.z)
				d = target - me2
				face = d
				var vs := absf(float(stolen.get("speed")))
				if d.length() < 2.4 and vs < 2.0:
					_reclaim(w, stolen)
					return
				if t < chase_owner_time and d.length() < 70.0:
					speed = 5.2
					me2 = _step_towards(me2, d.normalized(), speed * delta)
				else:
					_set_state(w, "angry")
			elif owner and pv == null and p2.distance_to(me2) < 25.0 and t < chase_owner_time:
				# le joueur est a pied : il vient se battre
				d = p2 - me2
				face = d
				if d.length() > 1.1:
					speed = 5.0
					me2 = _step_towards(me2, d.normalized(), speed * delta)
				else:
					w["punch_cd"] = w.get("punch_cd", 0.0) - delta
					if w["punch_cd"] <= 0.0:
						w["punch_cd"] = _rng.randf_range(0.7, 1.1)
						ch.set("gesture", 1.0)
						if _player is CharacterBody3D:
							(_player as CharacterBody3D).velocity += Vector3(d.normalized().x, 0.0, d.normalized().y) * owner_punch_push
							if _player.has_method("shake"):
								_player.shake(0.4)
						_speak(w, "vole")
			elif d.length() > 1.3 and t < 8.0 and d.length() < 45.0:
				speed = 4.6
				me2 = _step_towards(me2, d.normalized(), speed * delta)
			else:
				if d.length() <= 1.3 and pv == null and _player is CharacterBody3D:
					# il rattrape le joueur : une bonne bousculade
					var pb := _player as CharacterBody3D
					pb.velocity += Vector3(d.normalized().x, 0.0, d.normalized().y) * 5.0
				w["line_after"] = "vole" if w.get("carjacked", false) else "frappe"
				_set_state(w, "angry")
		"flee":
			var from: Vector2 = w.get("flee_from", p2)
			var d := me2 - from
			if d.length() < 0.1:
				d = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
			speed = 4.4
			face = d
			me2 = _step_towards(me2, d.normalized(), speed * delta)
			if t > w.get("flee_time", 5.0):
				_set_state(w, "resume")
		"gather":
			var c: Vector2 = w["target"]
			var spot: Vector2 = c + w["ring"]
			var d := spot - me2
			if d.length() > 0.4:
				speed = 1.9 if t < 6.0 else 1.3
				me2 = _step_towards(me2, d.normalized(), minf(speed * delta, d.length()))
				face = d
			else:
				face = c - me2
				if t > 3.0 and w["talk_cd"] <= 0.0 and _rng.randf() < 0.01:
					_speak(w, "temoin_accident")
			if t > w.get("gather_time", 12.0):
				_set_state(w, "resume")
		"resume":
			_resnap(w)
			_set_state(w, "walk")
	if face.length() > 0.001:
		w["yaw"] = lerp_angle(w["yaw"], atan2(-face.x, -face.y), 1.0 - exp(-8.0 * delta))
	w["pos"] = Vector3(me2.x, GROUND_Y, me2.y)
	# couche par terre : rotation autour des pieds, releve un peu pour ne pas traverser le sol
	var fall: float = tilt * PI * 0.5 * w.get("fall_sign", 1.0)
	var basis := Basis(Vector3.UP, w["yaw"]) * Basis(Vector3.RIGHT, fall)
	ch.global_transform = Transform3D(basis, w["pos"] + Vector3(0, 0.13 * tilt, 0))
	ch.set("speed", speed)
	ch.set("on_floor", true)
	var on_road := _carte.on_carriageway(me2)
	if on_road and not ch.is_in_group("obstacles_route"):
		ch.add_to_group("obstacles_route")   # les vehicules s'arretent devant un pieton sur la chaussee
	elif not on_road and ch.is_in_group("obstacles_route"):
		ch.remove_from_group("obstacles_route")


func _step_towards(from: Vector2, dir: Vector2, dist: float) -> Vector2:
	## Avance sans traverser les maisons ni les murs (glisse le long, sinon tourne un peu).
	for ang in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6]:
		var q := from + dir.rotated(ang) * dist
		if not _carte.in_building(q) and _carte.in_bounds(q):
			return q
	return from


func _resnap(w: Dictionary) -> void:
	## Rejoint le trottoir de la rue la plus proche apres une reaction.
	var me: Vector3 = w["pos"]
	var p := Vector2(me.x, me.z)
	if w["prom"]:
		return
	var near := _carte.nearest_on_network(p)
	if near["edge"] < 0:
		return
	var e: int = near["edge"]
	var ed: Dictionary = _carte.edges[e]
	var pts: PackedVector2Array = ed["pts"]
	var from: int = ed["a"] if _rng.randf() < 0.5 else ed["b"]
	var along: float = near["along"] if from == ed["a"] else ed["len"] - near["along"]
	# de quel cote de la rue est-il ?
	var q: Vector2 = near["point"]
	var dir := Vector2.ZERO
	for i in pts.size() - 1:
		if Geometry2D.get_closest_point_to_segment(q, pts[i], pts[i + 1]).distance_to(q) < 0.05:
			dir = (pts[i + 1] - pts[i]).normalized()
			break
	if from != ed["a"]:
		dir = -dir
	var side := 1.0 if (p - q).dot(Vector2(-dir.y, dir.x)) >= 0.0 else -1.0
	_set_edge(w, e, from, side)
	_advance_to(w, clampf(along, 0.0, ed["len"]))
	if not _carte.walkable(_walk_point(w)):
		_retarget_offset(w)


# ------------------------------------------------------------ declencheurs
func _triggers(w: Dictionary, delta: float, ppos: Vector3, pv: Node3D) -> void:
	w["talk_cd"] = maxf(0.0, w.get("talk_cd", 0.0) - delta)
	if w.get("far", false):
		return
	var me: Vector3 = w["pos"]
	var me2 := Vector2(me.x, me.z)
	var st: String = w["state"]
	if pv:
		# vehicule du joueur : renverse si on est dans son emprise et qu'il roule, sinon on s'ecarte en criant
		var vs: float = absf(float(pv.get("speed")))
		var vx: Transform3D = pv.global_transform
		var rel := me - vx.origin
		var lx := absf(rel.dot(vx.basis.x))
		var lz := absf(rel.dot(vx.basis.z))
		var car: bool = pv.get("kind") != "zem"
		var hw := 1.05 if car else 0.45
		var hl := 2.5 if car else 1.05
		if st != "down" and vs > 2.5 and lx < hw + 0.25 and lz < hl + 0.25 and absf(rel.y) < 2.0:
			var fwd := -vx.basis.z * signf(float(pv.get("speed")))
			_knock_down(w, Vector2(fwd.x, fwd.z) * minf(vs * 0.6, 9.0) + Vector2(rel.x, rel.z).normalized() * 1.5,
				"angry" if vs < 9.0 else "angry")
			w["line_after"] = "renverse"
			_vehicle_hit(pv, vs)
			_incident(me2, "temoin_accident", 30.0)
		elif st == "walk" and vs > 8.0 and lx < hw + 2.0 and lz < hl + 2.0 and w["talk_cd"] <= 0.0:
			w["flee_from"] = Vector2(vx.origin.x, vx.origin.z)
			w["flee_time"] = 1.2
			_set_state(w, "flee")
			_speak(w, "frole", true)
		return
	# joueur a pied
	var d := Vector2(ppos.x - me.x, ppos.z - me.z)
	var dist := d.length()
	if dist > 6.0:
		return
	var pvel := Vector2.ZERO
	if _player is CharacterBody3D:
		pvel = Vector2((_player as CharacterBody3D).velocity.x, (_player as CharacterBody3D).velocity.z)
	if st == "walk" and dist < 0.8 and pvel.dot(-d.normalized()) > 1.2:
		# bousculade : le joueur lui rentre dedans
		var hard := pvel.length() > 5.0
		if hard and _rng.randf() < 0.45:
			_knock_down(w, pvel * 0.7, "angry")
			w["line_after"] = "bassine" if w.get("basin_node") else "bouscule"
		else:
			_set_state(w, "stagger")
			w["push"] = pvel.normalized() * 1.6
			w["after"] = "angry" if hard or _rng.randf() < 0.3 else "walk"
			w["line_after"] = "bouscule"
			if w["after"] == "walk":
				_speak(w, "bouscule")
	elif st == "walk" and dist < 3.0 and pvel.length() < 2.6 and w["talk_cd"] <= 0.0 and _greet_cd <= 0.0 and _rng.randf() < 0.012:
		# salutation (bonjour le matin, bonsoir des l'apres-midi) en tournant la tete vers le joueur
		Bulle.say(w["node"], Dialogues.greeting(_hour(), _rng, _player_genre()))
		w["talk_cd"] = 20.0
		_greet_cd = 3.0


func _vehicle_hit(v: Node3D, vs: float) -> void:
	## Le choc ralentit le vehicule du joueur et s'entend.
	if v.has_method("damage"):
		v.call("damage", minf(vs * 0.3, 6.0))
	if v.get("_vel") != null:
		v.set("_vel", (v.get("_vel") as Vector2) * 0.88)
	elif v.get("speed") != null:
		v.set("speed", float(v.get("speed")) * 0.8)
	var traffic := get_node_or_null("../Circulation")
	if traffic and traffic.has_method("alert"):
		traffic.alert(v.global_position, 30.0)


func _incident(at: Vector2, line: String, radius: float) -> void:
	## Accident ou bagarre : les passants proches accourent voir (attroupement, tres courant a Cotonou),
	## quelques-uns s'enfuient, d'autres crient.
	if _incident_cd > 0.0:
		return
	_incident_cd = 3.0
	var shouted := 0
	for w in _walkers:
		if w["state"] != "walk":
			continue
		var me: Vector3 = w["pos"]
		var d := Vector2(me.x, me.z).distance_to(at)
		if d > radius or d < 0.5:
			continue
		var r := _rng.randf()
		if r < 0.62:
			_set_state(w, "gather")
			w["target"] = at
			w["ring"] = Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.6, 4.5)
			w["gather_time"] = _rng.randf_range(10.0, 18.0)
			if shouted < 2 and _rng.randf() < 0.5:
				_speak(w, line, shouted == 0)
				shouted += 1
		elif r < 0.8:
			w["flee_from"] = at
			w["flee_time"] = _rng.randf_range(3.0, 5.0)
			_set_state(w, "flee")


func player_attack(origin: Vector3, dir: Vector3) -> bool:
	## Coup de poing / bousculade du joueur (touche F, clic gauche, manette B). Renvoie vrai si quelqu'un est touche.
	var best: Dictionary = {}
	var bd := 1.5
	for w in _walkers:
		if w["state"] == "down":
			continue
		var rel: Vector3 = w["pos"] - origin
		rel.y = 0.0
		var d := rel.length()
		if d < bd and rel.normalized().dot(dir) > 0.4:
			bd = d
			best = w
	if best.is_empty():
		return false
	var push := Vector2(dir.x, dir.z) * 3.5
	if _rng.randf() < 0.6:
		_knock_down(best, push, "chase" if _rng.randf() < 0.4 else "flee")
	else:
		_set_state(best, "stagger")
		best["push"] = push * 0.6
		best["after"] = "chase" if _rng.randf() < 0.5 else "angry"
	best["line_after"] = "frappe"
	_speak(best, "frappe", true)
	var me: Vector3 = best["pos"]
	_incident(Vector2(me.x, me.z), "temoin_bagarre", 22.0)
	return true


func _on_driver_ejected(pos: Vector3, yaw: float, genre: String, by: Node3D, rider := []) -> void:
	## Le conducteur (ou le passager) d'un vehicule pris par le joueur : tombe sur le cote, se releve,
	## crie au voleur et court apres le vehicule un moment.
	var w := _new_walker(genre, Vector2(pos.x, pos.z), rider[1] if rider.size() > 2 else "", rider[2] if rider.size() > 2 else {})
	w["driver"] = rider.size() < 4 or rider[3] == 0   # le conducteur vient reprendre son bien
	w["yaw"] = yaw + PI / 2.0
	w["carjacked"] = true
	_knock_down(w, Vector2(-cos(yaw), sin(yaw)) * 2.5, "chase")
	w["lie"] = 0.8
	w["line_after"] = "vole"
	_speak(w, "vole", true)
	_incident(Vector2(pos.x, pos.z), "temoin_accident", 18.0)


func _vendor_calls(ppos: Vector3, pv: Node3D) -> void:
	## Les vendeuses hèlent le joueur qui passe a pied (une fois de temps en temps).
	var props := get_node_or_null(props_path)
	if props == null or pv != null:
		return
	for i in props.vendor_spots.size():
		var t: Transform3D = props.vendor_spots[i]
		if t.origin.distance_to(ppos) < 6.0 and _vendor_cd.get(i, 0.0) <= 0.0 and _rng.randf() < 0.02:
			_vendor_cd[i] = 40.0
			var anchor := Node3D.new()
			add_child(anchor)
			anchor.global_position = t.origin
			Bulle.say(anchor, Dialogues.pick("vendeuse", _rng, _player_genre()), 3.0, 1.55)
			var tw := anchor.create_tween()
			tw.tween_interval(3.6)
			tw.tween_callback(anchor.queue_free)
			return


func _reclaim(w: Dictionary, v: Node3D) -> void:
	## Le proprietaire rattrape son vehicule arrete : il en sort le joueur, le bouscule et repart avec.
	if _player and _player.get("vehicle") == v:
		_player.exit_vehicle()
		var away: Vector3 = (_player.global_position - v.global_position) * Vector3(1, 0, 1)
		(_player as CharacterBody3D).velocity = away.normalized() * 5.0 + Vector3.UP * 2.0
		if _player.has_method("shake"):
			_player.shake(0.6)
	_speak(w, "vole", true)
	var traffic := get_parent().get_node_or_null("Circulation")
	if traffic and traffic.has_method("reclaim") and traffic.reclaim(v):
		# il est remonte sur son vehicule : le pieton disparait (il est dans le maillage du vehicule)
		# (le passager du zem aussi), retires apres la boucle de mise a jour
		var gone := [w]
		for o in _walkers:
			if o.get("carjacked", false) and not o.get("driver", false) and o["pos"].distance_to(w["pos"]) < 10.0:
				gone.append(o)
		(func() -> void:
			for o in gone:
				_walkers.erase(o)
				(o["node"] as Node).queue_free()
				_spawn_walker()).call_deferred()
	else:
		_set_state(w, "angry")
