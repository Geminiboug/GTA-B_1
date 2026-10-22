extends Node3D
## Zem a heler au bord de la rue (demande d'Olympe du 21/10/2026) : H hele un zem qui arrive en vrai par les rues, E pour
## monter derriere le conducteur, on choisit la destination et le trajet se fait en direct (aucune teleportation), puis
## le zem depose le joueur et repart. Le prix est celui de la course (tarifs de zem), paye au depart.
## Complement du deplacement rapide des stations (scripts/taxi.gd) : ici le trajet se vit.

const ZEM_SCENE := preload("res://scenes/zem.tscn")
const DESTINATIONS := preload("res://scripts/taxi.gd").DESTINATIONS

@export var portee_route := 14.0             # m : distance maxi du joueur a une rue pour heler
@export var vitesse := 13.0                  # m/s en ligne droite (47 km/h)
@export var apparition := Vector2(70.0, 110.0)   # m : distance de depart du zem
@export var prix_base := 200                 # FCFA
@export var prix_km := 300                   # FCFA par km
@export var attente_max := 75.0              # s : le zem repart si le joueur ne monte pas

var etat := "libre"        # libre, arrive, pret, choix, course, depose, depart
var _zem: Node3D
var _route := PackedVector2Array()
var _dest := Vector3.ZERO
var _dest_nom := ""
var _t := 0.0
var _coince := 0.0
var _hint_t := 0.0
var _hint := false
var _rng := RandomNumberGenerator.new()
var _player: Node3D
var _hud: Node
var _carte: Carte
var _ui: CanvasLayer
var _liste: VBoxContainer
var _choix: Array = []
var _touche_tenue := {}


func _ready() -> void:
	_rng.randomize()
	_player = get_node_or_null("../Player")
	_hud = get_node_or_null("../HUD")


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if _carte == null:
		_carte = Carte.zone()
		if _carte == null:
			return
	match etat:
		"libre":
			_attente_appel(delta)
		"arrive":
			_t += delta
			if _conduire(delta, 5.0):
				etat = "pret"
				_t = 0.0
				_dire("Ça va ?", 1.6)
				Partie.notifier(tr("Le zem s'arrête : %s pour monter derrière.") % Partie.nom_touche("interact"))
			elif _t > 90.0:
				_renvoyer()
		"pret":
			_t += delta
			if _zem and _player.global_position.distance_to(_zem.global_position) < 3.6:
				if _hud and _hud.has_method("show_hint"):
					_hud.show_hint("%s : monter derrière le zem" % Partie.nom_touche("interact"))
				if Input.is_action_just_pressed("interact") and _player.get("vehicle") == null:
					_monter()
			if _t > attente_max:
				_renvoyer()
		"choix":
			_choisir()
		"course":
			_t += delta
			if _conduire(delta, 3.5):
				_arrivee()
		"depose":
			_t += delta
			if _t > 1.3 and _player.get("vehicle") == _zem:
				_player.call("exit_vehicle")
				if _hud and _hud.has_method("show_place"):
					_hud.show_place(_dest_nom)
				_depart()
		"depart":
			_t += delta
			_conduire(delta, 0.0)
			var loin := _zem == null or Vector2(_zem.global_position.x, _zem.global_position.z).distance_to(Vector2(_player.global_position.x, _player.global_position.z)) > 90.0
			if loin or _t > 25.0:
				_retirer()


# ------------------------------------------------------------------ appel
func _attente_appel(delta: float) -> void:
	if _player.get("vehicle") != null or Partie.recherche > 0:
		return
	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint_t = 0.5
		_hint = _pres_rue()
	if _hint and _hud and _hud.has_method("show_hint"):
		_hud.show_hint("%s : héler un zem" % Partie.nom_touche("heler"))
	if Input.is_action_just_pressed("heler"):
		_hele()


func _pres_rue() -> bool:
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	var near := _carte.nearest_on_network(pp)
	return not near.is_empty() and pp.distance_to(near["point"]) <= portee_route and not _carte.in_building(pp)


