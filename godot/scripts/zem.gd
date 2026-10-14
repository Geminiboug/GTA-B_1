extends CharacterBody3D
## Zem (moto-taxi) : conduite arcade-realiste.
## Z : accelerer. S : freiner puis reculer lentement. Q / D : tourner. Espace : frein arriere (derapage leger).
## H : klaxon. E : descendre (gere par le joueur).
## Physique simplifiee d'une 125 cc : ~80 km/h max, rayon de braquage qui grandit avec la vitesse,
## inclinaison dans les virages, inertie, roues et guidon animes.

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

var has_rider := false
var speed := 0.0          # vitesse longitudinale (m/s, negative = marche arriere)
var throttle := 0.0       # 0..1, lu par le son
var _steer := 0.0
var _lean := 0.0
var _yaw := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var visual: Node3D = $Visual
@onready var steer_pivot: Node3D = visual.find_child("piv_guidon", true, false)
@onready var wheel_f: Node3D = visual.find_child("piv_roue_av", true, false)
@onready var wheel_r: Node3D = visual.find_child("piv_roue_ar", true, false)
@onready var seat: Node3D = visual.find_child("pt_conducteur", true, false)
@onready var audio: Node = get_node_or_null("Audio")


func _ready() -> void:
	_yaw = rotation.y


func set_rider(value: bool) -> void:
	has_rider = value
	rider_changed.emit(value)


func _physics_process(delta: float) -> void:
	var accel_in := 0.0
	var brake_in := 0.0
	var steer_in := 0.0
	var rear_brake := false
	if has_rider:
		accel_in = Input.get_action_strength("move_forward")
		brake_in = Input.get_action_strength("move_back")
		steer_in = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		rear_brake = Input.is_action_pressed("jump")
		if Input.is_action_just_pressed("horn") and audio:
			audio.horn()

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
	_steer = move_toward(_steer, steer_in * steer_limit, steer_speed * delta)
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
	# un choc contre un mur coupe la vitesse
	for i in get_slide_collision_count():
		var n := get_slide_collision(i).get_normal()
		if abs(n.y) < 0.5 and fwd.dot(n) < -0.5:
			speed *= 0.2

	# --- Visuel : inclinaison, guidon, roues ---
	# angle d'equilibre d'une moto en virage : tan(lean) = v * lacet / g
	var target_lean: float = clamp(atan(speed * yaw_rate / gravity), -max_lean, max_lean)
	_lean = lerp(_lean, target_lean, 1.0 - exp(-6.0 * delta))
	visual.rotation.z = _lean
	if steer_pivot:
		steer_pivot.rotation.y = _steer
	var spin := speed / wheel_radius * delta
	if wheel_f:
		wheel_f.rotation.x -= spin
	if wheel_r:
		wheel_r.rotation.x -= spin


func seat_transform() -> Transform3D:
	return seat.global_transform if seat else global_transform
