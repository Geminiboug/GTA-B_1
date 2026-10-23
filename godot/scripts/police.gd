extends Node3D
## Police fictive ("Police de Gbê Town") et consequences (phase 8) :
## - delits (groupe "police", crime()) : vol de vehicule, agression, pieton renverse, choc contre une patrouille ;
##   chacun monte le niveau de recherche (Partie.recherche, 0 a 5 etoiles) ;
## - appel : un delit sans policier temoin est signale par telephone ; les patrouilles partent du commissariat apres
##   delai_appel s (au Benin la police n'arrive jamais aussitot ; decision d'Olympe : 1 min) et roulent jusqu'au
##   joueur, visibles sur la mini-carte et la carte (scripts/hud_carte.gd). Un policier temoin reagit tout de suite ;
## - patrouilles : berlines blanches a gyrophare (voiture.gd en pilote automatique) qui suivent les rues (itineraire
##   de scripts/carte.gd) jusqu'au joueur, une par niveau (4 au plus) ; a l'arret pres de lui, un agent descend et
##   court l'arreter ;
## - arrestation : agent a moins de 1,4 m pendant 1,5 s (joueur a pied ou vehicule arrete) : amende
##   (Partie.amende_par_niveau x niveau), sortie du commissariat ;
## - semer la police : hors de vue de tout agent pendant perte_vue s, le niveau retombe a zero ;
## - exces de vitesse sous les yeux d'une patrouille (sans etre recherche) : contravention ;
## - malaise (sante a zero) : reveil a la maison, frais de soins.
## - niveaux (phase 14) : 1 agent a pied ; 2 agent + patrouille ; 3 deux patrouilles + barrage (deux voitures en
##   travers de la rue devant le joueur, agents a cote) ; 4 unite speciale (4x4 bleu nuit, plus rapides) ; 5 motos de
##   police (zem en pilote automatique) qui passent partout.

@export var player_path: NodePath = ^"../Player"
@export var perte_vue := 14.0            # s hors de vue pour semer la police (+ 4 s par niveau)
@export var vue_distance := 70.0         # m
@export var apparition := Vector2(140.0, 260.0)   # m du joueur
@export var vitesse_poursuite := 15.0    # m/s vises en ville (54 km/h), + 2 m/s par niveau
@export var limite_vitesse := 19.5       # m/s (70 km/h) : au-dela, contravention si une patrouille voit
@export var contravention := 2000        # FCFA
@export var agent_vitesse := 5.2         # m/s a la course
@export var delai_appel := 60.0          # s entre l'appel et le depart des patrouilles (sans policier temoin)
@export var hopital := Vector3(140, 0, -60)        # Centre de sante Gbekpo (fictif) : reveil apres un malaise
@export var commissariat := Vector3(330, 0, -250)   # d'ou partent les patrouilles (et ou l'on sort apres arrestation)
@export var rattrapage := false          # patrouille avancee hors champ quand elle traine (desactive : on la voit venir)

const DELITS := {"vol": 1, "agression": 1, "renverse": 1, "choc_police": 1, "evasion": 1, "arme_blanche": 2, "tir": 2,
	"tir_police": 3, "braquage": 3}
const COMPOSITION := [[], ["pied"], ["pied", "berline"], ["berline", "berline"], ["berline", "special", "special"],
	["special", "special", "moto", "moto"]]
const ZEM_SCENE := preload("res://scenes/zem.tscn")
@export var barrage_distance := 150.0    # m devant le joueur

var units: Array = []                     # {car, route, route_t, officer, state}
var _player: Node3D
var _carte: Carte
var _rng := RandomNumberGenerator.new()
var _hors_vue := 0.0
var _arrest_t := 0.0
var _route_t := 0.0
var _ticket_cd := 0.0
var _busy := false                        # fondu en cours (arrestation, malaise)
var _fade: ColorRect
var _patrol: Dictionary = {}              # patrouille de routine (recherche 0)
var appel_t := 0.0                        # s avant le depart des patrouilles (> 0 : appel en cours)
var _arrivee := false                     # une patrouille est arrivee pres du joueur (on peut alors la semer)
var _spawn_cd := 0.0
@export var arrestation := true   # faux : jamais d arrestation (tests)
@export var patrouilles_sans_recherche := false   # vrai : patrouilles stationnees et contraventions sans recherche


