extends Node3D
## Ambiance sonore de la zone (tout est synthetise par AudioSynth, aucun fichier audio) :
## - ressac de l'ocean : sources 3D reparties le long du trait de cote reel ;
## - rumeur de la ville : fond sonore discret ;
## - oiseaux le jour (gazouillis autour du joueur), grillons et insectes la nuit.

@export var wave_spacing := 110.0
@export var day_night_path: NodePath = ^"../JourNuit"

var _city: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _birds: Array[AudioStreamPlayer3D] = []
var _bird_timer := 2.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Partie.chantier(_construire)   # sons synthetises : etape de la mise en place etalee pendant le chargement


func _construire() -> void:
	var data: Dictionary = Carte.zone().data
	var waves := AudioSynth.vagues_loop()
	var coast: Array = data.get("coast", [])
	var acc := 0.0
	var count := 0
	for i in range(coast.size() - 1):
		var a := Vector3(float(coast[i][0]), 0.0, float(coast[i][1]))
		var b := Vector3(float(coast[i + 1][0]), 0.0, float(coast[i + 1][1]))
		var seg := a.distance_to(b)
		while acc < seg:
			var p := a.lerp(b, acc / max(seg, 0.001))
			if abs(p.x) < 760.0:
				var s := AudioStreamPlayer3D.new()
				s.stream = waves
				s.unit_size = 25.0
				s.max_distance = 420.0
				s.volume_db = -2.0
				s.pitch_scale = _rng.randf_range(0.9, 1.1)
				s.position = p
				add_child(s)
				s.play(_rng.randf_range(0.0, 20.0))  # desynchronise : pas d'effet d'echo entre les sources
				count += 1
			acc += wave_spacing
		acc -= seg
	_city = AudioStreamPlayer.new()
	_city.stream = AudioSynth.ville_loop()
	_city.volume_db = -22.0
	add_child(_city)
	_city.play()
	_crickets = AudioStreamPlayer.new()
	_crickets.stream = AudioSynth.grillons_loop()
	_crickets.volume_db = -80.0
	add_child(_crickets)
	_crickets.play()
	for i in 3:
		var bp := AudioStreamPlayer3D.new()
		bp.unit_size = 10.0
		bp.max_distance = 90.0
		bp.volume_db = -6.0
		add_child(bp)
		_birds.append(bp)
	print("Ambiance : %d sources de ressac le long de la cote" % count)


func _process(delta: float) -> void:
	var dn := get_node_or_null(day_night_path)
	var night: float = dn.night if dn else 0.0
	_crickets.volume_db = linear_to_db(max(night, 0.0001)) - 12.0
	_city.volume_db = -22.0 - 6.0 * night
	# oiseaux : de jour, un gazouillis toutes les quelques secondes, dans un arbre proche du joueur
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = _rng.randf_range(1.5, 6.0)
		if night < 0.3:
			var cam := get_viewport().get_camera_3d()
			if cam:
				var bp := _birds[_rng.randi() % _birds.size()]
				if not bp.playing:
					bp.stream = AudioSynth.oiseau()
					var ang := _rng.randf_range(0.0, TAU)
					bp.global_position = cam.global_position + Vector3(cos(ang), 0.0, sin(ang)) * _rng.randf_range(10.0, 35.0) + Vector3(0, 6, 0)
					bp.pitch_scale = _rng.randf_range(0.85, 1.25)
					bp.play()
