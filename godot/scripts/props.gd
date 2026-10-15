extends Node3D
## Mobilier urbain, commerces de rue, vehicules gares, enseignes et avions, places au lancement a partir
## des donnees reelles de la zone (godot/assets/data/zone_aeroport.json, genere par osm_import.py).
## Deterministe (seed) : la ville est la meme a chaque partie. Rendu en MultiMesh decoupes par quartiers
## (pour que les objets lointains ne soient pas affiches) + collisions simples.
## Tous les noms d'enseignes et de marques sont FICTIFS (voir docs/LEGAL.md).

@export var props_scene: PackedScene = preload("res://assets/models/props.glb")
@export var zem_scene: PackedScene = preload("res://assets/models/veh_zem.glb")
@export var seed_value := 229
@export var chunk_size := 80.0   # petits quartiers : un objet ne disparait pas trop pres (distance mesuree au centre du groupe)

const SHOP_NAMES := [
	"BOUTIQUE LA GRACE DE DIEU", "COIFFURE DIEU EST GRAND", "QUINCAILLERIE LE BON BERGER",
	"ATELIER DE COUTURE MAMAN CHERIE", "VULCANISATEUR", "ALIMENTATION GENERALE", "SOUDURE ET FERRONNERIE",
	"PRESSING LA PROPRETE", "MAQUIS CHEZ TANTIE ROSE", "BAR LA DETENTE", "ECOLE PRIVEE LES ETOILES",
	"CENTRE DE SANTE ESPOIR", "ELECTRICITE BATIMENT", "MENUISERIE LE CHARPENTIER", "SALON DE BEAUTE GBE",
	"DEPOT DE BOISSONS", "PHOTO STUDIO SOURIRE", "CYBER CAFE LE NAVIGATEUR", "RESTAURANT CHEZ MAMI",
	"GARAGE AUTO L'AMITIE", "IMPRIMERIE LE SCRIBE", "TAILLEUR LE GRAND BOUBOU", "VENTE DE PAGNES",
	"AGENCE IMMOBILIERE LE TOIT", "PHARMACIE DU LITTORAL", "BOULANGERIE LE BON PAIN", "QUINCAILLERIE LA PERSEVERANCE",
	"COIFFURE MIXTE LE PRESTIGE", "CABINET MEDICAL LA GUERISON", "SECRETARIAT PUBLIC", "AUTO-ECOLE LE VOLANT",
]
const WALL_TEXTS := ["DEFENSE D'URINER ICI", "CE TERRAIN N'EST PAS A VENDRE", "A VENDRE", "INTERDIT DE DEPOSER LES ORDURES",
	"STATIONNEMENT INTERDIT", "A LOUER", "DIEU EST FIDELE"]
const ADS := [
	["GBE COLA", "La fraicheur du pays", Color(0.75, 0.08, 0.08), Color(1, 1, 1)],
	["ZEM : PORTEZ VOTRE CASQUE", "Securite routiere - c'est la vie", Color(0.95, 0.75, 0.1), Color(0.05, 0.05, 0.05)],
	["BANQUE OCEANIQUE", "Votre avenir commence ici", Color(0.05, 0.25, 0.55), Color(1, 1, 1)],
	["ARARAT HYPERMARKET", "Tout sous un meme toit", Color(0.1, 0.45, 0.2), Color(1, 1, 1)],
	["RADIO LITTORAL 98.6", "La voix de Cotonou", Color(0.45, 0.1, 0.5), Color(1, 0.9, 0.2)],
	["SAVON KOTO", "Propre comme jamais", Color(0.2, 0.55, 0.85), Color(1, 1, 1)],
	["CIMENT SOLIDE", "Batissez pour vos enfants", Color(0.35, 0.35, 0.38), Color(1, 0.85, 0.1)],
]
const SIGN_COLORS := [Color(0.85, 0.1, 0.1), Color(0.1, 0.3, 0.7), Color(0.95, 0.8, 0.1), Color(0.1, 0.5, 0.2),
	Color(0.95, 0.95, 0.92), Color(0.1, 0.1, 0.1), Color(0.95, 0.45, 0.1)]