func _hele() -> void:
	if Partie.recherche > 0:
		Partie.notifier(tr("Aucun zem ne s'arrête : la police te cherche."))
		return
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	var near := _carte.nearest_on_network(pp)
	if near.is_empty() or pp.distance_to(near["point"]) > portee_route:
		Partie.notifier(tr("Va au bord d'une rue pour héler un zem."))
		return
	var but: Vector2 = near["point"]
	var depart := Vector2.INF
	var chemin := PackedVector2Array()
	for essai in 10:
		var a := _rng.randf() * TAU
		var q := pp + Vector2(cos(a), sin(a)) * _rng.randf_range(apparition.x, apparition.y)
		var nq := _carte.nearest_on_network(q)
		if nq.is_empty():
			continue
		var s: Vector2 = nq["point"]
		var r := _carte.route(s, but, true)
		if r.size() < 2:
			continue
		var L := 0.0
		for i in r.size() - 1:
			L += r[i].distance_to(r[i + 1])
		if L < 50.0 or L > 260.0:
			continue
		depart = s
		chemin = r
		if not _a_l_ecran(Vector3(s.x, 0.0, s.y)):
			break
	if depart == Vector2.INF:
		Partie.notifier(tr("Aucun zem en vue, essaie un peu plus loin."))
		return
	_zem = _fabriquer(depart, chemin)
	_route = chemin
	etat = "arrive"
	_t = 0.0
	Partie.notifier(tr("Tu hèles un zem : il arrive."))


func _a_l_ecran(p: Vector3) -> bool:
	var cam := get_viewport().get_camera_3d()
	return cam != null and not cam.is_position_behind(p) and cam.is_position_in_frustum(p) and cam.global_position.distance_to(p) < 150.0


func _fabriquer(at: Vector2, chemin: PackedVector2Array) -> Node3D:
	var z := ZEM_SCENE.instantiate() as Node3D
	z.name = "ZemTaxi"
	add_child(z)
	var dir := (chemin[1] - chemin[0]).normalized() if chemin.size() > 1 else Vector2.DOWN
	var yaw := atan2(-dir.x, -dir.y)
	z.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, 0.4, at.y))
	z.set("_yaw", yaw)
	z.set("ai", true)
	z.set("max_speed", 20.0)
	var visual := z.get_node("Visual") as Node3D
	var pilote := PnjUtil.make("homme", false)
	pilote.name = "Pilote"
	visual.add_child(pilote)
	PnjUtil.apply(pilote, PnjUtil.random_look(pilote, _rng, "zem"))
	PnjUtil.pose_seated(pilote)
	pilote.position = Vector3(0, -0.05, 0.12)
	return z


func _dire(texte: String, duree := 2.4) -> void:
	if _zem and is_instance_valid(_zem):
		var p := _zem.find_child("Pilote", true, false) as Node3D
		if p:
			Bulle.say(p, texte, duree, 2.05)


