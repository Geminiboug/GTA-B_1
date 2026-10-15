extends Node3D
## Circulation : zems (conducteur en chemise jaune, parfois un passager) et voitures qui roulent sur le vrai
## reseau de rues (graphe des carrefours OSM, scripts/carte.gd).
## - conduite a droite (voie de droite, ou l'une des deux voies d'un boulevard a sens unique), sens uniques ;
## - aux carrefours : ralentissent, tournent plutot tout droit, cedent le passage a celui qui est deja engage ;
## - gardent leurs distances, s'arretent devant le joueur et klaxonnent ;
## - bruit de moteur (boucle synthetisee) dont la hauteur suit la vitesse, klaxons synthetises ;
## - corps physiques (on ne passe pas a travers), phares allumes la nuit.

@export var zem_count := 32
@export var car_count := 14
@export var player_path: NodePath = ^"../Player"
@export var seed_value := 77

const ZEM_SCENE := preload("res://assets/models/veh_zem.glb")
const PROPS_SCENE := preload("res://assets/models/props.glb")
const LAMP_MAT := preload("res://shaders/lampe_material.tres")
const CAR_COLORS := [Color(0.92, 0.92, 0.9), Color(0.92, 0.92, 0.9), Color(0.7, 0.71, 0.72), Color(0.08, 0.08, 0.09),
	Color(0.1, 0.18, 0.4), Color(0.55, 0.08, 0.06), Color(0.75, 0.68, 0.55)]
const GROUND_Y := 0.02
const ZEM_VARIANTS := ["zem_a", "zem_b", "zem_c", "zem_passager_h", "zem_passager_f", "zem_passager_f2"]

var _rng := RandomNumberGenerator.new()
var _carte: Carte
var _agents: Array = []
var _player: Node3D
var _locks := {}              # noeud de carrefour -> id de l'agent engage
var _obstacles: Array = []    # vehicules gares ou abandonnes, pietons qui traversent

signal honked(body: Node3D, at_player: bool)
var _snd_moto: AudioStreamWAV
var _snd_car: AudioStreamWAV
var _horn_moto: AudioStreamWAV
var _horn_car: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value
	_player = get_node_or_null(player_path)
	_carte = Carte.zone()
	_snd_moto = AudioSynth.moto_loop()
	_snd_car = AudioSynth.voiture_loop()
	_horn_moto = AudioSynth.klaxon(415.0, 520.0, 0.35)
	_horn_car = AudioSynth.klaxon(350.0, 440.0, 0.5)
	var meshes := _build_meshes()
	for i in zem_count:
		_spawn("zem_passager" if _rng.randf() < 0.35 else "zem", meshes)
	for i in car_count:
		_spawn("voiture", meshes)
	print("Circulation : %d zems, %d voitures, %d troncons, %d carrefours" % [zem_count, car_count, _carte.edges.size(), _carte.nodes.size()])


# ------------------------------------------------------------ vehicules
func _build_meshes() -> Dictionary:
	var out := {}
	# zem + conducteur en chemise jaune (+ passager ou passagere), poses puis fusionnes en un seul mesh
	for variant in ZEM_VARIANTS:
		var asm := Node3D.new()
		add_child(asm)
		var z := ZEM_SCENE.instantiate()
		asm.add_child(z)
		_lamp_surfaces(z, "veh_phare")
		var driver := PnjUtil.make("homme")
		asm.add_child(driver)
		PnjUtil.dress_random(driver, _rng, "zem")
		driver.scale = Vector3.ONE
		PnjUtil.pose_seated(driver)
		driver.position = Vector3(0, -0.05, 0.12)
		if variant.begins_with("zem_passager"):
			var genre := "femme" if variant.contains("_f") else "homme"
			var pas := PnjUtil.make(genre)
			asm.add_child(pas)
			PnjUtil.dress_random(pas, _rng)
			pas.scale = Vector3.ONE
			PnjUtil.pose_seated(pas)
			pas.position = Vector3(0, -0.02 + (0.04 if genre == "femme" else 0.0), 0.48)
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
		var pool := ZEM_VARIANTS.filter(func(v: String) -> bool: return v.begins_with("zem_passager") == (kind == "zem_passager"))
		mi.mesh = meshes[pool[_rng.randi() % pool.size()]]
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
	a["id"] = _agents.size()
	a["lane_side"] = 1.0 if kind != "voiture" or _rng.randf() < 0.6 else -1.0
	a["vis_pos"] = Vector3(1e6, 0, 1e6)
	a["vis_yaw"] = 0.0
	_place_random(a)
	body.global_position = a["vis_pos"]
	_agents.append(a)


