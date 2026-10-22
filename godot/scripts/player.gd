extends CharacterBody3D
## Joueur a pied, vue 3e personne.
## Clavier : ZQSD bouger (trot), Shift sprint (tapoter pour aller plus vite, maintenir = sprint moyen), Alt ou Ctrl
## marcher, C s'accroupir, Espace sauter (ou escalader un rebord de 0,5 a 1,6 m), E monter/descendre, V changer de vue.
## Manette : stick gauche bouger (l'inclinaison regle l'allure), stick droit camera, A (Croix) sprint (tapoter), X (Carre)
## sauter, L3 marcher, R3 s'accroupir, Y (Triangle) monter/descendre, croix bas changer de vue.
## Endurance cachee : a vide, plus de sprint (essoufflement) le temps de recuperer.
## Souris : tourner la camera. Molette : zoom. Echap : liberer / reprendre la souris.
## Vitesses reelles : marche ~1,6 m/s, trot ~4,2 m/s, sprint ~7 m/s.

@export var walk_speed := 1.6
@export var jog_speed := 4.2
@export var sprint_speed := 7.0
@export var jump_velocity := 3.1      # m/s : saut d'environ 0,5 m, 0,63 s en l'air (g = 9,81)
@export var land_brake := 0.45       # part de la vitesse horizontale gardee a la reception (flexion des jambes)
@export var land_stun := 0.25        # s de reception sans relance
@export var land_heavy := 6.0        # m/s de chute (~1,8 m) : en dessous, reception sans freinage
@export var step_height := 0.3       # m : marche, bordure ou seuil franchis sans sauter
@export var fall_hurt_speed := 8.0   # m/s a l'impact (chute de ~3,3 m) : au-dela, la chute blesse
@export var fall_hurt_per_ms := 12.0 # points de sante par m/s au-dela
@export var ground_accel := 9.0      # m/s2 au demarrage
@export var ground_decel := 18.0     # m/s2 au freinage (arret en 0,4 s depuis le trot)
@export var air_accel := 1.5         # tres peu de controle en l'air
@export var turn_speed_slow := 12.0  # rad/s, demi-tour quasi immediat a l'arret
@export var turn_speed_fast := 4.5   # virages plus larges en sprint
@export var mouse_sensitivity := 0.0025
@export var zoom_min := 2.0
@export var zoom_max := 12.0
@export_group("Accroupi et escalade (facon GTA V)")
@export var crouch_speed := 1.1      # m/s accroupi (C, manette R3 : bascule)
@export var crouch_height := 1.2     # m : hauteur de la capsule accroupi (debout 1,75)
@export var climb_min := 0.5         # m : en dessous, on saute ou on monte la marche
@export var climb_max := 2.8         # m : rebord le plus haut qu'on agrippe (au-dela de sa taille, on se hisse a la force des bras)
@export var climb_reach := 0.7       # m : distance maximale du mur devant soi
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

var _land_t := 0.0
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
var crouched := false
var _stand_height := 1.75
var _climb := {}            # escalade en cours : depart, hauteur, avance, temps
const CLIMB_CLIP := "ClimbUp_1m"


func _ready() -> void:
	# la camera ne doit pas buter contre le joueur lui-meme
	spring_arm.add_excluded_object(get_rid())
	# camera independante, recalee chaque image sur la position lissee du joueur (pas de saccades)
	cam_pivot.top_level = true
	cam_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cam_pivot.global_position = global_position + _cam_offset
	_facing = body.rotation.y
	_last_safe = global_position
	$Collision.shape = $Collision.shape.duplicate()    # la capsule change de hauteur accroupi
	_stand_height = ($Collision.shape as CapsuleShape3D).height
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	set_genre(genre)        # modele construit par PnjUtil.make (squelette standard tourne vers -Z)
	# on heurte aussi les passants (couche 5), pas seulement le decor
	collision_mask = 1 | (1 << 4)
	# garde (phase 14) : clic droit, manette LB
	if not InputMap.has_action("garde"):
		InputMap.add_action("garde")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("garde", mb)
		var jb := InputEventJoypadButton.new()
		jb.button_index = JOY_BUTTON_LEFT_SHOULDER
		InputMap.action_add_event("garde", jb)


var _punch_cd := 0.0
var menus := {}               # menus ouverts (achat, inventaire...) : le joueur ne bouge plus, les fleches servent au menu


func _move_input() -> Vector2:
	return Vector2.ZERO if not menus.is_empty() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")


# ---------- Corps a corps (phase 14) : enchainement direct / croise / crochet, garde, roulade ----------
const COUPS := ["Punch_Jab", "Punch_Cross", "Punch_Cross"]   # 3e coup : croise appuye qui fait tomber (Melee_Hook part au sol)
@export var combo_fenetre := 0.9        # s pour enchainer le coup suivant
@export var roulade_vitesse := 5.2      # m/s pendant la roulade (esquive)
@export var roulade_duree := 0.6
@export var garde_reduction := 0.85     # part des degats paree en garde, face a l'adversaire
var combo := 0
var garde := false
# armes (scripts/armes.gd) : arme en main, arme a feu (le clic droit vise au lieu de parer), visee en cours
var arme := ""
var force := 1.0                       # muscles (scripts/stats.gd) : multiplie les degats des coups de poing
var corps := ""                        # silhouette : "mince", "" (normale) ou "fort" (scripts/stats.gd)
var arme_feu := false
var visee := false
@export var visee_fov := 52.0
@export var visee_distance := 1.9        # m : camera rapprochee, par-dessus l'epaule droite
@export var visee_epaule := 0.55
var _combo_t := 0.0
var _roll_t := 0.0
## Animations de vie (clips Mixamo et Quaternius) : arret apres une course, gestes d'attente quand on reste immobile.
@export var attente_geste := Vector2(9.0, 20.0)   # s immobile avant un geste d'attente (tire au hasard)
const GESTES_ATTENTE := [[["MX_Idle_Regarde", 0.0]], [["Idle_FoldArms", 2.5]], [["MX_Idle_Content", 0.0]],
	[["MX_Idle_Appui", 0.0]], [["Yes", 0.0]]]
