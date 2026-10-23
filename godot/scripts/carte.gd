class_name Carte
extends RefCounted
## Donnees de la zone partagees par tous les systemes (circulation, pietons, mobilier, mini-carte, GPS).
## Chargees une seule fois (Carte.zone()) depuis godot/assets/data/zone_aeroport.json (osm_import.py).
## - Graphe routier construit sur les noeuds OSM partages (vrais carrefours), pas sur la simple proximite :
##   un vehicule ne saute plus d'une rue a une rue voisine qui passe a cote.
## - Masques sur une grille de 1 m : chaussees (index de la route) et batiments, pour savoir en un acces si un
##   point est sur la route, sur un trottoir libre ou dans une maison.
## Coordonnees : Vector2(x, z) du monde Godot.

const DATA_PATH := "res://assets/data/zone_aeroport.json"
const CACHE_PATH := "res://assets/data/zone_aeroport_carte.bin"
const CAR_KINDS := ["primary", "secondary", "tertiary", "residential", "unclassified", "service", "living_street",
	"track", "trunk"]
const MAJOR := ["primary", "secondary", "tertiary", "trunk"]

static var _zone: Carte = null

var data: Dictionary
var roads: Array = []          # {pts, width, oneway, kind, surface, name, car, major}
var origin := Vector2.ZERO     # coin nord-ouest de la grille
var gw := 0
var gh := 0
var road_mask := PackedInt32Array()   # index de route voiture + 1 sous la chaussee, 0 ailleurs
var bld_mask := PackedByteArray()     # 1 dans un batiment ou un mur
# graphe : noeuds = carrefours et extremites, aretes = troncons de rue entre deux noeuds
var nodes := PackedVector2Array()
var node_edges: Array = []     # noeud -> [index d'arete]
var edges: Array = []          # {a, b, pts (de a vers b), road, oneway, width, len, major, kind}
const CASE_ARETES := 40.0
var _cases_aretes := {}        # Vector2i -> [[arete, segment, distance depuis a au debut du segment]]
var _cases_min := Vector2i.ZERO
var _cases_max := Vector2i.ZERO


var _eaux: Array = []          # {rect, pts} : bassins, piscines et plans d'eau de la zone (zones "zone_eau" / "zone_piscine")
var _eaux_prete := false


func dans_eau(x: float, z: float) -> bool:
	## vrai si le point est sur un plan d'eau, un bassin ou une piscine (l'eau est un aplat sans collision propre)
	if not _eaux_prete:
		_eaux_prete = true
		for zn in data.get("zones", []):
			if zn["kind"] == "zone_eau" or zn["kind"] == "zone_piscine":
				var poly := PackedVector2Array()
				for q in zn["pts"]:
					poly.append(Vector2(float(q[0]), float(q[1])))
				var r := Rect2(poly[0], Vector2.ZERO)
				for q in poly:
					r = r.expand(q)
				_eaux.append({"rect": r, "pts": poly})
	var p := Vector2(x, z)
	for e in _eaux:
		if (e["rect"] as Rect2).has_point(p) and Geometry2D.is_point_in_polygon(p, e["pts"]):
			return true
	return false


static func zone() -> Carte:
	if _zone == null:
		_zone = Carte.new()
		_zone._load()
	return _zone


func _load() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	var b: Array = data["bounds"]
	origin = Vector2(floorf(float(b[0])) - 2.0, floorf(float(b[1])) - 2.0)
	gw = int(ceilf(float(b[2]) - origin.x)) + 4
	gh = int(ceilf(float(b[3]) - origin.y)) + 4
	for r in data["roads"]:
		var pts := PackedVector2Array()
		for p in r["pts"]:
			pts.append(Vector2(float(p[0]), float(p[1])))
		if pts.size() < 2:
			continue
		var kind: String = r["kind"]
		roads.append({"pts": pts, "width": float(r["width"]), "oneway": bool(r["oneway"]), "kind": kind,
			"surface": r["surface"], "name": r["name"], "car": kind in CAR_KINDS, "major": kind in MAJOR})
	# raccords des impasses et masques au metre : longs a calculer sur la grande carte (une minute), donc lus dans un
	# cache precalcule (tests/outil_cache_carte.gd) quand il correspond aux donnees de la zone (empreinte md5)
	var t := Time.get_ticks_msec()
	var cache := _lire_cache()
	var etapes := "cache %s %d ms" % ["oui" if cache else "non", Time.get_ticks_msec() - t]
	if not cache:
		t = Time.get_ticks_msec()
		_snap_dead_ends()
		etapes += ", raccords %d ms" % (Time.get_ticks_msec() - t)
	t = Time.get_ticks_msec()
	_build_graph()
	etapes += ", graphe %d ms" % (Time.get_ticks_msec() - t)
	t = Time.get_ticks_msec()
	_index_aretes()
	etapes += ", index %d ms" % (Time.get_ticks_msec() - t)
	if not cache:
		t = Time.get_ticks_msec()
		_build_masks()
		etapes += ", masques %d ms" % (Time.get_ticks_msec() - t)
	print("Carte : ", etapes)


