extends Node3D
## Mobilier urbain, commerces de rue, vehicules gares, enseignes et avions, places au lancement a partir
## des donnees reelles de la zone (godot/assets/data/zone_aeroport.json, genere par osm_import.py).
## Deterministe (seed) : la ville est la meme a chaque partie. Pose tuile par tuile (monde.gd, docs/chargement_par_morceaux.md) :
## chaque objet tire au sort avec sa propre graine (route et point, batiment, troncon de mur), le decor d'une tuile ne
## depend donc pas des autres ; collisions, enseignes, cables et MultiMesh (decoupes par quartiers de chunk_size, pour que
## les objets lointains ne soient pas affiches) sont ranges par tuile.
## Tous les noms d'enseignes et de marques sont FICTIFS (voir docs/LEGAL.md).

@export var props_scene: PackedScene = preload("res://assets/models/props.glb")
@export var zem_scene: PackedScene = preload("res://assets/models/veh_zem.glb")
@export var seed_value := 229
@export var monde_path: NodePath = ^"../zone_aeroport"
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
	["RADIO LITTORAL 98.6", "La voix de Gbê Town", Color(0.45, 0.1, 0.5), Color(1, 0.9, 0.2)],
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
var _monde: Monde
var _tuile := {}            # tuile en cours de decor : {cle, rect, corps, signs, fils, cles, routes, bats, troncons}
var _par_tuile := {}        # Vector2i -> contexte de la tuile (pour la liberer plus tard)
var _poteaux := {}          # Vector2i(route, point) -> attaches des cables du poteau (cables entre deux tuiles)
var _troncons: Array = []   # troncons de mur droits [a, b] (toute la zone)
signal tuile_placee(cle: Vector2i)
var _roads: Array = []
var _signs: Node3D
var counts := {}
var lamp_positions := PackedVector3Array()
const CAR_KINDS := ["veh_berline", "veh_4x4", "veh_minibus", "veh_pickup"]
var _chunk_nodes := {}
var parked: Array = []                      # voitures garees {model, xf, color} (conduites par le joueur)
var vendor_spots: Array[Transform3D] = []   # tabourets / chaises ou s'assoient les vendeurs (pedestrians.gd)
var shops: Array = []                        # commerces ou acheter (scripts/commerce.gd) : {pos, kind}
var placed := false
## Kit d'objets de rue devant les boutiques et le long des murs (audit Cotonou : parasols, bancs, bouteilles de gaz,
## bidons, casiers, tas de sable et parpaings). Tirage separe : le reste du decor ne change pas.
@export var kit_chance := 0.75         # part des devantures qui recoivent des objets
@export var chantier_chance := 0.05    # part des troncons de mur de 8 m avec un tas de sable et des parpaings devant
@export var mur_texte_chance := 0.12   # part des troncons de mur de 8 m avec une inscription peinte
@export var parabole_chance := 0.3     # part des toits plats avec une antenne parabolique
@export var grappe_chance := 0.35      # part des etals qui ont 1 ou 2 voisins (petit marche de rue)
var _en_grappe := false
const KIT_TEINTES := {"rue_parasol": [Color(0.72, 0.2, 0.16), Color(0.86, 0.68, 0.18), Color(0.18, 0.36, 0.62),
	Color(0.2, 0.48, 0.3), Color(0.85, 0.84, 0.8)], "rue_casiers": [Color(0.66, 0.12, 0.1), Color(0.12, 0.38, 0.2),
	Color(0.85, 0.6, 0.1)]}
var _rng_kit := RandomNumberGenerator.new()
var _devantures: Array = []   # [milieu, normale vers la rue, longueur, batiment] des facades a enseigne de la tuile
signal placement_done  # tetes de lampadaires (lues par day_night.gd pour l'eclairage de nuit)

const VIS := {"prop_poteau": 450.0, "prop_poteau_transfo": 450.0, "prop_lampadaire": 450.0, "toit_citerne": 350.0, "toit_fers": 200.0, "toit_parabole": 220.0, "veh_berline": 300.0,
	"veh_4x4": 300.0, "veh_minibus": 300.0, "veh_pickup": 300.0, "prop_panneau_pub": 600.0, "zem_gare": 200.0,
	"rue_parasol": 160.0, "rue_sable": 140.0, "rue_parpaings": 140.0}


