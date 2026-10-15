extends Node3D
class_name Avion
## Avion de ligne anime (assets/models/veh_avion_ligne.glb, blender/tools/build_avion.py).
## Pilote par air_traffic.gd : trains (sortis / rentres, roues qui tournent, roue avant qui braque), volets,
## spoilers, inverseurs de poussee, soufflantes, feux (navigation, anticollision, strobes, phares), son des
## reacteurs, fumee des pneus au toucher, collision (on ne traverse pas un avion au sol).
## Livrees : compagnies fictives (docs/LEGAL.md), couleurs et titres poses ici.

const MODEL := preload("res://assets/models/veh_avion_ligne.glb")
const FEU := preload("res://shaders/feu.gdshader")
const LIVERIES := {
	"air_gbe": {"c1": Color(0.07, 0.47, 0.24), "c2": Color(0.96, 0.75, 0.1), "titre": "Air Gbé", "logo": "GBÉ", "immat": "GB-AGB"},
	"atlantique": {"c1": Color(0.05, 0.22, 0.52), "c2": Color(0.1, 0.55, 0.82), "titre": "Atlantique Express", "logo": "AE", "immat": "GB-TAE"},
	"sahel": {"c1": Color(0.78, 0.42, 0.1), "c2": Color(0.5, 0.18, 0.08), "titre": "Sahel Airways", "logo": "SA", "immat": "GB-SAH"},
	"golfe": {"c1": Color(0.08, 0.42, 0.48), "c2": Color(0.08, 0.3, 0.36), "titre": "Golfe Aviation", "logo": "GA", "immat": "GB-GLF"},
	"trans_ouest": {"c1": Color(0.6, 0.08, 0.12), "c2": Color(0.75, 0.1, 0.15), "titre": "Trans-Ouest", "logo": "TO", "immat": "GB-TRO"},
	"air_lagune": {"c1": Color(0.15, 0.6, 0.65), "c2": Color(0.95, 0.55, 0.15), "titre": "Air Lagune", "logo": "AL", "immat": "GB-LAG"},
}
const MAIN_R := 0.57
const NOSE_R := 0.38

var gear := 1.0          # 1 sorti, 0 rentre
var flaps := 0.0         # 0 rentres, 1 atterrissage
var spoilers := 0.0
var reverse := 0.0
var n1 := 0.0            # regime des reacteurs 0..1 (0 : arretes)
var steer := 0.0         # braquage de la roue avant (rad)
var speed := 0.0         # vitesse au sol (m/s) pour les roues
var on_ground := true
var lights := {"nav": false, "beacon": false, "strobe": false, "landing": false, "taxi": false}
var livery := "air_gbe"
var day: Node                    # JourNuit (feux plus forts la nuit), pose par air_traffic.gd

var _model: Node3D
var _parts := {}
var _rest := {}
var _wheels: Array = []          # [noeud, rayon]
var _fan_angle := 0.0
var _t := 0.0
var _sprites := {}
var _omni := {}
var _spots: Array[SpotLight3D] = []
var _snd: AudioStreamPlayer3D
var _body: AnimatableBody3D
var _smoke: Array[GPUParticles3D] = []


func _ready() -> void:
	_model = MODEL.instantiate()
	add_child(_model)
	for n in ["train_avant", "train_avant_dir", "train_principal_G", "train_principal_D", "volet_int_G", "volet_int_D",
			"volet_ext_G", "volet_ext_D", "spoiler_G", "spoiler_D", "inverseur_G", "inverseur_D", "soufflante_G", "soufflante_D"]:
		var p := _model.find_child(n, true, false) as Node3D
		if p:
			_parts[n] = p
			_rest[n] = p.transform
	for w in _model.find_children("roue_*", "Node3D", true, false):
		if String(w.name).begins_with("roue_contact"):
			continue
		_wheels.append([w, NOSE_R if String(w.name).begins_with("roue_avant") else MAIN_R])
	_build_lights()
	_build_body()
	_build_smoke()
	_snd = AudioStreamPlayer3D.new()
	_snd.stream = AudioSynth.jet_loop()
	_snd.unit_size = 45.0
	_snd.max_distance = 3000.0
	_snd.volume_db = -80.0
	add_child(_snd)
	apply_livery(livery)


