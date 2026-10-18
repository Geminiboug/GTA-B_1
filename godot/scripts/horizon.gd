extends Node3D
## Ce qu'on voit au-dela de la carte jouable (le joueur n'y va pas, les murs invisibles l'arretent) :
## - sol jusqu'a 6 km : laterite cote terre, sable entre la promenade et l'eau, ocean au sud ;
## - quartiers de Cotonou qui continuent (maisons basses a toit de tole, immeubles de 2 a 4 niveaux, arbres) ;
## - routes qui sortent de la carte prolongees tout droit ;
## - suite de la piste de l'aeroport (2 400 m au total, seuil 24 au nord-est) avec son marquage et sa bande d'herbe.
## Tout est genere au lancement a partir des donnees de la zone (deterministe), en MultiMesh pour les maisons.

@export var extent := 6000.0          # demi-cote du sol lointain (m)
@export var city_depth := 1300.0      # profondeur des quartiers autour de la carte (m)
@export var city_step := 27.0         # pas de la grille des maisons lointaines (m)
@export var seed_value := 2026

const SOL := preload("res://shaders/sol.gdshader")
const MER := preload("res://shaders/mer.gdshader")
const RUNWAY_LENGTH := 2400.0         # piste 06/24 de Cotonou
const STRIP_HALF := 150.0             # bande d'herbe de part et d'autre de l'axe de piste
const CITY_CLEAR := 350.0             # pas de maisons a moins de 350 m de l'axe (emprise de l'aeroport)

var _rng := RandomNumberGenerator.new()
var _b := Rect2()                     # carte jouable (x, z)
var _coast: Array = []                # trait de cote (eau)
var _inner: Array = []                # limite interieure de la plage (promenade)
var _rw_a := Vector2.ZERO             # seuil 06 (sud-ouest)
var _rw_u := Vector2.ZERO             # direction 06 -> 24
var _road_strips: Array = []          # [a, b, demi-largeur] des routes prolongees (pas de maisons dessus)


func _ready() -> void:
	_rng.seed = seed_value
	var data: Dictionary = Carte.zone().data
	var bd: Array = data["bounds"]
	_b = Rect2(float(bd[0]), float(bd[1]), float(bd[2]) - float(bd[0]), float(bd[3]) - float(bd[1]))
	_coast = _pts(data.get("coast", []))
	_inner = _pts(data.get("beach_inner", []))
	_find_runway(data)
	# etapes de la mise en place etalee pendant le chargement (Partie.chantier)
	Partie.chantier(_build_ground)
	Partie.chantier(_extend_roads.bind(data))
	Partie.chantier(_extend_runway)
	Partie.chantier(_extend_taxiways)
	Partie.chantier(_build_city)


func _pts(arr: Array) -> Array:
	var out := []
	for p in arr:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


func _line_z(line: Array, x: float, fallback: float) -> float:
	## z de la ligne (trait de cote...) a l'abscisse x ; au-dela des donnees, prolongee par la pente moyenne des 300 derniers metres.
	if line.size() < 2:
		return fallback
	for i in line.size() - 1:
		var a: Vector2 = line[i]
		var c: Vector2 = line[i + 1]
		if (a.x - x) * (c.x - x) <= 0.0 and a.x != c.x:
			return lerpf(a.y, c.y, (x - a.x) / (c.x - a.x))
	# hors des donnees : pente moyenne sur ~400 m depuis l'extremite la plus proche (bornee : cote presque droite)
	var lo: Vector2 = line[0]
	var hi: Vector2 = line[line.size() - 1]
	var asc := lo.x < hi.x
	var end_: Vector2 = (lo if asc else hi) if x < minf(lo.x, hi.x) else (hi if asc else lo)
	var ref := end_
	for p in line:
		if absf((p as Vector2).x - end_.x) > absf(ref.x - end_.x) and absf((p as Vector2).x - end_.x) <= 400.0:
			ref = p
	var slope := 0.0 if absf(ref.x - end_.x) < 1.0 else clampf((ref.y - end_.y) / (ref.x - end_.x), -0.25, 0.25)
	return end_.y + (x - end_.x) * slope


func _find_runway(data: Dictionary) -> void:
	## Axe de la piste : extremite sud-ouest (seuil 06, cote mer) et direction vers le nord-est.
	var best: Array = []
	for r in data.get("runways", []):
		if r.size() > best.size():
			best = r
	if best.size() < 2:
		return
	var p0 := Vector2(float(best[0][0]), float(best[0][1]))
	var p1 := Vector2(float(best[-1][0]), float(best[-1][1]))
	# le seuil 06 est l'extremite la plus a l'ouest (dans la carte) ; la piste continue au-dela du bord nord
	if p1.x < p0.x:
		var t := p0
		p0 = p1
		p1 = t
	_rw_a = p0
	_rw_u = (p1 - p0).normalized()


