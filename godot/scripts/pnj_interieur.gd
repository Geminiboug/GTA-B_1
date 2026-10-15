extends Node3D
## PNJ des lieux a interieur (scripts/lieux.gd) :
## - Ararat Hypermarket : clients qui vont de rayon en rayon panier a la main et s'arretent devant les etageres,
##   caissieres en tenue du magasin, clients en file aux caisses, vigile a l'entree, vendeuse a la boulangerie ;
## - terminal : voyageurs avec bagage, agents d'enregistrement aux comptoirs, voyageurs assis, files d'attente,
##   agents de securite au controle, serveuse au cafe.
## Les PNJ n'existent que quand le joueur est a moins de 90 m (performances) et sont crees quelques-uns par image
## (pas d'a-coup). Les personnages immobiles sont figes dans leur pose et fusionnes en un seul maillage chacun ;
## ceux qui marchent sont animes.

const ANIM := preload("res://scripts/character_anim.gd")
const ACTIVE_RANGE := 90.0
const BATCH := 4               # personnages crees par image

var _root: Node3D
var _key := ""
var _player: Node3D
var _rng := RandomNumberGenerator.new()
var _center := Vector3.ZERO
var _wp := PackedVector3Array()
var _adj: Array = []
var _spots := {}               # type -> [Transform3D]
var _walkers: Array = []
var _statics: Array = []
var _active := false
var _building := false
var _guards: Array = []        # vigiles (figes) qui interviennent a la voix

@export var flee_speed := 4.2       # m/s : client qui s'enfuit apres une bagarre
@export var panic_radius := 14.0    # m : rayon dans lequel les clients prennent peur
@export var notice_radius := 1.6    # m : un client frole par le joueur s'ecarte et le regarde


func setup(root: Node3D, key: String, player: Node3D) -> void:
	add_to_group("pnj_interieur")
	_root = root
	_key = key
	_player = player
	_rng.seed = hash(key)
	var n := 0
	for e in root.find_children("pnj_*", "Node3D", true, false):
		var name := String(e.name)
		var t: Transform3D = (e as Node3D).global_transform
		if name.begins_with("pnj_chemin"):
			_wp.append(t.origin)
		else:
			var kind := name.split("_")[1]
			if not _spots.has(kind):
				_spots[kind] = []
			_spots[kind].append(t)
		_center += t.origin
		n += 1
	if n > 0:
		_center /= n


func positions() -> Array:
	## Positions des PNJ qui marchent (pour les portes automatiques).
	var out := []
	for w in _walkers:
		out.append((w["node"] as Node3D).global_position)
	return out


func _physics_process(delta: float) -> void:
	if _player == null or _key == "maison" or _building:
		return
	var pv = _player.get("vehicle")
	var pp: Vector3 = (pv as Node3D).global_position if pv else _player.global_position
	var near := pp.distance_to(_center) < ACTIVE_RANGE
	if near and not _active:
		_activate()
	elif not near and _active:
		_deactivate()
	if _active:
		for w in _walkers:
			_walk(w, delta)


# ------------------------------------------------------------------ creation
func _look(ch: Node3D, kind: String) -> void:
	## Tenues de travail (magasin, compagnies aeriennes, securite) ou tenue au hasard pour les clients.
	var skin: Color = PnjUtil.SKINS[_rng.randi() % PnjUtil.SKINS.size()]
	var genre: String = ch.get_meta("genre", "homme")
	var look := {}
	match kind:
		"caisse":
			var green := PnjUtil.plain(Color(0.1, 0.5, 0.28) if _key == "ararat" else Color(0.85, 0.2, 0.12))
			look = {"skin": skin, "top": green, "legs": PnjUtil.plain(Color(0.12, 0.12, 0.14)), "cloth": PnjUtil.plain(Color(0.12, 0.12, 0.14)),
				"show": ["chr_haut", "chr_pantalon", "chr_chaussures", "chr_cheveux", "chr_chignon"] if genre == "femme" else ["chr_haut", "chr_pantalon", "chr_chaussures", "chr_cheveux"]}
		"vigile" when _key == "terminal":
			PnjUtil.apply(ch, PnjUtil.uniform_look("agent_aeroport", genre, _rng))   # surete de l'aeroport
			return
		"vigile":
			var navy := PnjUtil.plain(Color(0.1, 0.13, 0.22))
			look = {"skin": skin, "top": navy, "legs": navy, "cloth": navy, "cap": navy,
				"show": ["chr_haut_long", "chr_pantalon", "chr_chaussures", "chr_casquette"]}
		"comptoir":
			var blue := PnjUtil.plain(Color(0.08, 0.25, 0.55))
			look = {"skin": skin, "top": blue, "legs": PnjUtil.plain(Color(0.1, 0.1, 0.12)), "cloth": PnjUtil.wax(PnjUtil.WAX_PALETTES[2], 1),
				"show": ["chr_haut_long", "chr_pantalon", "chr_chaussures", "chr_foulard"] if genre == "femme" else ["chr_haut_long", "chr_pantalon", "chr_chaussures", "chr_cheveux"]}
		_:
			PnjUtil.dress_random(ch, _rng)
			return
	look["face"] = PnjUtil.random_face(_rng)   # le personnel n'a plus tous le meme visage
	PnjUtil.apply(ch, look)


