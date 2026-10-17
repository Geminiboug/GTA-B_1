extends CanvasLayer
## Mode photo (phase 13) : F12 (ou Select + Start a la manette) fige le jeu, cache le HUD et donne une camera libre
## autour du joueur : souris / stick droit pour tourner, ZQSD / stick gauche pour bouger, Espace / Ctrl monter et
## descendre, Shift plus vite, molette champ de vision. Entree (ou A) enregistre une capture dans user://captures/,
## F12 ou Echap (B) pour sortir.

@export var touche := KEY_F12
@export var vitesse := 4.0
@export var portee := 40.0            # m : la camera reste a cette distance du joueur au plus
@export var sensibilite := 0.0025

var actif := false
var _cam: Camera3D
var _prev_cam: Camera3D
var _hidden: Array[CanvasLayer] = []
var _hint: Label
var _center := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0
var _was_paused := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hint = Label.new()
	_hint.text = "MODE PHOTO   Entrée capture · ZQSD / souris bouger · Espace / Ctrl hauteur · molette zoom · F12 sortir"
	_hint.position = Vector2(24, 18)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.visible = false
	add_child(_hint)


func _unhandled_input(event: InputEvent) -> void:
	var toggle: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == touche
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START and Input.is_joy_button_pressed(event.device, JOY_BUTTON_BACK):
		toggle = true
	if toggle:
		if actif:
			sortir()
		elif not get_tree().paused:
			entrer()
		get_viewport().set_input_as_handled()
		return
	if not actif:
		return
	if event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		sortir()
		get_viewport().set_input_as_handled()
	elif (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		capture()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_yaw -= event.relative.x * sensibilite
		_pitch = clampf(_pitch - event.relative.y * sensibilite, -1.45, 1.45)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_cam.fov = clampf(_cam.fov + (-3.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 3.0), 15.0, 100.0)


func entrer() -> void:
	_prev_cam = get_viewport().get_camera_3d()
	if _prev_cam == null:
		return
	actif = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_hidden.clear()
	for c in get_parent().get_children():
		if c is CanvasLayer and c != self and (c as CanvasLayer).visible:
			(c as CanvasLayer).visible = false
			_hidden.append(c)
	_cam = Camera3D.new()
	_cam.fov = _prev_cam.fov
	_cam.far = _prev_cam.far
	add_child(_cam)
	_cam.global_transform = _prev_cam.global_transform
	_cam.current = true
	var e := _cam.global_basis.get_euler()
	_pitch = e.x
	_yaw = e.y
	var p := get_parent().get_node_or_null("Player") as Node3D
	_center = p.global_position if p else _cam.global_position
	_hint.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func sortir() -> void:
	actif = false
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.current = true
	if _cam:
		_cam.queue_free()
		_cam = null
	for c in _hidden:
		if is_instance_valid(c):
			c.visible = true
	_hidden.clear()
	_hint.visible = false
	get_tree().paused = _was_paused


func capture() -> String:
	## Capture sans le bandeau d'aide, dans user://captures/gtb_<date>.png ; renvoie le chemin.
	_hint.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return ""
	DirAccess.make_dir_recursive_absolute("user://captures")
	var path := "user://captures/gtb_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(path)
	_hint.visible = actif
	print("Capture : ", ProjectSettings.globalize_path(path))
	return path


func _process(delta: float) -> void:
	if not actif or _cam == null:
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_yaw -= look.x * 2.0 * delta
	_pitch = clampf(_pitch - look.y * 2.0 * delta, -1.45, 1.45)
	_cam.global_basis = Basis.from_euler(Vector3(_pitch, _yaw, 0))
	var mv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var up := (1.0 if Input.is_key_pressed(KEY_SPACE) else 0.0) - (1.0 if Input.is_key_pressed(KEY_CTRL) else 0.0)
	var dir := _cam.global_basis * Vector3(mv.x, 0, mv.y) + Vector3.UP * up
	var boost := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	var pos := _cam.global_position + dir * vitesse * boost * delta
	var off := pos - _center
	if off.length() > portee:
		pos = _center + off.normalized() * portee
	pos.y = maxf(pos.y, 0.3)
	_cam.global_position = pos