## Virages sur place : a l'arret, une direction demandee a plus de virage_seuil degres joue un pas tourne capte
## (MX_Tourne_G90 / D90, MX_DemiTour_Marche) ; le corps tourne en suivant la rotation du bassin du clip.
@export var virage_seuil := 60.0       # degres
@export var virage_vitesse := 1.6      # vitesse de lecture des clips de virage (les captures sont lentes pour un jeu)
@export var virage_sortie := 0.8       # part de la rotation du clip apres laquelle on peut repartir
var _virage := {}
var _immobile_t := 0.0
var _prochain_geste := 12.0
var _vitesse_prec := 0.0
var _roll_dir := Vector2.ZERO


func _combat_ok() -> bool:
	## Souris capturee (pas un clic dans un menu) ; toujours vrai sans fenetre (tests).
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless" or DisplayServer.is_touchscreen_available()


func hurt(dmg: float, from: Vector3) -> void:
	## Coup recu d'un passant (scripts/pedestrians.gd) : pare en garde s'il vient de face, esquive en roulade.
	if _roll_t > 0.0 or vehicle != null:
		return
	var to := from - global_position
	to.y = 0.0
	var fwd := Vector3(-sin(_facing), 0.0, -cos(_facing))
	if garde and to.length() > 0.01 and to.normalized().dot(fwd) > 0.3:
		Partie.blesser(dmg * (1.0 - garde_reduction))
		shake(0.15)
		if anim and anim.has_method("play_clips"):
			anim.play_clips([["Shield_OneShot", 0.0]], true)
		return
	Partie.blesser(dmg)
	shake(0.5)
	if to.length() > 0.01:
		velocity += -to.normalized() * 1.5
	if anim and anim.has_method("play_clips"):
		anim.play_clips([["Hit_Head" if randf() < 0.5 else "Hit_Chest", 0.0]], true)


# ---------- Apparence : homme ou femme (F4 a pied pour changer) ----------
const ANIM_SCRIPT := preload("res://scripts/anim_ctrl.gd")   # clips captes (Quaternius), comme les PNJ
var genre := "homme"


func _player_look(g: String) -> Dictionary:
	if g == "femme":
		var w := PnjUtil.wax(PnjUtil.WAX_PALETTES[3], 0)
		return {"skin": PnjUtil.SKINS[0], "top": PnjUtil.plain(Color(0.95, 0.94, 0.9)), "legs": PnjUtil.plain(PnjUtil.SKINS[0]),
			"cloth": w, "show": ["chr_haut", "chr_pagne_long", "chr_semelle", "chr_foulard"]}
	# tenue de depart (planche d'Olympe, 22/10/2026) : t-shirt blanc a logo GTB, pantalon en wax jaune ocre, bleu nuit et rouge,
	# baskets blanches
	var wax_gtb := PnjUtil.wax([Color(0.08, 0.11, 0.3), Color(0.92, 0.62, 0.05), Color(0.6, 0.08, 0.12)], 4)
	return {"skin": PnjUtil.SKINS[0], "top": PnjUtil.plain(Color(0.96, 0.96, 0.95)), "legs": wax_gtb,
		"cloth": wax_gtb, "shoes_mat": PnjUtil.plain(Color(0.94, 0.94, 0.92)), "show": ["chr_haut", "chr_pantalon", "chr_chaussures", "chr_cheveux"]}


func _dress(model: Node, g: String) -> void:
	if model == null:
		return
	model.set_meta("genre", g)
	model.set_meta("age", "adulte")
	set_meta("genre", g)
	var perso := get_parent().get_node_or_null("Personnalisation") if get_parent() else null
	var depart: bool = not (perso and not Partie.tenue.is_empty())
	PnjUtil.apply(model, _player_look(g) if depart else perso.look(g))
	_logo_poitrine(model, depart and g == "homme")


var _logo_att: BoneAttachment3D
var _logo_lbl: Label3D


func _logo_poitrine(model: Node, voulu: bool) -> void:
	## Logo GTB noir sur la poitrine du t-shirt de depart : l'os de la poitrine donne la position, le texte est tenu face
	## au personnage (les axes des os importes ne sont pas ceux du corps).
	if _logo_lbl and is_instance_valid(_logo_lbl):
		_logo_lbl.queue_free()
	if _logo_att and is_instance_valid(_logo_att):
		_logo_att.queue_free()
	_logo_lbl = null
	_logo_att = null
	var sk := Squelette.find(model) as Skeleton3D
	if not voulu or sk == null:
		return
	var os := "UpperChest" if sk.find_bone("UpperChest") >= 0 else "Chest"
	if sk.find_bone(os) < 0:
		return
	_logo_att = BoneAttachment3D.new()
	_logo_att.name = "LogoPoitrine"
	_logo_att.bone_name = os
	sk.add_child(_logo_att)
	_logo_lbl = Label3D.new()
	_logo_lbl.text = "GTB"
	_logo_lbl.font_size = 96
	_logo_lbl.pixel_size = 0.0015
	_logo_lbl.outline_size = 0
	_logo_lbl.modulate = Color(0.04, 0.04, 0.05)
	_logo_lbl.shaded = false
	_logo_lbl.double_sided = false
	_logo_lbl.top_level = true
	_logo_att.add_child(_logo_lbl)


