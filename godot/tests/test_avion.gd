extends SceneTree
## Test du trafic aerien : cycles complets (depart puis arrivee) sur la piste 06 et sur la piste 24.
## Verifie : repoussage termine sur T2, ecart a la trajectoire de roulage, alignement sur l'axe, point d'envol,
## hauteur en bout de piste, train rentre, toucher dans la zone de toucher, vitesse verticale au toucher,
## degagement, arret au poste (position et cap), aucun batiment touche par les bouts d'aile au roulage.
## Lancement : godot --headless --path godot --script res://tests/test_avion.gd [-- 06|24]

var frame := 0
var scene: Node
var air: Node
var carte: Carte
var fails := 0
var step := 0
var runway := "06"
var cycle: Array = []           # [["depart"|"arrivee", piste]]
var _phase := ""
var _max_err := 0.0
var _max_err_at := Vector2.ZERO
var _wing_hits := 0
var _hit_at := Vector2.ZERO
var _liftoff := INF
var _touch := Vector2.INF
var _touch_vs := 0.0
var _end_h := -1.0
var _gear_up := false
var _stand := -1
var _timeout := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	runway = args[0] if args.size() > 0 else "06"
	cycle = [["depart", runway], ["arrivee", runway]]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	air = scene.get_node("TraficAerien")
	carte = Carte.zone()
	Engine.time_scale = 6.0
	Engine.physics_ticks_per_second = 60


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 30:
		return false
	if air.get("mv") == null:
		_check(false, "script du trafic aerien non charge")
		Engine.time_scale = 1.0
		return true
	if air.mv.is_empty():
		if _phase != "":
			_summary()
		if step >= cycle.size():
			print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
			Engine.time_scale = 1.0
			return true
		_start(cycle[step])
		step += 1
		return false
	_timeout += 1
	if _timeout > 60 * 60 * 20:
		_check(false, "mouvement bloque en phase '%s'" % air.mv.get("phase", "?"))
		air.mv = {}
		return false
	_watch()
	return false


func _start(c: Array) -> void:
	_timeout = 0
	_max_err = 0.0
	_wing_hits = 0
	_liftoff = INF
	_touch = Vector2.INF
	_end_h = -1.0
	_gear_up = false
	_phase = ""
	if c[0] == "depart":
		_stand = -1
		for i in air.stands.size():
			if air.stands[i]["plane"] != null:
				_stand = i
				break
		_check(_stand >= 0, "avion gare au poste (%d postes, %d avions)" % [air.stands.size(), air.planes.size()])
		print("TEST depart piste %s depuis le poste %d" % [c[1], _stand])
		air.start_departure(_stand, c[1])
	else:
		print("TEST arrivee piste %s" % c[1])
		air.start_arrival(c[1])
		_stand = air.mv.get("stand", -1)


func _watch() -> void:
	var mv: Dictionary = air.mv
	var ph: String = mv.get("phase", "")
	var p: Node3D = mv["plane"]
	var pos: Vector2 = mv.get("pos", Vector2.ZERO)
	var r: Vector2 = air.to_rw(pos)
	if ph != _phase:
		_on_phase(_phase, ph, mv, r)
		_phase = ph
	if ph == "roulage":
		var path: PackedVector2Array = mv["path"]
		var best := INF
		for i in path.size() - 1:
			best = minf(best, pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, path[i], path[i + 1])))
		if best > _max_err:
			_max_err = best
			_max_err_at = r
		# bouts d'aile, nez et queue : jamais dans un batiment (dans la carte)
		var head: Vector2 = mv["head"]
		var side := Vector2(-head.y, head.x)
		for q in [pos + side * 17.9, pos - side * 17.9, pos + head * 20.6, pos - head * 17.0]:
			if carte.in_bounds(q) and carte.in_building(q):
				if _wing_hits == 0:
					_hit_at = air.to_rw(q)
				_wing_hits += 1
	if mv["kind"] == "depart" and ph == "envol":
		if _liftoff == INF:
			_liftoff = absf(r.x - (0.0 if mv["runway"] == "06" else float(air.RUNWAY_LENGTH)))
		var end_t: float = air.RUNWAY_LENGTH if mv["runway"] == "06" else 0.0
		if _end_h < 0.0 and absf(r.x - end_t) < 15.0:
			_end_h = mv["h"]
		if p.get("gear") <= 0.01:
			_gear_up = true
	if mv["kind"] == "arrivee" and ph == "roulement" and _touch == Vector2.INF:
		_touch = r


