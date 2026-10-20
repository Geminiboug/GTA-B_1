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
	_preparer(func() -> void: get_tree().call_group("histoire", "commencer"))


## Apres l'ecran titre, le joueur est pose ailleurs que la ou le chargement a tout prepare (debut de l'histoire,
## sauvegarde) : tuiles, decor, passants et matieres de ce nouvel endroit arrivent d'un coup et les premieres
## secondes saccadent. Un ecran opaque reste le temps que les images redeviennent regulieres, puis le jeu commence.
@export var preparation_ips := 45.0     # images par seconde a tenir 30 images de suite
@export var preparation_max := 15.0     # s : au-dela, l'ecran part quand meme
const FOND_PREPARATION := Color(0.0902, 0.0784, 0.0588)


func _preparer(apres: Callable) -> void:
	if get_tree().current_scene != get_parent():
		apres.call()      # tests : scene lancee par un script
		return
	var ecran := ColorRect.new()
	ecran.color = FOND_PREPARATION
	ecran.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := Label.new()
	l.text = tr("Préparation du quartier…")
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.add_theme_font_size_override("font_size", 28)
	ecran.add_child(l)
	add_child(ecran)
	var t := 0.0
	var stables := 0
	while t < preparation_max:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		stables = stables + 1 if d < 1.0 / preparation_ips else 0
		if t > 1.0 and stables >= 30 and Partie.taches_en_attente() == 0:
			break
	print("Preparation : %.1f s" % t)
	Partie.suivre_saccades(30.0)
	apres.call()
	var tw := create_tween()
	tw.tween_property(ecran, "modulate:a", 0.0, 0.5)
	tw.tween_callback(ecran.queue_free)


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
		Partie.charger_emplacement(get_parent(), Partie.dernier_emplacement())
		_preparer(func() -> void: get_tree().call_group("histoire", "reprendre")), Partie.existe_sauvegarde())
	_button("Charger une partie", func() -> void: _show_emplacements(false), Partie.existe_sauvegarde())
	_button("Options", _show_options)
	_button("Crédits", _show_credits)
	_button("Quitter", func() -> void: get_tree().quit())
	first.grab_focus.call_deferred()


func _show_pause() -> void:
	_page = "principal"
	_clear("Pause")
	var first := _button("Reprendre", _close)
	var can_save: bool = Partie.recherche == 0
	_button("Sauvegarder" if can_save else "Sauvegarder (impossible : recherché)", func() -> void: _show_emplacements(true), can_save)
	_button("Charger une partie", func() -> void: _show_emplacements(false), Partie.existe_sauvegarde())
	_button("Options", _show_options)
	_button("Statistiques", _show_stats)
	_button("Succès", _show_succes)
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
	_slider("Véhicules", o.get("vol_vehicules", 1.0), 0.0, 1.0, func(v: float) -> void: o["vol_vehicules"] = v)
	_slider("Ambiance (ville, mer, pluie)", o.get("vol_ambiance", 1.0), 0.0, 1.0, func(v: float) -> void: o["vol_ambiance"] = v)
	_slider("Effets et voix", o.get("vol_effets", 1.0), 0.0, 1.0, func(v: float) -> void: o["vol_effets"] = v)
	_slider("Sensibilité de la souris", o["sensibilite"], 0.3, 2.5, func(v: float) -> void: o["sensibilite"] = v)
	_check("Effets de caméra (recentrage, secousses)", o["effets_camera"], func(v: bool) -> void: o["effets_camera"] = v)
	_check("Plein écran", o["plein_ecran"], func(v: bool) -> void: o["plein_ecran"] = v)
	_check("Sous-titres", o.get("sous_titres", true), func(v: bool) -> void: o["sous_titres"] = v)
	_slider("Taille des sous-titres", o.get("taille_sous_titres", 26), 18, 44, func(v: float) -> void: o["taille_sous_titres"] = int(v))
	_slider("Taille de l'interface", o.get("taille_interface", 1.0), 0.8, 1.6, func(v: float) -> void: o["taille_interface"] = v)
	_check("Aide à la visée (souris)", o.get("aide_visee", true), func(v: bool) -> void: o["aide_visee"] = v)
	_button("Touches du clavier", _show_touches)
	_check("Couleurs adaptées au daltonisme", o.get("daltonisme", false), func(v: bool) -> void: o["daltonisme"] = v)
	_check("Violence réduite (armes moins puissantes)", o.get("violence_reduite", false), func(v: bool) -> void: o["violence_reduite"] = v)
	var rl := HBoxContainer.new()
	var ll := Label.new()
	ll.text = "Langue / Language"
	ll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ll.add_theme_font_size_override("font_size", 20)
	rl.add_child(ll)
	var ol := OptionButton.new()
	var codes := ["auto", "fr", "en"]
	for n in ["Automatique", "Français", "English"]:
		ol.add_item(n)
	ol.selected = maxi(codes.find(String(o.get("langue", "auto"))), 0)
	ol.item_selected.connect(func(i: int) -> void:
		o["langue"] = codes[i]
		_apercu()
		_show_options.call_deferred())   # la page se redessine dans la nouvelle langue
	rl.add_child(ol)
	_box.add_child(rl)
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
	ob.item_selected.connect(func(i: int) -> void:
		o["qualite"] = i
		_apercu())
	row.add_child(ob)
	_box.add_child(row)
	_button("Appliquer et revenir", func() -> void:
		Partie.sauver_options()
		_back()).grab_focus.call_deferred()