func _maj_logo_poitrine() -> void:
	if _logo_lbl == null or not is_instance_valid(_logo_lbl) or not is_instance_valid(_logo_att):
		return
	var b := body.global_transform.basis.orthonormalized()
	var devant := -b.z
	_logo_lbl.visible = vehicle == null or vehicle.get("kind") == "zem"
	_logo_lbl.global_transform = Transform3D(b.rotated(Vector3.UP, PI), _logo_att.global_position + devant * 0.15 + Vector3.UP * -0.17)


signal modele_change


func set_corps(c: String) -> void:
	## Silhouette qui suit les statistiques (phase 15) : mince, normale ou forte (morphologies existantes).
	if c == corps:
		return
	corps = c
	set_genre(genre)


func set_genre(g: String) -> void:
	## Change le personnage (le modele est reconstruit : les pieces ont ete regroupees pour l'affichage).
	genre = g
	var old := body.get_node_or_null("Model")
	if old:
		body.remove_child(old)
		old.queue_free()
	var variante := g
	if corps == "mince":
		variante = g + "_mince"
	elif corps == "fort":
		variante = "homme_fort" if g == "homme" else "femme_ronde"
	var m := PnjUtil.make(variante, false)     # pas de capsule de PNJ : le joueur a la sienne
	m.set_script(ANIM_SCRIPT)
	m.set("anim_lod", false)
	m.name = "Model"
	body.add_child(m)
	anim = m
	_dress(m, g)
	modele_change.emit()


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


var _visee_k := 0.0
var _exit_from := Transform3D()
var _exit_t := 1.0
@export var exit_time := 0.35       # s : du siege au sol en descendant


func _process(delta: float) -> void:
	cam_pivot.global_position = get_global_transform_interpolated().origin + _cam_offset
	if _exit_t < 1.0:
		_exit_t = minf(1.0, _exit_t + delta / exit_time)
		var k := smoothstep(0.0, 1.0, _exit_t)
		var to := global_transform * Transform3D(Basis(Vector3.UP, _facing), Vector3.ZERO)
		body.global_transform = _exit_from.interpolate_with(to, k).translated(Vector3.UP * sin(k * PI) * 0.1)
		if _exit_t >= 1.0:
			body.transform = Transform3D(Basis(Vector3.UP, _facing), Vector3.ZERO)
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
	if visee or _visee_k > 0.0:
		# visee : camera par-dessus l'epaule, champ resserre (retour en douceur quand on relache)
		_visee_k = move_toward(_visee_k, 1.0 if visee else 0.0, delta * 5.0)
		if cam:
			cam.fov = lerpf(fov_base, visee_fov, _visee_k)
			cam.h_offset = visee_epaule * _visee_k
		spring_arm.spring_length = lerpf(view_distances[_view], visee_distance, _visee_k)
		_cam_idle = 0.0
		if visee:
			return
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


@export var look_plane_range := 600.0   # m : un avion plus proche (et assez bas) attire le regard
var _air_node: Node = null


func _update_look() -> void:
	## Regard facon GTA V : la tete suit la direction de la camera (dans la limite d'un mouvement de tete),
	## et se tourne vers un avion qui passe a basse altitude.
	var yaw := 0.0
	var pitch := 0.0
	var rel := angle_difference(_facing, cam_pivot.rotation.y)
	if absf(rel) < 1.7:
		yaw = rel
		pitch = clampf(-cam_pivot.rotation.x - 0.2, -0.3, 0.4)
	if _air_node == null:
		_air_node = get_parent().get_node_or_null("TraficAerien")
	if _air_node:
		var mv: Dictionary = _air_node.get("mv")
		var pl: Node3D = mv.get("plane") if mv else null
		if pl and is_instance_valid(pl):
			var d := pl.global_position - global_position
			var flat := Vector2(d.x, d.z).length()
			if flat < look_plane_range and d.y < 250.0 and d.y > 3.0:
				var ang := atan2(-d.x, -d.z)
				var r2 := angle_difference(_facing, ang)
				if absf(r2) < 1.9:
					yaw = r2
					pitch = atan2(d.y, flat)
	anim.look_yaw = yaw
	anim.look_pitch = pitch


func shake(amount: float) -> void:
	## Secousse de camera (atterrissage, avion a basse altitude, choc).
	if camera_effects:
		_shake = maxf(_shake, amount)


# ---------- Vehicules : E pour monter / descendre ----------
var vehicle: Node3D = null
const ENTER_DISTANCE := 2.5
const HIP_HEIGHT := 0.92  # hauteur du bassin au-dessus des pieds
# pose de conduite (clip Driving) : le bassin est 0,39 m plus bas et 0,30 m plus en arriere que debout (tests/mesure_assis.gd)
@export var seat_hip_drop := 0.39
@export var seat_hip_back := 0.30
@export var car_seat_raise := 0.0    # voiture : rehaussement de l assise (les pieds vont aux pedales par IK)


