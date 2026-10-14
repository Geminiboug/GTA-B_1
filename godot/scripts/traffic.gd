extends Node3D
## Circulation : zems (conducteur en chemise jaune, parfois un passager) et voitures qui roulent sur le vrai
## reseau de rues (godot/assets/data/zone_aeroport.json).
## - conduite a droite, respect des sens uniques, choix aleatoire aux carrefours ;
## - ralentissent dans les virages, gardent leurs distances, s'arretent devant le joueur et klaxonnent ;
## - bruit de moteur (boucle synthetisee) dont la hauteur suit la vitesse, klaxons synthetises ;
## - corps physiques (on ne passe pas a travers), phares allumes la nuit.

@export var data_path := "res://assets/data/zone_aeroport.json"
@export var zem_count := 32
@export var car_count := 14
@export var player_path: NodePath = ^"../Player"
@export var seed_value := 77

const ZEM_SCENE := preload("res://assets/models/veh_zem.glb")
const PROPS_SCENE := preload("res://assets/models/props.glb")
const LAMP_MAT := preload("res://shaders/lampe_material.tres")
const CAR_COLORS := [Color(0.92, 0.92, 0.9), Color(0.92, 0.92, 0.9), Color(0.7, 0.71, 0.72), Color(0.08, 0.08, 0.09),
	Color(0.1, 0.18, 0.4), Color(0.55, 0.08, 0.06), Color(0.75, 0.68, 0.55)]

var _rng := RandomNumberGenerator.new()
var _roads: Array = []           # [{pts: PackedVector2Array, width, oneway, big}]
var _grid := {}                  # cellule 10 m -> [[route, index]]
var _agents: Array = []
var _player: Node3D
var _snd_moto: AudioStreamWAV
var _snd_car: AudioStreamWAV
var _horn_moto: AudioStreamWAV
var _horn_car: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value
	_player = get_node_or_null(player_path)
	_load_roads()
	_snd_moto = AudioSynth.moto_loop()
	_snd_car = AudioSynth.voiture_loop()
	_horn_moto = AudioSynth.klaxon(415.0, 520.0, 0.35)
	_horn_car = AudioSynth.klaxon(350.0, 440.0, 0.5)
	var meshes := _build_meshes()
	for i in zem_count:
		_spawn("zem_passager" if _rng.randf() < 0.35 else "zem", meshes)
	for i in car_count:
		_spawn("voiture", meshes)
	print("Circulation : %d zems, %d voitures, %d troncons" % [zem_count, car_count, _roads.size()])


# ------------------------------------------------------------ reseau
func _load_roads() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	for r in data["roads"]:
		if r["kind"] in ["footway", "path", "pedestrian", "steps"]:
			continue
		var pts := PackedVector2Array()
		for p in r["pts"]:
			pts.append(Vector2(float(p[0]), float(p[1])))
		if pts.size() < 2:
			continue
		var road := {"pts": pts, "width": float(r["width"]), "oneway": bool(r["oneway"]),
			"big": r["kind"] in ["primary", "secondary", "tertiary"], "kind": r["kind"]}
		var idx := _roads.size()
		_roads.append(road)
		for i in pts.size():
			var c := Vector2i(floori(pts[i].x / 10.0), floori(pts[i].y / 10.0))
			if not _grid.has(c):
				_grid[c] = []
			_grid[c].append([idx, i])


