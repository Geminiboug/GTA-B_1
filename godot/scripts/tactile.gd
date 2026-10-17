extends CanvasLayer
## Commandes tactiles (smartphone Android, decision d'Olympe du 17/10/2026) : visibles seulement sur un ecran tactile
## (ou avec --tactile pour les tester sur PC). Les boutons envoient les memes actions que le clavier et la manette.
## - Joystick a gauche : marcher (a pied) ou diriger (en vehicule).
## - Moitie droite de l'ecran : glisser le doigt pour tourner la camera.
## - Boutons a droite selon la situation : a pied (sauter, courir, frapper, viser, monter, parler) ; en vehicule
##   (accelerer, freiner, frein a main, klaxon, descendre, limiteur). En haut : carte, inventaire, telephone, pause.

@export var rayon_joystick := 110.0       # px
@export var sensibilite_camera := 0.012   # force de l'axe camera par pixel glisse

var actif := false
var _joy_centre := Vector2.ZERO
var _joy_doigt := -1
var _joy_vec := Vector2.ZERO
var _cam_doigt := -1
var _cam_prec := Vector2.ZERO
var _cam_delta := Vector2.ZERO
var _base: Control
var _bouton_joy: Control
var _pied: Control
var _vehicule: Control
var _haut: Control
var _player: Node


func _ready() -> void:
	layer = 8
	actif = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or "--tactile" in OS.get_cmdline_user_args()
	visible = actif
	if not actif:
		set_process(false)
		set_process_input(false)
		return
	_player = get_node_or_null("../Player")
	_construire()
	# le toucher est aussi converti en clic de souris (menus) : sur ecran tactile, le clic ne frappe pas et ne vise pas
	for a in ["attaque", "garde"]:
		if InputMap.has_action(a):
			for ev in InputMap.action_get_events(a):
				if ev is InputEventMouseButton:
					InputMap.action_erase_event(a, ev)
	# premier lancement sur telephone : qualite Basse
	if OS.has_feature("mobile") and not FileAccess.file_exists(Partie.OPTIONS):
		Partie.options["qualite"] = 0
		Partie.sauver_options()


func _construire() -> void:
	var racine := Control.new()
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(racine)
	_base = _rond(rayon_joystick, Color(1, 1, 1, 0.12))
	_bouton_joy = _rond(rayon_joystick * 0.42, Color(1, 1, 1, 0.35))
	racine.add_child(_base)
	racine.add_child(_bouton_joy)
	_base.visible = false
	_bouton_joy.visible = false
	_pied = _colonne([["Sauter", "jump"], ["Courir", "sprint"], ["Frapper", "attaque"], ["Viser", "garde"],
		["Monter", "interact"], ["Parler", "parler"]])
	_vehicule = _colonne([["Gaz", "accelerate"], ["Frein", "brake"], ["Frein à main", "handbrake"], ["Klaxon", "horn"],
		["Descendre", "interact"], ["Limiteur", "limiteur"]])
	racine.add_child(_pied)
	racine.add_child(_vehicule)
	_haut = HBoxContainer.new()
	_haut.anchor_left = 0.5
	_haut.anchor_right = 0.5
	_haut.offset_left = -230
	_haut.offset_top = 12
	(_haut as HBoxContainer).add_theme_constant_override("separation", 10)
	for e in [["Carte", "map"], ["Sac", "inventaire_t"], ["Tél.", "telephone_t"], ["Pause", "pause"]]:
		_haut.add_child(_bouton(e[0], e[1], Vector2(100, 56)))
	racine.add_child(_haut)


func _rond(r: float, c: Color) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(r))
	p.add_theme_stylebox_override("panel", sb)
	p.size = Vector2(r * 2.0, r * 2.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _colonne(liste: Array) -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.anchor_left = 1.0
	g.anchor_right = 1.0
	g.anchor_top = 1.0
	g.anchor_bottom = 1.0
	g.offset_left = -330
	g.offset_right = -20
	g.offset_top = -330
	g.offset_bottom = -20
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 12)
	for e in liste:
		g.add_child(_bouton(e[0], e[1], Vector2(150, 92)))
	return g


