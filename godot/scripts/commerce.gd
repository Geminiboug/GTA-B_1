extends CanvasLayer
## Achats facon GTA : a pied pres d'un etal, d'un maquis, d'un kpayo, d'une cabine de transfert, d'une caisse de
## l'Ararat ou du cafe de l'aerogare, T (manette : croix droite) ouvre la liste des articles ; 1 a 4 (ou haut / bas
## puis A) achete, T ferme. Nourriture et boissons rendent de la sante (Partie.soigner), le reste va dans
## l'inventaire. Prix reels de Cotonou (FCFA, 2026).

@export var player_path: NodePath = ^"../Player"
@export var portee := 2.2          # m

# [nom, prix, sante rendue (mange sur place), quantite]
var ARTICLES := {
	# un etal vend une seule marchandise (celle qu'on voit sur le modele et que crie la vendeuse)
	"etal_pain": [["Pain", 150, 12], ["Pain au lait", 250, 14]],
	"etal_fruits": [["Ananas", 500, 15], ["Oranges (3)", 300, 10], ["Bananes (5)", 250, 10]],
	"etal_arachides": [["Arachides grillées", 200, 10], ["Arachides bouillies", 250, 11]],
	"etal_eau": [["Eau en sachet (pure water)", 50, 6], ["Eau minérale (1,5 l)", 500, 8], ["Jus de gingembre", 300, 9]],
	"etal_legumes": [["Tomates fraîches", 300, 8], ["Piments", 150, 0], ["Oignons", 200, 0]],
	"maquis": [["Pâte rouge et poulet", 1500, 60], ["Riz sauce arachide", 1000, 45], ["Akassa et poisson frit", 800, 40], ["Bière locale", 600, 5]],
	"kpayo": [["Essence (1 litre)", 650, 0]],
	"cabine": [["Crédit téléphone", 500, 0], ["Carte SIM", 1000, 0]],
	# Ararat Hypermarket : chaque article se prend dans son rayon (les caisses ne vendent rien)
	"rayon_riz": [["Sac de riz (5 kg)", 4500, 0]],
	"rayon_huile": [["Huile (1 litre)", 1500, 0]],
	"rayon_conserves": [["Boîte de tomate", 300, 0]],
	"rayon_boissons": [["Eau minérale (1,5 l)", 500, 8]],
	"rayon_vrac": [["Blouson de moto renforcé", 12000, 0]],
	"cafe": [["Café", 700, 5], ["Sandwich", 2000, 35], ["Jus de bissap", 800, 10]],
	# armes (scripts/armes.gd) : quincaillerie de jour, le Gaou la nuit pres de la plage
	"salle": [["Séance de musculation", 1000, 0]],
	"quincaillerie": [["Bâton", 500, 0], ["Machette", 3500, 0], ["Coupe-coupe", 2500, 0]],
	"gaou": [["Fusil de chasse artisanal", 60000, 0], ["Pistolet", 150000, 0], ["Fusil à pompe", 220000, 0],
		["Balles 9 mm", 1500, 0, 12], ["Cartouches", 2000, 0, 6]],
}
var NOMS := {"etal_pain": "l'étal de pain", "etal_fruits": "l'étal de fruits", "etal_arachides": "l'étal d'arachides",
	"etal_eau": "l'étal d'eau fraîche", "etal_legumes": "l'étal de légumes", "maquis": "le maquis", "kpayo": "le vendeur d'essence", "cabine": "la cabine",
	"rayon_riz": "le rayon Riz et céréales", "rayon_huile": "le rayon Huiles", "rayon_conserves": "le rayon Conserves",
	"rayon_boissons": "le rayon Boissons", "rayon_vrac": "le rayon Gros conditionnement", "cafe": "le café", "quincaillerie": "la quincaillerie", "gaou": "le Gaou",
	"salle": "Gbêkpo Fitness"}

var spots: Array = []          # [{pos, kind}]
var _player: Node3D
var _hud: Node
var _panel: PanelContainer
var _list: VBoxContainer
var _open := ""
var _sel := 0
var _scan_t := 0.0
var _near: Dictionary = {}


func _ready() -> void:
	layer = 6
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null("../HUD")
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.55
	_panel.offset_left = -260
	_panel.offset_right = 260
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.72)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_list = VBoxContainer.new()
	_panel.add_child(_list)
	Partie.chantier_differe(_collect)   # etape de la mise en place etalee pendant le chargement


func _collect() -> void:
	## Etals, maquis, kpayos et cabines (scripts/props.gd), caisses et cafe (scripts/lieux.gd).
	var props := get_node_or_null("../Props")
	if props and not props.get("placed"):
		await props.placement_done      # les etals sont poses apres deux images de physique
	if props and "shops" in props:
		spots.append_array(props.shops)
	var lieux := get_node_or_null("../Lieux")
	if lieux and "shop_spots" in lieux:
		spots.append_array(lieux.shop_spots)


func _nuit() -> float:
	var dn := get_node_or_null("../JourNuit")
	return float(dn.get("night")) if dn else 0.0