func _ready() -> void:
	add_to_group("police")
	add_to_group("circulation")       # chocs entre vehicules (voiture.gd : on_vehicle_hit)
	_rng.randomize()
	_player = get_node_or_null(player_path)
	_carte = Carte.zone()
	Partie.recherche_change.connect(_on_level)
	Partie.evanoui.connect(_malaise)
	Partie.chantier_differe(_batir_hopital)   # etape de la mise en place etalee pendant le chargement


func crime(kind: String, _where: Vector3) -> void:
	if _busy:
		return
	var add: int = DELITS.get(kind, 1)
	var avant := Partie.recherche
	var temoin := _witness()
	Partie.journal.delit(kind, temoin)
	# deja recherche : un nouveau delit fait monter le niveau
	Partie.set_recherche(maxi(Partie.recherche, 0) + add)
	_hors_vue = 0.0
	if temoin:
		appel_t = 0.0
	elif avant == 0:
		appel_t = delai_appel
		_arrivee = false
		Partie.notifier("Quelqu'un a appelé la police. Elle arrive dans environ %d min." % maxi(1, roundi(delai_appel / 60.0)))


func _witness() -> bool:
	## Un policier (patrouille, agent a pied, patrouille de routine) voit le joueur.
	if _player == null:
		return false
	var pv: Node3D = _player.get("vehicle")
	var ppos: Vector3 = pv.global_position if pv else _player.global_position
	for u in units:
		if is_instance_valid(u["car"]) and _sees(u, ppos):
			return true
		var o: Node3D = u.get("officer")
		if o and is_instance_valid(o) and o.global_position.distance_to(ppos) < vue_distance * 0.6:
			return true
	if not _patrol.is_empty() and is_instance_valid(_patrol.get("car")):
		return _sees({"car": _patrol["car"]}, ppos)
	return false


func on_vehicle_hit(collider: Object, impact: float) -> void:
	## Le vehicule du joueur emboutit une patrouille.
	var pv: Node3D = _player.get("vehicle") if _player else null
	if pv and impact > 4.0 and collider is Node and (collider as Node).is_in_group("police_car") \
			and pv.global_position.distance_to((collider as Node3D).global_position) < 7.0:
		crime("choc_police", pv.global_position)


func _on_level(n: int) -> void:
	if n == 0:
		appel_t = 0.0
		for u in units:
			_release(u)
		units.clear()
		Partie.police_voit = false
	elif n >= 3 and not units.any(func(u: Dictionary) -> bool: return u.get("kind") == "barrage"):
		_barrage.call_deferred()


func _barrage() -> void:
	## Deux voitures en travers de la rue, a barrage_distance m devant le joueur, et deux agents qui attendent.
	if _player == null or Partie.recherche < 3:
		return
	var pv: Node3D = _player.get("vehicle")
	var ppos: Vector3 = pv.global_position if pv else _player.global_position
	var yaw := float(pv.get("_yaw")) if pv else float(_player.get("_facing"))
	var pp := Vector2(ppos.x, ppos.z)
	var near := _carte.nearest_on_network(pp + Vector2(-sin(yaw), -cos(yaw)) * barrage_distance)
	if near.is_empty() or near.get("edge", -1) < 0:
		return
	var q: Vector2 = near["point"]
	var path := _carte.route(pp, q, false)
	var road := (path[-1] - path[-2]).normalized() if path.size() >= 2 else Vector2(-sin(yaw), -cos(yaw))
	var side := Vector2(-road.y, road.x)
	for k in [-1.0, 1.0]:
		var at: Vector2 = q + side * 2.4 * k
		var car := _make_car(Vector3(at.x, 0.0, at.y), atan2(-side.x, -side.y) + (0.25 * k))
		car.set("ai_input", Vector3(0, 1, 0))
		var o := _make_officer(Vector3(at.x, 0.0, at.y) + Vector3(road.x, 0, road.y) * -3.0)
		units.append({"car": car, "kind": "barrage", "route": PackedVector2Array(), "officer": o, "state": "barrage", "stuck": 0.0})