func _nearest_vehicle() -> Node3D:
	## Comme dans GTA, E prend le vehicule le plus proche de soi :
	## - un vehicule libre (le zem de depart, une voiture deja prise puis laissee) ;
	## - un vehicule de la circulation arrete ou au pas : son conducteur est ejecte (scripts/traffic.gd) ;
	## - une voiture ou un zem gare au bord de la route (scripts/props.gd).
	var best: Node3D = null
	var best_d := ENTER_DISTANCE
	for v in get_tree().get_nodes_in_group("vehicules"):
		if v.get("has_rider") or v.get("epave"):
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
		_carjack = true
		return traffic.take_over(t["index"], self)
	if pd < best_d:
		return props.take_parked(pk["index"])
	return best


var _enter_from := Transform3D()
var _carjack := false                 # le vehicule vient d'etre pris a son conducteur (geste pour l'en sortir)
var _pre := {}                        # geste avant de monter : {v, t, len} (portiere ouverte, conducteur tire dehors)
@export var geste_portiere := 0.55    # s : ouvrir la portiere (clip Interact) avant de s'asseoir
@export var geste_vol := 0.9          # s : tirer le conducteur dehors (clip Push)
var _enter_t := 1.0
@export var enter_time := 0.5      # s : du sol au siege (le corps glisse pendant que l'animation passe assise)


func _start_pre(v: Node3D) -> void:
	## Geste visible avant de monter : tirer le conducteur dehors (vol) ou ouvrir la portiere (voiture) ; le zem
	## s'enjambe directement (arc du corps dans _ride).
	var car: bool = v.get("kind") != "zem"
	if not _carjack and not car:
		enter_vehicle(v)
		return
	var ep: Vector3 = v.entry_point() if v.has_method("entry_point") else v.global_position
	var to := (v.global_position - ep) * Vector3(1, 0, 1)
	if to.length() > 0.05:
		_facing = atan2(-to.x, -to.z)
		body.rotation.y = _facing
	velocity = Vector3.ZERO
	var clip_name := "Push" if _carjack else "Interact"
	var dur := geste_vol if _carjack else geste_portiere
	if car and v.has_method("ouvrir_porte"):
		v.call("ouvrir_porte", "porte_g0", true, dur * 0.8)      # la portiere s'ouvre pendant le geste
	if anim and anim.has_method("play_clips"):
		anim.play_clips([[clip_name, 0.0]], true)
	_pre = {"v": v, "t": 0.0, "len": dur}


func _pre_step(delta: float) -> void:
	_pre["t"] = float(_pre["t"]) + delta
	velocity = Vector3(0, velocity.y - gravity * delta, 0) if not is_on_floor() else Vector3.ZERO
	move_and_slide()
	if float(_pre["t"]) >= float(_pre["len"]):
		var v: Node3D = _pre["v"]
		_pre = {}
		if is_instance_valid(v) and not v.get("has_rider"):
			enter_vehicle(v)


func knocked_out_of_vehicle(from: Vector3) -> void:
	## Le proprietaire reprend son vehicule (scripts/pedestrians.gd) : le joueur est tire dehors et projete.
	if vehicle:
		exit_vehicle(true)
	var away: Vector3 = (global_position - from) * Vector3(1, 0, 1)
	velocity = away.normalized() * 5.0 + Vector3.UP * 2.0
	if anim and anim.has_method("play_clips"):
		anim.play_clips([["Hit_Knockback", 0.0]])


func _skirt_visible(vis: bool) -> void:
	var m := get_node_or_null("Body/Model")
	if m == null:
		return
	for n in ["chr_pagne_long", "chr_jupe", "chr_boubou"]:
		var mi := m.find_child(n, true, false) as MeshInstance3D
		if mi and (vis or mi.visible):
			if not vis:
				mi.set_meta("_car_hide", true)
				mi.visible = false
			elif mi.has_meta("_car_hide"):
				mi.remove_meta("_car_hide")
				mi.visible = true


var pillion := false                # passager derriere le conducteur d'un zem-taxi (scripts/zem_taxi.gd) : ne conduit pas
var pillion_libre := false          # le zem-taxi est arrete : on peut descendre


func enter_vehicle(v: Node3D, en_passager := false) -> void:
	pillion = en_passager
	pillion_libre = false
	if crouched:
		crouched = false
		($Collision.shape as CapsuleShape3D).height = _stand_height
		$Collision.position.y = _stand_height * 0.5
	vehicle = v
	if v.get("kind") != "zem":
		_skirt_visible(false)
	_enter_from = global_transform
	_enter_t = 0.0
	$Collision.disabled = true
	velocity = Vector3.ZERO
	if not en_passager:
		v.set_rider(true)
	if v.has_method("a_portes") and v.a_portes():
		v.call("ouvrir_porte", "porte_g0", true, 0.2)
		get_tree().create_timer(enter_time * 1.1).timeout.connect(func() -> void:
			if is_instance_valid(v):
				v.call("ouvrir_porte", "porte_g0", false, 0.3))      # on referme la portiere une fois assis
	elif v.has_method("portiere"):
		v.portiere(true)
	v.get_node("CamRig").activate(true)
	if anim:
		anim.seated = true
	# le joueur suit la selle : mis a jour apres le vehicule a chaque tic physique (priorite), et interpole comme
	# lui entre deux tics ; sans interpolation, le corps sautait d'un cran par rapport a la moto (gigotement)
	process_physics_priority = 10
	reset_physics_interpolation()


