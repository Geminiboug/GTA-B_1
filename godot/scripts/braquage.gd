extends Node
## Braquage des commerces : arme a feu en main et en joue, a moins de 3,5 m d'une caisse (supermarche, cafe), d'un maquis
## ou de la quincaillerie, E lance le braquage. Il faut tenir en joue pendant quelques secondes sans s'eloigner ;
## le butin depend du lieu. Le delit alerte la police (police.gd, delit "braquage", niveau +3). Plus il y a de monde
## autour, plus il y a de temoins : la police est prevenue tout de suite, et la fuite est plus dure.
## Un lieu braque ne se laisse pas braquer a nouveau avant plusieurs minutes. Les lieux viennent de scripts/commerce.gd.

@export var portee := 3.5            # m
@export var duree := 5.0             # s a tenir en joue
@export var distance_max := 6.0      # m : au-dela, le braquage echoue
@export var recharge := 480.0        # s avant de pouvoir braquer le meme lieu
@export var temoins_alerte := 5      # passants proches a partir desquels la police est alertee sans delai
@export var rayon_temoins := 30.0
@export var rayon_panique := 18.0     # m : les passants dans ce rayon s'enfuient au debut du braquage
@export var butin := {"caisse": 120000, "cafe": 45000, "maquis": 30000, "quincaillerie": 70000}   # FCFA moyens

const NOMS := {"caisse": "la caisse", "cafe": "le café", "maquis": "le maquis", "quincaillerie": "la quincaillerie"}

var _player: Node3D
var _commerce: Node
var _hud: Node
var _rng := RandomNumberGenerator.new()
var _en_cours := {}                  # lieu en train d'etre braque, vide sinon
var _t := 0.0
var _cd := {}                        # position du lieu (Vector3i) -> temps de jeu a partir duquel il est a nouveau braquable
var _horloge := 0.0
var temoins := 0                     # passants proches au debut du dernier braquage (lu par les tests)


func _ready() -> void:
	_rng.randomize()
	_commerce = get_parent()
	_player = _commerce.get_node_or_null("../Player")
	_hud = _commerce.get_node_or_null("../HUD")


func _cle(s: Dictionary) -> Vector3i:
	var p: Vector3 = s["pos"]
	return Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))


func lieu_proche(p: Vector3) -> Dictionary:
	var best := {}
	var bd := portee
	for s in _commerce.spots:
		if not NOMS.has(s["kind"]):
			continue
		var d := Vector2(p.x - s["pos"].x, p.z - s["pos"].z).length()
		if d < bd and absf(p.y - s["pos"].y) < 2.5:
			bd = d
			best = s
	return best


func peut_braquer(s: Dictionary) -> bool:
	return not s.is_empty() and _horloge >= float(_cd.get(_cle(s), 0.0))


func _physics_process(delta: float) -> void:
	_horloge += delta
	if _player == null or _commerce == null:
		return
	if not _en_cours.is_empty():
		_suivre(delta)
		return
	if _player.get("vehicle") != null or not bool(_player.get("arme_feu")) or not bool(_player.get("visee")):
		return
	var s := lieu_proche(_player.global_position)
	if s.is_empty():
		return
	if not peut_braquer(s):
		return
	if _hud and _hud.has_method("show_hint"):
		_hud.show_hint("E : braquer %s" % NOMS[s["kind"]])
	if Input.is_action_just_pressed("interact"):
		demarrer(s)


func demarrer(s: Dictionary) -> void:
	_en_cours = s
	_t = 0.0
	temoins = _compter_temoins()
	Partie.notifier("Braquage de %s : tiens-les en joue (%d s) sans t'éloigner." % [NOMS[s["kind"]], roundi(duree)])
	var peds := _commerce.get_node_or_null("../Pietons")
	if peds and peds.has_method("_panique"):
		var c: Vector3 = s["pos"]
		peds.call("_panique", Vector2(c.x, c.z), rayon_panique)     # les passants proches fuient en criant
	get_tree().call_group("police", "crime", "braquage", s["pos"])
	if temoins >= temoins_alerte:
		for pol in get_tree().get_nodes_in_group("police"):
			if pol.get("appel_t") != null:
				pol.set("appel_t", 0.0)           # beaucoup de monde : la police est appelee tout de suite
		Partie.notifier("Trop de témoins : la police est prévenue.")


func _compter_temoins() -> int:
	var peds := _commerce.get_node_or_null("../Pietons")
	if peds == null or not "_walkers" in peds:
		return 0
	var n := 0
	var c: Vector3 = _en_cours["pos"]
	for w in peds._walkers:
		if w.get("far", false) or w["state"] == "assis":
			continue
		var p: Vector3 = w["pos"]
		if Vector2(p.x - c.x, p.z - c.z).length() < rayon_temoins:
			n += 1
	return n


func _suivre(delta: float) -> void:
	if _en_cours.is_empty():
		return
	var c: Vector3 = _en_cours["pos"]
	var loin := Vector2(_player.global_position.x - c.x, _player.global_position.z - c.z).length() > distance_max
	if loin or not bool(_player.get("visee")) or _player.get("vehicle") != null:
		Partie.notifier("Braquage raté : tu as lâché prise.")
		_cd[_cle(_en_cours)] = _horloge + recharge * 0.5
		_en_cours = {}
		return
	_t += delta
	if _hud and _hud.has_method("show_hint"):
		_hud.show_hint("Braquage en cours... %d" % ceili(duree - _t))
	if _t >= duree:
		var base := float(butin.get(_en_cours["kind"], 20000))
		var gain := roundi(base * _rng.randf_range(0.6, 1.4) * (1.0 + 0.04 * minf(temoins, 10.0)) / 100.0) * 100
		Partie.gagner(gain, "Braquage")
		_cd[_cle(_en_cours)] = _horloge + recharge
		_en_cours = {}