const CAR_COLORS := [Color(0.92, 0.92, 0.9), Color(0.92, 0.92, 0.9), Color(0.92, 0.92, 0.9), Color(0.7, 0.71, 0.72),
	Color(0.7, 0.71, 0.72), Color(0.08, 0.08, 0.09), Color(0.1, 0.18, 0.4), Color(0.55, 0.08, 0.06), Color(0.75, 0.68, 0.55),
	Color(0.15, 0.35, 0.2)]

var _rng := RandomNumberGenerator.new()
var _carte: Carte
var _meshes := {}
var _chunks := {}         # "kind|cx|cz" -> {"kind", "xf": [], "col": []}
var _occupied := {}       # grille 2 m -> true (evite les superpositions)
var _bodies: StaticBody3D
var _wire_pts := PackedVector3Array()
var _roads: Array = []
var _signs: Node3D
var counts := {}
var lamp_positions := PackedVector3Array()
const CAR_KINDS := ["veh_berline", "veh_4x4", "veh_minibus"]
var _chunk_nodes := {}
var parked: Array = []                      # voitures garees {model, xf, color} (conduites par le joueur)
var vendor_spots: Array[Transform3D] = []   # tabourets / chaises ou s'assoient les vendeurs (pedestrians.gd)
var placed := false
signal placement_done  # tetes de lampadaires (lues par day_night.gd pour l'eclairage de nuit)

const VIS := {"prop_poteau": 450.0, "prop_poteau_transfo": 450.0, "prop_lampadaire": 450.0, "veh_berline": 300.0,
	"veh_4x4": 300.0, "veh_minibus": 300.0, "veh_avion": 1500.0, "prop_panneau_pub": 600.0, "zem_gare": 200.0}


func _ready() -> void:
	_rng.seed = seed_value
	_load_meshes()
	_carte = Carte.zone()
	var data: Dictionary = _carte.data
	_roads = data["roads"]
	_bodies = StaticBody3D.new()
	_bodies.name = "Collisions"
	add_child(_bodies)
	_signs = Node3D.new()
	_signs.name = "Enseignes"
	add_child(_signs)
	# attendre que les collisions de la carte soient enregistrees avant les requetes physiques
	await get_tree().physics_frame
	await get_tree().physics_frame
	# avions aux postes : geres par air_traffic.gd (gares, departs, arrivees)
	_place_billboards()  # en premier : ils ont besoin de place
	_place_poles_and_lamps()
	_place_promenade_lamps(data.get("promenade", []))
	_place_roadside()
	_place_shop_signs(data["buildings"])
	_place_wall_texts(data.get("walls", []))
	_build()
	placed = true
	placement_done.emit()
	print("Props : ", counts)


# ---------------------------------------------------------------- chargement
func _load_meshes() -> void:
	var inst := props_scene.instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		_meshes[String(mi.name)] = mi.mesh
	inst.free()
	# carrosserie et parasols teintes par instance (couleur MultiMesh)
	# vehicules gares : memes modeles detailles que les vehicules conduisibles (Vehicules.merged)
	for k in CAR_KINDS:
		_meshes[k] = _tintable(Vehicules.merged(k), "mat_carrosserie")
	if _meshes.has("prop_lampadaire"):
		_meshes["prop_lampadaire"] = _night_lamp(_meshes["prop_lampadaire"])
	_meshes["zem_gare"] = _merge_scene(zem_scene)


func _tintable(mesh: Mesh, mat_name: String) -> Mesh:
	var m := mesh.duplicate() as Mesh
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s)
		if mat and mat.resource_name == mat_name and mat is BaseMaterial3D:
			var d := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			d.vertex_color_use_as_albedo = true
			d.albedo_color = Color.WHITE
			m.surface_set_material(s, d)
	return m


