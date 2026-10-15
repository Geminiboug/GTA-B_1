extends SceneTree
## Inventaire des bibliotheques d'animations (squelette, clips, duree, root motion).


func _initialize() -> void:
	for f in ["res://assets/animations/UAL1_RM.glb", "res://assets/animations/UAL2_RM.glb"]:
		var s: Node = (load(f) as PackedScene).instantiate()
		var sk := s.find_children("*", "Skeleton3D", true, false)
		print("## ", f, " squelettes : ", sk.size())
		if sk.size() > 0:
			var k := sk[0] as Skeleton3D
			var names := PackedStringArray()
			for i in k.get_bone_count():
				names.append(k.get_bone_name(i))
			print("  os (", k.get_bone_count(), ") : ", ", ".join(names))
		var ap := s.find_children("*", "AnimationPlayer", true, false)
		if ap.size() > 0:
			var p := ap[0] as AnimationPlayer
			var out := PackedStringArray()
			for a in p.get_animation_list():
				out.append("%s(%.1fs)" % [a, p.get_animation(a).length])
			print("  clips (", out.size(), ") : ", ", ".join(out))
	quit()