# ------------------------------------------------------------------ boucle
func _physics_process(delta: float) -> void:
	if _player == null or _busy:
		return
	var pv: Node3D = _player.get("vehicle")
	var ppos: Vector3 = pv.global_position if pv else _player.global_position
	_ticket_cd = maxf(0.0, _ticket_cd - delta)
	if Partie.recherche == 0:
		_routine(delta, pv, ppos)
		return
	# appel en cours : les patrouilles ne sont pas encore parties
	if appel_t > 0.0:
		appel_t -= delta
		Partie.police_voit = false
		return
	# unites selon le niveau (COMPOSITION, une toutes les 4 s) : agent a pied, patrouilles, unite speciale, motos
	_spawn_cd = maxf(0.0, _spawn_cd - delta)
	if _spawn_cd <= 0.0:
		var want: Array = COMPOSITION[clampi(Partie.recherche, 0, COMPOSITION.size() - 1)].duplicate()
		for u in units:
			want.erase(u.get("kind", "berline"))
		if not want.is_empty():
			_spawn_cd = 4.0
			_spawn_unit(ppos, want[0])
	_route_t -= delta
	var seen := false
	for u in units.duplicate():
		var kind: String = u.get("kind", "berline")
		if kind == "pied":
			if not (u.get("officer") and is_instance_valid(u["officer"])):
				units.erase(u)
				continue
		elif not is_instance_valid(u["car"]):
			units.erase(u)
			continue
		elif kind == "barrage":
			_lights(u["car"])
			seen = seen or _sees(u, ppos)
		elif _drive(u, ppos, pv, delta):
			seen = seen or _sees(u, ppos)
		if u.get("officer") and is_instance_valid(u["officer"]):
			_run_officer(u, ppos, pv, delta)
			seen = seen or (u["officer"] as Node3D).global_position.distance_to(ppos) < vue_distance * 0.6
	if _route_t <= 0.0:
		_route_t = 1.5
	Partie.police_voit = seen
	for u in units:
		if is_instance_valid(u["car"]) and (u["car"] as Node3D).global_position.distance_to(ppos) < vue_distance:
			_arrivee = true
	if seen or not _arrivee:
		_hors_vue = 0.0          # tant qu'aucune patrouille n'est arrivee, on ne peut pas la semer
	else:
		# cache au marche (au milieu des etals et des maquis) : la police perd la trace trois fois plus vite
		_hors_vue += delta * (3.0 if pv == null and _au_marche(ppos) else 1.0)
		if _hors_vue > perte_vue + 4.0 * Partie.recherche:
			Partie.journal.compter("police_semee", 1, {"niveau": Partie.recherche})
			Partie.set_recherche(0)
			Partie.notifier("Tu as semé la police")
	# arrestation
	var close := false
	for u in units:
		var o: Node3D = u.get("officer")
		if o and is_instance_valid(o) and o.global_position.distance_to(ppos) < 1.4 + (1.2 if pv else 0.0):
			close = true
	var stopped := pv == null or absf(float(pv.get("speed"))) < 1.0
	_arrest_t = _arrest_t + delta if close and stopped else maxf(0.0, _arrest_t - delta)
	if _arrest_t > 1.5:
		_arrest()


func _sees(u: Dictionary, ppos: Vector3) -> bool:
	var car: Node3D = u["car"]
	var d := car.global_position.distance_to(ppos)
	if d > vue_distance:
		return false
	var q := PhysicsRayQueryParameters3D.create(car.global_position + Vector3.UP * 1.4, ppos + Vector3.UP * 1.2, 1)
	q.exclude = [car.get_rid(), _player.get_rid()]
	var pv: Node3D = _player.get("vehicle")
	if pv and pv is CollisionObject3D:
		q.exclude.append((pv as CollisionObject3D).get_rid())
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ patrouilles
func _make_car(at: Vector3, yaw: float, kind := "berline") -> Node3D:
	if kind == "moto":
		return _make_moto(at, yaw)
	var car := Vehicules.create("veh_4x4" if kind == "special" else "veh_berline",
		Color(0.08, 0.1, 0.2) if kind == "special" else Color(0.93, 0.94, 0.95))
	car.name = "Police"
	add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, yaw), at + Vector3.UP * 0.3)
	car.set("_yaw", yaw)
	car.set("ai", true)
	car.add_to_group("police_car")
	# gyrophare (rouge / bleu qui alternent) et inscription sur les portieres
	var bar := Node3D.new()
	bar.name = "Gyrophare"
	car.add_child(bar)
	bar.position = Vector3(0, 1.52, 0.1)
	for i in 2:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.32, 0.09, 0.18)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.05, 0.05) if i == 0 else Color(0.05, 0.2, 1.0)
		m.emission_enabled = true
		m.emission = m.albedo_color
		mi.material_override = m
		mi.position = Vector3(-0.18 + 0.36 * i, 0, 0)
		bar.add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = m.albedo_color
		l.omni_range = 9.0
		l.light_energy = 0.0
		l.position = mi.position + Vector3.UP * 0.1
		bar.add_child(l)
	for s in [-1.0, 1.0]:
		var lab := Label3D.new()
		lab.text = "POLICE"
		lab.font_size = 64
		lab.pixel_size = 0.004
		lab.modulate = Color(0.9, 0.9, 0.95) if kind == "special" else Color(0.05, 0.15, 0.6)
		lab.outline_size = 0
		lab.position = Vector3((1.0 if kind == "special" else 0.93) * s, 1.1 if kind == "special" else 0.85, 0.0)
		lab.rotation = Vector3(0, PI / 2.0 * s, 0)
		car.add_child(lab)
	if kind == "special":
		bar.position = Vector3(0, 1.95, 0.3)
	return car


