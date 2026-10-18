extends CharacterBody3D
## Zem (moto-taxi) : conduite arcade-realiste.
## Clavier : Z gaz, S frein puis marche arriere, Q / D direction, Espace frein arriere, H klaxon.
## Manette : RT gaz, LT frein, stick gauche direction, RB frein arriere, L3 klaxon, Y descendre.
## Physique simplifiee d'une 125 cc : ~80 km/h max, rayon de braquage qui grandit avec la vitesse,
## inclinaison dans les virages, inertie, roues et guidon animes, plongee de fourche au freinage.

signal rider_changed(has_rider: bool)

@export var max_speed := 22.0          # m/s (~80 km/h)
@export var max_reverse := 2.0
@export var engine_accel := 4.2        # m/s2 a bas regime (125 cc chargee)
@export var brake_decel := 9.0
@export var rear_brake_decel := 5.0
@export var coast_decel := 0.8         # frein moteur + roulement
@export var wheelbase := 1.37
@export var max_steer := 0.6           # rad au guidon a l'arret
@export var steer_speed := 3.0         # rad/s pour tourner le guidon
@export var max_lean := 0.6            # rad (~35 degres)
@export var wheel_radius := 0.30
## Bequille centrale (piv_bequille, blender/tools/build_zem.py) : posee a l'arret sans conducteur, repliee des qu'on
## roule (le conducteur la releve en partant), redescendue quand on descend de la moto a l'arret.
const BEQUILLE_REPLIEE := -1.4          # rad autour de X
@export var bequille_vitesse := 7.0     # rad/s

var has_rider := false
var ai := false                  # pilote automatique (motos de police, scripts/police.gd)
var adresse := 1.0               # competence zem du joueur (scripts/stats.gd) : guidon plus vif et sur
var ai_input := Vector3.ZERO     # (gaz, frein, direction) comme voiture.gd
var speed := 0.0          # vitesse longitudinale (m/s, negative = marche arriere)
var throttle := 0.0       # 0..1, lu par le son
var _steer := 0.0
var _lean := 0.0
var _yaw := 0.0
var _last_safe := Vector3.ZERO
var _pitch := 0.0          # plongee de la fourche au freinage, cabrage a l'acceleration (visuel)
var _prev_speed := 0.0
@export var pitch_factor := 0.012
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visual: Node3D = $Visual
@onready var steer_pivot: Node3D = visual.find_child("piv_guidon", true, false)
@onready var wheel_f: Node3D = visual.find_child("piv_roue_av", true, false)
@onready var wheel_r: Node3D = visual.find_child("piv_roue_ar", true, false)
@onready var seat: Node3D = visual.find_child("pt_conducteur", true, false)
@onready var audio: Node = get_node_or_null("Audio")
@onready var bequille: Node3D = visual.find_child("piv_bequille", true, false)


func _ready() -> void:
	_yaw = rotation.y
	_last_safe = global_position


func set_rider(value: bool) -> void:
	has_rider = value
	rider_changed.emit(value)


