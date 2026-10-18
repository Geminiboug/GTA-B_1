extends Node
## Ecran de chargement (scene de demarrage) : charge la zone en tache de fond et montre un carrousel de vraies captures
## du jeu (fondu enchaine, leger zoom), le logo GTB, le nom du lieu, une astuce et la progression.
## Etapes : 1) chargement de la scene (ResourceLoader en fond) : vraie progression en % ;
## 2) construction des noeuds de la zone (instanciation dans un fil de travail) : pas de % connu, barre animee ;
## 3) entree dans la zone (change_scene_to_node, la zone devient current_scene comme avant), puis fondu de sortie.
## L'interface vit dans un CanvasLayer rattache a la racine pendant le passage, pour rester visible jusqu'au fondu.

const ZEM := Color("#F2BB2C")
const TITRE := Color("#FFD140")
const LATERITE := Color("#B0472B")
const LATERITE_CLAIRE := Color("#E0714F")
const NUIT := Color("#17140F")
const SABLE := Color("#F6F1E7")
const POUSSIERE := Color("#6C6457")
const VERT := Color("#008751")

## Captures du jeu (1280x720, prises avec l'interface) : la zone garde le cadre sans la mini-carte (haut gauche),
## l'heure et l'argent (haut droite)
const DIAPOS := [
	{"img": "res://assets/ui/chargement/epave_plage.png", "zone": Rect2(262, 48, 1018, 672), "lieu": "L'ÉPAVE VOLANTE"},
	{"img": "res://assets/ui/chargement/quartiers_vues.png", "zone": Rect2(772, 48, 508, 312), "lieu": "LES QUARTIERS"},
	{"img": "res://assets/ui/chargement/vehicules_plage.png", "zone": Rect2(262, 48, 1018, 672), "lieu": "LA PLAGE"},
	{"img": "res://assets/ui/chargement/minibus_plage.png", "zone": Rect2(262, 48, 1018, 672), "lieu": "LA PLAGE"},
]
const ASTUCES := [
	"Le zem est bien plus qu'un moyen de transport : à Gbê Town, c'est une institution.",
	"Vers 16 h, une fanfare annonce des funérailles. Accompagner le cortège, c'est gagner le respect du quartier.",
	"Pendant un délestage, les rues s'assombrissent : la torche de ton sac devient précieuse.",
	"Vingt sacs de cauris sont cachés dans les recoins du quartier. Ouvre l'œil.",
	"Dans la foule du marché, la police a du mal à te suivre.",
	"Un voyageur attend devant l'aérogare ? Une course de zem, c'est de l'argent vite gagné.",
	"Au volant d'un minibus, lance une ligne : chaque passager paie sa place.",
	"Le sable de la plage freine les roues : vas-y doucement.",
]

@export_file("*.tscn") var scene_jeu := "res://scenes/zone_aeroport.tscn"
@export var duree_diapo := 5.5           # s par image
@export var duree_fondu := 1.2           # s de fondu enchaine
@export var zoom_diapo := 0.06           # zoom lent sur chaque image (6 %)
@export var instancier_en_fond := false  # true : construit la zone dans un fil de travail (bien plus lent : chaque appel graphique attend une image)
@export var sous_fils := false        # sous-fils du ResourceLoader (plus lent sur certains disques)

var etape := "chargement"                # chargement, construction, entree, fini, erreur
var progression := 0.0                   # 0..1 (etape chargement), -1 = inconnue
var _ui: CanvasLayer
var _cadre: Control
var _img: Array[TextureRect] = []
var _cur := 0
var _diapo := 0
var _t_diapo := 0.0
var _lieu: Label
var _astuce: Label
var _etat: Label
var _pct: Label
var _barre: Control
var _roue: Control
var _paquet: PackedScene
var _zone: Node
var _tache := -1
var _rng := RandomNumberGenerator.new()
var _t0 := Time.get_ticks_msec()


func _ready() -> void:
	_rng.randomize()
	_construire_ui()
	_montrer(0, true)
	_astuce.text = tr(ASTUCES[_rng.randi() % ASTUCES.size()])
	if ResourceLoader.load_threaded_request(scene_jeu, "", sous_fils) != OK:
		_echec()


func _process(delta: float) -> void:
	_animer(delta)
	match etape:
		"chargement":
			var p := []
			var st := ResourceLoader.load_threaded_get_status(scene_jeu, p)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS or st == ResourceLoader.THREAD_LOAD_LOADED:
				progression = maxf(progression, float(p[0]) if not p.is_empty() else 0.0)
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				_paquet = ResourceLoader.load_threaded_get(scene_jeu) as PackedScene
				if _paquet == null:
					_echec()
					return
				etape = "construction"
				print("Chargement : scene chargee en %d ms" % (Time.get_ticks_msec() - _t0))
				progression = -1.0
				_etat.text = tr("Mise en place du quartier…")
				if instancier_en_fond:
					_tache = WorkerThreadPool.add_task(_instancier)
			elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_echec()
		"construction":
			if not instancier_en_fond:
				_instancier()
				_entrer.call_deferred()
				etape = "entree"
			elif WorkerThreadPool.is_task_completed(_tache):
				WorkerThreadPool.wait_for_task_completion(_tache)
				etape = "entree"
				_entrer.call_deferred()
	_maj_barre()


