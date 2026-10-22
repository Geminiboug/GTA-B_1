extends Node3D
## Camera de l'avion leger : derriere et au-dessus, l'horizon reste stable (le tangage est amorti) ; la souris oriente
## autour de l'avion, V passe en vue du cockpit (tete du pilote).

@export var distance := 13.0
@export var hauteur := 3.2
@export var mouse_sensitivity := 0.0025

@onready var avion: Node3D = get_parent()
@onready var cam: Camera3D = $Camera3D

var _dir := Vector3.FORWARD
var _orbite := Vector2.ZERO          # souris : lacet, tangage en plus
var _mouse_idle := 0.0
var _cockpit := false


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func activate(on: bool) -> void:
	cam.current = on
	if on:
		_dir = -avion.global_transform.basis.z
		_orbite = Vector2.ZERO
		_cockpit = false


func _unhandled_input(event: InputEvent) -> void:
	if not cam.current:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_orbite.x -= event.relative.x * mouse_sensitivity
		_orbite.y = clampf(_orbite.y - event.relative.y * mouse_sensitivity, -0.8, 0.8)
		_mouse_idle = 0.0
	elif event.is_action_pressed("camera_vue"):
		_cockpit = not _cockpit


func _process(delta: float) -> void:
	if not cam.current:
		return
	var xf := avion.get_global_transform_interpolated()
	var avant := -xf.basis.z
	_mouse_idle += delta
	if _mouse_idle > 2.0:
		_orbite = _orbite.lerp(Vector2.ZERO, 1.0 - exp(-1.5 * delta))
	if _cockpit:
		var tete := xf * Vector3(-0.3, 1.5, 0.45)
		cam.global_position = tete
		cam.global_transform.basis = xf.basis * Basis.from_euler(Vector3(_orbite.y, _orbite.x, 0.0))
		cam.fov = 80.0
		return
	var cible := Vector3(avant.x, avant.y * 0.45, avant.z).normalized()
	_dir = _dir.slerp(cible, 1.0 - exp(-3.0 * delta)).normalized()
	var lacet := Basis(Vector3.UP, _orbite.x)
	var d := lacet * _dir
	var droite := d.cross(Vector3.UP).normalized()
	d = d.rotated(droite, _orbite.y)
	cam.global_position = xf.origin - d * distance + Vector3.UP * hauteur
	cam.look_at(xf.origin + d * 4.0 + Vector3.UP * 1.2, Vector3.UP)
	cam.fov = 70.0
