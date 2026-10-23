extends Node3D
## Circulation : zems (conducteur en chemise jaune, parfois un passager) et voitures qui roulent sur le vrai
## reseau de rues (graphe des carrefours OSM, scripts/carte.gd).
## - conduite a droite (voie de droite, ou l'une des deux voies d'un boulevard a sens unique), sens uniques ;
## - aux carrefours : ralentissent, tournent plutot tout droit, cedent le passage a celui qui est deja engage ;
## - gardent leurs distances, s'arretent devant le joueur et klaxonnent ;
## - bruit de moteur (boucle synthetisee) dont la hauteur suit la vitesse, klaxons synthetises ;
## - corps physiques (on ne passe pas a travers), phares allumes la nuit.

@export var zem_count := 60             # la carte fait 7 x 2,3 km : plus dense qu'avant (retour d'Olympe du 21/10/2026, carte deserte)
@export var car_count := 36
## Recyclage : un vehicule trop loin du joueur reapparait dans une rue proche, hors de vue, pour que la densite autour du
## joueur reste la meme sur toute la carte.
@export var recycle_dist := 320.0
@export var recycle_zone := Vector2(90.0, 230.0)
@export var player_path: NodePath = ^"../Player"
@export var seed_value := 77
@export var turn_radius_car := 5.3     # m : rayon de braquage mini d'une berline
@export var turn_radius_moto := 2.6    # m : moto 125 cc
@export var look_ahead_min := 3.5      # m : point vise devant le vehicule...
@export var look_ahead_time := 0.45    # ... plus la distance parcourue en ce temps
@export var steer_gain := 2.2          # reactivite du volant (1/s)

const ZEM_SCENE := preload("res://assets/models/veh_zem.glb")
const ZEM := preload("res://scripts/zem.gd")
const SALETE := preload("res://shaders/salete_auto.gdshader")
const VOITURE := preload("res://scripts/voiture.gd")
const LAMP_MAT := preload("res://shaders/lampe_material.tres")
const CAR_COLORS := [Color(0.92, 0.92, 0.9), Color(0.92, 0.92, 0.9), Color(0.7, 0.71, 0.72), Color(0.08, 0.08, 0.09),
	Color(0.1, 0.18, 0.4), Color(0.55, 0.08, 0.06), Color(0.75, 0.68, 0.55)]
const GROUND_Y := 0.02
const CAR_MODELS := ["veh_berline", "veh_pejo", "veh_mersede", "veh_4x4", "veh_minibus", "veh_pickup", "veh_camion"]
const DRIVERS_PER_MODEL := 4
@export var zem_number_pos := Vector3(0, 1.17, 0.29)   # dos du conducteur assis (repere du zem)
@export var zem_number_tilt := -0.25                  # buste penche en avant
@export var lod_distance := 120.0       # m : au-dela, vehicule mis a jour un pas physique sur lod_pas
@export var lod_pas := 4
var _tick := 0
const ZEM_VARIANTS := ["zem_a", "zem_b", "zem_c", "zem_passager_h", "zem_passager_f", "zem_passager_f2"]
var _looks := {}   # variante de zem -> [[genre, morphologie, tenue]] du conducteur et du passager

var _rng := RandomNumberGenerator.new()
var _carte: Carte
var _agents: Array = []
var _player: Node3D
var _locks := {}              # noeud de carrefour -> id de l'agent engage
var _signal: Signalisation    # feux tricolores et STOP (scripts/signalisation.gd)
var _obstacles: Array = []    # vehicules gares ou abandonnes, pietons qui traversent

signal honked(body: Node3D, at_player: bool)
## le conducteur (et le passager) d'un vehicule pris par le joueur sont ejectes : scripts/pedestrians.gd les fait reagir
signal driver_ejected(pos: Vector3, yaw: float, genre: String, angry_at: Node3D, rider: Array)
var _snd_moto: AudioStreamWAV
var _snd_car: AudioStreamWAV
var _horn_moto: AudioStreamWAV
var _horn_car: AudioStreamWAV


func _ready() -> void:
	_rng.seed = seed_value
	add_to_group("circulation")
	_player = get_node_or_null(player_path)
	_carte = Carte.zone()
	# sons synthetises : etapes de la mise en place etalee (avant les vehicules qui les utilisent)
	Partie.chantier(func() -> void: _snd_moto = AudioSynth.moto_loop())
	Partie.chantier(func() -> void: _snd_car = AudioSynth.voiture_loop())
	Partie.chantier(func() -> void:
		_horn_moto = AudioSynth.klaxon(415.0, 520.0, 0.35)
		_horn_car = AudioSynth.klaxon(350.0, 440.0, 0.5))
	_signal = Signalisation.new()
	_signal.name = "Signalisation"
	add_child(_signal)
	Partie.chantier(func() -> void: _signal.monter(_carte))
	var meshes: Dictionary = await _build_meshes()
	# etale sur plusieurs images pendant l'ecran de chargement (Partie.chantier)
	for i in zem_count:
		Partie.chantier(_spawn.bind("zem_passager" if _rng.randf() < 0.35 else "zem", meshes))
	for i in car_count:
		Partie.chantier(_spawn.bind("voiture", meshes))
	print("Circulation : %d zems, %d voitures, %d troncons, %d carrefours" % [zem_count, car_count, _carte.edges.size(), _carte.nodes.size()])


