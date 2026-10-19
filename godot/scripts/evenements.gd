extends Node3D
## Evenements de quartier (phase 20) : chaque jour vers 16 h, un cortege de funerailles avec fanfare traverse le
## quartier (famille en blanc et noir, musiciens devant, au pas), a 60-150 m du joueur ; la fanfare s'entend de loin.
## Marcher a cote du cortege un moment (30 s a moins de 10 m) : respect du quartier.

@export var player_path: NodePath = ^"../Player"
@export var heure := 16.0
@export var marcheurs := 14
@export var vitesse := 0.9                 # m/s : pas lent de cortege
@export var duree_accompagner := 30.0     # s a moins de 10 m du cortege pour le respect

var cortege: Dictionary = {}               # {chemin, d, membres, son, accompagne}
var _player: CharacterBody3D
var _day: Node
var _jour_fait := -1
var _jour := 0
var _h_prec := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_player = get_node_or_null(player_path)
	_day = get_node_or_null("../JourNuit")


func _physics_process(delta: float) -> void:
	if _player == null or _day == null:
		return
	var h := float(_day.get("hour"))
	if h < _h_prec:
		_jour += 1                   # minuit passe
	_h_prec = h
	var jour := _jour
	if cortege.is_empty() and h >= heure and h < heure + 0.5 and _jour_fait != jour:
		_jour_fait = jour
		lancer()
	if not cortege.is_empty():
		_avancer(delta)


func lancer() -> void:
	var carte := Carte.zone()
	var pp := Vector2(_player.global_position.x, _player.global_position.z)
	var a := pp + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60.0, 150.0)
	var b := a + Vector2.from_angle(_rng.randf() * TAU) * 400.0
	var chemin: PackedVector2Array = carte.route(a, b, false)
	if chemin.size() < 2:
		return
	var membres: Array = []
	for i in marcheurs:
		var genre := "femme" if _rng.randf() < 0.55 else "homme"
		var ch := PnjUtil.make(PnjUtil.random_variant(_rng, genre))
		ch.set_script(preload("res://scripts/anim_ctrl.gd"))
		add_child(ch)
		var look := PnjUtil.random_look(ch, _rng)
		# deuil : blanc et noir (tenue des funerailles au Benin), musiciens en uniforme sombre devant
		var blanc := PnjUtil.plain(Color(0.95, 0.95, 0.93))
		var noir := PnjUtil.plain(Color(0.08, 0.08, 0.09))
		look["top"] = noir if i < 4 else blanc
		look["cloth"] = blanc if i % 2 == 0 else noir
		look["legs"] = noir
		PnjUtil.apply(ch, look)
		membres.append(ch)
	var son := AudioStreamPlayer3D.new()
	son.stream = AudioSynth.fanfare_loop()
	son.unit_size = 18.0
	son.max_distance = 220.0
	son.volume_db = -2.0
	add_child(son)
	son.play()
	cortege = {"chemin": chemin, "d": 0.0, "membres": membres, "son": son, "accompagne": 0.0, "fini": false}
	Partie.notifier(tr("Des funérailles passent dans le quartier : on entend la fanfare."))


func _point(chemin: PackedVector2Array, d: float) -> Array:
	## Position et direction a la distance d le long du chemin.
	var acc := 0.0
	for i in chemin.size() - 1:
		var seg := chemin[i].distance_to(chemin[i + 1])
		if acc + seg >= d:
			var t := (d - acc) / maxf(seg, 0.01)
			return [chemin[i].lerp(chemin[i + 1], t), (chemin[i + 1] - chemin[i]).normalized()]
		acc += seg
	return [chemin[-1], Vector2.ZERO]


func _avancer(delta: float) -> void:
	cortege["d"] = float(cortege["d"]) + vitesse * delta
	var chemin: PackedVector2Array = cortege["chemin"]
	var tete: Array = _point(chemin, float(cortege["d"]))
	if (tete[1] as Vector2) == Vector2.ZERO:
		_fin()
		return
	var membres: Array = cortege["membres"]
	for i in membres.size():
		var rang := i / 2
		var p: Array = _point(chemin, maxf(float(cortege["d"]) - rang * 1.4, 0.0))
		var dir: Vector2 = p[1]
		var cote := Vector2(-dir.y, dir.x) * (0.7 if i % 2 == 0 else -0.7)
		var q: Vector2 = (p[0] as Vector2) + cote
		var n: Node3D = membres[i]
		n.global_position = Vector3(q.x, 0.0, q.y)
		if dir != Vector2.ZERO:
			n.rotation.y = atan2(-dir.x, -dir.y)   # face au sens de la marche (meme convention que pedestrians.gd)
		n.set("speed", vitesse)
	var c := (tete[0] as Vector2)
	(cortege["son"] as Node3D).global_position = Vector3(c.x, 1.5, c.y)
	# accompagner le cortege : respect
	var milieu: Node3D = membres[membres.size() / 2]
	if _player.get("vehicle") == null and _player.global_position.distance_to(milieu.global_position) < 10.0:
		cortege["accompagne"] = float(cortege["accompagne"]) + delta
		if float(cortege["accompagne"]) >= duree_accompagner and not cortege["fini"]:
			cortege["fini"] = true
			var st := get_node_or_null("../Stats")
			if st:
				st.ajouter("respect", 4.0)
			Partie.notifier(tr("Tu as accompagné le cortège : la famille te remercie."))


func _fin() -> void:
	for n in cortege["membres"]:
		(n as Node).queue_free()
	(cortege["son"] as Node).queue_free()
	cortege = {}