func _sortie_libre(v: Node3D) -> Variant:
	## Endroit ou descendre : le cote prevu, sinon l'autre cote, l'avant ou l'arriere. Il faut la place de se tenir debout et
	## aucun mur entre le vehicule et ce point (sinon le personnage se retrouvait de l'autre cote du mur). null : aucune place.
	var prevu: Vector3 = v.exit_transform().origin
	var c := v.global_position
	var off := prevu - c
	off.y = 0.0
	var b := v.global_transform.basis
	var droite := b.x * (off.dot(b.x))
	var essais: Array[Vector3] = [prevu, c + off - droite * 2.0, c + off - droite + b.z * 2.2, c + off - droite - b.z * 2.2,
		c + off + b.z * 2.6, c + off - b.z * 2.6]
	for p in essais:
		var q := Vector3(p.x, prevu.y, p.z)
		var depart := c + (q - c) * 0.55 + Vector3.UP * 0.9
		if _ray(depart, q + Vector3.UP * 0.9).is_empty() and _fits(_stand_height, q):
			return q
	return null


func exit_vehicle(force := false) -> void:
	## force : sortie imposee (arrestation, vol, chargement) : on descend meme sans place libre.
	var v := vehicle
	if v == null:
		return
	var sortie: Variant = _sortie_libre(v)
	if sortie == null:
		if not force:
			Partie.notifier(tr("Pas la place pour descendre ici."))
			return
		sortie = v.exit_transform().origin
	process_physics_priority = 0
	_skirt_visible(true)
	_clear_ik()
	vehicle = null
	if not pillion:
		v.set_rider(false)
	pillion = false
	pillion_libre = false
	if v.has_method("a_portes") and v.a_portes():
		v.call("ouvrir_porte", "porte_g0", true, 0.25)
		get_tree().create_timer(1.3).timeout.connect(func() -> void:
			if is_instance_valid(v):
				v.call("ouvrir_porte", "porte_g0", false, 0.35))      # la portiere se referme derriere le conducteur
	elif v.has_method("portiere"):
		v.portiere(false)
	v.get_node("CamRig").activate(false)
	$CamPivot/SpringArm3D/Camera3D.current = true
	# on descend cote gauche (portiere conducteur / gauche de la moto), debout, dans le meme sens
	_exit_from = body.global_transform           # le corps visible glisse du siege jusqu'au sol (_process)
	_exit_t = 0.0
	global_transform = Transform3D(Basis.IDENTITY, sortie as Vector3)
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
	hip -= seat_hip_drop + (car_seat_raise if vehicle.name == "Voiture" else 0.0)
	var target := Transform3D(seat.basis, seat.origin - seat.basis.y * hip - seat.basis.z * (seat_hip_back - (0.52 if pillion else 0.0)))
	if _enter_t < 1.0:
		_enter_t = minf(1.0, _enter_t + _delta / enter_time)
		var k := smoothstep(0.0, 1.0, _enter_t)
		# on enjambe la moto / on se glisse dans la voiture : petit arc vers le haut a mi-chemin
		# zem : la jambe passe par-dessus la selle (arc plus haut) ; voiture : on se baisse sous le toit
		target = _enter_from.interpolate_with(target, k).translated(Vector3.UP * sin(k * PI) * (0.28 if vehicle.get("kind") == "zem" else 0.12))
	global_transform = target
	if pillion:
		_clear_ik()
	else:
		_ride_ik()
	body.rotation = Vector3.ZERO
	if anim:
		anim.speed = 0.0
		anim.on_floor = true
		anim.turn_rate = 0.0
		anim.accel = 0.0


