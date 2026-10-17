extends Node3D
## Pilote d'animation a base de clips captes (Quaternius, CC0), redirigees sur le squelette standard des personnages.
## Remplace l'animation procedurale (character_anim.gd) avec la meme interface : speed, on_floor, vertical_speed,
## turn_rate, accel, seated, crouch, land(), punch(), essouffle, look_yaw, look_pitch, femme, gesture...
##
## Calage pieds / vitesse : le deplacement reste pilote par le controleur (player.gd : sprint en tapotant, endurance,
## collisions) ; la vitesse naturelle de chaque clip est mesuree (root motion de la piste Root) et la vitesse de
## lecture est reglee pour que les pieds avancent exactement a la vitesse du corps : aucun patinage.
##
## Arbre : melange de deplacement (attente / marche / trot / sprint, cycles synchronises) -> echelle de temps ->
## mode (sol, air, assis, accroupi) -> impulsion (une fois) -> reception (une fois) -> coup (une fois).
## Par-dessus l'animation : regard (tete et buste), inclinaison dans les virages, respiration haletante.

const LIBS := {"ual1": "res://assets/animations/UAL1_RM.glb", "ual2": "res://assets/animations/UAL2_RM.glb"}
const ROOT_TRACK := "%GeneralSkeleton:Root"
const LOCO := [["Idle", 0.0], ["Walk", 1.0], ["Jog_Fwd", 2.0], ["Sprint", 3.0]]   # [clip, position dans le melange]
const MODES := ["sol", "air", "assis", "accroupi"]
# vitesse du pied d'appui dans chaque clip (tests/calibre_clips.gd sur l'homme, en hauteurs de hanche par seconde) :
# plus juste que la piste Root (la marche y avance plus vite que ses pieds)
const CALIB := {"Walk": 0.914, "Jog_Fwd": 5.79, "Sprint": 9.5, "Crouch_Fwd": 0.914, "Walk_Carry": 0.58}

@export var walk_to_jog := Vector2(1.9, 3.0)     # m/s : passage progressif marche -> trot
@export var jog_to_sprint := Vector2(5.6, 6.6)   # m/s : passage trot -> sprint
@export var lean_per_turn := 0.05                # inclinaison (rad) par (rad/s x m/s) dans les virages
@export var stance_width := 0.26                 # m entre les chevilles au repos
@export var stance_stagger := 0.08               # m d'un pied devant l'autre au repos
@export var saut_course_min := 1.0             # m/s : au-dela, saut en mouvement (foulee gardee en l'air)
@export var foulee_air := 0.2                    # vitesse de lecture de la foulee en l'air (jambes presque figees)
@export var reception_lourde := 6.0              # m/s de chute : au-dela, reception complete (Jump_Land)
@export var reception_courte := 0.15             # s de reception apres un petit saut sur place
@export var buste_marche := 0.04                 # rad : inclinaison du buste (bassin -> cou) en marchant
@export var buste_trot := 0.12                   # rad en trottinant
@export var buste_sprint := 0.24                 # rad en sprint
@export var cou_cible := 0.08                    # rad : tete presque droite (regard vers l'horizon)
@export var jambe_appui := 0.985                 # part de la longueur de jambe : jambe d'appui presque tendue
@export var bassin_max := 0.07                   # m : remontee maximale du bassin
@export var impulsion_duree := 0.22             # s de clip Jump_Start (poussee) avant de l'effacer
@export var pose_chute_apres := 0.75             # s en l'air avant la pose de chute (un saut dure ~0,63 s)
@export var anim_lod := true                    # PNJ eloignes animes moins souvent (le joueur : false)
@export var lod_steps: Array[float] = [8.0, 20.0, 45.0]   # m : au-dela, une image sur 2, 3, puis 4