func _make_moto(at: Vector3, yaw: float) -> Node3D:
	## Moto de police : zem bleu nuit en pilote automatique, agent en selle, gyrophare sur le porte-bagages.
	var z := ZEM_SCENE.instantiate() as Node3D
	z.name = "PoliceMoto"
	add_child(z)
	z.global_transform = Transform3D(Basis(Vector3.UP, yaw), at + Vector3.UP * 0.3)
	z.set("_yaw", yaw)
	z.set("ai", true)
	z.set("max_speed", 25.0)
	z.add_to_group("police_car")
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.08, 0.12, 0.3)
	paint.roughness = 0.35
	for mi in z.find_children("*", "MeshInstance3D", true, false):
		for si in (mi as MeshInstance3D).mesh.get_surface_count():
			var m: Material = (mi as MeshInstance3D).mesh.surface_get_material(si)
			if m and m.resource_name == "veh_peinture_rouge":
				(mi as MeshInstance3D).set_surface_override_material(si, paint)
	var visual := z.get_node("Visual") as Node3D
	var rider := PnjUtil.make("homme", false)   # sur la moto
	rider.name = "Agent"
	visual.add_child(rider)
	PnjUtil.apply(rider, PnjUtil.uniform_look("police", "homme", _rng))
	PnjUtil.pose_seated(rider)
	rider.position = Vector3(0, -0.05, 0.12)
	var bar := Node3D.new()
	bar.name = "Gyrophare"
	visual.add_child(bar)
	bar.position = Vector3(0, 1.0, 0.85)
	for i in 2:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.1, 0.06, 0.06)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.05, 0.05) if i == 0 else Color(0.05, 0.2, 1.0)
		m.emission_enabled = true
		m.emission = m.albedo_color
		mi.material_override = m
		mi.position = Vector3(-0.06 + 0.12 * i, 0, 0)
		bar.add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = m.albedo_color
		l.omni_range = 6.0
		l.light_energy = 0.0
		bar.add_child(l)
	return z


