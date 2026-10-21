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
	add_to_group("cibles_coups")      # player.gd et armes.gd : le cortege recoit les coups du joueur
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
	# plus de fanfare : le son du cortege etait effrayant (retour d'Olympe du 22/10/2026) ; le noeud reste pour suivre le cortege
	var son := Node3D.new()
	add_child(son)
	cortege = {"chemin": chemin, "d": 0.0, "membres": membres, "son": son, "accompagne": 0.0, "fini": false}
	Partie.notifier(tr("Des funérailles passent dans le quartier."))


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


@export var arret_apres_coup := 8.0     # s : le cortege s'arrete et proteste quand on frappe ou renverse l'un des siens


func player_attack(origin: Vector3, dir: Vector3, coup := 0, _degats := -1.0, portee := 1.6, _arme := false) -> bool:
	## Coup du joueur (player.gd, armes.gd) sur un membre du cortege : il chancelle ou tombe, tout le cortege s'arrete,
	## se tourne vers le joueur et proteste, la police est prevenue.
	if cortege.is_empty():
		return false
	var best: Node3D = null
	var bd := portee
	for n in cortege["membres"]:
		var rel: Vector3 = (n as Node3D).global_position - origin
		rel.y = 0.0
		if rel.length() < bd and rel.normalized().dot(dir) > 0.4:
			bd = rel.length()
			best = n
	if best == null:
		return false
	_toucher(best, coup >= 2 or _rng.randf() < 0.3)
	get_tree().call_group("police", "crime", "agression", best.global_position)
	return true


func _toucher(n: Node3D, tombe: bool) -> void:
	if tombe:
		n.call("play_clips", [["Death01", _rng.randf_range(1.5, 3.0)], ["LayToIdle", 0.0]])
	else:
		n.call("play_clips", [["Hit_Chest", 0.0]])
	cortege["arret"] = arret_apres_coup
	Bulle.say(n, tr(["Eh ! Respecte le deuil !", "Ça ne va pas, non ?", "On enterre notre mère !"][_rng.randi() % 3]))


func _chocs_vehicule() -> void:
	## Le vehicule du joueur qui fonce dans le cortege renverse ceux qu'il touche.
	var v: Node3D = _player.get("vehicle")
	if v == null or absf(float(v.get("speed"))) < 2.0:
		return
	for n in cortege["membres"]:
		var nn := n as Node3D
		if nn.global_position.distance_to(v.global_position) < 2.2 and not nn.get_meta("renverse", false):
			nn.set_meta("renverse", true)
			_toucher(nn, true)
			get_tree().call_group("police", "crime", "agression", nn.global_position)


func _avancer(delta: float) -> void:
	_chocs_vehicule()
	if float(cortege.get("arret", 0.0)) > 0.0:
		# arrete : chacun se tourne vers le joueur (sauf ceux a terre, dont le clip joue)
		cortege["arret"] = float(cortege["arret"]) - delta
		for n in cortege["membres"]:
			var nn := n as Node3D
			nn.set("speed", 0.0)
			if not nn.call("playing_clip"):
				var d := _player.global_position - nn.global_position
				nn.rotation.y = lerp_angle(nn.rotation.y, atan2(-d.x, -d.z), 1.0 - exp(-4.0 * delta))
		if float(cortege["arret"]) <= 0.0:
			for n in cortege["membres"]:
				(n as Node).remove_meta("renverse")
		return
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
