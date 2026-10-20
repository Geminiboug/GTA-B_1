extends Node
## Ecran de chargement (scene de demarrage) : charge la zone en tache de fond et montre un carrousel de vraies captures
## du jeu (fondu enchaine, leger zoom), le logo GTB, le nom du lieu, une astuce et la progression.
## Etapes : 1) chargement de la scene (ResourceLoader en fond) : vraie progression en % ;
## 2) entree dans la zone (change_scene_to_node : la zone devient current_scene comme avant) ;
## 3) mise en place etalee : les scripts lourds (pietons, circulation, concessions) ont confie leurs etapes a
##    Partie.chantier ; l'ecran les execute quelques ms par image (le carrousel continue), % = etapes faites ;
## 4) fondu de sortie. Ce noeud n'est plus la scene courante des l'etape 2 : il survit au changement de scene.

const ZEM := Color("#F2BB2C")
const TITRE := Color("#FFD140")
const LATERITE := Color("#B0472B")
const LATERITE_CLAIRE := Color("#E0714F")
const NUIT := Color("#17140F")
const SABLE := Color("#F6F1E7")
const POUSSIERE := Color("#6C6457")
const VERT := Color("#008751")

## Captures du jeu sans HUD (1920x1080, tests/capture_ecran_chargement.gd)
const DIAPOS := [
	{"img": "res://assets/ui/chargement/epave.png", "lieu": "L'ÉPAVE VOLANTE"},
	{"img": "res://assets/ui/chargement/quartier.png", "lieu": "LES QUARTIERS"},
	{"img": "res://assets/ui/chargement/ararat.png", "lieu": "ARARAT HYPERMARKET"},
	{"img": "res://assets/ui/chargement/route_peches.png", "lieu": "LA ROUTE DES PÊCHES"},
	{"img": "res://assets/ui/chargement/terminal.png", "lieu": "L'AÉROPORT"},
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
@export var sous_fils := false           # sous-fils du ResourceLoader (plus lent sur certains disques)
@export var budget_ms := 12.0            # temps de mise en place par image (le reste pour l'affichage)
@export var journal_ecarts := false     # mesure : temps hors etapes entre deux images, et l'etape qui precede
@export var rodage_tour := 2.5     # s : tour complet de la camera sous l'ecran (shaders de tout ce qui l'entoure)
@export var rodage_ips := 45.0     # images par seconde a tenir 30 images de suite pour lever l'ecran
@export var rodage_max := 12.0     # s : au-dela, l'ecran part quand meme
@export var etape_lente_ms := 120.0      # une etape plus longue est signalee dans le journal (saccade visible)

var etape := "chargement"                # chargement, mise_en_place, fini, erreur
var progression := 0.0                   # 0..1, -1 = inconnue
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
var _faits := 0
var _ms_etapes := 0.0
var _prets := []
var _tuiles: PackedStringArray = []
var _gardes: Array[Resource] = []
var _t_entree := 0
var _fin_image := 0
var _derniere := ""
var _ecarts := []
var _images := 0
var _vide := 0
var _t_rodage := 0.0
var _stables := 0
var _pivot: Node3D
var _pivot_rot := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _t0 := Time.get_ticks_msec()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # l ecran titre met le jeu en pause pendant la mise en place
	_rng.randomize()
	_construire_ui()
	_montrer(0, true)
	_astuce.text = tr(ASTUCES[_rng.randi() % ASTUCES.size()])
	if ResourceLoader.load_threaded_request(scene_jeu, "", sous_fils) != OK:
		_echec()
	# les tuiles de la zone (monde.gd) et les modeles charges par les scripts (lieux, vehicules, personnages) ne sont
	# pas des dependances de la scene : charges ici en arriere-plan aussi, sinon le _ready qui les lit fige l'ecran
	for f in _a_precharger():
		if ResourceLoader.load_threaded_request(f, "", sous_fils) == OK:
			_tuiles.append(f)


func _a_precharger() -> PackedStringArray:
	var res := Monde.fichiers()
	var lieux: Dictionary = (load("res://scripts/lieux.gd") as GDScript).get_script_constant_map().get("MODELS", {})
	for f in lieux.values() + Vehicules.MODELS.values():
		res.append(f)
	for v in PnjUtil.VARIANTS:
		res.append(PnjUtil.scene_path(v))
	return res


func _process(delta: float) -> void:
	_animer(delta)
	match etape:
		"chargement":
			var p := []
			var st := ResourceLoader.load_threaded_get_status(scene_jeu, p)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS or st == ResourceLoader.THREAD_LOAD_LOADED:
				progression = maxf(progression, float(p[0]) if not p.is_empty() else 0.0)
			var tuiles_pretes := 0
			for f in _tuiles:
				if ResourceLoader.load_threaded_get_status(f) != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					tuiles_pretes += 1
			if st == ResourceLoader.THREAD_LOAD_LOADED and tuiles_pretes == _tuiles.size():
				for f in _tuiles:
					var r := ResourceLoader.load_threaded_get(f)
					if r:
						_gardes.append(r)   # gardees en cache jusqu'a la fin : monde.gd les retrouve sans relire le disque
				_paquet = ResourceLoader.load_threaded_get(scene_jeu) as PackedScene
				if _paquet == null:
					_echec()
					return
				print("Chargement : scene chargee en %d ms" % (Time.get_ticks_msec() - _t0))
				_etat.text = tr("Mise en place du quartier…")
				progression = 0.0
				_entrer.call_deferred()
				etape = "entree"
			elif st == ResourceLoader.THREAD_LOAD_FAILED or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_echec()
		"mise_en_place":
			_mise_en_place()
		"rodage":
			_rodage(delta)
	_maj_barre()


func _entrer() -> void:
	## La zone devient la scene courante (les scripts qui testent current_scene a leur _ready gardent leur comportement).
	_t_entree = Time.get_ticks_msec()
	_zone = _paquet.instantiate()
	if journal_ecarts:
		for n in _zone.get_children():
			n.ready.connect(func() -> void: _prets.append([Time.get_ticks_usec(), String(n.name)]))
		_zone.tree_entered.connect(func() -> void: _prets.append([Time.get_ticks_usec(), "entree"]))
	if _zone == null:
		_echec()
		return
	Partie.chantiers.clear()
	Partie.chantier_actif = true
	var arbre := get_tree()
	arbre.current_scene = null          # ce noeud n'est plus la scene courante : le changement de scene ne le libere pas
	# le monde 3D n'est pas dessine sous l'ecran opaque : pas de rendu ni de compilation de shaders a chaque image
	get_viewport().disable_3d = true
	arbre.change_scene_to_node(_zone)
	etape = "mise_en_place"


func _mise_en_place() -> void:
	## Execute les etapes confiees a Partie.chantier, budget_ms par image ; progression = etapes faites / total connu.
	_images += 1
	var maint := Time.get_ticks_usec()
	if _fin_image > 0 and journal_ecarts:
		_ecarts.append([(maint - _fin_image) / 1000.0, _derniere])
	if _images == 1:
		print("Chargement : zone instanciee et prete en %d ms" % (Time.get_ticks_msec() - _t_entree))
		var lents := []
		for i in range(1, _prets.size()):
			lents.append([(_prets[i][0] - _prets[i - 1][0]) / 1000.0, _prets[i][1]])
		lents.sort_custom(func(a, b): return a[0] > b[0])
		if journal_ecarts:
			print("Chargement : _ready les plus longs ", lents.slice(0, 10))
	var t := Time.get_ticks_usec()
	while not Partie.chantiers.is_empty() and Time.get_ticks_usec() - t < budget_ms * 1000.0:
		var c: Callable = Partie.chantiers.pop_front()
		var t1 := Time.get_ticks_usec()
		if c.is_valid():
			c.call()
		var duree := (Time.get_ticks_usec() - t1) / 1000.0
		_ms_etapes += duree
		if duree > etape_lente_ms:
			print("Chargement : etape lente %.0f ms (%s.%s)" % [duree, c.get_object().get("name") if c.get_object() else "?", c.get_method()])
		_faits += 1
		_derniere = "%s.%s" % [c.get_object().get("name") if c.get_object() else "?", c.get_method()]
	_fin_image = Time.get_ticks_usec()
	var total := _faits + Partie.chantiers.size()
	progression = float(_faits) / float(maxi(total, 1))
	# quelques images sans nouvelle etape (des scripts attendent une image avant de confier les leurs) : termine
	_vide = _vide + 1 if Partie.chantiers.is_empty() else 0
	if _vide == 20:
		get_viewport().disable_3d = false   # premiere image du monde (la plus lourde) encore sous l'ecran
	if _vide >= 24:
		Partie.chantier_actif = false
		_gardes.clear()
		_debut_rodage()


func _debut_rodage() -> void:
	## Le monde tourne deja sous l'ecran opaque : les premieres images (compilation des shaders de ce que voit la camera,
	## decor des tuiles proches, pietons qui apparaissent) sont lourdes. On les fait passer ici, camera en tour complet,
	## et l'ecran ne part que quand les images sont redevenues regulieres.
	etape = "rodage"
	_t_rodage = 0.0
	_stables = 0
	_etat.text = tr("Derniers préparatifs…")
	var j := get_tree().current_scene.get_node_or_null("Player") if get_tree().current_scene else null
	_pivot = j.get("cam_pivot") as Node3D if j else null
	if _pivot:
		_pivot_rot = _pivot.rotation


func _rodage(delta: float) -> void:
	_t_rodage += delta
	if _pivot and is_instance_valid(_pivot):
		var u := clampf(_t_rodage / rodage_tour, 0.0, 1.0)
		_pivot.rotation = Vector3(_pivot_rot.x, _pivot_rot.y + TAU * u, _pivot_rot.z) if u < 1.0 else _pivot_rot
	_stables = _stables + 1 if delta < 1.0 / rodage_ips else 0
	progression = clampf(_t_rodage / rodage_max, 0.0, 1.0)
	var pret := _t_rodage > rodage_tour and _stables >= 30 and Partie.taches_en_attente() == 0
	if pret or _t_rodage > rodage_max:
		if _pivot and is_instance_valid(_pivot):
			_pivot.rotation = _pivot_rot
		_terminer()


func _terminer() -> void:
	etape = "fini"
	if journal_ecarts:
		_ecarts.sort_custom(func(a, b): return a[0] > b[0])
		var somme := 0.0
		for e in _ecarts:
			somme += e[0]
		print("Chargement : %.0f ms entre les images, les plus longs : %s" % [somme, str(_ecarts.slice(0, 12))])
	print("Chargement : zone en place en %d ms (%d etapes, %.0f ms de calcul, %d images)" % [Time.get_ticks_msec() - _t0, _faits, _ms_etapes, _images])
	print("Chargement : rodage %.1f s" % _t_rodage)
	Partie.suivre_saccades(30.0)
	var tw := create_tween().set_parallel()
	for c in _ui.get_children():
		if c is CanvasItem:
			tw.tween_property(c, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(queue_free)


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
	# une etape de mise en place lente donne un grand delta : le zoom ralentit au lieu de sauter
	_t_diapo += minf(delta, 1.0 / 30.0)
	var u := minf(_t_diapo / (duree_diapo + duree_fondu), 1.0)
	var img := _img[_cur]
	img.pivot_offset = img.size * 0.5
	img.scale = Vector2.ONE * (1.0 + zoom_diapo * u * (2.0 - u))
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
		t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