func _ground_mat(mode: int, tint := Color(1, 1, 1)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SOL
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	return m


func _quad_mesh(quads: Array, y: float, mat: Material, name_: String) -> void:
	## quads : liste de [p0, p1, p2, p3] (Vector2 x, z), sens quelconque.
	if quads.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for q in quads:
		var v: Array = []
		for p in q:
			v.append(Vector3((p as Vector2).x, y, (p as Vector2).y))
		# triangles orientes vers le haut (vus du dessus)
		var n := ((v[1] as Vector3) - (v[0] as Vector3)).cross((v[2] as Vector3) - (v[0] as Vector3))
		var order := [0, 2, 1, 0, 3, 2] if n.y > 0.0 else [0, 1, 2, 0, 2, 3]   # Godot : faces avant en sens horaire
		for i in order:
			st.add_vertex(v[i])
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ------------------------------------------------------------------ sol, sable, ocean
func _build_ground() -> void:
	var E := extent
	var xs: Array[float] = []
	var x := -E
	while x < E:
		xs.append(x)
		x += 60.0
	for v: float in [_b.position.x, _b.end.x, -720.0, 720.0]:
		xs.append(v)
	xs.append(E)
	xs.sort()
	var land: Array = []
	var sand: Array = []
	var sea: Array = []
	for i in xs.size() - 1:
		var x0: float = xs[i]
		var x1: float = xs[i + 1]
		if x1 - x0 < 0.01:
			continue
		var xm := (x0 + x1) * 0.5
		var c0 := _line_z(_coast, x0, 450.0)
		var c1 := _line_z(_coast, x1, 450.0)
		var i0 := _line_z(_inner, x0, 300.0)
		var i1 := _line_z(_inner, x1, 300.0)
		var in_map := xm > _b.position.x and xm < _b.end.x
		if in_map:
			# au nord de la carte seulement (la plage de la carte va deja jusqu'a l'eau)
			land.append([Vector2(x0, -E), Vector2(x1, -E), Vector2(x1, _b.position.y + 0.5), Vector2(x0, _b.position.y + 0.5)])
		else:
			land.append([Vector2(x0, -E), Vector2(x1, -E), Vector2(x1, i1), Vector2(x0, i0)])
			sand.append([Vector2(x0, i0), Vector2(x1, i1), Vector2(x1, c1 + 6.0), Vector2(x0, c0 + 6.0)])
		# ocean : au-dela de la mer animee de la carte (x -720..720, z 300..820)
		if xm > -720.0 and xm < 720.0:
			sea.append([Vector2(x0, 820.0), Vector2(x1, 820.0), Vector2(x1, E), Vector2(x0, E)])
		else:
			sea.append([Vector2(x0, c0), Vector2(x1, c1), Vector2(x1, E), Vector2(x0, E)])
	_quad_mesh(land, -0.02, _ground_mat(0), "SolLointain")
	_quad_mesh(sand, -0.01, _ground_mat(1), "PlageLointaine")
	var sm := ShaderMaterial.new()
	sm.shader = MER
	sm.set_shader_parameter("wave_height", 0.0)
	_quad_mesh(sea, -0.3, sm, "OceanLointain")


# ------------------------------------------------------------------ routes prolongees
func _extend_roads(data: Dictionary) -> void:
	var bitume: Array = []
	var terre: Array = []
	for r in data.get("roads", []):
		var pts: Array = r["pts"]
		if pts.size() < 2:
			continue
		for k in [0, pts.size() - 1]:
			var e := Vector2(float(pts[k][0]), float(pts[k][1]))
			var n2: Array = pts[1] if k == 0 else pts[pts.size() - 2]
			var prev := Vector2(float(n2[0]), float(n2[1]))
			if not _on_border(e):
				continue
			var dir := (e - prev).normalized()
			# la route doit sortir de la carte (pas longer le bord)
			var out := _outward(e)
			if dir.dot(out) < 0.35:
				continue
			var w := float(r.get("width", 6.0))
			var length := 1400.0 if w >= 6.0 else 500.0
			var b := e + dir * length
			var side := Vector2(-dir.y, dir.x) * (w * 0.5)
			var q := [e - dir * 0.5 + side, e - dir * 0.5 - side, b - side, b + side]
			if String(r.get("surface", "")) in ["sand", "unpaved", "dirt", "ground", "earth", "compacted", "gravel"]:
				terre.append(q)
			else:
				bitume.append(q)
			_road_strips.append([e, b, w * 0.5 + 6.0])
	_quad_mesh(bitume, 0.018, _ground_mat(2), "RoutesLointaines")
	_quad_mesh(terre, 0.016, _ground_mat(5), "PistesLointaines")


func _on_border(p: Vector2) -> bool:
	return absf(p.x - _b.position.x) < 3.0 or absf(p.x - _b.end.x) < 3.0 or absf(p.y - _b.position.y) < 3.0 or absf(p.y - _b.end.y) < 3.0


func _outward(p: Vector2) -> Vector2:
	if absf(p.x - _b.position.x) < 3.0:
		return Vector2.LEFT
	if absf(p.x - _b.end.x) < 3.0:
		return Vector2.RIGHT
	if absf(p.y - _b.position.y) < 3.0:
		return Vector2.UP
	return Vector2.DOWN


# ------------------------------------------------------------------ suite de la piste
func _extend_runway() -> void:
	if _rw_u == Vector2.ZERO:
		return
	var u := _rw_u
	var n := Vector2(-u.y, u.x)
	# point ou l'axe sort de la carte (bord nord)
	var t_exit := 0.0
	while t_exit < RUNWAY_LENGTH and _b.grow(-0.5).has_point(_rw_a + u * t_exit):
		t_exit += 1.0
	var p_exit := _rw_a + u * t_exit
	var p_end := _rw_a + u * RUNWAY_LENGTH
	var hw := 22.5
	_quad_mesh([[p_exit + n * hw, p_exit - n * hw, p_end - n * hw, p_end + n * hw]], 0.017, _ground_mat(2), "PisteLointaine")
	# bande d'herbe (graded strip) de part et d'autre, prolongee 60 m au-dela du seuil
	var g_end := p_end + u * 60.0
	_quad_mesh([[p_exit + n * STRIP_HALF, p_exit - n * STRIP_HALF, g_end - n * STRIP_HALF, g_end + n * STRIP_HALF]], 0.007, _ground_mat(8), "BandeHerbeLointaine")
	# marquage : axe (tirets 30 m / 20 m), bords, seuil 24 (bandes), zone de toucher et point de visee
	var marks: Array = []
	var t := ceilf((t_exit + 2.0) / 50.0) * 50.0
	while t + 30.0 < RUNWAY_LENGTH - 60.0:
		marks.append(_rect(_rw_a + u * t, u, 30.0, 0.9))
		t += 50.0
	for s: float in [-1.0, 1.0]:
		var c0 := _rw_a + u * t_exit + n * s * (hw - 1.0)
		marks.append(_rect(c0, u, RUNWAY_LENGTH - t_exit, 0.9))
	# seuil 24 : 12 bandes de 30 m (cote nord-est), tournees vers le sud-ouest
	var thr := p_end - u * 6.0
	for k in range(-6, 7):
		if k == 0:
			continue
		var off := k * 3.6 + (0.9 if k > 0 else -0.9) - signf(k) * 1.8
		marks.append(_rect(thr + n * off, -u, 30.0, 1.8))
	# zone de toucher et point de visee pour les deux seuils (ceux qui tombent dans la carte sont dessines aussi)
	for end in [[_rw_a, u], [p_end, -u]]:
		var p0: Vector2 = end[0]
		var d: Vector2 = end[1]
		for s: float in [-1.0, 1.0]:
			marks.append(_rect(p0 + d * 400.0 + n * s * 7.5, d, 45.0, 6.0))       # point de visee
			for zt: float in [150.0, 300.0, 600.0]:
				for j in range(3 if zt < 300.0 else (2 if zt < 600.0 else 1)):
					marks.append(_rect(p0 + d * zt + n * s * (4.0 + j * 3.0), d, 22.5, 1.8))
	_quad_mesh(marks, 0.021, _ground_mat(7, Color(0.93, 0.93, 0.9)), "MarquagePisteLointain")
	# numeros de piste (cap magnetique / 10) peints apres les bandes de seuil, lisibles par le pilote qui atterrit
	for end in [[_rw_a, u, "06"], [p_end, -u, "24"]]:
		var p: Vector2 = end[0]
		var d: Vector2 = end[1]
		var l := Label3D.new()
		l.text = end[2]
		l.font_size = 128
		l.pixel_size = 0.07          # chiffres d'environ 9 m de haut
		l.outline_size = 0
		l.modulate = Color(0.93, 0.93, 0.9)
		l.shaded = true
		l.double_sided = false
		l.no_depth_test = false
		add_child(l)
		var c := p + d * 58.0
		l.global_transform = Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.y)) * Basis(Vector3.RIGHT, -PI / 2.0), Vector3(c.x, 0.022, c.y))


