extends Node3D
## Concessions de Cotonou (phase 6, details urbains) : la plupart des maisons basses sont entourees d'un mur
## d'enceinte enduit (1,9 m) avec un portail en tole peinte cote rue. OpenStreetMap n'en connait qu'une cinquantaine
## (deja importes) : les autres sont generes autour des maisons de plain-pied ou R+1 (30 a 400 m2), seulement la ou il
## y a la place (ni sur la chaussee, ni dans un autre batiment ou une autre concession, ni pres d'un mur OSM).
## Murs en MultiMesh (couleur par instance), collisions en boites, murs marques sur la carte de marche des pietons.
## Tirage deterministe (une graine par batiment) : memes concessions a chaque partie. Pose tuile par tuile (monde.gd) :
## murs, portails et collisions de chaque tuile partent avec elle.

@export var marge := 2.4               # m entre la maison et le mur (cour)
@export var marge_min := 1.4
@export var hauteur := 1.9
@export var epaisseur := 0.18
@export var portail := 3.0             # m de large
@export var aire := Vector2(30.0, 400.0)
@export var exclure_rayon := 35.0      # m autour des lieux (maison du joueur, Ararat, aerogare)

const MURS := [Color(0.86, 0.82, 0.72), Color(0.8, 0.68, 0.5), Color(0.92, 0.9, 0.86), Color(0.72, 0.7, 0.66),
	Color(0.85, 0.75, 0.6)]
const PORTAILS := [Color(0.1, 0.25, 0.55), Color(0.12, 0.4, 0.22), Color(0.55, 0.12, 0.1), Color(0.2, 0.2, 0.22),
	Color(0.75, 0.55, 0.15)]

@export var monde_path: NodePath = ^"../zone_aeroport"

var count := 0
var _rects := {}                # Vector2i (case de 50 m) -> rectangles acceptes {c, u, v, hu, hv, tuile}
var _murs_osm := {}             # Vector2i (case de 25 m) -> points des murs OSM
var _par_tuile := {}            # Vector2i -> {noeuds, rects}
var _avoid: Array = []
var _carte: Carte
var _rng := RandomNumberGenerator.new()


const PAQUET := 20    # batiments par etape de construction


func _ready() -> void:
	_carte = Carte.zone()
	var data: Dictionary = _carte.data   # lu une seule fois pour tout le jeu
	for b in data["buildings"]:
		if String(b.get("style", "")).begins_with("lieu_") or b.get("style") in ["terminal", "hangar"]:
			_avoid.append(_centroid(b["pts"]))
	for w in data.get("walls", []):
		for q in w:
			var c := Vector2i(floori(float(q[0]) / 25.0), floori(float(q[1]) / 25.0))
			if not _murs_osm.has(c):
				_murs_osm[c] = []
			_murs_osm[c].append(Vector2(q[0], q[1]))
	var monde := get_node_or_null(monde_path) as Monde
	if monde == null:
		_tuile(Vector2i.ZERO, Rect2(-1e6, -1e6, 2e6, 2e6), true)
		return
	var cles: Array = monde.tuiles.keys().filter(func(c: Vector2i) -> bool: return monde.tuiles[c]["noeud"] != null)
	cles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	for cle in cles:
		_tuile(cle, monde.tuiles[cle]["rect"], true)
	monde.tuile_chargee.connect(func(cle: Vector2i, _n: Node3D) -> void:
		if not _par_tuile.has(cle):
			_tuile(cle, monde.tuiles[cle]["rect"], false))
	monde.tuile_dechargee.connect(liberer_tuile)


func _tuile(cle: Vector2i, rect: Rect2, au_chargement: bool) -> void:
	## Concessions des maisons dont le centre est dans la tuile ; au chargement par paquets de PAQUET batiments, en
	## cours de partie en travail de fond (paquets de 4).
	var bats: Array = _carte.data["buildings"]
	var lot: Array = []
	for bi in bats.size():
		if rect.has_point(_centroid(bats[bi]["pts"])):
			lot.append(bi)
	var ctx := {"noeuds": [], "rects": [], "walls": [], "gates": []}
	_par_tuile[cle] = ctx
	var n := PAQUET if au_chargement else 4
	var etape := func(f: Callable) -> void:
		var g := func() -> void:
			if _par_tuile.get(cle) == ctx:
				f.call()
		if au_chargement:
			Partie.chantier(g)
		else:
			Partie.tache(g)
	for debut in range(0, lot.size(), n):
		etape.call(_paquet.bind(lot.slice(debut, debut + n), ctx))
	etape.call(func() -> void:
		count += ctx["rects"].size()
		_meshes(ctx, "%d_%d" % [cle.x, cle.y]))


