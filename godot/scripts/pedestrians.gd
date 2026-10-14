extends Node3D
## Pietons et vendeurs :
## - pietons anims (character_anim.gd) qui marchent sur le bas-cote droit des rues, tenues variees,
##   certains portent une bassine sur la tete ; ils s'arretent si le joueur est juste devant eux ;
## - vendeurs / clients assis aux etals, kpayos et maquis (poses fixes fusionnees, MultiMesh : tres leger).
## Les pietons lointains sont caches et ne sont plus animes (performances).

@export var data_path := "res://assets/data/zone_aeroport.json"
@export var walker_count := 36
@export var props_path: NodePath = ^"../Props"
@export var player_path: NodePath = ^"../Player"
@export var seed_value := 4242
@export var lod_distance := 140.0

const ANIM := preload("res://scripts/character_anim.gd")

var _rng := RandomNumberGenerator.new()
var _roads: Array = []
var _grid := {}
var _walkers: Array = []
var _player: Node3D
var _lod_timer := 0.0
var _tick := 0


func _ready() -> void:
	_rng.seed = seed_value
	_player = get_node_or_null(player_path)
	_load_roads()
	for i in walker_count:
		_spawn_walker()
	var props = get_node_or_null(props_path)
	if props:
		if not props.placed:
			await props.placement_done
		_seat_vendors(props.vendor_spots)
	print("Pietons : %d marcheurs, %d assis" % [_walkers.size(), props.vendor_spots.size() if props else 0])


func _load_roads() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	for r in data["roads"]:
		if r["kind"] in ["steps"]:
			continue
		var pts := PackedVector2Array()
		for p in r["pts"]:
			pts.append(Vector2(float(p[0]), float(p[1])))
		if pts.size() < 2:
			continue
		var idx := _roads.size()
		_roads.append({"pts": pts, "width": float(r["width"]), "path": r["kind"] in ["footway", "path", "pedestrian"]})
		for i in pts.size():
			var c := Vector2i(floori(pts[i].x / 10.0), floori(pts[i].y / 10.0))
			if not _grid.has(c):
				_grid[c] = []
			_grid[c].append([idx, i])


# ------------------------------------------------------------ marcheurs
func _spawn_walker() -> void:
	var ch := load(PnjUtil.CHAR_SCENE).instantiate() as Node3D
	ch.set_script(ANIM)
	add_child(ch)
	PnjUtil.random_outfit(ch, _rng)
	if _rng.randf() < 0.3:
		_head_basin(ch)
	var w := {"node": ch, "speed": _rng.randf_range(1.1, 1.6), "side": 1.0 if _rng.randf() < 0.8 else -1.0,
		"pause": 0.0}
	_place(w)
	ch.global_position = w["pos"]
	_walkers.append(w)


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


func _place(w: Dictionary) -> void:
	for attempt in 30:
		var ri := _rng.randi() % _roads.size()
		var pts: PackedVector2Array = _roads[ri]["pts"]
		var i := _rng.randi() % (pts.size() - 1)
		var dir := 1 if _rng.randf() < 0.5 else -1
		if dir == -1:
			i += 1
		var p := pts[i]
		if _player and p.distance_to(Vector2(_player.global_position.x, _player.global_position.z)) < 20.0 and attempt < 25:
			continue
		w["road"] = ri
		w["i"] = i
		w["dir"] = dir
		w["s"] = _rng.randf_range(0.0, 3.0)
		w["pos"] = Vector3(p.x, 0.15, p.y)
		w["yaw"] = 0.0
		return