func _ready() -> void:
	_rng.seed = seed_value
	_rng_kit.seed = seed_value * 7 + 3
	_load_meshes()
	_carte = Carte.zone()
	var data: Dictionary = _carte.data
	_roads = data["roads"]
	_monde = get_node_or_null(monde_path) as Monde
	_troncons = _troncons_murs(data.get("walls", []))
	# attendre que les collisions de la carte soient enregistrees avant les requetes physiques
	await Partie.file_videe()   # pendant le chargement : apres les etapes deja confiees (realisme)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# avions aux postes : geres par air_traffic.gd (gares, departs, arrivees)
	# etapes de la mise en place etalee pendant le chargement (Partie.chantier), tuile par tuile
	var cles: Array = [Vector2i.ZERO]
	if _monde:
		cles = _monde.tuiles.keys().filter(func(c: Vector2i) -> bool: return _monde.tuiles[c]["noeud"] != null)
		cles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	Partie.chantier(_place_promenade_lamps.bind(data.get("promenade", [])))
	for cle in cles:
		_placer_tuile(cle)
	Partie.chantier(func() -> void:
		placed = true
		placement_done.emit()
		print("Props : ", counts))
	if _monde:
		_monde.tuile_chargee.connect(func(cle: Vector2i, _n: Node3D) -> void:
			if placed and not _par_tuile.has(cle):
				_placer_tuile(cle))


func _placer_tuile(cle: Vector2i) -> void:
	## Confie le decor d'une tuile a la mise en place etalee (meme ordre que la zone d'un seul tenant).
	var rect := Rect2(-1e6, -1e6, 2e6, 2e6) if _monde == null else (_monde.tuiles[cle]["rect"] as Rect2)
	var ctx := {"cle": cle, "rect": rect, "fils": PackedVector3Array(), "cles": [], "routes": [], "bats": [], "troncons": []}
	_par_tuile[cle] = ctx
	_choisir(ctx)
	var etape := func(f: Callable) -> void: Partie.chantier(_dans_tuile.bind(ctx, f))
	etape.call(_debut_tuile)
	etape.call(_place_billboards)  # en premier : ils ont besoin de place
	etape.call(_place_poles_and_lamps)
	etape.call(_place_roadside)
	for debut in range(0, ctx["bats"].size(), 60):   # enseignes par paquets (~70 ms)
		etape.call(_place_shop_signs.bind(debut, 60))
		etape.call(_place_kit)     # devant les facades a enseigne de ce paquet
	etape.call(_place_wall_texts)
	etape.call(_place_toits)
	etape.call(_place_chantiers)
	etape.call(_build)
	etape.call(func() -> void: tuile_placee.emit(cle))


func _dans_tuile(ctx: Dictionary, f: Callable) -> void:
	_tuile = ctx
	_bodies = ctx.get("corps")
	_signs = ctx.get("signs")
	_wire_pts = ctx["fils"]
	f.call()
	ctx["fils"] = _wire_pts


func _debut_tuile() -> void:
	## Conteneurs de la tuile (collisions, enseignes).
	var cle: Vector2i = _tuile["cle"]
	var suffixe := "_%d_%d" % [cle.x, cle.y]
	_bodies = StaticBody3D.new()
	_bodies.name = "Collisions" + suffixe
	add_child(_bodies)
	_signs = Node3D.new()
	_signs.name = "Enseignes" + suffixe
	add_child(_signs)
	_tuile["corps"] = _bodies
	_tuile["signs"] = _signs
	_devantures.clear()
	_kit_fait = 0


func _choisir(ctx: Dictionary) -> void:
	## Ce qui concerne la tuile : routes qui l'approchent (a 60 m), batiments et troncons de mur dont le centre est dedans.
	var rect: Rect2 = ctx["rect"]
	var large := rect.grow(60.0)
	for ri in _roads.size():
		var pts: Array = _roads[ri]["pts"]
		var bb := Rect2(_v2(pts[0]), Vector2.ZERO)
		for q in pts:
			bb = bb.expand(_v2(q))
		if bb.grow(1.0).intersects(large):
			ctx["routes"].append(ri)
	var bats: Array = _carte.data["buildings"]
	for bi in bats.size():
		var c := Vector2.ZERO
		for q in bats[bi]["pts"]:
			c += _v2(q)
		c /= bats[bi]["pts"].size()
		if rect.has_point(c):
			ctx["bats"].append(bi)
	for si in _troncons.size():
		if rect.has_point((_troncons[si][0] + _troncons[si][1]) * 0.5):
			ctx["troncons"].append(si)


