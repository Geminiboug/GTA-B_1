extends CharacterBody3D
## Voiture conduisible (berline, 4x4, minibus), conduite "arcade-simulation" comme dans les GTA.
## - Moteur et boite automatique (regime, passages de rapports entendus), freins, marche arriere.
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

@export var max_speed := 44.0          # m/s (~160 km/h)
@export var engine_accel := 4.6        # m/s2 a bas regime (berline chargee)
@export var brake_decel := 9.5
@export var handbrake_decel := 3.5
@export var max_reverse := 6.0
@export var max_steer := 0.62          # rad aux roues, a l'arret
@export var steer_speed := 2.6
@export var grip := 0.92               # adherence laterale maximale (en g)
@export var drag := 0.0011             # trainee aerodynamique (par metre)
@export var roll_factor := 0.012
@export var pitch_factor := 0.011
@export var gear_tops: PackedFloat32Array = [7.0, 13.0, 20.0, 29.0, 44.0]

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

	# --- longitudinal : moteur, freins, marche arriere, resistances ---
	throttle = move_toward(throttle, acc_in, delta * 3.0)
	var a := 0.0
	braking = false
	if acc_in > 0.0:
		if v_long > -0.5:
			a += engine_accel * acc_in * clampf(1.0 - pow(maxf(v_long, 0.0) / max_speed, 2.0), 0.0, 1.0)
		else:
			a += brake_decel * acc_in
			braking = true
	if brake_in > 0.0:
		if v_long > 0.5:
			a -= brake_decel * brake_in
			braking = true
		elif v_long > -max_reverse:
			a -= engine_accel * 0.55 * brake_in
	var resist := 0.22 + drag * v_long * v_long
	if hand:
		resist += handbrake_decel
	var nl := v_long + a * delta
	if acc_in == 0.0 and brake_in == 0.0 or hand:
		nl = move_toward(nl, 0.0, resist * delta)
	else:
		nl -= signf(nl) * (0.22 + drag * nl * nl) * delta
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
	_pitch = lerpf(_pitch, clampf(_a_long * pitch_factor, -0.06, 0.05), 1.0 - exp(-5.0 * delta))
	_roll = lerpf(_roll, clampf(-_a_lat * roll_factor, -0.07, 0.07), 1.0 - exp(-5.0 * delta))
	_visual.rotation = Vector3(_pitch, 0.0, _roll)
	for st in _steer_nodes:
		st.rotation.y = _steer
	for w in _wheel_nodes:
		w.rotation.x -= speed / _wheel_r * delta
	var night: float = _day_night.get("night") if _day_night else 0.0
	_tail_mat.emission_energy_multiplier = (2.5 if braking else 0.0) + night * 0.8
	for l in _lights:
		l.light_energy = 6.0 * night if has_rider or speed != 0.0 else 0.0
	if slip > 3.0 and absf(speed) > 4.0:
		_screech.volume_db = linear_to_db(clampf((slip - 3.0) / 6.0, 0.05, 1.0)) - 4.0
	else:
		_screech.volume_db = -80.0


func _update_sound(delta: float, _slip: float) -> void:
	var v := absf(speed)
	var gear := 0
	while gear < gear_tops.size() - 1 and v > gear_tops[gear] * 0.95:
		gear += 1
	var low: float = 0.0 if gear == 0 else gear_tops[gear - 1] * 0.62
	var t := clampf((v - low) / (gear_tops[gear] - low), 0.0, 1.0)
	var target := lerpf(1100.0, 5600.0, t)
	if v < 1.0:
		target = 850.0 + throttle * 2600.0
	if health <= 0.0:
		target = 0.0
	rpm = lerpf(rpm, target, 1.0 - exp(-6.0 * delta))
	_engine.pitch_scale = maxf(0.3, rpm / 2200.0)
	_engine.volume_db = -80.0 if health <= 0.0 else -10.0 + throttle * 5.0
