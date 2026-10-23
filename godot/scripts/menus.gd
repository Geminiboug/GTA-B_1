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

MANETTE (disposition PlayStation)
Stick gauche bouger · stick droit caméra · Croix courir · Carré sauter · Rond ou R2 frapper · Triangle véhicule
L1 ou L2 viser · R1 arme suivante · L3 recharger · R3 s'accroupir · Haut téléphone · Gauche inventaire · Droite parler
Bas changer de vue · Share carte · Options pause · Pavé tactile héler un zem · Misc1 torche
En véhicule : R2 accélérer · L2 freiner · R1 frein à main · L3 klaxon · L1 limiteur"""

var _root: Control
var _aube: AubeCotonou          # fond de l'ecran titre (aube sur Cotonou) ; cache dans le menu pause
var _centre: CenterContainer
var _box: VBoxContainer
var _title: Label
var _page := ""
var _mode := ""      # "titre", "pause"


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("menus")
	# touches choisies par le joueur, aussi pour les actions creees par les autres scripts a leur _ready (armes...)
	Partie.appliquer_touches.call_deferred()
	_root = ColorRect.new()
	(_root as ColorRect).color = Color(0.02, 0.03, 0.05, 0.62)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_aube = AubeCotonou.new()
	_aube.set_anchors_preset(Control.PRESET_FULL_RECT)
	_aube.visible = false
	_root.add_child(_aube)
	var center := CenterContainer.new()
	_centre = center
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
	ecran.clip_contents = true
	# aube sur Cotonou (meme image que l'ecran titre et le chargement)
	var photo := AubeCotonou.new()
	photo.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran.add_child(photo)
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_bottom = -70
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	ecran.add_child(l)
	var barre := ProgressBar.new()
	barre.show_percentage = false
	barre.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	barre.custom_minimum_size = Vector2(420, 8)
	barre.offset_left = -210
	barre.offset_right = 210
	barre.offset_top = -50
	barre.offset_bottom = -42
	ecran.add_child(barre)
	add_child(ecran)
	var t := 0.0
	var stables := 0
	while t < preparation_max:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		stables = stables + 1 if d < 1.0 / preparation_ips else 0
		# animation au temps reel (les images peuvent etre lentes pendant la preparation)
		var u := t / preparation_max
		barre.value = 100.0 * (1.0 - exp(-3.0 * u))
		l.text = tr("Préparation du quartier") + ".".repeat(1 + int(t * 2.0) % 3)
		if t > 1.0 and stables >= 30 and Partie.taches_en_attente() == 0:
			break
	barre.value = 100.0
	print("Preparation : %.1f s" % t)
	Partie.suivre_saccades(30.0)
	apres.call()
	var tw := create_tween()
	tw.tween_property(ecran, "modulate:a", 0.0, 0.5)
	tw.tween_callback(ecran.queue_free)


var _ouverture_tw: Tween


func _unhandled_input(event: InputEvent) -> void:
	if _mode == "titre" and _page == "titre" and _centre.modulate.a < 0.99 and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		if _ouverture_tw:
			_ouverture_tw.kill()
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(_centre, "modulate:a", 1.0, 0.3)
		get_viewport().set_input_as_handled()
		return
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
	_title.visible = true
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
	_title.visible = false      # le logo de l'aube sur Cotonou remplace le mot GTB
	(_root as ColorRect).color = Color(0.02, 0.03, 0.05, 0.0)
	_aube.visible = true
	_aube.logo_y = 0.24
	_aube.logo_echelle = 0.62
	_aube.rejouer()
	_centre.modulate.a = 0.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(5.0)
	tw.tween_property(_centre, "modulate:a", 1.0, 0.8)
	_ouverture_tw = tw
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(560, 200)      # place du logo (dessine par l'aube)
	_box.add_child(logo)
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
	_aube.visible = false
	_centre.modulate.a = 1.0
	(_root as ColorRect).color = Color(0.02, 0.03, 0.05, 0.62)
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
	_button("Commandes (clavier et souris)", _show_touches)
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
	_clear(tr("Commandes (clavier et souris)"))
	var info := Label.new()
	info.text = tr("Clique sur une commande puis appuie sur la nouvelle touche ou le bouton de souris (Échap : annuler).")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 16)
	_box.add_child(info)
	if _message_touche != "":
		var m := Label.new()
		m.text = _message_touche
		m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m.add_theme_font_size_override("font_size", 16)
		m.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
		_box.add_child(m)
	var first: Button = null
	var grille := GridContainer.new()      # deux colonnes : toute la liste tient a l'ecran
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 10)
	_box.add_child(grille)
	for e in Partie.TOUCHES_REGLABLES:
		if not InputMap.has_action(e[0]):
			continue
		var action: String = e[0]
		var b := Button.new()
		b.text = "%s : %s" % [tr(e[1]), "…" if _attente_touche == action else Partie.nom_touche(action)]
		b.pressed.connect(func() -> void:
			_attente_touche = action
			_message_touche = ""
			_show_touches())
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(380, 34)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		grille.add_child(b)
		if first == null or _attente_touche == action:
			first = b
	_button("Touches par défaut", func() -> void:
		Partie.touches_par_defaut()
		_message_touche = tr("Touches d'origine remises.")
		_show_touches())
	_button("Revenir", _show_options)
	if first:
		first.grab_focus.call_deferred()


var _message_touche := ""


func _input(event: InputEvent) -> void:
	## Saisie de la nouvelle touche : une touche du clavier ou un bouton de souris. Si une autre commande l'utilisait
	## deja, les deux echangent leurs touches (jamais deux commandes sur la meme touche).
	if _attente_touche == "":
		return
	var ok: bool = (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo()
	if not ok:
		return
	get_viewport().set_input_as_handled()
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		_attente_touche = ""
		_show_touches.call_deferred()
		return
	var code: Variant = Partie.code_touche(event)
	var t: Dictionary = Partie.options.get("touches", {})
	var ancien: Variant = Partie.code_touche(_premier_evenement(_attente_touche))
	_message_touche = ""
	for e in Partie.TOUCHES_REGLABLES:
		var autre: String = e[0]
		if autre == _attente_touche or not InputMap.has_action(autre):
			continue
		var code_autre: Variant = Partie.code_touche(_premier_evenement(autre))
		# touche (entier) et bouton de souris (texte) ne se comparent pas directement
		if typeof(code_autre) == typeof(code) and code_autre == code and ancien != null:
			t[autre] = ancien
			_message_touche = tr("« %s » prend l'ancienne touche (%s).") % [tr(e[1]), Partie.nom_touche(_attente_touche)]
	t[_attente_touche] = code
	Partie.options["touches"] = t
	Partie.sauver_options()
	_attente_touche = ""
	# la page est redessinee a l'image suivante (le clic de souris ne doit pas activer un autre bouton)
	_show_touches.call_deferred()


func _premier_evenement(action: String) -> InputEvent:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			return ev
	return null


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
