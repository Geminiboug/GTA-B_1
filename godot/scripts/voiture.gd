extends CharacterBody3D
## Voiture conduisible (berline, 4x4, minibus), conduite "arcade-simulation" comme dans les GTA.
## - Moteur a couple variable selon le regime, boite automatique a 5 rapports (passages avec coupure de couple,
##   retrogradage en reprise), pont, masse et trainee reelles : accelerations, reprises et vitesse de pointe en
##   decoulent. Frein moteur, patinage au demarrage si le couple depasse l'adherence des roues motrices.
## - Suspension : chaque roue suit le sol (rayon : trottoirs, bosses), la caisse seule bouge sur ressorts amortis
##   (plongee au freinage, cabrage a l'acceleration, roulis en virage, leger rebond).
## - Pneus a adherence limitee : la voiture garde son elan (inertie) et les pneus ne rattrapent la glissade
##   laterale que jusqu'a ~0,9 g : sous-virage si on entre trop vite, derapage au frein a main (arriere qui
##   decroche), contre-braquage possible.
## - Transfert de masse visible : roulis en virage, plongee au freinage, cabrage a l'acceleration.
## - Chocs : vitesse cassee, degats (fumee au capot, puis moteur hors service), son de choc ; crissements de pneus.
## - Phares et feux arriere allumes la nuit, feux stop au freinage, klaxon.
## Commandes : Z/S gaz / frein et marche arriere, Q/D direction, Espace frein a main, H klaxon, E descendre.
## Manette : RT / LT, stick gauche, RB frein a main, L3 klaxon, Y descendre.

signal rider_changed(has_rider: bool)

const G := 9.8
const LAMP_MAT := preload("res://shaders/lampe_material.tres")

@export var max_speed := 44.0          # m/s (~160 km/h) : limiteur
@export var masse := 1150.0            # kg (Vehicules.TUNING par modele)
@export var couple_max := 140.0        # N.m
@export var regime_couple := 4000.0    # tr/min du couple maximal
@export var regime_max := 6200.0       # tr/min (coupure)
@export var regime_ralenti := 850.0
@export var rapports: Array = [3.45, 1.94, 1.31, 1.03, 0.84]
@export var rapport_arriere := 3.3
@export var pont := 4.1
@export var rendement := 0.85
@export var part_motrice := 0.6        # part du poids sur les roues motrices (traction avant 0.6, 4x4 1.0)
@export var trainee := 0.62            # surface de trainee Cx.S (m2)
@export var duree_passage := 0.3       # s de coupure de couple a chaque passage de rapport
@export var suspension_freq := 1.5     # Hz (frequence propre de la caisse)
@export var suspension_amort := 0.35   # amortissement relatif
@export var debattement := 0.11        # m de course de roue (trottoirs, bosses)
@export var brake_decel := 9.5
@export var handbrake_decel := 3.5
@export var max_reverse := 6.0
@export var max_steer := 0.62          # rad aux roues, a l'arret
@export var steer_speed := 2.6
@export var grip := 0.92               # adherence laterale maximale (en g)
@export var drag := 0.0011             # trainee aerodynamique (par metre)
@export var roll_factor := 0.012
@export var pitch_factor := 0.011

var kind := "voiture"
var model_name := "veh_berline"
var has_rider := false
var ai := false                  # conduite automatique (police) tant que le joueur n'est pas au volant
var ai_input := Vector3.ZERO     # (accelerateur, frein, direction) 0..1, 0..1, -1..1 (+ = gauche)
var speed := 0.0         # vitesse longitudinale signee (camera, mini-carte, son, PNJ)
var throttle := 0.0
var braking := false
var health := 100.0
var rpm := 900.0
var rapport := 0                 # rapport engage (0 = premiere), -1 marche arriere
var patine := false              # roues motrices qui patinent (crissement)
var _passage_t := 0.0
var _parts: Array = []           # [Node3D, transform au repos] : caisse et details (pas les roues)
var _susp: Array = []            # [pivot de roue, position au repos, avant ?, gauche ?]
var _sq := Vector3.ZERO          # caisse : hauteur, tangage, roulis
var _sv := Vector3.ZERO          # vitesses correspondantes