func _dans(p: Vector2) -> bool:
	return (_tuile["rect"] as Rect2).has_point(p)


func _graine(a: String, b := 0, c := 0) -> void:
	## Tirage propre a un objet (deterministe, independant de l'ordre des tuiles).
	_rng.seed = hash([seed_value, a, b, c])
	_rng_kit.seed = hash([seed_value * 7 + 3, a, b, c])


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
	_meshes["toit_citerne"] = _mesh_citerne()
	_meshes["toit_fers"] = _mesh_fers()
	_meshes["toit_parabole"] = _mesh_parabole()
	_meshes.merge(_meshes_kit())


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
	var cle: Vector2i = _tuile.get("cle", Vector2i.ZERO)
	var key := "%s|%d|%d|%d|%d" % [kind, cle.x, cle.y, floori(xf.origin.x / chunk_size), floori(xf.origin.z / chunk_size)]
	if not _chunks.has(key):
		_chunks[key] = {"kind": kind, "xf": [], "col": []}
		if _tuile.has("cles"):
			_tuile["cles"].append(key)
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
	for ri in _tuile["routes"]:
		var r: Dictionary = _roads[ri]
		var kind: String = r["kind"]
		if kind in ["footway", "path", "pedestrian", "track"]:
			continue
		var w: float = r["width"]
		_graine("poteaux", ri)
		var side := 1.0 if _rng.randf() < 0.5 else -1.0
		var pts: Array = r["pts"]
		# poteaux bois tous les ~35 m d'un cote, cables entre eux (y compris vers un poteau deja pose d'une tuile voisine)
		_walk(pts, 35.0, _rng.randf_range(2.0, 20.0), func(p: Vector2, t: Vector2, k: int) -> void:
			if not _dans(p):
				return
			_graine("poteau", ri, k)
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
				return
			_occupy(pos, 1.0)
			var xf := Transform3D(_facing(t), Vector3(pos.x, y, pos.y))
			_add("prop_poteau_transfo" if _rng.randf() < 0.08 else "prop_poteau", xf)
			_cyl_col(xf.origin, 0.16, 9.0)
			var attach := []
			for x in [-0.75, 0.0, 0.75]:
				attach.append(xf * Vector3(x, 8.55, 0))
			_poteaux[Vector2i(ri, k)] = attach
			for voisin in [k - 1, k + 1]:
				var autre: Array = _poteaux.get(Vector2i(ri, voisin), [])
				if autre.size() == 3:
					for i in 3:
						_wire(autre[i], attach[i])
		)
		# lampadaires sur les grands axes, en quinconce
		if kind in ["primary", "secondary"] and r["surface"] == "bitume":
			_graine("lampadaires", ri)
			_walk(pts, 32.0, _rng.randf_range(5.0, 15.0), func(p: Vector2, t: Vector2, k: int) -> void:
				if not _dans(p):
					return
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
	## Front de mer (fichier commun, toujours charge) : pose une fois, hors tuiles.
	if prom.size() < 2:
		return
	_bodies = StaticBody3D.new()
	_bodies.name = "Collisions_promenade"
	add_child(_bodies)
	_tuile = {"cle": Vector2i(-9999, -9999), "rect": Rect2(-1e6, -1e6, 2e6, 2e6), "cles": [], "fils": PackedVector3Array()}
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
	_build()


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
	for ri in _tuile["routes"]:
		var r: Dictionary = _roads[ri]
		var kind: String = r["kind"]
		if kind in ["footway", "path", "pedestrian"]:
			continue
		var big := kind in ["primary", "secondary", "tertiary"]
		var w: float = r["width"]
		_graine("bord", ri)
		_walk(r["pts"], 9.0, _rng.randf_range(0.0, 9.0), func(p: Vector2, t: Vector2, k: int) -> void:
			if not _dans(p):
				return
			_graine("bord", ri, k)
			var roll := _rng.randf()
			var acc := 0.0
			for row in table:
				acc += row[2] if big else row[3]
				if roll < acc:
					_place_one(row[0], row[1], p, t, w)
					return
		)


func _reachable(edge: Vector2, pos: Vector2) -> bool:
	## Rien (mur, cloture, batiment) entre le bord de la chaussee et l'objet : on y accede depuis la rue.
	var a := Vector3(edge.x, 0, edge.y)
	var b := Vector3(pos.x, 0, pos.y)
	a.y = 0.9
	b.y = a.y
	var q := PhysicsRayQueryParameters3D.create(a, b + (b - a).normalized() * 0.8)
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


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
			var model := "veh_berline" if r < 0.55 else ("veh_4x4" if r < 0.78 else ("veh_pickup" if r < 0.9 else "veh_minibus"))
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
	if is_nan(y) or not _is_free(pos, radius) or not _reachable(p + n * (w / 2.0), pos):
		n = -n
		pos = p + n * dist
		y = _ground(pos, radius * 0.6)
		if is_nan(y) or not _is_free(pos, radius) or not _reachable(p + n * (w / 2.0), pos):
			return
	_occupy(pos, radius)
	var basis := _facing(-n)  # face a la route
	if kind == "zems":
		# station de zems : 2 a 4 motos garees en epi, legerement penchees sur la bequille
		var count := _rng.randi_range(2, 4)
		for i in count:
			var q := pos + t * (i - count / 2.0) * 0.95
			if _carte.on_carriageway(q, 0.6):
				continue      # moto qui deborderait sur une autre rue
			var b := _facing(-n.rotated(_rng.randf_range(-0.3, 0.3))) * Basis(Vector3(0, 0, 1), 0.1)
			var zxf := Transform3D(b, Vector3(q.x, y, q.y))
			parked.append({"model": "zem", "xf": zxf, "color": Color.WHITE, "slot": _add("zem_gare", zxf), "shape": null})
			_occupy(q, 1.0)
		return
	if kind == "prop_etal":
		kind = ["prop_etal_rouge", "prop_etal_jaune", "prop_etal_bleu"][_rng.randi() % 3]
		# petits marches de rue : les etals se groupent (2 ou 3 voisins le long de la rue)
		if not _en_grappe and _rng.randf() < grappe_chance:
			_en_grappe = true
			for j in _rng.randi_range(1, 2):
				_place_one("prop_etal", radius, p + t * (3.4 if j == 1 else -3.4), t, w)
			_en_grappe = false
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
	if kind.begins_with("prop_etal") or kind == "prop_maquis" or kind == "prop_kpayo" or kind == "prop_cabine":
		shops.append({"pos": xf.origin, "kind": kind.trim_prefix("prop_").get_slice("_", 0)})
	if kind == "prop_cabine":
		_box_col(xf, Vector3(1.6, 2.3, 1.3), 1.15)
		_label(xf * Transform3D(Basis.IDENTITY, Vector3(0, 1.85, -0.7)), "TRANSFERT D'ARGENT - CREDIT", 1.4, Color(0.1, 0.1, 0.1))
	elif kind.begins_with("prop_etal") or kind == "prop_maquis" or kind == "prop_kpayo":
		_box_col(xf, Vector3(1.2, 0.8, 0.8), 0.4)
	elif kind == "prop_pneus":
		_cyl_col(xf.origin, 0.4, 0.8)


func _place_billboards() -> void:
	for ri in _tuile["routes"]:
		var r: Dictionary = _roads[ri]
		if r["kind"] not in ["primary", "secondary"]:
			continue
		var w: float = r["width"]
		_graine("pubs", ri)
		_walk(r["pts"], 140.0, _rng.randf_range(30.0, 100.0), func(p: Vector2, t: Vector2, k: int) -> void:
			if not _dans(p):
				return
			_graine("pub", ri, k)
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
			var ad: Array = ADS[(ri * 3 + k) % ADS.size()]
			var face := xf * Transform3D(Basis.IDENTITY, Vector3(0, 5.5, -0.04))
			_panel(face, Vector2(6.0, 2.9), ad[2])
			_label(face * Transform3D(Basis.IDENTITY, Vector3(0, 0.45, -0.02)), ad[0], 5.4, ad[3], 0.9)
			_label(face * Transform3D(Basis.IDENTITY, Vector3(0, -0.6, -0.02)), ad[1], 5.0, ad[3], 0.45)
		)


# ---------------------------------------------------------------- enseignes et inscriptions
func _road_dist(p: Vector2) -> float:
	var best := INF
	for ri in _tuile["routes"]:
		var r: Dictionary = _roads[ri]
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


func _place_shop_signs(debut: int, nombre: int) -> void:
	var tous: Array = _carte.data["buildings"]
	for bi in (_tuile["bats"] as Array).slice(debut, debut + nombre):
		var bld: Dictionary = tous[bi]
		_graine("enseigne", bi)
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
		_devantures.append([mid, n, float(best[2]), bi])
		var pos := mid + n * 0.12
		var xf := Transform3D(_facing(n), Vector3(pos.x, 2.75, pos.y))
		var bg: Color = SIGN_COLORS[_rng.randi() % SIGN_COLORS.size()]
		_panel(xf, Vector2(width, 0.75), bg)
		var fg := Color(0.05, 0.05, 0.05) if bg.get_luminance() > 0.5 else Color(1, 1, 1)
		_label(xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.04)), SHOP_NAMES[_rng.randi() % SHOP_NAMES.size()], width * 0.92, fg, 0.42)
		counts["enseigne"] = counts.get("enseigne", 0) + 1