func _make(kind: String, genre: String) -> Node3D:
	var ch := PnjUtil.make(PnjUtil.random_variant(_rng, genre, 0.08 if kind in ["client", "voyageur", "file", "assis"] else 0.0))
	add_child(ch)
	_look(ch, kind)
	ch.scale = Vector3.ONE
	return ch


func _carry(ch: Node3D, what: String) -> void:
	## Panier (magasin) ou sac de voyage (terminal) tenu dans la main droite.
	var skel := Squelette.find(ch)
	if skel == null:
		return
	var ba := BoneAttachment3D.new()
	ba.bone_name = Squelette.bone_name(skel, "piv_main_D")
	skel.add_child(ba)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var m := StandardMaterial3D.new()
	if what == "panier":
		bm.size = Vector3(0.36, 0.2, 0.24)
		m.albedo_color = Color(0.8, 0.12, 0.1)
	else:
		bm.size = Vector3(0.42, 0.3, 0.16)
		m.albedo_color = [Color(0.1, 0.1, 0.12), Color(0.25, 0.15, 0.4), Color(0.45, 0.3, 0.18)][_rng.randi() % 3]
	m.roughness = 0.6
	bm.material = m
	mi.mesh = bm
	mi.position = Vector3(0, 0.18, 0.02)
	ba.add_child(mi)


func _activate() -> void:
	_active = true
	_building = true
	if _adj.is_empty() and _wp.size() > 0:
		_build_graph()
	# personnages immobiles : poses puis figes (fusion apres application de la pose)
	var posed: Array = []
	var plan := []
	for t in _spots.get("caisse", []):
		plan.append(["caisse", t, "debout", "femme" if _rng.randf() < 0.75 else "homme"])
	for t in _spots.get("vigile", []):
		plan.append(["vigile", t, "debout", "homme"])
	for t in _spots.get("comptoir", []):
		plan.append(["comptoir", t, "debout", "femme" if _rng.randf() < 0.6 else "homme"])
	for t in _spots.get("file", []):
		if _rng.randf() < 0.55:
			plan.append(["file", t, "debout", PnjUtil.random_genre(_rng)])
	for t in _spots.get("assis", []):
		if _rng.randf() < 0.7:
			plan.append(["assis", t, "assis", PnjUtil.random_genre(_rng)])
	var i0 := 0
	while i0 < plan.size():
		posed.clear()
		for p in plan.slice(i0, i0 + BATCH):
			var ch := _make(p[0], p[3])
			var t: Transform3D = p[1]
			if p[2] == "assis":
				PnjUtil.pose_seated(ch)
				ch.global_transform = Transform3D(t.basis, t.origin + Vector3(0, 0.45 - (0.89 if ch.get_meta("genre") == "homme" else 0.85), 0))
			else:
				Squelette.pose(ch, {"piv_epaule_G": 0.08, "piv_epaule_D": 0.08, "piv_coude_G": 0.25, "piv_coude_D": 0.25})
				ch.global_transform = t
			if p[0] == "file" and _key == "terminal":
				_suitcase_at(t)
			if p[0] == "vigile":
				ch.set_meta("vigile", true)
			posed.append(ch)
		i0 += BATCH
		# la pose n'est appliquee au maillage que deux images plus tard
		await get_tree().process_frame
		await get_tree().process_frame
		if not _active:
			for ch in posed:
				ch.queue_free()
			_building = false
			return
		for ch in posed:
			var mesh := PnjUtil.merge(ch)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.visibility_range_end = 70.0
			add_child(mi)
			mi.global_transform = ch.global_transform
			_statics.append(mi)
			if ch.has_meta("vigile"):
				_guards.append(mi)
			ch.queue_free()
	# personnages qui marchent
	var count := 14 if _key == "ararat" else 12
	for i in count:
		if _wp.size() < 2:
			break
		var genre := "femme" if _rng.randf() < (0.65 if _key == "ararat" else 0.45) else "homme"
		var ch := PnjUtil.make(PnjUtil.random_variant(_rng, genre, 0.08))
		var metas := {"genre": ch.get_meta("genre"), "age": ch.get_meta("age")}
		ch.set_script(ANIM)
		for m in metas:
			ch.set_meta(m, metas[m])
		add_child(ch)
		PnjUtil.dress_random(ch, _rng)
		_carry(ch, "panier" if _key == "ararat" else "sac")
		var start := _rng.randi() % _wp.size()
		ch.global_position = _wp[start]
		_walkers.append({"node": ch, "at": start, "to": start, "pause": _rng.randf_range(0.0, 4.0), "speed": _rng.randf_range(1.0, 1.35), "yaw": 0.0})
		if i % 2 == 1:
			await get_tree().process_frame
			if not _active:
				_building = false
				return
	_building = false