# ------------------------------------------------------------ vehicules
func _build_meshes() -> Dictionary:
	var out := {}
	# zem + conducteur en chemise jaune (+ passager ou passagere), poses puis fusionnes en un seul mesh
	for variant in ZEM_VARIANTS:
		await Partie.respirer()
		var asm := Node3D.new()
		add_child(asm)
		var z := ZEM_SCENE.instantiate()
		asm.add_child(z)
		var bq := z.find_child("piv_bequille", true, false) as Node3D
		if bq:
			bq.rotation.x = ZEM.BEQUILLE_REPLIEE   # moto qui roule : bequille relevee
		_lamp_surfaces(z, "veh_phare")
		var driver := PnjUtil.make("homme", false)
		asm.add_child(driver)
		var dl := PnjUtil.random_look(driver, _rng, "zem")
		PnjUtil.apply(driver, dl)
		_looks[variant] = [["homme", "homme", dl]]
		driver.scale = Vector3.ONE
		PnjUtil.pose_seated(driver)
		driver.position = Vector3(0, -0.05, 0.12)
		if variant.begins_with("zem_passager"):
			var genre := "femme" if variant.contains("_f") else "homme"
			var pas := PnjUtil.make(PnjUtil.random_variant(_rng, genre), false)
			asm.add_child(pas)
			var pl := PnjUtil.random_look(pas, _rng)
			PnjUtil.apply(pas, pl)
			_looks[variant].append([genre, pas.get_meta("variante", genre), pl])
			pas.scale = Vector3.ONE
			PnjUtil.pose_passenger(pas)
			pas.position = Vector3(0, -0.02 + (0.04 if genre == "femme" else 0.0), 0.48)
		out[variant] = asm
	# conducteurs des voitures (vus a travers les vitres teintees), assis sur le siege du modele (pt_conducteur)
	for model in CAR_MODELS:
		var car := (load(Vehicules.MODELS[model]) as PackedScene).instantiate() as Node3D
		var seat: Node3D = car.find_child("pt_conducteur", true, false)
		var sp: Vector3 = Vehicules._rel(car, seat).origin if seat else Vector3(-0.4, 0.6, 0.0)
		car.free()
		for n in DRIVERS_PER_MODEL:
			await Partie.respirer()
			var genre := "femme" if _rng.randf() < 0.2 else "homme"
			var dr := PnjUtil.make(PnjUtil.random_variant(_rng, genre), false)
			var asm2 := Node3D.new()
			add_child(asm2)
			asm2.add_child(dr)
			var look := PnjUtil.random_look(dr, _rng)
			PnjUtil.apply(dr, look)
			# dans la voiture, seul le haut est visible : le bas du pagne / boubou depasserait sous le plancher
			for sn in ["chr_pagne_long", "chr_jupe", "chr_boubou"]:
				var smi := dr.find_child(sn, true, false) as Node3D
				if smi:
					smi.visible = false
			dr.scale = Vector3.ONE
			PnjUtil.pose_driving(dr)
			dr.position = sp - Vector3(0, 0.89 if genre == "homme" else 0.85, 0)
			var key := "drv_%s_%d" % [model, n]
			out[key] = asm2
			_looks[key] = [[genre, dr.get_meta("variante", genre), look]]
	# la pose assise du squelette n'est appliquee au maillage qu'a l'image suivante : on fusionne apres
	await get_tree().process_frame
	await get_tree().process_frame
	for variant in ZEM_VARIANTS:
		await Partie.respirer()
		var asm: Node3D = out[variant]
		out[variant] = PnjUtil.merge(asm)
		asm.queue_free()
	for key in out.keys():
		if String(key).begins_with("drv_"):
			await Partie.respirer()
			var asm: Node3D = out[key]
			out[key] = PnjUtil.merge(asm)
			asm.queue_free()
	for model in CAR_MODELS:
		await Partie.respirer()
		out[model] = Vehicules.merged(model)
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
		# berlines d'occasion surtout, des 4x4, et les minibus "tokpa-tokpa" qui font le transport en commun
		var roll := _rng.randf()
		var model := Vehicules.berline(roll / 0.44) if roll < 0.44 else ("veh_4x4" if roll < 0.6 else ("veh_pickup" if roll < 0.7 else ("veh_minibus" if roll < 0.84 else "veh_camion")))
		mi.mesh = meshes[model]
		var dk := "drv_%s_%d" % [model, _rng.randi() % DRIVERS_PER_MODEL]
		var drv := MeshInstance3D.new()
		drv.mesh = meshes[dk]
		drv.visibility_range_end = 60.0
		mi.add_child(drv)
		a["riders"] = _looks[dk]
		var col: Color = CAR_COLORS[_rng.randi() % CAR_COLORS.size()]
		if model == "veh_minibus":
			col = [Color(0.93, 0.93, 0.9), Color(0.95, 0.8, 0.2), Color(0.85, 0.85, 0.82)][_rng.randi() % 3]
		a["model"] = model
		a["color"] = col
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m and m.resource_name == "mat_carrosserie":
				var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_color = col
				var sal := ShaderMaterial.new()          # poussiere de laterite et rouille, comme les voitures conduites
				sal.shader = SALETE
				sal.set_shader_parameter("poussiere", _rng.randf_range(0.25, 0.9))
				sal.set_shader_parameter("rouille", _rng.randf_range(0.0, 0.6) if model in ["veh_minibus", "veh_berline", "veh_pejo", "veh_mersede"] and _rng.randf() < 0.6 else 0.0)
				sal.set_shader_parameter("haut_caisse", 1.0 if model in Vehicules.BERLINES else 1.2)
				d.next_pass = sal
				mi.set_surface_override_material(s, d)
			elif m and m.resource_name == "mat_lampe":
				mi.set_surface_override_material(s, LAMP_MAT)
			elif m and m.resource_name == "mat_verre_auto":
				mi.set_surface_override_material(s, VOITURE._verre_teinte())
		var aabb: AABB = mi.mesh.get_aabb()
		box.size = Vector3(aabb.size.x - 0.15, aabb.size.y - 0.04, aabb.size.z - 0.1)
		cs.position = Vector3(0, aabb.position.y + 0.02 + box.size.y / 2.0, aabb.get_center().z)
		a["max_big"] = _rng.randf_range(11.0, 15.0) * (0.85 if model == "veh_minibus" else (0.75 if model == "veh_camion" else 1.0))
		a["max_small"] = _rng.randf_range(6.0, 8.5)
		a["lane"] = 0.27
		a["length"] = aabb.size.z
		a["feu_ar"] = Vector3(aabb.size.x * 0.5 - 0.22, FEU_HAUTEUR.get(model, 0.85), aabb.get_center().z + aabb.size.z * 0.5)
	else:
		var pool := ZEM_VARIANTS.filter(func(v: String) -> bool: return v.begins_with("zem_passager") == (kind == "zem_passager"))
		var variant: String = pool[_rng.randi() % pool.size()]
		# numero de zemidjan peint dans le dos de la chemise jaune (fictif : GT = Gbe Town)
		var num := Label3D.new()
		num.text = "GT %04d" % _rng.randi_range(1, 9999)
		num.font_size = 44
		num.pixel_size = 0.0016
		num.modulate = Color(0.08, 0.08, 0.1)
		num.outline_size = 0
		num.position = zem_number_pos
		num.rotation.x = zem_number_tilt
		num.visibility_range_end = 25.0
		num.double_sided = false            # lisible seulement de dos (pas en miroir de face)
		mi.add_child(num)
		mi.mesh = meshes[variant]
		a["model"] = "zem"
		a["riders"] = _looks.get(variant, [["homme", "homme", {}]])   # memes personnes (et memes habits) a l'ejection
		box.size = Vector3(0.6, 1.5, 2.0)
		cs.position = Vector3(0, 0.75, 0)
		a["max_big"] = _rng.randf_range(10.0, 14.0)
		a["max_small"] = _rng.randf_range(6.0, 9.0)
		a["lane"] = 0.36  # les zems serrent le bord droit
		a["length"] = 2.0
		a["feu_ar"] = Vector3(0.0, 0.8, 1.05)
	cs.shape = box
	body.add_child(cs)
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.add_child(mi)
	_feux_stop(a, body)
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
		if (a["kind"] == "voiture" and ed["kind"] == "track") or _carte.arete_reservee(e):
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