func _apercu() -> void:
	## Chaque reglage s'applique tout de suite (son, image, couleurs) ; "Appliquer" l'enregistre.
	if _page == "options":
		Partie.appliquer_options()


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
	s.value_changed.connect(func(_v: float) -> void: _apercu())
	row.add_child(s)
	_box.add_child(row)


func _check(text: String, value: bool, cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 20)
	c.toggled.connect(cb)
	c.toggled.connect(func(_v: bool) -> void: _apercu())
	_box.add_child(c)


var _attente_touche := ""


func _show_touches() -> void:
	## Reaffectation des touches : cliquer sur une action puis appuyer sur la nouvelle touche (Echap annule).
	_page = "touches"
	_clear(tr("Touches du clavier"))
	for e in Partie.TOUCHES_REGLABLES:
		var nom := ""
		for ev in InputMap.action_get_events(e[0]) if InputMap.has_action(e[0]) else []:
			if ev is InputEventKey:
				nom = OS.get_keycode_string((ev as InputEventKey).physical_keycode if (ev as InputEventKey).physical_keycode != 0 else (ev as InputEventKey).keycode)
				break
		var action: String = e[0]
		_button("%s : %s" % [tr(e[1]), "…" if _attente_touche == action else nom], func() -> void:
			_attente_touche = action
			_show_touches())
	_button("Touches par défaut", func() -> void:
		Partie.options["touches"] = {}
		Partie.sauver_options()
		for e in Partie.TOUCHES_REGLABLES:
			var defaut = ProjectSettings.get_setting("input/" + String(e[0]))
			if defaut is Dictionary and InputMap.has_action(e[0]):
				InputMap.action_erase_events(e[0])
				for ev in defaut["events"]:
					InputMap.action_add_event(e[0], ev)
		_show_touches())
	_button("Revenir", _show_options)


func _input(event: InputEvent) -> void:
	if _attente_touche == "" or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var k := event as InputEventKey
	if k.keycode != KEY_ESCAPE:
		var t: Dictionary = Partie.options.get("touches", {})
		t[_attente_touche] = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		Partie.options["touches"] = t
		Partie.sauver_options()
	_attente_touche = ""
	_show_touches()


func _show_succes() -> void:
	_page = "succes"
	var sc := get_parent().get_node_or_null("Succes") if get_parent() else null
	_clear(tr("Succès"))
	if sc:
		var n := 0
		for e in sc.LISTE:
			var l := Label.new()
			var ok: bool = sc.obtenus.has(e[0])
			n += 1 if ok else 0
			l.text = ("✓  " if ok else "·  ") + tr(e[1]) + "  —  " + tr(e[2])
			l.add_theme_font_size_override("font_size", 18)
			l.add_theme_color_override("font_color", Color(1, 0.85, 0.3) if ok else Color(0.7, 0.7, 0.7))
			_box.add_child(l)
		var tot := Label.new()
		tot.text = tr("%d / %d succès") % [n, sc.LISTE.size()]
		tot.add_theme_font_size_override("font_size", 20)
		_box.add_child(tot)
	_button("Revenir", _back).grab_focus.call_deferred()


func _show_emplacements(sauver: bool) -> void:
	## Trois emplacements de sauvegarde, avec chapitre, missions, argent et date.
	_page = "emplacements"
	_clear(tr("Sauvegarder") if sauver else tr("Charger une partie"))
	var first: Button = null
	for i in range(1, Partie.EMPLACEMENTS + 1):
		var occupe := FileAccess.file_exists(Partie.chemin_emplacement(i))
		var b := _button("%d.  %s" % [i, Partie.resume_emplacement(i)], func() -> void:
			if sauver:
				Partie.sauver_emplacement(get_parent(), i)
				_close()
			else:
				_close()
				Partie.charger_emplacement(get_parent(), i)
				get_tree().call_group("histoire", "reprendre"), sauver or occupe)
		if first == null and not b.disabled:
			first = b
	_button("Revenir", _back)
	if first:
		first.grab_focus.call_deferred()


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
	var ac := get_parent().get_node_or_null("Activites") if get_parent() else null
	if ac:
		var cp := Label.new()
		cp.text = tr("Progression du jeu : %d %%    Fresques : %d / %d") % [roundi(ac.completion()), ac.fresques_trouvees().size(), ac.NB_FRESQUES]
		cp.add_theme_font_size_override("font_size", 20)
		_box.add_child(cp)
	var info := Label.new()
	var corps := {"mince": "mince", "": "normale", "fort": "costaud"}
	var c: String = st.morpho() if st else ""
	info.text = tr("Silhouette : %s    Courses de zem : %d    Missions : %d    Amendes : %d") % [tr(corps.get(c, "normale")),
		int(Partie.stats.get("courses", 0)), Partie.missions_faites.size(), int(Partie.stats.get("amendes", 0))]
	info.add_theme_font_size_override("font_size", 17)
	_box.add_child(info)
	_button("Revenir", _back).grab_focus.call_deferred()