func _night_lamp(mesh: Mesh) -> Mesh:
	var m := mesh.duplicate() as Mesh
	for s in m.get_surface_count():
		var mat := m.surface_get_material(s)
		if mat and mat.resource_name == "mat_lampe":
			m.surface_set_material(s, load("res://shaders/lampe_material.tres"))
	return m


func _merge_scene(scene: PackedScene) -> ArrayMesh:
	## Fusionne toutes les pieces d'une scene (ex : le zem) en un seul mesh, un surface par materiau.
	var inst := scene.instantiate() as Node3D
	add_child(inst)
	var tools := {}
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var xf: Transform3D = inst.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			var key := mat.resource_name if mat else "aucun"
			if not tools.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mat)
				tools[key] = st
			(tools[key] as SurfaceTool).append_from(mi.mesh, s, xf)
	var out := ArrayMesh.new()
	for key in tools:
		(tools[key] as SurfaceTool).commit(out)
	inst.queue_free()
	return out


# ---------------------------------------------------------------- outils
func _v2(p) -> Vector2:
	return Vector2(float(p[0]), float(p[1]))


func _walk(pts: Array, spacing: float, start: float, cb: Callable) -> void:
	## Appelle cb(position 2D, direction 2D, index) tous les 'spacing' metres le long d'une polyligne.
	var acc := start
	var k := 0
	for i in range(pts.size() - 1):
		var a := _v2(pts[i])
		var b := _v2(pts[i + 1])
		var seg := a.distance_to(b)
		if seg < 0.01:
			continue
		while acc <= seg:
			cb.call(a.lerp(b, acc / seg), (b - a) / seg, k)
			k += 1
			acc += spacing
		acc -= seg


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))


func _is_free(p: Vector2, radius: float) -> bool:
	var c := _cell(p)
	var r := int(ceil(radius / 2.0))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if _occupied.has(c + Vector2i(dx, dz)):
				return false
	return true


func _occupy(p: Vector2, radius: float) -> void:
	var c := _cell(p)
	var r := int(ceil(radius / 2.0))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			_occupied[c + Vector2i(dx, dz)] = true


const AVOID_LAYER := 1 << 9
const NEVER_ON := ["aeroport_", "zone_piscine", "zone_eau", "zone_parking", "plage", "zone_plage", "promenade", "piste_cyclable"]


func _ground(p: Vector2, radius: float, allow_roads := false, allow_front := false) -> float:
	## Hauteur du sol si l'endroit est libre (pas dans un batiment, un mur, un arbre, ni sur le tarmac,
	## une piscine, la plage ; ni sur une route sauf si allow_roads), sinon NAN.
	var space := get_world_3d().direct_space_state
	var ray2 := PhysicsRayQueryParameters3D.create(Vector3(p.x, 5, p.y), Vector3(p.x, -2, p.y))
	ray2.collision_mask = AVOID_LAYER
	var hit2 := space.intersect_ray(ray2)
	if not hit2.is_empty():
		var sn := String(hit2.collider.name).to_lower()
		for prefix in NEVER_ON:
			if allow_front and prefix in ["plage", "promenade", "piste_cyclable"]:
				continue  # lampadaires et poteaux du front de mer : poses sur la promenade, c'est normal
			if sn.begins_with(prefix):
				return NAN
		if not allow_roads and sn.begins_with("route_"):
			return NAN
	# l'objet entier (pas seulement son centre) doit rester hors de la chaussee
	if not allow_roads and _carte.on_carriageway(p, radius):
		return NAN
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, 60, p.y), Vector3(p.x, -5, p.y))
	ray.collision_mask = 1  # decor seulement (pas les surfaces a eviter de la couche 10)
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return NAN
	var owner_name := String(hit.collider.get_parent().name).to_lower()
	if not owner_name.begins_with("sol_terre"):
		return NAN
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, hit.position.y + radius + 0.25, p.y))
	q.collision_mask = 1
	if not space.intersect_shape(q, 1).is_empty():
		return NAN
	return hit.position.y


