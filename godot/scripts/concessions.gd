extends Node3D
## Concessions de Cotonou (phase 6, details urbains) : la plupart des maisons basses sont entourees d'un mur
## d'enceinte enduit (1,9 m) avec un portail en tole peinte cote rue. OpenStreetMap n'en connait qu'une cinquantaine
## (deja importes) : les autres sont generes autour des maisons de plain-pied ou R+1 (30 a 400 m2), seulement la ou il
## y a la place (ni sur la chaussee, ni dans un autre batiment ou une autre concession, ni pres d'un mur OSM).
## Murs en MultiMesh (couleur par instance), collisions en boites, murs marques sur la carte de marche des pietons.
## Tirage deterministe (graine fixe) : memes concessions a chaque partie.

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

var count := 0
var _rects: Array = []          # rectangles acceptes : [centre, axe u, axe v, demi u, demi v]
var _carte: Carte
var _rng := RandomNumberGenerator.new()


const PAQUET := 20    # batiments par etape de construction (~40 ms)


func _ready() -> void:
	_rng.seed = 2610
	_carte = Carte.zone()
	_build()


func _build() -> void:
	var data: Dictionary = Carte.zone().data   # lu une seule fois pour tout le jeu
	var avoid: Array = []
	for b in data["buildings"]:
		if String(b.get("style", "")).begins_with("lieu_") or b.get("style") in ["terminal", "hangar"]:
			avoid.append(_centroid(b["pts"]))
	var osm_walls: Array = data.get("walls", [])
	var walls: Array = []          # [a, b, couleur]
	var gates: Array = []          # [centre, yaw, couleur]
	# par paquets de batiments : etale sur plusieurs images pendant l'ecran de chargement (Partie.chantier)
	var bats: Array = data["buildings"]
	for debut in range(0, bats.size(), PAQUET):
		Partie.chantier(_paquet.bind(bats, debut, avoid, osm_walls, walls, gates))
	Partie.chantier(func() -> void:
		count = _rects.size()
		_meshes(walls, gates))


func _paquet(bats: Array, debut: int, avoid: Array, osm_walls: Array, walls: Array, gates: Array) -> void:
	for b in bats.slice(debut, debut + PAQUET):
		if float(b.get("h", 99)) > 7.5 or String(b.get("style", "")).begins_with("lieu_") or b.get("style") in ["terminal", "hangar", null]:
			continue
		var pts: Array = b["pts"]
		var ar := _area(pts)
		if ar < aire.x or ar > aire.y:
			continue
		var c := _centroid(pts)
		var near_lieu := false
		for a in avoid:
			if (a as Vector2).distance_to(c) < exclure_rayon:
				near_lieu = true
		if near_lieu or _near_osm_wall(c, osm_walls):
			continue
		var rect := _fit(pts)
		if rect.is_empty():
			continue
		var col: Color = MURS[_rng.randi() % MURS.size()]
		var gcol: Color = PORTAILS[_rng.randi() % PORTAILS.size()]
		_ring(rect, col, gcol, walls, gates)


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


func _near_osm_wall(c: Vector2, walls: Array) -> bool:
	for w in walls:
		for p in w:
			if Vector2(p[0], p[1]).distance_to(c) < 25.0:
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
			_rects.append(r)
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
			for o in _rects:
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


func _meshes(walls: Array, gates: Array) -> void:
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
	body.name = "MursConcessions"
	add_child(body)
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
	mmi.name = "Concessions"
	mmi.multimesh = mm
	mmi.visibility_range_end = 450.0
	add_child(mmi)


func _ground(p: Vector2) -> float:
	return 0.0     # terrain plat dans la zone (relief Copernicus ecarte, voir le journal)
