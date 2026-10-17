extends Node3D
## Personnalisation et proprietes (phase 16). Tous les noms sont fictifs.
## - Tenues : tailleur Chez Dossou (boubou en wax sur mesure), friperie (t-shirts, jean), boutique de maillots de clubs
##   fictifs, chaussures (sandales, baskets) ; coiffeur Salon Élégance (coupes, afro, tresses, rase).
##   La tenue choisie (Partie.tenue) est gardee dans la sauvegarde, avec la garde-robe (tout ce qui a ete achete).
## - Garage de Tonton Codjo : reparation, peinture d'une nouvelle couleur, klaxon deux tons pour le vehicule gare devant.
## - Proprietes (Agence Immo Gbekpo) : chambre ou appartement achetes, planques et points de sauvegarde (E pour
##   dormir) ; le vehicule gare devant y reste d'une partie a l'autre.
## - Semer la police : repeindre son vehicule (plus recherche si aucun policier ne voit), changer de tenue (une etoile
##   de moins si aucun policier ne voit), se cacher au marche (scripts/police.gd : la police perd la trace trois fois
##   plus vite au milieu des etals).

const BOUTIQUES := {
	"tailleur": {"nom": "Chez Dossou, tailleur", "pos": Vector3(90, 0, -40)},
	"friperie": {"nom": "Friperie du Carrefour", "pos": Vector3(180, 0, -150)},
	"maillots": {"nom": "Maillots Sport 229", "pos": Vector3(250, 0, -80)},
	"coiffeur": {"nom": "Salon Élégance", "pos": Vector3(120, 0, 60)},
	"garage": {"nom": "Garage de Tonton Codjo", "pos": Vector3(30, 0, -220)},
	"agence": {"nom": "Agence Immo Gbêkpo", "pos": Vector3(200, 0, 20)},
}
const PROPRIETES := {
	"chambre": {"nom": "Chambre à Cadjehoue", "prix": 150000, "pos": Vector3(-40, 0, 140)},
	"appartement": {"nom": "Appartement à Haie Verte", "prix": 600000, "pos": Vector3(260, 0, -320)},
}
const CLUBS := ["Étoile de Gbê Town", "Racing Lagune", "Atlantique FC", "Union Sportive du Littoral", "Avenir de Cotodji"]
const TSHIRTS := {"rouge": Color(0.85, 0.15, 0.1), "bleu": Color(0.1, 0.35, 0.75), "blanc": Color(0.95, 0.95, 0.92),
	"vert": Color(0.1, 0.55, 0.3), "jaune": Color(0.95, 0.8, 0.15)}
const COIFFURES := {"Coupe courte": "chr_cheveux", "Afro": "chr_afro", "Tresses": "chr_tresse", "Crâne rasé": ""}
const PEINTURES := [Color(0.75, 0.1, 0.1), Color(0.1, 0.25, 0.6), Color(0.95, 0.95, 0.93), Color(0.08, 0.08, 0.09),
	Color(0.15, 0.45, 0.2), Color(0.95, 0.75, 0.15), Color(0.55, 0.55, 0.58)]

@export var player_path: NodePath = ^"../Player"
@export var portee_garage := 9.0        # m : vehicule gare devant le garage ou la propriete

var _player: CharacterBody3D
var _points := {}                 # cle -> position (boutiques, proprietes)
var _hud: Node
var _sleep_cd := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null("../HUD")
	var com := get_node_or_null("../Commerce")
	if com:
		var t: Array = []
		for i in Partie_wax_count():
			t.append(["Boubou wax sur mesure (motif %d)" % (i + 1), 6000 + 2000 * i, 0])
		com.ARTICLES["tailleur"] = t
		var f: Array = []
		for c in TSHIRTS:
			f.append(["T-shirt %s" % c, 1500, 0])
		f.append(["Jean délavé", 3000, 0])
		f.append(["Sandales", 1500, 0])
		f.append(["Baskets", 8000, 0])
		com.ARTICLES["friperie"] = f
		var m: Array = []
		for c in CLUBS:
			m.append(["Maillot %s" % c, 4000, 0])
		com.ARTICLES["maillots"] = m
		var h: Array = []
		for c in COIFFURES:
			h.append([c, 1000 if c != "Tresses" else 5000, 0])
		com.ARTICLES["coiffeur"] = h
		com.ARTICLES["garage"] = [["Réparation complète", 15000, 0], ["Peinture d'une nouvelle couleur", 25000, 0],
			["Klaxon deux tons", 5000, 0]]
		var a: Array = []
		for k in PROPRIETES:
			a.append([PROPRIETES[k]["nom"], PROPRIETES[k]["prix"], 0])
		com.ARTICLES["agence"] = a
		for k in BOUTIQUES:
			com.NOMS[k] = BOUTIQUES[k]["nom"]
	_placer.call_deferred()
	if _player and _player.has_signal("modele_change"):
		_player.connect("modele_change", _habiller_si_besoin)


