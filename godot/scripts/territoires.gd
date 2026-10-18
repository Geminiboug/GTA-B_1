extends Node3D
## Territoires des zems (phase 17). Noms de syndicats fictifs ; quartiers reels de Cotonou.
## - Stationnements de zems (carrefours, marches, aeroport), chacun tenu par un syndicat rival ou libre ; pancarte
##   aux couleurs du proprietaire, zems gares, repere carre sur la mini-carte.
## - Prendre un stationnement : sur place, T : "Negocier" (si le respect suffit, on paie le syndicat) ou "Defier"
##   (trois zemidjans du syndicat se battent ; tous a terre en moins de 90 s : il est a toi).
## - Revenus passifs : chaque stationnement tenu rapporte toutes les heures de jeu ; respect du quartier en plus.
## - Attaques : de temps en temps un syndicat attaque un de tes stationnements ; si tu n'y vas pas les mettre a terre
##   dans les 3 minutes, il est perdu.
## - Bande de Sena : avec assez de respect, B a un stationnement tenu recrute un zemidjan (jusqu a 3) qui te suit a pied et se
##   battent a tes cotes ; G (manette : croix haut) les fait suivre ou attendre.
## - Dans un quartier tenu, les passants saluent le patron.

var SYNDICATS := {
	"szu": {"nom": "Syndicat des Zems Unis", "couleur": Color(1.0, 0.55, 0.0) if Partie.options.get("daltonisme", false) else Color(0.85, 0.2, 0.15)},
	"lions": {"nom": "Les Lions du Littoral", "couleur": Color(0.15, 0.35, 0.85)},
	"joueur": {"nom": "La bande de Sena", "couleur": Color(0.95, 0.8, 0.1)},
}
const STATIONNEMENTS := [
	{"id": "aeroport", "nom": "Stationnement de l'aéroport", "pos": Vector3(150, 0, 330), "proprio": "szu"},
	{"id": "cadjehoun", "nom": "Carrefour de Cadjehoue", "pos": Vector3(60, 0, -60), "proprio": "lions"},
	{"id": "haie_vive", "nom": "Carrefour de Haie Verte", "pos": Vector3(260, 0, -280), "proprio": "szu"},
	{"id": "marche", "nom": "Marché de Cadjehoue", "pos": Vector3(-60, 0, 40), "proprio": "lions"},
	{"id": "plage", "nom": "Route des Filets", "pos": Vector3(-140, 0, 440), "proprio": ""},
	{"id": "cotodji", "nom": "Carrefour de Cotodji", "pos": Vector3(320, 0, -120), "proprio": "szu"},
]

@export var player_path: NodePath = ^"../Player"
@export var revenu_horaire := 1500             # FCFA par stationnement tenu et par heure de jeu
@export var respect_negociation := 35.0        # respect minimum pour negocier
@export var prix_negociation := 50000
@export var duree_defi := 90.0                 # s
@export var delai_attaque := 180.0             # s pour defendre un stationnement attaque
@export var attaque_toutes := 900.0            # s (en moyenne) entre deux attaques
@export var respect_bande := 25.0              # respect pour qu'un zemidjan rejoigne la bande
@export var bande_max := 3

var _player: CharacterBody3D
var _peds: Node
var _hud: Node
var _day: Node
var _defi: Dictionary = {}          # {id, t, rivaux: [walkers]}
var _attaque: Dictionary = {}       # {id, t, rivaux}
var _attaque_t := 0.0
var _heure_prec := -1
var _bande: Array = []              # zemidjans qui suivent : [{node, anim}]
var _bande_suit := true
var _salut_cd := 0.0
var _r_appuye := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("options")
	_rng.randomize()
	_player = get_node_or_null(player_path)
	_peds = get_node_or_null("../Pietons")
	_hud = get_node_or_null("../HUD")
	_day = get_node_or_null("../JourNuit")
	if not InputMap.has_action("bande"):
		InputMap.add_action("bande")
		var k := InputEventKey.new()
		k.physical_keycode = KEY_G
		InputMap.action_add_event("bande", k)
	_attaque_t = attaque_toutes
	Partie.chantier_differe(_placer)   # etape de la mise en place etalee pendant le chargement