func _recycler(ppos: Vector3) -> void:
	## Replace jusqu'a 2 vehicules trop loin sur une rue proche du joueur (hors du champ de la camera).
	if _player == null or ppos.x > 1e8:
		return
	var pp := Vector2(ppos.x, ppos.z)
	var cam := get_viewport().get_camera_3d()
	var faits := 0
	for a in _agents:
		if faits >= 2:
			return
		if not a.get("active", true) or (a["vis_pos"] as Vector3).distance_to(ppos) < recycle_dist:
			continue
		for essai in 8:
			var ang := _rng.randf() * TAU
			var q := pp + Vector2(cos(ang), sin(ang)) * _rng.randf_range(recycle_zone.x, recycle_zone.y)
			var nr := _carte.nearest_on_network(q)
			if nr.is_empty():
				continue
			var e: int = nr["edge"]
			var ed: Dictionary = _carte.edges[e]
			if a["kind"] == "voiture" and ed["kind"] == "track":
				continue
			var from: int = ed["a"]
			if not ed["oneway"] and _rng.randf() < 0.5:
				from = ed["b"]
			var pts := _carte.edge_pts_from(e, from)
			var best_i := 0
			var best_d := INF
			for i in pts.size() - 1:
				var d := Geometry2D.get_closest_point_to_segment(nr["point"], pts[i], pts[i + 1]).distance_to(nr["point"])
				if d < best_d:
					best_d = d
					best_i = i
			var libre := true
			for b in _agents:
				if not is_same(b, a) and Vector2(b["vis_pos"].x, b["vis_pos"].z).distance_to(pts[best_i]) < 10.0:
					libre = false
					break
			var pw := Vector3(pts[best_i].x, GROUND_Y, pts[best_i].y)
			if not libre or (cam != null and not cam.is_position_behind(pw) and cam.is_position_in_frustum(pw)):
				continue
			_set_edge(a, e, from)
			a["i"] = best_i
			var p := _lane_point(a)
			a["vis_pos"] = Vector3(p.x, GROUND_Y, p.y)
			var dd := pts[best_i + 1] - pts[best_i]
			a["vis_yaw"] = atan2(-dd.x, -dd.y)
			a["speed"] = 0.0
			a["stuck"] = 0.0
			faits += 1
			break