func _place_random(a: Dictionary) -> void:
	var ppos := Vector2(1e9, 1e9)
	if _player:
		ppos = Vector2(_player.global_position.x, _player.global_position.z)
	for attempt in 40:
		var e := _rng.randi() % _carte.edges.size()
		var ed: Dictionary = _carte.edges[e]
		if a["kind"] == "voiture" and ed["kind"] == "track":
			continue
		var from: int = ed["a"]
		if not ed["oneway"] and _rng.randf() < 0.5:
			from = ed["b"]
		var pts := _carte.edge_pts_from(e, from)
		var i := _rng.randi() % (pts.size() - 1)
		if pts[i].distance_to(ppos) < 35.0 and attempt < 35:
			continue
		var busy := false
		for b in _agents:
			if not is_same(b, a) and Vector2(b["vis_pos"].x, b["vis_pos"].z).distance_to(pts[i]) < 8.0:
				busy = true
				break
		if busy and attempt < 35:
			continue
		_set_edge(a, e, from)
		a["i"] = i
		var p := _lane_point(a)
		a["vis_pos"] = Vector3(p.x, GROUND_Y, p.y)
		var d := pts[i + 1] - pts[i]
		a["vis_yaw"] = atan2(-d.x, -d.y)
		return


func _set_edge(a: Dictionary, e: int, from: int) -> void:
	a["edge"] = e
	a["from"] = from
	a["to"] = _carte.other_end(e, from)
	a["pts"] = _carte.edge_pts_from(e, from)
	a["i"] = 0
	a["s"] = 0.0
	var ed: Dictionary = _carte.edges[e]
	var w: float = ed["width"]
	# voie : a droite sur une rue a double sens ; sur un boulevard a sens unique, une des deux voies
	if not ed["oneway"]:
		a["lane_off"] = w * a["lane"]
	elif w >= 6.5:
		a["lane_off"] = w * 0.25 * a["lane_side"]
	else:
		a["lane_off"] = w * 0.2 if a["kind"] != "voiture" else 0.0
	a["major"] = ed["major"]


func _lane_point(a: Dictionary) -> Vector2:
	var pts: PackedVector2Array = a["pts"]
	var i: int = a["i"]
	var d := pts[i + 1] - pts[i]
	var f := d / maxf(d.length(), 0.01)
	return pts[i] + f * a["s"] + Vector2(-f.y, f.x) * a["lane_off"]


func _remaining(a: Dictionary) -> float:
	## Distance restante jusqu'au bout de l'arete (au carrefour).
	var pts: PackedVector2Array = a["pts"]
	var i: int = a["i"]
	var rem: float = pts[i].distance_to(pts[i + 1]) - a["s"]
	for j in range(i + 1, pts.size() - 1):
		rem += pts[j].distance_to(pts[j + 1])
	return rem


