class_name Squelette
## Pilote les os d'un personnage (blender/tools/build_character.py) avec des angles exprimes dans le repere du
## personnage (comme les anciens pivots : rotation.x positive = membre vers l'avant), quelle que soit
## l'orientation des os dans le fichier.
## Squelette standard (noms Quaternius, renommes a l'import par le profil humanoide de Godot : Hips, Chest, Head,
## LeftUpperArm...) : les anciens noms (piv_tete, piv_epaule_G...) restent valables grace a ALIAS. Le modele regarde
## +Z dans son squelette (standard glTF) : les angles sont retournes, et la pose de repos des bras (en T apres
## l'import, "fix silhouette") est mesuree pour que les angles supposent toujours des bras pendants.

const A_POSE := deg_to_rad(12.0)      # ancien squelette : bras ecartes de 12 degres au repos
const ALIAS := {"piv_bassin": "Hips", "piv_tronc": "Chest", "piv_tete": "Head",
	"piv_epaule_G": "LeftUpperArm", "piv_coude_G": "LeftLowerArm", "piv_main_G": "LeftHand",
	"piv_hanche_G": "LeftUpperLeg", "piv_genou_G": "LeftLowerLeg", "piv_cheville_G": "LeftFoot",
	"piv_epaule_D": "RightUpperArm", "piv_coude_D": "RightLowerArm", "piv_main_D": "RightHand",
	"piv_hanche_D": "RightUpperLeg", "piv_genou_D": "RightLowerLeg", "piv_cheville_D": "RightFoot"}