func _add(kind: String, xf: Transform3D, color := Color.WHITE) -> Array:
	## Ajoute une instance ; renvoie [groupe, index] (pour pouvoir la retirer, ex. voiture prise par le joueur).
	if not _meshes.has(kind):
		return []
	var key := "%s|%d|%d" % [kind, floori(xf.origin.x / chunk_size), floori(xf.origin.z / chunk_size)]
	if not _chunks.has(key):
		_chunks[key] = {"kind": kind, "xf": [], "col": []}
	_chunks[key]["xf"].append(xf)
	_chunks[key]["col"].append(color)
	counts[kind] = counts.get(kind, 0) + 1
	return [key, _chunks[key]["xf"].size() - 1]


func _box_col(xf: Transform3D, size: Vector3, center_y: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.transform = xf * Transform3D(Basis.IDENTITY, Vector3(0, center_y, 0))
	_bodies.add_child(cs)
	return cs


func _cyl_col(pos: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	cs.shape = c
	cs.position = pos + Vector3(0, h / 2.0, 0)
	_bodies.add_child(cs)


func _facing(dir2: Vector2) -> Basis:
	## Base dont l'avant (-Z, = +Y Blender) regarde dans la direction donnee.
	return Basis.looking_at(Vector3(dir2.x, 0, dir2.y), Vector3.UP)


# ---------------------------------------------------------------- reseau electrique et eclairage
func _place_poles_and_lamps() -> void:
	for r in _roads:
		var kind: String = r["kind"]
		if kind in ["footway", "path", "pedestrian", "track"]:
			continue
		var w: float = r["width"]
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		# etat partage avec la fonction anonyme (les lambdas GDScript copient les variables locales)
		var state := {"prev": []}
		var pts: Array = r["pts"]
		# poteaux bois tous les ~35 m d'un cote, cables entre eux
		_walk(pts, 35.0, _rng.randf_range(2.0, 20.0), func(p: Vector2, t: Vector2, _k: int) -> void:
			# cote habituel, sinon l'autre cote (chaussees separees : on evite l'autre voie)
			var pos := Vector2.ZERO
			var y := NAN
			for s in [side, -side]:
				pos = p + Vector2(-t.y, t.x) * s * (w / 2.0 + 1.4)
				y = _ground(pos, 0.3, false, true)
				if not is_nan(y) and _is_free(pos, 1.0):
					break
				y = NAN
			if is_nan(y):
				state["prev"] = []
				return
			_occupy(pos, 1.0)
			var xf := Transform3D(_facing(t), Vector3(pos.x, y, pos.y))
			_add("prop_poteau_transfo" if _rng.randf() < 0.08 else "prop_poteau", xf)
			_cyl_col(xf.origin, 0.16, 9.0)
			var attach := []
			for x in [-0.75, 0.0, 0.75]:
				attach.append(xf * Vector3(x, 8.55, 0))
			var prev: Array = state["prev"]
			if prev.size() == 3:
				for i in 3:
					_wire(prev[i], attach[i])
			state["prev"] = attach
		)
		# lampadaires sur les grands axes, en quinconce
		if kind in ["primary", "secondary"] and r["surface"] == "bitume":
			_walk(pts, 32.0, _rng.randf_range(5.0, 15.0), func(p: Vector2, t: Vector2, k: int) -> void:
				var s0 := 1.0 if k % 2 == 0 else -1.0
				var n := Vector2.ZERO
				var pos := Vector2.ZERO
				var y := NAN
				for s in [s0, -s0]:
					n = Vector2(-t.y, t.x) * s
					pos = p + n * (w / 2.0 + 0.9)
					y = _ground(pos, 0.3, false, true)
					if not is_nan(y) and _is_free(pos, 1.0):
						break
					y = NAN
				if is_nan(y):
					return
				_occupy(pos, 1.0)
				var xf := Transform3D(_facing(-n), Vector3(pos.x, y, pos.y))
				_add("prop_lampadaire", xf)
				_cyl_col(xf.origin, 0.2, 8.5)
				lamp_positions.append(xf * Vector3(0, 8.1, -1.75))
			)


func _place_promenade_lamps(prom: Array) -> void:
	if prom.size() < 2:
		return
	_walk(prom, 25.0, 6.0, func(p: Vector2, t: Vector2, _k: int) -> void:
		var n := Vector2(-t.y, t.x)
		if n.y > 0.0:
			n = -n  # cote terre (nord = -Z)
		var pos := p + n * 4.8
		var y := _ground(pos, 0.3)
		if is_nan(y):
			y = 0.0
		var xf := Transform3D(_facing(-n), Vector3(pos.x, y + 0.016, pos.y))
		_add("prop_lampadaire", xf)
		_cyl_col(xf.origin, 0.2, 8.5)
		lamp_positions.append(xf * Vector3(0, 8.1, -1.75))
	)


func _wire(a: Vector3, b: Vector3) -> void:
	## Cable electrique : chainette approchee par une parabole (fleche ~ 1,5 % de la portee).
	var sag := 0.25 + a.distance_to(b) * 0.015
	var steps := 8
	var prev := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		_wire_pts.append(prev)
		_wire_pts.append(p)
		prev = p


# ---------------------------------------------------------------- commerces et vehicules de bord de route
func _place_roadside() -> void:
	# [type, rayon libre, proba axes bitumes, proba rues de quartier]
	var table := [
		["prop_kpayo", 1.0, 0.045, 0.012],
		["prop_etal", 1.6, 0.05, 0.03],
		["prop_ordures", 1.4, 0.012, 0.035],
		["prop_pneus", 1.0, 0.015, 0.008],
		["prop_maquis", 1.4, 0.02, 0.015],
		["prop_cabine", 1.2, 0.02, 0.01],
		["voiture", 2.4, 0.05, 0.07],
		["zems", 1.6, 0.04, 0.02],
	]
	for r in _roads:
		var kind: String = r["kind"]
		if kind in ["footway", "path", "pedestrian"]:
			continue
		var big := kind in ["primary", "secondary", "tertiary"]
		var w: float = r["width"]
		_walk(r["pts"], 9.0, _rng.randf_range(0.0, 9.0), func(p: Vector2, t: Vector2, _k: int) -> void:
			var roll := _rng.randf()
			var acc := 0.0
			for row in table:
				acc += row[2] if big else row[3]
				if roll < acc:
					_place_one(row[0], row[1], p, t, w)
					return
		)


func _footprint_ok(pos: Vector2, dir: Vector2, half_w: float, half_l: float) -> bool:
	## Les 4 coins et le centre d'un objet allonge (voiture) sont hors chaussee et hors batiment.
	var side := Vector2(-dir.y, dir.x)
	for c in [Vector2.ZERO, dir * half_l + side * half_w, dir * half_l - side * half_w, -dir * half_l + side * half_w,
			-dir * half_l - side * half_w]:
		var q: Vector2 = pos + c
		if _carte.on_carriageway(q, 0.2) or _carte.in_building(q) or not _carte.in_bounds(q):
			return false
	return true


func _place_one(kind: String, radius: float, p: Vector2, t: Vector2, w: float) -> void:
	# bord de route : trottoir / bande de marche jusqu'a ~2 m du bord de chaussee (pietons, poteaux),
	# puis la bande ou l'on se gare et ou s'installent les commerces
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var n := Vector2(-t.y, t.x) * side
	if kind == "voiture":
		# garee sur le bas-cote, parallele a la rue, jamais sur la chaussee
		for s in [n, -n]:
			var pos: Vector2 = p + s * (w / 2.0 + 3.2)
			var y := _ground(pos, 0.9)
			if is_nan(y) or not _is_free(pos, radius) or not _footprint_ok(pos, t, 1.0, 2.4):
				continue
			_occupy(pos, radius)
			var dir := t if _rng.randf() < 0.5 else -t
			var r := _rng.randf()
			var model := "veh_berline" if r < 0.62 else ("veh_4x4" if r < 0.88 else "veh_minibus")
			var xf := Transform3D(_facing(dir), Vector3(pos.x, y, pos.y))
			var col: Color = CAR_COLORS[_rng.randi() % CAR_COLORS.size()]
			var slot := _add(model, xf, col)
			var aabb: AABB = _meshes[model].get_aabb()
			var cs := _box_col(xf, Vector3(aabb.size.x - 0.15, aabb.size.y - 0.04, aabb.size.z - 0.1), aabb.position.y + 0.02 + (aabb.size.y - 0.04) / 2.0)
			parked.append({"model": model, "xf": xf, "color": col, "slot": slot, "shape": cs})
			return
		return
	var dist := w / 2.0 + _rng.randf_range(2.6, 3.8)
	var pos := p + n * dist
	var y := _ground(pos, radius * 0.6)
	if is_nan(y) or not _is_free(pos, radius):
		n = -n
		pos = p + n * dist
		y = _ground(pos, radius * 0.6)
		if is_nan(y) or not _is_free(pos, radius):
			return
	_occupy(pos, radius)
	var basis := _facing(-n)  # face a la route
	if kind == "zems":
		# station de zems : 2 a 4 motos garees en epi, legerement penchees sur la bequille
		var count := _rng.randi_range(2, 4)
		for i in count:
			var q := pos + t * (i - count / 2.0) * 0.95
			var b := _facing(-n.rotated(_rng.randf_range(-0.3, 0.3))) * Basis(Vector3(0, 0, 1), 0.1)
			var zxf := Transform3D(b, Vector3(q.x, y, q.y))
			parked.append({"model": "zem", "xf": zxf, "color": Color.WHITE, "slot": _add("zem_gare", zxf), "shape": null})
			_occupy(q, 1.0)
		return
	if kind == "prop_etal":
		kind = ["prop_etal_rouge", "prop_etal_jaune", "prop_etal_bleu"][_rng.randi() % 3]
	var xf := Transform3D(basis.rotated(Vector3.UP, _rng.randf_range(-0.25, 0.25)), Vector3(pos.x, y, pos.y))
	_add(kind, xf)
	# vendeur assis sur le tabouret, face a la route (positions locales du modele, Godot = Blender (x, z, -y))
	if kind == "prop_kpayo":
		vendor_spots.append(xf * Transform3D(Basis.IDENTITY, Vector3(-0.85, 0, 0.3)))
	elif kind.begins_with("prop_etal"):
		vendor_spots.append(xf * Transform3D(Basis.IDENTITY, Vector3(0.3, 0, 0.45)))
	elif kind == "prop_maquis" and _rng.randf() < 0.7:
		vendor_spots.append(xf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.85)))
		if _rng.randf() < 0.5:
			vendor_spots.append(xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(0.85, 0, 0)))
	if kind == "prop_cabine":
		_box_col(xf, Vector3(1.6, 2.3, 1.3), 1.15)
		_label(xf * Transform3D(Basis.IDENTITY, Vector3(0, 1.85, -0.7)), "TRANSFERT D'ARGENT - CREDIT", 1.4, Color(0.1, 0.1, 0.1))
	elif kind.begins_with("prop_etal") or kind == "prop_maquis" or kind == "prop_kpayo":
		_box_col(xf, Vector3(1.2, 0.8, 0.8), 0.4)
	elif kind == "prop_pneus":
		_cyl_col(xf.origin, 0.4, 0.8)


