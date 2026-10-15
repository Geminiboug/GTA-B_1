class_name Squelette
## Pilote les os d'un personnage (blender/tools/build_character.py) avec des angles exprimes dans le repere du
## personnage (comme les anciens pivots : rotation.x positive = membre vers l'avant), quelle que soit
## l'orientation des os dans le fichier. Pose de repos en "A" : bras ecartes de 12 degres (compense ici).

const A_POSE := deg_to_rad(12.0)


static func find(root: Node) -> Skeleton3D:
	var found := root.find_children("*", "Skeleton3D", true, false)
	return found[0] if found.size() > 0 else null


static func info(skel: Skeleton3D) -> Dictionary:
	## Pour chaque os : index, base du parent au repos (et son inverse), pose de repos.
	var out := {}
	for i in skel.get_bone_count():
		var parent := skel.get_bone_parent(i)
		var pb := skel.get_bone_global_rest(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
		out[skel.get_bone_name(i)] = {"idx": i, "p": pb, "pinv": pb.inverse(), "rest": skel.get_bone_rest(i)}
	return out


static func apply(skel: Skeleton3D, inf: Dictionary, bone: String, euler: Vector3, offset := Vector3.ZERO) -> void:
	## euler : rotation (repere du personnage) autour de la tete de l'os ; offset : deplacement (repere du personnage).
	var b: Dictionary = inf.get(bone, {})
	if b.is_empty():
		return
	var r := Basis.from_euler(euler)
	var pinv: Basis = b["pinv"]
	var rp: Basis = pinv * r * (b["p"] as Basis)
	var rest: Transform3D = b["rest"]
	skel.set_bone_pose_rotation(b["idx"], (rp * rest.basis).get_rotation_quaternion())
	skel.set_bone_pose_position(b["idx"], rest.origin + pinv * offset)


static func arm_rest(euler: Vector3, side: String) -> Vector3:
	## Les angles d'animation supposent des bras pendants : on retire l'ecart de la pose en "A".
	return euler + Vector3(0, 0, A_POSE if side == "G" else -A_POSE)


static func pose(root: Node, angles: Dictionary) -> void:
	## Pose fixe (vendeur assis, conducteur...) : angles = {nom d'os : rotation.x}.
	var skel := find(root)
	if skel == null:
		return
	var inf := info(skel)
	for bone in inf:
		var e := Vector3(angles.get(bone, 0.0), 0, 0)
		if bone.begins_with("piv_epaule_"):
			e = arm_rest(e + Vector3(0, 0, -0.07 if bone.ends_with("G") else 0.07), bone.right(1))
		apply(skel, inf, bone, e)
	skel.force_update_all_bone_transforms()