func apply_livery(key: String) -> void:
	livery = key if LIVERIES.has(key) else "air_gbe"
	var lv: Dictionary = LIVERIES[livery]
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for s in m3.mesh.get_surface_count():
			var m := m3.mesh.surface_get_material(s)
			if m == null:
				continue
			var col := Color.TRANSPARENT
			if m.resource_name == "mat_avion_livree_1":
				col = lv["c1"]
			elif m.resource_name == "mat_avion_livree_2":
				col = lv["c2"]
			if col.a > 0.0 and m is BaseMaterial3D:
				var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.albedo_color = col
				m3.set_surface_override_material(s, d)
	for c in _model.get_children():
		if c is Label3D:
			c.queue_free()
	# titres sur le fuselage (lisibles des deux cotes), logo sur la derive, immatriculation
	for side: float in [-1.0, 1.0]:
		var sn := "G" if side < 0 else "D"
		var t := _marker("titre_" + sn)
		if t != Vector3.INF:
			# au-dessus des hublots, colle a la peau du fuselage (incline comme elle)
			_label(lv["titre"], Vector3(side * 1.72, 4.47, t.z), side, 0.82, Color(lv["c1"]), deg_to_rad(31.0))
		var r := _marker("immatriculation_" + sn)
		if r != Vector3.INF:
			_label(lv["immat"], r + Vector3(-side * 0.25, 0, 0), side, 0.32, Color(0.15, 0.15, 0.18))
		var g := _marker("logo_derive")
		if g != Vector3.INF:
			_label(lv["logo"], g + Vector3(side * 0.24, 0, 0), side, 1.1, Color(1, 1, 1))


func _marker(n: String) -> Vector3:
	var e := _model.find_child(n, true, false) as Node3D
	return e.position if e else Vector3.INF


func _label(text: String, at: Vector3, side: float, height: float, col: Color, tilt := 0.0) -> void:
	if at == Vector3.INF:
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = height / 96.0
	l.outline_size = 0
	l.modulate = col
	l.shaded = true
	l.double_sided = false
	l.position = at
	l.basis = Basis(Vector3.BACK, side * tilt) * Basis(Vector3.UP, side * PI / 2.0)
	_model.add_child(l)


# ------------------------------------------------------------------ feux
func _sprite(at: Vector3, col: Color, size: float, energy: float, parent: Node3D = null) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = FEU
	m.set_shader_parameter("color", Vector3(col.r, col.g, col.b))
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("min_size", size)
	m.set_shader_parameter("px", 0.0018)
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	(parent if parent else _model).add_child(mi)
	return mi


func _build_lights() -> void:
	var defs := {"feu_nav_G": [Color(1, 0.1, 0.05), "nav"], "feu_nav_D": [Color(0.1, 1, 0.25), "nav"],
		"feu_queue": [Color(1, 1, 1), "nav"], "feu_anticollision_haut": [Color(1, 0.08, 0.04), "beacon"],
		"feu_anticollision_bas": [Color(1, 0.08, 0.04), "beacon"], "feu_strobe_G": [Color(1, 1, 1), "strobe"],
		"feu_strobe_D": [Color(1, 1, 1), "strobe"], "phare_atterrissage_G": [Color(1, 0.97, 0.9), "landing"],
		"phare_atterrissage_D": [Color(1, 0.97, 0.9), "landing"]}
	for n in defs:
		var at := _marker(n)
		if at == Vector3.INF:
			continue
		var kind: String = defs[n][1]
		var sp := _sprite(at, defs[n][0], 0.35 if kind != "landing" else 0.7, 4.0 if kind != "strobe" else 9.0)
		if not _sprites.has(kind):
			_sprites[kind] = []
		_sprites[kind].append(sp)
		if kind == "beacon" or kind == "strobe":
			var o := OmniLight3D.new()
			o.light_color = defs[n][0]
			o.omni_range = 14.0 if kind == "beacon" else 22.0
			o.light_energy = 0.0
			o.shadow_enabled = false
			o.position = at
			_model.add_child(o)
			if not _omni.has(kind):
				_omni[kind] = []
			_omni[kind].append(o)
		if kind == "landing":
			var s := SpotLight3D.new()
			s.light_color = Color(1, 0.96, 0.88)
			s.spot_range = 320.0
			s.spot_angle = 11.0
			s.light_energy = 9.0
			s.shadow_enabled = false
			s.position = at
			s.rotation = Vector3(deg_to_rad(-4.0), 0, 0)
			_model.add_child(s)
			_spots.append(s)
	var taxi := _model.find_child("phare_roulage", true, false) as Node3D
	if taxi:
		var s := SpotLight3D.new()
		s.spot_range = 90.0
		s.spot_angle = 25.0
		s.light_energy = 5.0
		s.shadow_enabled = false
		s.rotation = Vector3(deg_to_rad(-6.0), 0, 0)
		taxi.add_child(s)
		_spots.append(s)
		_sprites["taxi"] = [_sprite(Vector3.ZERO, Color(1, 0.97, 0.9), 0.4, 4.0, taxi)]   # suit le train avant


