extends SceneTree
## Calibrage des clips de deplacement : vitesse a laquelle le pied d'appui recule par rapport au corps (m/s, homme
## de reference), mesuree en jouant le clip sur notre personnage. Sert de vitesse naturelle dans anim_ctrl.gd.

const CLIPS := ["Walk", "Jog_Fwd", "Sprint", "Crouch_Fwd", "Walk_Carry"]


var frame := 0


func _process(_d: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	_run()
	return true


func _run() -> void:
	var ch := PnjUtil.make("homme")
	root.add_child(ch)
	var skel := Squelette.find(ch)
	var ap := AnimationPlayer.new()
	ch.add_child(ap)
	ap.root_node = NodePath("..")
	for f in ["res://assets/animations/UAL1_RM.glb", "res://assets/animations/UAL2_RM.glb"]:
		var s: Node = (load(f) as PackedScene).instantiate()
		var src := s.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		ap.add_animation_library(f.get_file().get_basename(), src.get_animation_library(src.get_animation_library_list()[0]))
	var rootb := skel.find_bone("Root")
	for c in CLIPS:
		var name := ""
		for lib in ap.get_animation_library_list():
			if ap.get_animation_library(lib).has_animation(c):
				name = "%s/%s" % [lib, c]
		if name == "":
			continue
		ap.play(name)
		var length := ap.current_animation_length
		var dt := 1.0 / 120.0
		var prev := {}
		var sum := 0.0
		var n := 0
		var ground := INF
		for pass_i in 2:
			var t := 0.0
			while t < length:
				ap.seek(t, true)
				skel.force_update_all_bone_transforms()
				var r := skel.get_bone_global_pose(rootb).origin
				for side in ["Left", "Right"]:
					var a := skel.get_bone_global_pose(skel.find_bone(side + "Foot")).origin - r
					var b := skel.get_bone_global_pose(skel.find_bone(side + "Toes")).origin - r
					var p := a if a.y < b.y else b
					ground = minf(ground, p.y)
					if pass_i == 1 and prev.has(side):
						var q: Vector3 = prev[side]
						if p.y < ground + 0.05 and absf(p.y - q.y) / dt < 0.4:
							sum += Vector2(p.x - q.x, p.z - q.z).length() / dt
							n += 1
					prev[side] = p
				t += dt
		print("%-12s pied d'appui %.2f m/s (echantillons %d)" % [c, sum / maxf(n, 1), n])

