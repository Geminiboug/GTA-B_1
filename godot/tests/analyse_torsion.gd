extends SceneTree
## Torsion (rotation autour de l'axe de l'os) des bras dans chaque clip : un avant-bras ou une main tordus de plus de ~60 degres
## par rapport a leur parent plissent le maillage ("papillote", retour d'Olympe du 22/10/2026 : main levee deformee).
## Lancement : godot --headless --path godot --script res://tests/analyse_torsion.gd
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


func _twist(bone: String) -> float:
	var q := skel.get_bone_pose_rotation(skel.find_bone(bone))
	return rad_to_deg(2.0 * atan2(q.y, q.w)) if absf(q.w) > 1e-6 or absf(q.y) > 1e-6 else 0.0


func _norm(a: float) -> float:
	return fposmod(a + 180.0, 360.0) - 180.0


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
		var s := ""
		for side in ["Left", "Right"]:
			s += " %s: haut %.0f avant %.0f main %.0f |" % [side, _norm(_twist(side + "UpperArm")), _norm(_twist(side + "LowerArm")), _norm(_twist(side + "Hand"))]
		print("TORSION %s :%s" % [cl, s])
		k += 1
		t0 = frame + 3
	return false
