extends Node3D
## Cycle jour / nuit de Cotonou (latitude ~6,4 N) :
## - soleil : lever ~6 h 30 a l'est, presque au zenith a midi (legerement au sud), coucher ~18 h 30 a l'ouest ;
## - lune opposee au soleil la nuit (lumiere bleutee faible) ;
## - ciel (shader ciel_nuages) : couleurs de jour, coucher de soleil, nuit etoilee ;
## - variables globales des shaders : gtb_night (fenetres, lampes) et gtb_power (delestages) ;
## - vraies lumieres sous les lampadaires les plus proches du joueur (pool de SpotLight3D) ;
## - delestages aleatoires la nuit (le courant saute, scintille et revient).
## Touche F2 : avancer d'une heure (pratique pour tester). Horloge affichee en haut a droite.

@export var start_hour := 16.0
@export var minutes_per_game_day := 48.0     # duree reelle d'une journee de jeu
@export var sun_path: NodePath = ^"../Sun"
@export var env_path: NodePath = ^"../WorldEnvironment"
@export var props_path: NodePath = ^"../Props"
@export var light_pool_size := 40        # vraies lumieres sous les lampadaires les plus proches (avant 14)
@export var portee_halos := 300.0        # tous les lampadaires dans ce rayon eclairent la chaussee d une tache de lumiere
@export var power_cut_chance_per_hour := 0.3

var hour := 16.0
var power := 1.0
var night := 0.0   # 0 jour, 1 nuit (lu par ambience.gd et les autres systemes)
var _cut_left := 0.0           # secondes reelles de coupure restantes
var _next_cut_check := 0.0
var _flicker := 0.0
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment
var _sky_mat: ShaderMaterial
var _pool: Array[SpotLight3D] = []
var _pool_timer := 0.0
var _clock: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	hour = start_hour
	_rng.randomize()
	_sun = get_node(sun_path) as DirectionalLight3D
	var we := get_node(env_path) as WorldEnvironment
	_env = we.environment
	_sky_mat = _env.sky.sky_material as ShaderMaterial
	_moon = DirectionalLight3D.new()
	_moon.name = "Lune"
	_moon.light_color = Color(0.6, 0.7, 1.0)
	_moon.shadow_enabled = true
	_moon.directional_shadow_max_distance = 120.0
	add_child(_moon)
	for i in light_pool_size:
		var l := SpotLight3D.new()
		l.spot_range = 24.0
		l.spot_angle = 68.0
		l.spot_attenuation = 0.9
		l.light_energy = 0.0
		l.light_color = Color(1.0, 0.8, 0.55)
		l.shadow_enabled = false
		l.rotation_degrees = Vector3(-90, 0, 0)  # eclaire vers le bas
		add_child(l)
		_pool.append(l)
	_faire_halos()
	var layer := CanvasLayer.new()
	add_child(layer)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 22)
	_clock.add_theme_color_override("font_color", Color(1, 1, 1))
	_clock.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_clock.add_theme_constant_override("outline_size", 6)
	_clock.anchor_left = 1.0
	_clock.anchor_right = 1.0
	_clock.offset_left = -300
	_clock.offset_right = -14
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_clock.offset_top = 12
	layer.add_child(_clock)
	_update(0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2:
		hour = fmod(hour + 1.0, 24.0)


func sun_direction(h: float) -> Vector3:
	## Direction VERS le soleil (X = est, Y = haut, Z = sud).
	var theta := (h - 6.5) / 24.0 * TAU
	var tilt := 0.12  # le soleil de midi passe un peu au sud du zenith
	return Vector3(cos(theta), sin(theta) * cos(tilt), sin(theta) * sin(tilt)).normalized()


func _process(delta: float) -> void:
	hour = fmod(hour + delta * 24.0 / (minutes_per_game_day * 60.0), 24.0)
	_update(delta)


func _update(delta: float) -> void:
	var sd := sun_direction(hour)
	var elev := asin(clamp(sd.y, -1.0, 1.0))
	night = 1.0 - smoothstep(-0.12, 0.06, elev)
	var low := 1.0 - smoothstep(0.0, 0.45, elev)  # soleil bas : lumiere doree

	# --- soleil ---
	_sun.visible = elev > -0.05
	_sun.global_transform = Transform3D(Basis.looking_at(-sd, Vector3(0, 0, 1)), Vector3(0, 50, 0))
	_sun.light_energy = 1.6 * pow(clamp(sin(elev) * 2.5, 0.0, 1.0), 0.7)
	_sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.55, 0.28), low)
	# --- lune ---
	var md := -sd
	md.y = abs(md.y) * 0.9 + 0.1
	_moon.visible = night > 0.05
	_moon.global_transform = Transform3D(Basis.looking_at(-md.normalized(), Vector3(0, 0, 1)), Vector3(0, 50, 0))
	_moon.light_energy = 0.14 * night

	# --- ciel et ambiance ---
	if _sky_mat:
		_sky_mat.set_shader_parameter("sun_dir_u", sd)
		_sky_mat.set_shader_parameter("night", night)
	_env.ambient_light_energy = lerp(0.6, 0.2, night)  # nuit lisible (comme dans les jeux du genre)
	_env.ambient_light_color = Color(0.55, 0.5, 0.45).lerp(Color(0.25, 0.3, 0.5), night)
	_env.fog_light_color = Color(0.72, 0.8, 0.88).lerp(Color(0.05, 0.06, 0.1), night).lerp(Color(0.95, 0.6, 0.4), low * (1.0 - night) * 0.6)
	_env.background_energy_multiplier = lerp(1.0, 0.6, night)

	# --- delestages (uniquement la nuit) ---
	_next_cut_check -= delta
	if _cut_left > 0.0:
		_cut_left -= delta
	elif _next_cut_check <= 0.0:
		# un tirage par heure de jeu
		_next_cut_check = minutes_per_game_day * 60.0 / 24.0
		if night > 0.5 and _rng.randf() < power_cut_chance_per_hour:
			_cut_left = _rng.randf_range(90.0, 360.0)
			_flicker = 1.2
	var target_power := 0.0 if _cut_left > 0.0 else 1.0
	if _flicker > 0.0:
		_flicker -= delta
		target_power = 1.0 if fmod(_flicker * 13.0, 1.0) > 0.5 else 0.15  # le courant vacille avant de sauter
	power = move_toward(power, target_power, delta * 6.0)
	RenderingServer.global_shader_parameter_set("gtb_night", night)
	RenderingServer.global_shader_parameter_set("gtb_power", power)

	# --- lumieres reelles sous les lampadaires proches ---
	_pool_timer -= delta
	var on := night * power
	if _pool_timer <= 0.0:
		_pool_timer = 0.4
		_assign_pool()
	for l in _pool:
		l.light_energy = 7.0 * on if l.visible else 0.0
	if _halos:
		_halos.visible = on > 0.02
		_halo_mat.albedo_color.a = 0.8 * on

	_clock.text = "%02d:%02d%s" % [int(hour), int(fmod(hour, 1.0) * 60.0), "  (delestage)" if _cut_left > 0.0 and night > 0.5 else ""]