func nearest(p: Vector3) -> Dictionary:
	var best := {}
	var bd := portee
	for s in spots:
		var d := Vector2(p.x - s["pos"].x, p.z - s["pos"].z).length()
		if not ARTICLES.has(s["kind"]):
			continue           # caisses, rayons sans article a vendre
		if s.get("nuit", false) and _nuit() < 0.5:
			continue           # le Gaou ne vend qu'a la nuit tombee
		if d < bd and absf(p.y - s["pos"].y) < 2.5:
			bd = d
			best = s
	return best


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	if _player.get("vehicle") != null:
		_close()
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.15
		_near = nearest(_player.global_position)
	if _open == "" and not _near.is_empty():
		if _hud and _hud.has_method("show_hint"):
			_hud.show_hint(tr("T : ouvrir l'armoire") if _near["kind"] == "armoire" else "T : acheter à %s" % NOMS.get(_near["kind"], "ici"))
		if Input.is_action_just_pressed("parler"):
			_show(_near["kind"])
	elif _open != "":
		if _near.is_empty():
			_close()
			return
		if Input.is_action_just_pressed("parler"):
			_close()
			return
		var items: Array = ARTICLES[_open]
		for i in items.size():
			if Input.is_key_pressed(KEY_1 + i) and not _key_held.get(i, false):
				buy(_open, i)
			_key_held[i] = Input.is_key_pressed(KEY_1 + i)
		if Input.is_action_just_pressed("ui_down"):
			_sel = (_sel + 1) % items.size()
			_refresh()
		elif Input.is_action_just_pressed("ui_up"):
			_sel = (_sel - 1 + items.size()) % items.size()
			_refresh()
		elif Input.is_action_just_pressed("ui_accept"):
			buy(_open, _sel)


var _key_held := {}


func buy(kind: String, i: int) -> bool:
	var it: Array = ARTICLES[kind][i]
	var perso := get_node_or_null("../Personnalisation")
	if perso and perso.gere(kind):
		# tenues, coiffeur, garage, agence : applique d'abord, facture seulement si c'est possible
		if Partie.argent < int(it[1]):
			Partie.notifier(tr("Pas assez d'argent."))
			return false
		if not perso.achat(kind, i):
			return false
		var an0: Node = _player.get("anim") if _player else null
		if kind == "armoire" and an0 and an0.has_method("play_clips"):
			an0.play_clips([["Chest_Open", 0.0]], true)     # on ouvre l'armoire et on se change
		if int(it[1]) > 0:
			Partie.payer(int(it[1]), it[0])
		if _open != "":
			_refresh()
		return true
	if not Partie.payer(int(it[1]), it[0]):
		return false
	# nourriture : mangee sur place (sante), sauf si une mission demande de la rapporter (Partie.drapeaux["garder"])
	var mange := int(it[2]) > 0 and not (Partie.drapeaux.get("garder", []) as Array).has(String(it[0]))
	if kind == "paris":
		var ac := get_node_or_null("../Activites")
		if ac:
			ac.parier(i)
		return true
	if String(it[0]) == "Séance de musculation":
		var st2 := get_node_or_null("../Stats")
		if st2:
			st2.seance_salle()
		return true
	if String(it[0]) == "Bière locale":
		Partie.ajouter("Bouteille")           # la bouteille vide reste : arme improvisee (scripts/armes.gd)
	if String(it[0]) == "Blouson de moto renforcé":
		Partie.equiper_armure(100.0)          # enfile tout de suite : barre bleue sous la sante
	elif mange:
		Partie.soigner(int(it[2]))
		var st := get_node_or_null("../Stats")
		if st:
			st.mange(float(it[2]))
	else:
		Partie.ajouter(String(it[0]), int(it[3]) if it.size() > 3 else 1)
	# geste : on tend la main pour payer et prendre, puis on mange sur place
	var an: Node = _player.get("anim") if _player else null
	if an and an.has_method("play_clips"):
		an.play_clips([["Interact", 0.0]] + ([["Consume", 0.0]] if mange else []), true)
	if _player:
		Bulle.say(_player, "Merci !" if randf() < 0.5 else "Akpé !", 1.4, 2.0, Color(0.8, 1, 0.8))
	return true


func _show(kind: String) -> void:
	var perso := get_node_or_null("../Personnalisation")
	if perso and perso.has_method("preparer"):
		perso.preparer(kind)              # listes qui changent (armoire : garde-robe du moment)
	_open = kind
	if _player:
		_player.menus["commerce"] = true
	_sel = 0
	_panel.visible = true
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.free()
	var title := Label.new()
	title.text = tr("Armoire : choisis ce que tu portes") if _open == "armoire" else tr("Acheter à %s   (%s en poche)") % [tr(NOMS.get(_open, "")), Partie.fcfa(Partie.argent)]
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_list.add_child(title)
	var items: Array = ARTICLES[_open]
	for i in items.size():
		var l := Label.new()
		l.text = "%s%d.  %s   %s" % ["> " if i == _sel else "   ", i + 1, tr(items[i][0]), "" if _open == "armoire" else Partie.fcfa(int(items[i][1]))]
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(1, 1, 1) if i == _sel else Color(0.8, 0.8, 0.8))
		_list.add_child(l)
	var help := Label.new()
	help.text = ("1-%d ou Entrée : mettre    T : fermer" if _open == "armoire" else "1-%d ou Entrée : acheter    T : fermer") % items.size()
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_list.add_child(help)


func _close() -> void:
	_open = ""
	if _player:
		_player.menus.erase("commerce")
	_panel.visible = false