## Part des vehicules en circulation selon l'heure de jeu : [heure, part]. Pointes du matin (7 h a 9 h) et du soir (16 h a 19 h) :
## tout le monde roule, donc des bouchons naturels aux carrefours ; creux de la nuit : un tiers seulement.
@export var densite_horaire: Array[Vector2] = [Vector2(0, 0.3), Vector2(5, 0.3), Vector2(6.5, 0.7), Vector2(7.5, 1.0),
	Vector2(9, 1.0), Vector2(10.5, 0.7), Vector2(15, 0.75), Vector2(16.5, 1.0), Vector2(19, 1.0), Vector2(21, 0.6),
	Vector2(23, 0.35), Vector2(24, 0.3)]


func part_circulation(heure: float) -> float:
	for k in densite_horaire.size() - 1:
		var a := densite_horaire[k]
		var b := densite_horaire[k + 1]
		if heure >= a.x and heure <= b.x:
			return lerpf(a.y, b.y, (heure - a.x) / maxf(b.x - a.x, 0.001))
	return 1.0


func _densite_horaire(ppos: Vector3) -> void:
	## Met au repos (ou remet en route) des vehicules selon l'heure, uniquement hors du champ de la camera et a plus de
	## 80 m du joueur : jamais d'apparition ni de disparition devant lui.
	if _jour_nuit == null:
		_jour_nuit = get_parent().get_node_or_null("JourNuit")
	if _jour_nuit == null:
		return
	var part := part_circulation(float(_jour_nuit.get("hour")))
	var cam := get_viewport().get_camera_3d()
	var n := float(_agents.size())
	for a in _agents:
		var rang := float(a["id"]) / n
		var repos: bool = a.get("repos", false)
		if repos == (rang >= part):
			continue
		var vp: Vector3 = a["vis_pos"]
		var pw := vp + Vector3(0, 1, 0)
		var visible_cam: bool = cam != null and not cam.is_position_behind(pw) and cam.is_position_in_frustum(pw)
		if vp.distance_to(ppos) < 80.0 or visible_cam:
			continue
		var body := a["body"] as Node3D
		if rang >= part:
			if not a.get("active", true):
				continue                       # epave ou vehicule pris : on n'y touche pas
			a["repos"] = true
			a["active"] = false
			a["speed"] = 0.0
			_release(a)
			body.visible = false
			a["couche"] = (body as CollisionObject3D).collision_layer
			(body as CollisionObject3D).collision_layer = 0
			(a["snd"] as AudioStreamPlayer3D).stop()
		else:
			a["repos"] = false
			a["active"] = true
			a["stuck"] = 0.0
			body.visible = true
			(body as CollisionObject3D).collision_layer = int(a.get("couche", 1))
			(a["snd"] as AudioStreamPlayer3D).play()


func _set_edge(a: Dictionary, e: int, from: int) -> void:
	a.erase("next_edge")
	a["detour"] = 0.0
	a["detour_cible"] = 0.0
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


func _ahead_point(a: Dictionary, dist: float) -> Vector2:
	## Point de la voie a dist metres devant la position courante sur le troncon (prolonge tout droit au bout).
	var pts: PackedVector2Array = a["pts"]
	var i: int = a["i"]
	var s: float = a["s"] + dist
	var lane: float = a["lane_off"] + a.get("detour", 0.0)
	while i + 2 < pts.size() and s > pts[i].distance_to(pts[i + 1]):
		s -= pts[i].distance_to(pts[i + 1])
		i += 1
	var last := pts[i].distance_to(pts[i + 1])
	if i + 2 >= pts.size() and s > last:
		# au-dela du carrefour : on choisit la rue suivante maintenant et on vise dedans (courbe dans le carrefour)
		if not a.has("next_edge"):
			a["next_edge"] = _pick_next(a)
		var ne: int = a["next_edge"]
		if ne >= 0:
			var p2 := _carte.edge_pts_from(ne, a["to"])
			var d2 := p2[1] - p2[0]
			var f2 := d2 / maxf(d2.length(), 0.01)
			var ed: Dictionary = _carte.edges[ne]
			var lane2: float = lane if not ed["oneway"] else ed["width"] * 0.25 * a["lane_side"] if ed["width"] >= 6.5 else 0.0
			if not ed["oneway"]:
				lane2 = ed["width"] * a["lane"]
			return p2[0] + f2 * minf(s - last, d2.length()) + Vector2(-f2.y, f2.x) * lane2
	var d := pts[i + 1] - pts[i]
	var f := d / maxf(d.length(), 0.01)
	return pts[i] + f * s + Vector2(-f.y, f.x) * lane


func _lane_point(a: Dictionary) -> Vector2:
	var pts: PackedVector2Array = a["pts"]
	var i: int = a["i"]
	var d := pts[i + 1] - pts[i]
	var f := d / maxf(d.length(), 0.01)
	return pts[i] + f * a["s"] + Vector2(-f.y, f.x) * (a["lane_off"] + a.get("detour", 0.0))


@export var contour_attente := 2.0     # s a l'arret derriere un obstacle fixe avant de chercher a le contourner
@export var contour_largeur := 2.7     # m de decalage lateral pour une voiture (zem : 70 %)