var _halos: MultiMeshInstance3D
var _halo_mat: StandardMaterial3D


func _faire_halos() -> void:
	## Tache de lumiere chaude sur la chaussee sous CHAQUE lampadaire proche (les vraies lumieres, couteuses, ne couvrent que
	## les plus proches de la camera) : en ville, tous les lampadaires eclairent, meme ceux du fond de la rue.
	var q := QuadMesh.new()
	q.size = Vector2(18.0, 18.0)
	q.orientation = PlaneMesh.FACE_Y
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.78, 0.45, 1.0))
	g.set_color(1, Color(1.0, 0.7, 0.35, 0.0))
	g.add_point(0.35, Color(1.0, 0.76, 0.42, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_mat.albedo_texture = tex
	_halo_mat.albedo_color = Color(1, 1, 1, 0.0)
	_halo_mat.disable_fog = true
	q.material = _halo_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = 0
	_halos = MultiMeshInstance3D.new()
	_halos.name = "HalosLampadaires"
	_halos.multimesh = mm
	_halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halos.visible = false
	add_child(_halos)


func _maj_halos(c: Vector3, lamps: PackedVector3Array) -> void:
	var liste := []
	for p in lamps:
		if c.distance_squared_to(p) < portee_halos * portee_halos:
			liste.append(Transform3D(Basis.IDENTITY, Vector3(p.x, p.y - 8.1 + 0.05, p.z)))
	var mm := _halos.multimesh
	mm.instance_count = liste.size()
	for i in liste.size():
		mm.set_instance_transform(i, liste[i])


func _assign_pool() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	var props := get_node_or_null(props_path)
	if props == null:
		return
	var lamps: PackedVector3Array = props.lamp_positions
	if _halos and night * power > 0.02:
		_maj_halos(c, lamps)
	# les plus proches (selection partielle simple)
	var best: Array = []
	for p in lamps:
		var d := c.distance_squared_to(p)
		if d > 140.0 * 140.0:
			continue
		best.append([d, p])
	best.sort_custom(func(a, b): return a[0] < b[0])
	for i in _pool.size():
		var l := _pool[i]
		if i < best.size():
			l.visible = true
			l.global_position = best[i][1] - Vector3(0, 0.15, 0)
		else:
			l.visible = false
