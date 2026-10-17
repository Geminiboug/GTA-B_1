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


func _ready() -> void:
	layer = 5
	add_to_group("hud_jeu")
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
	_compteur.offset_left = -360
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
	var bascule: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == aide_touche) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_UP)
	if bascule:
		_aide_on = not _aide_on
		_aide_t = 0.0 if _aide_on else _aide_t


func contexte() -> String:
	## "pied", "zem" ou "voiture" selon le vehicule du joueur.
	var v: Node = _player.get("vehicle") if _player else null
	if v == null:
		return "pied"
	return "zem" if v.get("kind") == "zem" else "voiture"


func texte_aide(ctx: String, manette: bool) -> String:
	var l: PackedStringArray
	if manette:
		match ctx:
			"pied":
				l = ["Stick gauche : marcher", "Stick droit : caméra", "A (tapoter) : courir", "X : sauter / escalader",
					"R3 : s'accroupir", "Y : monter dans un véhicule", "Croix droite : parler / acheter", "Select : carte   Croix bas : vue", "Croix gauche : inventaire (téléphone, torche)", "RB : arme   LB : viser   L3 : recharger"]
			"zem":
				l = ["RT : accélérer   LT : freiner", "Stick gauche : tourner", "RB : frein arrière", "L3 : klaxon",
					"Y : descendre", "Croix droite : chercher un client", "Croix bas : limiteur 50 km/h"]
			_:
				l = ["RT : accélérer   LT : freiner / reculer", "Stick gauche : tourner", "RB : frein à main",
					"Y : descendre", "Croix bas : limiteur 50 km/h"]
	else:
		match ctx:
			"pied":
				l = ["Z Q S D : marcher", "Souris : caméra", "Maj (tapoter) : courir   Alt : marche lente",
					"Espace : sauter / escalader", "C : s'accroupir", "E : monter dans un véhicule", "T : parler / acheter",
					"M : carte   V : vue", "I : inventaire   P : téléphone   L : torche", "Tab : arme   clic droit : viser   R : recharger"]
			"zem":
				l = ["Z : accélérer   S : freiner", "Q D : tourner", "Espace : frein arrière", "H : klaxon",
					"E : descendre", "T : chercher un client (à l'arrêt)", "K : limiteur 50 km/h"]
			_:
				l = ["Z : accélérer   S : freiner / reculer", "Q D : tourner", "Espace : frein à main", "H : klaxon",
					"E : descendre", "K : limiteur 50 km/h"]
	l.append(tr("Croix haut") if manette else "F2")
	l[-1] += tr(" : cacher l'aide")
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
	_etoiles.text = "★".repeat(n) + "☆".repeat(5 - n) if n > 0 else ""


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
		_compteur.text = "%d km/h" % kmh + ("
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
	# etoiles qui clignotent tant que la police a le joueur en vue
	_clign += delta
	if Partie.recherche > 0:
		_etoiles.modulate.a = 0.55 + 0.45 * absf(sin(_clign * 4.0)) if Partie.get("police_voit") else 1.0