func _near_points(p: Vector2, radius: float) -> Array:
	var out := []
	var c := Vector2i(floori(p.x / 10.0), floori(p.y / 10.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for e in _grid.get(c + Vector2i(dx, dz), []):
				if (_roads[e[0]]["pts"] as PackedVector2Array)[e[1]].distance_to(p) <= radius:
					out.append(e)
	return out


func _next_road(w: Dictionary) -> void:
	var pts: PackedVector2Array = _roads[w["road"]]["pts"]
	var end_p := pts[w["i"]]
	var cands := []
	for e in _near_points(end_p, 9.0):
		if e[0] == w["road"]:
			continue
		var rp: PackedVector2Array = _roads[e[0]]["pts"]
		if e[1] < rp.size() - 1:
			cands.append([e[0], e[1], 1])
		if e[1] > 0:
			cands.append([e[0], e[1], -1])
	if cands.is_empty() or _rng.randf() < 0.1:
		w["dir"] = -w["dir"]  # demi-tour
		w["pause"] = _rng.randf_range(1.0, 4.0)
		return
	var c: Array = cands[_rng.randi() % cands.size()]
	w["road"] = c[0]
	w["i"] = c[1]
	w["dir"] = c[2]
	w["s"] = 0.0


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
	var road: Dictionary = _roads[w["road"]]
	var pts: PackedVector2Array = road["pts"]
	var a := pts[w["i"]]
	var b := pts[w["i"] + w["dir"]]
	var seg := b - a
	var L := seg.length()
	var fwd := seg / maxf(L, 0.01)
	var speed: float = w["speed"]
	if w["pause"] > 0.0:
		w["pause"] -= delta
		speed = 0.0
	# s'arreter si le joueur est juste devant
	var me: Vector3 = w["pos"]
	var dp := ppos - me
	if dp.length() < 1.6 and dp.dot(Vector3(fwd.x, 0, fwd.y)) > 0.0:
		speed = 0.0
	w["s"] += speed * delta
	var guard := 0
	while w["s"] >= L and guard < 6:
		guard += 1
		w["s"] -= L
		w["i"] += w["dir"]
		var nxt: int = w["i"] + w["dir"]
		if nxt < 0 or nxt >= pts.size():
			_next_road(w)
		road = _roads[w["road"]]
		pts = road["pts"]
		a = pts[w["i"]]
		b = pts[w["i"] + w["dir"]]
		seg = b - a
		L = maxf(seg.length(), 0.01)
		fwd = seg / L
	# bas-cote droit (ou au milieu d'un chemin pieton)
	var right := Vector2(-fwd.y, fwd.x)
	var off: float = 0.3 if road["path"] else road["width"] / 2.0 + 0.9
	var p2: Vector2 = a + fwd * w["s"] + right * off * w["side"]
	var target := Vector3(p2.x, 0.15, p2.y)
	w["pos"] = me.lerp(target, 1.0 - exp(-5.0 * delta))
	var yaw := atan2(-fwd.x, -fwd.y)
	w["yaw"] = lerp_angle(w["yaw"], yaw, 1.0 - exp(-6.0 * delta))
	var ch: Node3D = w["node"]
	ch.global_transform = Transform3D(Basis(Vector3.UP, w["yaw"]), w["pos"])
	ch.set("speed", speed)
	ch.set("on_floor", true)


# ------------------------------------------------------------ vendeurs assis
func _seat_vendors(spots: Array) -> void:
	if spots.is_empty():
		return
	# quelques tenues differentes, chacune fusionnee en un mesh fixe, puis repartie en MultiMesh
	var variants := 6
	var lists := []
	for v in variants:
		lists.append([])
	for t in spots:
		lists[_rng.randi() % variants].append(t)
	for v in variants:
		if lists[v].is_empty():
			continue
		var asm := Node3D.new()
		add_child(asm)
		var ch := load(PnjUtil.CHAR_SCENE).instantiate() as Node3D
		asm.add_child(ch)
		PnjUtil.random_outfit(ch, _rng)
		PnjUtil.pose_vendor(ch, _rng)
		ch.position = Vector3(0, -0.5, 0)  # bassin a ~0,45 m : assis sur un tabouret
		var mesh := PnjUtil.merge(asm)
		asm.queue_free()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = lists[v].size()
		for i in lists[v].size():
			mm.set_instance_transform(i, lists[v][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.visibility_range_end = 160.0
		add_child(mmi)