func _near_points(p: Vector2, radius: float) -> Array:
	var out := []
	var c := Vector2i(floori(p.x / 10.0), floori(p.y / 10.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for e in _grid.get(c + Vector2i(dx, dz), []):
				if (_roads[e[0]]["pts"] as PackedVector2Array)[e[1]].distance_to(p) <= radius:
					out.append(e)
	return out


# ------------------------------------------------------------ vehicules
func _build_meshes() -> Dictionary:
	var out := {}
	# zem + conducteur (+ passager), poses puis fusionnes en un seul mesh
	for variant in ["zem", "zem_passager"]:
		var asm := Node3D.new()
		add_child(asm)
		var z := ZEM_SCENE.instantiate()
		asm.add_child(z)
		_lamp_surfaces(z, "veh_phare")
		var driver := load(PnjUtil.CHAR_SCENE).instantiate() as Node3D
		asm.add_child(driver)
		PnjUtil.pose_seated(driver)
		PnjUtil.dress(driver, Color(0.95, 0.78, 0.1), Color(0.15, 0.18, 0.3), Color(0.33, 0.2, 0.13))
		driver.position = Vector3(0, -0.05, 0.12)
		if variant == "zem_passager":
			var pas := load(PnjUtil.CHAR_SCENE).instantiate() as Node3D
			asm.add_child(pas)
			PnjUtil.pose_seated(pas)
			PnjUtil.dress(pas, Color(0.1, 0.35, 0.75), Color(0.85, 0.15, 0.1), Color(0.4, 0.26, 0.17))
			pas.position = Vector3(0, -0.02, 0.48)
		out[variant] = PnjUtil.merge(asm)
		asm.queue_free()
	var props := PROPS_SCENE.instantiate()
	for mi in props.find_children("veh_*", "MeshInstance3D", true, false):
		out[String(mi.name)] = mi.mesh
	props.free()
	return out


func _lamp_surfaces(node: Node, mat_name: String) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m and m.resource_name == mat_name:
				mi.set_surface_override_material(s, LAMP_MAT)


func _spawn(kind: String, meshes: Dictionary) -> void:
	var a := {"kind": kind}
	var mi := MeshInstance3D.new()
	var body := AnimatableBody3D.new()
	body.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if kind == "voiture":
		var model := "veh_4x4" if _rng.randf() < 0.3 else "veh_berline"
		mi.mesh = meshes[model]
		var col: Color = CAR_COLORS[_rng.randi() % CAR_COLORS.size()]
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m and m.resource_name == "mat_carrosserie":
				var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_color = col
				mi.set_surface_override_material(s, d)
			elif m and m.resource_name == "mat_lampe":
				mi.set_surface_override_material(s, LAMP_MAT)
		box.size = Vector3(1.85, 1.5, 4.6)
		cs.position = Vector3(0, 0.8, 0)
		a["max_big"] = _rng.randf_range(11.0, 15.0)
		a["max_small"] = _rng.randf_range(6.0, 8.5)
		a["lane"] = 0.27
		a["length"] = 4.6
	else:
		mi.mesh = meshes[kind]
		box.size = Vector3(0.6, 1.5, 2.0)
		cs.position = Vector3(0, 0.75, 0)
		a["max_big"] = _rng.randf_range(10.0, 14.0)
		a["max_small"] = _rng.randf_range(6.0, 9.0)
		a["lane"] = 0.36  # les zems serrent le bord droit
		a["length"] = 2.0
	cs.shape = box
	body.add_child(cs)
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.add_child(mi)
	var snd := AudioStreamPlayer3D.new()
	snd.stream = _snd_car if kind == "voiture" else _snd_moto
	snd.unit_size = 4.0
	snd.max_distance = 70.0
	snd.volume_db = -8.0
	snd.autoplay = true
	body.add_child(snd)
	var horn := AudioStreamPlayer3D.new()
	horn.stream = _horn_car if kind == "voiture" else _horn_moto
	horn.unit_size = 8.0
	horn.max_distance = 120.0
	body.add_child(horn)
	a["body"] = body
	a["snd"] = snd
	a["horn"] = horn
	a["speed"] = 0.0
	a["stuck"] = 0.0
	a["honk_cd"] = 0.0
	_place_random(a)
	body.global_position = a["vis_pos"]
	_agents.append(a)


func _place_random(a: Dictionary) -> void:
	for attempt in 30:
		var ri := _rng.randi() % _roads.size()
		var road: Dictionary = _roads[ri]
		if a["kind"] == "voiture" and road["kind"] == "track":
			continue
		var pts: PackedVector2Array = road["pts"]
		var i := _rng.randi() % (pts.size() - 1)
		var dir := 1 if road["oneway"] or _rng.randf() < 0.5 else -1
		if dir == -1:
			i += 1
		var p := pts[i]
		if _player and p.distance_to(Vector2(_player.global_position.x, _player.global_position.z)) < 35.0:
			continue
		_set_road(a, ri, i, dir)
		a["vis_pos"] = Vector3(p.x, 0.18, p.y)
		a["vis_yaw"] = 0.0
		return


func _set_road(a: Dictionary, ri: int, i: int, dir: int) -> void:
	a["road"] = ri
	a["i"] = i
	a["dir"] = dir
	a["s"] = 0.0


func _seg(a: Dictionary) -> Array:
	var pts: PackedVector2Array = _roads[a["road"]]["pts"]
	return [pts[a["i"]], pts[a["i"] + a["dir"]]]


func _next_road(a: Dictionary) -> void:
	## Au bout du troncon : prendre une rue qui part d'ici (pas demi-tour sauf impasse).
	var pts: PackedVector2Array = _roads[a["road"]]["pts"]
	var end_p := pts[a["i"]]
	var cands := []
	for e in _near_points(end_p, 9.0):
		if e[0] == a["road"]:
			continue
		var road: Dictionary = _roads[e[0]]
		var rp: PackedVector2Array = road["pts"]
		if a["kind"] == "voiture" and road["kind"] == "track":
			continue
		if e[1] < rp.size() - 1:
			cands.append([e[0], e[1], 1])
		if e[1] > 0 and not road["oneway"]:
			cands.append([e[0], e[1], -1])
	if cands.is_empty():
		if _roads[a["road"]]["oneway"]:
			_place_random(a)
		else:
			_set_road(a, a["road"], a["i"], -a["dir"])  # impasse : demi-tour
		return
	var c: Array = cands[_rng.randi() % cands.size()]
	_set_road(a, c[0], c[1], c[2])


# ------------------------------------------------------------ simulation
func _physics_process(delta: float) -> void:
	var ppos := Vector3(1e9, 0, 1e9)
	if _player:
		var pv = _player.get("vehicle")
		ppos = (pv as Node3D).global_position if pv else _player.global_position
	for a in _agents:
		_drive(a, delta, ppos)


func _drive(a: Dictionary, delta: float, ppos: Vector3) -> void:
	var road: Dictionary = _roads[a["road"]]
	var seg := _seg(a)
	var seg_v: Vector2 = seg[1] - seg[0]
	var seg_len := seg_v.length()
	if seg_len < 0.05:
		_advance(a, seg_len + 1.0)
		return
	var fwd2 := seg_v / seg_len
	var vmax: float = a["max_big"] if road["big"] else a["max_small"]
	# ralentir avant un virage serre
	var pts: PackedVector2Array = road["pts"]
	var ni: int = a["i"] + 2 * a["dir"]
	if ni >= 0 and ni < pts.size() and seg_len - a["s"] < 12.0:
		var nxt: Vector2 = (pts[ni] - (seg[1] as Vector2)).normalized()
		var turn := 1.0 - maxf(fwd2.dot(nxt), 0.0)
		vmax *= 1.0 - 0.6 * clamp(turn * 2.0, 0.0, 1.0)
	# obstacles devant : autres vehicules, joueur
	var me: Vector3 = a["vis_pos"]
	var fwd3 := Vector3(fwd2.x, 0, fwd2.y)
	var brake := false
	var blocked_by_player := false
	for b in _agents:
		if b == a:
			continue
		var d: Vector3 = b["vis_pos"] - me
		var ahead := d.dot(fwd3)
		if ahead > 0.5 and ahead < 9.0 + a["speed"] * 0.6 and abs(d.dot(Vector3(-fwd3.z, 0, fwd3.x))) < 1.8:
			vmax = min(vmax, b["speed"] * 0.9 if ahead > 5.0 else 0.0)
			brake = true
	var dp := ppos - me
	var pa := dp.dot(fwd3)
	var block_range := 13.0 if a["speed"] < 1.0 else 10.0  # marge : une fois arrete, il ne repart pas au moindre ecart
	if pa > 0.0 and pa < block_range and abs(dp.dot(Vector3(-fwd3.z, 0, fwd3.x))) < 2.2:
		vmax = 0.0
		blocked_by_player = true
	# acceleration / freinage
	var acc := 3.5 if vmax > a["speed"] else 8.0
	a["speed"] = move_toward(a["speed"], vmax, acc * delta)
	_advance(a, a["speed"] * delta)
	# klaxon si bloque par le joueur (ou bouchon qui dure)
	a["honk_cd"] = max(0.0, a["honk_cd"] - delta)
	if a["speed"] < 0.5 and (blocked_by_player or brake):
		a["stuck"] += delta
	else:
		a["stuck"] = 0.0
	if a["stuck"] > (0.7 if blocked_by_player else 6.0) and a["honk_cd"] <= 0.0:
		(a["horn"] as AudioStreamPlayer3D).play()
		a["honk_cd"] = _rng.randf_range(2.0, 4.0)
	# coince trop longtemps (embouteillage sans fin) : il repart ailleurs loin du joueur
	if a["stuck"] > 25.0 and not blocked_by_player:
		_place_random(a)
		a["stuck"] = 0.0
	# position visuelle : voie de droite, lissage pour adoucir les changements de troncon
	seg = _seg(a)
	seg_v = seg[1] - seg[0]
	seg_len = maxf(seg_v.length(), 0.01)
	fwd2 = seg_v / seg_len
	var right := Vector2(-fwd2.y, fwd2.x)
	var lane: float = 0.0 if road["oneway"] else road["width"] * a["lane"]
	var target2: Vector2 = seg[0] + fwd2 * a["s"] + right * lane
	var target := Vector3(target2.x, 0.18, target2.y)
	var k := 1.0 - exp(-6.0 * delta)
	a["vis_pos"] = (a["vis_pos"] as Vector3).lerp(target, k)
	var yaw := atan2(-fwd2.x, -fwd2.y)
	a["vis_yaw"] = lerp_angle(a["vis_yaw"], yaw, 1.0 - exp(-5.0 * delta))
	var lean := 0.0
	if a["kind"] != "voiture":
		lean = clamp(angle_difference(yaw, a["vis_yaw"]) * a["speed"] * 0.08, -0.4, 0.4)
	var body: AnimatableBody3D = a["body"]
	body.global_transform = Transform3D(Basis(Vector3.UP, a["vis_yaw"]) * Basis(Vector3(0, 0, 1), lean), a["vis_pos"])
	var snd: AudioStreamPlayer3D = a["snd"]
	snd.pitch_scale = 0.7 + a["speed"] / 12.0


func _advance(a: Dictionary, dist: float) -> void:
	a["s"] += dist
	var guard := 0
	while guard < 8:
		guard += 1
		var seg := _seg(a)
		var L: float = (seg[1] as Vector2).distance_to(seg[0])
		if a["s"] < L:
			return
		a["s"] -= L
		var pts: PackedVector2Array = _roads[a["road"]]["pts"]
		a["i"] += a["dir"]
		var last: int = a["i"] + a["dir"]
		if last < 0 or last >= pts.size():
			_next_road(a)
