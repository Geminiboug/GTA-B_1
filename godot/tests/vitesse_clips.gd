extends SceneTree
## Vitesse naturelle des clips de deplacement (root motion de la piste Root) : base du calage pieds / vitesse.


func _initialize() -> void:
	for f in ["res://assets/animations/UAL1_RM.glb", "res://assets/animations/UAL2_RM.glb"]:
		var s: Node = (load(f) as PackedScene).instantiate()
		var ap := s.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for n in ap.get_animation_list():
			var a := ap.get_animation(n)
			var t := a.find_track(NodePath("%GeneralSkeleton:Root"), Animation.TYPE_POSITION_3D)
			if t < 0:
				continue
			var p0: Vector3 = a.position_track_interpolate(t, 0.0)
			var p1: Vector3 = a.position_track_interpolate(t, a.length)
			var d := p1 - p0
			if d.length() > 0.05:
				print("%-18s %.2f s  deplacement %s  vitesse %.2f m/s  boucle %s" % [n, a.length, d.snapped(Vector3.ONE * 0.01), d.length() / a.length, a.loop_mode])
	quit()