func _spawn_unit(ppos: Vector3, kind := "berline") -> void:
	## Depart du commissariat (sur la rue la plus proche), tournee vers le joueur ; si le joueur est tout pres du
	## commissariat, a 140-260 m le long d'une rue reliee au joueur.
	var pp := Vector2(ppos.x, ppos.z)
	var cs := Vector2(commissariat.x, commissariat.z)
	if kind == "pied":
		# agent en patrouille a pied, a 60-90 m sur une rue reliee au joueur : il arrive en courant
		var q: Vector2 = pp + Vector2(70, 0)
		for essai in 8:
			var a := _rng.randf() * TAU
			var near := _carte.nearest_on_network(pp + Vector2(cos(a), sin(a)) * _rng.randf_range(60.0, 90.0))
			q = near.get("point", pp + Vector2(cos(a), sin(a)) * 70.0)
			if q.distance_to(pp) >= 60.0:       # la rue la plus proche du point tire peut etre bien plus pres du joueur
				break
		units.append({"car": null, "kind": "pied", "route": PackedVector2Array(), "state": "chase", "stuck": 0.0,
			"officer": _make_officer(Vector3(q.x, 0.0, q.y))})
		return
	if pp.distance_to(cs) > apparition.x:
		var near := _carte.nearest_on_network(cs)
		var path := _carte.route(pp, near.get("point", cs), false)
		if path.size() >= 2:
			var q: Vector2 = path[-1]
			var back := (path[-2] - path[-1]).normalized()
			var car0 := _make_car(Vector3(q.x, 0.0, q.y), atan2(-back.x, -back.y), kind)
			units.append({"car": car0, "kind": kind, "route": PackedVector2Array(), "officer": null, "state": "chase", "stuck": 0.0})
			return
	for attempt in 8:
		var a := _rng.randf() * TAU
		var far := pp + Vector2(cos(a), sin(a)) * apparition.y * 1.5
		if not _carte.in_bounds(far):
			continue
		var path := _carte.route(pp, far, false)
		if path.size() < 2:
			continue
		var want := _rng.randf_range(apparition.x, apparition.y)
		var acc := 0.0
		for i in path.size() - 1:
			var seg := path[i].distance_to(path[i + 1])
			if acc + seg >= want:
				var q := path[i].lerp(path[i + 1], (want - acc) / seg)
				var back := (path[i] - path[i + 1]).normalized()
				var car := _make_car(Vector3(q.x, 0.0, q.y), atan2(-back.x, -back.y), kind)
				units.append({"car": car, "kind": kind, "route": PackedVector2Array(), "officer": null, "state": "chase", "stuck": 0.0})
				return
			acc += seg