var _vel := Vector2.ZERO
var _yaw := 0.0
var _yaw_rate := 0.0
var _steer := 0.0
var _roll := 0.0
var _pitch := 0.0
var _a_long := 0.0
var _a_lat := 0.0
var _visual: Node3D
var _steer_nodes: Array[Node3D] = []
var _wheel_nodes: Array[Node3D] = []
var _seat: Node3D
var _exit: Node3D
var _wheel_r := 0.31
var _wheelbase := 2.6
var _body_mats: Array = []          # [MeshInstance3D, surface, materiau carrosserie d'origine]
var _tail_mat: StandardMaterial3D
var _engine: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _screech: AudioStreamPlayer3D
var _crash: AudioStreamPlayer3D
var _smoke: GPUParticles3D
var _lights: Array[SpotLight3D] = []
var _crash_cd := 0.0
var _last_safe := Vector3.ZERO
var _day_night: Node

signal crashed(impact: float, other: Object)


func setup(model: Node3D, model_id: String, color: Color) -> void:
	## Appele par Vehicules.create() avant l'entree dans l'arbre.
	model_name = model_id
	_visual = model
	_visual.name = "Visual"
	add_child(_visual)
	_seat = _visual.find_child("pt_conducteur", true, false)
	_exit = _visual.find_child("pt_sortie", true, false)
	for side in ["g", "d"]:
		var st := _visual.find_child("piv_direction_av" + side, true, false) as Node3D
		if st:
			_steer_nodes.append(st)
		for tag in ["av", "ar"]:
			var w := _visual.find_child("piv_roue_" + tag + side, true, false) as Node3D
			if w:
				_wheel_nodes.append(w)
	var front := _visual.find_child("piv_direction_avg", true, false) as Node3D
	var rear := _visual.find_child("piv_roue_arg", true, false) as Node3D
	if front and rear:
		_wheelbase = absf(front.position.z - rear.position.z)
		_wheel_r = rear.position.y
	for c in _visual.get_children():
		var n := String(c.name)
		if c is Node3D and not n.begins_with("piv_") and not n.begins_with("pt_"):
			_parts.append([c, (c as Node3D).transform])
	for n in ["piv_direction_avg", "piv_direction_avd", "piv_roue_arg", "piv_roue_ard"]:
		var w := _visual.find_child(n, true, false) as Node3D
		if w:
			_susp.append([w, w.position, n.contains("_av"), n.ends_with("g")])
	# materiaux : teinte de carrosserie, phares la nuit, feux arriere
	_tail_mat = StandardMaterial3D.new()
	_tail_mat.albedo_color = Color(0.6, 0.04, 0.03)
	_tail_mat.emission_enabled = true
	_tail_mat.emission = Color(1.0, 0.08, 0.05)
	_tail_mat.emission_energy_multiplier = 0.0
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m == null:
				continue
			match m.resource_name:
				"mat_carrosserie":
					var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
					d.albedo_color = color
					mi.set_surface_override_material(s, d)
					_body_mats.append([d, color])
				"mat_lampe":
					mi.set_surface_override_material(s, LAMP_MAT)
				"mat_feu_arriere":
					mi.set_surface_override_material(s, _tail_mat)


func _ready() -> void:
	_yaw = rotation.y
	_last_safe = global_position
	_day_night = get_parent().get_node_or_null("JourNuit") if get_parent() else null
	_engine = _sound(AudioSynth.voiture_loop(), -6.0, 6.0, 90.0, true)
	_horn = _sound(AudioSynth.klaxon(350.0, 440.0, 0.5), -2.0, 10.0, 140.0, false)
	_screech = _sound(AudioSynth.crissement_loop(), -80.0, 6.0, 90.0, true)
	_crash = _sound(AudioSynth.choc(), 0.0, 8.0, 120.0, false)
	_smoke = _make_smoke()
	for side in [-0.6, 0.6]:
		var l := SpotLight3D.new()
		l.spot_range = 34.0
		l.spot_angle = 32.0
		l.light_energy = 0.0
		l.light_color = Color(1.0, 0.95, 0.85)
		l.shadow_enabled = false
		l.position = Vector3(side, 0.75, -2.3)
		l.rotation.x = -0.08
		_visual.add_child(l)
		_lights.append(l)


func _sound(stream: AudioStream, db: float, unit: float, maxd: float, play: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = maxd
	p.position = Vector3(0, 0.6, -1.0)
	add_child(p)
	if play:
		p.play()
	return p


func _make_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 2.2
	p.emitting = false
	p.position = Vector3(0, 1.0, -1.6)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.35, 0.35, 0.35, 0.35)
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p