const TAXI_LINES := [[744.0, 191.0, 2352.0, 191.0], [1600.0, 22.0, 1600.0, 191.0], [2340.0, 22.0, 2340.0, 191.0], [650.0, 22.0, 650.0, 118.0]]


func _extend_taxiways() -> void:
	## Hors carte : suite du taxiway parallele T2 (a 191 m de l'axe) jusqu'au seuil 24, bretelles vers la piste a
	## 1 600 m et 2 340 m, suite de T1 jusqu'a la piste (meme trace que dans scripts/air_traffic.gd).
	if _rw_u == Vector2.ZERO:
		return
	var u := _rw_u
	var n := Vector2(-u.y, u.x)
	var tw: Array = []
	var lines: Array = []
	var grass: Array = []
	for l in TAXI_LINES:
		var a: Vector2 = _rw_a + u * float(l[0]) + n * float(l[1])
		var b: Vector2 = _rw_a + u * float(l[2]) + n * float(l[3])
		var d := (b - a).normalized()
		tw.append(_rect(a - d * 11.5, d, a.distance_to(b) + 23.0, 23.0))
		lines.append(_rect(a, d, a.distance_to(b), 0.3))
		grass.append(_rect(a - d * 40.0, d, a.distance_to(b) + 80.0, 80.0))
	_quad_mesh(grass, 0.006, _ground_mat(8), "HerbeTaxiwaysLointains")
	_quad_mesh(tw, 0.015, _ground_mat(2), "TaxiwaysLointains")
	_quad_mesh(lines, 0.018, _ground_mat(7, Color(0.95, 0.75, 0.12)), "MarquageTaxiwaysLointains")


