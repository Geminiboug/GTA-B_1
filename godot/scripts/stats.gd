extends Node
## Progression du personnage (phase 15), facon San Andreas. Valeurs 0..100 dans Partie.perso (sauvegardees) :
## - endurance : monte en courant (footing sur la plage, sprint) ; le sprint dure plus longtemps ;
## - muscles : coups portes et seances a la salle (Gbekpo Fitness, fictive) ; les coups font plus mal ;
## - poids (graisse) : monte en mangeant, baisse en courant et a la salle ; un peu plus lent quand il est haut ;
## - respect : missions reussies et courses de zem ; baisse avec les amendes et les arrestations (phase 17) ;
## - competences qui augmentent a l'usage : zem (km parcourus), voiture (km), tir (balles au but), natation (temps
##   dans l'eau) ; zem plus stable, voiture mieux tenue, visee plus precise.
## Le corps suit : mince, normal ou fort (morphologies existantes), change quand le seuil est franchi.

const DEFAUT := {"endurance": 20.0, "muscles": 20.0, "graisse": 35.0, "respect": 0.0,
	"zem": 10.0, "voiture": 10.0, "tir": 0.0, "natation": 0.0}
const NOMS := {"endurance": "Endurance", "muscles": "Muscles", "graisse": "Poids", "respect": "Respect",
	"zem": "Conduite du zem", "voiture": "Conduite en voiture", "tir": "Tir", "natation": "Natation"}

@export var player_path: NodePath = ^"../Player"
@export var gain_course := 1.0 / 45.0        # point d'endurance par seconde de course (trot ou sprint)
@export var perte_graisse_course := 1.0 / 90.0
@export var graisse_par_repas := 0.04        # par point de sante rendu en mangeant
@export var gain_coup := 0.4                 # muscles par coup porte
@export var gain_zem_km := 4.0
@export var gain_voiture_km := 4.0
@export var gain_tir := 0.5                  # par balle au but
@export var gain_natation := 1.0 / 20.0      # par seconde dans l'eau
@export var respect_mission := 4.0
@export var respect_course := 1.0
@export var respect_amende := 1.5

var _player: CharacterBody3D
var _prev := {}
var _morpho := ""
var _t := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path)
	for k in DEFAUT:
		if not Partie.perso.has(k):
			Partie.perso[k] = DEFAUT[k]
	_prev = {"courses": int(Partie.stats.get("courses", 0)), "livraisons": int(Partie.stats.get("livraisons", 0)),
		"amendes": int(Partie.stats.get("amendes", 0)), "missions": Partie.missions_faites.size(),
		"zem_km": float(Partie.stats.get("distance_zem", 0.0)) / 1000.0, "pos": Vector3.INF}
	appliquer.call_deferred()
	_batir_salle.call_deferred()


func ajouter(cle: String, n: float) -> void:
	var avant := float(Partie.perso.get(cle, DEFAUT[cle]))
	Partie.perso[cle] = clampf(avant + n, 0.0, 100.0)
	# palier franchi : petit message (tous les 10 points), comme dans San Andreas
	if floori(avant / 10.0) != floori(float(Partie.perso[cle]) / 10.0) and cle != "graisse":
		Partie.notifier(tr("%s : %d") % [tr(NOMS[cle]), roundi(float(Partie.perso[cle]))] + (" ▲" if n > 0 else " ▼"))


func v(cle: String) -> float:
	return float(Partie.perso.get(cle, DEFAUT[cle]))


func _physics_process(delta: float) -> void:
	if _player == null or Partie.get("en_jeu") == false:
		return
	var veh: Node3D = _player.get("vehicle")
	var hv := Vector2(_player.velocity.x, _player.velocity.z).length()
	if veh == null and _player.is_on_floor() and hv > 2.6:
		ajouter("endurance", gain_course * delta * (1.5 if float(_player.get("sprint_level")) > 0.0 else 1.0))
		ajouter("graisse", -perte_graisse_course * delta)
	if veh == null and _player.global_position.y < -0.6:
		ajouter("natation", gain_natation * delta)
	if veh and veh.get("kind") == "voiture" and veh.get("has_rider"):
		ajouter("voiture", absf(float(veh.get("speed"))) * delta / 1000.0 * gain_voiture_km)
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	# compteurs de Partie : courses de zem, livraisons, missions, amendes, distance en zem
	var zkm := float(Partie.stats.get("distance_zem", 0.0)) / 1000.0
	if zkm > float(_prev["zem_km"]):
		ajouter("zem", (zkm - float(_prev["zem_km"])) * gain_zem_km)
		_prev["zem_km"] = zkm
	for k in ["courses", "livraisons"]:
		var n := int(Partie.stats.get(k, 0))
		if n > int(_prev[k]):
			ajouter("respect", respect_course * (n - int(_prev[k])))
			_prev[k] = n
	if Partie.missions_faites.size() > int(_prev["missions"]):
		ajouter("respect", respect_mission * (Partie.missions_faites.size() - int(_prev["missions"])))
		_prev["missions"] = Partie.missions_faites.size()
	var am := int(Partie.stats.get("amendes", 0))
	if am > int(_prev["amendes"]):
		ajouter("respect", -respect_amende * (am - int(_prev["amendes"])))
		_prev["amendes"] = am
	appliquer()