func _build_body() -> void:
	## Collision au sol : fuselage, ailes, reacteurs, empennage (le joueur et les vehicules ne traversent pas l'avion).
	_body = AnimatableBody3D.new()
	_body.sync_to_physics = false
	add_child(_body)
	for b in [[Vector3(0, 3.43, -1.8), Vector3(3.9, 3.9, 37.0)], [Vector3(0, 2.5, 0.4), Vector3(34.0, 0.7, 4.2)],
			[Vector3(5.75, 1.52, -2.6), Vector3(2.1, 2.1, 4.6)], [Vector3(-5.75, 1.52, -2.6), Vector3(2.1, 2.1, 4.6)],
			[Vector3(0, 8.0, 10.6), Vector3(0.6, 6.0, 4.5)]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = b[1]
		cs.shape = box
		cs.position = b[0]
		_body.add_child(cs)


func _build_smoke() -> void:
	for sn in ["roue_contact_G", "roue_contact_D"]:
		var at := _marker(sn)
		if at == Vector3.INF:
			continue
		var p := GPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = 40
		p.lifetime = 2.2
		p.explosiveness = 0.85
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 0.4, 1)
		pm.spread = 35.0
		pm.initial_velocity_min = 4.0
		pm.initial_velocity_max = 12.0
		pm.gravity = Vector3(0, 0.6, 0)
		pm.damping_min = 3.0
		pm.damping_max = 5.0
		pm.scale_min = 1.0
		pm.scale_max = 2.6
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(1, 1.6))
		var ct := CurveTexture.new()
		ct.curve = curve
		pm.scale_curve = ct
		var grad := Gradient.new()
		grad.set_color(0, Color(0.88, 0.88, 0.88, 0.45))
		grad.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = grad
		pm.color_ramp = gt
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(1.2, 1.2)
		var sm := StandardMaterial3D.new()
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.vertex_color_use_as_albedo = true
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		# bouffee ronde et douce (degrade radial), sinon les particules sont des carres
		var puff := GradientTexture2D.new()
		puff.fill = GradientTexture2D.FILL_RADIAL
		puff.fill_from = Vector2(0.5, 0.5)
		puff.fill_to = Vector2(1.0, 0.5)
		puff.width = 64
		puff.height = 64
		var pg := Gradient.new()
		pg.set_color(0, Color(1, 1, 1, 1))
		pg.set_color(1, Color(1, 1, 1, 0))
		pg.add_point(0.5, Color(1, 1, 1, 0.55))
		puff.gradient = pg
		sm.albedo_texture = puff
		sm.proximity_fade_enabled = true
		sm.proximity_fade_distance = 1.5
		q.material = sm
		p.draw_pass_1 = q
		p.position = at + Vector3(0, 0.1, 0)
		p.local_coords = false
		_model.add_child(p)
		_smoke.append(p)


var _ground_kit: Node3D


