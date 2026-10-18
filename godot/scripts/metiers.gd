extends Node3D
## Metiers et defis libres (phase 20).
## - Chauffeur de minibus : au volant d'un minibus, T lance la ligne (6 arrets sur le reseau) ; a chaque arret (a
##   l'arret, portes ouvertes 2 s) des passagers descendent et montent, chacun paie 200 F ; fin de ligne : prime.
## - Sauts acrobatiques : un saut de plus de 1,2 s en l'air ou de plus de 15 m en zem ou en voiture rapporte selon la
##   longueur, avec une annonce ("SAUT ACROBATIQUE").
## - Cauris caches : 20 petits sacs de cauris dans des recoins du quartier (cours, toits bas, derriere les maquis) ;
##   500 F chacun, 20 000 F la collection.

const NB_CAURIS := 20

@export var player_path: NodePath = ^"../Player"
@export var arrets_ligne := 6
@export var prix_place := 200
@export var prime_ligne := 3000

var ligne: Dictionary = {}          # {arrets, i, passagers, attente}
var _player: CharacterBody3D
var _hud: Node
var _rng := RandomNumberGenerator.new()
var _air_t := 0.0
var _air_dep := Vector3.ZERO
var _en_l_air := false
var _cauris: Array = []
var _marq: MeshInstance3D


func _ready() -> void:
	_rng.seed = 229
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null("../HUD")
	Partie.chantier_differe(_placer_cauris)   # etape de la mise en place etalee pendant le chargement


# ------------------------------------------------------------------ minibus
func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var v: Node3D = _player.get("vehicle")
	_sauts(v, delta)
	_ramasser()
	if not ligne.is_empty():
		_ligne_maj(v, delta)
		return
	if v and str(v.get("model_name")) == "veh_minibus" and absf(float(v.get("speed"))) < 1.0:
		if _hud and _hud.has_method("show_hint"):
			_hud.show_hint(tr("T : commencer une ligne de minibus"))
		if Input.is_action_just_pressed("parler"):
			lancer_ligne(v)


func lancer_ligne(v: Node3D) -> void:
	var carte := Carte.zone()
	var arrets: Array = []
	var p := Vector2(v.global_position.x, v.global_position.z)
	var dir := Vector2(-sin(float(v.get("_yaw"))), -cos(float(v.get("_yaw"))))
	var essais := 0
	while arrets.size() < arrets_ligne and essais < 60:
		essais += 1
		var n: Dictionary = carte.nearest_on_network(p + dir.rotated(_rng.randf_range(-0.8, 0.8)) * 220.0)
		if n.is_empty():
			continue
		var q: Vector2 = n["point"]
		if q.distance_to(p) < 90.0:
			dir = dir.rotated(_rng.randf_range(1.0, 2.0))
			continue
		dir = (q - p).normalized()
		p = q
		arrets.append(Vector3(q.x, 0, q.y))
	ligne = {"arrets": arrets, "i": 0, "passagers": _rng.randi_range(2, 6), "attente": 0.0, "gain": 0}
	_marqueur(arrets[0])
	Partie.notifier(tr("Ligne de minibus : %d arrêts. %d passagers à bord.") % [arrets.size(), ligne["passagers"]])


func _ligne_maj(v: Node3D, delta: float) -> void:
	if v == null or str(v.get("model_name")) != "veh_minibus":
		ligne = {}
		if _marq:
			_marq.visible = false
		Partie.notifier(tr("Ligne de minibus abandonnée."))
		return
	var a: Vector3 = ligne["arrets"][ligne["i"]]
	if v.global_position.distance_to(a) < 12.0 and absf(float(v.get("speed"))) < 0.8:
		ligne["attente"] = float(ligne["attente"]) + delta
		if float(ligne["attente"]) >= 2.0:
			# descentes et montees, chaque passager paie sa place
			var desc := _rng.randi_range(0, int(ligne["passagers"]))
			var mont := _rng.randi_range(1, 5)
			ligne["passagers"] = clampi(int(ligne["passagers"]) - desc + mont, 0, 14)
			var gain := mont * prix_place
			ligne["gain"] = int(ligne["gain"]) + gain
			Partie.gagner(gain, "Minibus")
			Partie.notifier(tr("Arrêt %d : %d descendent, %d montent (+%s).") % [int(ligne["i"]) + 1, desc, mont, Partie.fcfa(gain)])
			ligne["i"] = int(ligne["i"]) + 1
			ligne["attente"] = 0.0
			if int(ligne["i"]) >= (ligne["arrets"] as Array).size():
				Partie.gagner(prime_ligne, "Prime de fin de ligne")
				Partie.stats["lignes"] = int(Partie.stats.get("lignes", 0)) + 1
				Partie.notifier(tr("Fin de ligne ! Prime de %s.") % Partie.fcfa(prime_ligne))
				ligne = {}
				_marq.visible = false
			else:
				_marqueur(ligne["arrets"][ligne["i"]])
	else:
		ligne["attente"] = 0.0