func mange(soin: float) -> void:
	## Appele quand le joueur mange (commerce, inventaire).
	ajouter("graisse", soin * graisse_par_repas)


func coup_porte() -> void:
	ajouter("muscles", gain_coup)


func balle_au_but() -> void:
	ajouter("tir", gain_tir)


func seance_salle() -> void:
	## Seance a la salle de sport : muscles et endurance, un peu de poids en moins.
	ajouter("muscles", 3.0)
	ajouter("endurance", 1.0)
	ajouter("graisse", -1.5)


func appliquer() -> void:
	## Effets des statistiques sur le joueur et ses vehicules, et silhouette.
	if _player == null:
		return
	var e := v("endurance") / 100.0
	var g := v("graisse") / 100.0
	_player.set("stamina_drain", 0.085 * lerpf(1.35, 0.5, e) * lerpf(0.9, 1.25, g))
	_player.set("force", lerpf(0.85, 1.6, v("muscles") / 100.0))
	_player.set("sprint_speed", 7.0 * lerpf(1.04, 0.93, clampf((g - 0.3) / 0.7, 0.0, 1.0)))
	var armes := get_node_or_null("../Armes")
	if armes:
		armes.set("precision", lerpf(1.6, 0.6, v("tir") / 100.0))
	var veh: Node3D = _player.get("vehicle")
	if veh and veh.get("kind") == "voiture":
		veh.set("adresse", lerpf(0.94, 1.06, v("voiture") / 100.0))
	elif veh:
		veh.set("adresse", lerpf(0.85, 1.1, v("zem") / 100.0))
	var m := morpho()
	if m != _morpho:
		var premier := _morpho == ""
		_morpho = m
		if _player.has_method("set_corps"):
			_player.set_corps(m)
		if not premier:
			Partie.notifier(tr("Ton corps change : %s") % tr({"mince": "plus mince", "": "silhouette normale", "fort": "plus costaud"}[m]))


func morpho() -> String:
	## "mince", "" (normal) ou "fort" : poids et muscles.
	var g := v("graisse")
	var mu := v("muscles")
	if g > 70.0 or mu > 70.0:
		return "fort"
	if g < 20.0 and mu < 45.0:
		return "mince"
	return ""


# ------------------------------------------------------------------ salle de sport (fictive)
@export var salle := Vector3(220, 0, 40)


func _batir_salle() -> void:
	## Gbekpo Fitness : hangar ouvert au bord de la rue, enseigne, banc et barre ; T pour une seance (1 000 F).
	var carte := Carte.zone()
	var p := salle
	var near: Dictionary = carte.nearest_on_network(Vector2(p.x, p.z)) if carte else {}
	if not near.is_empty():
		var q: Vector2 = near["point"]
		p = Vector3(q.x + 4.0, 0.0, q.y)
	var root := Node3D.new()
	root.name = "SalleDeSport"
	add_child(root)
	root.position = p
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.57, 0.6)
	mat.metallic = 0.5
	for e in [[Vector3(4.0, 0.06, 3.0), Vector3(0, 2.6, 0)], [Vector3(0.1, 2.6, 0.1), Vector3(-1.9, 1.3, -1.4)],
			[Vector3(0.1, 2.6, 0.1), Vector3(1.9, 1.3, -1.4)], [Vector3(0.1, 2.6, 0.1), Vector3(-1.9, 1.3, 1.4)],
			[Vector3(0.1, 2.6, 0.1), Vector3(1.9, 1.3, 1.4)], [Vector3(1.4, 0.45, 0.4), Vector3(0, 0.22, 0)],
			[Vector3(1.6, 0.04, 0.04), Vector3(0, 1.1, 0.3)]]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = e[0]
		mi.mesh = b
		mi.material_override = mat
		mi.position = e[1]
		root.add_child(mi)
	var lab := Label3D.new()
	lab.text = "GBÊKPO FITNESS"
	lab.font_size = 56
	lab.pixel_size = 0.006
	lab.outline_size = 10
	lab.modulate = Color(1, 0.85, 0.3)
	lab.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lab.position = Vector3(0, 3.0, 0)
	root.add_child(lab)
	var com := get_node_or_null("../Commerce")
	if com:
		com.spots.append({"pos": p, "kind": "salle"})