func _physics_process(delta: float) -> void:
	var accel_in := 0.0
	var brake_in := 0.0
	var steer_in := 0.0
	var rear_brake := false
	if has_rider:
		# clavier : Z / S ; manette : gachettes RT / LT (analogiques), stick gauche pour diriger
		Limiteur.entrees()
		accel_in = Limiteur.gaz(Input.get_action_strength("accelerate"), speed)
		brake_in = maxf(Input.get_action_strength("brake"), Limiteur.retenue(speed))
		steer_in = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		rear_brake = Input.is_action_pressed("handbrake")
		if Input.is_action_just_pressed("horn") and audio:
			audio.horn()
	elif ai:
		accel_in = ai_input.x
		brake_in = ai_input.y
		steer_in = ai_input.z

	# --- Longitudinal ---
	throttle = move_toward(throttle, accel_in, delta * 4.0)
	if accel_in > 0.0 and speed >= -0.1:
		# couple qui baisse avec la vitesse (rapports de boite simplifies)
		var torque: float = engine_accel * (1.0 - pow(speed / max_speed, 2.0))
		speed += torque * accel_in * delta
	elif brake_in > 0.0:
		if speed > 0.2:
			speed = move_toward(speed, 0.0, brake_decel * brake_in * delta)
		else:
			speed = move_toward(speed, -max_reverse, 2.0 * delta)
	else:
		speed = move_toward(speed, 0.0, coast_decel * delta)
	if rear_brake:
		speed = move_toward(speed, 0.0, rear_brake_decel * delta)
	speed = clamp(speed, -max_reverse, max_speed)

	# --- Direction : le guidon braque moins quand on va vite ---
	var steer_limit: float = max_steer / (1.0 + abs(speed) * 0.22)
	_steer = move_toward(_steer, steer_in * steer_limit, steer_speed * (adresse if has_rider else 1.0) * delta)
	# modele bicyclette : vitesse de lacet = v * tan(braquage) / empattement
	var yaw_rate := speed * tan(_steer) / wheelbase
	if rear_brake and abs(speed) > 4.0:
		yaw_rate *= 1.35  # le frein arriere fait legerement chasser l'arriere
	# adherence : acceleration laterale max = g * tan(inclinaison max) (~0,7 g)
	var max_yaw: float = gravity * tan(max_lean) / max(abs(speed), 0.5)
	yaw_rate = clamp(yaw_rate, -max_yaw, max_yaw)
	_yaw += yaw_rate * delta
	rotation.y = _yaw

	# --- Mouvement ---
	var fwd := -transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	# filet de securite : jamais sous la carte
	# (sous le fond marin des limites du monde, -1,2 m : l estran de la plage descend jusque-la)
	if global_position.y < -2.0:
		global_position = _last_safe + Vector3.UP * 0.3
		speed = 0.0
		velocity = Vector3.ZERO
	elif is_on_floor() and global_position.y > -0.3:
		_last_safe = global_position
	# dans la mer (surface a -0,3 m) : l eau freine fort
	if global_position.y < -0.5:
		speed *= exp(-1.8 * delta)
	# un choc contre un mur coupe la vitesse
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if abs(n.y) < 0.5 and fwd.dot(n) < -0.5:
			if absf(speed) > 3.0:
				get_tree().call_group("circulation", "on_vehicle_hit", get_slide_collision(i).get_collider(), absf(speed))
			speed *= 0.2

	# --- Visuel : inclinaison, guidon, roues ---
	# angle d'equilibre d'une moto en virage : tan(lean) = v * lacet / g
	var target_lean: float = clamp(atan(speed * yaw_rate / gravity), -max_lean, max_lean)
	_lean = lerp(_lean, target_lean, 1.0 - exp(-6.0 * delta))
	# transfert de masse : la fourche plonge au freinage, l'arriere s'ecrase a l'acceleration
	var a_long := (speed - _prev_speed) / maxf(delta, 0.001)
	_prev_speed = speed
	_pitch = lerpf(_pitch, clampf(a_long * pitch_factor, -0.07, 0.04), 1.0 - exp(-8.0 * delta))
	visual.rotation = Vector3(_pitch, 0.0, _lean)
	if steer_pivot:
		steer_pivot.rotation.y = _steer
	var spin := speed / wheel_radius * delta
	if wheel_f:
		wheel_f.rotation.x -= spin
	if wheel_r:
		wheel_r.rotation.x -= spin
	if bequille:
		var posee := not has_rider and not ai and absf(speed) < 0.3
		bequille.rotation.x = move_toward(bequille.rotation.x, 0.0 if posee else BEQUILLE_REPLIEE, bequille_vitesse * delta)


func seat_transform() -> Transform3D:
	return seat.global_transform if seat else global_transform


# interface commune avec voiture.gd (joueur, circulation, mini-carte)
var kind := "zem"
var health := 100.0


func entry_point() -> Vector3:
	return global_position - global_transform.basis.x * 0.6


func exit_transform() -> Transform3D:
	# on descend a gauche de la moto, debout, en regardant dans le meme sens
	var p := global_position - global_transform.basis.x * 0.9
	return Transform3D(Basis(Vector3.UP, rotation.y), p + Vector3.UP * 0.1)


func horn() -> void:
	if audio:
		audio.horn()
