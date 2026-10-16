extends Node3D
## Police fictive ("Police de Gbê Town") et consequences (phase 8) :
## - delits (groupe "police", crime()) : vol de vehicule, agression, pieton renverse, choc contre une patrouille ;
##   chacun monte le niveau de recherche (Partie.recherche, 0 a 5 etoiles) ;
## - patrouilles : berlines blanches a gyrophare (voiture.gd en pilote automatique) qui suivent les rues (itineraire
##   de scripts/carte.gd) jusqu'au joueur, une par niveau (4 au plus) ; a l'arret pres de lui, un agent descend et
##   court l'arreter ;
## - arrestation : agent a moins de 1,4 m pendant 1,5 s (joueur a pied ou vehicule arrete) : amende
##   (Partie.amende_par_niveau x niveau), sortie du commissariat ;
## - semer la police : hors de vue de tout agent pendant perte_vue s, le niveau retombe a zero ;
## - exces de vitesse sous les yeux d'une patrouille (sans etre recherche) : contravention ;
## - malaise (sante a zero) : reveil a la maison, frais de soins.

@export var player_path: NodePath = ^"../Player"
@export var perte_vue := 14.0            # s hors de vue pour semer la police (+ 4 s par niveau)
@export var vue_distance := 70.0         # m
@export var apparition := Vector2(140.0, 260.0)   # m du joueur
@export var vitesse_poursuite := 15.0    # m/s vises en ville (54 km/h), + 2 m/s par niveau
@export var limite_vitesse := 19.5       # m/s (70 km/h) : au-dela, contravention si une patrouille voit
@export var contravention := 2000        # FCFA
@export var agent_vitesse := 5.2         # m/s a la course

const DELITS := {"vol": 1, "agression": 1, "renverse": 1, "choc_police": 1, "evasion": 1}

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


func _ready() -> void:
	add_to_group("police")
	add_to_group("circulation")       # chocs entre vehicules (voiture.gd : on_vehicle_hit)
	_rng.randomize()
	_player = get_node_or_null(player_path)
	_carte = Carte.zone()
	Partie.recherche_change.connect(_on_level)
	Partie.evanoui.connect(_malaise)


func crime(kind: String, _where: Vector3) -> void:
	if _busy:
		return
	var add: int = DELITS.get(kind, 1)
	# deja recherche : un nouveau delit sous les yeux de la police fait monter plus vite
	Partie.set_recherche(maxi(Partie.recherche, 0) + add)
	_hors_vue = 0.0
	if Partie.recherche == 1 and kind != "evasion":
		Partie.notifier("La police a été prévenue")


func on_vehicle_hit(collider: Object, impact: float) -> void:
	## Le vehicule du joueur emboutit une patrouille.
	var pv: Node3D = _player.get("vehicle") if _player else null
	if pv and impact > 4.0 and collider is Node and (collider as Node).is_in_group("police_car") \
			and pv.global_position.distance_to((collider as Node3D).global_position) < 7.0:
		crime("choc_police", pv.global_position)


func _on_level(n: int) -> void:
	if n == 0:
		for u in units:
			_release(u)
		units.clear()
		Partie.police_voit = false


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
	# nombre de patrouilles selon le niveau
	var want := mini(Partie.recherche, 4)
	if units.size() < want:
		_spawn_unit(ppos)
	_route_t -= delta
	var seen := false
	for u in units.duplicate():
		if not is_instance_valid(u["car"]):
			units.erase(u)
			continue
		if _drive(u, ppos, pv, delta):
			seen = seen or _sees(u, ppos)
		if u.get("officer") and is_instance_valid(u["officer"]):
			_run_officer(u, ppos, pv, delta)
			seen = seen or (u["officer"] as Node3D).global_position.distance_to(ppos) < vue_distance * 0.6
	if _route_t <= 0.0:
		_route_t = 1.5
	Partie.police_voit = seen
	if seen:
		_hors_vue = 0.0
	else:
		_hors_vue += delta
		if _hors_vue > perte_vue + 4.0 * Partie.recherche:
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
func _make_car(at: Vector3, yaw: float) -> Node3D:
	var car := Vehicules.create("veh_berline", Color(0.93, 0.94, 0.95))
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
		lab.modulate = Color(0.05, 0.15, 0.6)
		lab.outline_size = 0
		lab.position = Vector3(0.93 * s, 0.85, 0.0)
		lab.rotation = Vector3(0, PI / 2.0 * s, 0)
		car.add_child(lab)
	return car


