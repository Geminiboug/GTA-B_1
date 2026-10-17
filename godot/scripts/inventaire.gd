extends CanvasLayer
## Inventaire du joueur : I (manette : croix gauche) ouvre la liste de ce qu'il a sur lui (Partie.inventaire) ;
## haut / bas pour choisir, Entree (A) pour utiliser, I ou Echap (B) pour fermer. Le jeu continue pendant ce temps.
## Au depart : un smartphone (scripts/telephone.gd, aussi sur P) et une torche (aussi sur L) : lampe dans la main
## droite et faisceau qui suit le regard, eteinte en vehicule. Nourriture achetee a emporter : "Manger" rend de la
## sante. Les autres objets (colis, riz...) servent aux missions.

@export var player_path: NodePath = ^"../Player"
@export var touche := KEY_I
@export var touche_torche := KEY_L
@export var torche_portee := 28.0       # m
@export var torche_angle := 26.0        # degres (demi-angle du cone)
@export var torche_energie := 9.0

const DESCRIPTIONS := {
	"Smartphone": "Messages, carte, zem à la demande, appareil photo.",
	"Torche": "Lampe torche à piles. Pratique la nuit et pendant les délestages.",
	"Pain": "Pain frais de l'étal.",
	"Sac de riz (5 kg)": "Riz parfumé, pour la maison.",
	"Huile (1 litre)": "Huile d'arachide.",
	"Boîte de tomate": "Concentré de tomate.",
	"Essence (1 litre)": "Essence du kpayo, en bouteille.",
	"Crédit téléphone": "Recharge pour le smartphone.",
	"Carte SIM": "Une puce de plus.",
	"Colis": "Un colis à livrer. Ne pas ouvrir.",
}
const ORDRE := ["Smartphone", "Torche"]   # toujours en tete de liste
const COMMERCE := preload("res://scripts/commerce.gd")

var ouvert := false
var torche_allumee := false
var _player: Node3D
var _panel: PanelContainer
var _list: VBoxContainer
var _desc: Label
var _sel := 0
var _items: Array = []
var _spot: SpotLight3D
var _lamp: Node3D
var _lamp_check := 0.0


func _ready() -> void:
	layer = 7
	_player = get_node_or_null(player_path)
	_panel = PanelContainer.new()
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = 24
	_panel.offset_right = 404
	_panel.offset_top = -170
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.06, 0.82)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_panel.add_child(col)
	var t := Label.new()
	t.text = "INVENTAIRE"
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
	col.add_child(t)
	_list = VBoxContainer.new()
	col.add_child(_list)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(350, 0)
	_desc.add_theme_font_size_override("font_size", 15)
	_desc.add_theme_color_override("font_color", Color(0.78, 0.8, 0.82))
	col.add_child(_desc)
	var h := Label.new()
	h.name = "Aide"
	h.text = "Haut / Bas choisir · Entrée utiliser · I fermer"
	h.add_theme_font_size_override("font_size", 14)
	h.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	col.add_child(h)
	Partie.inventaire_change.connect(func() -> void:
		if ouvert:
			_refresh()
		if torche_allumee and not Partie.a("Torche"):
			torche(false))


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	var toggle: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == touche) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_LEFT)
	if toggle:
		ouvrir(not ouvert)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == touche_torche:
		if Partie.a("Torche"):
			torche(not torche_allumee)
		get_viewport().set_input_as_handled()
		return
	if not ouvert:
		return
	# liste ouverte : les fleches et la croix de la manette servent a choisir (pas a l'aide ni a la vue)
	var up: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_UP) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_UP)
	var down: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_DOWN) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_DOWN)
	var use: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)
	var close: bool = event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if up or down:
		_sel = wrapi(_sel + (1 if down else -1), 0, maxi(1, _items.size()))
		_refresh()
	elif use:
		utiliser(_items[_sel] if _sel < _items.size() else "")
	elif close:
		ouvrir(false)
	else:
		return
	get_viewport().set_input_as_handled()


func ouvrir(on: bool) -> void:
	ouvert = on
	_panel.visible = on
	if on:
		_sel = 0
		_refresh()


func liste() -> Array:
	## Objets dans l'ordre d'affichage : smartphone et torche d'abord, puis le reste par ordre alphabetique.
	var out: Array = []
	for k in ORDRE:
		if Partie.a(k):
			out.append(k)
	var rest: Array = []
	for k in Partie.inventaire:
		if not k in ORDRE:
			rest.append(k)
	rest.sort()
	return out + rest


func _action(item: String) -> String:
	match item:
		"Smartphone":
			return "Ouvrir"
		"Torche":
			return "Éteindre" if torche_allumee else "Allumer"
	return "Manger" if _soin(item) > 0 else ""