func _troncons_murs(walls: Array, longueur := 8.0) -> Array:
	## Murs d'enceinte (polylignes, un point tous les 0,5 m) decoupes en troncons droits [a, b] d'environ `longueur` m.
	var out := []
	for wpts in walls:
		var i := 0
		while i < wpts.size() - 1:
			var a := _v2(wpts[i])
			var j := i + 1
			while j < wpts.size() - 1 and _v2(wpts[j + 1]).distance_to(a) <= longueur:
				j += 1
			var b := _v2(wpts[j])
			# droit si la corde fait presque la longueur parcourue (pas d'angle de mur au milieu)
			if a.distance_to(b) >= 4.0 and a.distance_to(b) > 0.9 * (j - i) * _v2(wpts[i]).distance_to(_v2(wpts[i + 1])):
				out.append([a, b])
			i = j
	return out


func _place_wall_texts() -> void:
	for si in _tuile["troncons"]:
		var seg: Array = _troncons[si]
		_graine("inscription", si)
		if _rng.randf() > mur_texte_chance:
			continue
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
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
	for key in _tuile["cles"]:
		var ch: Dictionary = _chunks[key]
		var kind: String = ch["kind"]
		var list: Array = ch["xf"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = kind in CAR_KINDS or KIT_TEINTES.has(kind)
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
		wires.name = "Cables_%d_%d" % [_tuile["cle"].x, _tuile["cle"].y]
		wires.mesh = am
		wires.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wires)
		_tuile["cables"] = wires
		counts["cables"] = counts.get("cables", 0) + _wire_pts.size() / 2


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