func _choose_next(a: Dictionary) -> void:
	## Au carrefour : une rue autorisee, plutot tout droit ; demi-tour seulement au fond d'une impasse.
	var n: int = a["to"]
	var pts: PackedVector2Array = a["pts"]
	var in_dir := (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	var cands := []
	var weights := []
	for e in _carte.node_edges[n]:
		if e == a["edge"] or not _carte.can_drive(e, n):
			continue
		var ed: Dictionary = _carte.edges[e]
		if a["kind"] == "voiture" and ed["kind"] == "track":
			continue
		var p2 := _carte.edge_pts_from(e, n)
		var straight := in_dir.dot((p2[1] - p2[0]).normalized())
		var wgt := 1.0 + 2.0 * maxf(straight, 0.0) + (1.5 if ed["major"] else 0.0)
		if straight < -0.7:
			wgt *= 0.1
		cands.append(e)
		weights.append(wgt)
	if cands.is_empty():
		if not _carte.edges[a["edge"]]["oneway"]:
			_set_edge(a, a["edge"], n)   # impasse : demi-tour
		else:
			_release(a)
			_place_random(a)              # sens unique sans issue (bord de carte) : reapparait ailleurs
		return
	var total := 0.0
	for w in weights:
		total += w
	var roll := _rng.randf() * total
	for k in cands.size():
		roll -= weights[k]
		if roll <= 0.0:
			_set_edge(a, cands[k], n)
			return
	_set_edge(a, cands[cands.size() - 1], n)


# ------------------------------------------------------------ simulation
func _physics_process(delta: float) -> void:
	var ppos := Vector3(1e9, 0, 1e9)
	if _player:
		var pv = _player.get("vehicle")
		ppos = (pv as Node3D).global_position if pv else _player.global_position
	_obstacles = get_tree().get_nodes_in_group("vehicules") + get_tree().get_nodes_in_group("obstacles_route")
	for a in _agents:
		if a.get("active", true):
			_drive(a, delta, ppos)


func _drive(a: Dictionary, delta: float, ppos: Vector3) -> void:
	var pts: PackedVector2Array = a["pts"]
	var i: int = a["i"]
	var fwd2 := (pts[i + 1] - pts[i]).normalized()
	var vmax: float = a["max_big"] if a["major"] else a["max_small"]
	var rem := _remaining(a)
	# virage a l'interieur du troncon
	if i + 2 < pts.size() and pts[i + 1].distance_to(pts[i]) - a["s"] < 12.0:
		var turn := 1.0 - maxf(fwd2.dot((pts[i + 2] - pts[i + 1]).normalized()), 0.0)
		vmax *= 1.0 - 0.6 * clamp(turn * 2.0, 0.0, 1.0)
	# carrefour : ralentir, et ceder le passage a celui qui est deja engage
	var n: int = a["to"]
	if _carte.node_degree(n) >= 3 and rem < 18.0:
		vmax = minf(vmax, 4.0 + rem * 0.45)
		if rem < 9.0:
			var holder: int = _locks.get(n, -1)
			if holder < 0 or holder == a["id"] or _lock_expired(_agents[holder], n):
				_locks[n] = a["id"]
				a["wait"] = 0.0
			else:
				a["wait"] = a.get("wait", 0.0) + delta
				if a["wait"] < 6.0:
					vmax = minf(vmax, maxf(rem - 6.0, 0.0) * 1.5)
	# obstacles devant : autres vehicules, joueur
	var me: Vector3 = a["vis_pos"]
	var fwd3 := Vector3(-sin(a["vis_yaw"]), 0, -cos(a["vis_yaw"]))
	var side3 := Vector3(-fwd3.z, 0, fwd3.x)
	var brake := false
	var blocked_by_player := false
	for b in _agents:
		if is_same(b, a) or not b.get("active", true):
			continue
		var d: Vector3 = b["vis_pos"] - me
		var ahead := d.dot(fwd3)
		if ahead > 0.5 and ahead < 9.0 + a["speed"] * 0.6 and absf(d.dot(side3)) < 1.6:
			vmax = minf(vmax, b["speed"] * 0.9 if ahead > 5.0 else 0.0)
			brake = true
	for o in _obstacles:
		var d: Vector3 = (o as Node3D).global_position - me
		var ahead := d.dot(fwd3)
		if ahead > 0.5 and ahead < 9.0 + a["speed"] * 0.6 and absf(d.dot(side3)) < 1.8:
			vmax = 0.0
			brake = true
	var dp := ppos - me
	var pa := dp.dot(fwd3)
	var block_range := 13.0 if a["speed"] < 1.0 else 12.0  # marge : une fois arrete, il ne repart pas au moindre ecart
	if pa > 0.0 and pa < block_range and absf(dp.dot(side3)) < 2.2:
		vmax = 0.0
		blocked_by_player = true
	# acceleration / freinage
	var acc := 3.0 if vmax > a["speed"] else 8.0
	a["speed"] = move_toward(a["speed"], vmax, acc * delta)
	_advance(a, a["speed"] * delta)
	# klaxon si bloque par le joueur (ou bouchon qui dure)
	a["honk_cd"] = maxf(0.0, a["honk_cd"] - delta)
	if a["speed"] < 0.5 and (blocked_by_player or brake):
		a["stuck"] += delta
	else:
		a["stuck"] = 0.0
	if a["stuck"] > (0.7 if blocked_by_player else 6.0) and a["honk_cd"] <= 0.0:
		(a["horn"] as AudioStreamPlayer3D).play()
		a["honk_cd"] = _rng.randf_range(2.0, 4.0)
		honked.emit(a["body"], blocked_by_player)
	# coince trop longtemps (embouteillage sans fin) : il repart ailleurs, loin du joueur
	if a["stuck"] > 25.0 and not blocked_by_player:
		_release(a)
		_place_random(a)
		a["stuck"] = 0.0
	# position visuelle : voie, lissage pour adoucir les virages aux carrefours
	pts = a["pts"]
	i = a["i"]
	fwd2 = (pts[i + 1] - pts[i]).normalized()
	var target2 := _lane_point(a)
	var k := 1.0 - exp(-6.0 * delta)
	a["vis_pos"] = (a["vis_pos"] as Vector3).lerp(Vector3(target2.x, GROUND_Y, target2.y), k)
	var yaw := atan2(-fwd2.x, -fwd2.y)
	a["vis_yaw"] = lerp_angle(a["vis_yaw"], yaw, 1.0 - exp(-5.0 * delta))
	var lean := 0.0
	if a["kind"] != "voiture":
		lean = clamp(angle_difference(yaw, a["vis_yaw"]) * a["speed"] * 0.08, -0.4, 0.4)
	var body: AnimatableBody3D = a["body"]
	body.global_transform = Transform3D(Basis(Vector3.UP, a["vis_yaw"]) * Basis(Vector3(0, 0, 1), lean), a["vis_pos"])
	(a["snd"] as AudioStreamPlayer3D).pitch_scale = 0.7 + a["speed"] / 12.0
	# carrefour libere une fois traverse
	var last: int = a.get("last_node", -1)
	if last >= 0 and _locks.get(last, -1) == a["id"] and Vector2(me.x, me.z).distance_to(_carte.nodes[last]) > 8.0:
		_locks.erase(last)


func _lock_expired(holder: Dictionary, n: int) -> bool:
	## Le vehicule qui tenait le carrefour en est loin, ne s'en approche plus, ou a quitte la circulation.
	if not holder.get("active", true):
		return true
	var hp: Vector3 = holder["vis_pos"]
	return Vector2(hp.x, hp.z).distance_to(_carte.nodes[n]) > 14.0 or (holder["to"] != n and holder.get("last_node", -1) != n)


func _release(a: Dictionary) -> void:
	for n in _locks.keys():
		if _locks[n] == a["id"]:
			_locks.erase(n)


func _advance(a: Dictionary, dist: float) -> void:
	a["s"] += dist
	var guard := 0
	while guard < 8:
		guard += 1
		var pts: PackedVector2Array = a["pts"]
		var L: float = pts[a["i"]].distance_to(pts[a["i"] + 1])
		if a["s"] < L:
			return
		a["s"] -= L
		a["i"] += 1
		if a["i"] >= pts.size() - 1:
			var left: float = a["s"]
			a["last_node"] = a["to"]
			_choose_next(a)
			a["s"] = left