func set_rider(value: bool) -> void:
	has_rider = value
	rider_changed.emit(value)


func seat_transform() -> Transform3D:
	return _seat.global_transform if _seat else global_transform


func entry_point() -> Vector3:
	return _exit.global_position if _exit else global_position


func exit_transform() -> Transform3D:
	var p := entry_point()
	return Transform3D(Basis(Vector3.UP, _yaw), Vector3(p.x, global_position.y + 0.1, p.z))


func horn() -> void:
	if not _horn.playing:
		_horn.play()


func damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	# carrosserie salie et ternie par les chocs
	for e in _body_mats:
		var m: BaseMaterial3D = e[0]
		m.albedo_color = (e[1] as Color).darkened((100.0 - health) / 100.0 * 0.35)
		m.roughness = lerpf(0.35, 0.8, 1.0 - health / 100.0)
	_smoke.emitting = health < 40.0
	if health <= 0.0:
		(_smoke.process_material as ParticleProcessMaterial).color = Color(0.1, 0.1, 0.1)


func couple(regime: float) -> float:
	## Courbe de couple : ~60 % au ralenti, maximum au regime de couple, ~80 % a la coupure.
	if regime <= regime_couple:
		return couple_max * lerpf(0.6, 1.0, clampf((regime - regime_ralenti) / (regime_couple - regime_ralenti), 0.0, 1.0))
	return couple_max * lerpf(1.0, 0.8, clampf((regime - regime_couple) / (regime_max - regime_couple), 0.0, 1.0))


func vitesse_pointe() -> float:
	## Vitesse (m/s) ou la force du moteur sur le meilleur rapport egale la trainee et le roulement (sans limiteur).
	var best := 0.0
	for r in rapports:
		var v := 1.0
		while v < 90.0:
			var engine := v / _wheel_r * 60.0 / TAU * float(r) * pont
			if engine > regime_max:
				break
			var force := couple(engine) * float(r) * pont * rendement / _wheel_r
			if force < 0.5 * 1.2 * trainee * v * v + 0.015 * masse * G:
				break
			v += 0.25
		best = maxf(best, v)
	return best


func _boite(v: float, acc_in: float) -> void:
	## Boite automatique : monte pres du regime maximal, redescend en deceleration ou en reprise pied au plancher.
	if rapport < 0 or v < 0.5:
		if rapport >= 0:
			rapport = 0
		return
	var wheel_rpm := v / _wheel_r * 60.0 / TAU
	var r_now := wheel_rpm * float(rapports[rapport]) * pont
	if r_now > regime_max * 0.9 and rapport < rapports.size() - 1 and acc_in > 0.05:
		rapport += 1
		_passage_t = duree_passage
	elif rapport > 0:
		var r_down := wheel_rpm * float(rapports[rapport - 1]) * pont
		if r_now < regime_max * 0.38 or (acc_in > 0.9 and r_down < regime_max * 0.8 and r_now < regime_couple * 0.85):
			rapport -= 1


