extends CharacterBody3D
## Joueur a pied, vue 3e personne.
## ZQSD : bouger (relatif a la camera). Shift : courir. Espace : sauter.
## Souris : tourner la camera. Molette : zoom. Echap : liberer / reprendre la souris.

@export var walk_speed := 4.0
@export var run_speed := 8.5
@export var jump_velocity := 5.0
@export var acceleration := 12.0
@export var air_control := 0.3
@export var turn_speed := 10.0
@export var mouse_sensitivity := 0.0025
@export var zoom_min := 2.0
@export var zoom_max := 12.0

@onready var cam_pivot: Node3D = $CamPivot
@onready var spring_arm: SpringArm3D = $CamPivot/SpringArm3D
@onready var body: Node3D = $Body

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	# la camera ne doit pas buter contre le joueur lui-meme
	spring_arm.add_excluded_object(get_rid())
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


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (Basis(Vector3.UP, cam_pivot.rotation.y) * Vector3(input.x, 0, input.y)).normalized()
	var speed := run_speed if Input.is_action_pressed("sprint") else walk_speed
	var accel := acceleration if is_on_floor() else acceleration * air_control
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, accel * speed * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * speed * delta)

	if dir != Vector3.ZERO:
		var angle := atan2(-dir.x, -dir.z)
		body.rotation.y = lerp_angle(body.rotation.y, angle, turn_speed * delta)

	move_and_slide()