func _instancier() -> void:
	_zone = _paquet.instantiate()


func _entrer() -> void:
	## La zone devient la scene courante (les scripts qui testent current_scene a leur _ready gardent leur comportement).
	if _zone == null:
		_echec()
		return
	_ui.reparent(get_tree().root)
	set_process(false)
	var arbre := get_tree()   # ce noeud quitte l arbre des le changement de scene
	arbre.change_scene_to_node(_zone)
	etape = "fini"
	# ce noeud est libere par le changement de scene : le journal passe par une fonction statique du script
	arbre.process_frame.connect(Callable(get_script(), "journal").bind(_t0), CONNECT_ONE_SHOT)
	# l'ecran reste affiche pendant les premieres images de la zone (souvent les plus lourdes), puis fondu ;
	# le tween appartient a l'interface, qui survit a ce noeud (libere par le changement de scene)
	var ui := _ui
	var tw := ui.create_tween().set_parallel()
	for c in ui.get_children():
		if c is CanvasItem:
			tw.tween_property(c, "modulate:a", 0.0, 0.6).set_delay(0.4)
	tw.chain().tween_callback(ui.queue_free)


func _echec() -> void:
	etape = "erreur"
	progression = -1.0
	_etat.text = tr("Le chargement a échoué. Relance le jeu.")
	_etat.add_theme_color_override("font_color", LATERITE_CLAIRE)
	push_error("Chargement : impossible de charger %s" % scene_jeu)


# ------------------------------------------------------------------ carrousel
func _texture(d: Dictionary) -> Texture2D:
	var t: Texture2D = load(d["img"])
	if d.has("zone"):
		var a := AtlasTexture.new()
		a.atlas = t
		a.region = d["zone"]
		return a
	return t


func _montrer(i: int, direct := false) -> void:
	_diapo = i
	_t_diapo = 0.0
	var d: Dictionary = DIAPOS[i]
	var dessous := _img[_cur]
	_cur = 1 - _cur
	var dessus := _img[_cur]
	dessus.texture = _texture(d)
	dessus.scale = Vector2.ONE
	dessus.move_to_front()
	_lieu.text = tr(d["lieu"])
	if direct:
		dessus.modulate.a = 1.0
		dessous.modulate.a = 0.0
		return
	dessus.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(dessus, "modulate:a", 1.0, duree_fondu)
	tw.tween_callback(func() -> void: dessous.modulate.a = 0.0)


func _animer(delta: float) -> void:
	_t_diapo += delta
	var img := _img[_cur]
	img.pivot_offset = img.size * 0.5
	img.scale = Vector2.ONE * (1.0 + zoom_diapo * minf(_t_diapo / (duree_diapo + duree_fondu), 1.0))
	if _t_diapo >= duree_diapo and DIAPOS.size() > 1:
		_montrer((_diapo + 1) % DIAPOS.size())
	_roue.rotation += delta * 3.0
	_barre.queue_redraw()


func _maj_barre() -> void:
	if progression >= 0.0:
		_pct.text = "%d %%" % int(progression * 100.0)
		_pct.visible = true
	else:
		_pct.visible = false


# ------------------------------------------------------------------ interface
func _label(taille: int, couleur: Color, contour := 0) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if contour > 0:
		l.add_theme_color_override("font_outline_color", NUIT)
		l.add_theme_constant_override("outline_size", contour)
	return l


