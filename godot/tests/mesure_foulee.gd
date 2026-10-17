extends SceneTree
## Mesure des clips de locomotion captes (Mixamo) : deplacement du bassin sur un cycle (sur place ou non) et vitesse du
## pied d'appui (vitesse naturelle du clip, en m/s et en hauteurs de hanche / s), sur le personnage "homme".
## Lancement : godot --headless --path godot --script res://tests/mesure_foulee.gd

const CLIPS := ["MX_Marche", "MX_Marche_Femme", "MX_Marche_Standard", "MX_Trot", "MX_Course", "MX_Sprint", "Walk", "Jog_Fwd"]


var _f := 0


func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		_mesurer()
	return _f > 3


func _mesurer() -> void:
	var ch := PnjUtil.make("homme")
	root.add_child(ch)
	var skel := Squelette.find(ch)
	var ap := AnimationPlayer.new()
	ch.add_child(ap)
	ap.root_node = ap.get_path_to(ch)
	var anim_script := load("res://scripts/anim_ctrl.gd")
	anim_script.call("_load_libs")
	var libs: Dictionary = anim_script.get("_libs")
	for k in libs:
		ap.add_animation_library(k, libs[k])
	var hips := skel.find_bone("Hips")
	var lf := skel.find_bone("LeftFoot")
	var rf := skel.find_bone("RightFoot")
	var hip_h := skel.get_bone_global_rest(hips).origin.y
	for c in CLIPS:
		var full: String = anim_script.call("clip", c)
		if full == "":
			print(c, " : absent")
			continue
		ap.play(full)
		var a := ap.get_animation(full)
		var n := 60
		var prev := {}
		var vit: Array[float] = []
		var h0 := Vector3.ZERO
		var h1 := Vector3.ZERO
		for i in n + 1:
			ap.seek(a.length * i / n, true)
			skel.force_update_all_bone_transforms() if skel.has_method("force_update_all_bone_transforms") else null
			var hp := skel.get_bone_global_pose(hips).origin
			if i == 0:
				h0 = hp
			h1 = hp
			for b in [lf, rf]:
				var p := skel.get_bone_global_pose(b).origin - Vector3(hp.x, 0, hp.z)
				if prev.has(b) and p.y < 0.14:
					vit.append(Vector2(p.x - prev[b].x, p.z - prev[b].z).length() / (a.length / n))
				prev[b] = p
		vit.sort()
		var v := vit[vit.size() / 2] if vit.size() > 0 else 0.0
		print("%s : bassin %.2f m sur le cycle, pied d'appui %.2f m/s = %.2f hauteurs de hanche/s (hanche %.2f m, cycle %.2f s)" % [c, Vector2(h1.x - h0.x, h1.z - h0.z).length(), v, v / hip_h, hip_h, a.length])
	quit()