func _drive(u: Dictionary, ppos: Vector3, pv: Node3D, delta: float) -> bool:
	## Vrai si la patrouille roule encore (le joueur ne l'a pas prise).
	var car: Node3D = u["car"]
	if car.get("has_rider"):
		car.set("ai", false)
		units.erase(u)
		crime("evasion", car.global_position)
		return false
	_lights(car)
	var cp := Vector2(car.global_position.x, car.global_position.z)
	var target := Vector2(ppos.x, ppos.z)
	var d := cp.distance_to(target)
	if _route_t <= 0.0 or (u["route"] as PackedVector2Array).is_empty():
		# itineraire calcule depuis le joueur puis retourne (le depart cote patrouille donnait des detours)
		var r := _carte.route(target, cp, false) if d > 35.0 else PackedVector2Array([target])
		r.reverse()
		if r.size() > 0 and d > 35.0:
			r.append(target)
		u["route"] = r
	var route: PackedVector2Array = u["route"]
	while route.size() > 1 and cp.distance_to(route[0]) < 7.0:
		route.remove_at(0)
	# rattrapage (comme dans GTA) : loin et hors du champ de la camera depuis 6 s, la patrouille est avancee sur son
	# itineraire jusqu'a ~60 m du joueur
	u["far_t"] = float(u.get("far_t", 0.0)) + delta if rattrapage and d > 75.0 and not _on_screen(car.global_position) else 0.0
	if float(u["far_t"]) > 6.0 and route.size() > 1:
		u["far_t"] = 0.0
		var acc := 0.0
		var prev := target
		for i in range(route.size() - 1, -1, -1):
			acc += prev.distance_to(route[i])
			prev = route[i]
			if acc > 60.0:
				var nxt := route[mini(i + 1, route.size() - 1)]
				var dv := (nxt - route[i]).normalized() if nxt.distance_to(route[i]) > 0.5 else (target - route[i]).normalized()
				var ny := atan2(-dv.x, -dv.y)
				car.global_transform = Transform3D(Basis(Vector3.UP, ny), Vector3(route[i].x, car.global_position.y + 0.2, route[i].y))
				car.set("_yaw", ny)
				car.set("_vel", Vector2.ZERO)
				route = route.slice(i + 1)
				u["route"] = route
				cp = Vector2(car.global_position.x, car.global_position.z)
				break
	var aim := route[0] if route.size() > 0 else target
	var yaw: float = float(car.get("_yaw"))
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var to := (aim - cp).normalized()
	var ang := atan2(fwd.cross(to), fwd.dot(to))       # + : a gauche
	var speed: float = float(car.get("speed"))
	var goal := vitesse_poursuite + 2.0 * Partie.recherche + (5.0 if u.get("kind") == "special" else 0.0)
	if d < 18.0:
		goal = 3.0 if pv == null else maxf(absf(float(pv.get("speed"))) + 2.0, 6.0)
	# virage : on ralentit selon l'angle a prendre (5 m/s pour un angle droit)
	goal = minf(goal, lerpf(goal, 5.0, clampf(absf(ang) / 1.4, 0.0, 1.0)))
	# carrefour en vue : on freine avant le virage selon l'angle du segment suivant
	if route.size() >= 2 and cp.distance_to(route[0]) < maxf(speed, 4.0) * 2.2:
		var a1 := (route[0] - cp).normalized()
		var a2 := (route[1] - route[0]).normalized()
		var turn := absf(a1.angle_to(a2))
		goal = minf(goal, lerpf(goal, 5.5, clampf(turn / 1.4, 0.0, 1.0)))
	var stop := d < 9.0 and (pv == null or absf(float(pv.get("speed"))) < 2.0)
	car.set("ai_input", Vector3(0.0 if stop or speed > goal else clampf((goal - speed) / 4.0, 0.2, 1.0),
		1.0 if stop or speed > goal + 3.0 else 0.0, clampf(-ang * 2.0, -1.0, 1.0)))   # direction : + = a gauche
	# coince contre un mur : on recule un instant
	u["stuck"] = float(u["stuck"]) + delta if absf(speed) < 0.8 and not stop else maxf(0.0, float(u["stuck"]) - delta)
	u["stuck_total"] = float(u.get("stuck_total", 0.0)) + (delta if float(u["stuck"]) > 1.0 else 0.0)
	if float(u["stuck"]) > 1.5 and route.size() > 0 and not _on_screen(car.global_position):
		# coincee hors du champ de la camera : replacee sur la rue, au point suivant de son itineraire
		var nxt: Vector2 = route[0]
		var dirv := (nxt - cp).normalized() if nxt.distance_to(cp) > 1.0 else fwd
		var ny := atan2(-dirv.x, -dirv.y)
		car.global_transform = Transform3D(Basis(Vector3.UP, ny), Vector3(nxt.x, car.global_position.y + 0.2, nxt.y))
		car.set("_yaw", ny)
		car.set("_vel", Vector2.ZERO)
		u["stuck"] = 0.0
		route.remove_at(0)
	elif float(u["stuck"]) > 1.5:
		# recule en contre-braquant, puis repart
		car.set("ai_input", Vector3(0, 1.0, clampf(ang * 3.0, -1.0, 1.0)))
		if float(u["stuck"]) > 3.2:
			u["stuck"] = 0.0
	# trop longtemps coincee loin du joueur : retiree (une autre sera envoyee)
	if float(u["stuck_total"]) > 10.0 and d > 80.0:
		_release(u)
		units.erase(u)
		return false
	# a l'arret pres du joueur (ou coincee a moins de 80 m) : un agent descend et finit a pied
	if (stop or (d < 80.0 and float(u["stuck_total"]) > 2.0)) and (u.get("officer") == null or not is_instance_valid(u["officer"])):
		u["officer"] = _make_officer(car.global_position - car.global_transform.basis.x * 1.2)
		var rider := car.find_child("Agent", true, false) as Node3D
		if rider:
			rider.visible = false            # l'agent de la moto descend
	elif u.get("officer") == null or not is_instance_valid(u["officer"]):
		var rider := car.find_child("Agent", true, false) as Node3D
		if rider:
			rider.visible = true
	return true


