extends CharacterBody3D
## Voiture conduisible (berline, 4x4, minibus), conduite "arcade-simulation" comme dans les GTA.
## - Moteur a couple variable selon le regime, boite automatique a 5 rapports (passages avec coupure de couple,
##   retrogradage en reprise), pont, masse et trainee reelles : accelerations, reprises et vitesse de pointe en
##   decoulent. Frein moteur, patinage au demarrage si le couple depasse l'adherence des roues motrices.
## - Suspension : chaque roue suit le sol (rayon : trottoirs, bosses), la caisse seule bouge sur ressorts amortis
##   (plongee au freinage, cabrage a l'acceleration, roulis en virage, leger rebond).
## - Pneus a adherence limitee : la voiture garde son elan (inertie) et les pneus ne rattrapent la glissade
##   laterale que jusqu'a ~0,9 g : sous-virage si on entre trop vite, derapage au frein a main (arriere qui
##   decroche), contre-braquage possible.
## - Transfert de masse visible : roulis en virage, plongee au freinage, cabrage a l'acceleration.
## - Chocs : vitesse cassee, degats (fumee au capot, puis moteur hors service), son de choc ; crissements de pneus.
## - Phares et feux arriere allumes la nuit, feux stop au freinage, klaxon.
## Commandes : Z/S gaz / frein et marche arriere, Q/D direction, Espace frein a main, H klaxon, E descendre.
## Manette : RT / LT, stick gauche, RB frein a main, L3 klaxon, Y descendre.

signal rider_changed(has_rider: bool)

const G := 9.8
const LAMP_MAT := preload("res://shaders/lampe_material.tres")

@export var max_speed := 44.0          # m/s (~160 km/h) : limiteur
@export var masse := 1150.0            # kg (Vehicules.TUNING par modele)
@export var couple_max := 140.0        # N.m
@export var regime_couple := 4000.0    # tr/min du couple maximal
@export var regime_max := 6200.0       # tr/min (coupure)
@export var regime_ralenti := 850.0
@export var rapports: Array = [3.45, 1.94, 1.31, 1.03, 0.84]
@export var rapport_arriere := 3.3
@export var pont := 4.1
@export var rendement := 0.85
@export var part_motrice := 0.6        # part du poids sur les roues motrices (traction avant 0.6, 4x4 1.0)
@export var trainee := 0.62            # surface de trainee Cx.S (m2)
@export var duree_passage := 0.3       # s de coupure de couple a chaque passage de rapport
@export var suspension_freq := 1.5     # Hz (frequence propre de la caisse)
@export var suspension_amort := 0.35   # amortissement relatif
@export var debattement := 0.11        # m de course de roue (trottoirs, bosses)
@export var brake_decel := 9.5
@export var handbrake_decel := 3.5
@export var max_reverse := 6.0
@export var max_steer := 0.62          # rad aux roues, a l'arret
@export var steer_speed := 2.6
@export var grip := 0.92               # adherence laterale maximale (en g)
@export var drag := 0.0011             # trainee aerodynamique (par metre)
@export var roll_factor := 0.012
@export var pitch_factor := 0.011
@export_group("Pneus et chassis")
@export var repartition_avant := 0.6     # part du poids sur l'essieu avant a l'arret
@export var hauteur_cg := 0.55           # m : hauteur du centre de gravite (transferts de charge, roulis)
@export var rigidite_avant := 11.0       # rigidite de derive / charge (par rad) : plus haut = plus vif
@export var rigidite_arriere := 12.5     # un peu plus a l'arriere : la voiture sous-vire, stable
@export var abs_actif := true            # freinage a la limite d'adherence sans bloquer les roues
## Direction asservie a la vitesse : au-dela de quelques m/s, le braquage est limite a ce que les pneus peuvent
## transmettre (marge braquage_marge) : au clavier (tout ou rien), on tourne au maximum sans saturer les pneus.
@export var braquage_marge := 1.35
## Controle de stabilite (ESP) : 0 = aucun, 1 = la derive de la caisse est corrigee des qu'elle depasse esp_seuil
## (sauf frein a main : on peut toujours faire deraper volontairement).
@export_range(0.0, 1.0) var esp := 1.0
@export var marche_max := 0.22           # m : bordures et trottoirs franchis par les roues (pas un choc)
@export var esp_seuil := 0.1             # rad de derive de la caisse avant correction
@export_group("")

var kind := "voiture"
var model_name := "veh_berline"
var has_rider := false
var ai := false                  # conduite automatique (police) tant que le joueur n'est pas au volant
var ai_input := Vector3.ZERO     # (accelerateur, frein, direction) 0..1, 0..1, -1..1 (+ = gauche)
var speed := 0.0         # vitesse longitudinale signee (camera, mini-carte, son, PNJ)
var throttle := 0.0
var braking := false
var health := 100.0
var rpm := 900.0
var rapport := 0                 # rapport engage (0 = premiere), -1 marche arriere
var patine := false              # roues motrices qui patinent (crissement)
var _passage_t := 0.0
var _parts: Array = []           # [Node3D, transform au repos] : caisse et details (pas les roues)
var _susp: Array = []            # [pivot de roue, position au repos, avant ?, gauche ?]
var _sq := Vector3.ZERO          # caisse : hauteur, tangage, roulis
var _sv := Vector3.ZERO          # vitesses correspondantes

