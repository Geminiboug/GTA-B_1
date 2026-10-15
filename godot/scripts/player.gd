extends CharacterBody3D
## Joueur a pied, vue 3e personne.
## Clavier : ZQSD bouger (trot), Shift sprint (tapoter pour aller plus vite, maintenir = sprint moyen), Alt ou Ctrl
## marcher, Espace sauter, E monter/descendre, V changer de vue.
## Manette : stick gauche bouger (l'inclinaison regle l'allure), stick droit camera, A (Croix) sprint (tapoter), X (Carre)
## sauter, L3 marcher, Y (Triangle) monter/descendre, croix bas changer de vue.
## Endurance cachee : a vide, plus de sprint (essoufflement) le temps de recuperer.
## Souris : tourner la camera. Molette : zoom. Echap : liberer / reprendre la souris.
## Vitesses reelles : marche ~1,6 m/s, trot ~4,2 m/s, sprint ~7 m/s.

@export var walk_speed := 1.6
@export var jog_speed := 4.2
@export var sprint_speed := 7.0
@export var jump_velocity := 4.4
@export var ground_accel := 9.0      # m/s2 au demarrage
@export var ground_decel := 14.0     # m/s2 au freinage
@export var air_accel := 1.5         # tres peu de controle en l'air
@export var turn_speed_slow := 12.0  # rad/s, demi-tour quasi immediat a l'arret
@export var turn_speed_fast := 4.5   # virages plus larges en sprint
@export var mouse_sensitivity := 0.0025
@export var zoom_min := 2.0
@export var zoom_max := 12.0
@export_group("Sprint et endurance (facon GTA V)")
@export var sprint_hold_level := 0.55     # maintenir le bouton : sprint moyen (0 = trot, 1 = sprint maximal)
@export var sprint_tap_boost := 0.22      # chaque tapotement rapproche du sprint maximal
@export var sprint_decay := 0.45          # par seconde, sans tapoter
@export var stamina_drain := 0.085        # par seconde au sprint maximal (~12 s)
@export var stamina_regen := 0.16         # par seconde hors sprint
@export var stamina_min_sprint := 0.12    # en dessous : plus de sprint
@export_group("Camera (facon GTA V)")
@export var camera_effects := true        # recentrage, FOV dynamique, secousses (desactivables dans les options)
@export var recenter_delay := 1.5         # s sans toucher la camera avant de la ramener derriere le joueur
@export var recenter_speed := 1.4         # rad/s
@export var fov_base := 70.0
@export var fov_sprint := 80.0
@export var view_distances: Array[float] = [2.6, 4.2, 6.5]   # vue proche, moyenne, lointaine (touche V)
@export var shake_land := 0.12             # intensite de la secousse a l'atterrissage brutal

@onready var cam_pivot: Node3D = $CamPivot
@onready var spring_arm: SpringArm3D = $CamPivot/SpringArm3D
@onready var body: Node3D = $Body
@onready var anim: Node = get_node_or_null("Body/Model")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _cam_offset := Vector3(0, 1.6, 0)
var _facing := 0.0        # direction du corps (yaw)
var _prev_facing := 0.0
var _prev_hspeed := 0.0
var _fall_speed := 0.0
var _last_safe := Vector3.ZERO
var sprint_level := 0.0     # 0..1 (tapotements)
var stamina := 1.0          # 0..1, cachee
var _cam_idle := 0.0
var _view := 1
var _shake := 0.0


func _ready() -> void:
	# la camera ne doit pas buter contre le joueur lui-meme
	spring_arm.add_excluded_object(get_rid())
	# camera independante, recalee chaque image sur la position lissee du joueur (pas de saccades)
	cam_pivot.top_level = true
	cam_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam_pivot.global_position = global_position + _cam_offset
	_facing = body.rotation.y
	_last_safe = global_position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_dress(anim, genre)
	# on heurte aussi les passants (couche 5), pas seulement le decor
	collision_mask = 1 | (1 << 4)


var _punch_cd := 0.0


# ---------- Apparence : homme ou femme (F4 a pied pour changer) ----------
const ANIM_SCRIPT := preload("res://scripts/character_anim.gd")
var genre := "homme"