func Partie_wax_count() -> int:
	return mini(PnjUtil.WAX_PALETTES.size(), 4)


func _placer() -> void:
	## Boutiques et proprietes au bord de la rue la plus proche : auvent, enseigne ; points d'achat du commerce.
	var com := get_node_or_null("../Commerce")
	var carte := Carte.zone()
	var tout := {}
	for k in BOUTIQUES:
		tout[k] = [BOUTIQUES[k]["pos"], BOUTIQUES[k]["nom"]]
	for k in PROPRIETES:
		tout["prop_" + k] = [PROPRIETES[k]["pos"], PROPRIETES[k]["nom"]]
	for k in tout:
		var p: Vector3 = tout[k][0]
		var near: Dictionary = carte.nearest_on_network(Vector2(p.x, p.z)) if carte else {}
		if not near.is_empty():
			var q: Vector2 = near["point"]
			p = Vector3(q.x + 4.0, 0.0, q.y + 1.5)
		_points[k] = p
		_enseigne(k, p, String(tout[k][1]))
		if com and not String(k).begins_with("prop_"):
			com.spots.append({"pos": p, "kind": k})
	_garer_vehicules_sauves()


func _enseigne(k: String, p: Vector3, nom: String) -> void:
	var root := Node3D.new()
	root.name = "Enseigne_" + k
	add_child(root)
	root.global_position = p
	var toit := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(2.6, 0.06, 1.6)
	toit.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.45, 0.7) if not k.begins_with("prop_") else Color(0.55, 0.35, 0.2)
	toit.material_override = m
	toit.position = Vector3(0, 2.4, 0)
	root.add_child(toit)
	for x in [-1.2, 1.2]:
		var pot := MeshInstance3D.new()
		var c := BoxMesh.new()
		c.size = Vector3(0.08, 2.4, 0.08)
		pot.mesh = c
		pot.position = Vector3(x, 1.2, -0.7)
		root.add_child(pot)
	var lab := Label3D.new()
	lab.text = nom.to_upper() if not k.begins_with("prop_") else nom + ("  ✓" if _possede(k.trim_prefix("prop_")) else "  —  à vendre")
	lab.name = "Nom"
	lab.font_size = 44
	lab.pixel_size = 0.006
	lab.outline_size = 10
	lab.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lab.position = Vector3(0, 2.75, 0)
	root.add_child(lab)


func _possede(k: String) -> bool:
	return (Partie.drapeaux.get("proprietes", []) as Array).has(k)


# ------------------------------------------------------------------ achats (appele par scripts/commerce.gd)
func gere(kind: String) -> bool:
	return BOUTIQUES.has(kind)