# ---------------------------------------------------------------- toits de Cotonou (photos refs/rues/)
func _mesh_citerne() -> Mesh:
	## Citerne d'eau en plastique noir sur le toit (tres frequente sur les maisons a toit plat), sur un socle de briques.
	var st := SurfaceTool.new()
	var cuve := CylinderMesh.new()
	cuve.top_radius = 0.55
	cuve.bottom_radius = 0.58
	cuve.height = 1.2
	cuve.radial_segments = 12
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color(0.07, 0.07, 0.08)
	noir.roughness = 0.55
	st.append_from(cuve, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)))
	var couvercle := CylinderMesh.new()
	couvercle.top_radius = 0.2
	couvercle.bottom_radius = 0.22
	couvercle.height = 0.08
	couvercle.radial_segments = 10
	st.append_from(couvercle, 0, Transform3D(Basis.IDENTITY, Vector3(0, 1.59, 0)))
	var m := st.commit()
	m.surface_set_material(0, noir)
	var socle := BoxMesh.new()
	socle.size = Vector3(1.3, 0.35, 1.3)
	var st2 := SurfaceTool.new()
	st2.append_from(socle, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.175, 0)))
	st2.commit(m)
	var gris := StandardMaterial3D.new()
	gris.albedo_color = Color(0.55, 0.53, 0.5)
	gris.roughness = 0.95
	m.surface_set_material(1, gris)
	return m