func _physics_process(delta: float) -> void:
	var acc_in := 0.0
	var brake_in := 0.0
	var steer_in := 0.0
	var hand := not has_rider  # frein de stationnement quand personne ne conduit
	if has_rider:
		acc_in = Input.get_action_strength("accelerate")
		brake_in = Input.get_action_strength("brake")
		steer_in = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		hand = Input.is_action_pressed("handbrake")
		if Input.is_action_just_pressed("horn"):
			horn()
	elif ai:
		# pilote automatique (scripts/police.gd) : memes commandes que le joueur
		acc_in = ai_input.x
		brake_in = ai_input.y
		steer_in = ai_input.z
		hand = false
	if health <= 0.0:
		acc_in = 0.0
	var fwd := Vector2(-sin(_yaw), -cos(_yaw))
	var right := Vector2(cos(_yaw), -sin(_yaw))
	var v_long := _vel.dot(fwd)
	var v_lat := _vel.dot(right)

	# --- longitudinal : moteur (couple selon le regime), boite automatique, adherence, freins, resistances ---
	throttle = move_toward(throttle, acc_in, delta * 3.0)
	var a := 0.0
	braking = false
	patine = false
	_passage_t = maxf(0.0, _passage_t - delta)
	var wheel_rpm := absf(v_long) / _wheel_r * 60.0 / TAU
	var en_arriere := v_long < -0.3 or (brake_in > 0.0 and acc_in == 0.0 and v_long < 0.5)
	if en_arriere:
		rapport = -1
	elif rapport < 0:
		rapport = 0
	var ratio: float = (rapport_arriere if rapport < 0 else float(rapports[rapport])) * pont
	# embrayage qui patine au demarrage : le moteur monte en regime avant que la voiture ne suive
	var pedal := brake_in if en_arriere else throttle
	var engine := maxf(wheel_rpm * ratio, regime_ralenti + pedal * 1800.0 * clampf(1.0 - wheel_rpm * ratio / 2600.0, 0.0, 1.0))
	engine = minf(engine, regime_max * 1.02)
	# poids sur les roues motrices : transfert de charge (l'avant s'allege en acceleration, l'arriere se charge)
	var shift_load := clampf(_a_long * 0.55 / (G * _wheelbase), -0.15, 0.15)
	var load := part_motrice
	if part_motrice < 1.0:
		load += shift_load if part_motrice < 0.5 else -shift_load
	var traction := grip * G * clampf(load, 0.2, 1.0)
	if acc_in > 0.0:
		if v_long > -0.5:
			var force := couple(engine) * acc_in * ratio * rendement / _wheel_r
			if _passage_t > 0.0 or engine >= regime_max:
				force = 0.0
			var a_drive := force / masse
			if a_drive > traction:
				patine = v_long < 12.0
				a_drive = traction
			if v_long < max_speed:
				a += a_drive
		else:
			a += brake_decel * acc_in
			braking = true
	if brake_in > 0.0:
		if v_long > 0.5:
			a -= brake_decel * brake_in
			braking = true
		elif v_long > -max_reverse:
			a -= minf(couple(engine) * brake_in * rapport_arriere * pont * rendement / _wheel_r / masse, traction) * 0.7
	# resistances : trainee aerodynamique, roulement, frein moteur (pied leve, rapport engage)
	var resist := (0.5 * 1.2 * trainee * v_long * v_long + 0.015 * masse * G) / masse
	if acc_in == 0.0 and absf(v_long) > 1.0:
		resist += couple_max * 0.12 * ratio * rendement / _wheel_r / masse
	if hand:
		resist += handbrake_decel
	var nl := v_long + a * delta
	if acc_in == 0.0 and brake_in == 0.0 or hand:
		nl = move_toward(nl, 0.0, resist * delta)
	else:
		nl -= signf(nl) * minf(resist * delta, absf(nl))
	_boite(nl, acc_in)
	rpm = lerpf(rpm, engine, 1.0 - exp(-10.0 * delta))
	# --- direction : modele bicyclette limite par l'adherence ---
	var steer_limit := max_steer / (1.0 + absf(nl) * 0.055)
	_steer = move_toward(_steer, steer_in * steer_limit, steer_speed * delta)
	var target_rate := nl * tan(_steer) / _wheelbase
	var max_rate := grip * G / maxf(absf(nl), 1.0)
	if hand and absf(nl) > 5.0:
		max_rate *= 1.8           # l'arriere decroche : la voiture pivote
		target_rate *= 1.5
	target_rate = clampf(target_rate, -max_rate, max_rate)
	_yaw_rate = lerpf(_yaw_rate, target_rate, 1.0 - exp(-7.0 * delta))
	# --- lateral : les pneus "rattrapent" la glissade jusqu'a la limite d'adherence ---
	var lat_grip := grip * G * (0.3 if hand and absf(nl) > 3.0 else 1.0)
	var nlat := move_toward(v_lat, 0.0, lat_grip * delta)
	_vel = fwd * nl + right * nlat
	_yaw += _yaw_rate * delta
	rotation.y = _yaw

	# --- deplacement et chocs ---
	var before := _vel
	velocity.x = _vel.x
	velocity.z = _vel.y
	if not is_on_floor():
		velocity.y -= G * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_crash_cd = maxf(0.0, _crash_cd - delta)
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.6:
			continue
		var n2 := Vector2(n.x, n.z).normalized()
		var impact := -before.dot(n2)
		if impact > 1.5:
			_vel -= n2 * _vel.dot(n2) * 1.25        # rebond leger
			_vel *= 0.85
			if _crash_cd <= 0.0 and impact > 3.0:
				_crash_cd = 0.4
				_crash.volume_db = linear_to_db(clampf(impact / 15.0, 0.15, 1.0))
				_crash.play()
				damage((impact - 3.0) * 2.2)
				crashed.emit(impact, c.get_collider())
				get_tree().call_group("circulation", "on_vehicle_hit", c.get_collider(), impact)
	# filet de securite : jamais sous la carte (retour au dernier endroit sur, a l'arret)
	if global_position.y < -0.6:
		global_position = _last_safe + Vector3.UP * 0.3
		_vel = Vector2.ZERO
		velocity = Vector3.ZERO
	elif is_on_floor() and absf(global_position.y) < 0.2:
		_last_safe = global_position
	var rv := get_real_velocity()
	if Vector2(rv.x, rv.z).length() < _vel.length():
		_vel = Vector2(rv.x, rv.z)
	speed = _vel.dot(Vector2(-sin(_yaw), -cos(_yaw)))
	_a_long = lerpf(_a_long, (speed - v_long) / delta, 1.0 - exp(-6.0 * delta))
	_a_lat = lerpf(_a_lat, speed * _yaw_rate, 1.0 - exp(-6.0 * delta))
	_update_visual(delta, absf(nlat))
	_update_sound(delta, absf(nlat))


