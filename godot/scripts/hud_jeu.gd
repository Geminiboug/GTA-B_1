extends CanvasLayer
## HUD du jeu (facon GTA) : argent en haut a droite (gain / depense qui s'affiche un instant), niveau de recherche
## (etoiles), notifications a droite, objectif de mission en bas, grandes
## annonces (mission reussie, arrete...), barre de sante sous la mini-carte. Les autres scripts passent par le
## groupe "hud_jeu" (l'indication d'action reste dans hud_carte.gd : show_hint).

@export var notif_duree := 4.0

var _argent: Label
var _delta: Label
var _etoiles: Label
var _notifs: VBoxContainer
var _objectif: Label
var _annonce: Label
var _sous: Label
var _delta_t := 0.0
var _annonce_t := 0.0
var _clign := 0.0
var _sante: ProgressBar
var _armure: ProgressBar                 # blouson renforce : barre bleue sous la sante, cachee a zero
var _arme_lbl: Label                     # arme en main et munitions (bas a droite, a pied)
var _reticule: Label                     # croix de visee au centre (arme a feu, clic droit)
var _compteur: Label                     # vitesse en vehicule (bas a droite) et etat du limiteur (K)
# aide aux commandes (a gauche, sous la mini-carte) : selon la situation (a pied, zem, voiture) et l'appareil
# (clavier ou manette) ; affichee pendant les premieres minutes de jeu, F2 (manette : croix haut) l'affiche ou la cache
@export var aide_duree := 600.0          # s de jeu pendant lesquelles l'aide reste affichee
@export var aide_touche := KEY_F2
var _aide: Label
var _aide_on := true
var _aide_t := 0.0
var _manette := false
var _ctx := ""
var _player: Node
var _fill_sante: StyleBoxFlat


func options_changees() -> void:
	## Options appliquees depuis le menu : couleurs du mode daltonien sans relancer le jeu.
	var dalt: bool = bool(Partie.options.get("daltonisme", false))
	if _argent:
		_argent.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0) if dalt else Color(0.55, 0.95, 0.55))
	if _fill_sante:
		_fill_sante.bg_color = Color(0.3, 0.65, 1.0) if dalt else Color(0.35, 0.8, 0.35)