func liberer_tuile(cle: Vector2i) -> void:
	var ctx: Dictionary = _par_tuile.get(cle, {})
	_par_tuile.erase(cle)
	for nd in ctx.get("noeuds", []):
		if is_instance_valid(nd):
			(nd as Node).queue_free()
	for r in ctx.get("rects", []):
		(_rects.get(_case(r["c"]), []) as Array).erase(r)
	count -= ctx.get("rects", []).size()


func _case(c: Vector2) -> Vector2i:
	return Vector2i(floori(c.x / 50.0), floori(c.y / 50.0))


func _paquet(lot: Array, ctx: Dictionary) -> void:
	var bats: Array = _carte.data["buildings"]
	for bi in lot:
		var b: Dictionary = bats[bi]
		if float(b.get("h", 99)) > 7.5 or String(b.get("style", "")).begins_with("lieu_") or b.get("style") in ["terminal", "hangar", null]:
			continue
		var pts: Array = b["pts"]
		var ar := _area(pts)
		if ar < aire.x or ar > aire.y:
			continue
		var c := _centroid(pts)
		var near_lieu := false
		for a in _avoid:
			if (a as Vector2).distance_to(c) < exclure_rayon:
				near_lieu = true
		if near_lieu or _near_osm_wall(c):
			continue
		var rect := _fit(pts)
		if rect.is_empty():
			continue
		ctx["rects"].append(rect)
		_rng.seed = hash([2610, bi])
		var col: Color = MURS[_rng.randi() % MURS.size()]
		var gcol: Color = PORTAILS[_rng.randi() % PORTAILS.size()]
		_ring(rect, col, gcol, ctx["walls"], ctx["gates"])


func _centroid(pts: Array) -> Vector2:
	var s := Vector2.ZERO
	for p in pts:
		s += Vector2(p[0], p[1])
	return s / maxf(pts.size(), 1)


func _area(pts: Array) -> float:
	var a := 0.0
	for i in pts.size():
		var p: Array = pts[i]
		var q: Array = pts[(i + 1) % pts.size()]
		a += p[0] * q[1] - q[0] * p[1]
	return absf(a) * 0.5


func _near_osm_wall(c: Vector2) -> bool:
	var k := Vector2i(floori(c.x / 25.0), floori(c.y / 25.0))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for q in _murs_osm.get(k + Vector2i(dx, dz), []):
				if (q as Vector2).distance_to(c) < 25.0:
					return true
	return false


func _fit(pts: Array) -> Dictionary:
	## Rectangle oriente sur le plus long cote de la maison, agrandi de la cour ; on essaie la marge pleine puis la
	## marge minimale. Vide si rien ne tient.
	var best_len := 0.0
	var u := Vector2.RIGHT
	for i in pts.size():
		var a := Vector2(pts[i][0], pts[i][1])
		var b := Vector2(pts[(i + 1) % pts.size()][0], pts[(i + 1) % pts.size()][1])
		if a.distance_to(b) > best_len:
			best_len = a.distance_to(b)
			u = (b - a).normalized()
	var v := Vector2(-u.y, u.x)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		var q := Vector2(p[0], p[1])
		var l := Vector2(q.dot(u), q.dot(v))
		lo = Vector2(minf(lo.x, l.x), minf(lo.y, l.y))
		hi = Vector2(maxf(hi.x, l.x), maxf(hi.y, l.y))
	var mid := (lo + hi) * 0.5
	var half := (hi - lo) * 0.5
	var center := u * mid.x + v * mid.y
	for m in [marge, (marge + marge_min) * 0.5, marge_min]:
		var r := {"c": center, "u": u, "v": v, "hu": half.x + m, "hv": half.y + m}
		if _free(r):
			var k := _case(center)
			if not _rects.has(k):
				_rects[k] = []
			_rects[k].append(r)
			return r
	return {}


func _corner(r: Dictionary, su: float, sv: float) -> Vector2:
	return r["c"] + r["u"] * (r["hu"] * su) + r["v"] * (r["hv"] * sv)