func _contourner(a: Dictionary, delta: float, bloque: bool, me: Vector3, fwd3: Vector3, side3: Vector3) -> void:
	## Contournement d'un vehicule gare ou en panne : apres quelques secondes d'arret derriere lui, si la voie voisine est
	## libre sur 40 m (ni vehicule en face, ni derriere qui arrive), le vehicule se decale, double, puis reprend sa voie.
	## Sinon il attend (il ne fait ni demi-tour ni manoeuvre dangereuse).
	if bloque and a["speed"] < 0.6:
		a["obs_t"] = a.get("obs_t", 0.0) + delta
	elif not bloque:
		a["obs_t"] = maxf(0.0, a.get("obs_t", 0.0) - delta * 2.0)
	var cible: float = a.get("detour_cible", 0.0)
	if cible == 0.0:
		if a.get("obs_t", 0.0) > contour_attente and a["speed"] < 0.6:
			var ed: Dictionary = _carte.edges[a["edge"]]
			var demi: float = float(ed["width"]) * 0.5
			var pas := contour_largeur * (1.0 if a["kind"] == "voiture" else 0.7)
			var essais := [-pas, pas]
			for cand in essais:
				if absf(a["lane_off"] + cand) > demi - 0.7:
					continue
				var libre := true
				for b in _agents:
					if is_same(b, a) or not b.get("active", true):
						continue
					var d: Vector3 = b["vis_pos"] - me
					var ahead := d.dot(fwd3)
					if ahead > -12.0 and ahead < 40.0 and absf(d.dot(side3) - cand) < 2.4:
						libre = false
						break
				if libre:
					a["detour_cible"] = cand
					a["fin_t"] = 0.0
					break
	elif not bloque:
		# l'obstacle est a cote ou derriere : on attend d'etre bien passe avant de se rabattre
		a["fin_t"] = a.get("fin_t", 0.0) + delta * (0.6 + a["speed"] * 0.1)
		if a["fin_t"] > 2.0:
			a["detour_cible"] = 0.0
			a["obs_t"] = 0.0
	if absf(a.get("detour", 0.0) - a.get("detour_cible", 0.0)) > 0.001:
		a["detour"] = move_toward(a.get("detour", 0.0), a.get("detour_cible", 0.0), 1.4 * delta)


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
	# rue deja choisie a l'approche (le vehicule a commence a tourner)
	var pre: int = a.get("next_edge", -1)
	a.erase("next_edge")
	if pre >= 0:
		_set_edge(a, pre, a["to"])
		return
	var e := _pick_next(a)
	if e >= 0:
		_set_edge(a, e, a["to"])
	elif not _carte.edges[a["edge"]]["oneway"]:
		_set_edge(a, a["edge"], a["to"])   # impasse : demi-tour
	else:
		_release(a)
		_place_random(a)              # sens unique sans issue (bord de carte) : reapparait ailleurs