var _vel := Vector2.ZERO
var _yaw := 0.0
var _yaw_rate := 0.0
var _steer := 0.0
var _roll := 0.0
var _pitch := 0.0
var _a_long := 0.0
var _a_lat := 0.0
var _visual: Node3D
var _steer_nodes: Array[Node3D] = []
var _wheel_nodes: Array[Node3D] = []
var _seat: Node3D
var _exit: Node3D
var _wheel_r := 0.31
var _wheelbase := 2.6
var _body_mats: Array = []          # [MeshInstance3D, surface, materiau carrosserie d'origine]
var _tail_mat: StandardMaterial3D
var _engine: AudioStreamPlayer3D      # moteur en charge (pied sur l'accelerateur)
var _engine_off: AudioStreamPlayer3D  # moteur a vide (frein moteur, ralenti)
var _roul: AudioStreamPlayer3D        # roulement des pneus (goudron ou gravier selon le revetement)
var _wind: AudioStreamPlayer3D
var _fx: AudioStreamPlayer3D          # bruits ponctuels : passage de rapport, petarade, portieres
var _roll_gravier := false
var _rapport_prec := 0
var _thr_prec := 0.0
static var _sons := {}                # boucles calculees une fois pour toutes les voitures
var _poussiere: GPUParticles3D        # laterite ou sable souleve par les roues
var _fumee_pneus: GPUParticles3D      # pneus qui fument en derapage ou en patinage
var _trace_prec := [Vector3.ZERO, Vector3.ZERO]
static var _traces: MultiMeshInstance3D   # traces de pneus sur le goudron (anneau de TRACES_MAX quads)
static var _trace_i := 0
static var _trace_n := 0
const TRACES_MAX := 700
const VITRE_CASSEE := preload("res://shaders/vitre_cassee.gdshader")
const SALETE := preload("res://shaders/salete_auto.gdshader")
const CLIGNOTANT := preload("res://shaders/clignotant.gdshader")
static var _verre: StandardMaterial3D      # vitres teintees qui refletent le ciel (communes a toutes les voitures)
var usure := Vector2(-1.0, -1.0)          # (poussiere, rouille) 0..1 ; negatif : tire au hasard a la creation
# degats visibles : tole enfoncee au point de choc, vitres etoilees, phares casses, feu moteur
var _tole: Dictionary = {}            # MeshInstance3D -> [surfaces d'origine (Array d'arrays), materiaux]
var _vitres: Array = []               # [MeshInstance3D, surface] des vitres
var _vitre_mat: ShaderMaterial
var _phares_casses := [false, false]
var _feu: GPUParticles3D
var _feu_lum: OmniLight3D
var _recul: SpotLight3D                # feux de recul : eclairent le sol derriere en marche arriere
var _clign_mat: ShaderMaterial         # clignotants : gauche / droite (shaders/clignotant.gdshader), warnings en panne
var moteur := false              # contact mis : le moteur tourne (demarreur quand on s'installe, coupe en descendant)
var _demarreur_t := 0.0
var _clign_cote := 0             # -1 gauche, 1 droite, 0 eteints (clignotant automatique en tournant)
var _clign_on := false
var _clign_t := 0.0
var _horn: AudioStreamPlayer3D
var _screech: AudioStreamPlayer3D
var _crash: AudioStreamPlayer3D
var _smoke: GPUParticles3D
var _lights: Array[SpotLight3D] = []
var _crash_cd := 0.0
var _last_safe := Vector3.ZERO
var _day_night: Node
var _meteo: Node
var adresse := 1.0               # competence du conducteur (scripts/stats.gd) : adherence tiree des pneus
var surface := "route"           # revetement sous la voiture : route, paves, terre, plage, eau
var adherence := 1.0             # multiplicateur d'adherence du revetement (pluie comprise)
var derive := 0.0                # angle de derive de la caisse (rad) : derapage visible et crissements
var _surf_t := 0.0
const SURFACES := {"route": [1.0, 0.015], "paves": [0.85, 0.02], "terre": [0.7, 0.03], "herbe": [0.6, 0.04],
	"plage": [0.5, 0.09], "eau": [0.35, 0.2]}   # [adherence, resistance au roulement]

signal crashed(impact: float, other: Object)


func setup(model: Node3D, model_id: String, color: Color) -> void:
	## Appele par Vehicules.create() avant l'entree dans l'arbre.
	model_name = model_id
	_visual = model
	_visual.name = "Visual"
	add_child(_visual)
	_seat = _visual.find_child("pt_conducteur", true, false)
	_exit = _visual.find_child("pt_sortie", true, false)
	for side in ["g", "d"]:
		var st := _visual.find_child("piv_direction_av" + side, true, false) as Node3D
		if st:
			_steer_nodes.append(st)
		for tag in ["av", "ar"]:
			var w := _visual.find_child("piv_roue_" + tag + side, true, false) as Node3D
			if w:
				_wheel_nodes.append(w)
	var front := _visual.find_child("piv_direction_avg", true, false) as Node3D
	var rear := _visual.find_child("piv_roue_arg", true, false) as Node3D
	if front and rear:
		_wheelbase = absf(front.position.z - rear.position.z)
		_wheel_r = rear.position.y
	for c in _visual.get_children():
		var n := String(c.name)
		if c is Node3D and not n.begins_with("piv_") and not n.begins_with("pt_"):
			_parts.append([c, (c as Node3D).transform])
	for n in ["piv_direction_avg", "piv_direction_avd", "piv_roue_arg", "piv_roue_ard"]:
		var w := _visual.find_child(n, true, false) as Node3D
		if w:
			_susp.append([w, w.position, n.contains("_av"), n.ends_with("g")])
	# materiaux : teinte de carrosserie, phares la nuit, feux arriere
	_tail_mat = StandardMaterial3D.new()
	_tail_mat.albedo_color = Color(0.6, 0.04, 0.03)
	_tail_mat.emission_enabled = true
	_tail_mat.emission = Color(1.0, 0.08, 0.05)
	_tail_mat.emission_energy_multiplier = 0.0
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(s)
			if m == null:
				continue
			match m.resource_name:
				"mat_carrosserie":
					var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
					d.albedo_color = color
					d.next_pass = _salete()
					mi.set_surface_override_material(s, d)
					_body_mats.append([d, color])
				"mat_verre_auto":
					mi.set_surface_override_material(s, _verre_teinte())
					_vitres.append([mi, s])
				"mat_lampe":
					mi.set_surface_override_material(s, LAMP_MAT)
				"mat_feu_arriere":
					mi.set_surface_override_material(s, _tail_mat)
				"mat_clignotant":
					if _clign_mat == null:
						_clign_mat = ShaderMaterial.new()
						_clign_mat.shader = CLIGNOTANT
					mi.set_surface_override_material(s, _clign_mat)