func _rect(start: Vector2, dir: Vector2, length: float, width: float) -> Array:
	var side := Vector2(-dir.y, dir.x) * (width * 0.5)
	var e := start + dir * length
	return [start + side, start - side, e - side, e + side]


# ------------------------------------------------------------------ quartiers lointains
func _build_city() -> void:
	var walls: Array = []     # [Transform3D, Color]
	var roofs: Array = []
	var trees: Array = []
	var palms: Array = []
	var wall_cols := [Color(0.86, 0.8, 0.68), Color(0.9, 0.86, 0.78), Color(0.78, 0.62, 0.45), Color(0.93, 0.92, 0.88),
		Color(0.72, 0.74, 0.7), Color(0.85, 0.72, 0.55), Color(0.8, 0.84, 0.86), Color(0.7, 0.55, 0.42)]
	var r0 := _b.grow(city_depth)
	var z := r0.position.y
	while z < r0.end.y:
		var x := r0.position.x
		while x < r0.end.x:
			var p := Vector2(x + _rng.randf_range(-6.0, 6.0), z + _rng.randf_range(-6.0, 6.0))
			x += city_step
			if _b.grow(25.0).has_point(p):
				continue
			if p.y > _line_z(_inner, p.x, 300.0) - 40.0:
				continue      # plage et front de mer : pas de maisons
			if _near_runway(p, CITY_CLEAR) or _near_road(p):
				continue
			var dist := _dist_outside(p)
			var roll := _rng.randf()
			if roll < 0.62 * (1.0 - dist / (city_depth * 1.6)):
				var w := _rng.randf_range(8.0, 16.0)
				var d := _rng.randf_range(8.0, 15.0)
				var floors := 1 if _rng.randf() < 0.6 else (2 if _rng.randf() < 0.75 else _rng.randi_range(3, 4))
				var h := 3.2 * floors + _rng.randf_range(-0.3, 0.4)
				var yaw := _rng.randf_range(-0.12, 0.12) + (0.0 if _rng.randf() < 0.7 else PI / 2.0)
				var basis := Basis(Vector3.UP, yaw)
				walls.append([Transform3D(basis.scaled(Vector3(w, h, d)), Vector3(p.x, h * 0.5, p.y)), wall_cols[_rng.randi() % wall_cols.size()]])
				var tin := floors == 1 or _rng.randf() < 0.25
				var rc := Color(0.5, 0.42, 0.36).lerp(Color(0.62, 0.63, 0.64), _rng.randf()) if tin else Color(0.6, 0.6, 0.58)
				roofs.append([Transform3D(basis.scaled(Vector3(w + 0.6, 0.25, d + 0.6)), Vector3(p.x, h + 0.12, p.y)), rc])
			elif roll < 0.8:
				trees.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.4)), Vector3(p.x, 0, p.y)))
			elif roll < 0.84:
				palms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.15)), Vector3(p.x, 0, p.y)))
		z += city_step
	# cocotiers le long de la plage lointaine
	var xx := -2600.0
	while xx < 2600.0:
		if xx < _b.position.x - 10.0 or xx > _b.end.x + 10.0:
			var pz := _line_z(_inner, xx, 300.0) + _rng.randf_range(8.0, 30.0)
			palms.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.85, 1.2)), Vector3(xx, 0, pz)))
		xx += _rng.randf_range(10.0, 22.0)
	_multimesh_box(walls, "MaisonsLointaines", 0.85)
	_multimesh_box(roofs, "ToitsLointains", 0.6)
	var veg := (load("res://assets/models/vegetation.glb") as PackedScene).instantiate()
	var meshes := {}
	for mi in veg.find_children("*", "MeshInstance3D", true, false):
		meshes[String(mi.name)] = (mi as MeshInstance3D).mesh
	veg.free()
	_multimesh_tiles(meshes.get("veg_arbre"), trees, "ArbresLointains", Color(0.2, 0.33, 0.14))
	_multimesh_tiles(meshes.get("veg_cocotier"), palms, "CocotiersLointains", Color(0.3, 0.4, 0.18))
	print("Horizon : %d maisons, %d arbres, %d cocotiers au-dela de la carte" % [walls.size(), trees.size(), palms.size()])


