class_name Ragdoll
## Ragdoll (corps inerte qui tombe selon la physique) pour les chocs violents (pieton percute par un vehicule).
## Les corps physiques (PhysicalBone3D, capsules le long des os) sont crees au moment du choc puis retires : aucun cout
## tant que personne n'est renverse. Au plus max_actifs a la fois (les autres gardent la chute captee Death01).
## anim_ctrl.gd s'efface pendant la simulation (ragdoll = true) ; a la fin, le personnage se releve (LayToIdle).

const BONES := [
	# [os, os de bout (fin de la capsule), rayon (m), articulation]
	["Hips", "Spine", 0.12, "cone"], ["Spine", "UpperChest", 0.12, "cone"], ["UpperChest", "Neck", 0.13, "cone"],
	["Head", "", 0.1, "cone"],
	["LeftUpperArm", "LeftLowerArm", 0.05, "cone"], ["LeftLowerArm", "LeftHand", 0.045, "hinge"],
	["RightUpperArm", "RightLowerArm", 0.05, "cone"], ["RightLowerArm", "RightHand", 0.045, "hinge"],
	["LeftUpperLeg", "LeftLowerLeg", 0.075, "cone"], ["LeftLowerLeg", "LeftFoot", 0.055, "hinge"],
	["RightUpperLeg", "RightLowerLeg", 0.075, "cone"], ["RightLowerLeg", "RightFoot", 0.055, "hinge"],
]
const LAYER := 1 << 9          # couche propre aux ragdolls (ne gene ni le joueur ni la circulation)
const MAX_ACTIFS := 3

static var _actifs: Array = []


static func disponible() -> bool:
	_actifs = _actifs.filter(func(s: Variant) -> bool: return is_instance_valid(s))
	return _actifs.size() < MAX_ACTIFS


static func start(ch: Node3D, impulse: Vector3) -> PhysicalBoneSimulator3D:
	## Lance la chute physique du personnage ; impulsion (m/s) appliquee au bassin et au buste.
	var skel := Squelette.find(ch)
	if skel == null or not disponible():
		return null
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	skel.add_child(sim)
	for spec in BONES:
		var bi := skel.find_bone(spec[0])
		if bi < 0:
			continue
		var pb := PhysicalBone3D.new()
		pb.name = "pb_" + spec[0]
		pb.bone_name = spec[0]
		pb.collision_layer = LAYER
		pb.collision_mask = 1
		pb.mass = 8.0 if spec[0] in ["Hips", "Spine", "UpperChest"] else 3.0
		pb.friction = 0.9
		pb.linear_damp = 0.2
		pb.angular_damp = 1.5
		match spec[3]:
			"hinge":
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
			_:
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
		var bp := skel.get_bone_global_pose(bi)
		var a := bp.origin
		var e: Vector3 = a + bp.basis.y.normalized() * 0.22
		if String(spec[1]) != "":
			var ci := skel.find_bone(spec[1])
			if ci >= 0:
				e = skel.get_bone_global_pose(ci).origin
		var seg := e - a
		var length := maxf(seg.length(), 0.08)
		var cap := CapsuleShape3D.new()
		cap.radius = spec[2]
		cap.height = maxf(length + spec[2] * 0.6, spec[2] * 2.05)
		var cs := CollisionShape3D.new()
		cs.shape = cap
		# capsule dans le repere de l'os : axe Y vers l'os suivant, centree sur le segment
		var local_dir := bp.basis.inverse() * seg.normalized()
		var y := local_dir.normalized()
		var x := y.cross(Vector3.FORWARD) if absf(y.dot(Vector3.FORWARD)) < 0.9 else y.cross(Vector3.RIGHT)
		x = x.normalized()
		cs.transform = Transform3D(Basis(x, y, x.cross(y).normalized() * -1.0).orthonormalized(), bp.basis.inverse() * (seg * 0.5))
		pb.add_child(cs)
		sim.add_child(pb)
	ch.set("ragdoll", true)
	sim.physical_bones_start_simulation()
	for pb in sim.get_children():
		if pb is PhysicalBone3D:
			var k: float = 1.0 if String(pb.bone_name) in ["Hips", "Spine", "UpperChest"] else 0.7
			(pb as PhysicalBone3D).linear_velocity = impulse * k
	_actifs.append(sim)
	return sim


static func hips_position(sim: PhysicalBoneSimulator3D) -> Vector3:
	var hb := sim.get_node_or_null("pb_Hips") as Node3D
	return hb.global_position if hb else Vector3.INF


static func stop(ch: Node3D, sim: PhysicalBoneSimulator3D) -> void:
	## Fin de la chute : corps physiques retires, l'animation reprend la main (le personnage se releve).
	if sim and is_instance_valid(sim):
		sim.physical_bones_stop_simulation()
		sim.queue_free()
	ch.set("ragdoll", false)