# ------------------------------------------------------------------ conduite automatique
func _conduire(delta: float, arret: float) -> bool:
	## Suit _route ; vrai quand le zem est arrete a `arret` m du bout (arret 0 : ne s'arrete jamais).
	if _zem == null or not is_instance_valid(_zem):
		return false
	var z := _zem
	var cp := Vector2(z.global_position.x, z.global_position.z)
	while _route.size() > 1 and cp.distance_to(_route[0]) < 6.0:
		_route.remove_at(0)
	var bout := _route[_route.size() - 1] if _route.size() > 0 else cp
	var reste := cp.distance_to(_route[0]) if _route.size() > 0 else 0.0
	for i in range(0, _route.size() - 1):
		reste += _route[i].distance_to(_route[i + 1])
	var aim := _route[0] if _route.size() > 0 else bout
	var yaw: float = float(z.get("_yaw"))
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var to := (aim - cp).normalized() if aim.distance_to(cp) > 0.1 else fwd
	var ang := atan2(fwd.cross(to), fwd.dot(to))      # + : a gauche
	var v: float = float(z.get("speed"))
	var but := vitesse
	# virages : on ralentit selon l'angle a prendre, et avant les carrefours
	but = minf(but, lerpf(but, 4.5, clampf(absf(ang) / 1.3, 0.0, 1.0)))
	if _route.size() >= 2 and cp.distance_to(_route[0]) < maxf(v, 4.0) * 2.0:
		var turn := absf((_route[0] - cp).angle_to(_route[1] - _route[0]))
		but = minf(but, lerpf(but, 5.0, clampf(turn / 1.3, 0.0, 1.0)))
	# obstacle devant (voiture arretee au carrefour, vehicule lent) : on ralentit et on attend derriere au lieu de le percuter
	var libre_devant := _distance_libre(z, fwd)
	if libre_devant < 14.0:
		but = minf(but, maxf(0.0, (libre_devant - 3.5) * 1.2))
	var fini := false
	if arret > 0.0:
		var libre := maxf(reste - arret, 0.0)
		but = minf(but, sqrt(2.0 * 2.2 * libre) + 0.5)
		fini = reste <= arret + 0.8 and absf(v) < 0.6
	var freine := v > but + 1.0 or (arret > 0.0 and reste <= arret)
	z.set("ai_input", Vector3(0.0 if freine or v > but else clampf((but - v) / 3.0, 0.25, 1.0), 1.0 if freine else 0.0, clampf(-ang * 2.0, -1.0, 1.0)))
	# coince longtemps (mur, voiture en travers) : replace un peu plus loin sur le trajet, en dernier recours
	if absf(v) < 0.7 and not fini and not (arret > 0.0 and reste <= arret + 1.5) and libre_devant > 6.0:
		_coince += delta
	else:
		_coince = maxf(0.0, _coince - delta)
	if _coince > 9.0 and _route.size() > 0:
		var nxt: Vector2 = _route[0] if _route.size() == 1 else _route[1]
		var dv := (nxt - cp).normalized() if nxt.distance_to(cp) > 1.0 else fwd
		var ny := atan2(-dv.x, -dv.y)
		z.global_transform = Transform3D(Basis(Vector3.UP, ny), Vector3(nxt.x, z.global_position.y + 0.2, nxt.y))
		z.set("_yaw", ny)
		z.set("speed", 0.0)
		_coince = 0.0
	return fini


func _distance_libre(z: Node3D, fwd: Vector2) -> float:
	## Distance libre devant le zem (rayon horizontal a 0,6 m du sol, 16 m maxi).
	var depart := z.global_position + Vector3(0, 0.6, 0) + Vector3(fwd.x, 0, fwd.y) * 1.2
	var q := PhysicsRayQueryParameters3D.create(depart, depart + Vector3(fwd.x, 0, fwd.y) * 16.0, 1, [z.get_rid()])
	var h := z.get_world_3d().direct_space_state.intersect_ray(q)
	return 16.0 if h.is_empty() else depart.distance_to(h["position"])


# ------------------------------------------------------------------ monter, choisir, arriver
func _monter() -> void:
	_player.call("enter_vehicle", _zem, true)
	etat = "choix"
	_t = 0.0
	_ouvrir_choix()


func _destinations() -> Array:
	var l: Array = []
	var h := get_node_or_null("../Histoire")
	if h and bool(h.get("active")) and h.get("_marker_pos") != null and (h.get("_marker_pos") as Vector3) != Vector3.INF:
		l.append([tr("Mon objectif"), h.get("_marker_pos")])
	for i in DESTINATIONS.size():
		var pos := Vector3(float(DESTINATIONS[i][1]), 0.0, float(DESTINATIONS[i][2]))
		if i == 0:
			var lieux := get_node_or_null("../Lieux")
			pos = lieux.home_position() if lieux else pos
		l.append([tr(DESTINATIONS[i][0]), pos])
	return l


func _prix(pos: Vector3) -> int:
	var d := Vector2(_zem.global_position.x, _zem.global_position.z).distance_to(Vector2(pos.x, pos.z))
	return int(round((prix_base + prix_km * d / 1000.0) / 50.0)) * 50