func _place_billboards() -> void:
	var ad_i := 0
	for r in _roads:
		if r["kind"] not in ["primary", "secondary"]:
			continue
		var w: float = r["width"]
		_walk(r["pts"], 140.0, _rng.randf_range(30.0, 100.0), func(p: Vector2, t: Vector2, _k: int) -> void:
			var side := 1.0 if _rng.randf() < 0.5 else -1.0
			var n := Vector2(-t.y, t.x) * side
			var pos := p + n * (w / 2.0 + 5.5)
			var y := _ground(pos, 1.2)
			if is_nan(y) or not _is_free(pos, 3.5):
				return
			_occupy(pos, 3.5)
			# l'affiche regarde la route, legerement orientee vers les vehicules qui arrivent
			var xf := Transform3D(_facing(-n.rotated(0.35 * side)), Vector3(pos.x, y, pos.y))
			_add("prop_panneau_pub", xf)
			_box_col(xf, Vector3(4.6, 5.6, 0.4), 2.8)
			var ad: Array = ADS[ad_i % ADS.size()]
			ad_i += 1
			var face := xf * Transform3D(Basis.IDENTITY, Vector3(0, 5.5, -0.04))
			_panel(face, Vector2(6.0, 2.9), ad[2])
			_label(face * Transform3D(Basis.IDENTITY, Vector3(0, 0.45, -0.02)), ad[0], 5.4, ad[3], 0.9)
			_label(face * Transform3D(Basis.IDENTITY, Vector3(0, -0.6, -0.02)), ad[1], 5.0, ad[3], 0.45)
		)


