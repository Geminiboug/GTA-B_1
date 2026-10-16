extends Node3D
## Trafic aerien realiste sur l'aeroport (piste 06/24 de 2 400 m, axe tire des donnees OSM et prolonge hors carte).
## - Postes de stationnement OSM : des avions y sont gares (compagnies fictives), d'autres arrivent et repartent.
## - Depart : repoussage par un tracteur, mise en route, roulage sur les taxiways reels (T2 parallele a la piste,
##   T1 vers la piste, raquette T4 au seuil 06 ; prolongements hors carte vers le seuil 24), alignement, course au
##   decollage (VR ~ 140 kt), rotation a 2,5 deg/s, envol, train rentre 3 s apres, volets rentres a 400 m.
## - Arrivee : approche finale stabilisee a 3 deg (feux et train sortis, volets pleins), arrondi vers 14 m,
##   toucher train principal dans la zone de toucher (fumee, crissement), spoilers, inverseurs, freinage,
##   degagement par un taxiway, roulage jusqu'au poste, arret des reacteurs.
## - Piste en service : 06 ou 24 (une seule a la fois), un mouvement a la fois (piste occupee).
## Pilotage cinematique : le train principal suit la trajectoire (poursuite pure, braquage de la roue avant),
## le nez pivote autour du train principal a la rotation et a l'arrondi.

const AVION := preload("res://scripts/avion.gd")
const RUNWAY_LENGTH := 2400.0
const T2_S := 191.0            # taxiway parallele (T2) a 191 m de l'axe, cote aerogare
const NOSE_GEAR := 12.6        # du train principal au train avant (m)
const GROUND_Y := 0.017

@export var first_delay := 45.0
@export var min_gap := 40.0          # s reelles mini entre deux mouvements (piste degagee)
# Frequence reelle de Cotonou-Cadjehoun : ~35 mouvements commerciaux par jour (donnees ASECNA / ACI, ordre de
# grandeur), concentres de 6 h a 1 h avec une pointe le soir (vols long-courriers d'Europe et d'Afrique de l'Est).
# Mouvements par heure de jeu, heure par heure (0 h a 23 h) ; une heure de jeu dure minutes_per_game_day / 24.
@export var movements_per_hour: Array[float] = [0.6, 0.3, 0.0, 0.0, 0.0, 0.3, 1.2, 2.0, 2.0, 1.6, 1.4, 1.4,
	1.6, 1.6, 1.4, 1.4, 1.6, 2.0, 2.4, 2.6, 2.6, 2.4, 1.8, 1.2]
@export var runway_24_share := 0.85   # vent de mer du sud-ouest dominant : piste 24 le plus souvent
@export var initial_parked := 3

var stands: Array = []         # {pos (train principal), dir (nez), t, s, plane}
var planes: Array = []
var _a := Vector2.ZERO         # seuil 06
var _u := Vector2.ZERO         # 06 -> 24
var _n := Vector2.ZERO         # vers l'aerogare
var _t1: Array = []            # taxiway T1 (de la piste vers T2)
var _t1w: Array = []           # T1, troncon ouest : bord nord (vers la piste) -> carrefour J avec T3
var _t1e: Array = []           # T1, troncon est : J -> T2 (t ~ 680)
var _t3: Array = []            # T3 : J -> T2 (t ~ 618), vers le sud-ouest
var _t3_t := 618.0
var _t4: Array = []            # raquette du seuil 06 (de la piste t=189 a t=10)
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _day: Node
var mv := {}                   # mouvement en cours (pour les tests)


func _ready() -> void:
	_rng.randomize()
	_day = get_node_or_null("../JourNuit")
	var data: Dictionary = Carte.zone().data
	var best: Array = []
	for r in data.get("runways", []):
		if r.size() > best.size():
			best = r
	if best.size() < 2:
		set_process(false)
		set_physics_process(false)
		return
	var p0 := Vector2(float(best[0][0]), float(best[0][1]))
	var p1 := Vector2(float(best[-1][0]), float(best[-1][1]))
	if p1.x < p0.x:
		var tmp := p0
		p0 = p1
		p1 = tmp
	_a = p0
	_u = (p1 - p0).normalized()
	_n = Vector2(-_u.y, _u.x)
	_find_taxiways(data)
	_split_t1(data)
	_find_stands(data)
	for i in mini(initial_parked, stands.size()):
		var k := _free_stand()
		if k >= 0:
			_park_new(k)
	_timer = first_delay


# ------------------------------------------------------------------ geometrie
func rw(t: float, s: float) -> Vector2:
	return _a + _u * t + _n * s


func to_rw(p: Vector2) -> Vector2:
	var d := p - _a
	return Vector2(d.dot(_u), d.dot(_n))


