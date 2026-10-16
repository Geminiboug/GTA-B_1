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


func _ready() -> void:
	layer = 5
	add_to_group("hud_jeu")
	_argent = _label(30, Color(0.55, 0.95, 0.55))
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
	_sante.offset_top = 268
	_sante.offset_right = 258
	_sante.offset_bottom = 276
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.8, 0.35)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	_sante.add_theme_stylebox_override("fill", fill)
	_sante.add_theme_stylebox_override("background", bg)
	_sante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sante)
	Partie.sante_change.connect(func(v: float) -> void: _sante.value = v)
	_sante.value = Partie.sante
	Partie.argent_change.connect(_on_argent)
	Partie.notification.connect(notifier)
	Partie.recherche_change.connect(_on_recherche)
	_on_argent(Partie.argent, 0)
	_on_recherche(Partie.recherche)


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
	_delta.visible = _delta_t > 0.0
	_annonce_t = maxf(0.0, _annonce_t - delta)
	_annonce.visible = _annonce_t > 0.0
	_sous.visible = _annonce_t > 0.0
	# etoiles qui clignotent tant que la police a le joueur en vue
	_clign += delta
	if Partie.recherche > 0:
		_etoiles.modulate.a = 0.55 + 0.45 * absf(sin(_clign * 4.0)) if Partie.get("police_voit") else 1.0