func _mesh_fers() -> Mesh:
	## Fers d'attente : quatre barres d'armature qui depassent d'un poteau de beton (etage pas encore construit).
	var st := SurfaceTool.new()
	var poteau := BoxMesh.new()
	poteau.size = Vector3(0.22, 0.25, 0.22)
	st.append_from(poteau, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.125, 0)))
	var fer := BoxMesh.new()
	fer.size = Vector3(0.016, 1.1, 0.016)
	for d in [Vector2(-0.07, -0.07), Vector2(0.07, -0.07), Vector2(-0.07, 0.07), Vector2(0.07, 0.07)]:
		st.append_from(fer, 0, Transform3D(Basis(Vector3(d.x, 0, d.y).normalized(), 0.05), Vector3(d.x, 0.75, d.y)))
	var m := st.commit()
	var rouille := StandardMaterial3D.new()
	rouille.albedo_color = Color(0.36, 0.22, 0.14)
	rouille.roughness = 0.9
	m.surface_set_material(0, rouille)
	return m


func _mesh_parabole() -> Mesh:
	## Antenne parabolique sur un pied : coupelle blanche presque tournee vers le ciel (Cotonou est a 6 degres nord : satellites hauts dans le ciel).
	var blanc := _mat(Color(0.86, 0.86, 0.84), 0.5)
	var gris := _mat(Color(0.35, 0.36, 0.37), 0.6)
	var incl := Basis(Vector3.RIGHT, deg_to_rad(-35.0))
	return _assemble([[_boite(Vector3(0.35, 0.05, 0.35)), _at(0, 0.025, 0), 1], [_cyl(0.025, 0.85), _at(0, 0.45, 0), 1],
		[_cyl(0.05, 0.14, 0.42, 12), Transform3D(incl, Vector3(0, 0.95, 0.04)), 0],
		[_cyl(0.012, 0.42), Transform3D(incl * Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0, 1.02, -0.17)), 1]], [blanc, gris])


func _place_toits() -> void:
	## Sur les toits plats : citerne noire sur environ un toit sur deux ; fers d'attente aux angles des maisons a
	## etage (construction qui continue quand l'argent revient).
	var tous: Array = _carte.data["buildings"]
	for bi in _tuile["bats"]:
		var bld: Dictionary = tous[bi]
		if String(bld.get("roof", "")) != "plat":
			continue
		_graine("toit", bi)
		var h := float(bld.get("h", 0.0))
		if h < 2.8 or h > 14.0:
			continue
		var pts: Array = bld["pts"]
		if pts.size() < 4:
			continue
		var c := Vector2.ZERO
		for q in pts:
			c += _v2(q)
		c /= pts.size()
		if _rng.randf() < 0.5:
			var coin := _v2(pts[_rng.randi() % pts.size()])
			var p := c.lerp(coin, _rng.randf_range(0.3, 0.6))
			_add("toit_citerne", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(p.x, h, p.y)))
		if h > 5.0 and _rng.randf() < 0.3:
			for i in range(0, mini(pts.size(), 4)):
				var q := _v2(pts[i]).lerp(c, 0.12 / maxf(_v2(pts[i]).distance_to(c), 0.5))
				_add("toit_fers", Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), Vector3(q.x, h, q.y)))
		if _rng_kit.randf() < parabole_chance:
			# parabole pres d'un bord du toit, tournee vers le sud (satellites geostationnaires, presque a la verticale)
			var bord := _v2(pts[_rng_kit.randi() % pts.size()])
			var q2 := bord.lerp(c, 0.8 / maxf(bord.distance_to(c), 0.9))
			_add("toit_parabole", Transform3D(Basis(Vector3.UP, PI + _rng_kit.randf_range(-0.5, 0.5)), Vector3(q2.x, h, q2.y)))