func set_parked(on: bool) -> void:
	## Au poste : escalier mobile a la porte avant gauche et cones de securite (bouts d'aile, nez, reacteurs).
	_cabin_access(on)
	if not on:
		if _ground_kit:
			_ground_kit.queue_free()
			_ground_kit = null
		return
	if _ground_kit:
		return
	_ground_kit = Node3D.new()
	add_child(_ground_kit)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.9)
	white.roughness = 0.5
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.35, 0.36, 0.38)
	grey.metallic = 0.5
	grey.roughness = 0.5
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(1.0, 0.42, 0.05)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.09)
	var door_z := -15.75
	# escalier mobile : camion perpendiculaire au fuselage, palier au seuil de la porte (2,7 m)
	_kit_box(Vector3(6.2, 1.1, 2.3), Vector3(-6.9, 1.05, door_z), white)
	_kit_box(Vector3(1.6, 1.3, 2.2), Vector3(-10.4, 1.5, door_z), white)
	_kit_box(Vector3(0.05, 0.6, 2.0), Vector3(-11.22, 1.75, door_z), dark)
	for wz: float in [-0.85, 0.85]:
		for wx: float in [-9.4, -5.0]:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.4
			cyl.bottom_radius = 0.4
			cyl.height = 0.3
			cyl.material = dark
			w.mesh = cyl
			_ground_kit.add_child(w)
			w.position = Vector3(wx, 0.4, door_z + wz * 1.1)
			w.rotation = Vector3(PI / 2.0, 0, 0)
	# volee de marches : du plateau du camion (1,2 m) au palier (2,66 m), pente de 15 degres
	var slope := deg_to_rad(15.0)
	var stairs := _kit_box(Vector3(5.6, 0.12, 1.4), Vector3(-5.4, 1.93, door_z), grey)
	stairs.rotation = Vector3(0, 0, slope)
	_kit_box(Vector3(1.3, 0.1, 1.6), Vector3(-2.55, 2.53, door_z), grey)   # sous le haut de la volee : pas de rebord
	for rz: float in [-0.72, 0.72]:
		var rail := _kit_box(Vector3(5.8, 0.05, 0.05), Vector3(-5.3, 2.9, door_z + rz), grey)
		rail.rotation = Vector3(0, 0, slope)
		for px: float in [-7.9, -5.3, -2.7]:
			_kit_box(Vector3(0.05, 0.95, 0.05), Vector3(px, 1.93 + (px + 5.4) * tan(slope) + 0.48, door_z + rz), grey)
	# cones
	for c in [Vector3(-17.8, 0, 4.0), Vector3(17.8, 0, 4.0), Vector3(0, 0, -23.0), Vector3(-5.75, 0, -7.2), Vector3(5.75, 0, -7.2), Vector3(0, 0, 19.0)]:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.17
		cm.height = 0.55
		cm.material = orange
		cone.mesh = cm
		_ground_kit.add_child(cone)
		cone.position = (c as Vector3) + Vector3(0, 0.29, 0)