func _free(r: Dictionary) -> bool:
	## Le trace du mur (echantillonne tous les 0,8 m) ne touche ni chaussee, ni batiment, ni autre concession.
	var corners := [_corner(r, -1, -1), _corner(r, 1, -1), _corner(r, 1, 1), _corner(r, -1, 1)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var n := int(a.distance_to(b) / 0.8) + 1
		for k in n + 1:
			var p := a.lerp(b, float(k) / n)
			if not _carte.in_bounds(p) or _carte.on_carriageway(p, 1.2) or _carte.in_building(p):
				return false
			var kc := _case(p)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					for o in _rects.get(kc + Vector2i(dx, dz), []):
						var d: Vector2 = p - o["c"]
						if absf(d.dot(o["u"])) < o["hu"] + 0.6 and absf(d.dot(o["v"])) < o["hv"] + 0.6:
							return false
	return true


func _ring(r: Dictionary, col: Color, gcol: Color, walls: Array, gates: Array) -> void:
	## 4 murs ; le portail est sur le cote le plus proche d'une rue.
	var corners := [_corner(r, -1, -1), _corner(r, 1, -1), _corner(r, 1, 1), _corner(r, -1, 1)]
	var best := 0
	var bd := INF
	for i in 4:
		var mid: Vector2 = (corners[i] + corners[(i + 1) % 4]) * 0.5
		var near := _carte.nearest_on_network(mid)
		if float(near.get("dist", INF)) < bd:
			bd = near["dist"]
			best = i
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		if i == best and a.distance_to(b) > portail + 2.0:
			var m := (a + b) * 0.5
			var dir := (b - a).normalized()
			walls.append([a, m - dir * portail * 0.5, col])
			walls.append([m + dir * portail * 0.5, b, col])
			gates.append([m, atan2(-dir.y, dir.x), gcol, dir])
		else:
			walls.append([a, b, col])
		_carte._stamp_wall(a, b)


func _meshes(ctx: Dictionary, nom: String) -> void:
	var walls: Array = ctx["walls"]
	var gates: Array = ctx["gates"]
	if walls.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	box.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box
	mm.instance_count = walls.size() + gates.size() * 2
	var body := StaticBody3D.new()
	body.name = "MursConcessions_" + nom
	add_child(body)
	ctx["noeuds"].append(body)
	var idx := 0
	for w in walls:
		var a: Vector2 = w[0]
		var b: Vector2 = w[1]
		var len := a.distance_to(b)
		if len < 0.05:
			continue
		var mid := (a + b) * 0.5
		var yaw := atan2(-(b - a).y, (b - a).x)
		var y := _ground(mid)
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(len + epaisseur, hauteur, epaisseur)), Vector3(mid.x, y + hauteur * 0.5, mid.y))
		mm.set_instance_transform(idx, xf)
		mm.set_instance_color(idx, w[2])
		idx += 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(len + epaisseur, hauteur, epaisseur)
		cs.shape = sh
		cs.transform = Transform3D(Basis(Vector3.UP, yaw), xf.origin)
		body.add_child(cs)
	# portail : deux battants de tole peinte, un peu plus haut que le mur
	for g in gates:
		var m: Vector2 = g[0]
		var dir: Vector2 = g[3]
		var y := _ground(m)
		for s in [-1.0, 1.0]:
			var c: Vector2 = m + dir * (portail * 0.25 * s)
			var xf := Transform3D(Basis(Vector3.UP, g[1]).scaled(Vector3(portail * 0.5 - 0.04, 2.1, 0.06)), Vector3(c.x, y + 1.05, c.y))
			mm.set_instance_transform(idx, xf)
			mm.set_instance_color(idx, g[2])
			idx += 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(portail, 2.1, 0.1)
		cs.shape = sh
		cs.transform = Transform3D(Basis(Vector3.UP, g[1]), Vector3(m.x, y + 1.05, m.y))
		body.add_child(cs)
	mm.visible_instance_count = idx
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Concessions_" + nom
	mmi.multimesh = mm
	mmi.visibility_range_end = 450.0
	add_child(mmi)
	ctx["noeuds"].append(mmi)


func _ground(p: Vector2) -> float:
	return 0.0     # terrain plat dans la zone (relief Copernicus ecarte, voir le journal)
