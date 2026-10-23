extends Node3D
## Repartit la vegetation sur la carte au lancement (deterministe : meme resultat a chaque partie).
## - Cocotiers en ligne le long de la plage (cote mer de la promenade), un peu irreguliers.
## - Arbres, buissons et quelques cocotiers dans les espaces libres a terre.
## Jamais sur un batiment, un mur, une route, la piste, le tarmac ou la plage pour les arbres.
## Rien sur l'aerodrome : 120 m de part et d'autre de l'axe de piste, 45 m autour des taxiways (bande d'herbe).
## Rendu en MultiMesh (des centaines d'arbres pour un cout tres faible) + collision sur les troncs.
## Pose tuile par tuile (monde.gd) : chaque case de la grille tire avec sa propre graine, MultiMesh et troncs par tuile.

@export var zone_path: NodePath = ^"../zone_aeroport"
@export var models: PackedScene = preload("res://assets/models/vegetation.glb")
@export var area := Rect2()   # x, z (Godot) ; vide : les limites de la carte (zone_aeroport.json)
@export var grid_step := 9.0
@export var tree_chance := 0.10
@export var bush_chance := 0.10
@export var inland_palm_chance := 0.03
@export var beach_palm_spacing := 13.0
@export var seed_value := 2026
## Essences des arbres a terre (audit Cotonou) : badamier (arbre d'ombre des rues et des cours), neem, manguier.
@export var part_badamier := 0.4
@export var part_neem := 0.3

const ROAD_LAYER := 1 << 9   # couche 10 : surfaces "a eviter", jamais vues par le joueur ni les vehicules
const AVOID := ["route_", "accotement", "zone_parking", "aeroport_", "promenade", "piste_cyclable", "plage", "zone_plage", "zone_piscine", "zone_eau", "abri_toit"]

var _rng := RandomNumberGenerator.new()
var _meshes := {}
var _xforms := {"veg_cocotier": [], "veg_arbre": [], "veg_buisson": [], "veg_badamier": [], "veg_neem": []}
var _trunks: StaticBody3D
var _par_tuile := {}        # Vector2i -> [troncs, MultiMeshInstance3D...] (pour liberer la tuile plus tard)
var _temp_bodies: Array[Node] = []
var _airside: Array = []      # [a, b, demi-largeur] : axes de piste et de taxiways (Vector2 x, z)


func _ready() -> void:
	_rng.seed = seed_value
	if area.size == Vector2.ZERO:
		var b: Array = Carte.zone().data["bounds"]
		area = Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
	var inst := models.instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		_meshes[String(mi.name)] = mi.mesh
	inst.free()
	var zone := get_node_or_null(zone_path)
	if zone == null:
		return
	# les surfaces a eviter sont creees par realism.gd (noeud Realisme) ; attendre qu'elles soient enregistrees
	await Partie.file_videe()   # pendant le chargement : apres les etapes du realisme
	await get_tree().physics_frame
	await get_tree().physics_frame
	for a in Carte.zone().data.get("aeroways", []):
		var half := 120.0 if a["kind"] in ["runway", "stopway"] else 45.0
		var pts: Array = a["pts"]
		for k in pts.size() - 1:
			_airside.append([Vector2(float(pts[k][0]), float(pts[k][1])), Vector2(float(pts[k + 1][0]), float(pts[k + 1][1])), half])
	Partie.chantier(func() -> void:
		_debut("plage")
		_scatter_beach_palms(zone)
		_build_multimeshes("plage"))
	var monde := zone as Monde
	var cles: Array = [Vector2i.ZERO]
	if monde:
		cles = monde.tuiles.keys().filter(func(c: Vector2i) -> bool: return monde.tuiles[c]["noeud"] != null)
		cles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
		monde.tuile_chargee.connect(func(cle: Vector2i, _n: Node3D) -> void:
			if not _par_tuile.has(cle):
				_tuile(cle, monde.tuiles[cle]["rect"], false))
		monde.tuile_dechargee.connect(liberer_tuile)
	for cle in cles:
		_tuile(cle, monde.tuiles[cle]["rect"] if monde else area, true)
	Partie.chantier(func() -> void: print("Vegetation : %d cocotiers, %d badamiers, %d neems, %d manguiers, %d buissons" % [_xforms["veg_cocotier"].size(), _xforms["veg_badamier"].size(), _xforms["veg_neem"].size(), _xforms["veg_arbre"].size(), _xforms["veg_buisson"].size()]))