var speed := 0.0
var on_floor := true
var vertical_speed := 0.0
var turn_rate := 0.0
var accel := 0.0
var seated := false
var crouch := false
var femme := false
var gesture := 0.0
var essouffle := 0.0
var look_yaw := 0.0
var look_pitch := 0.0
var posture := 0.0
var carry_head := false
var rain_cover := 0.0
# cibles en position monde (Vector3.INF : aucune) : mains sur le guidon / volant, pieds sur les repose-pieds / pedales
var ik_targets := {"LeftHand": Vector3.INF, "RightHand": Vector3.INF, "LeftFoot": Vector3.INF, "RightFoot": Vector3.INF}

static var _libs := {}            # bibliotheques chargees une fois pour tous les personnages
static var _natural := {}         # vitesse naturelle des clips (hauteurs de hanche par seconde)

var _skel: Skeleton3D
var _player: AnimationPlayer
var _tree: AnimationTree
var _look := Vector2.ZERO
var _lean := 0.0
var _was_floor := true
var _t := 0.0
var _bone := {}


static func _load_libs() -> void:
	if not _libs.is_empty():
		return
	for key in LIBS:
		var s: Node = (load(LIBS[key]) as PackedScene).instantiate()
		var ap := s.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var lib := ap.get_animation_library(ap.get_animation_library_list()[0])
		_libs[key] = lib
		for n in lib.get_animation_list():
			var a := lib.get_animation(n)
			var t := a.find_track(NodePath(ROOT_TRACK), Animation.TYPE_POSITION_3D)
			if t >= 0 and a.length > 0.0:
				var d: Vector3 = a.position_track_interpolate(t, a.length) - a.position_track_interpolate(t, 0.0)
				_natural[n] = CALIB.get(n, Vector2(d.x, d.z).length() / a.length)
		s.free()


static func clip(name: String) -> String:
	## Nom complet ("ual1/Walk") d'un clip des bibliotheques.
	_load_libs()
	for key in _libs:
		if (_libs[key] as AnimationLibrary).has_animation(name):
			return "%s/%s" % [key, name]
	return ""


func _ready() -> void:
	_skel = Squelette.find(self)
	if _skel == null:
		return
	_load_libs()
	for n in ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
			"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]:
		_bone[n] = _skel.find_bone(n)
	_player = AnimationPlayer.new()
	_player.name = "Clips"
	add_child(_player)
	_player.root_node = NodePath("..")
	for key in _libs:
		_player.add_animation_library(key, _libs[key])
	for n in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Idle", "Crouch_Fwd", "Driving", "Idle_Talking"]:
		var a: Animation = _player.get_animation(clip(n))
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	_tree = AnimationTree.new()
	_tree.name = "Arbre"
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(_player)
	_tree.root_node = NodePath("..")
	_tree.root_motion_track = NodePath(ROOT_TRACK)      # translation du clip retiree : le controleur deplace le corps
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_tree.tree_root = _build_tree()
	_tree.active = true


