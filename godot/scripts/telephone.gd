extends CanvasLayer
## Smartphone du joueur (dans l'inventaire au depart) : P, ou Inventaire > Smartphone (manette : croix gauche puis A).
## Ecran en bas a droite, comme dans les GTA : heure de jeu, meteo, argent ; applications :
## - Messages : objectif en cours et dernieres repliques entendues (scripts/histoire.gd) ;
## - Carte : ouvre la grande carte (scripts/hud_carte.gd) ;
## - Zem : un zem vient te chercher ou que tu sois (deplacement rapide de scripts/taxi.gd, + frais d'appel) ;
## - Contacts : appeler les personnages de l'histoire ;
## - Appareil photo : mode photo (scripts/mode_photo.gd).
## Haut / bas choisir, Entree (A) ouvrir, Retour arriere / Echap (B) revenir, P fermer. Le jeu continue.

@export var touche := KEY_P
@export var frais_appel_zem := 100       # FCFA en plus de la course quand on appelle un zem

const APPS := ["Messages", "Carte", "Zem", "Contacts", "Appareil photo"]
const NOMS := {"tante": "Tante Mireille", "codjo": "Vieux Codjo", "patronne": "Maman Fifi", "commandant": "Le commandant",
	"client": "Client", "joueur": "Moi", "etal": "Vendeuse", "femme_ronde": "Voisine", "homme_age": "Le vieux"}
const CONTACTS := [
	["Tante Mireille", ["Allô ? Tu as mangé ? Reviens avant la nuit.", "Ne traîne pas sur la plage le soir, hein."]],
	["Vieux Codjo", ["Le moteur de ton père, je le reconnaîtrais entre mille.", "Passe me voir, j'ai peut-être du travail."]],
	["Maman Fifi", ["Le maquis est ouvert jusqu'à minuit !", "Si tu as faim, viens, il reste de la pâte."]],
]

var ouvert := false
var _app := ""
var _sel := 0
var _rows: Array = []
var _panel: PanelContainer
var _head: Label
var _title: Label
var _list: VBoxContainer
var _foot: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 7
	_rng.randomize()
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -340
	_panel.offset_right = -24
	_panel.offset_top = -560
	_panel.offset_bottom = -24
	_panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.1, 0.95)
	sb.border_color = Color(0.02, 0.02, 0.02)
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(26)
	sb.set_content_margin_all(18)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_panel.add_child(col)
	_head = Label.new()
	_head.clip_text = true
	_head.custom_minimum_size = Vector2(270, 0)
	_head.add_theme_font_size_override("font_size", 14)
	_head.add_theme_color_override("font_color", Color(0.8, 0.82, 0.86))
	col.add_child(_head)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(1, 0.82, 0.25))
	col.add_child(_title)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(270, 0)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	sc.add_child(_list)
	_foot = Label.new()
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot.custom_minimum_size = Vector2(270, 0)
	_foot.add_theme_font_size_override("font_size", 13)
	_foot.add_theme_color_override("font_color", Color(0.55, 0.57, 0.6))
	col.add_child(_foot)


func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == touche:
		if ouvert or Partie.a("Smartphone"):
			ouvrir(not ouvert)
		get_viewport().set_input_as_handled()
		return
	if not ouvert:
		return
	var up: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_UP) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_UP)
	var down: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_DOWN) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_DPAD_DOWN)
	var ok: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)
	var back: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_BACKSPACE) or event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if up or down:
		if not _rows.is_empty():
			_sel = wrapi(_sel + (1 if down else -1), 0, _rows.size())
			_draw()
	elif ok:
		choisir(_sel)
	elif back:
		if _app == "":
			ouvrir(false)
		else:
			_app = ""
			_sel = 0
			_draw()
	else:
		return
	get_viewport().set_input_as_handled()


func ouvrir(on: bool) -> void:
	ouvert = on and Partie.a("Smartphone")
	var inv := get_node_or_null("../Inventaire")
	if ouvert and inv and inv.get("ouvert"):
		inv.ouvrir(false)
	_panel.visible = ouvert
	_app = ""
	_sel = 0
	if ouvert:
		_draw()


func app(nom: String) -> void:
	## Ouvre directement une application (tests, raccourcis).
	if not ouvert:
		ouvrir(true)
	_app = nom
	_sel = 0
	_draw()