func _pick_next(a: Dictionary) -> int:
	## Rue suivante au carrefour (-1 : aucune). Plutot tout droit et les grands axes.
	var n: int = a["to"]
	var pts: PackedVector2Array = a["pts"]
	var in_dir := (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
	var cands := []
	var weights := []
	for e in _carte.node_edges[n]:
		if e == a["edge"] or not _carte.can_drive(e, n):
			continue
		var ed: Dictionary = _carte.edges[e]
		if (a["kind"] == "voiture" and ed["kind"] == "track") or _carte.arete_reservee(e):
			continue
		var p2 := _carte.edge_pts_from(e, n)
		var straight := in_dir.dot((p2[1] - p2[0]).normalized())
		var wgt := 1.0 + 2.0 * maxf(straight, 0.0) + (1.5 if ed["major"] else 0.0)
		if straight < -0.7:
			wgt *= 0.1
		cands.append(e)
		weights.append(wgt)
	if cands.is_empty():
		return -1
	var total := 0.0
	for w in weights:
		total += w
	var roll := _rng.randf() * total
	for k in cands.size():
		roll -= weights[k]
		if roll <= 0.0:
			return cands[k]
	return cands[cands.size() - 1]


# ------------------------------------------------------------ simulation
func _physics_process(delta: float) -> void:
	var ppos := Vector3(1e9, 0, 1e9)
	if _player:
		var pv = _player.get("vehicle")
		ppos = (pv as Node3D).global_position if pv else _player.global_position
	_obstacles = get_tree().get_nodes_in_group("vehicules") + get_tree().get_nodes_in_group("obstacles_route")
	_tick += 1
	if _tick % 45 == 0:
		_recycler(ppos)
	if _tick % 60 == 0:
		_densite_horaire(ppos)
	for a in _agents:
		if a.get("active", true) and (a["body"] as Node).has_meta("epave"):
			a["active"] = false          # explose : epave immobile
		if a.get("active", true):
			# loin du joueur : mis a jour un pas sur lod_pas, avec le temps cumule (budget CPU, phase 11)
			a["dt"] = a.get("dt", 0.0) + delta
			var far: bool = (a["vis_pos"] as Vector3).distance_squared_to(ppos) > lod_distance * lod_distance
			if far and (_tick + int(a["id"])) % lod_pas != 0:
				continue
			_drive(a, minf(a["dt"], 0.1), ppos)
			a["dt"] = 0.0


func _drive(a: Dictionary, delta: float, ppos: Vector3) -> void:
	var pts: PackedVector2Array = a["pts"]
	var i: int = a["i"]
	var fwd2 := (pts[i + 1] - pts[i]).normalized()
	var vmax: float = a["max_big"] if a["major"] else a["max_small"]
	if _signal:
		vmax = minf(vmax, _signal.limite_ms(a["major"]))      # limitation de vitesse (50 km/h sur les voies principales, 30 ailleurs)
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
	# feu rouge / orange et STOP : on s'arrete avant la ligne (a 3 m du carrefour), puis on repart
	a["au_feu"] = false
	if _signal and rem < 34.0 and rem > 1.5:
		var arret_d := Signalisation.ligne(float(_carte.edges[a["edge"]]["width"])) + 2.0    # centre du vehicule : pare-chocs a la ligne
		var etat := _signal.etat(n, fwd2)
		if rem < arret_d - 1.5:
			pass                                  # deja engage au-dela de la ligne : on degage le carrefour
		elif etat == 2 or (etat == 1 and rem > a["speed"] * 1.4 + 5.0):
			vmax = minf(vmax, maxf(rem - arret_d, 0.0) * 1.3)
			a["au_feu"] = true
		elif _signal.est_stop(n, a["edge"]) and a.get("stop_ok", -1) != n:
			vmax = minf(vmax, maxf(rem - arret_d, 0.0) * 1.3)
			if rem < arret_d + 2.0 and a["speed"] < 0.4:
				a["stop_t"] = a.get("stop_t", 0.0) + delta
				a["au_feu"] = true
				if a["stop_t"] > 1.4:
					a["stop_ok"] = n
					a["stop_t"] = 0.0
	# accident ou choc tout pres : le conducteur s'arrete un moment
	if a.get("stunned", 0.0) > 0.0:
		a["stunned"] -= delta
		vmax = 0.0
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
	var statique := false
	for o in _obstacles:
		var d: Vector3 = (o as Node3D).global_position - me
		var ahead := d.dot(fwd3)
		if ahead > 0.5 and ahead < 9.0 + a["speed"] * 0.6 and absf(d.dot(side3)) < 1.8:
			vmax = 0.0
			brake = true
			var vit = o.get("speed")
			if (o as Node).is_in_group("vehicules") and (vit == null or absf(float(vit)) < 0.5):
				statique = true            # vehicule gare ou en panne : on peut le contourner
	_contourner(a, delta, statique and not a.get("au_feu", false), me, fwd3, side3)
	var dp := ppos - me
	var pa := dp.dot(fwd3)
	var block_range := 13.0 if a["speed"] < 1.0 else 12.0  # marge : une fois arrete, il ne repart pas au moindre ecart
	if pa > 0.0 and pa < block_range and absf(dp.dot(side3)) < 2.2:
		vmax = 0.0
		blocked_by_player = true
	# acceleration / freinage
	var acc := 3.0 if vmax > a["speed"] else 8.0
	var freine: bool = vmax < a["speed"] - 0.3 or bool(a.get("au_feu", false)) or (a["speed"] < 0.5 and vmax < 0.5)
	if freine != a.get("freine", false):
		a["freine"] = freine
		(a["feux"] as Node3D).visible = freine
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
		if blocked_by_player and _rng.randf() < 0.45:
			Bulle.say(a["body"], Dialogues.pick("klaxon", _rng, _pgenre()), 2.4, 2.0)
		honked.emit(a["body"], blocked_by_player)
	# coince trop longtemps (embouteillage sans fin) : il repart ailleurs, loin du joueur
	if a["stuck"] > 45.0 and not blocked_by_player:
		_release(a)
		_place_random(a)
		a["stuck"] = 0.0
	# position visuelle : voie, lissage pour adoucir les virages aux carrefours
	pts = a["pts"]
	i = a["i"]
	fwd2 = (pts[i + 1] - pts[i]).normalized()
	# conduite comme un vrai vehicule (modele bicyclette) : il vise un point de sa voie devant lui, braque au plus
	# de ce que permet son rayon de braquage et avance toujours dans l'axe de ses roues (pas de glissade de cote)
	var vp: Vector3 = a["vis_pos"]
	var look := _ahead_point(a, look_ahead_min + a["speed"] * look_ahead_time)
	var to := Vector2(look.x - vp.x, look.y - vp.z)
	var want: float = atan2(-to.x, -to.y) if to.length() > 0.3 else a["vis_yaw"]
	var r_min: float = turn_radius_car if a["kind"] == "voiture" else turn_radius_moto
	var max_rate := maxf(a["speed"], 0.8) / r_min
	var rate := clampf(angle_difference(a["vis_yaw"], want) * steer_gain, -max_rate, max_rate)
	a["vis_yaw"] = wrapf(a["vis_yaw"] + rate * delta, -PI, PI)
	var heading := Vector3(-sin(a["vis_yaw"]), 0, -cos(a["vis_yaw"]))
	vp += heading * a["speed"] * delta
	# derive lente vers le milieu de la voie (sans glissade visible)
	var lane2 := _lane_point(a)
	var off := Vector3(lane2.x - vp.x, 0, lane2.y - vp.z)
	if off.length() > 6.0:
		vp = Vector3(lane2.x, GROUND_Y, lane2.y)     # trop loin (replace, demi-tour) : recale d'un coup
	else:
		vp += off * minf(1.0, 1.5 * delta)
	vp.y = GROUND_Y
	a["vis_pos"] = vp
	var lean := 0.0
	if a["kind"] != "voiture":
		# la moto s'incline dans le virage : tan(angle) = v * vitesse de lacet / g
		lean = clampf(-atan(a["speed"] * rate / 9.81), -0.5, 0.5)
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


# ------------------------------------------------------------ vehicules pris par le joueur
func nearest_agent(p: Vector3, max_dist: float) -> Dictionary:
	## Vehicule de la circulation le plus proche (portiere conducteur, a gauche), seulement s'il est arrete
	## ou au pas : on ne monte pas dans une voiture lancee.
	var best := {}
	var bd := max_dist
	for a in _agents:
		if not a.get("active", true) or a["speed"] > 4.0:
			continue
		var body: Node3D = a["body"]
		var left := -body.global_transform.basis.x
		var door: Vector3 = body.global_position + left * (1.0 if a["kind"] == "voiture" else 0.5)
		var d := p.distance_to(door)
		if d < bd:
			bd = d
			best = {"index": a["id"], "dist": d}
	return best


func take_over(i: int, by: Node3D) -> Node3D:
	## Le joueur prend ce vehicule : il sort de la circulation, un vehicule conduisible identique le remplace sur
	## place, et le conducteur (et son passager) est ejecte cote portiere. Un autre vehicule reapparaitra ailleurs.
	var a: Dictionary = _agents[i]
	var body: AnimatableBody3D = a["body"]
	var xf := Transform3D(Basis(Vector3.UP, a["vis_yaw"]), body.global_position + Vector3(0, 0.12, 0))
	a["active"] = false
	_release(a)
	body.visible = false
	body.collision_layer = 0
	(a["snd"] as AudioStreamPlayer3D).stop()
	var v := Vehicules.create(a["model"], a.get("color", Color.WHITE))
	v.transform = xf  # avant l'entree dans l'arbre : le vehicule part avec le bon cap
	get_parent().add_child(v)
	v.set("_yaw", a["vis_yaw"])
	v.set_meta("agent", i)   # le proprietaire peut venir le reprendre (pedestrians.gd)
	var left := -xf.basis.x
	var riders: Array = a.get("riders", [["homme" if _rng.randf() < 0.8 else "femme", ""]])
	for k in riders.size():
		var pos: Vector3 = xf.origin + left * (1.3 if a["kind"] == "voiture" else 0.9) - xf.basis.z * (0.6 * k)
		var r: Array = riders[k] if riders[k].size() > 2 else [riders[k][0], "", {}]
		driver_ejected.emit(pos, a["vis_yaw"], riders[k][0], by, r + [k])
	a["respawn"] = 25.0
	return v


## Phares des vehicules de la circulation (retour d'Olympe du 23/10/2026) : de vraies lumieres pour les plus proches de la
## camera la nuit, reaffectees cinq fois par seconde (les autres gardent seulement leurs glaces allumees, lampe.gdshader).
@export var phares_max := 12
@export var portee_phare_voiture := 60.0       # feu de croisement : 50 a 70 m utiles
@export var portee_phare_moto := 45.0
var _phares: Array[SpotLight3D] = []
var _phares_t := 0.0
var _jour_nuit: Node


func _maj_phares(delta: float) -> void:
	_phares_t -= delta
	if _phares_t > 0.0:
		return
	_phares_t = 0.2
	if _jour_nuit == null:
		_jour_nuit = get_parent().get_node_or_null("JourNuit")
	var nuit: float = float(_jour_nuit.get("night")) if _jour_nuit else 0.0
	if _phares.is_empty():
		for i in phares_max:
			var l := SpotLight3D.new()
			l.spot_angle = 27.0
			l.spot_attenuation = 0.8
			l.light_color = Color(1.0, 0.95, 0.82)
			l.shadow_enabled = false
			l.light_energy = 0.0
			l.visible = false
			add_child(l)
			_phares.append(l)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cand: Array = []
	if nuit > 0.05:
		for a in _agents:
			if not a.get("active", true):
				continue
			var d := cam.global_position.distance_squared_to((a["body"] as Node3D).global_position)
			if d < 120.0 * 120.0:
				cand.append([d, a])
		cand.sort_custom(func(x, y): return x[0] < y[0])
	for i in _phares.size():
		var l := _phares[i]
		if i >= cand.size():
			l.visible = false
			continue
		var a: Dictionary = cand[i][1]
		var body: Node3D = a["body"]
		var moto: bool = a["kind"] != "voiture"
		var fwd := -body.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var origine := body.global_position + fwd * (0.9 if moto else 2.0) + Vector3.UP * (0.95 if moto else 0.75)
		l.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3.RIGHT, -0.05), origine)
		l.spot_range = portee_phare_moto if moto else portee_phare_voiture
		l.light_energy = (6.0 if moto else 9.0) * nuit
		l.visible = true


