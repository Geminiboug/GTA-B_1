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