func _marqueur(p: Vector3) -> void:
	if _marq == null:
		_marq = MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 4.0
		c.bottom_radius = 4.0
		c.height = 2.5
		c.cap_top = false
		c.cap_bottom = false
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 1.0, 0.4, 0.3)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		c.material = m
		_marq.mesh = c
		add_child(_marq)
	_marq.visible = true
	_marq.global_position = p + Vector3(0, 1.25, 0)
	var hc := get_node_or_null("../HUD")
	if hc and "waypoint" in hc:
		hc.set("waypoint", Vector2(p.x, p.z))
		hc.set("has_waypoint", true)


# ------------------------------------------------------------------ sauts acrobatiques
func _sauts(v: Node3D, delta: float) -> void:
	if v == null:
		_en_l_air = false
		return
	var air: bool = not (v as CharacterBody3D).is_on_floor() and absf(float(v.get("speed"))) > 8.0
	if air and not _en_l_air:
		_en_l_air = true
		_air_t = 0.0
		_air_dep = v.global_position
	elif air:
		_air_t += delta
	elif _en_l_air:
		_en_l_air = false
		var dist := Vector2(v.global_position.x - _air_dep.x, v.global_position.z - _air_dep.z).length()
		if _air_t > 1.2 or dist > 15.0:
			saut_reussi(dist, _air_t)


func saut_reussi(dist: float, duree: float) -> void:
	var gain := int(roundf(dist * 40.0 + duree * 300.0) / 50.0) * 50
	Partie.gagner(gain, "Saut acrobatique")
	Partie.stats["sauts"] = int(Partie.stats.get("sauts", 0)) + 1
	var hj := get_tree().get_first_node_in_group("hud_jeu")
	if hj and hj.has_method("annonce"):
		hj.annonce(tr("SAUT ACROBATIQUE"), tr("%.0f m, %.1f s en l'air : %s") % [dist, duree, Partie.fcfa(gain)], 2.5)


# ------------------------------------------------------------------ cauris caches
func _placer_cauris() -> void:
	## Recoins : a 4 a 12 m d'un point de rue, au pied d'un mur (rayon de sol), loin les uns des autres.
	var carte := Carte.zone()
	if carte == null:
		return
	var space := get_world_3d().direct_space_state
	var essais := 0
	while _cauris.size() < NB_CAURIS and essais < 600:
		essais += 1
		var n: Dictionary = carte.nearest_on_network(Vector2(_rng.randf_range(-600, 700), _rng.randf_range(-900, 500)))
		if n.is_empty():
			continue
		var q: Vector2 = n["point"]
		var off := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(4.0, 12.0)
		var p := Vector3(q.x + off.x, 30, q.y + off.y)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p - Vector3(0, 40, 0), 1))
		if hit.is_empty() or (hit["position"] as Vector3).y > 3.5:
			continue
		var pos: Vector3 = hit["position"]
		var loin := true
		for c in _cauris:
			if (c["pos"] as Vector3).distance_to(pos) < 60.0:
				loin = false
		if not loin:
			continue
		var id := _cauris.size()
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.12
		s.height = 0.2
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.9, 0.75)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.9, 0.6)
		m.emission_energy_multiplier = 0.4
		s.material = m
		mi.mesh = s
		add_child(mi)
		mi.global_position = pos + Vector3(0, 0.12, 0)
		mi.visible = not (Partie.drapeaux.get("cauris", []) as Array).has(id)
		_cauris.append({"id": id, "pos": pos, "node": mi})


func _ramasser() -> void:
	if _player.get("vehicle") != null:
		return
	var deja: Array = Partie.drapeaux.get("cauris", [])
	for c in _cauris:
		if deja.has(c["id"]):
			continue
		if _player.global_position.distance_to(c["pos"]) < 1.3:
			deja.append(c["id"])
			Partie.drapeaux["cauris"] = deja
			(c["node"] as Node3D).visible = false
			Partie.gagner(500, "Cauris trouvés")
			Partie.notifier(tr("Sac de cauris : %d / %d") % [deja.size(), NB_CAURIS])
			if deja.size() == NB_CAURIS:
				Partie.gagner(20000, "Tous les cauris")
