extends CanvasLayer
## Menus : ecran titre au lancement (Nouvelle partie, Continuer, Options, Quitter), pause (Echap / Start :
## Reprendre, Sauvegarder, Charger, Options, Commandes, Quitter vers le titre), options (volume, sensibilite de la
## souris, effets de camera, qualite graphique, plein ecran ; enregistrees dans user://options.cfg).
## Les tests (scene lancee par un script, current_scene nul) demarrent directement en jeu, sans ecran titre.

@export var titre_au_lancement := true

const COMMANDES := """A PIED
ZQSD bouger · Shift sprint (tapoter) · Alt / Ctrl marcher · C s'accroupir
Espace sauter / escalader · F ou clic gauche frapper · E monter dans un véhicule
T parler / acheter · M carte · V vue · Échap pause

EN VÉHICULE
Z accélérer · S freiner / reculer · Q D tourner · Espace frein à main · H klaxon · E descendre

MANETTE
Stick gauche bouger · stick droit caméra · A sprint · X sauter · B frapper · Y véhicule
Croix droite parler · Select carte · Start pause · L3 marcher · R3 s'accroupir"""

var _root: Control
var _box: VBoxContainer
var _title: Label
var _page := ""
var _mode := ""      # "titre", "pause"


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("menus")
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.02, 0.03, 0.05, 0.62)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(520, 0)
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 64)
	_title.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_title.add_theme_constant_override("outline_size", 12)
	col.add_child(_title)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	col.add_child(_box)
	_root.visible = false
	if titre_au_lancement and get_tree().current_scene == get_parent():
		_open("titre")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _mode == "pause":
			if _page == "principal":
				_close()
			else:
				_show_pause()
			get_viewport().set_input_as_handled()
		elif _mode == "" and not get_tree().paused:
			_open("pause")
			get_viewport().set_input_as_handled()


func _open(mode: String) -> void:
	_mode = mode
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mode == "titre":
		_show_title()
	else:
		_show_pause()


func _close() -> void:
	_mode = ""
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_open() -> bool:
	return _mode != ""


func _clear(title: String) -> void:
	_title.text = title
	for c in _box.get_children():
		c.queue_free()


func _button(text: String, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _show_title() -> void:
	_page = "titre"
	_clear("GTB")
	var sub := Label.new()
	sub.text = "Gbê Town Bénin · Le Dernier Vol"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	_box.add_child(sub)
	var first := _button("Nouvelle partie", func() -> void:
		Partie.nouvelle_partie()
		_close()
		get_tree().call_group("histoire", "commencer"))
	_button("Continuer", func() -> void:
		_close()
		Partie.charger(get_parent())
		get_tree().call_group("histoire", "reprendre"), Partie.existe_sauvegarde())
	_button("Options", _show_options)
	_button("Quitter", func() -> void: get_tree().quit())
	first.grab_focus.call_deferred()


func _show_pause() -> void:
	_page = "principal"
	_clear("Pause")
	var first := _button("Reprendre", _close)
	var can_save: bool = Partie.recherche == 0
	_button("Sauvegarder" if can_save else "Sauvegarder (impossible : recherché)", func() -> void:
		Partie.sauver(get_parent())
		_close(), can_save)
	_button("Charger la dernière sauvegarde", func() -> void:
		_close()
		Partie.charger(get_parent())
		get_tree().call_group("histoire", "reprendre"), Partie.existe_sauvegarde())
	_button("Options", _show_options)
	_button("Commandes", _show_controls)
	_button("Quitter vers l'écran titre", func() -> void:
		_mode = "titre"
		_show_title())
	first.grab_focus.call_deferred()


func _show_controls() -> void:
	_page = "commandes"
	_clear("Commandes")
	var l := Label.new()
	l.text = COMMANDES
	l.add_theme_font_size_override("font_size", 18)
	_box.add_child(l)
	_button("Retour", _back).grab_focus.call_deferred()


func _back() -> void:
	if _mode == "titre":
		_show_title()
	else:
		_show_pause()


func _show_options() -> void:
	_page = "options"
	_clear("Options")
	var o: Dictionary = Partie.options
	_slider("Volume", o["volume"], 0.0, 1.0, func(v: float) -> void: o["volume"] = v)
	_slider("Sensibilité de la souris", o["sensibilite"], 0.3, 2.5, func(v: float) -> void: o["sensibilite"] = v)
	_check("Effets de caméra (recentrage, secousses)", o["effets_camera"], func(v: bool) -> void: o["effets_camera"] = v)
	_check("Plein écran", o["plein_ecran"], func(v: bool) -> void: o["plein_ecran"] = v)
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = "Qualité graphique"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	var ob := OptionButton.new()
	for n in Qualite.NOMS:
		ob.add_item(n)
	ob.selected = int(o["qualite"])
	ob.item_selected.connect(func(i: int) -> void: o["qualite"] = i)
	row.add_child(ob)
	_box.add_child(row)
	_button("Appliquer et revenir", func() -> void:
		Partie.sauver_options()
		_back()).grab_focus.call_deferred()


func _slider(text: String, value: float, lo: float, hi: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 20)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(200, 0)
	s.value_changed.connect(cb)
	row.add_child(s)
	_box.add_child(row)


func _check(text: String, value: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 20)
	c.toggled.connect(cb)
	_box.add_child(c)
