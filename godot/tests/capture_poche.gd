extends SceneTree
## Captures d'un personnage qui joue un clip d'attente puis le quitte : verifie les mains (poches, deformations).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_poche.gd -- <dossier> <clip>
var frame := 0
var scene: Node
var out_dir := "user://"
var clip := "MX_Idle_Appui"
var ch: Node3D
var cam: Camera3D


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	if a.size() > 1:
		clip = a[1]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _snap(nom: String) -> void:
	root.get_viewport().get_texture().get_image().save_png("%s/poche_%s_%s.png" % [out_dir, clip, nom])


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 100:
		(scene.get_node("Player") as Node3D).global_position = Vector3(25, 1, 6)
		ch = PnjUtil.make("homme", false)
		ch.set_script(preload("res://scripts/anim_ctrl.gd"))
		scene.add_child(ch)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		PnjUtil.apply(ch, PnjUtil.random_look(ch, rng, ""))
		ch.global_position = Vector3(43.7, 0.0, 6.0)
		ch.rotation.y = PI * 0.5
		cam = Camera3D.new()
		scene.add_child(cam)
		cam.global_position = Vector3(43.7 + 2.6, 1.3, 6.0 + 0.3)
		cam.look_at(Vector3(43.7, 1.0, 6.0))
		cam.current = true
		var an: Node = ch
		print("DBG methodes: ", an.has_method("play_clips"), " ", ch.get_class())
	if frame == 110 and ch.has_method("play_clips"):
		ch.play_clips([[clip, 8.0]], true)
	if frame == 160:
		_snap("a")
	if frame == 220:
		_snap("b")
	if frame == 260 and ch.has_method("stop_clips"):
		ch.stop_clips()
	if frame == 268:
		_snap("sortie1")
	if frame == 276:
		_snap("sortie2")
	if frame == 290:
		_snap("sortie3")
	if frame == 300:
		quit()
		return true
	return false