func _tuile(cle: Vector2i, rect: Rect2, au_chargement: bool) -> void:
	## Vegetation d'une tuile : d'un bloc au chargement, par bandes de quelques rangees en cours de partie (travail de fond).
	var nom := "%d_%d" % [cle.x, cle.y]
	var zone := rect.intersection(area)
	var ctx := {"noeuds": []}
	_par_tuile[cle] = ctx
	var bande := zone.size.y if au_chargement else grid_step * 4.0
	var etapes: Array[Callable] = []
	var z := zone.position.y
	while z < zone.end.y - 0.001:
		var morceau := Rect2(zone.position.x, z, zone.size.x, minf(bande, zone.end.y - z))
		etapes.append(func() -> void: _scatter_inland(morceau))
		z += bande
	var suite := func(f: Callable) -> void:
		var g := func() -> void:
			if _par_tuile.get(cle) != ctx:
				return    # tuile liberee entre-temps
			f.call()
		if au_chargement:
			Partie.chantier(g)
		else:
			Partie.tache(g)
	suite.call(func() -> void:
		_debut(nom)
		ctx["noeuds"] = _derniers)
	for e in etapes:
		suite.call(e)
	suite.call(func() -> void:
		_build_multimeshes(nom))


func liberer_tuile(cle: Vector2i) -> void:
	var ctx: Dictionary = _par_tuile.get(cle, {})
	_par_tuile.erase(cle)
	for n in ctx.get("noeuds", []):
		if is_instance_valid(n):
			(n as Node).queue_free()


var _derniers: Array = []   # noeuds de la derniere tuile posee
var _lot := {}               # kind -> transformations de la tuile en cours (_xforms : toute la zone)


func _debut(nom: String) -> void:
	_lot = {}
	_trunks = StaticBody3D.new()
	_trunks.name = "Troncs_" + nom
	add_child(_trunks)
	_derniers = [_trunks]


func _build_avoid_shapes(zone: Node) -> void:
	for mi in zone.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		for prefix in AVOID:
			if n.begins_with(prefix):
				var body := StaticBody3D.new()
				body.collision_layer = ROAD_LAYER
				body.collision_mask = 0
				var cs := CollisionShape3D.new()
				cs.shape = mi.mesh.create_trimesh_shape()
				body.add_child(cs)
				mi.add_child(body)
				_temp_bodies.append(body)
				break


func _free_spot(p: Vector3, radius: float, allow_beach := false) -> float:
	## Renvoie la hauteur du sol si l'endroit est libre, sinon NAN.
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, 80, p.z), Vector3(p.x, -10, p.z))
	ray.collision_mask = 1
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return NAN
	var owner_name := String(hit.collider.get_parent().name).to_lower()
	if not owner_name.begins_with("sol_terre"):
		return NAN  # batiment, mur, repere...
	# routes et surfaces a eviter (plage autorisee pour les cocotiers de plage)
	var ray2 := PhysicsRayQueryParameters3D.create(Vector3(p.x, 5, p.z), Vector3(p.x, -2, p.z))
	ray2.collision_mask = ROAD_LAYER
	var hit2 := space.intersect_ray(ray2)
	if not hit2.is_empty():
		var n2 := String(hit2.collider.name).to_lower()
		if not (allow_beach and (n2.begins_with("plage") or n2.begins_with("zone_plage"))):
			return NAN
	# pas de batiment / mur dans le rayon
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, hit.position.y + radius + 0.3, p.z))
	q.collision_mask = 1
	if not space.intersect_shape(q, 1).is_empty():
		return NAN
	return hit.position.y