func _ready() -> void:
	_yaw = rotation.y
	_last_safe = global_position
	_day_night = get_parent().get_node_or_null("JourNuit") if get_parent() else null
	_meteo = get_parent().get_node_or_null("Meteo") if get_parent() else null
	var diesel := diesel_moteur()
	_engine = _sound(_son("on%s" % diesel, func() -> AudioStream: return AudioSynth.moteur(diesel, true)), -8.0, 6.0, 90.0, true)
	_engine_off = _sound(_son("off%s" % diesel, func() -> AudioStream: return AudioSynth.moteur(diesel, false)), -80.0, 6.0, 90.0, true)
	_roul = _sound(_son("roll0", func() -> AudioStream: return AudioSynth.roulement_loop(false)), -80.0, 5.0, 50.0, true)
	_wind = _sound(_son("vent", func() -> AudioStream: return AudioSynth.vent_loop()), -80.0, 4.0, 30.0, true)
	_fx = _sound(_son("rapport", func() -> AudioStream: return AudioSynth.passage_rapport()), -6.0, 6.0, 60.0, false)
	_roul.position = Vector3(0, 0.3, 0)
	_engine.position = Vector3(0, 0.6, -1.4) if not model_name == "veh_minibus" else Vector3(0, 0.6, -1.2)
	_engine_off.position = _engine.position
	_horn = _sound(AudioSynth.klaxon(350.0, 440.0, 0.5), -2.0, 10.0, 140.0, false)
	_screech = _sound(AudioSynth.crissement_loop(), -80.0, 6.0, 90.0, true)
	_crash = _sound(AudioSynth.choc(), 0.0, 8.0, 120.0, false)
	_smoke = _make_smoke()
	_recul = SpotLight3D.new()
	_recul.spot_range = 9.0
	_recul.spot_angle = 50.0
	_recul.light_energy = 0.0
	_recul.light_color = Color(1.0, 1.0, 0.97)
	_recul.shadow_enabled = false
	_recul.position = Vector3(0, 0.8, _wheelbase * 0.5 + 0.9)
	_recul.rotation = Vector3(-0.35, PI, 0)
	_visual.add_child(_recul)
	_poussiere = _particules(Color(0.66, 0.6, 0.5, 0.32), 48, 1.6, Vector3(0, 0.25, 1.8), 1.4)
	_fumee_pneus = _particules(Color(0.85, 0.85, 0.85, 0.4), 40, 1.3, Vector3(0, 0.2, 1.4), 1.0)
	for side in [-0.6, 0.6]:
		var l := SpotLight3D.new()
		l.spot_range = 34.0
		l.spot_angle = 32.0
		l.light_energy = 0.0
		l.light_color = Color(1.0, 0.95, 0.85)
		l.shadow_enabled = false
		l.position = Vector3(side, 0.75, -2.3)
		l.rotation.x = -0.08
		_visual.add_child(l)
		_lights.append(l)


func _salete() -> ShaderMaterial:
	## Poussiere de laterite et rouille propres a chaque voiture (les vieux minibus et berlines rouillent plus).
	if usure.x < 0.0:
		var vieux := model_name in ["veh_minibus", "veh_berline"]
		usure = Vector2(randf_range(0.25, 0.9), randf_range(0.0, 0.7) if vieux and randf() < 0.6 else randf_range(0.0, 0.15))
	var m := ShaderMaterial.new()
	m.shader = SALETE
	m.set_shader_parameter("poussiere", usure.x)
	m.set_shader_parameter("rouille", usure.y)
	m.set_shader_parameter("haut_caisse", 1.0 if model_name == "veh_berline" else 1.2)
	return m


static func _verre_teinte() -> StandardMaterial3D:
	if _verre == null:
		_verre = StandardMaterial3D.new()
		_verre.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_verre.albedo_color = Color(0.05, 0.065, 0.075, 0.74)
		_verre.roughness = 0.03
		_verre.metallic = 0.15
		_verre.metallic_specular = 0.9
		_verre.rim_enabled = true
		_verre.rim = 0.35
		_verre.rim_tint = 0.2
	return _verre


func diesel_moteur() -> bool:
	return model_name != "veh_berline"


static func _son(cle: String, fabrique: Callable) -> AudioStream:
	if not _sons.has(cle):
		_sons[cle] = fabrique.call()
	return _sons[cle]


func portiere(fermer: bool) -> void:
	## Bruit de portiere (scripts/player.gd en montant et en descendant).
	_fx.stream = _son("porte%s" % fermer, func() -> AudioStream: return AudioSynth.portiere(fermer))
	_fx.volume_db = -2.0
	_fx.play()


func _sound(stream: AudioStream, db: float, unit: float, maxd: float, play: bool) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = maxd
	p.position = Vector3(0, 0.6, -1.0)
	add_child(p)
	if play:
		p.play()
	return p


func _make_smoke() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 2.2
	p.emitting = false
	p.position = Vector3(0, 1.0, -1.6)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.6
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _tache()
	m.albedo_color = Color(0.35, 0.35, 0.35, 0.35)
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p


func _particules(col: Color, amount: int, life: float, pos: Vector3, taille: float) -> GPUParticles3D:
	## Nuage derriere les roues arriere (poussiere, fumee de pneus), en coordonnees du monde (il reste en place).
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emitting = false
	p.local_coords = false
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.8, 0.05, 0.2)
	pm.direction = Vector3(0, 0.6, 1)
	pm.spread = 35.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, 0.25, 0)
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.scale_min = taille * 0.6
	pm.scale_max = taille * 1.6
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.6))
	var ct := CurveTexture.new()
	ct.curve = grow
	pm.scale_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _tache()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p


func _effets(delta: float) -> void:
	## Poussiere sur la laterite et le sable, fumee et traces de pneus sur le goudron quand ca glisse.
	var v := absf(speed)
	var terreux := surface in ["terre", "plage", "herbe"]
	_poussiere.emitting = terreux and v > 4.0
	if _poussiere.emitting:
		_poussiere.amount_ratio = clampf(v / 20.0, 0.2, 1.0)
		var sable := surface == "plage"
		var col := Color(0.86, 0.78, 0.6, 0.3) if sable else Color(0.66, 0.6, 0.5, 0.32)
		((_poussiere.draw_pass_1 as QuadMesh).material as StandardMaterial3D).albedo_color = col
	var glisse := (absf(derive) > 0.14 and v > 5.0) or patine or (braking and v > 8.0 and not abs_actif)
	_fumee_pneus.emitting = glisse and not terreux
	if glisse and not terreux and is_inside_tree():
		_trace(delta)
	else:
		_trace_prec = [Vector3.ZERO, Vector3.ZERO]