# ---------------------------------------------------------------- kit d'objets de rue (audit Cotonou)
func _mat(c: Color, rough := 0.8, teinte := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE if teinte else c
	m.vertex_color_use_as_albedo = teinte
	m.roughness = rough
	return m


func _assemble(parts: Array, mats: Array) -> ArrayMesh:
	## parts : [[PrimitiveMesh, Transform3D, indice du materiau], ...] -> une surface par materiau.
	var am := ArrayMesh.new()
	for k in mats.size():
		var st := SurfaceTool.new()
		var vide := true
		for p in parts:
			if int(p[2]) == k:
				st.append_from(p[0], 0, p[1])
				vide = false
		if vide:
			continue
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, mats[k])
	return am


func _boite(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _cyl(r: float, h: float, r_haut := -1.0, segs := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_haut < 0.0 else r_haut
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


func _at(x: float, y: float, z: float, rot_y := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, rot_y), Vector3(x, y, z))


func _meshes_kit() -> Dictionary:
	var bois := _mat(Color(0.42, 0.3, 0.2), 0.9)
	var metal := _mat(Color(0.3, 0.31, 0.32), 0.6)
	var beton := _mat(Color(0.58, 0.57, 0.54), 0.95)
	var sable := _mat(Color(0.71, 0.65, 0.55), 1.0)
	var m := {}
	# parasol de vendeuse (toile teintee par instance, mat sur un pied en beton)
	m["rue_parasol"] = _assemble([[_cyl(0.2, 0.14, 0.17), _at(0, 0.07, 0), 0], [_cyl(0.022, 2.15), _at(0, 1.12, 0), 1],
		[_cyl(1.15, 0.42, 0.03, 8), _at(0, 2.02, 0), 2]], [beton, metal, _mat(Color.WHITE, 0.85, true)])
	# banc de bois (planche sur deux pieds)
	m["rue_banc"] = _assemble([[_boite(Vector3(1.7, 0.05, 0.3)), _at(0, 0.44, 0), 0], [_boite(Vector3(0.06, 0.42, 0.26)), _at(-0.7, 0.21, 0), 0],
		[_boite(Vector3(0.06, 0.42, 0.26)), _at(0.7, 0.21, 0), 0]], [bois])
	# bouteilles de gaz (revendeur) : trois bouteilles peintes, robinet
	var gaz := []
	for i in 3:
		var x := (i - 1) * 0.34
		gaz.append([_cyl(0.15, 0.5), _at(x, 0.25, 0), 0])
		gaz.append([_cyl(0.1, 0.06, 0.06), _at(x, 0.53, 0), 0])
		gaz.append([_cyl(0.03, 0.1), _at(x, 0.6, 0), 1])
	m["rue_gaz"] = _assemble(gaz, [_mat(Color(0.25, 0.42, 0.6), 0.5), metal])
	# bidons jaunes (essence, eau, huile) alignes
	var bid := []
	for i in 4:
		bid.append([_boite(Vector3(0.18, 0.4, 0.3)), _at((i - 1.5) * 0.22, 0.2, 0, (i % 2) * 0.08 - 0.04), 0])
		bid.append([_cyl(0.025, 0.05), _at((i - 1.5) * 0.22, 0.42, 0.08), 1])
	m["rue_bidons"] = _assemble(bid, [_mat(Color(0.86, 0.72, 0.12), 0.55), _mat(Color(0.1, 0.1, 0.1), 0.6)])
	# casiers de boissons empiles (teinte par instance)
	var cas := []
	for i in 3:
		cas.append([_boite(Vector3(0.42, 0.28, 0.3)), _at(0, 0.14 + i * 0.29, 0, (i % 2) * 0.08), 0])
	cas.append([_boite(Vector3(0.42, 0.28, 0.3)), _at(0.45, 0.14, 0.02), 0])
	m["rue_casiers"] = _assemble(cas, [_mat(Color.WHITE, 0.6, true)])
	# tas de sable de chantier (le meme sable gris-beige que le sol) et parpaings empiles
	m["rue_sable"] = _assemble([[_cyl(1.3, 0.65, 0.15, 12), Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.75)), Vector3(0, 0.32, 0)), 0]], [sable])
	var pp := []
	for rang in 4:
		for i in 3:
			pp.append([_boite(Vector3(0.39, 0.19, 0.19)), _at((i - 1) * 0.4, 0.1 + rang * 0.2, 0.0), 0])
			pp.append([_boite(Vector3(0.39, 0.19, 0.19)), _at((i - 1) * 0.4, 0.1 + rang * 0.2, 0.21), 0])
	m["rue_parpaings"] = _assemble(pp, [_mat(Color(0.55, 0.55, 0.53), 0.95)])
	return m