func _physics_process(delta: float) -> void:
	_maj_logo_poitrine()
	if not _pre.is_empty():
		_pre_step(delta)
		return
	if Input.is_action_just_pressed("interact"):
		if vehicle:
			if (not pillion or pillion_libre) and (not vehicle.has_method("peut_descendre") or vehicle.peut_descendre()):
				exit_vehicle()
			elif vehicle.has_method("peut_descendre"):
				Partie.notifier(tr("On ne descend pas en vol : pose l'avion et arrête-toi."))
			return
		_carjack = false
		var v := _nearest_vehicle()
		if v:
			_start_pre(v)
			return
	if vehicle:
		_ride(delta)
		return
	if not _climb.is_empty():
		_climb_step(delta)
		return
	# un geste (achat, conversation...) s'arrete des qu'on repart
	if anim and anim.has_method("stop_clips") and anim.playing_clip() and _combo_t <= 0.0 and not garde and _roll_t <= 0.0 and _move_input().length() > 0.2 and _virage.is_empty():
		anim.stop_clips()
	if Input.is_action_just_pressed("crouch") and is_on_floor():
		_set_crouch(not crouched)
	_cam_offset.y = move_toward(_cam_offset.y, 1.15 if crouched else 1.6, 2.0 * delta)
	# coup de poing / bousculade (F, clic gauche, manette B) : les passants reagissent (scripts/pedestrians.gd)
	_punch_cd = maxf(0.0, _punch_cd - delta)
	_combo_t = maxf(0.0, _combo_t - delta)
	_roll_t = maxf(0.0, _roll_t - delta)
	var was_guard := garde
	garde = Input.is_action_pressed("garde") and is_on_floor() and _roll_t <= 0.0 and _combat_ok() and not arme_feu
	if garde and anim and anim.has_method("play_clips") and (not was_guard or not anim.playing_clip()):
		anim.play_clips([["Idle_Shield_Loop", 0.3]], true)
	elif was_guard and not garde and anim and anim.has_method("stop_clips"):
		anim.stop_clips()
	if Input.is_action_just_pressed("attaque") and is_on_floor() and _punch_cd <= 0.0 and not garde and _roll_t <= 0.0 and _combat_ok() and arme == "":
		_punch_cd = 0.38
		combo = (combo + 1) % COUPS.size() if _combo_t > 0.0 else 0
		_combo_t = combo_fenetre
		var coup := combo
		if anim and anim.has_method("play_clips"):
			anim.play_clips([[COUPS[coup], 0.0]], true)
		elif anim and anim.has_method("punch"):
			anim.punch()
		# passants de la rue et clients des interieurs (magasin, aerogare : scripts/pnj_interieur.gd)
		var targets := get_tree().get_nodes_in_group("pnj_interieur") + get_tree().get_nodes_in_group("cibles_coups")
		var peds := get_parent().get_node_or_null("Pietons")
		if peds:
			targets.append(peds)
		var fwd := Vector3(-sin(_facing), 0.0, -cos(_facing))
		get_tree().create_timer(0.18 + 0.06 * coup).timeout.connect(func() -> void:
			for tg in targets:
				if is_instance_valid(tg):
					if tg.player_attack(global_position, fwd, coup, [25.0, 30.0, 50.0][coup] * force):
						var st := get_parent().get_node_or_null("Stats")
						if st:
							st.coup_porte())
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
	elif garde and Input.is_action_just_pressed("jump"):
		# esquive : roulade dans la direction voulue (sinon en arriere), invulnerable pendant la roulade
		var iv := _move_input()
		var rd := Basis(Vector3.UP, cam_pivot.rotation.y) * Vector3(iv.x, 0, iv.y)
		_roll_dir = Vector2(rd.x, rd.z).normalized() if rd.length() > 0.2 else -Vector2(-sin(_facing), -cos(_facing))
		_roll_t = roulade_duree
		garde = false
		if anim and anim.has_method("play_clips"):
			anim.play_clips([["Roll", 0.0]], true)
	elif Input.is_action_just_pressed("jump"):
		# saut contextuel facon GTA V : accroupi on se releve, devant un rebord on l'escalade, sinon on saute
		if crouched:
			_set_crouch(false)
		elif _try_climb():
			return
		else:
			velocity.y = jump_velocity

	var input := _move_input()
	var dir := (Basis(Vector3.UP, cam_pivot.rotation.y) * Vector3(input.x, 0, input.y))
	# sprint facon GTA V : tapoter rapproche du sprint maximal, maintenir donne un sprint moyen ; endurance cachee
	if Input.is_action_just_pressed("sprint") and crouched:
		_set_crouch(false)            # sprinter releve le joueur
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
	if crouched:
		target_speed = crouch_speed
	if garde:
		target_speed = minf(target_speed, walk_speed)   # en garde on se deplace au pas
	# stick : l'inclinaison regle l'allure (marche lente -> marche -> trot)
	var tilt := minf(dir.length(), 1.0)
	if tilt < 0.98 and sprint_level <= 0.0:
		target_speed = lerpf(walk_speed * 0.6, target_speed, smoothstep(0.15, 0.95, tilt))
	target_speed *= minf(tilt * 4.0, 1.0)
	if _punch_cd > 0.0 and arme == "":
		target_speed = 0.0      # pieds plantes pendant un coup : le clip est sur place, sinon le personnage glisse

	var hvel := Vector2(velocity.x, velocity.z)
	var hspeed := hvel.length()

	if is_on_floor():
		_land_t = maxf(0.0, _land_t - delta)
		if _land_t > 0.0:
			hvel = hvel.move_toward(Vector2.ZERO, ground_decel * delta)
		elif _maj_virage(dir):
			hvel = Vector2.ZERO           # pas tourne sur place : le clip fait les pieds, le corps suit son bassin
		elif dir.length() > 0.01:
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

	if visee and is_on_floor():
		# en visee : le corps regarde ou vise la camera, on se deplace au pas dans toutes les directions
		_facing = cam_pivot.rotation.y
		hvel = hvel.move_toward(Vector2(dir.x, dir.z).limit_length(1.0) * walk_speed, ground_accel * delta)
	if _roll_t > 0.0:
		hvel = _roll_dir * roulade_vitesse * (0.4 + 0.6 * _roll_t / roulade_duree)
		_facing = atan2(-_roll_dir.x, -_roll_dir.y)
	if _punch_cd > 0.0 and arme == "" and is_on_floor():
		hvel = Vector2.ZERO
	velocity.x = hvel.x
	velocity.z = hvel.y
	_animations_vie(delta, dir, hvel.length())
	body.rotation.y = _facing
	move_and_slide()
	_step_up(hvel)

	if anim:
		var new_hspeed := Vector2(velocity.x, velocity.z).length()
		anim.speed = new_hspeed
		anim.on_floor = is_on_floor()
		anim.vertical_speed = velocity.y
		anim.turn_rate = angle_difference(_prev_facing, _facing) / delta
		anim.accel = (new_hspeed - _prev_hspeed) / delta
		anim.essouffle = clampf((0.6 - stamina) / 0.5, 0.0, 1.0)
		anim.crouch = crouched
		_update_look()
		if is_on_floor() and not was_on_floor and _fall_speed >= land_heavy:
			# vraie chute : flexion des jambes, on perd l'elan ; un saut ordinaire garde l'elan (pas de glissade)
			velocity.x *= land_brake
			velocity.z *= land_brake
			_land_t = land_stun
		if is_on_floor() and not was_on_floor:
			anim.land(_fall_speed)
			if _fall_speed > fall_hurt_speed:
				Partie.blesser((_fall_speed - fall_hurt_speed) * fall_hurt_per_ms)
			if _fall_speed > 5.0:
				shake(shake_land * clampf(_fall_speed / 9.0, 0.3, 1.0))
		_prev_hspeed = new_hspeed
	if is_on_floor():
		_fall_speed = 0.0
	_prev_facing = _facing


