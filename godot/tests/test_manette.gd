extends SceneTree
## Verifie que les evenements manette arrivent bien sur les actions (sticks, gachettes analogiques, boutons).
## Lancement : godot --headless --path godot --script res://tests/test_manette.gd

func _send_axis(axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)


func _send_button(index: int, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	e.pressed = pressed
	Input.parse_input_event(e)


func _initialize() -> void:
	var lines: Array[String] = []
	_send_axis(JOY_AXIS_LEFT_Y, -0.8)
	_send_axis(JOY_AXIS_LEFT_X, 0.5)
	_send_axis(JOY_AXIS_RIGHT_X, -1.0)
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.5)
	_send_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
	_send_button(JOY_BUTTON_A, true)
	_send_button(JOY_BUTTON_X, true)
	_send_button(JOY_BUTTON_Y, true)
	Input.flush_buffered_events()
	lines.append("stick gauche avant 0.8 -> move_forward %.2f" % Input.get_action_strength("move_forward"))
	lines.append("stick gauche droite 0.5 -> move_right %.2f" % Input.get_action_strength("move_right"))
	lines.append("stick droit gauche -> look_left %.2f" % Input.get_action_strength("look_left"))
	lines.append("RT a moitie -> accelerate %.2f" % Input.get_action_strength("accelerate"))
	lines.append("LT a fond -> brake %.2f" % Input.get_action_strength("brake"))
	lines.append("A -> sprint %s, X -> jump %s, Y -> interact %s" % [Input.is_action_pressed("sprint"), Input.is_action_pressed("jump"), Input.is_action_pressed("interact")])
	for l in lines:
		print("TEST ", l)
	quit()