func _ready() -> void:
	layer = 5
	add_to_group("hud_jeu")
	add_to_group("options")
	var dalt: bool = bool(Partie.options.get("daltonisme", false))
	_argent = _label(30, Color(0.4, 0.85, 1.0) if dalt else Color(0.55, 0.95, 0.55))
	_argent.anchor_left = 1.0
	_argent.anchor_right = 1.0
	_argent.offset_left = -320
	_argent.offset_right = -24
	_argent.offset_top = 44          # sous l'horloge (scripts/hud_carte.gd)
	_argent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_delta = _label(22, Color(1, 1, 1))
	_delta.anchor_left = 1.0
	_delta.anchor_right = 1.0
	_delta.offset_left = -320
	_delta.offset_right = -24
	_delta.offset_top = 82
	_delta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_etoiles = _label(30, Color(1, 0.85, 0.2))
	_etoiles.anchor_left = 1.0
	_etoiles.anchor_right = 1.0
	_etoiles.offset_left = -320
	_etoiles.offset_right = -24
	_etoiles.offset_top = 108
	_etoiles.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notifs = VBoxContainer.new()
	_notifs.anchor_left = 1.0
	_notifs.anchor_right = 1.0
	_notifs.offset_left = -460
	_notifs.offset_right = -24
	_notifs.offset_top = 152
	_notifs.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(_notifs)
	_arme_lbl = _label(24, Color(1, 1, 1))
	_arme_lbl.anchor_left = 1.0
	_arme_lbl.anchor_right = 1.0
	_arme_lbl.anchor_top = 1.0
	_arme_lbl.anchor_bottom = 1.0
	_arme_lbl.offset_left = -420
	_arme_lbl.offset_right = -24
	_arme_lbl.offset_top = -70
	_arme_lbl.offset_bottom = -24
	_arme_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reticule = _label(30, Color(1, 1, 1, 0.9))
	_reticule.text = "+"
	_reticule.anchor_left = 0.5
	_reticule.anchor_right = 0.5
	_reticule.anchor_top = 0.5
	_reticule.anchor_bottom = 0.5
	_reticule.offset_left = -20
	_reticule.offset_right = 20
	_reticule.offset_top = -22
	_reticule.offset_bottom = 18
	_reticule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compteur = _label(26, Color(1, 1, 1))
	_compteur.anchor_left = 1.0
	_compteur.anchor_right = 1.0
	_compteur.anchor_top = 1.0
	_compteur.anchor_bottom = 1.0
	_compteur.offset_left = -760
	_compteur.offset_right = -24
	_compteur.offset_top = -96
	_compteur.offset_bottom = -24
	_compteur.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_compteur.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_objectif = _label(24, Color(1, 1, 1))
	_objectif.anchor_top = 1.0
	_objectif.anchor_bottom = 1.0
	_objectif.anchor_right = 1.0
	_objectif.offset_top = -120
	_objectif.offset_bottom = -84
	_objectif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce = _label(54, Color(1, 0.8, 0.2))
	_annonce.anchor_top = 0.3
	_annonce.anchor_bottom = 0.3
	_annonce.anchor_right = 1.0
	_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sous = _label(26, Color(1, 1, 1))
	_sous.anchor_top = 0.3
	_sous.anchor_bottom = 0.3
	_sous.anchor_right = 1.0
	_sous.offset_top = 70
	_sous.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# barre de sante sous la mini-carte (240 px, marge 18 : scripts/hud_carte.gd)
	_sante = ProgressBar.new()
	_sante.show_percentage = false
	_sante.offset_left = 18
	_sante.offset_top = 262
	_sante.offset_right = 258
	_sante.offset_bottom = 268
	var fill := StyleBoxFlat.new()
	_fill_sante = fill
	fill.bg_color = Color(0.3, 0.65, 1.0) if dalt else Color(0.35, 0.8, 0.35)   # daltonisme : pas de vert
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	_sante.add_theme_stylebox_override("fill", fill)
	_sante.add_theme_stylebox_override("background", bg)
	_sante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sante)
	Partie.sante_change.connect(func(v: float) -> void: _sante.value = v)
	_sante.value = Partie.sante
	_armure = ProgressBar.new()
	_armure.show_percentage = false
	_armure.offset_left = 18
	_armure.offset_top = 271
	_armure.offset_right = 258
	_armure.offset_bottom = 276
	var fa := StyleBoxFlat.new()
	fa.bg_color = Color(0.92, 0.92, 0.92) if dalt else Color(0.35, 0.6, 0.95)
	_armure.add_theme_stylebox_override("fill", fa)
	_armure.add_theme_stylebox_override("background", bg)
	_armure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_armure)
	var maj_armure := func(v: float) -> void:
		_armure.value = v
		_armure.visible = v > 0.0
	Partie.armure_change.connect(maj_armure)
	maj_armure.call(Partie.armure)
	Partie.argent_change.connect(_on_argent)
	Partie.notification.connect(notifier)
	Partie.recherche_change.connect(_on_recherche)
	_on_argent(Partie.argent, 0)
	_on_recherche(Partie.recherche)
	_aide = _label(17, Color(1, 1, 1))
	_aide.offset_left = 18
	_aide.offset_top = 326
	_aide.offset_right = 420
	var ab := StyleBoxFlat.new()
	ab.bg_color = Color(0, 0, 0, 0.45)
	ab.set_content_margin_all(8)
	ab.set_corner_radius_all(4)
	_aide.add_theme_stylebox_override("normal", ab)
	_aide.add_theme_constant_override("outline_size", 4)
	_manette = Input.get_connected_joypads().size() > 0
	_player = get_node_or_null("../Player")


func _input(event: InputEvent) -> void:
	# appareil utilise en dernier : clavier / souris ou manette (sans consommer l'evenement)
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.4):
		_manette = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_manette = false
	# a la manette l'aide s'efface seule (la croix haut ouvre le telephone)
	var bascule: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == aide_touche
	if bascule:
		_aide_on = not _aide_on
		_aide_t = 0.0 if _aide_on else _aide_t


func contexte() -> String:
	## "pied", "zem" ou "voiture" selon le vehicule du joueur.
	var v: Node = _player.get("vehicle") if _player else null
	if v == null:
		return "pied"
	if v.get("kind") == "avion":
		return "avion"
	return "zem" if v.get("kind") == "zem" else "voiture"