func _pose_kit(kind: String, p: Vector2, n: Vector2, rayon: float) -> bool:
	## Pose un objet du kit en p (dos a la facade si n est donne), avec sa collision ; faux si la place est prise.
	var y := _ground(p, rayon)
	if is_nan(y) or not _is_free(p, rayon):
		return false
	_occupy(p, rayon)
	var xf := Transform3D(_facing(n).rotated(Vector3.UP, _rng_kit.randf_range(-0.3, 0.3)), Vector3(p.x, y, p.y))
	var teintes: Array = KIT_TEINTES.get(kind, [])
	_add(kind, xf, teintes[_rng_kit.randi() % teintes.size()] if not teintes.is_empty() else Color.WHITE)
	match kind:
		"rue_parasol":
			_cyl_col(xf.origin, 0.2, 2.0)
		"rue_banc":
			_box_col(xf, Vector3(1.7, 0.46, 0.3), 0.23)
		"rue_gaz":
			_box_col(xf, Vector3(1.0, 0.62, 0.32), 0.31)
		"rue_bidons":
			_box_col(xf, Vector3(0.9, 0.44, 0.3), 0.22)
		"rue_casiers":
			_box_col(xf, Vector3(0.9, 0.86, 0.32), 0.43)
		"rue_sable":
			_box_col(xf, Vector3(1.8, 0.3, 1.3), 0.15)
		"rue_parpaings":
			_box_col(xf, Vector3(1.2, 0.8, 0.42), 0.4)
	return true


var _kit_fait := 0


func _place_kit() -> void:
	## Devant les facades a enseigne : un parasol avec un banc, ou un revendeur (gaz, bidons, casiers), a 1 ou 2 m du mur.
	var choix := [["rue_parasol", 0.45], ["rue_banc", 0.25], ["rue_gaz", 0.1], ["rue_bidons", 0.12], ["rue_casiers", 0.08]]
	for i in range(_kit_fait, _devantures.size()):
		_graine("kit", _devantures[i][3])
		if _rng_kit.randf() > kit_chance:
			continue
		var mid: Vector2 = _devantures[i][0]
		var n: Vector2 = _devantures[i][1]
		var t := Vector2(-n.y, n.x)
		var L: float = _devantures[i][2]
		var r := _rng_kit.randf()
		var kind := "rue_casiers"
		for c in choix:
			r -= float(c[1])
			if r <= 0.0:
				kind = c[0]
				break
		var p := mid + n * _rng_kit.randf_range(0.9, 1.6) + t * _rng_kit.randf_range(-0.35, 0.35) * L
		if _pose_kit(kind, p, n if kind != "rue_banc" else -n, 0.6) and kind == "rue_parasol" and _rng_kit.randf() < 0.6:
			_pose_kit("rue_banc", p + t * 1.4 + n * 0.3, -n, 0.5)    # banc a l'ombre du parasol, cote facade
	_kit_fait = _devantures.size()


func _place_chantiers() -> void:
	## Devant quelques murs : tas de sable et parpaings (on construit partout, petit a petit), cote rue.
	for si in _tuile["troncons"]:
		var seg: Array = _troncons[si]
		_graine("chantier", si)
		if _rng_kit.randf() > chantier_chance:
			continue
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var t := (b - a).normalized()
		var n := Vector2(-t.y, t.x)
		var mid := a.lerp(b, _rng_kit.randf_range(0.3, 0.7))
		if _road_dist(mid - n * 1.5) < _road_dist(mid + n * 1.5):
			n = -n
		if _pose_kit("rue_sable", mid + n * 1.6, t, 1.0):
			_pose_kit("rue_parpaings", mid + n * 0.9 + t * 2.0, n, 0.7)
