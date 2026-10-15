extends SceneTree
## Clips Quaternius (redirigees par le profil humanoide) joues sur nos personnages : planche de poses a mi-clip.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_clips.gd -- <dossier> [variante] [clip...]

const LIBS := ["res://assets/animations/UAL1_RM.glb", "res://assets/animations/UAL2_RM.glb"]
var frame := 0
var out_dir := ""
var cam: Camera3D
var chars: Array[Node3D] = []
var clips: Array = ["Idle", "Walk", "Jog_Fwd", "Sprint", "Crouch_Fwd", "Jump", "Sitting_Idle", "Walk_Carry"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	var variant := args[1] if args.size() > 1 else "homme"
	if args.size() > 2:
		clips = Array(args.slice(2))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.74, 0.76)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(40), 0)
	root.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 28.0
	root.add_child(cam)
	cam.current = true
	# bibliotheques : on recupere les AnimationLibrary des deux fichiers
	var libs: Array[AnimationLibrary] = []
	for f in LIBS:
		var s: Node = (load(f) as PackedScene).instantiate()
		var ap := s.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		libs.append(ap.get_animation_library(ap.get_animation_library_list()[0]))
	for i in clips.size():
		var ch := PnjUtil.make(variant)
		root.add_child(ch)
		var rng := RandomNumberGenerator.new()
		rng.seed = 3 + i
		PnjUtil.dress_random(ch, rng)
		ch.scale = Vector3.ONE
		ch.position = Vector3(i * 1.1 - clips.size() * 0.55, 0, 0)
		var ap := AnimationPlayer.new()
		ch.add_child(ap)
		ap.root_node = NodePath("..")
		for k in libs.size():
			ap.add_animation_library("ual%d" % (k + 1), libs[k])
		var name := ""
		for k in libs.size():
			if libs[k].has_animation(clips[i]):
				name = "ual%d/%s" % [k + 1, clips[i]]
		if name != "":
			ap.play(name)
			ap.seek(ap.current_animation_length * 0.4, true)
			ap.pause()
		else:
			print("clip absent : ", clips[i])
		chars.append(ch)
	var sk := Squelette.find(chars[0])
	print("squelette : ", sk.name if sk else "?", " os : ", sk.get_bone_count() if sk else 0,
		" (", ", ".join(PackedStringArray([sk.get_bone_name(0), sk.get_bone_name(1), sk.get_bone_name(2)])) if sk else "", "...)")


func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		cam.position = Vector3(0, 1.2, 9.5)
		cam.look_at(Vector3(0, 0.85, 0), Vector3.UP)
	if frame == 20:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("clips.png"))
		print("capture clips")
		return true
	return false
