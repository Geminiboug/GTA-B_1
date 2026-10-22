extends SceneTree
## Cherche les clips ou une main se retrouve pres de la poche (cote du bassin, sous la ceinture) : position des deux mains
## par rapport au bassin, dans le repere du personnage, a 1 s de chaque clip joue. Sert a trouver le clip "mains dans les
## poches" dont la sortie deforme la main (retour d'Olympe du 22/10/2026).
## Lancement : godot --headless --path godot --script res://tests/analyse_poches.gd

var frame := 0
var scene: Node
var ch: Node3D
var skel: Skeleton3D
var clips: Array = []
var k := 0
var t0 := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _pos(os: String, ref: String) -> Vector3:
	var a := skel.get_bone_global_pose(skel.find_bone(os)).origin
	var r := skel.get_bone_global_pose(skel.find_bone(ref)).origin
	return a - r


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 100:
		(scene.get_node("Player") as Node3D).global_position = Vector3(25, 1, 6)
		ch = PnjUtil.make("homme", false)
		ch.set_script(preload("res://scripts/anim_ctrl.gd"))
		scene.add_child(ch)
		ch.global_position = Vector3(43.7, 0.0, 6.0)
		skel = Squelette.find(ch) as Skeleton3D
		for lib in ch.get_script().get("_libs").values():
			for n in (lib as AnimationLibrary).get_animation_list():
				clips.append(String(n))
		clips.sort()
		print("clips : ", clips.size())
		t0 = frame + 5
	if frame < 110 or clips.is_empty():
		return false
	if k >= clips.size():
		quit()
		return true
	var cl: String = clips[k]
	if frame == t0:
		ch.play_clips([[cl, 3.0]], true)
	if frame == t0 + 30:
		var lh := _pos("LeftHand", "Hips")
		var rh := _pos("RightHand", "Hips")
		# repere du squelette : +Z devant, +Y haut, X lateral ; la poche : cote (|x| 0.12 a 0.32), sous le bassin (y -0.35 a +0.05)
		var poche := false
		for h in [lh, rh]:
			if absf(h.x) > 0.1 and absf(h.x) < 0.34 and h.y < 0.08 and h.y > -0.4 and absf(h.z) < 0.18:
				poche = true
		if poche:
			print("POCHE ? %s : main G %s main D %s" % [cl, lh, rh])
		k += 1
		t0 = frame + 3
	return false