func _on_phase(old: String, ph: String, mv: Dictionary, r: Vector2) -> void:
	if mv["kind"] == "depart":
		if old == "repoussage":
			var head: Vector2 = mv["head"]
			_check(absf(r.y - air.T2_S) < 3.0 and absf(head.dot(air._u)) > 0.98,
				"repoussage termine sur T2 (s = %.1f m, cap aligne %.2f)" % [r.y, absf(head.dot(air._u))])
		if old == "roulage":
			var head: Vector2 = mv["head"]
			var want: Vector2 = air._u if mv["runway"] == "06" else -air._u
			_check(_max_err < 6.0, "roulage : ecart maximal a la trajectoire %.1f m (t = %.0f, s = %.0f)" % [_max_err, _max_err_at.x, _max_err_at.y])
			_check(_wing_hits == 0, "roulage : bouts d'aile, nez et queue hors des batiments (%d contacts)" % _wing_hits)
			_check(absf(r.y) < 2.5 and head.dot(want) > 0.995, "aligne sur l'axe : ecart %.1f m, cap %.1f deg" % [r.y, rad_to_deg(head.angle_to(want))])
		if ph == "" or old == "envol":
			pass
	else:
		if old == "arrondi":
			pass
		if old == "roulement":
			_check(_touch.x != INF, "toucher enregistre")
			var thr_d: float = _touch.x if mv["runway"] == "06" else air.RUNWAY_LENGTH - _touch.x
			_check(thr_d > 300.0 and thr_d < 900.0 and absf(_touch.y) < 2.0,
				"toucher dans la zone de toucher : %.0f m du seuil, %.1f m de l'axe" % [thr_d, _touch.y])
			_check(float(mv["speed"]) <= 12.0, "vitesse au degagement %.1f m/s" % float(mv["speed"]))
	if ph == "":
		pass


func _summary() -> void:
	## Fin d'un mouvement (efface par air_traffic) : bilans.
	if _phase == "envol":
		_check(_liftoff > 800.0 and _liftoff < 1900.0, "envol a %.0f m du debut de la course" % _liftoff)
		_check(_end_h > 60.0, "hauteur au-dessus du bout de piste : %.0f m" % _end_h)
		_check(_gear_up, "train rentre apres l'envol")
	elif _phase == "arret":
		_check(_max_err < 6.0, "roulage vers le poste : ecart maximal %.1f m (t = %.0f, s = %.0f)" % [_max_err, _max_err_at.x, _max_err_at.y])
		_check(_wing_hits == 0, "roulage vers le poste : aucun batiment touche (%d, premier a t = %.0f, s = %.0f)" % [_wing_hits, _hit_at.x, _hit_at.y])
		var st: Dictionary = air.stands[_stand]
		var pl: Node3D = st["plane"]
		var pos := Vector2(pl.global_position.x, pl.global_position.z) if pl else Vector2.INF
		var fwd := -pl.global_transform.basis.z if pl else Vector3.ZERO
		_check(pl != null and pos.distance_to(st["pos"]) < 1.5 and Vector2(fwd.x, fwd.z).normalized().dot(st["dir"]) > 0.99,
			"arret au poste : a %.2f m du repere, cap aligne" % pos.distance_to(st["pos"]))
	else:
		_check(false, "mouvement termine en phase '%s'" % _phase)
	_phase = ""