func _empreinte() -> String:
	return FileAccess.get_md5(DATA_PATH)


func _lire_cache() -> bool:
	if not FileAccess.file_exists(CACHE_PATH):
		return false
	var f := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d: Variant = bytes_to_var(f.get_buffer(f.get_length()).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP))
	if typeof(d) != TYPE_DICTIONARY or d.get("md5", "") != _empreinte() or (d["pts"] as Array).size() != roads.size():
		return false
	for i in roads.size():
		roads[i]["pts"] = d["pts"][i]
	road_mask = d["road_mask"]
	bld_mask = d["bld_mask"]
	return true


func ecrire_cache(chemin := CACHE_PATH) -> void:
	## Outil (editeur) : enregistre les rues raccordees et les masques calcules, pour les prochains lancements.
	var pts: Array = []
	for r in roads:
		pts.append(r["pts"])
	var octets := var_to_bytes({"md5": _empreinte(), "pts": pts, "road_mask": road_mask, "bld_mask": bld_mask})
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_buffer(octets.compress(FileAccess.COMPRESSION_GZIP))


# ------------------------------------------------------------------ graphe
func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 10.0), roundi(p.y * 10.0))


func _snap_dead_ends() -> void:
	## Rues qui s'arretent a 1-5 m d'une autre sans noeud commun (trace OSM imprecis) : on les raccorde.
	var count := {}
	for r in roads:
		if not r["car"]:
			continue
		var pts: PackedVector2Array = r["pts"]
		for i in pts.size():
			var k := _key(pts[i])
			count[k] = count.get(k, 0) + (1 if i == 0 or i == pts.size() - 1 else 2)
	for ri in roads.size():
		var r: Dictionary = roads[ri]
		if not r["car"]:
			continue
		for end in [0, -1]:
			var pts: PackedVector2Array = r["pts"]
			var ei := 0 if end == 0 else pts.size() - 1
			var p := pts[ei]
			if count.get(_key(p), 0) != 1:
				continue
			# rue coupee au bord de la zone : ce n'est pas un trace imprecis, on ne la raccorde pas
			var bd: Array = data["bounds"]
			if p.x < float(bd[0]) + 1.0 or p.x > float(bd[2]) - 1.0 or p.y < float(bd[1]) + 1.0 or p.y > float(bd[3]) - 1.0:
				continue
			var best_d := 5.0
			var best := []
			for rj in roads.size():
				if rj == ri or not roads[rj]["car"]:
					continue
				var q: PackedVector2Array = roads[rj]["pts"]
				for i in q.size() - 1:
					var c := Geometry2D.get_closest_point_to_segment(p, q[i], q[i + 1])
					var d := c.distance_to(p)
					if d < best_d:
						best_d = d
						best = [rj, i, c]
			if best.is_empty():
				continue
			var c: Vector2 = best[2]
			var q: PackedVector2Array = roads[best[0]]["pts"]
			var at: int = best[1]
			if c.distance_to(q[at]) < 0.5:
				c = q[at]
			elif c.distance_to(q[at + 1]) < 0.5:
				c = q[at + 1]
			else:
				q.insert(at + 1, c)
				roads[best[0]]["pts"] = q
			pts[ei] = c
			r["pts"] = pts
			count[_key(c)] = count.get(_key(c), 0) + 2