const CLIP_Z := -386.06       # limite nord de la premiere zone : les trajets de roulage ont ete regles sur ces troncons


func _taxi_pts(aw: Dictionary) -> Array:
	## Taxiway coupe a l'ancienne limite nord (la zone agrandie en phase 9 contient les taxiways entiers ; T1, T3 et T4
	## sont reconnus par leurs extremites telles qu'elles etaient au bord de la carte).
	var out: Array = []
	var prev := Vector2.INF
	for q in aw["pts"]:
		var p := Vector2(float(q[0]), float(q[1]))
		var inside := p.y >= CLIP_Z
		if prev != Vector2.INF and (prev.y >= CLIP_Z) != inside:
			var k := (CLIP_Z - prev.y) / (p.y - prev.y)
			var x := prev.lerp(p, k)
			if inside:
				out.append(x)
			else:
				out.append(x)
				break
		if inside:
			out.append(p)
		prev = p
	return out


func _find_taxiways(data: Dictionary) -> void:
	for aw in data.get("aeroways", []):
		if aw["kind"] != "taxiway":
			continue
		var pts: Array = _taxi_pts(aw)
		if pts.size() < 2:
			continue
		var r0 := to_rw(pts[0])
		var r1 := to_rw(pts[pts.size() - 1])
		# T1 : relie T2 (s ~ 191) au bord nord de la carte en direction de la piste (s ~ 117)
		if absf(r0.y - 117.0) < 25.0 and absf(r1.y - T2_S) < 15.0:
			_t1 = pts
		elif absf(r1.y - 117.0) < 25.0 and absf(r0.y - T2_S) < 15.0:
			pts.reverse()
			_t1 = pts
		# T4 : raquette entre t ~ 10 et t ~ 190 sur l'axe
		elif absf(r0.y) < 6.0 and absf(r1.y) < 6.0 and absf(r0.x - r1.x) > 120.0:
			if r0.x > r1.x:
				_t4 = pts
			else:
				pts.reverse()
				_t4 = pts


func _split_t1(data: Dictionary) -> void:
	## T1 rejoint T2 en Y vers le nord-est ; le raccord T3 part du meme carrefour J vers le sud-ouest.
	if _t1.is_empty():
		return
	for aw in data.get("aeroways", []):
		if aw["kind"] != "taxiway":
			continue
		var pts: Array = _taxi_pts(aw)
		if pts.size() < 2:
			continue
		for flip in [false, true]:
			var cand: Array = pts.duplicate()
			if flip:
				cand.reverse()
			var j := -1
			for i in range(1, _t1.size() - 1):
				if (_t1[i] as Vector2).distance_to(cand[0]) < 2.0:
					j = i
			if j > 0 and absf(to_rw(cand[cand.size() - 1]).y - T2_S) < 15.0:
				_t3 = cand
				_t3_t = to_rw(cand[cand.size() - 1]).x
				_t1w = _t1.slice(0, j + 1)
				_t1e = _t1.slice(j)
				return
	_t1w = _t1.duplicate()
	_t1e = []


func _to_runway_06(st: Dictionary) -> Array:
	## Depuis le poste : T2 puis T3 (postes au sud-ouest) ou T2 puis T1 est (postes au nord-est), T1 ouest, piste.
	var path: Array = []
	var west: bool = float(st["t"]) < 650.0 and not _t3.is_empty()
	var j_t := _t3_t if west else 680.0
	path.append_array(_t2_line(float(st["t"]) + (22.0 if west else -22.0), j_t))
	var link: Array = _t3.duplicate() if west else _t1e.duplicate()
	link.reverse()
	path.append_array(link)
	var w := _t1w.duplicate()
	w.reverse()
	path.append_array(w)
	return path


func _from_t1(st: Dictionary) -> Array:
	## Sortie de piste par T1 (arrivee en 24) jusqu'a T2, du bon cote du poste.
	var path: Array = _t1w.duplicate()
	var west: bool = float(st["t"]) < 650.0 and not _t3.is_empty()
	path.append_array(_t3 if west else _t1e)
	return path


func _find_stands(data: Dictionary) -> void:
	for sp in data.get("parking_positions", []):
		if sp.size() < 5:
			continue
		var p := Vector2(float(sp[0]), float(sp[1]))
		if p.y < CLIP_Z:
			continue      # au-dela de la premiere zone : pas de trajet de roulage regle jusque-la
		var d := Vector2(float(sp[3]), float(sp[4])).normalized()
		var r := to_rw(p)
		if d.dot(_n) < 0.5 or r.y < 230.0:
			continue      # poste inutilisable par un biréacteur de cette taille (trop pres du taxiway, ou sens inverse)
		var dup := false
		for st in stands:
			if (st["nose"] as Vector2).distance_to(p) < 30.0:
				dup = true
		if dup or not _stand_clear(p - d * NOSE_GEAR, d):
			continue
		stands.append({"nose": p, "dir": d, "pos": p - d * NOSE_GEAR, "t": r.x, "s": r.y, "plane": null})