func proprio(id: String) -> String:
	## Proprietaire actuel (Partie.drapeaux["territoires"], sinon celui du depart).
	var t: Dictionary = Partie.drapeaux.get("territoires", {})
	if t.has(id):
		return t[id]
	for s in STATIONNEMENTS:
		if s["id"] == id:
			return s["proprio"]
	return ""


func _set_proprio(id: String, qui: String) -> void:
	var t: Dictionary = Partie.drapeaux.get("territoires", {})
	t[id] = qui
	Partie.drapeaux["territoires"] = t
	_pancarte(id)


func tenus() -> Array:
	var out: Array = []
	for s in STATIONNEMENTS:
		if proprio(s["id"]) == "joueur":
			out.append(s["id"])
	return out


# ------------------------------------------------------------------ monde
var _pos := {}


func _placer() -> void:
	var carte := Carte.zone()
	for s in STATIONNEMENTS:
		var p: Vector3 = s["pos"]
		var near: Dictionary = carte.nearest_on_network(Vector2(p.x, p.z)) if carte else {}
		if not near.is_empty():
			var q: Vector2 = near["point"]
			p = Vector3(q.x + 3.0, 0.0, q.y)
		_pos[s["id"]] = p
		var root := Node3D.new()
		root.name = "Stationnement_" + s["id"]
		add_child(root)
		root.global_position = p
		root.add_to_group("carte_repere")
		var lab := Label3D.new()
		lab.name = "Pancarte"
		lab.font_size = 40
		lab.pixel_size = 0.006
		lab.outline_size = 10
		lab.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lab.position = Vector3(0, 2.4, 0)
		root.add_child(lab)
		var poteau := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.04
		c.bottom_radius = 0.04
		c.height = 2.2
		poteau.mesh = c
		poteau.position.y = 1.1
		root.add_child(poteau)
		# zems gares, en rang, au bord de la rue
		var zem_scene := load("res://assets/models/veh_zem.glb") as PackedScene
		for i in 3:
			var z := zem_scene.instantiate() as Node3D
			z.position = Vector3(1.2 + i * 0.9, 0, 1.5)
			z.rotation.y = PI * 0.5
			root.add_child(z)
		_pancarte(s["id"])


func options_changees() -> void:
	## Mode daltonien change dans le menu : couleur du syndicat rouge et pancartes, sans relancer le jeu.
	SYNDICATS["szu"]["couleur"] = Color(1.0, 0.55, 0.0) if Partie.options.get("daltonisme", false) else Color(0.85, 0.2, 0.15)
	for s in STATIONNEMENTS:
		_pancarte(s["id"])


func _pancarte(id: String) -> void:
	var root := get_node_or_null("Stationnement_" + id)
	if root == null:
		return
	var qui := proprio(id)
	var lab := root.get_node("Pancarte") as Label3D
	var nom := ""
	for s in STATIONNEMENTS:
		if s["id"] == id:
			nom = s["nom"]
	lab.text = "%s\n%s" % [nom, SYNDICATS[qui]["nom"] if qui != "" else tr("Libre")]
	var col: Color = SYNDICATS[qui]["couleur"] if qui != "" else Color(0.9, 0.9, 0.9)
	lab.modulate = col
	root.set_meta("couleur", col)


# ------------------------------------------------------------------ boucle
func _physics_process(delta: float) -> void:
	if _player == null or Partie.get("en_jeu") == false:
		return
	_revenus()
	_bande_maj(delta)
	_salut_cd = maxf(0.0, _salut_cd - delta)
	if not _defi.is_empty():
		_suivre_combat(_defi, delta, true)
	elif not _attaque.is_empty():
		_suivre_combat(_attaque, delta, false)
	else:
		_attaque_t -= delta
		if _attaque_t <= 0.0:
			_attaque_t = attaque_toutes * _rng.randf_range(0.6, 1.4)
			_lancer_attaque()
	var id := _proche()
	if id == "" or _player.get("vehicle") != null or not _defi.is_empty():
		return
	var qui := proprio(id)
	if qui == "joueur":
		if _salut_cd <= 0.0 and _peds:
			_salut_cd = 25.0
			_saluer()
		return
	if _hud and _hud.has_method("show_hint"):
		var neg := float(Partie.perso.get("respect", 0.0)) >= respect_negociation and qui != ""
		_hud.show_hint(tr("T : défier %s") % tr(SYNDICATS[qui]["nom"] if qui != "" else "le quartier") +
			(tr("   N : négocier (%s)") % Partie.fcfa(prix_negociation) if neg else ""))
	if Input.is_action_just_pressed("parler"):
		_lancer_defi(id)
	elif Input.is_key_pressed(KEY_N) and qui != "" and float(Partie.perso.get("respect", 0.0)) >= respect_negociation:
		if Partie.payer(prix_negociation, "Négociation du stationnement"):
			_set_proprio(id, "joueur")
			Partie.notifier(tr("Accord conclu : le stationnement est à toi."))


