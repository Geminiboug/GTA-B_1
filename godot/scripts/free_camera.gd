extends Camera3D
## Camera libre de test : ZQSD pour bouger, clic droit maintenu pour tourner, Shift pour accelerer.

@export var speed := 10.0
@export var mouse_sensitivity := 0.003

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotation.y -= event.relative.x * mouse_sensitivity
		rotation.x = clamp(rotation.x - event.relative.y * mouse_sensitivity, -1.5, 1.5)

func _process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := global_transform.basis * Vector3(input.x, 0, input.y)
	var boost := 4.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	global_position += dir * speed * boost * delta