func _panneau(couleur: Color, biais := 0.0) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = couleur
	sb.skew = Vector2(biais, 0)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _construire_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "EcranChargement"
	_ui.layer = 100
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS   # le fondu continue quand l ecran titre met le jeu en pause
	add_child(_ui)
	# cadre a l'echelle de la hauteur d'ecran (maquette en 720 p) : meme mise en page sur PC et telephone
	_cadre = Control.new()
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_cadre)
	get_viewport().size_changed.connect(_echelle)
	_echelle()
	var fond := ColorRect.new()
	fond.color = NUIT
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cadre.add_child(fond)
	for i in 2:
		var t := TextureRect.new()
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.modulate.a = 0.0
		fond.add_child(t)
		_img.append(t)
	# degrade sombre en bas pour la lisibilite du bandeau
	var ombre := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(NUIT, 0.0))
	g.gradient.set_color(1, Color(NUIT, 0.85))
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	ombre.texture = g
	ombre.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ombre.stretch_mode = TextureRect.STRETCH_SCALE
	ombre.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	ombre.offset_top = -260
	_cadre.add_child(ombre)

	# logo (haut gauche) : panneau biseaute nuit, GTB en jaune contour noir comme le titre du jeu, filet vert
	var logo := _panneau(Color(NUIT, 0.88), -0.18)
	logo.position = Vector2(-40, 0)
	logo.size = Vector2(430, 250)
	_cadre.add_child(logo)
	var gtb := _label(118, TITRE, 22)
	gtb.text = "GTB"
	gtb.position = Vector2(70, 8)
	gtb.rotation = -0.05
	logo.add_child(gtb)
	var sous := _label(28, SABLE, 8)
	sous.text = "GBÊ TOWN BÉNIN"
	sous.position = Vector2(76, 166)
	sous.rotation = -0.05
	logo.add_child(sous)
	var filet := ColorRect.new()
	filet.color = VERT
	filet.position = Vector2(78, 204)
	filet.size = Vector2(250, 5)
	logo.add_child(filet)
	var filet2 := ColorRect.new()
	filet2.color = ZEM
	filet2.position = Vector2(78, 212)
	filet2.size = Vector2(150, 3)
	logo.add_child(filet2)

	# lieu (haut droite)
	var badge := _panneau(Color(NUIT, 0.88), -0.25)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -360
	badge.offset_right = 30
	badge.offset_top = 0
	badge.offset_bottom = 74
	_cadre.add_child(badge)
	var pin := ColorRect.new()
	pin.color = LATERITE_CLAIRE
	pin.position = Vector2(40, 30)
	pin.size = Vector2(12, 12)
	pin.rotation = PI / 4
	badge.add_child(pin)
	_lieu = _label(26, ZEM)
	_lieu.position = Vector2(66, 18)
	badge.add_child(_lieu)

	# bandeau du bas : astuce, etat, barre, pourcentage
	var bas := _panneau(Color(NUIT, 0.92))
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_top = -112
	_cadre.add_child(bas)
	var accent := ColorRect.new()
	accent.color = LATERITE
	accent.set_anchors_preset(Control.PRESET_TOP_WIDE)
	accent.offset_bottom = 4
	bas.add_child(accent)
	var titre_astuce := _label(16, LATERITE_CLAIRE)
	titre_astuce.text = tr("ASTUCE")
	titre_astuce.position = Vector2(40, 20)
	bas.add_child(titre_astuce)
	_astuce = _label(19, SABLE)
	_astuce.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_astuce.position = Vector2(40, 44)
	_astuce.size = Vector2(560, 56)
	bas.add_child(_astuce)

	var droite := Control.new()
	droite.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	droite.offset_left = -600
	droite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bas.add_child(droite)
	_etat = _label(16, POUSSIERE.lightened(0.35))
	_etat.text = tr("Chargement de Gbê Town…")
	_etat.position = Vector2(64, 26)
	droite.add_child(_etat)
	_roue = Control.new()
	_roue.position = Vector2(40, 36)
	_roue.draw.connect(func() -> void: _roue.draw_arc(Vector2.ZERO, 11, 0, PI * 1.4, 24, ZEM, 3.0, true))
	droite.add_child(_roue)
	_barre = Control.new()
	_barre.position = Vector2(28, 64)
	_barre.size = Vector2(440, 14)
	_barre.draw.connect(_dessiner_barre)
	droite.add_child(_barre)
	_pct = _label(26, ZEM)
	_pct.position = Vector2(490, 50)
	droite.add_child(_pct)
	_echelle()


func _echelle() -> void:
	var vp := get_viewport().get_visible_rect().size
	var f := maxf(vp.y / 720.0, 0.5)
	_cadre.scale = Vector2(f, f)
	_cadre.size = vp / f
	if _astuce:
		_astuce.size.x = clampf(_cadre.size.x - 660.0, 260.0, 560.0)   # ecrans etroits (4:3) : ne pas passer sous la barre
		_astuce.add_theme_font_size_override("font_size", 19 if _astuce.size.x >= 480.0 else 15)


func _dessiner_barre() -> void:
	var s := _barre.size
	_barre.draw_rect(Rect2(Vector2.ZERO, s), Color(POUSSIERE, 0.45))
	if progression >= 0.0:
		_barre.draw_rect(Rect2(Vector2.ZERO, Vector2(s.x * progression, s.y)), ZEM)
	else:
		# progression inconnue : segment qui va et vient (pas de faux pourcentage)
		var t := Time.get_ticks_msec() / 1000.0
		var w := s.x * 0.25
		var x := (sin(t * 2.2) * 0.5 + 0.5) * (s.x - w)
		_barre.draw_rect(Rect2(Vector2(x, 0), Vector2(w, s.y)), ZEM)


static func journal(t0: int) -> void:
	## premiere image apres l'entree de la zone dans l'arbre : temps total jusqu'au jeu
	print("Chargement : zone en place en %d ms" % (Time.get_ticks_msec() - t0))