func _update_visual(delta: float, slip: float) -> void:
	_suspension(delta)
	for st in _steer_nodes:
		st.rotation.y = _steer
	for w in _wheel_nodes:
		w.rotation.x -= speed / _wheel_r * delta
	var night: float = _day_night.get("night") if _day_night else 0.0
	_tail_mat.emission_energy_multiplier = (2.5 if braking else 0.0) + night * 0.8
	for l in _lights:
		l.light_energy = 6.0 * night if has_rider or speed != 0.0 else 0.0
	if (slip > 3.0 and absf(speed) > 4.0) or patine:
		_screech.volume_db = linear_to_db(clampf((slip - 3.0) / 6.0, 0.05, 1.0)) - 4.0
	else:
		_screech.volume_db = -80.0


func _suspension(delta: float) -> void:
	## Roues qui suivent le sol (rayon sous chaque roue), caisse sur ressorts amortis : hauteur, tangage, roulis.
	var off := [0.0, 0.0, 0.0, 0.0]
	if (has_rider or ai or absf(speed) > 0.5) and is_inside_tree():
		var space := get_world_3d().direct_space_state
		for i in _susp.size():
			var top: Vector3 = _visual.global_transform * ((_susp[i][1] as Vector3) + Vector3(0, 0.45, 0))
			var q := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 1.2, 0), 1, [get_rid()])
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				off[i] = clampf((hit["position"] as Vector3).y - (top.y - 0.45 - _wheel_r), -debattement, debattement)
	var front := 0.0
	var rear := 0.0
	var left := 0.0
	var right := 0.0
	for i in _susp.size():
		var w: Node3D = _susp[i][0]
		w.position.y = lerpf(w.position.y, (_susp[i][1] as Vector3).y + off[i], 1.0 - exp(-25.0 * delta))
		if _susp[i][2]:
			front += off[i] * 0.5
		else:
			rear += off[i] * 0.5
		if _susp[i][3]:
			left += off[i] * 0.5
		else:
			right += off[i] * 0.5
	var target := Vector3((front + rear) * 0.5,
		clampf((front - rear) / _wheelbase + _a_long * pitch_factor, -0.08, 0.07),
		clampf((right - left) / 1.5 - _a_lat * roll_factor, -0.09, 0.09))
	var w0 := TAU * suspension_freq
	var acc := (target - _sq) * w0 * w0 - _sv * 2.0 * suspension_amort * w0
	_sv += acc * delta
	_sq += _sv * delta
	_pitch = _sq.y
	_roll = _sq.z
	var cg := Vector3(0, 0.55, 0)
	var body := Transform3D(Basis.from_euler(Vector3(_sq.y, 0.0, _sq.z)), Vector3(0, _sq.x, 0))
	body = Transform3D(Basis.IDENTITY, cg) * body * Transform3D(Basis.IDENTITY, -cg)
	for p in _parts:
		(p[0] as Node3D).transform = body * (p[1] as Transform3D)


func _update_sound(delta: float, _slip: float) -> void:
	if health <= 0.0:
		rpm = lerpf(rpm, 0.0, 1.0 - exp(-6.0 * delta))
	_engine.pitch_scale = maxf(0.3, rpm / 2200.0)
	_engine.volume_db = -80.0 if health <= 0.0 else -10.0 + throttle * 5.0