func _process(delta: float) -> void:
	_maj_phares(delta)
	# les vehicules pris par le joueur sont remplaces, loin de lui, pour garder une circulation constante
	for a in _agents:
		if a.get("active", true) or not a.has("respawn"):
			continue
		a["respawn"] -= delta
		if a["respawn"] <= 0.0:
			a.erase("respawn")
			_place_random(a)
			a["speed"] = 0.0
			a["active"] = true
			var body: AnimatableBody3D = a["body"]
			body.global_position = a["vis_pos"]
			body.visible = true
			body.collision_layer = 1
			(a["snd"] as AudioStreamPlayer3D).play()


func _pgenre() -> String:
	return _player.get("genre") if _player and _player.get("genre") != null else "homme"


func alert(pos: Vector3, radius: float) -> void:
	## Accident a proximite : les vehicules autour s'arretent quelques secondes (et klaxonnent).
	for a in _agents:
		if a.get("active", true) and (a["vis_pos"] as Vector3).distance_to(pos) < radius:
			a["stunned"] = _rng.randf_range(3.0, 7.0)


func on_vehicle_hit(collider: Object, impact: float) -> void:
	## Le joueur a percute un vehicule de la circulation : il pile, klaxonne, le conducteur l'engueule.
	for a in _agents:
		if a["body"] == collider and a.get("active", true):
			_abimer(a, impact)
			a["stunned"] = _rng.randf_range(4.0, 8.0)
			a["speed"] = 0.0
			(a["horn"] as AudioStreamPlayer3D).play()
			Bulle.say(a["body"], Dialogues.pick("choc_voiture", _rng, _pgenre()), 3.0, 2.0)
			return


