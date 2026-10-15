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
	loco.sync = true
	loco.min_space = 0.0
	loco.max_space = 3.0
	for e in LOCO:
		loco.add_blend_point(_anim(e[0]), e[1], -1, e[0])
	bt.add_node("loco", loco, Vector2(0, 0))
	bt.add_node("echelle", AnimationNodeTimeScale.new(), Vector2(200, 0))
	bt.connect_node("echelle", 0, "loco")
	var crouch_bs := AnimationNodeBlendSpace1D.new()
	crouch_bs.sync = true
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


func land(fall_speed: float) -> void:
	if _tree and fall_speed > 1.5:
		_tree.set("parameters/reception/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func punch() -> void:
	if _tree:
		_tree.set("parameters/coup/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _physics_process(delta: float) -> void:
	if _tree == null:
		return
	_t += delta
	var mode := "sol"
	if seated:
		mode = "assis"
	elif not on_floor:
		mode = "air"
	elif crouch:
		mode = "accroupi"
	if _tree.get("parameters/mode/current_state") != mode:
		_tree.set("parameters/mode/transition_request", mode)
	if _was_floor and not on_floor and vertical_speed > 1.0 and not seated:
		_tree.set("parameters/impulsion/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	_was_floor = on_floor
	var g := _gait(speed)
	_tree.set("parameters/loco/blend_position", g)
	_tree.set("parameters/echelle/scale", clampf(speed / _natural_speed(g), 0.5, 2.0) if g >= 1.0 else 1.0)
	var cn: float = _natural.get("Crouch_Fwd", 0.8) * (_skel.motion_scale if _skel else 1.0)
	_tree.set("parameters/accroupi/blend_position", clampf(speed / 0.5, 0.0, 1.0))
	_tree.set("parameters/echelle_accroupi/scale", clampf(speed / cn, 0.6, 1.8) if speed > 0.2 else 1.0)
	_tree.advance(delta)
	_overlay(delta)


func _overlay(delta: float) -> void:
	## Ajouts par-dessus l'animation : regard (tete 65 %, buste 30 %), respiration haletante, inclinaison en virage.
	_look = _look.lerp(Vector2(clampf(look_yaw, -1.2, 1.2), clampf(look_pitch, -0.4, 0.6)), 1.0 - exp(-5.0 * delta))
	var breath := sin(_t * (1.7 + 2.6 * essouffle)) * 0.035 * essouffle
	_turn_bone("Head", Vector3(-_look.y * 0.8, _look.x * 0.65, 0.0))
	_turn_bone("UpperChest", Vector3(breath, _look.x * 0.3, 0.0))
	var target := clampf(-turn_rate * speed * lean_per_turn, -0.35, 0.35) if on_floor and not seated else 0.0
	_lean = lerpf(_lean, target, 1.0 - exp(-4.0 * delta))
	rotation.z = _lean
	for end in ik_targets:
		if ik_targets[end] != Vector3.INF:
			var side: String = "Left" if end.begins_with("Left") else "Right"
			if end.ends_with("Hand"):
				_two_bone_ik(side + "UpperArm", side + "LowerArm", end, ik_targets[end])
			else:
				_two_bone_ik(side + "UpperLeg", side + "LowerLeg", end, ik_targets[end])


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


func _two_bone_ik(upper: String, lower: String, end: String, target_world: Vector3) -> void:
	## IK analytique a deux os (epaule-coude-main ou hanche-genou-pied) : le coude / genou garde son plan de flexion.
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