func _trace(_delta: float) -> void:
	## Deux bandes sombres sous les roues arriere, posees tous les 0,35 m.
	if _traces == null or not is_instance_valid(_traces):
		_traces = MultiMeshInstance3D.new()
		_traces.name = "TracesPneus"
		_trace_i = 0
		_trace_n = 0
		_traces.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var q := QuadMesh.new()
		q.size = Vector2(0.2, 1.0)
		q.orientation = PlaneMesh.FACE_Y
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.05, 0.05, 0.55)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		q.material = m
		mm.mesh = q
		mm.instance_count = TRACES_MAX
		mm.visible_instance_count = 0
		_traces.multimesh = mm
		get_tree().current_scene.add_child(_traces) if get_tree().current_scene else get_parent().add_child(_traces)
	var mm := _traces.multimesh
	for k in 2:
		var side := -0.75 if k == 0 else 0.75
		var p := global_transform * Vector3(side, 0.0, _wheelbase * 0.45)
		p.y = global_position.y + 0.025
		var prev: Vector3 = _trace_prec[k]
		if prev == Vector3.ZERO:
			_trace_prec[k] = p
			continue
		var d := p - prev
		d.y = 0.0
		if d.length() < 0.35:
			continue
		var mid := (p + prev) * 0.5
		var b := Basis(Vector3.UP, atan2(d.x, d.z)).scaled(Vector3(1, 1, d.length()))
		mm.set_instance_transform(_trace_i, Transform3D(b, mid))
		_trace_i = (_trace_i + 1) % TRACES_MAX
		_trace_n = mini(_trace_n + 1, TRACES_MAX)
		mm.visible_instance_count = _trace_n
		_trace_prec[k] = p


func set_rider(value: bool) -> void:
	has_rider = value
	rider_changed.emit(value)
	# contact : demarreur en s'installant, moteur coupe en descendant
	if value and not moteur and health > 0.0:
		_demarreur_t = 0.9
		if _fx == null:
			return
		_fx.stream = _son("demarreur", func() -> AudioStream: return AudioSynth.demarreur())
		_fx.volume_db = -6.0
		_fx.play()
	elif not value:
		moteur = false


func seat_transform() -> Transform3D:
	return _seat.global_transform if _seat else global_transform


func entry_point() -> Vector3:
	return _exit.global_position if _exit else global_position


func exit_transform() -> Transform3D:
	var p := entry_point()
	return Transform3D(Basis(Vector3.UP, _yaw), Vector3(p.x, global_position.y + 0.1, p.z))


func horn() -> void:
	if not _horn.playing:
		_horn.play()


func damage(amount: float) -> void:
	health = maxf(0.0, health - amount)
	# carrosserie salie et ternie par les chocs
	for e in _body_mats:
		var m: BaseMaterial3D = e[0]
		m.albedo_color = (e[1] as Color).darkened((100.0 - health) / 100.0 * 0.35)
		m.roughness = lerpf(0.35, 0.8, 1.0 - health / 100.0)
	_smoke.emitting = health < 40.0
	if health <= 0.0:
		(_smoke.process_material as ParticleProcessMaterial).color = Color(0.1, 0.1, 0.1)
	if health < 15.0 and _feu == null:
		_allumer_feu()


func enfoncer(point: Vector3, normale: Vector3, impact: float) -> void:
	## Tole enfoncee autour du point de choc (sommets de la caisse et des details pousses vers l'interieur, d'autant plus
	## pres du point et fort le choc) ; vitres etoilees et phares casses au-dela d'un gros choc.
	if impact < 4.0 or _visual == null:
		return
	var prof := clampf((impact - 4.0) * 0.028, 0.03, 0.32)
	var rayon := clampf(0.45 + impact * 0.03, 0.5, 1.1)
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		var nm := String(mi.name)
		if nm.contains("roue") or nm.contains("interieur") or not (mi.mesh is ArrayMesh):
			continue
		var inv := (mi as Node3D).global_transform.affine_inverse()
		var pl := inv * point
		if not (mi.mesh as ArrayMesh).get_aabb().grow(rayon).has_point(pl):
			continue
		var dl := (inv.basis * normale).normalized()
		_deformer(mi, pl, dl, prof, rayon)
	var loc := _visual.global_transform.affine_inverse() * point
	if impact > 9.0 and not _vitres.is_empty():
		if _vitre_mat == null:
			_vitre_mat = ShaderMaterial.new()
			_vitre_mat.shader = VITRE_CASSEE
			for v in _vitres:
				(v[0] as MeshInstance3D).set_surface_override_material(int(v[1]), _vitre_mat)
		_vitre_mat.set_shader_parameter("impact", loc)
		_vitre_mat.set_shader_parameter("force", clampf((impact - 9.0) / 10.0 + 0.3, 0.3, 1.0))
	if impact > 7.0 and loc.z < -_wheelbase * 0.5:
		_phares_casses[0 if loc.x < 0.0 else 1] = true


func _deformer(mi: MeshInstance3D, p: Vector3, dir: Vector3, prof: float, rayon: float) -> void:
	var am := mi.mesh as ArrayMesh
	if not _tole.has(mi):
		# premiere bosse : copie propre de la piece (le maillage d'origine est partage entre les voitures du modele)
		var orig: Array = []
		var mats0: Array = []
		for sidx in am.get_surface_count():
			orig.append(am.surface_get_arrays(sidx))
			mats0.append(am.surface_get_material(sidx))
		_tole[mi] = [orig, mats0]
		var copie := ArrayMesh.new()
		for sidx in orig.size():
			copie.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, (orig[sidx] as Array).duplicate(true))
			copie.surface_set_material(sidx, mats0[sidx])
		mi.mesh = copie
		am = copie
	var arrays: Array = []
	var mats: Array = []
	for sidx in am.get_surface_count():
		var arr := am.surface_get_arrays(sidx)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for i in verts.size():
			var d := verts[i].distance_to(p)
			if d < rayon:
				var f := 1.0 - d / rayon
				# tole froissee : enfoncement irregulier (bruit fixe par sommet) et reflets casses
				var h := fposmod(sin(verts[i].dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0)
				verts[i] += dir * prof * f * (0.6 + 0.8 * h)
				if i < norms.size():
					var j := Vector3(h - 0.5, fposmod(h * 7.31, 1.0) - 0.5, fposmod(h * 3.17, 1.0) - 0.5)
					norms[i] = (norms[i] + j * 1.2 * f).normalized()
		arr[Mesh.ARRAY_VERTEX] = verts
		if norms.size() == verts.size():
			arr[Mesh.ARRAY_NORMAL] = norms
		arrays.append(arr)
		mats.append(am.surface_get_material(sidx))
	am.clear_surfaces()
	for sidx in arrays.size():
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays[sidx])
		am.surface_set_material(sidx, mats[sidx])


