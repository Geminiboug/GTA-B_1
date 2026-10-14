extends Node3D
## Camera de conduite du zem : suit la position lissee de la moto,
## se replace derriere elle quand on roule, la souris permet de regarder autour.

@export var follow_height := 1.5
@export var auto_align_speed := 2.5   # rad/s
@export var mouse_sensitivity := 0.0025

@onready var zem: Node3D = get_parent()
@onready var cam: Camera3D = $SpringArm3D/Camera3D
@onready var arm: SpringArm3D = $SpringArm3D

var _mouse_idle := 0.0


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	arm.add_excluded_object(zem.get_rid())
	global_position = zem.global_position + Vector3.UP * follow_height
	rotation.y = zem.rotation.y


func activate(on: bool) -> void:
	cam.current = on
	if on:
		rotation.y = zem.rotation.y
		rotation.x = -0.25


func _unhandled_input(event: InputEvent) -> void:
	if not cam.current:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.x = clamp(rotation.x - event.relative.y * mouse_sensitivity, -1.0, 0.3)
		_mouse_idle = 0.0


func _process(delta: float) -> void:
	global_position = zem.get_global_transform_interpolated().origin + Vector3.UP * follow_height
	_mouse_idle += delta
	if cam.current:
		# stick droit de la manette
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look.length() > 0.0:
			rotation.y -= look.x * 2.6 * delta
			rotation.x = clamp(rotation.x - look.y * 1.8 * delta, -1.0, 0.3)
			_mouse_idle = 0.0
	# apres 1,5 s sans souris, la camera revient derriere la moto quand elle roule
	if _mouse_idle > 1.5 and abs(zem.speed) > 2.0:
		rotation.y = rotate_toward(rotation.y, zem.rotation.y, auto_align_speed * delta)
	# un peu plus loin et plus large a haute vitesse
	arm.spring_length = lerp(arm.spring_length, 4.5 + abs(zem.speed) * 0.08, 1.0 - exp(-2.0 * delta))
	cam.fov = lerp(cam.fov, 70.0 + abs(zem.speed) * 0.5, 1.0 - exp(-2.0 * delta))
