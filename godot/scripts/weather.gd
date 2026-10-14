extends Node3D
## Meteo tropicale de Cotonou : ciel degage / nuageux / averse / orage, transitions douces.
## - pluie : particules autour de la camera (inclinees par le vent), son de pluie ;
## - sol et murs mouilles (variable globale des shaders gtb_wet) : plus sombres, brillants, flaques ; sechage lent ;
## - orage : eclairs (flash) puis tonnerre avec un delai (la lumiere va plus vite que le son) ;
## - le ciel se couvre et s'assombrit, la lumiere baisse, la brume monte.
## Doit etre APRES le noeud JourNuit dans la scene (il module ce que JourNuit vient de regler).
## Touche F3 : declencher / arreter l'averse (test).

@export var sun_path: NodePath = ^"../Sun"
@export var env_path: NodePath = ^"../WorldEnvironment"
@export var rain_chance := 0.25          # probabilite qu'un nouvel episode soit pluvieux
@export var min_episode := 240.0          # secondes reelles
@export var max_episode := 720.0

var storm := 0.0      # 0 ciel normal, 1 ciel d'orage (lu par le ciel et la lumiere)
var rain := 0.0       # intensite de pluie
var wet := 0.0        # humidite du sol
var _target_storm := 0.0
var _target_rain := 0.0
var _thunder := false
var _episode := 0.0
var _flash := 0.0
var _next_flash := 0.0
var _rng := RandomNumberGenerator.new()
var _sun: DirectionalLight3D
var _env: Environment
var _sky_mat: ShaderMaterial
var _particles: GPUParticles3D
var _rain_snd: AudioStreamPlayer
var _thunder_snd: AudioStreamPlayer
var _pending_thunder := -1.0
var _rain_mat: StandardMaterial3D
@export var day_night_path: NodePath = ^"../JourNuit"


func _ready() -> void:
	_rng.randomize()
	_sun = get_node(sun_path) as DirectionalLight3D
	_env = (get_node(env_path) as WorldEnvironment).environment
	_sky_mat = _env.sky.sky_material as ShaderMaterial
	_build_rain()
	_rain_snd = AudioStreamPlayer.new()
	_rain_snd.stream = AudioSynth.pluie_loop()
	_rain_snd.volume_db = -80.0
	add_child(_rain_snd)
	_rain_snd.play()
	_thunder_snd = AudioStreamPlayer.new()
	_thunder_snd.volume_db = -2.0
	add_child(_thunder_snd)
	_episode = _rng.randf_range(min_episode * 0.5, max_episode)


func _build_rain() -> void:
	_particles = GPUParticles3D.new()
	_particles.amount = 9000
	_particles.lifetime = 1.4
	_particles.visibility_aabb = AABB(Vector3(-30, -25, -30), Vector3(60, 50, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 1, 28)
	pm.direction = Vector3(0.18, -1, 0.08)
	pm.spread = 2.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 17.0
	pm.gravity = Vector3(0, -2, 0)
	_particles.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.015, 0.55)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.8, 0.85, 0.35)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	quad.material = m
	_rain_mat = m
	_particles.draw_pass_1 = quad
	_particles.emitting = false
	add_child(_particles)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		if _target_rain > 0.0:
			_set_episode("degage")
		else:
			_set_episode("orage")


func _set_episode(kind: String) -> void:
	match kind:
		"degage":
			_target_storm = _rng.randf_range(0.0, 0.15)
			_target_rain = 0.0
			_thunder = false
		"nuageux":
			_target_storm = _rng.randf_range(0.35, 0.6)
			_target_rain = 0.0
			_thunder = false
		"averse":
			_target_storm = 0.8
			_target_rain = _rng.randf_range(0.5, 0.8)
			_thunder = false
		"orage":
			_target_storm = 1.0
			_target_rain = 1.0
			_thunder = true
			_next_flash = _rng.randf_range(4.0, 12.0)
	_episode = _rng.randf_range(min_episode, max_episode)


func _process(delta: float) -> void:
	_episode -= delta
	if _episode <= 0.0:
		var r := _rng.randf()
		if r < rain_chance * 0.4:
			_set_episode("orage")
		elif r < rain_chance:
			_set_episode("averse")
		elif r < rain_chance + 0.3:
			_set_episode("nuageux")
		else:
			_set_episode("degage")
	# transitions douces : le ciel se couvre avant la pluie, la pluie s'arrete avant que le ciel se degage
	storm = move_toward(storm, _target_storm, delta / 40.0)
	var rain_goal := _target_rain if storm > 0.6 else 0.0
	rain = move_toward(rain, rain_goal, delta / 15.0)
	wet = move_toward(wet, 1.0, delta * rain / 45.0) if rain > 0.05 else move_toward(wet, 0.0, delta / 240.0)
	RenderingServer.global_shader_parameter_set("gtb_wet", wet)

	# --- pluie autour de la camera ---
	var cam := get_viewport().get_camera_3d()
	if cam:
		_particles.global_position = cam.global_position + Vector3(0, 14, 0)
	_particles.emitting = rain > 0.02
	_particles.amount_ratio = clamp(rain, 0.05, 1.0)
	_rain_snd.volume_db = linear_to_db(max(rain, 0.0001)) - 4.0
	# la nuit, les gouttes ne se voient presque plus (sauf pres des lumieres)
	var dn := get_node_or_null(day_night_path)
	var night: float = dn.night if dn else 0.0
	_rain_mat.albedo_color = Color(0.75, 0.8, 0.85, 0.35).lerp(Color(0.25, 0.27, 0.3, 0.12), night)

	# --- lumiere, ciel, brume (module les valeurs que JourNuit vient de regler) ---
	_sun.light_energy *= 1.0 - 0.8 * storm
	_sun.shadow_opacity = 1.0 - 0.7 * storm
	_env.ambient_light_energy *= 1.0 - 0.35 * storm
	_env.fog_density = 0.0003 + 0.0022 * rain + 0.0003 * storm
	_env.fog_light_color = _env.fog_light_color.lerp(Color(0.45, 0.48, 0.52) * _env.ambient_light_energy * 1.6, storm * 0.7)
	if _sky_mat:
		_sky_mat.set_shader_parameter("storm", storm)

	# --- eclairs et tonnerre ---
	if _thunder and rain > 0.5:
		_next_flash -= delta
		if _next_flash <= 0.0:
			_next_flash = _rng.randf_range(6.0, 20.0)
			_flash = 0.35
			# l'eclair tombe a 1-6 km : le son arrive 3 a 18 s plus tard
			_pending_thunder = _rng.randf_range(2.0, 9.0)
	if _flash > 0.0:
		_flash -= delta
		var f: float = 1.0 if fmod(_flash * 20.0, 1.0) > 0.4 else 0.3
		_env.background_energy_multiplier += 6.0 * f
		_env.ambient_light_energy += 2.5 * f
	if _pending_thunder > 0.0:
		_pending_thunder -= delta
		if _pending_thunder <= 0.0:
			_thunder_snd.stream = AudioSynth.tonnerre()
			_thunder_snd.pitch_scale = _rng.randf_range(0.8, 1.1)
			_thunder_snd.play()