func texte_aide(ctx: String, manette: bool) -> String:
	var l: PackedStringArray
	if manette:
		match ctx:
			"pied":
				l = ["Stick gauche : marcher (l'inclinaison règle l'allure)", "Stick droit : caméra", "Croix : courir (tapoter)", "Carré : sauter / escalader",
					"R3 : s'accroupir", "Triangle : monter / descendre d'un véhicule", "Rond ou R2 : frapper / tirer", "L1 ou L2 : viser / se protéger",
					"R1 : arme suivante   L3 : recharger", "Croix directionnelle : haut téléphone, gauche inventaire, droite parler, bas vue",
					"Share : carte   Options : pause", "Pavé tactile : héler un zem   Misc1 : torche"]
			"zem":
				l = ["R2 : accélérer   L2 : freiner", "Stick gauche : tourner", "R1 : frein arrière", "L3 : klaxon",
					"Triangle : descendre", "Droite : chercher un client", "L1 : limiteur 50 km/h", "Bas : changer de vue"]
			"avion":
				l = ["R2 : gaz +   L2 : gaz - / freins", "Stick gauche : tangage et roulis", "Gauche / droite : palonnier", "R1 : freins de roues", "Triangle : descendre (à l'arrêt)"]
			_:
				l = ["R2 : accélérer   L2 : freiner / reculer", "Stick gauche : tourner", "R1 : frein à main", "L3 : klaxon",
					"Triangle : descendre", "L1 : limiteur 50 km/h", "Bas : changer de vue"]
	else:
		# touches reelles (Options > Commandes : elles peuvent avoir ete changees)
		var k := func(a: String) -> String: return Partie.nom_touche(a)
		var dep := "%s %s %s %s" % [k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right")]
		var t := func(touche: String, quoi: String) -> String: return "%s : %s" % [touche, tr(quoi)]
		match ctx:
			"pied":
				l = [t.call(dep, "marcher"), t.call(tr("Souris"), "caméra"),
					t.call(k.call("sprint"), "courir (tapoter)") + "   " + t.call(k.call("walk"), "marche lente"),
					t.call(k.call("jump"), "sauter / escalader"), t.call(k.call("crouch"), "s'accroupir"),
					t.call(k.call("interact"), "monter dans un véhicule") + "   " + t.call(k.call("heler"), "héler un zem"), t.call(k.call("parler"), "parler / acheter"),
					t.call(k.call("map"), "carte") + "   " + t.call(k.call("camera_vue"), "vue"),
					t.call(k.call("inventaire"), "inventaire") + "   " + t.call(k.call("telephone"), "téléphone") + "   " + t.call(k.call("torche"), "torche"),
					t.call(k.call("arme_suivante"), "arme") + "   " + t.call(k.call("garde"), "viser") + "   " + t.call(k.call("recharger"), "recharger")]
			"avion":
				l = [t.call(k.call("accelerate"), "gaz +") + "   " + t.call(k.call("brake"), "gaz - / freins"),
					t.call(k.call("move_forward"), "piquer") + "   " + t.call(k.call("move_back"), "cabrer"),
					t.call(k.call("move_left") + " " + k.call("move_right"), "incliner / tourner au sol"),
					t.call(k.call("lacet_g") + " " + k.call("lacet_d"), "palonnier"), t.call(k.call("handbrake"), "freins de roues"),
					t.call(k.call("camera_vue"), "vue cockpit"), t.call(k.call("interact"), "descendre (à l'arrêt)")]
			"zem":
				l = [t.call(k.call("accelerate"), "accélérer") + "   " + t.call(k.call("brake"), "freiner"),
					t.call(k.call("move_left") + " " + k.call("move_right"), "tourner"), t.call(k.call("handbrake"), "frein arrière"),
					t.call(k.call("horn"), "klaxon"), t.call(k.call("interact"), "descendre"),
					t.call(k.call("parler"), "chercher un client (à l'arrêt)"), t.call(k.call("limiteur"), "limiteur 50 km/h")]
			_:
				l = [t.call(k.call("accelerate"), "accélérer") + "   " + t.call(k.call("brake"), "freiner / reculer"),
					t.call(k.call("move_left") + " " + k.call("move_right"), "tourner"), t.call(k.call("handbrake"), "frein à main"),
					t.call(k.call("horn"), "klaxon"), t.call(k.call("interact"), "descendre"), t.call(k.call("limiteur"), "limiteur 50 km/h")]
		l.append("F2" + tr(" : cacher l'aide"))
		return "\n".join(l)
	for i in l.size():
		l[i] = tr(l[i])
	return "\n".join(l)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _on_argent(total: int, delta: int) -> void:
	_argent.text = Partie.fcfa(total)
	if delta != 0:
		_delta.text = ("+" if delta > 0 else "-") + Partie.fcfa(absi(delta))
		_delta.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if delta > 0 else Color(1, 0.45, 0.4))
		_delta_t = 2.5