func _allumer_feu() -> void:
	## Moteur en feu sous le capot (voiture tres abimee) : flammes, lueur qui vacille.
	_feu = GPUParticles3D.new()
	_feu.amount = 36
	_feu.lifetime = 0.7
	_feu.position = Vector3(0, 0.95, -_wheelbase * 0.55)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.45, 0.05, 0.3)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 1.5, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.3, 1.0))
	g.set_color(1, Color(0.6, 0.1, 0.02, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	_feu.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.6)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = _tache()
	m.vertex_color_use_as_albedo = true
	q.material = m
	_feu.draw_pass_1 = q
	add_child(_feu)
	_feu_lum = OmniLight3D.new()
	_feu_lum.light_color = Color(1.0, 0.55, 0.2)
	_feu_lum.omni_range = 6.0
	_feu_lum.light_energy = 2.0
	_feu_lum.shadow_enabled = false
	_feu_lum.position = _feu.position + Vector3(0, 0.4, 0)
	add_child(_feu_lum)


func reparer() -> void:
	## Garage (phase 16) : tole redressee, vitres et phares neufs, moteur repare.
	health = 100.0
	for mi in _tole:
		if not is_instance_valid(mi):
			continue
		var orig: Array = _tole[mi][0]
		var mats0: Array = _tole[mi][1]
		var am := ArrayMesh.new()
		for sidx in orig.size():
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, orig[sidx])
			am.surface_set_material(sidx, mats0[sidx])
		(mi as MeshInstance3D).mesh = am
	_tole.clear()
	for v in _vitres:
		(v[0] as MeshInstance3D).set_surface_override_material(int(v[1]), _verre_teinte())
	_vitre_mat = null
	_phares_casses = [false, false]
	if _feu:
		_feu.queue_free()
		_feu_lum.queue_free()
		_feu = null
		_feu_lum = null
	_smoke.emitting = false
	(_smoke.process_material as ParticleProcessMaterial).color = Color(1, 1, 1)
	for e in _body_mats:
		(e[0] as BaseMaterial3D).albedo_color = e[1]
		(e[0] as BaseMaterial3D).roughness = 0.35


func _sonde_surface(delta: float) -> void:
	## Revetement sous la voiture (surfaces nommees de scripts/realism.gd, couche 10) : goudron, paves, laterite,
	## herbe, sable, eau ; la pluie rend le goudron et les paves glissants, la laterite boueuse.
	_surf_t -= delta
	if _surf_t > 0.0 or not is_inside_tree():
		return
	_surf_t = 0.15
	var p := global_position
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.0, 0), p + Vector3(0, -1.5, 0), 1 << 9)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var n := String((hit["collider"] as Node).name) if not hit.is_empty() else ""
	if p.y < -0.45:
		surface = "eau"
	elif n.begins_with("plage"):
		surface = "plage"
	elif n.ends_with("_paves"):
		surface = "paves"
	elif n.ends_with("_terre") or n.begins_with("accotement"):
		surface = "terre"
	elif n == "":
		surface = "terre"            # sol nu hors des surfaces nommees : laterite
	else:
		surface = "route"
	var wet: float = float(_meteo.get("wet")) if _meteo else 0.0
	adherence = float(SURFACES[surface][0]) * (1.0 - wet * (0.25 if surface in ["route", "paves"] else 0.15))


func couple(regime: float) -> float:
	## Courbe de couple : ~60 % au ralenti, maximum au regime de couple, ~80 % a la coupure.
	if regime <= regime_couple:
		return couple_max * lerpf(0.6, 1.0, clampf((regime - regime_ralenti) / (regime_couple - regime_ralenti), 0.0, 1.0))
	return couple_max * lerpf(1.0, 0.8, clampf((regime - regime_couple) / (regime_max - regime_couple), 0.0, 1.0))


func vitesse_pointe() -> float:
	## Vitesse (m/s) ou la force du moteur sur le meilleur rapport egale la trainee et le roulement (sans limiteur).
	var best := 0.0
	for r in rapports:
		var v := 1.0
		while v < 90.0:
			var engine := v / _wheel_r * 60.0 / TAU * float(r) * pont
			if engine > regime_max:
				break
			var force := couple(engine) * float(r) * pont * rendement / _wheel_r
			if force < 0.5 * 1.2 * trainee * v * v + 0.015 * masse * G:
				break
			v += 0.25
		best = maxf(best, v)
	return best


func _boite(v: float, acc_in: float) -> void:
	## Boite automatique : monte pres du regime maximal, redescend en deceleration ou en reprise pied au plancher.
	if rapport < 0 or v < 0.5:
		if rapport >= 0:
			rapport = 0
		return
	var wheel_rpm := v / _wheel_r * 60.0 / TAU
	var r_now := wheel_rpm * float(rapports[rapport]) * pont
	if r_now > regime_max * 0.9 and rapport < rapports.size() - 1 and acc_in > 0.05:
		rapport += 1
		_passage_t = duree_passage
	elif rapport > 0:
		var r_down := wheel_rpm * float(rapports[rapport - 1]) * pont
		if r_now < regime_max * 0.38 or (acc_in > 0.9 and r_down < regime_max * 0.8 and r_now < regime_couple * 0.85):
			rapport -= 1