func _soin(item: String) -> int:
	for kind in COMMERCE.ARTICLES:
		for a in COMMERCE.ARTICLES[kind]:
			if a[0] == item:
				return int(a[2])
	return 0


func _refresh() -> void:
	_items = liste()
	_sel = clampi(_sel, 0, maxi(0, _items.size() - 1))
	for c in _list.get_children():
		c.free()
	if _items.is_empty():
		var l := Label.new()
		l.text = "Poches vides."
		_list.add_child(l)
		_desc.text = ""
		return
	for i in _items.size():
		var item: String = _items[i]
		var l := Label.new()
		var n := int(Partie.inventaire.get(item, 0))
		var act := _action(item)
		l.text = "%s%s%s%s" % ["> " if i == _sel else "   ", tr(item), "  x%d" % n if n > 1 else "", "   [%s]" % tr(act) if act != "" and i == _sel else ""]
		l.add_theme_font_size_override("font_size", 19)
		if i == _sel:
			l.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
		_list.add_child(l)
	_desc.text = tr(DESCRIPTIONS.get(_items[_sel], ""))


func utiliser(item: String) -> void:
	match item:
		"Smartphone":
			ouvrir(false)
			var tel := get_node_or_null("../Telephone")
			if tel:
				tel.ouvrir(true)
		"Torche":
			torche(not torche_allumee)
			_refresh()
		_:
			var soin := _soin(item)
			if soin > 0 and Partie.retirer(item):
				Partie.soigner(soin)
				Partie.notifier(tr("Tu manges : %s") % tr(item))
				var an: Node = _player.get("anim") if _player else null
				if an and an.has_method("play_clips") and _player.get("vehicle") == null:
					an.play_clips([["Consume", 0.0]], true)


# ------------------------------------------------------------------ torche
func torche(on: bool) -> void:
	torche_allumee = on and Partie.a("Torche")
	if torche_allumee and _spot == null and _player:
		_spot = SpotLight3D.new()
		_spot.name = "Torche"
		_spot.light_color = Color(1.0, 0.95, 0.85)
		_spot.light_energy = torche_energie
		_spot.spot_range = torche_portee
		_spot.spot_angle = torche_angle
		_spot.spot_angle_attenuation = 1.6
		_spot.shadow_enabled = true
		_spot.distance_fade_enabled = true
		_spot.distance_fade_begin = 60.0
		_player.add_child(_spot)
	_attach_lamp()
	if _spot:
		_spot.visible = torche_allumee
	if _lamp:
		_lamp.visible = torche_allumee


func _attach_lamp() -> void:
	## Lampe torche dans la main droite (refaite si le modele du joueur change).
	if _player == null or (_lamp and is_instance_valid(_lamp) and _lamp.is_inside_tree()):
		return
	var skel := Squelette.find(_player.get_node_or_null("Body"))
	if skel == null:
		return
	var ba := BoneAttachment3D.new()
	ba.name = "MainTorche"
	ba.bone_name = Squelette.bone_name(skel, "piv_main_D")
	skel.add_child(ba)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.022
	cm.bottom_radius = 0.018
	cm.height = 0.2
	cm.radial_segments = 10
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.08, 0.09)
	m.metallic = 0.4
	m.roughness = 0.4
	cm.material = m
	body.mesh = cm
	body.position = Vector3(0, 0.06, 0.03)
	body.rotation = Vector3(PI / 2.0, 0, 0)
	ba.add_child(body)
	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.03
	hm.bottom_radius = 0.022
	hm.height = 0.05
	hm.radial_segments = 10
	var em := StandardMaterial3D.new()
	em.albedo_color = Color(1, 0.97, 0.85)
	em.emission_enabled = true
	em.emission = Color(1, 0.95, 0.8)
	em.emission_energy_multiplier = 3.0
	hm.material = em
	head.mesh = hm
	head.position = Vector3(0, 0.06, 0.15)
	head.rotation = Vector3(PI / 2.0, 0, 0)
	ba.add_child(head)
	_lamp = ba
	_lamp.visible = torche_allumee


func _process(delta: float) -> void:
	if _spot == null or not torche_allumee:
		return
	var in_car: bool = _player.get("vehicle") != null
	_spot.visible = not in_car
	if _lamp:
		_lamp.visible = not in_car
	# faisceau a hauteur de main, dans la direction du regard (camera)
	var pivot := _player.get("cam_pivot") as Node3D
	var yaw := pivot.global_rotation.y if pivot else _player.global_rotation.y
	var pitch := clampf(pivot.rotation.x + 0.12, -0.9, 0.5) if pivot else -0.1
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0))
	_spot.global_transform = Transform3D(basis, _player.global_position + Vector3(0, 1.15, 0) + basis * Vector3(0.22, 0, -0.35))
	_lamp_check -= delta
	if _lamp_check <= 0.0:
		_lamp_check = 1.0
		_attach_lamp()