func _suitcase_at(t: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.visibility_range_end = 70.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.62, 0.26)
	var m := StandardMaterial3D.new()
	m.albedo_color = [Color(0.1, 0.1, 0.12), Color(0.55, 0.1, 0.1), Color(0.1, 0.3, 0.5)][_rng.randi() % 3]
	bm.material = m
	mi.mesh = bm
	add_child(mi)
	mi.global_position = t.origin + t.basis.x * 0.45 + Vector3(0, 0.31, 0)
	mi.global_rotation.y = t.basis.get_euler().y
	_statics.append(mi)


func _deactivate() -> void:
	_active = false
	for w in _walkers:
		(w["node"] as Node).queue_free()
	_walkers.clear()
	for s in _statics:
		(s as Node).queue_free()
	_statics.clear()
	_guards.clear()


func _build_graph() -> void:
	## Chemins : deux reperes sont relies s'ils sont proches et qu'aucun mur ou meuble ne les separe.
	var space := get_world_3d().direct_space_state
	_adj.resize(_wp.size())
	for i in _wp.size():
		_adj[i] = []
	for i in _wp.size():
		for j in range(i + 1, _wp.size()):
			if _wp[i].distance_to(_wp[j]) > 9.5:
				continue
			var q := PhysicsRayQueryParameters3D.create(_wp[i] + Vector3(0, 0.9, 0), _wp[j] + Vector3(0, 0.9, 0))
			q.collision_mask = 1
			if space.intersect_ray(q).is_empty():
				_adj[i].append(j)
				_adj[j].append(i)


# ------------------------------------------------------------------ marche et reactions
func _walk(w: Dictionary, delta: float) -> void:
	var ch: Node3D = w["node"]
	var speed := 0.0
	var tilt := 0.0
	var st: String = w.get("state", "walk")
	w["t"] = w.get("t", 0.0) + delta
	w["talk_cd"] = w.get("talk_cd", 0.0) - delta
	var pp := _player.global_position
	var rel := pp - ch.global_position
	rel.y = 0.0
	match st:
		"down":
			# au sol apres un coup, puis se releve et s'enfuit
			var t: float = w["t"]
			if t < 0.4:
				tilt = smoothstep(0.0, 0.4, t)
				ch.global_position += w["push"] * delta * (1.0 - t / 0.4)
			elif t < 1.6:
				tilt = 1.0
			elif t < 2.4:
				tilt = 1.0 - smoothstep(1.6, 2.4, t)
			else:
				_flee(w)
		"flee":
			# court vers le repere voisin le plus eloigne du joueur, par le graphe (pas a travers les rayons)
			speed = flee_speed
			if _go(w, speed, delta) and w["t"] < 8.0:
				_pick_away(w)
			elif w["t"] >= 8.0:
				w["state"] = "walk"
				w["pause"] = _rng.randf_range(2.0, 4.0)
		"stare":
			# frole par le joueur : s'arrete, le regarde, une remarque
			w["yaw"] = lerp_angle(w["yaw"], atan2(-rel.x, -rel.z), 1.0 - exp(-8.0 * delta))
			if w["t"] > 1.6:
				w["state"] = "walk"
		_:
			if rel.length() < notice_radius and _player.get("vehicle") == null and w["talk_cd"] <= 0.0:
				w["state"] = "stare"
				w["t"] = 0.0
				w["talk_cd"] = 8.0
				Bulle.say(ch, Dialogues.pick("croise", _rng, String(_player.get("genre"))), 2.0, 2.05)
			elif w["pause"] > 0.0:
				w["pause"] -= delta
			else:
				speed = w["speed"]
				if _go(w, speed, delta):
					var nb: Array = _adj[w["at"]] if _adj.size() > w["at"] else []
					if nb.is_empty():
						w["pause"] = 3.0
					else:
						w["to"] = nb[_rng.randi() % nb.size()]
						# on s'arrete regarder les rayons, la vitrine, le tableau des departs
						if _rng.randf() < 0.45:
							w["pause"] = _rng.randf_range(1.5, 6.0)
	var basis := Basis(Vector3.UP, w["yaw"]) * Basis(Vector3.RIGHT, tilt * PI * 0.5)
	ch.global_transform = Transform3D(basis, Vector3(ch.global_position.x, w.get("floor_y", ch.global_position.y), ch.global_position.z) + Vector3(0, 0.13 * tilt, 0))
	ch.set("speed", speed)
	ch.set("on_floor", true)