func achat(kind: String, i: int) -> bool:
	## Applique l'article i de la boutique ; renvoie faux s'il n'a pas pu etre applique (rien n'est alors facture).
	var nom: String = (get_node("../Commerce").ARTICLES[kind] as Array)[i][0]
	var t: Dictionary = Partie.tenue
	match kind:
		"tailleur":
			t["style"] = "boubou"
			t["wax"] = i
		"friperie":
			if nom.begins_with("T-shirt"):
				t["style"] = "tshirt"
				var c: Color = TSHIRTS[nom.trim_prefix("T-shirt ")]
				t["haut"] = [c.r, c.g, c.b]
			elif nom == "Jean délavé":
				t["bas"] = [0.32, 0.42, 0.58]
			else:
				t["chaussures"] = "chr_semelle" if nom == "Sandales" else "chr_chaussures"
		"maillots":
			t["style"] = "maillot"
			t["club"] = i
		"coiffeur":
			t["coiffure"] = COIFFURES[nom]
		"garage":
			return _garage(i)
		"agence":
			return _acheter_propriete(PROPRIETES.keys()[i])
	var gr: Array = Partie.drapeaux.get("garde_robe", [])
	if not gr.has(nom):
		gr.append(nom)
	Partie.drapeaux["garde_robe"] = gr
	habiller()
	# nouvelle tenue sans policier en vue : une etoile de moins
	if Partie.recherche > 0 and not Partie.police_voit and kind != "coiffeur":
		Partie.set_recherche(Partie.recherche - 1)
		Partie.notifier(tr("Nouvelle tenue : la police ne te reconnaît plus aussi bien."))
	return true


func habiller() -> void:
	## Applique Partie.tenue au modele du joueur.
	if _player == null:
		return
	var m: Node = _player.get_node_or_null("Body/Model")
	if m == null:
		return
	PnjUtil.apply(m, look(String(_player.get("genre"))))


func _habiller_si_besoin() -> void:
	if not Partie.tenue.is_empty():
		habiller.call_deferred()


func look(genre: String) -> Dictionary:
	var t: Dictionary = Partie.tenue
	var skin: Color = PnjUtil.SKINS[0]
	var bas_c: Array = t.get("bas", [0.2, 0.3, 0.48])
	var bas := PnjUtil.plain(Color(bas_c[0], bas_c[1], bas_c[2]))
	var haut_c: Array = t.get("haut", [0.1, 0.5, 0.55])
	var haut := PnjUtil.plain(Color(haut_c[0], haut_c[1], haut_c[2]))
	var cheveux: String = t.get("coiffure", "chr_cheveux" if genre == "homme" else "chr_tresse")
	var pieds: String = t.get("chaussures", "chr_chaussures")
	var show: Array = []
	var cloth: Material = bas
	match String(t.get("style", "tshirt")):
		"boubou":
			cloth = PnjUtil.wax(PnjUtil.WAX_PALETTES[int(t.get("wax", 0)) % PnjUtil.WAX_PALETTES.size()], int(t.get("wax", 0)) % 4)
			haut = cloth
			show = ["chr_boubou", "chr_haut_long", "chr_pantalon"] if genre == "homme" else ["chr_haut", "chr_pagne_long", "chr_foulard"]
		"maillot":
			haut = PnjUtil.jersey(int(t.get("club", 0)))
			show = ["chr_haut", "chr_pantalon"] if genre == "homme" else ["chr_haut", "chr_pagne_long"]
		_:
			show = ["chr_haut", "chr_pantalon"] if genre == "homme" else ["chr_haut", "chr_pagne_long"]
	show.append(pieds)
	if cheveux != "":
		show.append(cheveux)
	return {"skin": skin, "top": haut, "legs": bas, "cloth": cloth, "show": show}


# ------------------------------------------------------------------ garage
func _vehicule_devant(cle: String) -> Node3D:
	var p: Vector3 = _points.get(cle, Vector3.INF)
	var best: Node3D = null
	var bd := portee_garage
	for v in get_tree().get_nodes_in_group("vehicules"):
		var d := (v as Node3D).global_position.distance_to(p)
		if d < bd:
			bd = d
			best = v
	var z := get_node_or_null("../Zem") as Node3D
	if z and z.global_position.distance_to(p) < bd:
		best = z
	return best


