extends CanvasLayer
## Achats facon GTA : a pied pres d'un etal, d'un maquis, d'un kpayo, d'une cabine de transfert, d'une caisse de
## l'Ararat ou du cafe de l'aerogare, T (manette : croix droite) ouvre la liste des articles ; 1 a 4 (ou haut / bas
## puis A) achete, T ferme. Nourriture et boissons rendent de la sante (Partie.soigner), le reste va dans
## l'inventaire. Prix reels de Cotonou (FCFA, 2026).

@export var player_path: NodePath = ^"../Player"
@export var portee := 2.2          # m

const ARTICLES := {
	"etal": [["Eau en sachet (pure water)", 50, 6], ["Arachides grillées", 200, 10], ["Ananas", 500, 15], ["Pain", 150, 12]],
	"maquis": [["Pâte rouge et poulet", 1500, 60], ["Riz sauce arachide", 1000, 45], ["Akassa et poisson frit", 800, 40], ["Bière locale", 600, 5]],
	"kpayo": [["Essence (1 litre)", 650, 0]],
	"cabine": [["Crédit téléphone", 500, 0], ["Carte SIM", 1000, 0]],
	"caisse": [["Sac de riz (5 kg)", 4500, 0], ["Huile (1 litre)", 1500, 0], ["Boîte de tomate", 300, 0], ["Eau minérale (1,5 l)", 500, 8]],
	"cafe": [["Café", 700, 5], ["Sandwich", 2000, 35], ["Jus de bissap", 800, 10]],
}
const NOMS := {"etal": "l'étal", "maquis": "le maquis", "kpayo": "le vendeur d'essence", "cabine": "la cabine",
	"caisse": "la caisse", "cafe": "le café"}

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
	_collect.call_deferred()


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


func nearest(p: Vector3) -> Dictionary:
	var best := {}
	var bd := portee
	for s in spots:
		var d := Vector2(p.x - s["pos"].x, p.z - s["pos"].z).length()
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
			_hud.show_hint("T : acheter à %s" % NOMS.get(_near["kind"], "l'étal"))
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
	if not Partie.payer(int(it[1]), it[0]):
		return false
	# nourriture : mangee sur place (sante), sauf si une mission demande de la rapporter (Partie.drapeaux["garder"])
	var mange := int(it[2]) > 0 and not (Partie.drapeaux.get("garder", []) as Array).has(String(it[0]))
	if mange:
		Partie.soigner(int(it[2]))
	else:
		Partie.ajouter(String(it[0]))
	# geste : on tend la main pour payer et prendre, puis on mange sur place
	var an: Node = _player.get("anim") if _player else null
	if an and an.has_method("play_clips"):
		an.play_clips([["Interact", 0.0]] + ([["Consume", 0.0]] if mange else []), true)
	if _player:
		Bulle.say(_player, "Merci !" if randf() < 0.5 else "Akpé !", 1.4, 2.0, Color(0.8, 1, 0.8))
	return true


func _show(kind: String) -> void:
	_open = kind
	_sel = 0
	_panel.visible = true
	_refresh()


func _refresh() -> void:
	for c in _list.get_children():
		c.free()
	var title := Label.new()
	title.text = "Acheter à %s   (%s en poche)" % [NOMS.get(_open, ""), Partie.fcfa(Partie.argent)]
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	_list.add_child(title)
	var items: Array = ARTICLES[_open]
	for i in items.size():
		var l := Label.new()
		l.text = "%s%d.  %s   %s" % ["> " if i == _sel else "   ", i + 1, items[i][0], Partie.fcfa(int(items[i][1]))]
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(1, 1, 1) if i == _sel else Color(0.8, 0.8, 0.8))
		_list.add_child(l)
	var help := Label.new()
	help.text = "1-%d ou Entrée : acheter    T : fermer" % items.size()
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_list.add_child(help)


func _close() -> void:
	_open = ""
	_panel.visible = false