func _go(w: Dictionary, speed: float, delta: float) -> bool:
	## Avance vers le repere vise ; vrai a l'arrivee.
	var ch: Node3D = w["node"]
	if not w.has("floor_y"):
		w["floor_y"] = ch.global_position.y
	var d: Vector3 = _wp[w["to"]] - ch.global_position
	d.y = 0.0
	if d.length() < 0.25:
		w["at"] = w["to"]
		return true
	ch.global_position += d.normalized() * minf(speed * delta, d.length())
	w["yaw"] = lerp_angle(w["yaw"], atan2(-d.x, -d.z), 1.0 - exp(-(10.0 if speed > 3.0 else 6.0) * delta))
	return false


func _pick_away(w: Dictionary) -> void:
	var nb: Array = _adj[w["at"]] if _adj.size() > w["at"] else []
	var best: int = w["at"]
	var bd := -1.0
	for j in nb:
		var dd: float = _wp[j].distance_to(_player.global_position)
		if dd > bd:
			bd = dd
			best = j
	w["to"] = best


func _flee(w: Dictionary) -> void:
	w["state"] = "flee"
	w["t"] = 0.0
	w["pause"] = 0.0
	# repart du repere le plus proche
	var p: Vector3 = (w["node"] as Node3D).global_position
	var bi: int = w["at"]
	for i in _wp.size():
		if _wp[i].distance_to(p) < _wp[bi].distance_to(p):
			bi = i
	w["at"] = bi
	w["to"] = bi
	_pick_away(w)


func player_attack(origin: Vector3, dir: Vector3) -> bool:
	## Coup du joueur dans le magasin ou l'aerogare : la personne touchee tombe, les clients proches
	## s'enfuient en criant, le vigile intervient a la voix.
	if not _active:
		return false
	var best: Dictionary = {}
	var bd := 1.5
	for w in _walkers:
		var rel: Vector3 = (w["node"] as Node3D).global_position - origin
		rel.y = 0.0
		if rel.length() < bd and rel.normalized().dot(dir) > 0.4 and w.get("state", "walk") != "down":
			bd = rel.length()
			best = w
	if best.is_empty():
		return false
	best["state"] = "down"
	best["t"] = 0.0
	best["push"] = Vector3(dir.x, 0.0, dir.z) * 2.5
	Bulle.say(best["node"], Dialogues.pick("frappe", _rng, String(_player.get("genre"))), 2.5, 0.7)
	for w in _walkers:
		if w != best and (w["node"] as Node3D).global_position.distance_to(origin) < panic_radius:
			_flee(w)
			if _rng.randf() < 0.3:
				Bulle.say(w["node"], Dialogues.pick("fuite", _rng, String(_player.get("genre"))), 2.0, 2.05)
	for g in _guards:
		if (g as Node3D).global_position.distance_to(origin) < 40.0:
			Bulle.say(g, Dialogues.pick("vigile", _rng, String(_player.get("genre"))), 3.0, 2.1)
	return true