func _build_graph() -> void:
	var use := {}
	for r in roads:
		if not r["car"]:
			continue
		var pts: PackedVector2Array = r["pts"]
		for i in pts.size():
			var k := _key(pts[i])
			use[k] = use.get(k, 0) + (1 if i == 0 or i == pts.size() - 1 else 2)
	var node_of := {}
	for ri in roads.size():
		var r: Dictionary = roads[ri]
		if not r["car"]:
			continue
		var pts: PackedVector2Array = r["pts"]
		var cur := PackedVector2Array([pts[0]])
		var start := _node(pts[0], node_of)
		for i in range(1, pts.size()):
			cur.append(pts[i])
			var k := _key(pts[i])
			var is_node: bool = i == pts.size() - 1 or use.get(k, 0) > 2
			if not is_node:
				continue
			var end := _node(pts[i], node_of)
			var L := 0.0
			for j in cur.size() - 1:
				L += cur[j].distance_to(cur[j + 1])
			if L > 0.05 and end != start:
				var e := {"a": start, "b": end, "pts": cur, "road": ri, "oneway": r["oneway"], "width": r["width"],
					"len": L, "major": r["major"], "kind": r["kind"]}
				node_edges[start].append(edges.size())
				node_edges[end].append(edges.size())
				edges.append(e)
			cur = PackedVector2Array([pts[i]])
			start = end


func _node(p: Vector2, node_of: Dictionary) -> int:
	var k := _key(p)
	if node_of.has(k):
		return node_of[k]
	node_of[k] = nodes.size()
	nodes.append(p)
	node_edges.append([])
	return nodes.size() - 1


func edge_pts_from(e: int, from_node: int) -> PackedVector2Array:
	## Points de l'arete dans le sens de parcours depuis from_node.
	var ed: Dictionary = edges[e]
	if ed["a"] == from_node:
		return ed["pts"]
	var p: PackedVector2Array = ed["pts"].duplicate()
	p.reverse()
	return p


func other_end(e: int, n: int) -> int:
	return edges[e]["b"] if edges[e]["a"] == n else edges[e]["a"]


func can_drive(e: int, from_node: int) -> bool:
	return not edges[e]["oneway"] or edges[e]["a"] == from_node


func node_degree(n: int) -> int:
	return (node_edges[n] as Array).size()


# ------------------------------------------------------------------ masques
func _build_masks() -> void:
	road_mask.resize(gw * gh)
	bld_mask.resize(gw * gh)
	for ri in roads.size():
		var r: Dictionary = roads[ri]
		if not r["car"]:
			continue
		var pts: PackedVector2Array = r["pts"]
		var hw: float = r["width"] / 2.0
		for i in pts.size() - 1:
			_stamp_segment(pts[i], pts[i + 1], hw, ri + 1)
	for bld in data["buildings"]:
		if bld.get("roof", "") == "abri":
			continue  # preau ouvert : on passe dessous
		var poly := PackedVector2Array()
		for p in bld["pts"]:
			poly.append(Vector2(float(p[0]), float(p[1])))
		_stamp_polygon(poly)
	for wpts in data.get("walls", []):
		for i in wpts.size() - 1:
			_stamp_wall(Vector2(float(wpts[i][0]), float(wpts[i][1])), Vector2(float(wpts[i + 1][0]), float(wpts[i + 1][1])))
	# terre-pleins centraux : ni trottoir ni chaussee (valeur 2 : bloque pour les pietons, pas un batiment)
	for mpts in data.get("medians", []):
		for i in mpts.size() - 1:
			var a := Vector2(float(mpts[i][0]), float(mpts[i][1]))
			var b := Vector2(float(mpts[i + 1][0]), float(mpts[i + 1][1]))
			var L := a.distance_to(b)
			var steps := maxi(1, int(L / 0.5))
			var n := (b - a).normalized().orthogonal()
			for k in steps + 1:
				for v in [-0.9, -0.3, 0.3, 0.9]:
					var c := cell(a.lerp(b, float(k) / steps) + n * v)
					if c >= 0 and bld_mask[c] == 0:
						bld_mask[c] = 2


