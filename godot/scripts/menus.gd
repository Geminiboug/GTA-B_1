extends CanvasLayer
## Menus : ecran titre au lancement (Nouvelle partie, Continuer, Options, Quitter), pause (Echap / Start :
## Reprendre, Sauvegarder, Charger, Options, Commandes, Quitter vers le titre), options (volume, sensibilite de la
## souris, effets de camera, qualite graphique, plein ecran ; enregistrees dans user://options.cfg).
## Les tests (scene lancee par un script, current_scene nul) demarrent directement en jeu, sans ecran titre.

const STATS_SCRIPT := preload("res://scripts/stats.gd")

@export var titre_au_lancement := true
@export var formulaire_retours := ""   # lien du formulaire de retours des joueurs (ecran de fin de demo), vide = pas de bouton

const COMMANDES := """A PIED
ZQSD bouger · Shift sprint (tapoter) · Alt / Ctrl marcher · C s'accroupir
Espace sauter / escalader · F ou clic gauche frapper · E monter dans un véhicule
T parler / acheter · M carte · V vue · Échap pause
I inventaire · P téléphone · L torche · F12 mode photo

EN VÉHICULE
Z accélérer · S freiner / reculer · Q D tourner · Espace frein à main · H klaxon · E descendre

MANETTE
Stick gauche bouger · stick droit caméra · A sprint · X sauter · B frapper · Y véhicule
Croix droite parler · croix gauche inventaire · Select carte · Start pause · L3 marcher · R3 s'accroupir"""

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
	var ver := Label.new()
	ver.name = "Version"
	ver.text = "v%s" % Partie.version_jeu()
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -160
	ver.offset_top = -36
	ver.offset_right = -18
	ver.offset_bottom = -10
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.add_theme_font_size_override("font_size", 16)
	ver.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.75))
	_root.add_child(ver)
	_root.visible = false
	if titre_au_lancement and get_tree().current_scene == get_parent():
		_open("titre")
		# version web lancee avec ?test : nouvelle partie directe (mesure des images/s, phase 11)
		if OS.has_feature("web") and String(JavaScriptBridge.eval("location.search")).contains("test"):
			_nouvelle_partie.call_deferred()


func _nouvelle_partie() -> void:
	Partie.nouvelle_partie()
	_close()
	get_tree().call_group("histoire", "commencer")


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
	var first := _button("Nouvelle partie", _nouvelle_partie)
	_button("Continuer", func() -> void:
		_close()
		Partie.charger(get_parent())
		get_tree().call_group("histoire", "reprendre"), Partie.existe_sauvegarde())
	_button("Options", _show_options)
	_button("Crédits", _show_credits)
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
	_button("Statistiques", _show_stats)
	_button("Commandes", _show_controls)
	_button("Crédits", _show_credits)
	_button("Quitter vers l'écran titre", func() -> void:
		_mode = "titre"
		_show_title())
	first.grab_focus.call_deferred()


func _show_credits() -> void:
	_page = "credits"
	_clear("Crédits")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, 440)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(sc)
	var l := Label.new()
	var f := FileAccess.open("res://assets/data/credits.txt", FileAccess.READ)
	l.text = f.get_as_text() if f else "GTB"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(740, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 17)
	sc.add_child(l)
	_button("Retour", _back).grab_focus.call_deferred()


func fin_demo() -> void:
	## Fin de l'acte 1 (fin de la demo) : "A suivre", avis des joueurs, puis jeu libre ou retour au titre.
	## Pas dans les tests (scene lancee par un script) : le jeu ne se met pas en pause.
	if get_tree().current_scene != get_parent():
		return
	_open("pause")
	_mode = "fin"
	_page = "fin"
	_clear("À suivre")
	var l := Label.new()
	l.text = "Merci d'avoir joué à la démo de GTB !
L'acte 2, « Sous les ailes », arrive bientôt.
Tu peux continuer à te balader dans le quartier."
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	_box.add_child(l)
	var first := _button("Continuer à jouer", _close)
	if formulaire_retours != "":
		_button("Donner mon avis", func() -> void: OS.shell_open(formulaire_retours))
	_button("Crédits", _show_credits)
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
	elif _mode == "fin":
		fin_demo()
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
	_check("Sous-titres", o.get("sous_titres", true), func(v: bool) -> void: o["sous_titres"] = v)
	_slider("Taille des sous-titres", o.get("taille_sous_titres", 26), 18, 44, func(v: float) -> void: o["taille_sous_titres"] = int(v))
	_check("Violence réduite (armes moins puissantes)", o.get("violence_reduite", false), func(v: bool) -> void: o["violence_reduite"] = v)
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


func _show_stats() -> void:
	## Statistiques du personnage (phase 15) : barres 0..100, silhouette, compteurs de partie.
	_page = "stats"
	_clear("Statistiques")
	var st := get_parent().get_node_or_null("Stats") if get_parent() else null
	for k in ["endurance", "muscles", "graisse", "respect", "zem", "voiture", "tir", "natation"]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = tr(STATS_SCRIPT.NOMS[k])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 20)
		row.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(240, 18)
		bar.value = float(Partie.perso.get(k, 0.0))
		bar.show_percentage = false
		row.add_child(bar)
		var n := Label.new()
		n.text = "%d" % roundi(bar.value)
		n.custom_minimum_size = Vector2(48, 0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.add_theme_font_size_override("font_size", 20)
		row.add_child(n)
		_box.add_child(row)
	var info := Label.new()
	var corps := {"mince": "mince", "": "normale", "fort": "costaud"}
	var c: String = st.morpho() if st else ""
	info.text = tr("Silhouette : %s    Courses de zem : %d    Missions : %d    Amendes : %d") % [tr(corps.get(c, "normale")),
		int(Partie.stats.get("courses", 0)), Partie.missions_faites.size(), int(Partie.stats.get("amendes", 0))]
	info.add_theme_font_size_override("font_size", 17)
	_box.add_child(info)
	_button("Revenir", _back).grab_focus.call_deferred()