func _kit_box(size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = m
	mi.mesh = b
	_ground_kit.add_child(mi)
	mi.position = at
	# collision : on monte l'escalier a pied
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	mi.add_child(sb)
	return mi


func touchdown() -> void:
	## Contact du train principal : fumee des pneus et crissement.
	for p in _smoke:
		p.restart()
	var chirp := AudioStreamPlayer3D.new()
	chirp.stream = AudioSynth.crissement_loop()
	chirp.unit_size = 30.0
	chirp.max_distance = 1500.0
	add_child(chirp)
	chirp.play()
	get_tree().create_timer(0.7).timeout.connect(chirp.queue_free)


# ------------------------------------------------------------------ animation
func _physics_process(_delta: float) -> void:
	if _body:
		_body.global_transform = global_transform
		# en vol (au-dessus de 15 m), plus de collision
		for c in _body.get_children():
			(c as CollisionShape3D).disabled = global_position.y > 15.0 or (_hull != null and c.get_index() == 0)


func _process(delta: float) -> void:
	_t += delta
	var g := clampf(gear, 0.0, 1.0)
	_pose("train_avant", Basis(Vector3.RIGHT, deg_to_rad(95.0) * (1.0 - g)))
	_pose("train_principal_D", Basis(Vector3.BACK, -deg_to_rad(88.0) * (1.0 - g)))
	_pose("train_principal_G", Basis(Vector3.BACK, deg_to_rad(88.0) * (1.0 - g)))
	_pose("train_avant_dir", Basis(Vector3.UP, steer * g))
	var f := smoothstep(0.0, 1.0, flaps)
	for n in ["volet_int_G", "volet_int_D", "volet_ext_G", "volet_ext_D"]:
		var back := 0.95 if n.contains("int") else 0.62
		_pose(n, Basis(Vector3.RIGHT, deg_to_rad(32.0) * f), Vector3(0, 0, back * f))
	for n in ["spoiler_G", "spoiler_D"]:
		_pose(n, Basis(Vector3.RIGHT, -deg_to_rad(48.0) * spoilers))
	for n in ["inverseur_G", "inverseur_D"]:
		_pose(n, Basis(), Vector3(0, 0, 0.62 * reverse))
	_fan_angle = fmod(_fan_angle + delta * TAU * (n1 * 28.0), TAU)
	for n in ["soufflante_G", "soufflante_D"]:
		_pose(n, Basis(Vector3.BACK, _fan_angle))
	if on_ground or g > 0.5:
		for w in _wheels:
			(w[0] as Node3D).rotate_object_local(Vector3.RIGHT, -speed / float(w[1]) * delta)
	_update_lights()
	# son des reacteurs : regime + poussee inverse
	var loud := n1 + reverse * 0.5
	if loud > 0.02:
		if not _snd.playing:
			_snd.play()
		_snd.volume_db = linear_to_db(clampf(loud, 0.05, 1.4)) + 4.0
		_snd.pitch_scale = 0.55 + n1 * 0.65
	elif _snd.playing:
		_snd.stop()


func _pose(n: String, b: Basis, offset := Vector3.ZERO) -> void:
	if not _parts.has(n):
		return
	var rest: Transform3D = _rest[n]
	(_parts[n] as Node3D).transform = Transform3D(rest.basis * b, rest.origin + rest.basis * offset)


func _update_lights() -> void:
	var night: float = day.get("night") if day else 0.0
	var beacon_on := bool(lights["beacon"]) and fmod(_t, 1.25) < 0.12
	var strobe_ph := fmod(_t, 1.3)
	var strobe_on := bool(lights["strobe"]) and (strobe_ph < 0.05 or (strobe_ph > 0.14 and strobe_ph < 0.19))
	for kind in _sprites:
		var on := false
		match kind:
			"nav": on = lights["nav"]
			"beacon": on = beacon_on
			"strobe": on = strobe_on
			"landing": on = lights["landing"]
			"taxi": on = lights["taxi"]
		for sp in _sprites[kind]:
			(sp as MeshInstance3D).visible = on
	for o in _omni.get("beacon", []):
		(o as OmniLight3D).light_energy = (2.5 * night) if beacon_on else 0.0
	for o in _omni.get("strobe", []):
		(o as OmniLight3D).light_energy = (5.0 * night + 0.5) if strobe_on else 0.0
	for s in _spots:
		var want: bool = lights["taxi"] if s.get_parent().name == "phare_roulage" else lights["landing"]
		s.visible = want and night > 0.2


var _hull: StaticBody3D


func _cabin_access(on: bool) -> void:
	## Au poste : porte avant gauche ouverte et coque en collision exacte (le joueur entre dans la cabine par
	## l'escalier). En mouvement : porte fermee, collision simple en boites.
	var door := _model.find_child("porte_avant", true, false) as Node3D
	if door:
		door.visible = not on
	var fus_box := _body.get_child(0) as CollisionShape3D
	fus_box.disabled = on
	if on and _hull == null:
		_hull = StaticBody3D.new()
		add_child(_hull)
		for n in ["avion_fuselage", "avion_cabine", "avion_cabine_parois"]:
			var mi := _model.find_child(n, true, false) as MeshInstance3D
			if mi == null:
				continue
			var cs := CollisionShape3D.new()
			cs.shape = mi.mesh.create_trimesh_shape()
			_hull.add_child(cs)
			cs.global_transform = mi.global_transform
		# seuil de porte : petite rampe du palier de l'escalier (2,58 m) au plancher de la cabine (2,67 m)
		var sill := CollisionShape3D.new()
		var sb := BoxShape3D.new()
		sb.size = Vector3(0.8, 0.04, 0.8)
		sill.shape = sb
		_hull.add_child(sill)
		sill.global_transform = global_transform * Transform3D(Basis(Vector3(0, 0, 1), 0.13), Vector3(-1.85, 2.665, -15.75))
	elif not on and _hull:
		_hull.queue_free()
		_hull = null