func _stamp_segment(a: Vector2, b: Vector2, hw: float, value: int) -> void:
	var L := a.distance_to(b)
	if L < 0.01:
		return
	var d := (b - a) / L
	var n := Vector2(-d.y, d.x)
	var u := -hw
	while u <= L + hw:
		var v := -hw
		while v <= hw:
			# bouts arrondis : au-dela des extremites, seulement dans le demi-disque
			if (u < 0.0 and Vector2(u, v).length() > hw) or (u > L and Vector2(u - L, v).length() > hw):
				v += 0.7
				continue
			var c := cell(a + d * u + n * v)
			if c >= 0 and road_mask[c] == 0:
				road_mask[c] = value
			v += 0.7
		u += 0.7


func _stamp_polygon(poly: PackedVector2Array) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poly:
		lo = lo.min(p)
		hi = hi.max(p)
	for z in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			var q := Vector2(x + 0.5, z + 0.5)
			if Geometry2D.is_point_in_polygon(q, poly):
				var c := cell(q)
				if c >= 0:
					bld_mask[c] = 1


func _stamp_wall(a: Vector2, b: Vector2) -> void:
	var L := a.distance_to(b)
	var steps := maxi(1, int(L / 0.5))
	for i in steps + 1:
		var c := cell(a.lerp(b, float(i) / steps))
		if c >= 0:
			bld_mask[c] = 1


func cell(p: Vector2) -> int:
	var x := floori(p.x - origin.x)
	var z := floori(p.y - origin.y)
	if x < 0 or z < 0 or x >= gw or z >= gh:
		return -1
	return z * gw + x


func road_at(p: Vector2) -> int:
	## Index de la route voiture sous ce point (-1 hors chaussee).
	var c := cell(p)
	return road_mask[c] - 1 if c >= 0 else -1


func on_carriageway(p: Vector2, margin := 0.0) -> bool:
	if margin <= 0.0:
		return road_at(p) >= 0
	for off in [Vector2.ZERO, Vector2(margin, 0), Vector2(-margin, 0), Vector2(0, margin), Vector2(0, -margin),
			Vector2(margin, margin) * 0.7, Vector2(-margin, margin) * 0.7, Vector2(margin, -margin) * 0.7, Vector2(-margin, -margin) * 0.7]:
		if road_at(p + off) >= 0:
			return true
	return false


func in_building(p: Vector2) -> bool:
	var c := cell(p)
	return c >= 0 and bld_mask[c] == 1


func walkable(p: Vector2) -> bool:
	## Ou un pieton peut marcher : pas sur la chaussee (marge 0,4 m), ni dans un batiment ou un mur, ni sur un
	## terre-plein central, et dans la zone de jeu.
	var c := cell(p)
	return c >= 0 and bld_mask[c] == 0 and in_bounds(p) and not on_carriageway(p, 0.4)


func free_ground(p: Vector2, radius: float) -> bool:
	## Ni chaussee ni batiment dans le rayon (test sur la grille de 1 m).
	var r := ceili(radius)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if Vector2(dx, dz).length() > radius + 0.5:
				continue
			var c := cell(p + Vector2(dx, dz))
			if c < 0 or road_mask[c] != 0 or bld_mask[c] != 0:
				return false
	return true


func in_bounds(p: Vector2) -> bool:
	var b: Array = data["bounds"]
	return p.x > float(b[0]) and p.x < float(b[2]) and p.y > float(b[1]) and p.y < float(b[3])


# ------------------------------------------------------------------ itineraire (GPS)
func _index_aretes() -> void:
	## Segments des aretes ranges par cases de CASE_ARETES m (nearest_on_network sans parcourir tout le reseau).
	_cases_min = Vector2i(1 << 30, 1 << 30)
	_cases_max = -_cases_min
	for e in edges.size():
		var pts: PackedVector2Array = edges[e]["pts"]
		var along := 0.0
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var c0 := Vector2i(floori(minf(a.x, b.x) / CASE_ARETES), floori(minf(a.y, b.y) / CASE_ARETES))
			var c1 := Vector2i(floori(maxf(a.x, b.x) / CASE_ARETES), floori(maxf(a.y, b.y) / CASE_ARETES))
			for cx in range(c0.x, c1.x + 1):
				for cy in range(c0.y, c1.y + 1):
					var k := Vector2i(cx, cy)
					if not _cases_aretes.has(k):
						_cases_aretes[k] = []
					_cases_aretes[k].append([e, i, along])
			_cases_min = Vector2i(mini(_cases_min.x, c0.x), mini(_cases_min.y, c0.y))
			_cases_max = Vector2i(maxi(_cases_max.x, c1.x), maxi(_cases_max.y, c1.y))
			along += a.distance_to(b)