func _stand_clear(pos: Vector2, d: Vector2) -> bool:
	## Envergure (35,8 m), nez et queue hors des batiments sur la ligne droite d'entree depuis T2 jusqu'au poste.
	var carte := Carte.zone()
	var side := Vector2(-d.y, d.x)
	var q := pos
	while to_rw(q).y > T2_S + 20.0:
		for c in [q + side * 17.9, q - side * 17.9, q + d * 20.6, q - d * 17.0]:
			if carte.in_bounds(c) and carte.in_building(c):
				return false
		q -= d * 2.0
	return true


func _free_stand() -> int:
	var free: Array = []
	for i in stands.size():
		if stands[i]["plane"] == null and not stands[i].get("reserved", false):
			free.append(i)
	return free[_rng.randi() % free.size()] if not free.is_empty() else -1


func _new_plane() -> Node3D:
	var p := Node3D.new()
	p.set_script(AVION)
	p.set("livery", AVION.LIVERIES.keys()[_rng.randi() % AVION.LIVERIES.size()])
	p.set("day", _day)
	add_child(p)
	planes.append(p)
	return p


func _park_new(k: int) -> void:
	var p := _new_plane()
	var st: Dictionary = stands[k]
	st["plane"] = p
	_place(p, st["pos"], st["dir"], 0.0, 0.0)
	p.set("lights", {"nav": true, "beacon": false, "strobe": false, "landing": false, "taxi": false})
	p.call("set_parked", true)


func _place(p: Node3D, pos: Vector2, heading: Vector2, h: float, pitch: float, roll := 0.0) -> void:
	var b := Basis.looking_at(Vector3(heading.x, 0, heading.y), Vector3.UP) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, roll)
	p.global_transform = Transform3D(b, Vector3(pos.x, GROUND_Y + h, pos.y))


# ------------------------------------------------------------------ planification
func _process(delta: float) -> void:
	if mv.is_empty():
		_timer -= delta
		if _timer <= 0.0:
			_schedule()
	else:
		_step(delta)


func _schedule() -> void:
	var hour: float = _day.get("hour") if _day else 12.0
	if movements_per_hour[int(hour) % 24] <= 0.01:
		_timer = _next_gap()   # aeroport ferme la nuit (pas de vol commercial entre 2 h et 5 h)
		return
	var parked: Array = []
	for i in stands.size():
		if stands[i]["plane"] != null:
			parked.append(i)
	var free := _free_stand()
	var runway := "24" if _rng.randf() < runway_24_share else "06"
	if free >= 0 and (parked.is_empty() or _rng.randf() < 0.5):
		start_arrival(runway)
	elif not parked.is_empty():
		start_departure(parked[_rng.randi() % parked.size()], runway)
	else:
		_timer = 30.0


func start_departure(k: int, runway: String) -> void:
	var st: Dictionary = stands[k]
	var p: Node3D = st["plane"]
	if p == null:
		return
	# repoussage : le nez se retrouve vers la jonction a prendre sur T2 (T1 pour la 06, nord-est pour la 24)
	var to_t1 := runway == "06"
	var go_ne: bool = (not to_t1) or float(st["t"]) < 650.0
	var head := _u if go_ne else -_u
	var t_push: float = st["t"] + (-22.0 if go_ne else 22.0)
	var end := rw(t_push, T2_S)
	var path: Array = [end]          # le roulage part de la ou le tracteur a laisse l'avion
	if to_t1:
		path.append_array(_to_runway_06(st))
		path.append_array([rw(650.0, 60.0), rw(648.0, 22.0), rw(630.0, 3.0), rw(600.0, 0.0)])
		path.append_array(_rw_line(560.0, 200.0))
		var R := 28.0
		for q in _t4:
			if to_rw(q).y > R + 4.0 or to_rw(q).x > 60.0:
				path.append(q)
		for j in range(0, 10):
			var ang := float(j) / 9.0 * PI / 2.0       # quart de cercle : cap -n -> cap +u
			path.append(rw(10.0 + R - R * cos(ang), R - R * sin(ang)))
		path.append_array([rw(10.0 + R + 30.0, 0.0), rw(10.0 + R + 55.0, 0.0)])
	else:
		path.append_array(_t2_line(t_push, 2340.0))
		var R2 := 28.0
		path.append(rw(2340.0, 60.0))
		for j in range(0, 10):
			var ang2 := float(j) / 9.0 * PI / 2.0       # cap -n -> cap -u
			path.append(rw(2340.0 - R2 + R2 * cos(ang2), R2 - R2 * sin(ang2)))
		path.append_array([rw(2340.0 - R2 - 30.0, 0.0), rw(2340.0 - R2 - 55.0, 0.0)])
	st["plane"] = null
	st["reserved"] = false
	p.call("set_parked", false)
	mv = {"kind": "depart", "plane": p, "runway": runway, "phase": "repoussage", "t": 0.0, "stand": k,
		"push_from": st["pos"], "push_head0": st["dir"], "push_to": end, "push_head1": head, "path": _clean(path),
		"pos": st["pos"], "head": st["dir"], "speed": 0.0, "h": 0.0, "pitch": 0.0, "n1": 0.0}
	p.set("lights", {"nav": true, "beacon": true, "strobe": false, "landing": false, "taxi": false})
	_spawn_tug(p)


