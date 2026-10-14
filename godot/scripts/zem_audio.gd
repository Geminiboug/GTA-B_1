extends Node3D
## Son du zem synthetise en temps reel (aucun fichier audio, aucun droit a gerer).
## Moteur : monocylindre 4 temps (une explosion tous les 2 tours) -> train d'impulsions grave + bruit d'echappement.
## Boite 4 vitesses simulee : le regime monte puis redescend a chaque changement de rapport.
## Klaxon : deux tons aigus, typique des petites motos.

@export var idle_rpm := 1400.0
@export var max_rpm := 8500.0
@export var gear_top_speeds: PackedFloat32Array = [6.0, 11.0, 16.5, 22.0]  # m/s en haut de chaque rapport
@export var volume_db := -6.0

var rpm := 1400.0
var _zem: Node
var _player: AudioStreamPlayer3D
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _rate := 22050.0
var _horn_time := 0.0
var _horn_phase := 0.0
var _rng := RandomNumberGenerator.new()
var _lp := 0.0
var _gear := 0


func _ready() -> void:
	_zem = get_parent()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _rate
	gen.buffer_length = 0.1
	_player = AudioStreamPlayer3D.new()
	_player.stream = gen
	_player.volume_db = volume_db
	_player.unit_size = 6.0
	_player.max_distance = 120.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func horn() -> void:
	_horn_time = 0.45


func _target_rpm() -> float:
	var v: float = abs(_zem.speed)
	var throttle: float = _zem.throttle
	# choix du rapport
	_gear = 0
	while _gear < gear_top_speeds.size() - 1 and v > gear_top_speeds[_gear] * 0.92:
		_gear += 1
	var low: float = 0.0 if _gear == 0 else gear_top_speeds[_gear - 1] * 0.6
	var t: float = clamp((v - low) / (gear_top_speeds[_gear] - low), 0.0, 1.0)
	var r: float = lerp(idle_rpm, max_rpm, t)
	# gaz a l'arret : le moteur monte dans les tours
	return max(r, idle_rpm + throttle * 2500.0 * (1.0 if v < 1.0 else 0.3))


func _process(delta: float) -> void:
	if _playback == null:
		return
	rpm = lerp(rpm, _target_rpm(), 1.0 - exp(-8.0 * delta))
	_horn_time = max(0.0, _horn_time - delta)
	var frames := _playback.get_frames_available()
	# un monocylindre 4 temps explose une fois tous les 2 tours
	var fire_hz := rpm / 60.0 / 2.0
	var load: float = 0.35 + 0.65 * _zem.throttle
	for i in frames:
		_phase = fmod(_phase + fire_hz / _rate, 1.0)
		# impulsion d'explosion qui decroit vite, + harmoniques
		var pulse := exp(-_phase * 9.0) * 2.0 - 0.45
		var body := sin(_phase * TAU) * 0.5 + sin(_phase * TAU * 2.0) * 0.25
		var noise := _rng.randf_range(-1.0, 1.0) * exp(-_phase * 5.0) * 0.6
		var s := (pulse * 0.6 + body * 0.4 + noise * load) * (0.25 + 0.35 * load)
		# filtre passe-bas simple : son d'echappement etouffe
		_lp += (s - _lp) * 0.35
		var out := _lp
		if _horn_time > 0.0:
			_horn_phase += 1.0 / _rate
			var h: float = sign(sin(_horn_phase * TAU * 415.0)) * 0.5 + sign(sin(_horn_phase * TAU * 520.0)) * 0.5
			out += h * 0.18
		_playback.push_frame(Vector2(out, out))