func _spawn_unit(ppos: Vector3) -> void:
	## Sur une rue reliee au joueur : on suit un itineraire depuis le joueur vers un point au hasard et la patrouille
	## apparait a 140-260 m le long de ce chemin, tournee vers lui.
	var pp := Vector2(ppos.x, ppos.z)
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
				var car := _make_car(Vector3(q.x, 0.0, q.y), atan2(-back.x, -back.y))
				units.append({"car": car, "route": PackedVector2Array(), "officer": null, "state": "chase", "stuck": 0.0})
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
	u["far_t"] = float(u.get("far_t", 0.0)) + delta if d > 75.0 and not _on_screen(car.global_position) else 0.0
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
	var goal := vitesse_poursuite + 2.0 * Partie.recherche
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
	return true


func _on_screen(p: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_to(p) < 90.0 and cam.is_position_in_frustum(p)


func _lights(car: Node3D) -> void:
	var bar := car.get_node_or_null("Gyrophare")
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
	Bulle.say(ch, ["Halte ! Police !", "Arrêtez-vous !", "Ne bougez plus !"][_rng.randi() % 3], 2.5)
	return ch


func _run_officer(u: Dictionary, ppos: Vector3, _pv: Node3D, delta: float) -> void:
	var o: Node3D = u["officer"]
	var to := ppos - o.global_position
	to.y = 0.0
	var d := to.length()
	var sp := 0.0 if d < 1.1 else agent_vitesse
	if d > 0.01:
		o.global_position += to / d * minf(sp * delta, maxf(d - 1.0, 0.0))
		o.rotation.y = atan2(-to.x, -to.z)          # le modele regarde -Z (comme les pietons)
	o.set("speed", sp)
	# trop loin (le joueur a file) : il remonte en voiture
	if d > 45.0:
		o.queue_free()
		u["officer"] = null


func _release(u: Dictionary) -> void:
	if u.get("officer") and is_instance_valid(u["officer"]):
		(u["officer"] as Node).queue_free()
	var car: Node3D = u["car"]
	if is_instance_valid(car) and not car.get("has_rider"):
		car.queue_free()


# ------------------------------------------------------------------ patrouille de routine, contraventions
func _routine(delta: float, pv: Node3D, ppos: Vector3) -> void:
	## Sans recherche : une patrouille stationne parfois au bord de la route ; un exces de vitesse devant elle
	## coute une contravention.
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
		Partie.prelever(contravention, "Contravention : excès de vitesse")
		Partie.stats["amendes"] = int(Partie.stats.get("amendes", 0)) + 1
		Bulle.say(car, "Excès de vitesse !", 2.5, 2.2)


# ------------------------------------------------------------------ arrestation, malaise
func _arrest() -> void:
	var lvl := Partie.recherche
	_busy = true
	_arrest_t = 0.0
	var hj := get_tree().get_first_node_in_group("hud_jeu")
	if hj:
		hj.annonce("ARRÊTÉ", "Amende : %s" % Partie.fcfa(Partie.amende_par_niveau * lvl), 3.5)
	_fade_then(func() -> void:
		if _player.get("vehicle"):
			_player.exit_vehicle()
		Partie.prelever(Partie.amende_par_niveau * lvl, "Amende")
		Partie.stats["amendes"] = int(Partie.stats.get("amendes", 0)) + 1
		Partie.set_recherche(0)
		_teleport(Vector3(330, 0, -250), "Commissariat de Gbê Town"))


func _malaise() -> void:
	if _busy:
		return
	_busy = true
	var hj := get_tree().get_first_node_in_group("hud_jeu")
	if hj:
		hj.annonce("ÉVANOUI", "Frais de soins : %s" % Partie.fcfa(Partie.frais_hopital), 3.5)
	_fade_then(func() -> void:
		if _player.get("vehicle"):
			_player.exit_vehicle()
		Partie.prelever(Partie.frais_hopital, "Soins")
		Partie.set_recherche(0)
		Partie.soigner(100.0)
		var lieux := get_node_or_null("../Lieux")
		_teleport(lieux.home_position() if lieux else Vector3.ZERO, "Réveil à la maison"))


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
