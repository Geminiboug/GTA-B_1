extends CharacterBody3D
## Joueur a pied, vue 3e personne.
## Clavier : ZQSD bouger (trot), Shift sprint, Ctrl marcher, Espace sauter, E monter/descendre.
## Manette : stick gauche bouger, stick droit camera, A (Croix) sprint, X (Carre) sauter, L3 marcher, Y (Triangle) monter/descendre.
## Souris : tourner la camera. Molette : zoom. Echap : liberer / reprendre la souris.
## Vitesses reelles : marche ~1,6 m/s, trot ~4,2 m/s, sprint ~7 m/s.

@export var walk_speed := 1.6
@export var jog_speed := 4.2
@export var sprint_speed := 7.0
@export var jump_velocity := 4.4
@export var ground_accel := 9.0      # m/s2 au demarrage
@export var ground_decel := 14.0     # m/s2 au freinage
@export var air_accel := 1.5         # tres peu de controle en l'air
@export var turn_speed_slow := 12.0  # rad/s, demi-tour quasi immediat a l'arret
@export var turn_speed_fast := 4.5   # virages plus larges en sprint
@export var mouse_sensitivity := 0.0025
@export var zoom_min := 2.0
@export var zoom_max := 12.0

@onready var cam_pivot: Node3D = $CamPivot
@onready var spring_arm: SpringArm3D = $CamPivot/SpringArm3D
@onready var body: Node3D = $Body
@onready var anim: Node = get_node_or_null("Body/Model")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _cam_offset := Vector3(0, 1.6, 0)
var _facing := 0.0        # direction du corps (yaw)
var _prev_facing := 0.0
var _prev_hspeed := 0.0
var _fall_speed := 0.0
var _last_safe := Vector3.ZERO


func _ready() -> void:
	# la camera ne doit pas buter contre le joueur lui-meme
	spring_arm.add_excluded_object(get_rid())
	# camera independante, recalee chaque image sur la position lissee du joueur (pas de saccades)
	cam_pivot.top_level = true
	cam_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam_pivot.global_position = global_position + _cam_offset
	_facing = body.rotation.y
	_last_safe = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		cam_pivot.rotation.x = clamp(cam_pivot.rotation.x - event.relative.y * mouse_sensitivity, -1.2, 0.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = max(zoom_min, spring_arm.spring_length - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = min(zoom_max, spring_arm.spring_length + 0.5)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


@export var stick_look_speed := 2.6  # rad/s au stick droit


func _process(delta: float) -> void:
	cam_pivot.global_position = get_global_transform_interpolated().origin + _cam_offset
	# stick droit de la manette (quand on est a pied)
	if vehicle == null:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		cam_pivot.rotation.y -= look.x * stick_look_speed * delta
		cam_pivot.rotation.x = clamp(cam_pivot.rotation.x - look.y * stick_look_speed * 0.7 * delta, -1.2, 0.5)


# ---------- Vehicules : E pour monter / descendre ----------
var vehicle: Node3D = null
const ENTER_DISTANCE := 2.5
const HIP_HEIGHT := 0.92  # hauteur du bassin au-dessus des pieds


func _nearest_vehicle() -> Node3D:
	var best: Node3D = null
	var best_d := ENTER_DISTANCE
	for v in get_tree().get_nodes_in_group("vehicules"):
		var d: float = global_position.distance_to(v.global_position)
		if d < best_d:
			best_d = d
			best = v
	return best


func enter_vehicle(v: Node3D) -> void:
	vehicle = v
	$Collision.disabled = true
	velocity = Vector3.ZERO
	v.set_rider(true)
	v.get_node("CamRig").activate(true)
	if anim:
		anim.seated = true
	# le joueur suit la selle : pas d'interpolation propre pour eviter un decalage d'une image
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func exit_vehicle() -> void:
	var v := vehicle
	vehicle = null
	v.set_rider(false)
	v.get_node("CamRig").activate(false)
	$CamPivot/SpringArm3D/Camera3D.current = true
	# on descend a gauche de la moto, debout, en regardant dans le meme sens
	var left: Vector3 = -v.global_transform.basis.x
	global_transform = Transform3D(Basis.IDENTITY, v.global_position + left * 0.9 + Vector3.UP * 0.1)
	_facing = v.rotation.y
	body.rotation = Vector3(0, _facing, 0)
	cam_pivot.rotation.y = v.get_node("CamRig").rotation.y
	$Collision.disabled = false
	if anim:
		anim.seated = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	reset_physics_interpolation()


func _ride(_delta: float) -> void:
	var seat: Transform3D = vehicle.seat_transform()
	global_transform = Transform3D(seat.basis, seat.origin - seat.basis.y * HIP_HEIGHT)
	body.rotation = Vector3.ZERO
	if anim:
		anim.speed = 0.0
		anim.on_floor = true
		anim.turn_rate = 0.0
		anim.accel = 0.0


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if vehicle:
			exit_vehicle()
			return
		var v := _nearest_vehicle()
		if v:
			enter_vehicle(v)
	if vehicle:
		_ride(delta)
		return
	# filet de securite : si on passe sous la carte, retour au dernier endroit sur
	if global_position.y < -20.0:
		global_position = _last_safe + Vector3.UP * 1.0
		velocity = Vector3.ZERO
		reset_physics_interpolation()
	elif is_on_floor() and global_position.y > -0.5:
		_last_safe = global_position
	var was_on_floor := is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * delta
		_fall_speed = max(_fall_speed, -velocity.y)
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (Basis(Vector3.UP, cam_pivot.rotation.y) * Vector3(input.x, 0, input.y))
	var target_speed := jog_speed
	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed
	elif Input.is_action_pressed("walk"):
		target_speed = walk_speed
	target_speed *= min(dir.length(), 1.0)

	var hvel := Vector2(velocity.x, velocity.z)
	var hspeed := hvel.length()

	if is_on_floor():
		if dir.length() > 0.01:
			# le corps tourne vers la direction voulue, moins vite quand on va vite
			var want := atan2(-dir.x, -dir.z)
			var turn: float = lerp(turn_speed_slow, turn_speed_fast, clamp(hspeed / sprint_speed, 0.0, 1.0))
			_facing = rotate_toward(_facing, want, turn * delta)
			# on avance dans la direction du corps : virages en courbe, pas en glissade
			var fwd := Vector2(-sin(_facing), -cos(_facing))
			var align: float = clamp(cos(angle_difference(_facing, want)), 0.0, 1.0)
			var goal := target_speed * (0.35 + 0.65 * align)
			hspeed = move_toward(hspeed, goal, (ground_accel if goal > hspeed else ground_decel) * delta)
			hvel = fwd * hspeed
		else:
			hvel = hvel.move_toward(Vector2.ZERO, ground_decel * delta)
	else:
		var air_goal := Vector2(dir.x, dir.z) * target_speed
		hvel = hvel.move_toward(air_goal, air_accel * delta) if dir.length() > 0.01 else hvel

	velocity.x = hvel.x
	velocity.z = hvel.y
	body.rotation.y = _facing
	move_and_slide()

	if anim:
		var new_hspeed := Vector2(velocity.x, velocity.z).length()
		anim.speed = new_hspeed
		anim.on_floor = is_on_floor()
		anim.vertical_speed = velocity.y
		anim.turn_rate = angle_difference(_prev_facing, _facing) / delta
		anim.accel = (new_hspeed - _prev_hspeed) / delta
		if is_on_floor() and not was_on_floor:
			anim.land(_fall_speed)
		_prev_hspeed = new_hspeed
	if is_on_floor():
		_fall_speed = 0.0
	_prev_facing = _facing