# ---------------------------------------------------------------- enseignes et inscriptions
func _road_dist(p: Vector2) -> float:
	var best := INF
	for r in _roads:
		if r["kind"] in ["footway", "path"]:
			continue
		var pts: Array = r["pts"]
		var half: float = r["width"] / 2.0
		for i in range(pts.size() - 1):
			var a := _v2(pts[i])
			var b := _v2(pts[i + 1])
			var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) - half
			if d < best:
				best = d
	return best


func _place_shop_signs(buildings: Array) -> void:
	for bld in buildings:
		if bld["roof"] == "abri" or float(bld["h"]) < 2.9 or _rng.randf() > 0.4:
			continue
		var pts: Array = bld["pts"]
		var c := Vector2.ZERO
		for q in pts:
			c += _v2(q)
		c /= pts.size()
		var best_d := 8.0
		var best := []
		for i in pts.size():
			var a := _v2(pts[i])
			var b := _v2(pts[(i + 1) % pts.size()])
			var L := a.distance_to(b)
			if L < 3.0:
				continue
			var mid := (a + b) / 2.0
			var n := Vector2(-(b - a).y, (b - a).x).normalized()
			if n.dot(mid - c) < 0.0:
				n = -n
			var d := _road_dist(mid + n * 0.5)
			if d < best_d:
				best_d = d
				best = [mid, n, L]
		if best.is_empty():
			continue
		var mid: Vector2 = best[0]
		var n: Vector2 = best[1]
		var width: float = min(float(best[2]) * 0.75, 5.0)
		var pos := mid + n * 0.12
		var xf := Transform3D(_facing(n), Vector3(pos.x, 2.75, pos.y))
		var bg: Color = SIGN_COLORS[_rng.randi() % SIGN_COLORS.size()]
		_panel(xf, Vector2(width, 0.75), bg)
		var fg := Color(0.05, 0.05, 0.05) if bg.get_luminance() > 0.5 else Color(1, 1, 1)
		_label(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.04)), SHOP_NAMES[_rng.randi() % SHOP_NAMES.size()], width * 0.92, fg, 0.42)
		counts["enseigne"] = counts.get("enseigne", 0) + 1