func _dist_outside(p: Vector2) -> float:
	var dx := maxf(maxf(_b.position.x - p.x, p.x - _b.end.x), 0.0)
	var dz := maxf(maxf(_b.position.y - p.y, p.y - _b.end.y), 0.0)
	return Vector2(dx, dz).length()


func _near_runway(p: Vector2, r: float) -> bool:
	if _rw_u == Vector2.ZERO:
		return false
	var t := clampf((p - _rw_a).dot(_rw_u), -300.0, RUNWAY_LENGTH + 300.0)
	return p.distance_to(_rw_a + _rw_u * t) < r


func _near_road(p: Vector2) -> bool:
	for s in _road_strips:
		var q := Geometry2D.get_closest_point_to_segment(p, s[0], s[1])
		if p.distance_to(q) < float(s[2]) + 6.0:
			return true
	return false


func _multimesh_box(items: Array, name_: String, rough: float) -> void:
	if items.is_empty():
		return
	var box := BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	box.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# arbres lointains (optimisation, phase 11) : par tuiles de tuile_arbres m (decoupage camera par tuile), vrai modele
# jusqu'a detail_arbres m, au-dela une silhouette de quelques dizaines de triangles (houppier, sans tronc)
@export var tuile_arbres := 250.0
@export var detail_arbres := 250.0


func _multimesh_tiles(mesh: Mesh, xforms: Array, name_: String, crown: Color) -> void:
	if mesh == null or xforms.is_empty():
		return
	var proxy := _crown_proxy(mesh.get_aabb(), crown)
	var tiles := {}
	for t in xforms:
		var k := Vector2i(floori(t.origin.x / tuile_arbres), floori(t.origin.z / tuile_arbres))
		if not tiles.has(k):
			tiles[k] = []
		tiles[k].append(t)
	var parent := Node3D.new()
	parent.name = name_
	add_child(parent)
	for k in tiles:
		for far in [false, true]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = proxy if far else mesh
			mm.instance_count = tiles[k].size()
			for i in tiles[k].size():
				mm.set_instance_transform(i, tiles[k][i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if far:
				mmi.visibility_range_begin = detail_arbres
			else:
				mmi.visibility_range_end = detail_arbres
			parent.add_child(mmi)


func _crown_proxy(box: AABB, col: Color) -> Mesh:
	var sm := SphereMesh.new()
	sm.radial_segments = 7
	sm.rings = 3
	var r := maxf(box.size.x, box.size.z) * 0.42
	var crown_h := box.size.y * 0.55
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i] = Vector3(v[i].x * 2.0 * r, v[i].y * crown_h, v[i].z * 2.0 * r) + Vector3(box.get_center().x, box.end.y - crown_h * 0.5, box.get_center().z)
	arr[Mesh.ARRAY_VERTEX] = v
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.95
	am.surface_set_material(0, m)
	return am


func _multimesh(mesh: Mesh, xforms: Array, name_: String) -> void:
	if mesh == null or xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = name_
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