func _physics_process(delta: float) -> void:
	var acc_in := 0.0
	var brake_in := 0.0
	var steer_in := 0.0
	var hand := not has_rider  # frein de stationnement quand personne ne conduit
	if has_rider:
		Limiteur.entrees()
		acc_in = Limiteur.gaz(Input.get_action_strength("accelerate"), speed)
		brake_in = maxf(Input.get_action_strength("brake"), Limiteur.retenue(speed))
		steer_in = Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
		hand = Input.is_action_pressed("handbrake")
		if Input.is_action_just_pressed("horn"):
			horn()
	elif ai:
		# pilote automatique (scripts/police.gd) : memes commandes que le joueur
		acc_in = ai_input.x
		brake_in = ai_input.y
		steer_in = ai_input.z
		hand = false
	if ai:
		moteur = true
	if _demarreur_t > 0.0:
		_demarreur_t -= delta
		if _demarreur_t <= 0.0:
			moteur = true
	if health <= 0.0 or not moteur:
		acc_in = 0.0
	_clignotants(steer_in)
	_sonde_surface(delta)
	var fwd := Vector2(-sin(_yaw), -cos(_yaw))
	var right := Vector2(cos(_yaw), -sin(_yaw))
	var v_long := _vel.dot(fwd)
	var v_lat := _vel.dot(right)

	# --- longitudinal : moteur (couple selon le regime), boite automatique, adherence, freins, resistances ---
	throttle = move_toward(throttle, acc_in, delta * 3.0)
	var a := 0.0
	braking = false
	patine = false
	_passage_t = maxf(0.0, _passage_t - delta)
	var wheel_rpm := absf(v_long) / _wheel_r * 60.0 / TAU
	var en_arriere := v_long < -0.3 or (brake_in > 0.0 and acc_in == 0.0 and v_long < 0.5)
	if en_arriere:
		rapport = -1
	elif rapport < 0:
		rapport = 0
	var ratio: float = (rapport_arriere if rapport < 0 else float(rapports[rapport])) * pont
	# embrayage qui patine au demarrage : le moteur monte en regime avant que la voiture ne suive
	var pedal := brake_in if en_arriere else throttle
	var engine := maxf(wheel_rpm * ratio, regime_ralenti + pedal * 1800.0 * clampf(1.0 - wheel_rpm * ratio / 2600.0, 0.0, 1.0))
	engine = minf(engine, regime_max * 1.02)
	# poids sur les roues motrices : transfert de charge (l'avant s'allege en acceleration, l'arriere se charge)
	var shift_load := clampf(_a_long * 0.55 / (G * _wheelbase), -0.15, 0.15)
	var load := part_motrice
	if part_motrice < 1.0:
		load += shift_load if part_motrice < 0.5 else -shift_load
	var mu := grip * adherence * (adresse if has_rider else 1.0)
	var traction := mu * G * clampf(load, 0.2, 1.0)
	if acc_in > 0.0:
		if v_long > -0.5:
			var force := couple(engine) * acc_in * ratio * rendement / _wheel_r
			if _passage_t > 0.0 or engine >= regime_max:
				force = 0.0
			var a_drive := force / masse
			if a_drive > traction:
				patine = v_long < 12.0
				a_drive = traction
			if v_long < max_speed:
				a += a_drive
		else:
			a += brake_decel * acc_in
			braking = true
	var bloque := false
	if brake_in > 0.0:
		if v_long > 0.5:
			var dec := brake_decel * brake_in
			if dec > mu * G:
				bloque = not abs_actif
				dec = mu * G * (0.75 if bloque else 0.97)     # ABS : a la limite ; roues bloquees : moins bien
			a -= dec
			braking = true
		elif v_long > -max_reverse:
			a -= minf(couple(engine) * brake_in * rapport_arriere * pont * rendement / _wheel_r / masse, traction) * 0.7
	# resistances : trainee aerodynamique, roulement, frein moteur (pied leve, rapport engage)
	var resist := (0.5 * 1.2 * trainee * v_long * v_long + float(SURFACES[surface][1]) * masse * G) / masse
	if acc_in == 0.0 and absf(v_long) > 1.0:
		resist += couple_max * 0.12 * ratio * rendement / _wheel_r / masse
	if hand:
		resist += handbrake_decel
	var nl := v_long + a * delta
	if acc_in == 0.0 and brake_in == 0.0 or hand:
		nl = move_toward(nl, 0.0, resist * delta)
	else:
		nl -= signf(nl) * minf(resist * delta, absf(nl))
	_boite(nl, acc_in)
	rpm = lerpf(rpm, engine, 1.0 - exp(-10.0 * delta))
	# --- direction et pneus : modele bicyclette dynamique (derive des pneus, charge sur chaque essieu, inertie de
	# lacet). Sous-virage si l'avant sature (entree trop rapide), survirage si l'arriere decroche (frein a main, lever
	# de pied en appui, terre ou sable), contre-braquage possible. A basse vitesse : geometrie pure (manoeuvres).
	var steer_limit := max_steer / (1.0 + absf(nl) * 0.045)
	if absf(nl) > 4.0:
		# braquage utile max : virage a la limite d'adherence (R = v2 / mu.g) + derive des pneus, avec une marge
		var utile := _wheelbase * mu * G / (nl * nl) + mu * G * masse / maxf(rigidite_avant * masse * G, 1.0)
		steer_limit = minf(steer_limit, utile * braquage_marge)
	var steer_goal := steer_in * steer_limit
	# volant qui revient seul au centre plus vite qu'il ne braque
	var rate := steer_speed * (1.6 if absf(steer_goal) < absf(_steer) else 1.0)
	_steer = move_toward(_steer, steer_goal, rate * delta)
	var L := _wheelbase
	var la := L * (1.0 - repartition_avant)     # CG -> essieu avant
	var lb := L * repartition_avant             # CG -> essieu arriere
	var iz := masse * la * lb * 1.15
	var vy := -v_lat                            # lateral vers la gauche
	var r := _yaw_rate
	var vx := nl
	var n_sub := 4
	var h := delta / n_sub
	var hand_on := hand and absf(vx) > 2.0
	for _k in n_sub:
		if absf(vx) < 2.5:
			# manoeuvre : geometrie d'Ackermann, glissade laterale amortie
			var rk := vx * tan(_steer) / L
			r = lerpf(r, rk, 1.0 - exp(-12.0 * h))
			vy = move_toward(vy, 0.0, mu * G * h)
			continue
		var fz_f := masse * (G * lb - _a_long * hauteur_cg) / L
		var fz_r := masse * (G * la + _a_long * hauteur_cg) / L
		var mu_f := mu
		var mu_r := mu * (0.35 if hand_on else 1.0)
		# cercle d'adherence : les roues motrices qui patinent ou freinent ont moins de grip lateral
		if patine:
			if part_motrice >= 0.99:
				mu_f *= 0.6
				mu_r *= 0.6
			elif part_motrice < 0.5:
				mu_r *= 0.55
			else:
				mu_f *= 0.55
		if bloque:
			mu_f *= 0.3
			mu_r *= 0.3
		var af := _steer - atan((vy + la * r) / vx)
		var ar := -atan((vy - lb * r) / vx)
		var cf := rigidite_avant * fz_f * (0.4 if hand_on else 1.0)
		var cr := rigidite_arriere * fz_r * (0.3 if hand_on else 1.0)
		var ff := mu_f * fz_f * tanh(cf * af / maxf(mu_f * fz_f, 1.0))
		var fr := mu_r * fz_r * tanh(cr * ar / maxf(mu_r * fz_r, 1.0))
		var dvy := (ff * cos(_steer) + fr) / masse - vx * r
		var dr := (la * ff * cos(_steer) - lb * fr) / iz
		vy += dvy * h
		r += dr * h
		# ESP : freinage selectif simule, la derive de la caisse et le lacet sont ramenes vers la trajectoire
		if esp > 0.0 and not hand_on:
			var beta := atan2(vy, absf(vx))
			if absf(beta) > esp_seuil:
				var exces := (absf(beta) - esp_seuil) * signf(beta)
				vy -= exces * absf(vx) * esp * 6.0 * h
			var r_max := mu * G / maxf(absf(vx), 1.0) * 1.1
			if absf(r) > r_max:
				r = move_toward(r, signf(r) * r_max, absf(r) * esp * 8.0 * h)
	_yaw_rate = r
	var nlat := -vy
	derive = atan2(vy, maxf(absf(vx), 1.0))
	# vitesses calculees dans le repere de la caisse (le terme vx.r y tient deja compte de sa rotation) : on les
	# remet dans le monde avec le cap mis a jour
	_yaw += _yaw_rate * delta
	rotation.y = _yaw
	fwd = Vector2(-sin(_yaw), -cos(_yaw))
	right = Vector2(cos(_yaw), -sin(_yaw))
	_vel = fwd * nl + right * nlat

	# --- deplacement et chocs ---
	var before := _vel
	velocity.x = _vel.x
	velocity.z = _vel.y
	if not is_on_floor():
		velocity.y -= G * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_crash_cd = maxf(0.0, _crash_cd - delta)
	var marche := false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		if absf(n.y) > 0.6:
			continue
		# bordure, trottoir : obstacle bas que les roues franchissent ; la caisse monte, pas de choc ni de degats
		var haut := _hauteur_obstacle(c.get_position(), n)
		if haut < marche_max and absf(speed) > 0.5:
			if not marche:
				global_position.y += haut + 0.03
				marche = true
			continue
		var n2 := Vector2(n.x, n.z).normalized()
		var impact := -before.dot(n2)
		if impact > 1.5:
			_vel -= n2 * _vel.dot(n2) * 1.25        # rebond leger
			_vel *= 0.85
			if _crash_cd <= 0.0 and impact > 3.0:
				_crash_cd = 0.4
				_crash.volume_db = linear_to_db(clampf(impact / 15.0, 0.15, 1.0))
				_crash.play()
				damage((impact - 3.0) * 2.2)
				enfoncer(c.get_position(), n, impact)
				crashed.emit(impact, c.get_collider())
				get_tree().call_group("circulation", "on_vehicle_hit", c.get_collider(), impact)
	# filet de securite : jamais sous la carte (retour au dernier endroit sur, a l'arret)
	# (sous le fond marin des limites du monde, -1,2 m : l estran de la plage descend jusque-la)
	if global_position.y < -2.0:
		global_position = _last_safe + Vector3.UP * 0.3
		_vel = Vector2.ZERO
		velocity = Vector3.ZERO
	elif is_on_floor() and global_position.y > -0.3:
		_last_safe = global_position
	# dans la mer (surface a -0,3 m) : l eau freine fort, on ne traverse pas l ocean en voiture
	if global_position.y < -0.5:
		_vel *= exp(-1.6 * delta)
	var rv := get_real_velocity()
	if marche:
		_vel = before * 0.96                     # la bordure secoue un peu, sans arreter la voiture
	elif Vector2(rv.x, rv.z).length() < _vel.length():
		_vel = Vector2(rv.x, rv.z)
	speed = _vel.dot(Vector2(-sin(_yaw), -cos(_yaw)))
	_a_long = lerpf(_a_long, (speed - v_long) / delta, 1.0 - exp(-6.0 * delta))
	_a_lat = lerpf(_a_lat, speed * _yaw_rate, 1.0 - exp(-6.0 * delta))
	_update_visual(delta, absf(nlat))
	_update_sound(delta, absf(nlat))
	_effets(delta)