func nearest_on_network(p: Vector2) -> Dictionary:
	## Point de rue le plus proche : {edge, point, dist, along (distance depuis le noeud a)}. Recherche par anneaux de
	## cases autour du point ; a distance egale, la plus petite arete puis le premier segment (comme un parcours complet).
	var best := {"edge": -1, "dist": INF}
	var bs := -1
	var k0 := Vector2i(floori(p.x / CASE_ARETES), floori(p.y / CASE_ARETES))
	var r_max := maxi(maxi(absi(k0.x - _cases_min.x), absi(_cases_max.x - k0.x)), maxi(absi(k0.y - _cases_min.y), absi(_cases_max.y - k0.y)))
	for r in r_max + 1:
		for cx in range(k0.x - r, k0.x + r + 1):
			for cy in range(k0.y - r, k0.y + r + 1):
				if maxi(absi(cx - k0.x), absi(cy - k0.y)) != r:
					continue
				for s in _cases_aretes.get(Vector2i(cx, cy), []):
					var e: int = s[0]
					var i: int = s[1]
					var pts: PackedVector2Array = edges[e]["pts"]
					var c := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
					var d := c.distance_to(p)
					if d < best["dist"] or (d == best["dist"] and (e < best["edge"] or (e == best["edge"] and i < bs))):
						best = {"edge": e, "point": c, "dist": d, "along": float(s[2]) + pts[i].distance_to(c)}
						bs = i
		# les cases de l'anneau suivant sont toutes a plus de r cases du point
		if best["edge"] >= 0 and best["dist"] <= r * CASE_ARETES:
			break
	return best


func route(from: Vector2, to: Vector2, respect_oneway := true) -> PackedVector2Array:
	## Plus court chemin sur le reseau (A*), sens interdits respectes pour les vehicules. Renvoie la polyligne
	## depuis le point de rue le plus proche du depart jusqu'au point de rue le plus proche de l'arrivee.
	var s := nearest_on_network(from)
	var t := nearest_on_network(to)
	if s["edge"] < 0 or t["edge"] < 0:
		return PackedVector2Array()
	var se: Dictionary = edges[s["edge"]]
	var te: Dictionary = edges[t["edge"]]
	if s["edge"] == t["edge"] and (not se["oneway"] or t["along"] >= s["along"]):
		return PackedVector2Array([s["point"], t["point"]])
	# noeuds de depart : extremites de l'arete de depart atteignables depuis le point
	var dist := {}
	var prev := {}
	var open: Array = []   # [f, g, noeud]
	var starts := [[se["b"], se["len"] - s["along"]]]
	if not se["oneway"] or not respect_oneway:
		starts.append([se["a"], s["along"]])
	for st in starts:
		dist[st[0]] = st[1]
		prev[st[0]] = -1
		open.append([st[1] + nodes[st[0]].distance_to(to), st[1], st[0]])
	# arrivee : on entre dans l'arete cible par a (si autorise) ou par b
	var goal_cost := {}
	goal_cost[te["a"]] = t["along"]
	if not te["oneway"] or not respect_oneway:
		goal_cost[te["b"]] = te["len"] - t["along"]
	var best_end := -1
	var best_total := INF
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if open[i][0] < open[bi][0]:
				bi = i
		var cur: Array = open[bi]
		open.remove_at(bi)
		var n: int = cur[2]
		var g: float = cur[1]
		if g > dist.get(n, INF) + 0.001:
			continue
		if g >= best_total:
			break
		if goal_cost.has(n) and g + goal_cost[n] < best_total:
			best_total = g + goal_cost[n]
			best_end = n
		for e in node_edges[n]:
			if respect_oneway and not can_drive(e, n):
				continue
			var m := other_end(e, n)
			var ng: float = g + edges[e]["len"]
			if ng < dist.get(m, INF):
				dist[m] = ng
				prev[m] = [n, e]
				open.append([ng + nodes[m].distance_to(to), ng, m])
	if best_end < 0:
		if respect_oneway:
			return route(from, to, false)  # a pied ou en dernier recours
		return PackedVector2Array()
	# reconstitution : point de depart -> premier noeud -> aretes -> point d'arrivee
	var chain: Array = []
	var n := best_end
	while prev.get(n, -1) is Array:
		chain.push_front(prev[n])
		n = prev[n][0]
	var out := PackedVector2Array([s["point"]])
	out.append_array(_partial(s["edge"], s["along"], n))
	for step in chain:
		var pts := edge_pts_from(step[1], step[0])
		for i in range(1, pts.size()):
			out.append(pts[i])
	# derniere portion dans l'arete cible jusqu'au point d'arrivee
	var tp := edge_pts_from(t["edge"], best_end)
	var remain: float = goal_cost[best_end]
	var acc := 0.0
	for i in tp.size() - 1:
		var L := tp[i].distance_to(tp[i + 1])
		if acc + L >= remain:
			out.append(tp[i].lerp(tp[i + 1], (remain - acc) / maxf(L, 0.001)))
			break
		out.append(tp[i + 1])
		acc += L
	return out