static func find(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found[0] if found.size() > 0 else null


static func bone_name(skel: Skeleton3D, name: String) -> String:
	## Nom reel d'un os (accepte les anciens noms piv_*).
	if skel and skel.find_bone(name) < 0 and ALIAS.has(name):
		return ALIAS[name]
	return name


static func info(skel: Skeleton3D) -> Dictionary:
	## Pour chaque os : index, base du parent au repos (et son inverse), pose de repos. Cles speciales :
	## "_flip" (modele tourne vers +Z) et "_arm" (ecart des bras au repos, depuis la verticale).
	var out := {}
	for i in skel.get_bone_count():
		var parent := skel.get_bone_parent(i)
		var pb := skel.get_bone_global_rest(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
		out[skel.get_bone_name(i)] = {"idx": i, "p": pb, "pinv": pb.inverse(), "rest": skel.get_bone_rest(i)}
	var standard := skel.find_bone("Hips") >= 0
	for old in ALIAS:
		if out.has(ALIAS[old]):
			out[old] = out[ALIAS[old]]
	out["_flip"] = standard
	out["_arm"] = A_POSE
	if standard:
		var ua := skel.find_bone("LeftUpperArm")
		var la := skel.find_bone("LeftLowerArm")
		if ua >= 0 and la >= 0:
			var d := (skel.get_bone_global_rest(la).origin - skel.get_bone_global_rest(ua).origin).normalized()
			out["_arm"] = acos(clampf(d.dot(Vector3.DOWN), -1.0, 1.0))
	return out


static func apply(skel: Skeleton3D, inf: Dictionary, bone: String, euler: Vector3, offset := Vector3.ZERO) -> void:
	## euler : rotation (repere du personnage) autour de la tete de l'os ; offset : deplacement (repere du personnage).
	var b: Dictionary = inf.get(bone, {})
	if b.is_empty():
		return
	var r := Basis.from_euler(euler)
	# avant-bras et main : les angles supposent un bras pendant ; au repos le bras est ecarte (en T apres l'import) :
	# l'axe de flexion du coude suit le bras ramene le long du corps (sinon la flexion devient une torsion)
	if bone.begins_with("piv_coude_") or bone.begins_with("piv_main_"):
		var c := Basis(Vector3.BACK, inf.get("_arm", A_POSE) * (1.0 if bone.ends_with("G") else -1.0))
		r = c.inverse() * r * c
	if inf.get("_flip", false):
		var turn := Basis(Vector3.UP, PI)
		r = turn * r * turn.inverse()
		offset = Vector3(-offset.x, offset.y, -offset.z)
	var pinv: Basis = b["pinv"]
	var rp: Basis = pinv * r * (b["p"] as Basis)
	var rest: Transform3D = b["rest"]
	skel.set_bone_pose_rotation(b["idx"], (rp * rest.basis).get_rotation_quaternion())
	skel.set_bone_pose_position(b["idx"], rest.origin + pinv * offset)


static func arm_rest(euler: Vector3, side: String, arm := A_POSE) -> Vector3:
	## Les angles d'animation supposent des bras pendants : on retire l'ecart des bras au repos.
	return euler + Vector3(0, 0, arm if side == "G" else -arm)


static func pose(root: Node, angles: Dictionary) -> void:
	## Pose fixe (vendeur assis, conducteur...) : angles = {nom d'os : rotation.x}.
	var skel := find(root)
	if skel == null:
		return
	var inf := info(skel)
	for bone in ALIAS:
		if not inf.has(bone):
			continue
		var e := Vector3(angles.get(bone, 0.0), 0, 0)
		if bone.begins_with("piv_epaule_"):
			e = arm_rest(e + Vector3(0, 0, -0.07 if bone.ends_with("G") else 0.07), bone.right(1), inf["_arm"])
		apply(skel, inf, bone, e)
	skel.force_update_all_bone_transforms()


static func ik_deux_os(skel: Skeleton3D, haut: String, bas: String, bout: String, cible_monde: Vector3, pole_monde := Vector3.ZERO) -> void:
	## IK analytique a deux os sur un squelette fige (conducteur de moto : mains au guidon, pieds aux repose-pieds). Meme
	## calcul que anim_ctrl._two_bone_ik, sans animation : le coude / genou pointe vers pole_monde s'il est donne.
	var iu := skel.find_bone(haut)
	var il := skel.find_bone(bas)
	var ie := skel.find_bone(bout)
	if iu < 0 or il < 0 or ie < 0:
		return
	var t := skel.global_transform.affine_inverse() * cible_monde
	var gu := skel.get_bone_global_pose(iu)
	var gl := skel.get_bone_global_pose(il)
	var ge := skel.get_bone_global_pose(ie)
	var a := gu.origin
	var b := gl.origin
	var c := ge.origin
	var l1 := (b - a).length()
	var l2 := (c - b).length()
	var to_t := t - a
	var d := clampf(to_t.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	var dir := to_t.normalized()
	var pole := (b - a) - dir * (b - a).dot(dir)
	if pole_monde != Vector3.ZERO:
		var pw := skel.global_transform.basis.inverse() * pole_monde
		pole = pw - dir * pw.dot(dir)
	if pole.length() < 1e-4:
		pole = Vector3.UP.cross(dir) if absf(dir.y) < 0.9 else Vector3.RIGHT
	pole = pole.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var b2 := a + dir * (l1 * cos_a) + pole * (l1 * sqrt(1.0 - cos_a * cos_a))
	var r1 := Quaternion((b - a).normalized(), (b2 - a).normalized())
	var parent := skel.get_bone_parent(iu)
	var pu := skel.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	var new_gu := r1 * gu.basis.get_rotation_quaternion()
	var lu := (pu.inverse() * new_gu).normalized()
	skel.set_bone_pose_rotation(iu, lu)
	var gl2 := skel.get_bone_global_pose(il)
	var ge2 := skel.get_bone_global_pose(ie)
	var r2 := Quaternion((ge2.origin - gl2.origin).normalized(), (a + dir * d - gl2.origin).normalized())
	var ll := (new_gu.inverse() * (r2 * gl2.basis.get_rotation_quaternion())).normalized()
	skel.set_bone_pose_rotation(il, ll)


static func poser_sur_moto(personnage: Node, moto: Node3D) -> void:
	## Mains aux deux poignees du guidon et pieds sur les repose-pieds de la moto (nœuds poignee_-1 / poignee_1,
	## cale_pied_-1 / cale_pied_1 du modele), coudes et genoux vers l'exterieur. A appeler apres PnjUtil.pose_seated.
	var skel := find(personnage)
	if skel == null:
		return
	skel.force_update_all_bone_transforms()
	var cote := {"Left": -1, "Right": 1}
	for s in cote:
		var poignee := moto.find_child("poignee_%d" % cote[s], true, false) as Node3D
		var cale := moto.find_child("cale_pied_%d" % cote[s], true, false) as Node3D
		var ext: Vector3 = moto.global_transform.basis.x * float(cote[s])          # vers l exterieur de la moto
		var avant: Vector3 = -moto.global_transform.basis.z
		if poignee:
			ik_deux_os(skel, s + "UpperArm", s + "LowerArm", s + "Hand", poignee.global_position, ext + Vector3.DOWN * 0.3)
		if cale:
			ik_deux_os(skel, s + "UpperLeg", s + "LowerLeg", s + "Foot", cale.global_position + Vector3.UP * 0.05, ext + avant * 0.3)
	skel.force_update_all_bone_transforms()