func choisir(i: int) -> void:
	if _app == "":
		if i < APPS.size():
			var a: String = APPS[i]
			if a == "Carte":
				ouvrir(false)
				var hc := get_node_or_null("../HUD")
				if hc and hc.has_method("open_map"):
					hc.open_map(true)
			elif a == "Appareil photo":
				ouvrir(false)
				var ph := get_node_or_null("../ModePhoto")
				if ph:
					ph.entrer()
			else:
				app(a)
		return
	match _app:
		"Zem":
			var taxi := get_node_or_null("../Taxi")
			var pl := get_node_or_null("../Player")
			if taxi == null or i >= taxi.DESTINATIONS.size():
				return
			if pl and pl.get("vehicle") != null:
				Partie.notifier(tr("Descends d'abord du véhicule"))
				return
			if Partie.argent < taxi.prix(i) + frais_appel_zem:
				Partie.notifier(tr("Pas assez d'argent pour la course"))
				return
			ouvrir(false)
			if taxi.voyager(i):
				Partie.prelever(frais_appel_zem, "Appel du zem")
		"Contacts":
			if i < CONTACTS.size():
				var c: Array = CONTACTS[i]
				var pl := get_node_or_null("../Player") as Node3D
				var lignes: Array = c[1]
				if pl:
					Bulle.say(pl, "« %s »" % tr(lignes[_rng.randi() % lignes.size()]), 3.5, 2.15, Color(0.75, 0.9, 1.0))
				Partie.notifier(tr("Appel : %s") % tr(c[0]))
				ouvrir(false)


func _heure() -> String:
	var jn := get_node_or_null("../JourNuit")
	var h := float(jn.get("hour")) if jn else 12.0
	var met := get_node_or_null("../Meteo")
	var rain := float(met.get("rain")) if met and met.get("rain") != null else 0.0
	var temps := tr("Pluie") if rain > 0.3 else (tr("Nuit claire") if h < 6.0 or h > 19.0 else tr("Ensoleillé"))
	return "%02d:%02d    %s    %s" % [int(h), int(fmod(h, 1.0) * 60.0), temps, Partie.fcfa(Partie.argent)]


func _row(text: String, i: int, size := 19) -> void:
	var l := Label.new()
	l.text = ("> " if i == _sel else "   ") + text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
	l.add_theme_font_size_override("font_size", size)
	if i == _sel:
		l.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	_list.add_child(l)
	_rows.append(text)


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
	l.add_theme_font_size_override("font_size", 16)
	_list.add_child(l)


func _draw() -> void:
	_head.text = _heure()
	for c in _list.get_children():
		c.free()
	_rows.clear()
	_foot.text = tr("Haut / Bas · Entrée ouvrir · Retour revenir · P fermer")
	match _app:
		"":
			_title.text = "GTB Phone"
			for i in APPS.size():
				_row(tr(APPS[i]), i, 21)
		"Messages":
			_title.text = tr("Messages")
			var h := get_node_or_null("../Histoire")
			var obj: String = h.objectif_actuel() if h and h.has_method("objectif_actuel") else ""
			_note(tr("Objectif : %s") % (tr(obj) if obj != "" else tr("aucun pour l'instant")))
			var msgs: Array = h.get("messages") if h and h.get("messages") != null else []
			if msgs.is_empty():
				_note(tr("Pas de nouveau message."))
			for k in range(msgs.size() - 1, maxi(-1, msgs.size() - 9), -1):
				var m: Array = msgs[k]
				_note("%s : %s" % [tr(NOMS.get(m[0], m[0])), tr(m[1])])
		"Zem":
			_title.text = tr("Zem à la demande")
			var taxi := get_node_or_null("../Taxi")
			if taxi:
				for i in taxi.DESTINATIONS.size():
					_row("%s   %s" % [tr(taxi.DESTINATIONS[i][0]), Partie.fcfa(taxi.prix(i) + frais_appel_zem)], i, 17)
		"Contacts":
			_title.text = tr("Contacts")
			for i in CONTACTS.size():
				_row(tr(CONTACTS[i][0]), i)


func _process(_d: float) -> void:
	if ouvert:
		_head.text = _heure()