func _on_screen(p: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_to(p) < 90.0 and cam.is_position_in_frustum(p)


func _lights(car: Node3D) -> void:
	var bar := car.find_child("Gyrophare", true, false)
	if bar == null:
		return
	var on := int(Time.get_ticks_msec() / 260) % 2
	var k := 0
	for c in bar.get_children():
		if c is OmniLight3D:
			(c as OmniLight3D).light_energy = 2.5 if k == on else 0.0
			k += 1


func _make_officer(at: Vector3) -> Node3D:
	var genre := "femme" if _rng.randf() < 0.3 else "homme"
	var ch := PnjUtil.make(genre)
	ch.set_script(load("res://scripts/anim_ctrl.gd"))
	add_child(ch)
	PnjUtil.apply(ch, PnjUtil.uniform_look("police", genre, _rng))
	ch.global_position = at
	ch.add_to_group("police_agent")      # point clignotant sur la mini-carte (hud_carte.gd), comme les patrouilles
	Bulle.say(ch, ["Halte ! Police !", "Arrêtez-vous !", "Ne bougez plus !"][_rng.randi() % 3], 2.5)
	return ch


func _run_officer(u: Dictionary, ppos: Vector3, _pv: Node3D, delta: float) -> void:
	var o: Node3D = u["officer"]
	var to := ppos - o.global_position
	to.y = 0.0
	var d := to.length()
	var sp := 0.0 if d < 1.1 else agent_vitesse
	if u.get("kind") == "barrage" and d > 35.0:
		sp = 0.0                              # les agents du barrage attendent pres des voitures
	if d > 0.01:
		o.global_position += to / d * minf(sp * delta, maxf(d - 1.0, 0.0))
		o.rotation.y = atan2(-to.x, -to.z)          # le modele regarde -Z (comme les pietons)
	o.set("speed", sp)
	# trop loin (le joueur a file) : il remonte en voiture (l'agent a pied et ceux du barrage restent)
	if d > 45.0 and not u.get("kind") in ["pied", "barrage"]:
		o.queue_free()
		u["officer"] = null


func _release(u: Dictionary) -> void:
	if u.get("officer") and is_instance_valid(u["officer"]):
		(u["officer"] as Node).queue_free()
	var car = u["car"]
	if is_instance_valid(car) and not car.get("has_rider"):
		car.queue_free()


# ------------------------------------------------------------------ patrouille de routine, contraventions
func _routine(delta: float, pv: Node3D, ppos: Vector3) -> void:
	## Sans recherche : une patrouille stationne parfois au bord de la route ; un exces de vitesse devant elle
	## coute une contravention.
	if not patrouilles_sans_recherche:
		# decision d Olympe (17/10/2026) : aucun policier a l ecran tant que personne n a appele la police
		if not _patrol.is_empty() and is_instance_valid(_patrol.get("car")) and not _patrol["car"].get("has_rider"):
			_patrol["car"].queue_free()
		_patrol = {}
		return
	if _patrol.is_empty() or not is_instance_valid(_patrol.get("car")):
		_patrol = {}
		if _rng.randf() < delta / 30.0:
			var near := _carte.nearest_on_network(Vector2(ppos.x, ppos.z) + Vector2(_rng.randf_range(-120, 120), _rng.randf_range(-120, 120)))
			if not near.is_empty():
				var q: Vector2 = near.get("point", Vector2.ZERO)
				var car := _make_car(Vector3(q.x, 0, q.y), _rng.randf() * TAU)
				car.set("ai_input", Vector3(0, 1, 0))
				_patrol = {"car": car, "t": 90.0}
		return
	var car: Node3D = _patrol["car"]
	_patrol["t"] = float(_patrol["t"]) - delta
	if car.get("has_rider"):
		car.set("ai", false)
		_patrol = {}
		crime("vol", ppos)
		return
	if float(_patrol["t"]) <= 0.0 and car.global_position.distance_to(ppos) > 120.0:
		car.queue_free()
		_patrol = {}
		return
	if pv and _ticket_cd <= 0.0 and absf(float(pv.get("speed"))) > limite_vitesse and car.global_position.distance_to(ppos) < 30.0:
		_ticket_cd = 60.0
		Partie.journal.compter("contraventions", 1, {"kmh": roundi(absf(float(pv.get("speed"))) * 3.6)})
		Partie.journal.amende(mini(contravention, Partie.argent))
		Partie.prelever(contravention, "Contravention : excès de vitesse")
		Partie.stats["amendes"] = int(Partie.stats.get("amendes", 0)) + 1
		Bulle.say(car, "Excès de vitesse !", 2.5, 2.2)


# ------------------------------------------------------------------ arrestation, malaise
func _arrest() -> void:
	if not arrestation:
		return
	var lvl := Partie.recherche
	_busy = true
	_arrest_t = 0.0
	Partie.journal.compter("arrestations", 1, {"niveau": lvl, "amende": Partie.amende_par_niveau * lvl})
	Partie.journal.amende(mini(Partie.amende_par_niveau * lvl, Partie.argent))
	var hj := get_tree().get_first_node_in_group("hud_jeu")
	if hj:
		hj.annonce("ARRÊTÉ", "Amende : %s" % Partie.fcfa(Partie.amende_par_niveau * lvl), 3.5)
	_fade_then(func() -> void:
		if _player.get("vehicle"):
			_player.exit_vehicle(true)
		Partie.prelever(Partie.amende_par_niveau * lvl, "Amende")
		Partie.stats["amendes"] = int(Partie.stats.get("amendes", 0)) + 1
		Partie.set_recherche(0)
		_teleport(commissariat, "Commissariat de Gbê Town"))


func _malaise() -> void:
	if _busy:
		return
	_busy = true
	Partie.journal.compter("morts", 1, {"recherche": Partie.recherche})
	var hj := get_tree().get_first_node_in_group("hud_jeu")
	if hj:
		hj.annonce("ÉVANOUI", "Centre de santé Gbêkpo : %s de soins" % Partie.fcfa(Partie.frais_hopital), 3.5)
	_fade_then(func() -> void:
		if _player.get("vehicle"):
			_player.exit_vehicle(true)
		Partie.prelever(Partie.frais_hopital, "Soins")
		Partie.set_recherche(0)
		Partie.soigner(100.0)
		_teleport(_hopital_rue(), "Centre de santé Gbêkpo"))


func _au_marche(p: Vector3) -> bool:
	var com := get_node_or_null("../Commerce")
	if com == null:
		return false
	var n := 0
	for s in com.spots:
		if (String(s["kind"]).begins_with("etal") or s["kind"] in ["maquis", "kpayo"]) and Vector2(p.x - s["pos"].x, p.z - s["pos"].z).length() < 14.0:
			n += 1
	return n >= 3


func _hopital_rue() -> Vector3:
	## Point de rue le plus proche du centre de sante (on se reveille devant, sur le trottoir).
	var near := _carte.nearest_on_network(Vector2(hopital.x, hopital.z)) if _carte else {}
	if near.is_empty():
		return hopital
	var q: Vector2 = near["point"]
	return Vector3(q.x, 0.0, q.y)


func _batir_hopital() -> void:
	## Repere visible du centre de sante : poteau, croix verte lumineuse et enseigne, au bord de la rue.
	var p := _hopital_rue()
	var root := Node3D.new()
	root.name = "CentreSante"
	add_child(root)
	root.global_position = p + Vector3(3.0, 0, 0)
	var poteau := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = 3.9      # monte jusqu'a la croix (avant : 3,2 m, la croix flottait au-dessus du poteau)
	poteau.mesh = cyl
	poteau.position.y = 1.95
	root.add_child(poteau)
	var croix_mat := StandardMaterial3D.new()
	croix_mat.albedo_color = Color(0.1, 0.7, 0.3)
	croix_mat.emission_enabled = true
	croix_mat.emission = Color(0.1, 0.9, 0.35)
	croix_mat.emission_energy_multiplier = 1.5
	for sz in [Vector3(0.9, 0.3, 0.12), Vector3(0.3, 0.9, 0.12)]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		bm.material = croix_mat
		b.mesh = bm
		b.position.y = 3.5
		root.add_child(b)
	# enseigne : planche fixee au poteau, texte colle sur ses deux faces (avant : un texte flottant sans support)
	var planche := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(3.2, 0.5, 0.08)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.08, 0.5, 0.25)
	pm.material = pmat
	planche.mesh = pm
	planche.position.y = 2.75
	root.add_child(planche)
	for sens in [1.0, -1.0]:
		var enseigne := Label3D.new()
		enseigne.text = "CENTRE DE SANTÉ GBÊKPO"
		enseigne.font_size = 64
		enseigne.pixel_size = 0.0034
		enseigne.shaded = false
		enseigne.modulate = Color(1, 1, 1)
		enseigne.outline_size = 0
		enseigne.position = Vector3(0, 2.75, 0.045 * sens)
		enseigne.rotation.y = 0.0 if sens > 0.0 else PI
		root.add_child(enseigne)


func _teleport(p: Vector3, place: String) -> void:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 80, p.z), Vector3(p.x, -10, p.z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_player.global_position = (hit["position"] if not hit.is_empty() else p) + Vector3.UP * 0.2
	_player.set("velocity", Vector3.ZERO)
	_player.reset_physics_interpolation()
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("show_place"):
		hud.show_place(place)


func _fade_then(cb: Callable) -> void:
	if _fade == null:
		var layer := CanvasLayer.new()
		layer.layer = 20
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(_fade, "color:a", 1.0, 1.0)
	tw.tween_callback(cb)
	tw.tween_interval(1.0)
	tw.tween_property(_fade, "color:a", 0.0, 1.0)
	tw.tween_callback(func() -> void: _busy = false)