func _ouvrir_choix() -> void:
	if _ui == null:
		_ui = CanvasLayer.new()
		_ui.layer = 6
		add_child(_ui)
		var pc := PanelContainer.new()
		pc.anchor_left = 0.5
		pc.anchor_right = 0.5
		pc.anchor_top = 0.3
		pc.offset_left = -290
		pc.offset_right = 290
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.78)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		pc.add_theme_stylebox_override("panel", sb)
		_ui.add_child(pc)
		_liste = VBoxContainer.new()
		pc.add_child(_liste)
	_ui.visible = true
	for c in _liste.get_children():
		c.free()
	_choix = _destinations()
	var t := Label.new()
	t.text = tr("Zem : on va où ?   (%s en poche)") % Partie.fcfa(Partie.argent)
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_liste.add_child(t)
	for i in mini(_choix.size(), 9):
		var l := Label.new()
		l.text = "%d.  %s   %s" % [i + 1, _choix[i][0], Partie.fcfa(_prix(_choix[i][1]))]
		l.add_theme_font_size_override("font_size", 20)
		_liste.add_child(l)
	var h := Label.new()
	h.text = tr("1-9 : partir    Échap : descendre")
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_liste.add_child(h)


func _choisir() -> void:
	if Input.is_key_pressed(KEY_ESCAPE):
		_fermer_choix()
		_player.set("pillion_libre", true)
		_player.call("exit_vehicle")
		_depart()
		return
	for i in mini(_choix.size(), 9):
		var bas := Input.is_key_pressed(KEY_1 + i)
		if bas and not _touche_tenue.get(i, false):
			_partir(i)
			return
		_touche_tenue[i] = bas


func _fermer_choix() -> void:
	if _ui:
		_ui.visible = false
	_touche_tenue.clear()


func _partir(i: int) -> void:
	var pos: Vector3 = _choix[i][1]
	var p := _prix(pos)
	if not Partie.payer(p, "Zem vers %s" % _choix[i][0]):
		return
	var cp := Vector2(_zem.global_position.x, _zem.global_position.z)
	var near := _carte.nearest_on_network(Vector2(pos.x, pos.z))
	var but: Vector2 = near["point"] if not near.is_empty() else Vector2(pos.x, pos.z)
	var r := _carte.route(cp, but, true)
	if r.size() < 2:
		Partie.argent += p        # aucun itineraire : rembourse
		Partie.argent_change.emit(Partie.argent, p)
		Partie.notifier(tr("Le zem ne connaît pas le chemin."))
		return
	_route = r
	_dest = pos
	_dest_nom = String(_choix[i][0])
	_fermer_choix()
	etat = "course"
	_t = 0.0
	_dire(["On y va !", "Accroche-toi !", "C'est parti, patron !"][_rng.randi() % 3])
	if _hud and _hud.has_method("set_waypoint"):
		_hud.set_waypoint(Vector2(pos.x, pos.z))


func _arrivee() -> void:
	etat = "depose"
	_t = 0.0
	_player.set("pillion_libre", true)
	_dire(tr("On est arrivés !"))
	if _hud and _hud.has_method("clear_waypoint"):
		_hud.call("clear_waypoint")


func _depart() -> void:
	## Le zem repart : une rue au hasard, puis retire une fois loin ou hors de vue.
	etat = "depart"
	_t = 0.0
	if _zem == null:
		_retirer()
		return
	var cp := Vector2(_zem.global_position.x, _zem.global_position.z)
	var a := _rng.randf() * TAU
	var near := _carte.nearest_on_network(cp + Vector2(cos(a), sin(a)) * 140.0)
	var r := _carte.route(cp, near["point"], true) if not near.is_empty() else PackedVector2Array()
	_route = r if r.size() >= 2 else PackedVector2Array([cp + Vector2(cos(a), sin(a)) * 60.0])


func _renvoyer() -> void:
	## Le client n'est pas monte : le zem repart.
	_depart()


func _retirer() -> void:
	if _zem and is_instance_valid(_zem):
		_zem.queue_free()
	_zem = null
	_route = PackedVector2Array()
	etat = "libre"
	_t = 0.0