func _partial(e: int, along: float, to_node: int) -> PackedVector2Array:
	## Points de l'arete e depuis la position 'along' jusqu'au noeud to_node (inclus).
	var pts: PackedVector2Array = edges[e]["pts"]
	var before := PackedVector2Array()
	var after := PackedVector2Array()
	var cum := 0.0
	for i in pts.size():
		if i > 0:
			cum += pts[i - 1].distance_to(pts[i])
		if cum < along - 0.01:
			before.append(pts[i])
		elif cum > along + 0.01:
			after.append(pts[i])
	if to_node == edges[e]["b"]:
		return after
	before.reverse()
	return before


# ------------------------------------------------------------ zone reservee de l'aeroport (cote piste)
@export var marge_piste := 45.0        # m de part et d'autre de l'axe d'une piste
var _reserve_prete := false
var _pistes: Array = []                # [[Vector2 a, Vector2 b], ...] segments des pistes
var _tarmacs: Array = []               # polygones des aires de stationnement d'avions
var _reserve_aretes := {}


func zone_reservee(p: Vector2) -> bool:
	## Vrai cote piste (pistes, aires de stationnement des avions) : ni vendeurs ambulants, ni zems, ni voitures de particuliers,
	## ni passants ordinaires (docs/benin-gta-roadmap.md : fidelite de l'aeroport).
	if not _reserve_prete:
		_reserve_prete = true
		for r in data.get("runways", []):
			for i in range(0, r.size() - 1):
				_pistes.append([Vector2(float(r[i][0]), float(r[i][1])), Vector2(float(r[i + 1][0]), float(r[i + 1][1])), marge_piste])
		for aw in data.get("aeroways", []):
			var demi := marge_piste if aw["kind"] in ["runway", "stopway"] else 25.0
			var ap: Array = aw["pts"]
			for i in range(0, ap.size() - 1):
				_pistes.append([Vector2(float(ap[i][0]), float(ap[i][1])), Vector2(float(ap[i + 1][0]), float(ap[i + 1][1])), demi])
		for z in data.get("zones", []):
			if z["kind"] == "aeroport_tarmac":
				var poly := PackedVector2Array()
				for q in z["pts"]:
					poly.append(Vector2(float(q[0]), float(q[1])))
				_tarmacs.append(poly)
	for poly in _tarmacs:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	for s in _pistes:
		if Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p) < s[2]:
			return true
	return false


func arete_reservee(e: int) -> bool:
	## Une arete (rue) dont le milieu est cote piste.
	if _reserve_aretes.has(e):
		return _reserve_aretes[e]
	var pts: PackedVector2Array = edges[e]["pts"]
	var m := pts[pts.size() / 2]
	var r := zone_reservee(m) or zone_reservee(pts[0]) or zone_reservee(pts[pts.size() - 1])
	_reserve_aretes[e] = r
	return r