func _step_up(hvel: Vector2) -> void:
	## Monte une marche ou un rebord bas (trottoir, seuil de porte, escalier) au lieu de buter dessus.
	if not is_on_floor() or not is_on_wall() or hvel.length() < 0.3:
		return
	var fwd := Vector3(hvel.x, 0, hvel.y).normalized() * 0.2
	var xf := global_transform
	# hauteur la plus basse qui degage le passage (un seuil sous un linteau bas ne demande pas 30 cm)
	for k in range(1, 4):
		var up := Vector3.UP * step_height * k / 3.0
		if test_move(xf, up):
			return
		var raised := xf.translated(up)
		if test_move(raised, fwd):
			continue
		# pose sur le dessus de la marche
		var col := KinematicCollision3D.new()
		var top := raised.translated(fwd)
		if test_move(top, -up, col) and col.get_normal().y > 0.7:
			global_position = top.origin + col.get_travel()
			apply_floor_snap()
		return


func _fits(height: float, at: Vector3) -> bool:
	## Vrai si une capsule de cette hauteur (pieds en `at`) tient sans toucher le decor.
	var cap := CapsuleShape3D.new()
	cap.radius = ($Collision.shape as CapsuleShape3D).radius - 0.02
	cap.height = height
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (height * 0.5 + 0.04))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _set_crouch(on: bool) -> void:
	## Accroupi : capsule basse ; on ne se releve pas sous un plafond ou une table.
	if on == crouched or (not on and not _fits(_stand_height, global_position)):
		return
	crouched = on
	var cap := $Collision.shape as CapsuleShape3D
	cap.height = crouch_height if on else _stand_height
	$Collision.position.y = cap.height * 0.5
	if on:
		sprint_level = 0.0


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


func _try_climb() -> bool:
	## Rebord devant soi entre climb_min et climb_max (muret, cloture basse, conteneur, toit d'abri) : on l'agrippe
	## et on se hisse dessus (clip ClimbUp_1m), si l'on tient debout en haut.
	if anim == null or not anim.has_method("play_clips"):
		return false
	var fwd := Vector3(-sin(_facing), 0.0, -cos(_facing))
	var p := global_position
	var wall := _ray(p + Vector3.UP * 0.4, p + Vector3.UP * 0.4 + fwd * climb_reach)
	if wall.is_empty() or (wall["normal"] as Vector3).dot(fwd) > -0.5:
		return false
	var probe: Vector3 = wall["position"] + fwd * 0.3
	var top := _ray(Vector3(probe.x, p.y + climb_max + 0.3, probe.z), Vector3(probe.x, p.y + 0.3, probe.z))
	if top.is_empty() or (top["normal"] as Vector3).y < 0.7:
		return false
	var h: float = (top["position"] as Vector3).y - p.y
	if h < climb_min or h > climb_max:
		return false
	var dest: Vector3 = top["position"]
	if not _fits(_stand_height, dest) or not _fits(_stand_height, Vector3(p.x, dest.y, p.z)):
		return false        # pas la place en haut, ou plafond au-dessus du rebord
	var end: Vector3 = anim.root_offset(CLIMB_CLIP, 99.0)
	_climb = {"t": 0.0, "from": p, "dest": dest, "rise": maxf(end.y, 0.3), "adv": maxf(Vector2(end.x, end.z).length(), 0.1),
		"len": anim.clip_length(CLIMB_CLIP),
		"rate": clampf(1.0 / sqrt(h), 0.55, 1.3)}      # rebord haut : on se hisse plus lentement
	$Collision.disabled = true
	velocity = Vector3.ZERO
	sprint_level = 0.0
	anim.play_clips([[CLIMB_CLIP, 0.0]], true)
	return true


func _climb_step(delta: float) -> void:
	## Le corps suit la courbe de la racine du clip, mise a l'echelle de la hauteur et de la profondeur du rebord.
	var c := _climb
	c["t"] += delta * float(c["rate"])
	var o: Vector3 = anim.root_offset(CLIMB_CLIP, c["t"])
	var from: Vector3 = c["from"]
	var dest: Vector3 = c["dest"]
	var ky: float = (dest.y - from.y) / float(c["rise"])
	var flat := Vector2(dest.x - from.x, dest.z - from.z)
	var kf: float = Vector2(o.x, o.z).length() / float(c["adv"])
	global_position = Vector3(from.x + flat.x * kf, from.y + o.y * ky, from.z + flat.y * kf)
	anim.speed = 0.0
	anim.on_floor = true
	if c["t"] >= float(c["len"]):
		global_position = dest + Vector3.UP * 0.02
		_climb = {}
		$Collision.disabled = false
		apply_floor_snap()
		reset_physics_interpolation()