func _anim(name: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip(name)
	return n


func _build_tree() -> AnimationNodeBlendTree:
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.sync = not anim_lod      # joueur : cycles synchronises ; PNJ : seuls les clips actifs sont calcules
	loco.min_space = 0.0
	loco.max_space = 3.0
	for e in LOCO:
		loco.add_blend_point(_anim(e[0]), e[1], -1, e[0])
	bt.add_node("loco", loco, Vector2(0, 0))
	bt.add_node("echelle", AnimationNodeTimeScale.new(), Vector2(200, 0))
	bt.connect_node("echelle", 0, "loco")
	var crouch_bs := AnimationNodeBlendSpace1D.new()
	crouch_bs.sync = not anim_lod
	crouch_bs.add_blend_point(_anim("Crouch_Idle"), 0.0, -1, "Crouch_Idle")
	crouch_bs.add_blend_point(_anim("Crouch_Fwd"), 1.0, -1, "Crouch_Fwd")
	bt.add_node("accroupi", crouch_bs, Vector2(0, 300))
	bt.add_node("echelle_accroupi", AnimationNodeTimeScale.new(), Vector2(200, 300))
	bt.connect_node("echelle_accroupi", 0, "accroupi")
	bt.add_node("air", _anim("Jump"), Vector2(0, 150))
	bt.add_node("assis", _anim("Driving"), Vector2(0, 220))
	var mode := AnimationNodeTransition.new()
	for m in MODES:
		mode.add_input(m)
	mode.xfade_time = 0.2
	bt.add_node("mode", mode, Vector2(420, 100))
	bt.connect_node("mode", 0, "echelle")
	bt.connect_node("mode", 1, "air")
	bt.connect_node("mode", 2, "assis")
	bt.connect_node("mode", 3, "echelle_accroupi")
	var prev := "mode"
	var x := 640
	for s in [["impulsion", "Jump_Start", 0.08, 0.2], ["reception", "Jump_Land", 0.05, 0.25], ["coup", "Punch_Jab", 0.08, 0.2]]:
		var os := AnimationNodeOneShot.new()
		os.fadein_time = s[2]
		os.fadeout_time = s[3]
		bt.add_node(s[0], os, Vector2(x, 100))
		bt.add_node(s[0] + "_clip", _anim(s[1]), Vector2(x, 250))
		bt.connect_node(s[0], 0, prev)
		bt.connect_node(s[0], 1, s[0] + "_clip")
		prev = s[0]
		x += 220
	bt.connect_node("output", 0, prev)
	return bt


func _gait(v: float) -> float:
	## Position dans le melange (0 attente, 1 marche, 2 trot, 3 sprint) selon la vitesse reelle.
	if v < 0.15:
		return 0.0
	if v <= walk_to_jog.x:
		return clampf(v / 0.6, 0.0, 1.0)
	if v <= walk_to_jog.y:
		return 1.0 + (v - walk_to_jog.x) / (walk_to_jog.y - walk_to_jog.x)
	if v <= jog_to_sprint.x:
		return 2.0
	return 2.0 + clampf((v - jog_to_sprint.x) / (jog_to_sprint.y - jog_to_sprint.x), 0.0, 1.0)


func _natural_speed(g: float) -> float:
	## Vitesse (m/s) a laquelle les pieds du melange avancent a vitesse de lecture normale.
	var k := _skel.motion_scale if _skel else 1.0
	var w: float = _natural.get("Walk", 1.0) * k
	var j: float = _natural.get("Jog_Fwd", 5.0) * k
	var s: float = _natural.get("Sprint", 8.0) * k
	if g <= 1.0:
		return w
	if g <= 2.0:
		return lerpf(w, j, g - 1.0)
	return lerpf(j, s, g - 2.0)


var _air_moving := false        # saut en mouvement : foulee de course gardee en l'air, pas de clip de saut
var _land_cut := -1.0
var _imp_cut := -1.0
var _air_t := 0.0            # s avant d'effacer la reception (petit saut sur place)


func land(fall_speed: float) -> void:
	## Reception : rien apres un saut en mouvement (on enchaine la course), courte flexion apres un petit saut
	## sur place, reception complete seulement apres une vraie chute.
	if _tree == null or fall_speed < 1.5:
		return
	if fall_speed >= reception_lourde:
		_tree.set("parameters/reception/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	elif not _air_moving and speed < saut_course_min:
		_tree.set("parameters/reception/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_land_cut = reception_courte


func punch() -> void:
	if _tree:
		_tree.set("parameters/coup/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


var _lod_acc := 0.0
var _lod_frame := 0


func _lod_every() -> int:
	if not anim_lod:
		return 1
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 1
	var d := cam.global_position.distance_to(global_position)
	var n := 1
	for s in lod_steps:
		if d > s:
			n += 1
	return n


var ragdoll := false        # corps simule par la physique (scripts/ragdoll.gd) : l'animation s'efface
var _shadow_on := true
var _meshes: Array = []


func _shadows(on: bool) -> void:
	## Etape 17 : au-dela du 2e palier (20 m), un PNJ ne projette plus d'ombre (passe d'ombre des maillages animes).
	if on == _shadow_on:
		return
	_shadow_on = on
	if _meshes.is_empty():
		_meshes = find_children("*", "MeshInstance3D", true, false)
	for m in _meshes:
		if is_instance_valid(m):
			(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	if _tree == null or ragdoll:
		return
	# niveau de detail : un PNJ eloigne n'est recalcule qu'une image sur n (decalage propre a chacun)
	_lod_acc += delta
	_lod_frame += 1
	var every := _lod_every()
	if anim_lod and _lod_frame % 15 == 0:
		_shadows(every <= 2)
	if (_lod_frame + get_instance_id()) % every != 0:
		return
	delta = _lod_acc
	_lod_acc = 0.0
	_t += delta
	if _clip_step(delta):
		return
	var mode := "sol"
	if on_floor:
		_air_moving = false
		_air_t = 0.0
	else:
		_air_t += delta
		if _was_floor and not seated:
			_air_moving = speed >= saut_course_min
	if _imp_cut > 0.0:
		_imp_cut -= delta
		if _imp_cut <= 0.0:
			_tree.set("parameters/impulsion/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	if _land_cut > 0.0:
		_land_cut -= delta
		if _land_cut <= 0.0:
			_tree.set("parameters/reception/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	if seated:
		mode = "assis"
	elif not on_floor and not _air_moving and _air_t > pose_chute_apres:
		mode = "air"          # vraie chute (plus longue qu'un saut) : pose en l'air
	elif crouch:
		mode = "accroupi"
	if _tree.get("parameters/mode/current_state") != mode:
		_tree.set("parameters/mode/transition_request", mode)
	if _was_floor and not on_floor and vertical_speed > 1.0 and not seated and not _air_moving:
		_tree.set("parameters/impulsion/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_imp_cut = impulsion_duree     # seulement la poussee des jambes, pas la suite acrobatique du clip
	_was_floor = on_floor
	var g := _gait(speed)
	_tree.set("parameters/loco/blend_position", g)
	_tree.set("parameters/echelle/scale", foulee_air if not on_floor and _air_moving else (clampf(speed / _natural_speed(g), 0.5, 2.0) if g >= 1.0 else 1.0))
	var cn: float = _natural.get("Crouch_Fwd", 0.8) * (_skel.motion_scale if _skel else 1.0)
	_tree.set("parameters/accroupi/blend_position", clampf(speed / 0.5, 0.0, 1.0))
	_tree.set("parameters/echelle_accroupi/scale", clampf(speed / cn, 0.6, 1.8) if speed > 0.2 else 1.0)
	_tree.advance(delta)
	_overlay(delta)


func _overlay(delta: float) -> void:
	## Ajouts par-dessus l'animation : regard (tete 65 %, buste 30 %), respiration haletante, inclinaison en virage.
	var moving := clampf((speed - 0.3) / 0.6, 0.0, 1.0) if on_floor and not seated and not crouch and _clip_free() else 0.0
	if moving > 0.01 and (not anim_lod or _lod_every() <= 1):
		_upright(moving)
	_look = _look.lerp(Vector2(clampf(look_yaw, -1.2, 1.2), clampf(look_pitch, -0.4, 0.6)), 1.0 - exp(-5.0 * delta))
	var breath := sin(_t * (1.7 + 2.6 * essouffle)) * 0.035 * essouffle
	_turn_bone("Head", Vector3(-_look.y * 0.8, _look.x * 0.65, 0.0))
	_turn_bone("UpperChest", Vector3(breath, _look.x * 0.3, 0.0))
	var target := clampf(-turn_rate * speed * lean_per_turn, -0.35, 0.35) if on_floor and not seated else 0.0
	_lean = lerpf(_lean, target, 1.0 - exp(-4.0 * delta))
	rotation.z = _lean
	# dos voute (personne agee) : buste penche, tete relevee pour regarder devant
	# (seulement des os que les clips reecrivent a chaque image, sinon la rotation s'accumulerait)
	if posture != 0.0:
		_turn_bone("UpperChest", Vector3(posture, 0.0, 0.0))
		_turn_bone("Head", Vector3(-posture * 0.6, 0.0, 0.0))
	_gest = lerpf(_gest, gesture, 1.0 - exp(-6.0 * delta))
	_rain = lerpf(_rain, rain_cover, 1.0 - exp(-3.0 * delta))
	var hold := smoothstep(0.1, 0.6, sin(_t * 0.35 + get_instance_id() % 7)) if carry_head else 0.0
	if _gest > 0.01 or _rain > 0.01 or hold > 0.01:
		var head := _skel.global_transform * _gpose(_bone["Head"], {}).origin
		var b := _skel.global_transform.basis.orthonormalized()
		var fwd := b * Vector3(0, 0, 1)      # le squelette regarde +Z
		var right := b * Vector3(-1, 0, 0)
		var wave := sin(_t * 7.0)
		# coude ouvert sur le cote quand la main monte sur la tete, vers le bas devant le buste
		if hold > 0.01:            # charge sur la tete : la main droite vient la stabiliser
			_arm_to("Right", head + Vector3.UP * 0.26 + right * 0.08, hold, right + Vector3.UP * 0.3)
		elif _rain > 0.01:         # averse : main a plat sur le haut du crane
			_arm_to("Right", head + Vector3.UP * 0.12 + fwd * 0.06 + right * 0.03, _rain, right + fwd * 0.4)
		if _gest > 0.01:           # dispute : mains qui s'agitent devant le buste
			_arm_to("Right", head - Vector3.UP * (0.2 - 0.1 * wave) + fwd * 0.38 + right * 0.18, _gest, right - Vector3.UP)
			_arm_to("Left", head - Vector3.UP * (0.38 + 0.06 * wave) + fwd * 0.3 - right * 0.14, _gest, -right - Vector3.UP)
	# au repos, pieds a largeur de bassin et presque alignes (le clip Idle se tient en garde : 0,26 m d'ecart lateral
	# trop large et un pied 0,38 m devant l'autre)
	var still := (1.0 - clampf(speed / 0.4, 0.0, 1.0)) if on_floor and not seated and not crouch else 0.0
	if still > 0.01 and ik_targets["LeftFoot"] == Vector3.INF:
		var lf := _skel.global_transform * _gpose(_bone["LeftFoot"], {}).origin
		var rf := _skel.global_transform * _gpose(_bone["RightFoot"], {}).origin
		var bb := _skel.global_transform.basis.orthonormalized()
		var side := bb * Vector3(1, 0, 0)
		var ahead := bb * Vector3(0, 0, 1)
		var half := (lf - rf).dot(side) * 0.5
		var half_f := (lf - rf).dot(ahead) * 0.5
		var shift := (side * (signf(half) * stance_width * 0.5 - half) + ahead * (signf(half_f) * stance_stagger * 0.5 - half_f)) * still
		# bassin remonte pour que les jambes soient presque tendues (le clip garde le bassin bas, jambes en garde)
		var raise := 0.0
		for e in [["Left", lf + shift], ["Right", rf - shift]]:
			var hip := _skel.global_transform * _gpose(_bone[e[0] + "UpperLeg"], {}).origin
			var knee := _skel.global_transform * _gpose(_bone[e[0] + "LowerLeg"], {}).origin
			var leg := (knee - hip).length() + ((e[1] as Vector3) - knee).length()
			var d: Vector3 = hip - e[1]
			var flat := Vector2(d.x, d.z).length()
			raise += (sqrt(maxf(pow(leg * 0.975, 2.0) - flat * flat, 0.0)) - d.y) * 0.5
		raise = clampf(raise, 0.0, 0.1) * still
		var ih: int = _bone["Hips"]
		var root_b := _gpose(_skel.get_bone_parent(ih), {}).basis if _skel.get_bone_parent(ih) >= 0 else Basis.IDENTITY
		var up_local := root_b.inverse() * (_skel.global_transform.basis.inverse() * (Vector3.UP * raise))
		_skel.set_bone_pose_position(ih, _skel.get_bone_pose_position(ih) + up_local)
		_two_bone_ik("LeftUpperLeg", "LeftLowerLeg", "LeftFoot", lf + shift, ahead)
		_two_bone_ik("RightUpperLeg", "RightLowerLeg", "RightFoot", rf - shift, ahead)
	for end in ik_targets:
		if ik_targets[end] != Vector3.INF:
			var side: String = "Left" if end.begins_with("Left") else "Right"
			if end.ends_with("Hand"):
				_two_bone_ik(side + "UpperArm", side + "LowerArm", end, ik_targets[end])
			else:
				_two_bone_ik(side + "UpperLeg", side + "LowerLeg", end, ik_targets[end])


func _clip_free() -> bool:
	return _seq.is_empty() and (_clip == null or not _clip.is_playing())


func _upright(w: float) -> void:
	## Les clips de marche et de course (Quaternius) avancent buste penche, tete basse et genoux toujours plies.
	## On ramene le buste a l'inclinaison d'une vraie personne selon l'allure, la tete a l'horizontale, et on
	## remonte le bassin pour que la jambe d'appui se tende (pieds gardes a leur place par IK).
	var g := _gait(speed)
	var target := lerpf(buste_marche, buste_trot, clampf(g - 1.0, 0.0, 1.0)) if g < 2.0 \
		else lerpf(buste_trot, buste_sprint, clampf(g - 2.0, 0.0, 1.0))
	var hips := _gpose(_bone["Hips"], {}).origin
	var neck := _gpose(_bone["Neck"], {}).origin
	var lean := atan2(neck.z - hips.z, neck.y - hips.y)        # squelette : +Z devant, +Y en haut
	var corr := (target - lean) * w
	_turn_bone("UpperChest", Vector3(corr, 0.0, 0.0))   # os reecrit par les clips a chaque image (pas d'accumulation)
	var hy := _gpose(_bone["Head"], {}).basis.orthonormalized() * Vector3.UP   # axe du crane (os : +Y vers le haut)
	var tilt := atan2(hy.z, hy.y)                               # > 0 : tete penchee en avant, regard vers le sol
	_turn_bone("Head", Vector3((tilt - cou_cible) * w, 0.0, 0.0))
	# bassin : jambe d'appui (pied le plus bas) presque tendue
	var feet := {}
	for s in ["Left", "Right"]:
		feet[s] = _skel.global_transform * _gpose(_bone[s + "Foot"], {}).origin
	var st: String = "Left" if (feet["Left"] as Vector3).y < (feet["Right"] as Vector3).y else "Right"
	var hip := _skel.global_transform * _gpose(_bone[st + "UpperLeg"], {}).origin
	var knee := _skel.global_transform * _gpose(_bone[st + "LowerLeg"], {}).origin
	var leg := (knee - hip).length() + ((feet[st] as Vector3) - knee).length()
	var d: Vector3 = hip - feet[st]
	var flat := Vector2(d.x, d.z).length()
	var raise := clampf((sqrt(maxf(pow(leg * jambe_appui, 2.0) - flat * flat, 0.0)) - d.y), 0.0, bassin_max) * w
	if raise > 0.002:
		var ih: int = _bone["Hips"]
		var root_b := _gpose(_skel.get_bone_parent(ih), {}).basis if _skel.get_bone_parent(ih) >= 0 else Basis.IDENTITY
		var up_local := root_b.inverse() * (_skel.global_transform.basis.inverse() * (Vector3.UP * raise))
		_skel.set_bone_pose_position(ih, _skel.get_bone_pose_position(ih) + up_local)
		var ahead := _skel.global_transform.basis.orthonormalized() * Vector3(0, 0, 1)
		_two_bone_ik("LeftUpperLeg", "LeftLowerLeg", "LeftFoot", feet["Left"], ahead)
		_two_bone_ik("RightUpperLeg", "RightLowerLeg", "RightFoot", feet["Right"], ahead)
	# bras : ecart minimal aux hanches (evite que la main ou l'avant-bras ne traverse le bassin, le pagne ou la poche)
	for e in [["Left", 1.0, -0.055], ["Right", -1.0, 0.055]]:
		_turn_bone(e[0] + "UpperArm", Vector3(0.0, 0.0, float(e[2]) * w))


func _arm_to(side: String, goal: Vector3, w: float, pole := Vector3.ZERO) -> void:
	## Amene la main vers `goal` (monde) avec un poids w (0 : pose du clip, 1 : sur la cible) ; pole : ou pointe le coude.
	var hand := _skel.global_transform * _gpose(_bone[side + "Hand"], {}).origin
	_two_bone_ik(side + "UpperArm", side + "LowerArm", side + "Hand", hand.lerp(goal, clampf(w, 0.0, 1.0)), pole)


# ------------------------------------------------------------------ clips ponctuels (chute, coup encaisse, releve)
var _gest := 0.0
var _rain := 0.0
var _clip: AnimationPlayer
var _seq: Array = []          # [[clip, attente apres (s)], ...]
var _hold := 0.0


func clip_length(name: String) -> float:
	var c := clip(name)
	return (_libs[c.get_slice("/", 0)] as AnimationLibrary).get_animation(name).length if c != "" else 0.0


func root_offset(name: String, t: float) -> Vector3:
	## Deplacement de la racine du clip entre 0 et t (m, repere du squelette : +Z devant), a l'echelle du personnage.
	var a: Animation = (_libs[clip(name).get_slice("/", 0)] as AnimationLibrary).get_animation(name)
	var tr := a.find_track(NodePath(ROOT_TRACK), Animation.TYPE_POSITION_3D)
	if tr < 0:
		return Vector3.ZERO
	var k := _skel.motion_scale if _skel else 1.0
	return (a.position_track_interpolate(tr, clampf(t, 0.0, a.length)) - a.position_track_interpolate(tr, 0.0)) * k


func play_clips(seq: Array, in_place := false) -> void:
	## Joue une suite de clips (ex. [["Death01", 1.2], ["LayToIdle", 0.0]]) a la place de l'arbre, puis reprend.
	## in_place : le deplacement de la racine est retire (le controleur deplace lui-meme le corps, ex. escalade).
	if _skel == null:
		return
	if _clip == null:
		_clip = AnimationPlayer.new()
		_clip.name = "ClipsCaptes"
		add_child(_clip)
		_clip.root_node = NodePath("..")
		_clip.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for key in _libs:
			_clip.add_animation_library(key, _libs[key])
	_clip.root_motion_track = NodePath(ROOT_TRACK) if in_place else NodePath()
	_seq = seq.duplicate(true)
	_hold = 0.0
	_next_clip()


func stop_clips() -> void:
	## Interrompt un geste (le joueur repart) : l'arbre d'animation reprend la main.
	_seq.clear()
	_hold = 0.0
	if _clip:
		_clip.stop()


func playing_clip() -> bool:
	return not _seq.is_empty() or (_clip != null and _clip.is_playing()) or _hold > 0.0


func _next_clip() -> void:
	if _seq.is_empty():
		_clip.stop()
		return
	var e: Array = _seq.pop_front()
	_clip.play(clip(String(e[0])), 0.12)
	_hold = -float(e[1])          # negatif : attente a faire une fois le clip termine


func _clip_step(delta: float) -> bool:
	## Vrai tant qu'un clip ponctuel pilote le squelette.
	if _clip == null or (not _clip.is_playing() and _hold == 0.0 and _seq.is_empty()):
		return false
	if _clip.is_playing():
		_clip.advance(delta)
		return true
	if _hold < 0.0:
		_hold = -_hold
		if _hold == 0.0:
			_next_clip()
		return true
	_hold = maxf(0.0, _hold - delta)
	if _hold == 0.0:
		_next_clip()
		return not _seq.is_empty() or _clip.is_playing()
	return true


func _turn_bone(name: String, euler: Vector3) -> void:
	## Rotation supplementaire d'un os, exprimee dans le repere du personnage (x : vers le haut / bas, y : gauche / droite).
	var i: int = _bone.get(name, -1)
	if i < 0 or euler.length_squared() < 1e-8:
		return
	# repere du personnage dans le squelette : le modele regarde +Z (demi-tour fait par PnjUtil.make)
	var parent := _skel.get_bone_parent(i)
	var pg := _skel.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var r := Basis.from_euler(Vector3(-euler.x, euler.y, -euler.z))
	var local := pg.inverse() * r * pg
	_skel.set_bone_pose_rotation(i, (local * Basis(_skel.get_bone_pose_rotation(i))).get_rotation_quaternion())


func _gpose(i: int, local: Dictionary) -> Transform3D:
	## Pose globale d'un os (repere du squelette) en tenant compte des rotations deja modifiees dans `local`.
	var chain: Array[int] = []
	var b := i
	while b >= 0:
		chain.push_front(b)
		b = _skel.get_bone_parent(b)
	var xf := Transform3D.IDENTITY
	for c in chain:
		var q: Quaternion = local.get(c, _skel.get_bone_pose_rotation(c))
		xf = xf * Transform3D(Basis(q).scaled(_skel.get_bone_pose_scale(c)), _skel.get_bone_pose_position(c))
	return xf


func _two_bone_ik(upper: String, lower: String, end: String, target_world: Vector3, pole_world := Vector3.ZERO) -> void:
	## IK analytique a deux os (epaule-coude-main ou hanche-genou-pied) : le coude / genou garde son plan de flexion,
	## ou pointe vers pole_world (direction monde) si elle est donnee.
	var iu: int = _bone.get(upper, -1)
	var il: int = _bone.get(lower, -1)
	var ie: int = _bone.get(end, -1)
	if iu < 0 or il < 0 or ie < 0:
		return
	var t := _skel.global_transform.affine_inverse() * target_world
	var gu := _gpose(iu, {})
	var gl := _gpose(il, {})
	var ge := _gpose(ie, {})
	var a := gu.origin
	var b := gl.origin
	var c := ge.origin
	var l1 := (b - a).length()
	var l2 := (c - b).length()
	var to_t := t - a
	var d := clampf(to_t.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	var dir := to_t.normalized()
	# plan de flexion : direction actuelle du coude / genou, retiree de l'axe epaule -> cible
	var pole := (b - a) - dir * (b - a).dot(dir)
	if pole_world != Vector3.ZERO:
		var pw := _skel.global_transform.basis.inverse() * pole_world
		pole = pw - dir * pw.dot(dir)
	if pole.length() < 1e-4:
		pole = Vector3.UP.cross(dir) if absf(dir.y) < 0.9 else Vector3.RIGHT
	pole = pole.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var b2 := a + dir * (l1 * cos_a) + pole * (l1 * sqrt(1.0 - cos_a * cos_a))
	# os superieur : (b - a) -> (b2 - a)
	var r1 := Quaternion((b - a).normalized(), (b2 - a).normalized())
	var pu := _gpose(_skel.get_bone_parent(iu), {}).basis.get_rotation_quaternion() if _skel.get_bone_parent(iu) >= 0 else Quaternion.IDENTITY
	var new_gu := r1 * gu.basis.get_rotation_quaternion()
	var lu := pu.inverse() * new_gu
	var local := {iu: lu}
	# os inferieur : (c - b2) -> (t - b2)
	var gl2 := _gpose(il, local)
	var ge2 := _gpose(ie, local)
	var r2 := Quaternion((ge2.origin - gl2.origin).normalized(), (a + dir * d - gl2.origin).normalized())
	var ll := new_gu.inverse() * (r2 * gl2.basis.get_rotation_quaternion())
	_skel.set_bone_pose_rotation(iu, lu.normalized())
	_skel.set_bone_pose_rotation(il, ll.normalized())