func start_arrival(runway: String) -> void:
	var k := _free_stand()
	if k < 0:
		return
	stands[k]["reserved"] = true
	var p := _new_plane()
	var thr := _a if runway == "06" else _a + _u * RUNWAY_LENGTH
	var d := _u if runway == "06" else -_u
	var aim := thr + d * 400.0
	mv = {"kind": "arrivee", "plane": p, "runway": runway, "phase": "approche", "t": 0.0, "stand": k,
		"aim": aim, "dir": d, "dist": -11000.0, "speed": 75.0, "h": 0.0, "pitch": deg_to_rad(2.5), "vs": 0.0, "n1": 0.45}
	p.set("gear", 1.0)
	p.set("flaps", 0.75)
	p.set("on_ground", false)
	p.set("lights", {"nav": true, "beacon": true, "strobe": true, "landing": true, "taxi": false})


func _t2_line(t0: float, t1: float) -> Array:
	var out: Array = []
	var n := maxi(2, int(absf(t1 - t0) / 40.0) + 1)
	for i in n:
		out.append(rw(lerpf(t0, t1, float(i) / (n - 1)), T2_S))
	return out


func _rw_line(t0: float, t1: float) -> Array:
	var out: Array = []
	var n := maxi(2, int(absf(t1 - t0) / 60.0) + 1)
	for i in n:
		out.append(rw(lerpf(t0, t1, float(i) / (n - 1)), 0.0))
	return out