func _ride_ik() -> void:
	## Mains sur les poignees du guidon (zem) ou sur le volant, pieds sur les repose-pieds ou les pedales.
	if anim == null or not ("ik_targets" in anim):
		return
	var t: Dictionary = anim.ik_targets
	var vx: Transform3D = vehicle.global_transform
	var grip_l := vehicle.find_child("poignee_-1", true, false) as Node3D
	if grip_l:
		var grip_r := vehicle.find_child("poignee_1", true, false) as Node3D
		var peg_l := vehicle.find_child("cale_pied_-1", true, false) as Node3D
		var peg_r := vehicle.find_child("cale_pied_1", true, false) as Node3D
		t["LeftHand"] = grip_l.global_position
		t["RightHand"] = grip_r.global_position if grip_r else Vector3.INF
		t["LeftFoot"] = peg_l.global_position + vx.basis.y * 0.05 if peg_l else Vector3.INF
		t["RightFoot"] = peg_r.global_position + vx.basis.y * 0.05 if peg_r else Vector3.INF
		return
	var wheel := vehicle.find_child("pt_volant", true, false) as Node3D
	var pedals := vehicle.find_child("pt_pedales", true, false) as Node3D
	if wheel:
		var side := wheel.global_transform.basis.x.normalized()
		t["LeftHand"] = wheel.global_position - side * 0.17
		t["RightHand"] = wheel.global_position + side * 0.17
	if pedals:
		var side2 := pedals.global_transform.basis.x.normalized()
		t["LeftFoot"] = pedals.global_position - side2 * 0.12 + vx.basis.y * 0.08
		t["RightFoot"] = pedals.global_position + side2 * 0.08 + vx.basis.y * 0.08


func _clear_ik() -> void:
	if anim and "ik_targets" in anim:
		for k in anim.ik_targets:
			anim.ik_targets[k] = Vector3.INF


func _maj_virage(dir: Vector3) -> bool:
	## Vrai pendant un pas tourne sur place (lance ici quand le joueur, a l'arret, demande une direction tres differente).
	if anim == null or not anim.has_method("clip_position"):
		return false
	if _virage.is_empty():
		if dir.length() < 0.2 or Vector2(velocity.x, velocity.z).length() > 0.3 or crouched or visee or garde \
				or _roll_t > 0.0 or _land_t > 0.0 or not menus.is_empty() or (anim.playing_clip() and _move_input().length() <= 0.2):
			return false
		var diff := angle_difference(_facing, atan2(-dir.x, -dir.z))
		if absf(diff) < deg_to_rad(virage_seuil):
			return false
		var nom := "MX_DemiTour_Marche" if absf(diff) > deg_to_rad(135.0) else ("MX_Tourne_G90" if diff > 0.0 else "MX_Tourne_D90")
		var duree: float = anim.clip_length(nom)
		var total: float = anim.lacet(nom, duree)
		if duree <= 0.0 or absf(total) < 0.5:
			return false
		if signf(diff) != signf(total):
			diff += signf(total) * TAU       # demi-tour : on tourne du cote ou tourne la capture
		anim.stop_clips()
		anim.play_clips([[nom, 0.0]], true, virage_vitesse)
		_virage = {"nom": nom, "depart": _facing, "angle": diff, "total": total, "duree": duree}
	var t: float = anim.clip_position(_virage["nom"])
	if t < 0.0:
		_virage.clear()
		return false
	var fait := clampf(anim.lacet(_virage["nom"], t) / float(_virage["total"]), 0.0, 1.0)
	_facing = wrapf(float(_virage["depart"]) + float(_virage["angle"]) * fait, -PI, PI)
	if fait >= virage_sortie and dir.length() > 0.2:
		anim.stop_clips()             # la fin du clip est un temps de pose : on repart, le reste du virage se fait en marchant
		_virage.clear()
		return false
	return true


func _animations_vie(delta: float, dir: Vector3, hspeed: float) -> void:
	## Arret marque apres une course (MX_Arret) et gestes d'attente (regarder autour, bras croises...) quand le joueur
	## reste immobile ; tout mouvement les interrompt (stop_clips plus haut).
	if anim == null or not anim.has_method("play_clips") or not is_on_floor() or crouched or visee or garde 			or _roll_t > 0.0 or not menus.is_empty():
		_immobile_t = 0.0
		_vitesse_prec = hspeed
		return
	var lache := dir.length() < 0.01
	if lache and _vitesse_prec > 3.5 and not anim.playing_clip():
		anim.play_clips([["MX_Arret", 0.0]], true)    # on freine sur un ou deux pas, en place (le corps ralentit seul)
	if lache and hspeed < 0.1:
		_immobile_t += delta
		if _immobile_t > _prochain_geste and not anim.playing_clip():
			anim.play_clips(GESTES_ATTENTE[randi() % GESTES_ATTENTE.size()], true)
			_immobile_t = 0.0
			_prochain_geste = randf_range(attente_geste.x, attente_geste.y)
	else:
		_immobile_t = 0.0
	_vitesse_prec = hspeed