func _bouton(texte: String, action: String, taille: Vector2) -> Button:
	var b := Button.new()
	b.text = texte
	b.custom_minimum_size = taille
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(18)
	sb.border_color = Color(1, 1, 1, 0.5)
	sb.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", sb)
	var sp := sb.duplicate() as StyleBoxFlat
	sp.bg_color = Color(1, 1, 1, 0.3)
	b.add_theme_stylebox_override("pressed", sp)
	b.button_down.connect(func() -> void: _appui(action, true))
	b.button_up.connect(func() -> void: _appui(action, false))
	return b


func _appui(action: String, on: bool) -> void:
	match action:
		"inventaire_t":
			if on:
				var inv := get_node_or_null("../Inventaire")
				if inv:
					inv.ouvrir(not inv.get("ouvert"))
		"telephone_t":
			if on:
				var tel := get_node_or_null("../Telephone")
				if tel:
					tel.ouvrir(not tel.get("ouvert"))
		_:
			if not InputMap.has_action(action):
				return
			if on:
				Input.action_press(action)
			else:
				Input.action_release(action)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var w := get_viewport().get_visible_rect().size.x
		if t.pressed:
			if t.position.x < w * 0.4 and _joy_doigt < 0:
				_joy_doigt = t.index
				_joy_centre = t.position
				_base.visible = true
				_bouton_joy.visible = true
				_placer_joy(t.position)
			elif t.position.x >= w * 0.4 and _cam_doigt < 0 and not _sur_bouton(t.position):
				_cam_doigt = t.index
				_cam_prec = t.position
		else:
			if t.index == _joy_doigt:
				_joy_doigt = -1
				_joy_vec = Vector2.ZERO
				_base.visible = false
				_bouton_joy.visible = false
			elif t.index == _cam_doigt:
				_cam_doigt = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_doigt:
			_placer_joy(d.position)
		elif d.index == _cam_doigt:
			_cam_delta += d.position - _cam_prec
			_cam_prec = d.position


func _sur_bouton(p: Vector2) -> bool:
	for c in [_pied, _vehicule, _haut]:
		if (c as Control).visible and (c as Control).get_global_rect().has_point(p):
			return true
	return false


func _placer_joy(p: Vector2) -> void:
	var v := (p - _joy_centre).limit_length(rayon_joystick)
	_joy_vec = v / rayon_joystick
	_base.position = _joy_centre - Vector2(rayon_joystick, rayon_joystick)
	_bouton_joy.position = _joy_centre + v - Vector2(rayon_joystick, rayon_joystick) * 0.42


func _process(delta: float) -> void:
	var en_vehicule: bool = _player != null and _player.get("vehicle") != null
	_pied.visible = not en_vehicule
	_vehicule.visible = en_vehicule
	# joystick -> axes de deplacement (memes actions que ZQSD et le stick gauche)
	for e in [["move_left", -_joy_vec.x], ["move_right", _joy_vec.x], ["move_forward", -_joy_vec.y], ["move_back", _joy_vec.y]]:
		var f: float = maxf(0.0, e[1])
		if f > 0.05:
			Input.action_press(e[0], f)
		else:
			Input.action_release(e[0])
	# glisser a droite -> axes de camera (comme le stick droit), amorti
	var c := _cam_delta * sensibilite_camera / maxf(delta * 60.0, 0.5)
	for e in [["look_left", -c.x], ["look_right", c.x], ["look_up", -c.y], ["look_down", c.y]]:
		var f: float = clampf(e[1], 0.0, 1.0)
		if f > 0.01:
			Input.action_press(e[0], f)
		else:
			Input.action_release(e[0])
	_cam_delta = Vector2.ZERO