func _proche() -> String:
	for id in _pos:
		if (_pos[id] as Vector3).distance_to(_player.global_position) < 6.0:
			return id
	return ""


func _rivaux(at: Vector3, n: int) -> Array:
	## Trois zemidjans du syndicat : les passants les plus proches prennent ce role (bagarreurs, en colere).
	var out: Array = []
	if _peds == null:
		return out
	var libres: Array = (_peds.get("_walkers") as Array).filter(func(w: Dictionary) -> bool: return w["state"] == "walk")
	libres.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["pos"] as Vector3).distance_to(at) < (b["pos"] as Vector3).distance_to(at))
	for i in mini(n, libres.size()):
		var w: Dictionary = libres[i]
		w["pos"] = at + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
		w["pos"].y = _peds.GROUND_Y
		w["caractere"] = "bagarreur"
		w["pv"] = 100.0
		w["state"] = "fight"
		w["state_t"] = 0.0
		out.append(w)
	return out


func _lancer_defi(id: String) -> void:
	_defi = {"id": id, "t": duree_defi, "rivaux": _rivaux(_pos[id], 3)}
	Partie.notifier(tr("Défi lancé : mets les trois zemidjans à terre !"))


func _lancer_attaque() -> void:
	var mes := tenus()
	if mes.is_empty():
		return
	var id: String = mes[_rng.randi() % mes.size()]
	var qui: String = ["szu", "lions"][_rng.randi() % 2]
	_attaque = {"id": id, "t": delai_attaque, "qui": qui, "rivaux": [], "arrive": false}
	Partie.notifier(tr("%s attaque ton stationnement : %s ! Tu as 3 minutes.") % [tr(SYNDICATS[qui]["nom"]), _nom(id)])
	var hc := get_node_or_null("../HUD")
	if hc and "waypoint" in hc:
		hc.set("waypoint", Vector2(_pos[id].x, _pos[id].z))
		hc.set("has_waypoint", true)


func _nom(id: String) -> String:
	for s in STATIONNEMENTS:
		if s["id"] == id:
			return tr(s["nom"])
	return id


func _suivre_combat(c: Dictionary, delta: float, defi: bool) -> void:
	c["t"] = float(c["t"]) - delta
	var p: Vector3 = _pos[c["id"]]
	if not defi and not c["arrive"] and _player.global_position.distance_to(p) < 30.0:
		c["arrive"] = true
		c["rivaux"] = _rivaux(p, 3)
	var tous_a_terre := (c["rivaux"] as Array).size() > 0
	for w in c["rivaux"]:
		if not (w["state"] == "down" or float(w.get("pv", 100.0)) <= 0.0):
			tous_a_terre = false
	if tous_a_terre:
		_set_proprio(c["id"], "joueur")
		Partie.notifier(tr("%s est à toi !") % _nom(c["id"]) if defi else tr("Attaque repoussée : %s reste à toi.") % _nom(c["id"]))
		var st := get_node_or_null("../Stats")
		if st:
			st.ajouter("respect", 5.0 if defi else 3.0)
		_fin_combat(defi)
	elif float(c["t"]) <= 0.0:
		if defi:
			Partie.notifier(tr("Défi perdu : le syndicat garde le stationnement."))
		else:
			_set_proprio(c["id"], c.get("qui", "szu"))
			Partie.notifier(tr("Tu as perdu %s.") % _nom(c["id"]))
		_fin_combat(defi)


func _fin_combat(defi: bool) -> void:
	for w in (_defi if defi else _attaque).get("rivaux", []):
		if w["state"] == "fight":
			w["state"] = "flee"
			w["flee_from"] = Vector2(_player.global_position.x, _player.global_position.z)
			w["flee_time"] = 4.0
	if defi:
		_defi = {}
	else:
		_attaque = {}