func _abimer(a: Dictionary, impact: float) -> void:
	## Les chocs abiment les vehicules de la circulation : fumee sous 40 %, feu sous 15 % puis explosion (feu_vehicule.gd).
	var body: Node3D = a["body"]
	a["pv"] = float(a.get("pv", 100.0)) - maxf(0.0, impact - 3.0) * 4.0
	if float(a["pv"]) < 40.0 and not a.has("fumee"):
		var f := FeuVehicule.flammes_moto(Vector3(0, 0.9, -1.2))
		(f[0] as GPUParticles3D).emitting = false
		a["fumee"] = f
		body.add_child(f[0])
		body.add_child(f[1])
		(f[1] as Light3D).light_energy = 0.0
	if float(a["pv"]) < 15.0 and not a.has("feu"):
		var f: Array = a["fumee"]
		(f[0] as GPUParticles3D).emitting = true
		a["feu"] = FeuVehicule.allumer(body, f[0], f[1], 9.0)


func reclaim(v: Node3D) -> bool:
	## Le proprietaire a repris son vehicule au joueur : il remonte dessus et repart dans la circulation.
	if not v.has_meta("agent"):
		return false
	var a: Dictionary = _agents[int(v.get_meta("agent"))]
	if a.get("active", true):
		return false   # deja remplace ailleurs dans la circulation
	var p := Vector2(v.global_position.x, v.global_position.z)
	var near: Dictionary = _carte.nearest_on_network(p)
	if near["edge"] < 0 or near["dist"] > 12.0:
		return false
	var ed: Dictionary = _carte.edges[near["edge"]]
	var yaw: float = v.rotation.y
	var from: int = ed["a"]
	var pts := _carte.edge_pts_from(near["edge"], from)
	# sens de la rue le plus proche du cap du vehicule
	if not ed["oneway"] and Vector2(-sin(yaw), -cos(yaw)).dot(pts[1] - pts[0]) < 0.0:
		from = ed["b"]
	_set_edge(a, near["edge"], from)
	var best_i := 0
	var bd := INF
	for i in a["pts"].size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, a["pts"][i], a["pts"][i + 1])
		if c.distance_to(p) < bd:
			bd = c.distance_to(p)
			best_i = i
			a["s"] = c.distance_to(a["pts"][i])
	a["i"] = best_i
	a["speed"] = 0.0
	a["vis_pos"] = Vector3(p.x, GROUND_Y, p.y)
	a["vis_yaw"] = yaw
	a.erase("respawn")
	a["active"] = true
	var body: AnimatableBody3D = a["body"]
	body.global_position = a["vis_pos"]
	body.visible = true
	body.collision_layer = 1
	(a["snd"] as AudioStreamPlayer3D).play()
	v.queue_free()
	return true


## Feux de freinage : deux lumignons rouges a l'arriere (un seul pour une moto), visibles quand le vehicule freine ou attend.
const FEU_HAUTEUR := {"veh_berline": 0.8, "veh_pejo": 0.86, "veh_mersede": 0.8, "veh_4x4": 1.0, "veh_minibus": 0.95,
	"veh_pickup": 0.9, "veh_camion": 1.0}
static var _feu_mesh: BoxMesh
static var _feu_mat: StandardMaterial3D


func _feux_stop(a: Dictionary, body: Node3D) -> void:
	if _feu_mesh == null:
		_feu_mat = StandardMaterial3D.new()
		_feu_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_feu_mat.albedo_color = Color(1.0, 0.08, 0.05)
		_feu_mat.emission_enabled = true
		_feu_mat.emission = Color(1.0, 0.05, 0.02)
		_feu_mat.emission_energy_multiplier = 2.5
		_feu_mesh = BoxMesh.new()
		_feu_mesh.size = Vector3(0.3, 0.13, 0.04)
		_feu_mesh.material = _feu_mat
	var feux := Node3D.new()
	feux.visible = false
	var pos: Vector3 = a["feu_ar"]
	for s in ([-1.0, 1.0] if a["kind"] == "voiture" else [0.0]):
		var m := MeshInstance3D.new()
		m.mesh = _feu_mesh
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visibility_range_end = 90.0
		m.position = Vector3(s * pos.x, pos.y, pos.z + 0.03)
		feux.add_child(m)
	body.add_child(feux)
	a["feux"] = feux