func _clean(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or (p as Vector2).distance_to(out[out.size() - 1]) > 2.0:
			out.append(p)
	return _smooth(out, 30.0)


func _smooth(path: PackedVector2Array, radius: float) -> PackedVector2Array:
	## Raccords en arc de cercle aux angles (comme les congés des axes de taxiway) : l'avion suit sans couper.
	if path.size() < 3:
		return path
	var out := PackedVector2Array([path[0]])
	for i in range(1, path.size() - 1):
		var a := path[i - 1]
		var b := path[i]
		var c := path[i + 1]
		var d1 := (b - a).normalized()
		var d2 := (c - b).normalized()
		var turn := d1.angle_to(d2)
		if absf(turn) < deg_to_rad(4.0):
			out.append(b)
			continue
		var tan_len := minf(radius * tan(absf(turn) / 2.0), minf(a.distance_to(b), b.distance_to(c)) * 0.5)
		var r := tan_len / tan(absf(turn) / 2.0)
		var p0 := b - d1 * tan_len
		var nrm := Vector2(-d1.y, d1.x) * signf(turn)
		var center := p0 + nrm * r
		var steps := maxi(2, int(absf(turn) / deg_to_rad(8.0)))
		for k in steps + 1:
			var ang := turn * float(k) / steps
			out.append(center + (p0 - center).rotated(ang))
	out.append(path[path.size() - 1])
	return out


func _taxi_in_path(from_t: float, k: int, exit_pts: Array) -> PackedVector2Array:
	var st: Dictionary = stands[k]
	var path: Array = exit_pts.duplicate()
	var dir: Vector2 = st["dir"]
	# virage depuis T2 sur l'axe du poste : coin a l'intersection axe du poste / T2, arrondi par _clean
	var ps := to_rw(st["pos"]).y
	var ds := to_rw(st["pos"] + dir).y - ps
	var x := to_rw(st["pos"] - dir * ((ps - T2_S) / maxf(ds, 0.1)))
	path.append_array(_t2_line(from_t, x.x + (60.0 if from_t > x.x else -60.0)))
	path.append_array([rw(x.x, T2_S), st["pos"] - dir * 15.0, st["pos"]])
	return _clean(path)


# ------------------------------------------------------------------ deroulement
func _step(delta: float) -> void:
	var p: Node3D = mv["plane"]
	if not is_instance_valid(p):
		mv = {}
		return
	mv["t"] += delta
	match mv["kind"]:
		"depart":
			_step_departure(p, delta)
		"arrivee":
			_step_arrival(p, delta)


func _step_departure(p: Node3D, delta: float) -> void:
	match mv["phase"]:
		"repoussage":
			# courbe de Bezier du train principal (on recule : le nez regarde a l'oppose du deplacement)
			var dur := 48.0
			var u: float = clampf(mv["t"] / dur, 0.0, 1.0)
			var k := smoothstep(0.0, 1.0, u)
			var p0: Vector2 = mv["push_from"]
			var p3: Vector2 = mv["push_to"]
			var p1: Vector2 = p0 - (mv["push_head0"] as Vector2) * 30.0
			var p2: Vector2 = p3 + (mv["push_head1"] as Vector2) * 30.0
			var pos := _bezier(p0, p1, p2, p3, k)
			var ahead := _bezier(p0, p1, p2, p3, minf(k + 0.01, 1.0))
			var mvdir := (ahead - pos).normalized() if ahead.distance_to(pos) > 0.001 else -(mv["head"] as Vector2)
			var head := -mvdir if u < 0.99 else (mv["push_head1"] as Vector2)
			mv["head"] = (mv["head"] as Vector2).slerp(head, clampf(delta * 3.0, 0.0, 1.0))
			mv["pos"] = pos
			p.set("speed", -pos.distance_to(mv.get("last", pos)) / maxf(delta, 0.001))
			mv["last"] = pos
			p.set("steer", 0.0)
			_place(p, pos, mv["head"], 0.0, 0.0)
			_move_tug(p)
			# mise en route des reacteurs pendant le repoussage
			mv["n1"] = move_toward(mv["n1"], 0.22, delta * 0.012)
			p.set("n1", mv["n1"])
			if u >= 1.0:
				_release_tug()
				mv["phase"] = "attente_roulage"
				mv["t"] = 0.0
		"attente_roulage":
			mv["n1"] = move_toward(mv["n1"], 0.22, delta * 0.02)
			p.set("n1", mv["n1"])
			p.set("speed", 0.0)
			if mv["t"] > 12.0:
				mv["phase"] = "roulage"
				mv["seg"] = 0
				mv["flaps_set"] = false
				p.set("lights", {"nav": true, "beacon": true, "strobe": false, "landing": false, "taxi": true})
		"roulage":
			p.set("flaps", move_toward(p.get("flaps"), 0.35, delta * 0.08))      # volets de decollage
			var done := _follow(p, delta, 8.5)
			if done:
				mv["phase"] = "alignement"
				mv["t"] = 0.0
		"alignement":
			p.set("lights", {"nav": true, "beacon": true, "strobe": true, "landing": true, "taxi": true})
			mv["speed"] = 0.0
			p.set("speed", 0.0)
			mv["n1"] = move_toward(mv["n1"], 0.4 if mv["t"] > 6.0 else 0.25, delta * 0.08)
			p.set("n1", mv["n1"])
			if mv["t"] > 10.0:
				mv["phase"] = "course"
				mv["t"] = 0.0
		"course", "envol":
			_takeoff(p, delta)


func _takeoff(p: Node3D, delta: float) -> void:
	mv["n1"] = move_toward(mv["n1"], 0.95, delta * 0.15)
	p.set("n1", mv["n1"])
	var v: float = mv["speed"]
	var thrust: float = 2.75 * clampf((mv["n1"] - 0.25) / 0.7, 0.0, 1.0)
	var head: Vector2 = mv["head"]
	if mv["phase"] == "course":
		v += (thrust - 0.00011 * v * v - 0.12) * delta
		if v > 72.0:
			mv["pitch"] = minf(mv["pitch"] + deg_to_rad(2.6) * delta, deg_to_rad(15.0))
		if v > 77.0 and mv["pitch"] > deg_to_rad(8.5):
			mv["phase"] = "envol"
			mv["t"] = 0.0
			mv["vs"] = 0.0
			p.set("on_ground", false)
		# l'avion reste sur l'axe (petite correction de cap)
		var r := to_rw(mv["pos"])
		head = head.rotated(clampf(-r.y * 0.002 * signf(head.dot(_u)), -0.01, 0.01))
	else:
		v = minf(v + (thrust * 0.45) * delta, 92.0)
		mv["pitch"] = move_toward(mv["pitch"], deg_to_rad(15.0), deg_to_rad(2.0) * delta)
		var gamma := clampf((mv["pitch"] - deg_to_rad(5.0)) * 0.95, 0.0, deg_to_rad(9.0))
		mv["vs"] = move_toward(mv["vs"], v * sin(gamma), 2.2 * delta)
		mv["h"] += mv["vs"] * delta
		if mv["t"] > 3.0:
			p.set("gear", move_toward(p.get("gear"), 0.0, delta / 8.0))
		if mv["h"] > 400.0:
			p.set("flaps", move_toward(p.get("flaps"), 0.0, delta / 15.0))
		if mv["h"] > 900.0:
			p.set("lights", {"nav": true, "beacon": true, "strobe": true, "landing": false, "taxi": false})
	mv["speed"] = v
	mv["head"] = head
	mv["pos"] = (mv["pos"] as Vector2) + head * v * delta
	p.set("speed", v)
	p.set("steer", 0.0)
	_place(p, mv["pos"], head, mv["h"], mv["pitch"])
	if mv["h"] > 1600.0 or to_rw(mv["pos"]).x > RUNWAY_LENGTH + 10000.0 or to_rw(mv["pos"]).x < -10000.0:
		_finish(p, true)


func _step_arrival(p: Node3D, delta: float) -> void:
	var d: Vector2 = mv["dir"]
	var aim: Vector2 = mv["aim"]
	match mv["phase"]:
		"approche":
			var dist: float = mv["dist"]            # distance au point vise (negative avant)
			var v: float = mv["speed"]
			v = move_toward(v, 69.0, delta * 0.35)
			if dist > -6000.0:
				p.set("flaps", move_toward(p.get("flaps"), 1.0, delta / 12.0))
			dist += v * delta
			var h := -dist * tan(deg_to_rad(3.0))
			mv["vs"] = -v * sin(deg_to_rad(3.0))
			if h < 9.0:
				mv["phase"] = "arrondi"
				mv["t"] = 0.0
				h = 9.0
			mv["dist"] = dist
			mv["speed"] = v
			mv["h"] = h
			mv["pitch"] = move_toward(mv["pitch"], deg_to_rad(2.8), delta * 0.02)
			mv["n1"] = 0.45
			p.set("n1", 0.45)
			mv["pos"] = aim + d * dist
			p.set("speed", v)
			_place(p, mv["pos"], d, h, mv["pitch"])
		"arrondi":
			var v: float = move_toward(mv["speed"], 64.0, delta * 1.2)
			mv["vs"] = move_toward(mv["vs"], -1.3, delta * 1.3)
			mv["h"] += mv["vs"] * delta
			mv["pitch"] = move_toward(mv["pitch"], deg_to_rad(5.8), deg_to_rad(1.1) * delta)
			mv["n1"] = move_toward(mv["n1"], 0.2, delta * 0.12)
			p.set("n1", mv["n1"])
			mv["dist"] += v * delta
			mv["speed"] = v
			mv["pos"] = aim + d * float(mv["dist"])
			p.set("speed", v)
			if mv["h"] <= 0.0:
				mv["h"] = 0.0
				mv["phase"] = "roulement"
				mv["t"] = 0.0
				mv["head"] = d
				mv["touch"] = mv["pos"]
				p.set("on_ground", true)
				p.touchdown()
			_place(p, mv["pos"], d, mv["h"], mv["pitch"])
		"roulement":
			var t: float = mv["t"]
			var v: float = mv["speed"]
			p.set("spoilers", move_toward(p.get("spoilers"), 1.0, delta * 2.0))
			# nez qui descend en 4 s autour du train principal
			mv["pitch"] = move_toward(mv["pitch"], 0.0, deg_to_rad(1.6) * delta)
			# inverseurs de 2 s a 35 m/s, freins automatiques
			var rev := t > 1.6 and v > 33.0
			p.set("reverse", move_toward(p.get("reverse"), 1.0 if rev else 0.0, delta * 0.8))
			mv["n1"] = move_toward(mv["n1"], 0.72 if rev and p.get("reverse") > 0.8 else 0.2, delta * 0.25)
			p.set("n1", mv["n1"])
			var dec := 1.7 + (1.0 if p.get("reverse") > 0.5 else 0.0) + (0.7 if t > 3.0 else 0.0)
			v = maxf(v - dec * delta, 11.0)
			mv["speed"] = v
			mv["pos"] = (mv["pos"] as Vector2) + d * v * delta
			p.set("speed", v)
			_place(p, mv["pos"], d, 0.0, mv["pitch"])
			var r := to_rw(mv["pos"])
			# bretelle de sortie : 1 600 m (ou 2 340 m si encore trop rapide) en 06, T1 en 24 ; on quitte la piste
			# a vitesse de roulage, l'entree de la trajectoire commence 90 m avant le virage
			var exits: Array = [1510.0, 2250.0] if mv["runway"] == "06" else [760.0]
			for e in exits:
				var reached: bool = (r.x >= e) if mv["runway"] == "06" else (r.x <= e)
				if reached and not mv.get("passed_" + str(e), false):
					mv["passed_" + str(e)] = true
					if v <= 12.5 or e == exits[exits.size() - 1]:
						_begin_taxi_in(p, e)
						break
		"roulage":
			p.set("spoilers", move_toward(p.get("spoilers"), 0.0, delta))
			p.set("reverse", move_toward(p.get("reverse"), 0.0, delta))
			p.set("flaps", move_toward(p.get("flaps"), 0.0, delta / 20.0))
			mv["n1"] = move_toward(mv["n1"], 0.2, delta * 0.1)
			p.set("n1", mv["n1"])
			if _follow(p, delta, 8.5):
				mv["phase"] = "arret"
				mv["t"] = 0.0
				p.set("lights", {"nav": true, "beacon": true, "strobe": false, "landing": false, "taxi": false})
		"arret":
			mv["n1"] = move_toward(mv["n1"], 0.0, delta * 0.01)
			p.set("n1", mv["n1"])
			p.set("speed", 0.0)
			if mv["n1"] <= 0.0:
				p.set("lights", {"nav": true, "beacon": false, "strobe": false, "landing": false, "taxi": false})
				var st: Dictionary = stands[mv["stand"]]
				st["plane"] = p
				st["reserved"] = false
				p.call("set_parked", true)
				_finish(p, false)


func _begin_taxi_in(p: Node3D, at_t: float) -> void:
	var exit_pts: Array
	var from_t: float
	if mv["runway"] == "06":
		# sortie a droite par la bretelle perpendiculaire (1 600 m ou 2 340 m), puis T2 vers le sud-ouest
		var link := 1600.0 if at_t < 2000.0 else 2340.0
		exit_pts = [rw(at_t, 0.0), rw(link, 0.0), rw(link, 60.0), rw(link, T2_S)]
		from_t = link
	else:
		# sortie a gauche par T1, puis T3 (postes au sud-ouest) ou T1 est (postes au nord-est)
		exit_pts = [rw(at_t, 0.0), rw(650.0, 0.0), rw(650.0, 60.0)]
		exit_pts.append_array(_from_t1(stands[mv["stand"]]))
		from_t = to_rw(exit_pts[exit_pts.size() - 1]).x
	mv["phase"] = "roulage"
	mv["path"] = _taxi_in_path(from_t, mv["stand"], exit_pts)
	mv["seg"] = 0
	p.set("lights", {"nav": true, "beacon": true, "strobe": false, "landing": false, "taxi": true})


func _finish(p: Node3D, remove: bool) -> void:
	if remove:
		planes.erase(p)
		p.queue_free()
	mv = {}
	_timer = _next_gap()


# ------------------------------------------------------------------ suivi de trajectoire au sol
func _follow(p: Node3D, delta: float, vmax: float) -> bool:
	## Poursuite pure du train principal sur mv["path"] ; renvoie true a l'arret au bout.
	var path: PackedVector2Array = mv["path"]
	var pos: Vector2 = mv["pos"]
	var head: Vector2 = mv["head"]
	var seg: int = mv.get("seg", 0)
	# avance du segment courant
	while seg < path.size() - 2:
		var a := path[seg]
		var b := path[seg + 1]
		var ab := b - a
		var tt := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if tt >= 0.999 or pos.distance_to(b) < 3.0:
			seg += 1
		else:
			break
	mv["seg"] = seg
	# distance restante et virages a venir
	var proj := Geometry2D.get_closest_point_to_segment(pos, path[seg], path[mini(seg + 1, path.size() - 1)])
	var remain := proj.distance_to(path[mini(seg + 1, path.size() - 1)])
	for i in range(seg + 1, path.size() - 1):
		remain += path[i].distance_to(path[i + 1])
	var turn := 0.0
	var acc_d := proj.distance_to(path[mini(seg + 1, path.size() - 1)])
	for i in range(seg + 1, path.size() - 1):
		if acc_d > 60.0:
			break
		var d1 := (path[i] - path[i - 1]).normalized()
		var d2 := (path[i + 1] - path[i]).normalized()
		turn = maxf(turn, absf(d1.angle_to(d2)) * (1.0 - acc_d / 60.0))
		acc_d += path[i].distance_to(path[i + 1])
	var head_err := absf(head.angle_to((path[mini(seg + 1, path.size() - 1)] - pos).normalized())) if pos.distance_to(path[mini(seg + 1, path.size() - 1)]) > 1.0 else 0.0
	var v_target := minf(vmax, maxf(2.5, vmax * (1.0 - 0.75 * clampf(maxf(turn, head_err) / 1.2, 0.0, 1.0))))
	v_target = minf(v_target, sqrt(maxf(0.0, 2.0 * 0.5 * (remain - 0.5))))
	var v: float = mv["speed"]
	v = move_toward(v, v_target, (0.6 if v_target > v else 2.0) * delta)
	# point vise a l'avance (distance de poursuite)
	var look := 9.0 + v * 0.6
	var target := _point_ahead(path, seg, proj, look)
	var to := target - pos
	var alpha := head.angle_to(to.normalized()) if to.length() > 0.5 else 0.0
	var kappa := clampf(2.0 * sin(alpha) / maxf(to.length(), 1.0), -1.0 / 22.0, 1.0 / 22.0)
	head = head.rotated(kappa * v * delta).normalized()
	pos += head * v * delta
	mv["pos"] = pos
	mv["head"] = head
	mv["speed"] = v
	p.set("speed", v)
	p.set("steer", -atan(kappa * NOSE_GEAR))
	_place(p, pos, head, 0.0, 0.0)
	return remain < 0.8 and v < 0.3


func _point_ahead(path: PackedVector2Array, seg: int, proj: Vector2, dist: float) -> Vector2:
	var p := proj
	var i := seg + 1
	while i < path.size():
		var d := p.distance_to(path[i])
		if d >= dist:
			return p + (path[i] - p).normalized() * dist
		dist -= d
		p = path[i]
		i += 1
	return path[path.size() - 1]


func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t)