func _player_look(g: String) -> Dictionary:
	if g == "femme":
		var w := PnjUtil.wax(PnjUtil.WAX_PALETTES[3], 0)
		return {"skin": PnjUtil.SKINS[0], "top": PnjUtil.plain(Color(0.95, 0.94, 0.9)), "legs": PnjUtil.plain(PnjUtil.SKINS[0]),
			"cloth": w, "show": ["chr_haut", "chr_pagne_long", "chr_semelle", "chr_foulard"]}
	return {"skin": PnjUtil.SKINS[0], "top": PnjUtil.plain(Color(0.1, 0.5, 0.55)), "legs": PnjUtil.plain(Color(0.2, 0.3, 0.48)),
		"cloth": PnjUtil.plain(Color(0.2, 0.3, 0.48)), "show": ["chr_haut", "chr_pantalon", "chr_chaussures", "chr_cheveux"]}


func _dress(model: Node, g: String) -> void:
	if model == null:
		return
	model.set_meta("genre", g)
	model.set_meta("age", "adulte")
	set_meta("genre", g)
	PnjUtil.apply(model, _player_look(g))


func set_genre(g: String) -> void:
	## Change le personnage (le modele est reconstruit : les pieces ont ete regroupees pour l'affichage).
	genre = g
	var old := body.get_node_or_null("Model")
	if old:
		body.remove_child(old)
		old.queue_free()
	var m := PnjUtil.make(g)
	m.set_script(ANIM_SCRIPT)
	m.name = "Model"
	body.add_child(m)
	anim = m
	_dress(m, g)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		cam_pivot.rotation.x = clamp(cam_pivot.rotation.x - event.relative.y * mouse_sensitivity, -1.2, 0.5)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = max(zoom_min, spring_arm.spring_length - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = min(zoom_max, spring_arm.spring_length + 0.5)
		elif Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4 and vehicle == null:
		set_genre("femme" if genre == "homme" else "homme")
	elif event.is_action_pressed("camera_vue") and vehicle == null:
		_view = (_view + 1) % view_distances.size()
		spring_arm.spring_length = view_distances[_view]
	if event is InputEventMouseMotion and event.relative.length() > 0.5:
		_cam_idle = 0.0


@export var stick_look_speed := 2.6  # rad/s au stick droit


func _process(delta: float) -> void:
	cam_pivot.global_position = get_global_transform_interpolated().origin + _cam_offset
	# stick droit de la manette (quand on est a pied)
	if vehicle == null:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		cam_pivot.rotation.y -= look.x * stick_look_speed * delta
		cam_pivot.rotation.x = clamp(cam_pivot.rotation.x - look.y * stick_look_speed * 0.7 * delta, -1.2, 0.5)
		if look.length() > 0.1:
			_cam_idle = 0.0
		_camera_gta(delta)


func _camera_gta(delta: float) -> void:
	## Camera facon GTA V : recentrage derriere le joueur quand on avance sans toucher la camera, FOV et recul
	## en sprint, secousse a l'atterrissage.
	_cam_idle += delta
	var cam := spring_arm.get_node_or_null("Camera3D") as Camera3D
	var hv := Vector2(velocity.x, velocity.z).length()
	if not camera_effects:
		if cam:
			cam.fov = fov_base
		return
	if _cam_idle > recenter_delay and hv > 1.0:
		var k := clampf(hv / sprint_speed, 0.3, 1.0)
		cam_pivot.rotation.y = rotate_toward(cam_pivot.rotation.y, _facing, recenter_speed * k * delta)
		cam_pivot.rotation.x = move_toward(cam_pivot.rotation.x, -0.2, 0.5 * delta)
	var sprinting := clampf((hv - jog_speed) / maxf(sprint_speed - jog_speed, 0.1), 0.0, 1.0)
	if cam:
		cam.fov = lerpf(cam.fov, lerpf(fov_base, fov_sprint, sprinting), 1.0 - exp(-4.0 * delta))
		_shake = maxf(0.0, _shake - delta * 0.6)
		var t := Time.get_ticks_msec() * 0.001
		cam.h_offset = sin(t * 37.0) * _shake * 0.3
		cam.v_offset = sin(t * 43.0 + 1.3) * _shake * 0.3


func shake(amount: float) -> void:
	## Secousse de camera (atterrissage, avion a basse altitude, choc).
	if camera_effects:
		_shake = maxf(_shake, amount)


# ---------- Vehicules : E pour monter / descendre ----------
var vehicle: Node3D = null
const ENTER_DISTANCE := 2.5
const HIP_HEIGHT := 0.92  # hauteur du bassin au-dessus des pieds


func _nearest_vehicle() -> Node3D:
	## Comme dans GTA, E prend le vehicule le plus proche de soi :
	## - un vehicule libre (le zem de depart, une voiture deja prise puis laissee) ;
	## - un vehicule de la circulation arrete ou au pas : son conducteur est ejecte (scripts/traffic.gd) ;
	## - une voiture ou un zem gare au bord de la route (scripts/props.gd).
	var best: Node3D = null
	var best_d := ENTER_DISTANCE
	for v in get_tree().get_nodes_in_group("vehicules"):
		if v.get("has_rider"):
			continue
		var ep: Vector3 = v.entry_point() if v.has_method("entry_point") else v.global_position
		var d: float = global_position.distance_to(ep)
		if d < best_d:
			best_d = d
			best = v
	var scene := get_parent()  # la scene de la zone (current_scene est nul quand on lance un test)
	var traffic := scene.get_node_or_null("Circulation") if scene else null
	var props := scene.get_node_or_null("Props") if scene else null
	var t: Dictionary = traffic.nearest_agent(global_position, ENTER_DISTANCE + 0.6) if traffic else {}
	var pk: Dictionary = props.nearest_parked(global_position, ENTER_DISTANCE + 0.4) if props else {}
	var td: float = t.get("dist", INF)
	var pd: float = pk.get("dist", INF)
	if td < best_d and td <= pd:
		return traffic.take_over(t["index"], self)
	if pd < best_d:
		return props.take_parked(pk["index"])
	return best


func enter_vehicle(v: Node3D) -> void:
	vehicle = v
	$Collision.disabled = true
	velocity = Vector3.ZERO
	v.set_rider(true)
	v.get_node("CamRig").activate(true)
	if anim:
		anim.seated = true
	# le joueur suit la selle : pas d'interpolation propre pour eviter un decalage d'une image
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func exit_vehicle() -> void:
	var v := vehicle
	vehicle = null
	v.set_rider(false)
	v.get_node("CamRig").activate(false)
	$CamPivot/SpringArm3D/Camera3D.current = true
	# on descend cote gauche (portiere conducteur / gauche de la moto), debout, dans le meme sens
	var xf: Transform3D = v.exit_transform()
	global_transform = Transform3D(Basis.IDENTITY, xf.origin)
	_facing = v.rotation.y
	body.rotation = Vector3(0, _facing, 0)
	cam_pivot.rotation.y = v.get_node("CamRig").rotation.y
	$Collision.disabled = false
	if anim:
		anim.seated = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	reset_physics_interpolation()


func _ride(_delta: float) -> void:
	var seat: Transform3D = vehicle.seat_transform()
	var hip := HIP_HEIGHT - (0.04 if genre == "femme" else 0.0)
	global_transform = Transform3D(seat.basis, seat.origin - seat.basis.y * hip)
	body.rotation = Vector3.ZERO
	if anim:
		anim.speed = 0.0
		anim.on_floor = true
		anim.turn_rate = 0.0
		anim.accel = 0.0


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		if vehicle:
			exit_vehicle()
			return
		var v := _nearest_vehicle()
		if v:
			enter_vehicle(v)
	if vehicle:
		_ride(delta)
		return
	# coup de poing / bousculade (F, clic gauche, manette B) : les passants reagissent (scripts/pedestrians.gd)
	_punch_cd = maxf(0.0, _punch_cd - delta)
	if Input.is_action_just_pressed("attaque") and is_on_floor() and _punch_cd <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_punch_cd = 0.6
		if anim and anim.has_method("punch"):
			anim.punch()
		var peds := get_parent().get_node_or_null("Pietons")
		if peds:
			var fwd := Vector3(-sin(_facing), 0.0, -cos(_facing))
			get_tree().create_timer(0.18).timeout.connect(func() -> void: peds.player_attack(global_position, fwd))
	# filet de securite : si on passe sous la carte, retour au dernier endroit sur
	if global_position.y < -20.0:
		global_position = _last_safe + Vector3.UP * 1.0
		velocity = Vector3.ZERO
		reset_physics_interpolation()
	elif is_on_floor() and global_position.y > -0.5:
		_last_safe = global_position
	var was_on_floor := is_on_floor()
	if not is_on_floor():
		velocity.y -= gravity * delta
		_fall_speed = max(_fall_speed, -velocity.y)
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (Basis(Vector3.UP, cam_pivot.rotation.y) * Vector3(input.x, 0, input.y))
	# sprint facon GTA V : tapoter rapproche du sprint maximal, maintenir donne un sprint moyen ; endurance cachee
	if Input.is_action_just_pressed("sprint"):
		sprint_level = minf(1.0, maxf(sprint_level, sprint_hold_level) + sprint_tap_boost)
	elif Input.is_action_pressed("sprint"):
		sprint_level = move_toward(sprint_level, sprint_hold_level, sprint_decay * delta)
	else:
		sprint_level = move_toward(sprint_level, 0.0, sprint_decay * 2.0 * delta)
	var hv_now := Vector2(velocity.x, velocity.z).length()
	if sprint_level > 0.0 and hv_now > jog_speed * 0.9:
		stamina = maxf(0.0, stamina - stamina_drain * sprint_level * delta)
	else:
		stamina = minf(1.0, stamina + stamina_regen * delta)
	var can_sprint := stamina > stamina_min_sprint
	var target_speed := jog_speed
	if sprint_level > 0.0 and can_sprint:
		target_speed = lerpf(jog_speed, sprint_speed, clampf(sprint_level / maxf(sprint_hold_level, 0.01) * 0.6, 0.0, 1.0) if sprint_level <= sprint_hold_level else lerpf(0.6, 1.0, (sprint_level - sprint_hold_level) / maxf(1.0 - sprint_hold_level, 0.01)))
	elif Input.is_action_pressed("walk"):
		target_speed = walk_speed
	# stick : l'inclinaison regle l'allure (marche lente -> marche -> trot)
	var tilt := minf(dir.length(), 1.0)
	if tilt < 0.98 and sprint_level <= 0.0:
		target_speed = lerpf(walk_speed * 0.6, target_speed, smoothstep(0.15, 0.95, tilt))
	target_speed *= minf(tilt * 4.0, 1.0)

	var hvel := Vector2(velocity.x, velocity.z)
	var hspeed := hvel.length()

	if is_on_floor():
		if dir.length() > 0.01:
			# le corps tourne vers la direction voulue, moins vite quand on va vite
			var want := atan2(-dir.x, -dir.z)
			var turn: float = lerp(turn_speed_slow, turn_speed_fast, clamp(hspeed / sprint_speed, 0.0, 1.0))
			_facing = rotate_toward(_facing, want, turn * delta)
			# on avance dans la direction du corps : virages en courbe, pas en glissade
			var fwd := Vector2(-sin(_facing), -cos(_facing))
			var align: float = clamp(cos(angle_difference(_facing, want)), 0.0, 1.0)
			var goal := target_speed * (0.35 + 0.65 * align)
			hspeed = move_toward(hspeed, goal, (ground_accel if goal > hspeed else ground_decel) * delta)
			hvel = fwd * hspeed
		else:
			hvel = hvel.move_toward(Vector2.ZERO, ground_decel * delta)
	else:
		var air_goal := Vector2(dir.x, dir.z) * target_speed
		hvel = hvel.move_toward(air_goal, air_accel * delta) if dir.length() > 0.01 else hvel

	velocity.x = hvel.x
	velocity.z = hvel.y
	body.rotation.y = _facing
	move_and_slide()

	if anim:
		var new_hspeed := Vector2(velocity.x, velocity.z).length()
		anim.speed = new_hspeed
		anim.on_floor = is_on_floor()
		anim.vertical_speed = velocity.y
		anim.turn_rate = angle_difference(_prev_facing, _facing) / delta
		anim.accel = (new_hspeed - _prev_hspeed) / delta
		anim.essouffle = clampf((0.6 - stamina) / 0.5, 0.0, 1.0)
		if is_on_floor() and not was_on_floor:
			anim.land(_fall_speed)
			if _fall_speed > 5.0:
				shake(shake_land * clampf(_fall_speed / 9.0, 0.3, 1.0))
		_prev_hspeed = new_hspeed
	if is_on_floor():
		_fall_speed = 0.0
	_prev_facing = _facing