func _revenus() -> void:
	if _day == null:
		return
	var h := int(float(_day.get("hour")))
	if _heure_prec < 0:
		_heure_prec = h
		return
	if h != _heure_prec:
		_heure_prec = h
		var n := tenus().size()
		if n > 0:
			Partie.gagner(revenu_horaire * n, "Stationnements de zems")


func _saluer() -> void:
	var best: Dictionary = {}
	var bd := 12.0
	for w in _peds.get("_walkers"):
		var d := (w["pos"] as Vector3).distance_to(_player.global_position)
		if d < bd and w["state"] == "walk":
			bd = d
			best = w
	if not best.is_empty() and best.get("node"):
		Bulle.say(best["node"], ["Salut le boss !", "Bonne arrivée, chef !", "Respect, grand frère !"][_rng.randi() % 3], 2.0, 2.0)


# ------------------------------------------------------------------ bande de Sena
func recruter() -> bool:
	## Pipo envoie un zemidjan dans la bande (respect suffisant, au plus bande_max).
	if _bande.size() >= bande_max or float(Partie.perso.get("respect", 0.0)) < respect_bande * (_bande.size() + 1):
		return false
	var ch := PnjUtil.make("homme")
	ch.set_script(preload("res://scripts/anim_ctrl.gd"))
	add_child(ch)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	PnjUtil.apply(ch, PnjUtil.random_look(ch, rng, "zem"))
	ch.global_position = _player.global_position + Vector3(rng.randf_range(-2, 2), 0, 2.0)
	_bande.append({"node": ch, "vit": Vector3.ZERO})
	Partie.notifier(tr("Un zemidjan rejoint ta bande (%d / %d).") % [_bande.size(), bande_max])
	return true


func _bande_maj(delta: float) -> void:
	if Input.is_action_just_pressed("bande") and not _bande.is_empty():
		_bande_suit = not _bande_suit
		Partie.notifier(tr("La bande te suit.") if _bande_suit else tr("La bande t'attend ici."))
	# recrutement : a un stationnement tenu, R (respect suffisant) ; la bande revient a chaque partie chargee
	var id := _proche()
	if id != "" and proprio(id) == "joueur" and _bande.size() < bande_max and _player.get("vehicle") == null:
		if float(Partie.perso.get("respect", 0.0)) >= respect_bande * (_bande.size() + 1):
			if _hud and _hud.has_method("show_hint"):
				_hud.show_hint(tr("B : recruter un zemidjan dans ta bande (%d / %d)") % [_bande.size(), bande_max])
			if Input.is_key_pressed(KEY_B) and not _r_appuye:
				if recruter():
					Partie.drapeaux["bande"] = _bande.size()
		_r_appuye = Input.is_key_pressed(KEY_B)
	elif _bande.size() < int(Partie.drapeaux.get("bande", 0)):
		recruter()
	for i in _bande.size():
		var b: Dictionary = _bande[i]
		var n: Node3D = b["node"]
		if not is_instance_valid(n):
			continue
		var cible := _player.global_position + _player.global_transform.basis.z * (1.6 + i * 0.9) + Vector3(-1.0 + i, 0, 0)
		var to := cible - n.global_position
		to.y = 0.0
		var d := to.length()
		var vit := 0.0
		if _bande_suit and d > 1.2:
			vit = clampf(d * 1.5, 0.0, 6.5)
			n.global_position += to.normalized() * vit * delta
			n.rotation.y = atan2(-to.x, -to.z) + PI
		n.global_position.y = _player.global_position.y if _player.is_on_floor() else n.global_position.y
		n.set("speed", vit)
		# bagarre : un rival en colere a portee prend un coup de temps en temps
		b["coup"] = float(b.get("coup", 0.0)) - delta
		if float(b["coup"]) <= 0.0 and _peds:
			for w in _peds.get("_walkers"):
				if w["state"] == "fight" and (w["pos"] as Vector3).distance_to(n.global_position) < 1.8:
					b["coup"] = 1.2
					var dir: Vector3 = ((w["pos"] as Vector3) - n.global_position).normalized()
					if n.has_method("play_clips"):
						n.play_clips([["Punch_Cross", 0.0]], true)
					_peds.player_attack(n.global_position, dir, 1, 22.0, 2.0)
					break