func _place_wall_texts(walls: Array) -> void:
	for wpts in walls:
		if wpts.size() < 2 or _rng.randf() > 0.25:
			continue
		var a := _v2(wpts[0])
		var b := _v2(wpts[1])
		if a.distance_to(b) < 4.0:
			continue
		var t := (b - a).normalized()
		var n := Vector2(-t.y, t.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var mid := a.lerp(b, 0.5) + n * 0.13
		var xf := Transform3D(_facing(n), Vector3(mid.x, 1.3, mid.y))
		var col: Color = [Color(0.1, 0.1, 0.1), Color(0.6, 0.05, 0.05), Color(0.05, 0.2, 0.5)][_rng.randi() % 3]
		_label(xf, WALL_TEXTS[_rng.randi() % WALL_TEXTS.size()], min(a.distance_to(b) * 0.8, 4.0), col, 0.3)
		counts["inscription"] = counts.get("inscription", 0) + 1


func _panel(xf: Transform3D, size: Vector2, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, size.y, 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.7
	bm.material = mat
	mi.mesh = bm
	mi.transform = xf
	mi.visibility_range_end = 150.0
	_signs.add_child(mi)


func _label(xf: Transform3D, text: String, max_width: float, color: Color, height := 0.35) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.outline_size = 0
	l.modulate = color
	l.double_sided = false
	l.shaded = true
	# taille : hauteur de lettre visee, reduite si le texte depasse la largeur disponible
	var px := height / 64.0
	var est_w := text.length() * 0.6 * 64.0 * px
	if est_w > max_width:
		px *= max_width / est_w
	l.pixel_size = px
	# Label3D lit face a +Z : on le retourne pour qu'il soit lisible du cote de la face avant (-Z)
	l.transform = xf * Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	l.visibility_range_end = 120.0
	_signs.add_child(l)


# ---------------------------------------------------------------- construction
func _build() -> void:
	for key in _chunks:
		var ch: Dictionary = _chunks[key]
		var kind: String = ch["kind"]
		var list: Array = ch["xf"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = kind in CAR_KINDS
		mm.mesh = _meshes[kind]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			if mm.use_colors:
				mm.set_instance_color(i, ch["col"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = key.replace("|", "_")
		_chunk_nodes[key] = mmi
		mmi.multimesh = mm
		mmi.visibility_range_end = VIS.get(kind, 180.0)
		mmi.visibility_range_end_margin = 20.0
		add_child(mmi)
	if _wire_pts.size() > 0:
		var am := ArrayMesh.new()
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = _wire_pts
		am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.05, 0.05, 0.05)
		am.surface_set_material(0, mat)
		var wires := MeshInstance3D.new()
		wires.name = "Cables"
		wires.mesh = am
		wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wires)
		counts["cables"] = _wire_pts.size() / 2


# ---------------------------------------------------------------- vehicules gares pris par le joueur
func nearest_parked(p: Vector3, max_dist: float) -> Dictionary:
	var best := {}
	var bd := max_dist
	for i in parked.size():
		var pk: Dictionary = parked[i]
		if pk.get("taken", false):
			continue
		var xf: Transform3D = pk["xf"]
		# portiere conducteur (gauche) pour une voiture, flanc gauche pour un zem
		var door: Vector3 = xf.origin - xf.basis.x * (1.0 if pk["model"] != "zem" else 0.5)
		var d := p.distance_to(door)
		if d < bd:
			bd = d
			best = {"index": i, "dist": d}
	return best


func take_parked(i: int) -> Node3D:
	## Retire l'instance garee (MultiMesh + collision) et la remplace par un vehicule conduisible identique.
	var pk: Dictionary = parked[i]
	pk["taken"] = true
	var slot: Array = pk["slot"]
	if slot.size() == 2 and _chunk_nodes.has(slot[0]):
		var mm: MultiMesh = (_chunk_nodes[slot[0]] as MultiMeshInstance3D).multimesh
		mm.set_instance_transform(slot[1], Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0, -50, 0)))
	if pk["shape"]:
		# retirer la collision tout de suite : sinon la voiture apparait imbriquee dedans et le moteur
		# physique la repousse a travers le sol
		var shape: Node = pk["shape"]
		shape.get_parent().remove_child(shape)
		shape.free()
		pk["shape"] = null
	var xf: Transform3D = pk["xf"]
	var yaw := atan2(-(-xf.basis.z).x, -(-xf.basis.z).z)
	var v := Vehicules.create(pk["model"], pk["color"])
	v.transform = Transform3D(Basis(Vector3.UP, yaw), xf.origin + Vector3(0, 0.12, 0))
	get_parent().add_child(v)
	return v