func _on_recherche(n: int) -> void:
	_etoiles.text = "★".repeat(n) + "☆".repeat(6 - n) if n > 0 else ""


func notifier(texte: String) -> void:
	var l := _label(20, Color(1, 1, 1))
	remove_child(l)
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notifs.add_child(l)
	while _notifs.get_child_count() > 5:
		_notifs.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(notif_duree)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func objectif(texte: String) -> void:
	_objectif.text = texte


func annonce(titre: String, sous := "", duree := 3.5) -> void:
	_annonce.text = titre
	_sous.text = sous
	_annonce_t = duree


func _process(delta: float) -> void:
	_delta_t = maxf(0.0, _delta_t - delta)
	var veh: Node3D = _player.get("vehicle") if _player else null
	var ar := get_node_or_null("../Armes")
	var nom: String = ar.arme if ar else ""
	_arme_lbl.visible = nom != "" and veh == null and Partie.get("en_jeu") != false
	if _arme_lbl.visible:
		var a: Dictionary = ar.ARMES[nom]
		_arme_lbl.text = tr(nom) + ("   %d / %d" % [ar.chargeur.get(nom, 0), Partie.inventaire.get(a["munition"], 0)] if a["type"] == "feu" else "")
	_reticule.visible = _player != null and bool(_player.get("visee"))
	if _reticule.visible:
		_reticule.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if ar and not (ar.cible as Dictionary).is_empty() else Color(1, 1, 1, 0.9))
	_compteur.visible = veh != null and Partie.get("en_jeu") != false
	if _compteur.visible:
		var kmh := roundi(absf(float(veh.get("speed"))) * 3.6)
		var jauge := ""
		if veh.get("carburant") != null:
			var pc := roundi(100.0 * float(veh.get("carburant")) / maxf(float(veh.get("reservoir")), 1.0))
			jauge = "   " + tr("Essence %d %%") % pc + (" !" if pc < 15 else "")
		if veh.has_method("info_hud"):
			_compteur.text = veh.info_hud()
			var carte := get_parent().get_node_or_null("HUD") if get_parent() else null
			if veh.has_method("conseil") and carte and carte.has_method("show_hint") and bool(Partie.options.get("conseils_vol", true)):
				var c: String = veh.conseil()
				if c != "":
					carte.call("show_hint", c)
		else:
			_compteur.text = "%d km/h" % kmh + jauge + ("
" + tr("LIMITEUR %d (K)") % roundi(Limiteur.vitesse_kmh) if Limiteur.actif else "
" + tr("K : limiteur"))
		_compteur.add_theme_color_override("font_color", Color(0.55, 0.95, 0.55) if Limiteur.actif else Color(1, 1, 1))
	_delta.visible = _delta_t > 0.0
	if _aide_on:
		_aide_t += delta
		if _aide_t > aide_duree:
			_aide_on = false
	var inv := get_node_or_null("../Inventaire")
	var tact := get_node_or_null("../Tactile")
	_aide.visible = _aide_on and Partie.get("en_jeu") != false and not (inv and inv.get("ouvert")) and not (tact and tact.get("actif"))
	if _aide.visible:
		var ctx := contexte() + ("_m" if _manette else "")
		if ctx != _ctx:
			_ctx = ctx
			_aide.text = texte_aide(contexte(), _manette)
	_annonce_t = maxf(0.0, _annonce_t - delta)
	_annonce.visible = _annonce_t > 0.0
	_sous.visible = _annonce_t > 0.0
	# comme San Andreas : etoiles fixes tant qu on est poursuivi, qui clignotent vite quand la police a perdu la trace
	_clign += delta
	if Partie.recherche > 0:
		_etoiles.modulate.a = (1.0 if int(_clign * 6.0) % 2 == 0 else 0.15) if Partie.recherche_clignote else 1.0