func _hauteur_obstacle(contact: Vector3, n: Vector3) -> float:
	## Hauteur du dessus de l'obstacle au-dessus du sol sous la voiture (rayons verticaux, pas le point de contact
	## renvoye par le moteur, qui est au milieu de la zone de contact).
	var space := get_world_3d().direct_space_state
	var dans := contact - Vector3(n.x, 0.0, n.z).normalized() * 0.08
	var q := PhysicsRayQueryParameters3D.create(dans + Vector3.UP * 2.0, dans - Vector3.UP * 2.0)
	q.exclude = [get_rid()]
	var h1 := space.intersect_ray(q)
	var q2 := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position - Vector3.UP * 3.0)
	q2.exclude = [get_rid()]
	var h2 := space.intersect_ray(q2)
	if h1.is_empty() or h2.is_empty():
		return INF
	return (h1["position"] as Vector3).y - (h2["position"] as Vector3).y


func _clignotants(steer_in: float) -> void:
	## Clignotant automatique : en ville, on tourne (volant tenu d'un cote, sous ~50 km/h) ; s'eteint en sortant du
	## virage, comme le volant qui revient au centre.
	if not has_rider:
		_clign_cote = 0
	elif absf(steer_in) > 0.5 and absf(speed) < 14.0 and absf(speed) > 0.5:
		_clign_cote = -1 if steer_in > 0.0 else 1
	elif absf(_steer) < 0.05:
		_clign_cote = 0