func _add(kind: String, p: Vector3, y: float, scale_range := Vector2(0.8, 1.2), yaw := -1.0) -> void:
	var s := _rng.randf_range(scale_range.x, scale_range.y)
	var r := yaw if yaw >= 0.0 else _rng.randf_range(0.0, TAU)
	# silhouette moins geometrique : largeur et hauteur legerement differentes, tronc un peu penche (tirage par la position,
	# le generateur du reste de la vegetation ne bouge pas)
	var h := absi(hash(Vector2i(roundi(p.x * 10.0), roundi(p.z * 10.0))))
	var u1 := float(h % 1000) / 1000.0
	var u2 := float((h / 1000) % 1000) / 1000.0
	var u3 := float((h / 1000000) % 1000) / 1000.0
	var penche := 0.12 if kind == "veg_cocotier" else (0.0 if kind == "veg_buisson" else 0.06)
	var tilt := Basis(Vector3.RIGHT, (u1 - 0.5) * 2.0 * penche) * Basis(Vector3.BACK, (u2 - 0.5) * 2.0 * penche)
	var b := Basis(Vector3.UP, r) * tilt * Basis.from_scale(Vector3(s * lerpf(0.88, 1.14, u3), s * lerpf(0.9, 1.15, u1), s * lerpf(0.88, 1.14, u2)))
	_xforms[kind].append(Transform3D(b, Vector3(p.x, y, p.z)))
	if not _lot.has(kind):
		_lot[kind] = []
	_lot[kind].append(_xforms[kind][-1])
	if kind != "veg_buisson":
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3 * s
		cyl.height = 3.0
		cs.shape = cyl
		cs.position = Vector3(p.x, y + 1.5, p.z)
		_trunks.add_child(cs)


func _scatter_beach_palms(zone: Node) -> void:
	var prom := zone.find_child("promenade", true, false) as MeshInstance3D
	if prom == null:
		return
	var verts: PackedVector3Array = prom.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var pts: Array[Vector3] = []
	for v in verts:
		pts.append(prom.global_transform * v)
	pts.sort_custom(func(a, b): return a.x < b.x)
	var last_x := -INF
	_rng.seed = seed_value
	for p in pts:
		if p.x - last_x < beach_palm_spacing:
			continue
		last_x = p.x + _rng.randf_range(-3.0, 3.0)
		# cote mer de la promenade (+Z = sud), parfois deux cocotiers ensemble
		for k in range(1 if _rng.randf() < 0.7 else 2):
			var q := p + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(6.0, 16.0))
			var y := _free_spot(q, 1.0, true)
			if is_nan(y):
				y = q.y if q.y > -0.5 else NAN
			if not is_nan(y):
				# ils penchent vers la mer (le modele penche vers +X Blender = +X Godot)
				_add("veg_cocotier", q, max(y, 0.0), Vector2(0.85, 1.25), PI / 2.0 + _rng.randf_range(-0.6, 0.6))


func _scatter_inland(zone: Rect2) -> void:
	## Grille alignee sur area (les memes cases quelle que soit la tuile) ; une graine par case.
	if zone.size.x <= 0.0 or zone.size.y <= 0.0:
		return
	for ix in range(ceili((zone.position.x - area.position.x) / grid_step), ceili((zone.end.x - area.position.x) / grid_step)):
		for iz in range(ceili((zone.position.y - area.position.y) / grid_step), ceili((zone.end.y - area.position.y) / grid_step)):
			_rng.seed = hash([seed_value, ix, iz])
			var p := Vector3(area.position.x + ix * grid_step + _rng.randf_range(-3.5, 3.5), 0,
				area.position.y + iz * grid_step + _rng.randf_range(-3.5, 3.5))
			var roll := _rng.randf()
			if _on_airside(Vector2(p.x, p.z)):
				continue
			if roll < tree_chance:
				var y := _free_spot(p, 2.2)
				if not is_nan(y):
					_add(_essence(p), p, y, Vector2(0.75, 1.3))
			elif roll < tree_chance + inland_palm_chance:
				var y := _free_spot(p, 1.0)
				if not is_nan(y):
					_add("veg_cocotier", p, y, Vector2(0.8, 1.15))
			elif roll < tree_chance + inland_palm_chance + bush_chance:
				var y := _free_spot(p, 0.8)
				if not is_nan(y):
					_add("veg_buisson", p, y, Vector2(0.7, 1.4))


func _essence(p: Vector3) -> String:
	## Tirage par la position (pas par le generateur : le reste de la vegetation ne bouge pas).
	var u := float(absi(hash(Vector2i(roundi(p.x * 10.0), roundi(p.z * 10.0)))) % 1000) / 1000.0
	return "veg_badamier" if u < part_badamier else ("veg_neem" if u < part_badamier + part_neem else "veg_arbre")


func _on_airside(p: Vector2) -> bool:
	for s in _airside:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, s[0], s[1])) < float(s[2]):
			return true
	return false


func _build_multimeshes(nom: String) -> void:
	for kind in _lot:
		var list: Array = _lot[kind]
		if list.is_empty() or not _meshes.has(kind):
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[kind]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = kind + "_" + nom
		mmi.multimesh = mm
		add_child(mmi)
		_derniers.append(mmi)
