extends Node3D
## Trafic aerien : decollages et atterrissages sur la vraie piste de l'aeroport (axe tire des donnees OSM).
## - decollage : roulage depuis le seuil, acceleration jusqu'a ~280 km/h, rotation, montee a ~8 degres ;
## - atterrissage : approche finale a 3 degres, arrondi, toucher, freinage puis sortie de piste ;
## - grondement des reacteurs synthetise (audible de loin), feux anticollision clignotants la nuit.
## Un mouvement toutes les 2 a 5 minutes reelles (premier mouvement peu apres le lancement).

@export var data_path := "res://assets/data/zone_aeroport.json"
@export var min_interval := 120.0
@export var max_interval := 300.0
@export var first_delay := 25.0

const PROPS_SCENE := preload("res://assets/models/props.glb")

var _rng := RandomNumberGenerator.new()
var _a := Vector3.ZERO          # extremite 1 de l'axe de piste (au sol)
var _b := Vector3.ZERO          # extremite 2
var _plane: Node3D
var _snd: AudioStreamPlayer3D
var _beacon: OmniLight3D
var _timer := 0.0
var _state := "attente"
var _t := 0.0
var _dir := Vector3.FORWARD
var _start := Vector3.ZERO
var _speed := 0.0
var _height := 0.0
var _dist := 0.0
var _pitch := 0.0


func _ready() -> void:
	_rng.randomize()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	var best: Array = []
	for r in data.get("runways", []):
		if r.size() > best.size():
			best = r
	if best.size() < 2:
		set_process(false)
		return
	_a = Vector3(float(best[0][0]), 0.0, float(best[0][1]))
	_b = Vector3(float(best[-1][0]), 0.0, float(best[-1][1]))
	var props := PROPS_SCENE.instantiate()
	var mi := props.find_child("veh_avion", true, false) as MeshInstance3D
	_plane = Node3D.new()
	_plane.name = "AvionEnMouvement"
	add_child(_plane)
	if mi:
		var m := MeshInstance3D.new()
		m.mesh = mi.mesh
		_plane.add_child(m)
	props.free()
	_snd = AudioStreamPlayer3D.new()
	_snd.stream = AudioSynth.jet_loop()
	_snd.unit_size = 60.0
	_snd.max_distance = 2500.0
	_snd.volume_db = 6.0
	_plane.add_child(_snd)
	_beacon = OmniLight3D.new()
	_beacon.light_color = Color(1.0, 0.15, 0.1)
	_beacon.omni_range = 12.0
	_beacon.position = Vector3(0, 5.5, 0)
	_plane.add_child(_beacon)
	_plane.visible = false
	_timer = first_delay


func _process(delta: float) -> void:
	match _state:
		"attente":
			_timer -= delta
			if _timer <= 0.0:
				if _rng.randf() < 0.5:
					_begin_takeoff()
				else:
					_begin_landing()
		"decollage":
			_takeoff(delta)
		"atterrissage":
			_landing(delta)
	if _plane.visible:
		var night: float = get_node_or_null("../JourNuit").night if has_node("../JourNuit") else 0.0
		_beacon.light_energy = 3.0 * night if fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.12 else 0.0


func _runway_ends() -> Array:
	# un sens ou l'autre, au hasard (les avions decollent face au vent)
	return [_a, _b] if _rng.randf() < 0.5 else [_b, _a]


func _begin_takeoff() -> void:
	var ends := _runway_ends()
	_start = ends[0]
	_dir = (ends[1] - ends[0]).normalized()
	_speed = 0.0
	_height = 0.0
	_dist = 0.0
	_pitch = 0.0
	_state = "decollage"
	_plane.visible = true
	_snd.play()


func _takeoff(delta: float) -> void:
	# acceleration ~2,8 m/s2 au sol (pleine poussee), rotation vers 75 m/s, montee
	if _height <= 0.0:
		_speed += 2.8 * delta
	else:
		_speed = min(_speed + 1.0 * delta, 95.0)
	_dist += _speed * delta
	if _speed > 75.0:
		_pitch = move_toward(_pitch, deg_to_rad(10.0), delta * 0.12)
		_height += _speed * sin(_pitch * 0.8) * delta
	_place(_start + _dir * _dist + Vector3(0, _height, 0), _pitch)
	_snd.pitch_scale = 0.8 + _speed / 160.0
	if _height > 600.0 or _dist > 9000.0:
		_finish()


func _begin_landing() -> void:
	var ends := _runway_ends()
	# seuil d'atterrissage + 300 m (zone de toucher), approche depuis 7 km a 3 degres
	_dir = (ends[1] - ends[0]).normalized()
	_start = ends[0] + _dir * 300.0
	_dist = -7000.0
	_speed = 72.0
	_state = "atterrissage"
	_plane.visible = true
	_snd.play()


func _landing(delta: float) -> void:
	if _dist < 0.0:
		_speed = move_toward(_speed, 68.0, delta * 0.5)
		_height = -_dist * tan(deg_to_rad(3.0))
		_pitch = deg_to_rad(2.5)  # assiette d'approche, nez legerement haut
	else:
		_height = 0.0
		_pitch = move_toward(_pitch, 0.0, delta * 0.2)
		_speed = move_toward(_speed, 8.0, delta * 2.8)  # inverseurs + freins
	_dist += _speed * delta
	_place(_start + _dir * _dist + Vector3(0, _height, 0), _pitch)
	_snd.pitch_scale = 0.7 + _speed / 180.0
	if _dist > 0.0 and _speed <= 8.5:
		_finish()


func _place(pos: Vector3, pitch: float) -> void:
	var basis := Basis.looking_at(_dir, Vector3.UP) * Basis(Vector3.RIGHT, pitch)
	_plane.global_transform = Transform3D(basis, pos + Vector3(0, 0.12, 0))


func _finish() -> void:
	_state = "attente"
	_plane.visible = false
	_snd.stop()
	_timer = _rng.randf_range(min_interval, max_interval)