# ------------------------------------------------------------------ tracteur de repoussage
func _spawn_tug(p: Node3D) -> void:
	## Tracteur de repoussage : chassis bas jaune, cabine vitree sur le cote, 4 roues, barre de remorquage.
	var tug := Node3D.new()
	tug.name = "Tracteur"
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(0.95, 0.72, 0.1)
	yellow.roughness = 0.55
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.09)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.15, 0.2, 0.25)
	glass.roughness = 0.05
	glass.metallic = 0.3
	var parts := [[Vector3(2.5, 0.9, 5.2), Vector3(0, 0.75, 0), yellow], [Vector3(0.9, 0.95, 1.3), Vector3(-0.75, 1.65, 0.6), glass],
		[Vector3(0.98, 0.08, 1.38), Vector3(-0.75, 2.16, 0.6), yellow], [Vector3(2.55, 0.25, 0.3), Vector3(0, 0.55, -2.65), dark],
		[Vector3(0.12, 0.12, 2.6), Vector3(0, 0.6, -3.9), dark]]
	for pt in parts:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = pt[0]
		b.material = pt[2]
		mi.mesh = b
		mi.position = pt[1]
		tug.add_child(mi)
	for wx: float in [-1.1, 1.1]:
		for wz: float in [-1.6, 1.6]:
			var w := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.42
			c.bottom_radius = 0.42
			c.height = 0.35
			c.material = dark
			w.mesh = c
			w.position = Vector3(wx, 0.42, wz)
			w.rotation = Vector3(0, 0, PI / 2.0)
			tug.add_child(w)
	add_child(tug)
	mv_tug = tug