func _update_visual(delta: float, slip: float) -> void:
	_suspension(delta)
	for st in _steer_nodes:
		st.rotation.y = _steer
	for w in _wheel_nodes:
		w.rotation.x -= speed / _wheel_r * delta
	var night: float = _day_night.get("night") if _day_night else 0.0
	_tail_mat.emission_energy_multiplier = (2.5 if braking else 0.0) + night * 0.8
	for i in _lights.size():
		var l := _lights[i]
		l.light_energy = 0.0 if _phares_casses[i] else (6.0 * night if has_rider or speed != 0.0 else 0.0)
	if _feu_lum:
		_feu_lum.light_energy = 1.6 + randf() * 0.9
	_recul.light_energy = 2.5 if rapport < 0 and absf(speed) > 0.05 and has_rider else 0.0
	# clignotants (1,5 Hz) : warnings si la voiture est abimee, sinon le cote ou l'on tourne
	if _clign_mat:
		_clign_t += delta
		var phase := fmod(_clign_t * 1.5, 1.0) < 0.5
		var warn := health < 40.0
		var g := 1.0 if phase and (warn or _clign_cote < 0) else 0.0
		var d := 1.0 if phase and (warn or _clign_cote > 0) else 0.0
		_clign_mat.set_shader_parameter("gauche", g)
		_clign_mat.set_shader_parameter("droite", d)
		var on := g + d > 0.0
		if on != _clign_on and has_rider and (warn or _clign_cote != 0) and not _fx.playing:
			_fx.stream = _son("tic", func() -> AudioStream: return AudioSynth.tic_clignotant())
			_fx.volume_db = -14.0
			_fx.play()
		_clign_on = on
	if (slip > 3.0 and absf(speed) > 4.0) or patine:
		_screech.volume_db = linear_to_db(clampf((slip - 3.0) / 6.0, 0.05, 1.0)) - 4.0
	else:
		_screech.volume_db = -80.0


func _suspension(delta: float) -> void:
	## Roues qui suivent le sol (rayon sous chaque roue), caisse sur ressorts amortis : hauteur, tangage, roulis.
	var off := [0.0, 0.0, 0.0, 0.0]
	if (has_rider or ai or absf(speed) > 0.5) and is_inside_tree():
		var space := get_world_3d().direct_space_state
		for i in _susp.size():
			var top: Vector3 = _visual.global_transform * ((_susp[i][1] as Vector3) + Vector3(0, 0.45, 0))
			var q := PhysicsRayQueryParameters3D.create(top, top - Vector3(0, 1.2, 0), 1, [get_rid()])
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				off[i] = clampf((hit["position"] as Vector3).y - (top.y - 0.45 - _wheel_r), -debattement, debattement)
	var front := 0.0
	var rear := 0.0
	var left := 0.0
	var right := 0.0
	for i in _susp.size():
		var w: Node3D = _susp[i][0]
		w.position.y = lerpf(w.position.y, (_susp[i][1] as Vector3).y + off[i], 1.0 - exp(-25.0 * delta))
		if _susp[i][2]:
			front += off[i] * 0.5
		else:
			rear += off[i] * 0.5
		if _susp[i][3]:
			left += off[i] * 0.5
		else:
			right += off[i] * 0.5
	var target := Vector3((front + rear) * 0.5,
		clampf((front - rear) / _wheelbase + _a_long * pitch_factor, -0.08, 0.07),
		clampf((right - left) / 1.5 - _a_lat * roll_factor, -0.09, 0.09))
	var w0 := TAU * suspension_freq
	var acc := (target - _sq) * w0 * w0 - _sv * 2.0 * suspension_amort * w0
	_sv += acc * delta
	_sq += _sv * delta
	_pitch = _sq.y
	_roll = _sq.z
	var cg := Vector3(0, 0.55, 0)
	var body := Transform3D(Basis.from_euler(Vector3(_sq.y, 0.0, _sq.z)), Vector3(0, _sq.x, 0))
	body = Transform3D(Basis.IDENTITY, cg) * body * Transform3D(Basis.IDENTITY, -cg)
	for p in _parts:
		(p[0] as Node3D).transform = body * (p[1] as Transform3D)


func _update_sound(delta: float, _slip: float) -> void:
	## Moteur : deux boucles (en charge / a vide) accordees sur le regime et melangees selon l'accelerateur ; roulement
	## selon le revetement, vent au-dela de 60 km/h, clonc du passage de rapport, petarades au lever de pied.
	if health <= 0.0:
		rpm = lerpf(rpm, 0.0, 1.0 - exp(-6.0 * delta))
	var pitch := maxf(0.25, rpm / AudioSynth.MOTEUR_REF_RPM)
	_engine.pitch_scale = pitch
	_engine_off.pitch_scale = pitch
	var load := clampf(throttle, 0.0, 1.0)
	var vol := -11.0 + 7.0 * clampf(rpm / regime_max, 0.0, 1.0)
	if not moteur and _demarreur_t <= 0.0:
		rpm = lerpf(rpm, 0.0, 1.0 - exp(-4.0 * delta))
	if health <= 0.0 or (not moteur and _demarreur_t <= 0.0):
		_engine.volume_db = -80.0
		_engine_off.volume_db = -80.0
	else:
		_engine.volume_db = vol + linear_to_db(maxf(load, 0.05)) + 3.0
		_engine_off.volume_db = vol + linear_to_db(maxf(1.0 - load, 0.05)) - 1.0
	var v := absf(speed)
	var gravier := surface in ["terre", "plage", "herbe"]
	if gravier != _roll_gravier:
		_roll_gravier = gravier
		_roul.stream = _son("roll%s" % gravier, func() -> AudioStream: return AudioSynth.roulement_loop(gravier))
		_roul.play()
	_roul.volume_db = linear_to_db(clampf(v / 25.0, 0.0, 1.0) * (1.0 if gravier else 0.6) + 0.0001) - 6.0
	_roul.pitch_scale = clampf(0.7 + v / 40.0, 0.7, 1.6)
	_wind.volume_db = linear_to_db(clampf((v - 15.0) / 25.0, 0.0, 1.0) + 0.0001) - 8.0
	if rapport != _rapport_prec and rapport > 0 and _rapport_prec >= 0 and not _fx.playing:
		_fx.stream = _son("rapport", func() -> AudioStream: return AudioSynth.passage_rapport())
		_fx.volume_db = -8.0
		_fx.play()
	_rapport_prec = rapport
	if model_name == "veh_berline" and _thr_prec > 0.7 and throttle < 0.2 and rpm > regime_max * 0.7 and randf() < 0.5 and not _fx.playing:
		_fx.stream = _son("petarade", func() -> AudioStream: return AudioSynth.petarade())
		_fx.volume_db = -4.0
		_fx.play()
	_thr_prec = throttle


static var _tache_tex: Texture2D


static func _tache() -> Texture2D:
	## Tache ronde et floue (blanc au centre, transparent au bord) pour la fumee, la poussiere et les flammes.
	if _tache_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_tache_tex = t
	return _tache_tex