func _garage(i: int) -> bool:
	var v := _vehicule_devant("garage")
	if v == null:
		Partie.notifier(tr("Gare ton véhicule devant le garage d'abord."))
		return false
	match i:
		0:
			if v.has_method("reparer"):
				v.reparer()
			else:
				v.set("health", 100.0)
			Partie.notifier(tr("Tonton Codjo : « Elle est comme neuve ! »"))
		1:
			var c: Color = PEINTURES[randi() % PEINTURES.size()]
			_peindre(v, c)
			if Partie.recherche > 0 and not Partie.police_voit:
				Partie.set_recherche(0)
				Partie.notifier(tr("Nouvelle couleur : la police a perdu ta trace."))
			else:
				Partie.notifier(tr("Tonton Codjo : « Belle couleur, hein ! »"))
		2:
			if v.get("_horn"):
				(v.get("_horn") as AudioStreamPlayer3D).stream = AudioSynth.klaxon(420.0, 560.0, 0.7)
			v.set_meta("klaxon", "deux_tons")
			Partie.notifier(tr("Klaxon deux tons monté."))
	return true


func _peindre(v: Node3D, c: Color) -> void:
	v.set_meta("couleur", c)
	var mats = v.get("_body_mats")
	if mats is Array:
		for e in mats:
			(e[0] as BaseMaterial3D).albedo_color = c
			e[1] = c
	else:
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				var m: Material = (mi as MeshInstance3D).mesh.surface_get_material(s)
				if m and m.resource_name in ["mat_carrosserie", "zem_reservoir"]:
					var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
					d.albedo_color = c
					(mi as MeshInstance3D).set_surface_override_material(s, d)


# ------------------------------------------------------------------ proprietes
func _acheter_propriete(k: String) -> bool:
	if _possede(k):
		Partie.notifier(tr("Tu possèdes déjà ce logement."))
		return false
	var l: Array = Partie.drapeaux.get("proprietes", [])
	l.append(k)
	Partie.drapeaux["proprietes"] = l
	var lab := get_node_or_null("Enseigne_prop_%s/Nom" % k) as Label3D
	if lab:
		lab.text = PROPRIETES[k]["nom"] + "  ✓"
	Partie.notifier(tr("%s est à toi : E devant la porte pour dormir et sauvegarder.") % tr(PROPRIETES[k]["nom"]))
	return true


func _physics_process(delta: float) -> void:
	_sleep_cd = maxf(0.0, _sleep_cd - delta)
	if _player == null or _player.get("vehicle") != null:
		return
	for k in PROPRIETES:
		if not _possede(k):
			continue
		var p: Vector3 = _points.get("prop_" + k, Vector3.INF)
		if _player.global_position.distance_to(p) < 2.5:
			if _hud and _hud.has_method("show_hint"):
				_hud.show_hint(tr("E : dormir et sauvegarder (%s)") % tr(PROPRIETES[k]["nom"]))
			if Input.is_action_just_pressed("interact") and _sleep_cd <= 0.0 and Partie.recherche == 0:
				_sleep_cd = 5.0
				_dormir(k)


func _dormir(k: String) -> void:
	## Planque : la nuit passe, sante pleine, sauvegarde ; le vehicule gare devant est garde.
	var v := _vehicule_devant("prop_" + k)
	if v and v != get_node_or_null("../Zem"):
		var c: Color = v.get_meta("couleur", Color.WHITE)
		Partie.drapeaux["garage_" + k] = {"modele": String(v.get("model_name")), "couleur": [c.r, c.g, c.b]}
	var day := get_node_or_null("../JourNuit")
	if day:
		day.set("hour", 7.0)
	Partie.soigner(100.0)
	Partie.sauver(get_parent())
	Partie.notifier(tr("Une nouvelle journée commence. Partie sauvegardée."))


func _garer_vehicules_sauves() -> void:
	## Au chargement : les vehicules gares devant les proprietes reviennent.
	for k in PROPRIETES:
		var g = Partie.drapeaux.get("garage_" + k)
		if not (g is Dictionary) or not _possede(k):
			continue
		var cc: Array = g.get("couleur", [1, 1, 1])
		var c := Color(cc[0], cc[1], cc[2])
		var v := Vehicules.create(String(g.get("modele", "veh_berline")), c)
		v.set_meta("couleur", c)
		var p: Vector3 = _points["prop_" + k]
		v.transform = Transform3D(Basis.IDENTITY, p + Vector3(-3.0, 0.3, 2.0))
		get_parent().add_child.call_deferred(v)