var mv_tug: Node3D


func _move_tug(p: Node3D) -> void:
	if mv_tug == null:
		return
	# barre accrochee a la roue avant, le tracteur face a l'avion
	var xf: Transform3D = p.global_transform
	var flat := Transform3D(Basis(Vector3.UP, xf.basis.get_euler().y), xf.origin)
	mv_tug.global_transform = flat * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.0, -(NOSE_GEAR + 6.6)))


func _release_tug() -> void:
	if mv_tug == null:
		return
	var tug := mv_tug
	mv_tug = null
	var tw := create_tween()
	var away := tug.global_transform.translated_local(Vector3(0, 0, -40.0))
	tw.tween_property(tug, "global_transform", away, 9.0)
	tw.tween_callback(tug.queue_free)


func _next_gap() -> float:
	## Attente avant le prochain mouvement, d'apres la frequence reelle a l'heure de jeu courante
	## (loi exponentielle : les vols n'arrivent pas a intervalles reguliers).
	var hour: float = _day.get("hour") if _day else 12.0
	var game_hour_s: float = (_day.get("minutes_per_game_day") if _day else 48.0) * 60.0 / 24.0
	var rate: float = movements_per_hour[int(hour) % 24]
	if rate <= 0.01:
		return game_hour_s * 0.5          # nuit sans vol : on revient voir plus tard
	return maxf(min_gap, -log(maxf(_rng.randf(), 0.05)) * game_hour_s / rate)
