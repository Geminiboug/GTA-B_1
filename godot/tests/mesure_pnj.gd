extends SceneTree
## Cout par image quand des passants (avec leur AnimCtrl) s'ajoutent a la scene : un de plus a chaque image, jusqu'a 40,
## puis des images de repos. Affiche la duree d'image et TIME_PROCESS tous les 5 passants.
## Lancement (avec fenetre) : godot --path godot --resolution 640x360 --script res://tests/mesure_pnj.gd [-- sans_anim]
const ANIM := preload("res://scripts/anim_ctrl.gd")
var rng := RandomNumberGenerator.new()
var frame := 0
var parent: Node3D
var garde := {}
var t_prec := 0
var avec_anim := true


func _initialize() -> void:
	rng.seed = 7
	avec_anim = not OS.get_cmdline_user_args().has("sans_anim")
	for v in PnjUtil.VARIANTS:
		garde[v] = load(PnjUtil.scene_path(v))
	parent = Node3D.new()
	root.add_child(parent)
	var cam := Camera3D.new()
	parent.add_child(cam)
	cam.position = Vector3(0, 1.5, 6)


func _process(_d: float) -> bool:
	frame += 1
	var t := Time.get_ticks_usec()
	var ms := (t - t_prec) / 1000.0
	t_prec = t
	if frame <= 40 and frame > 5:
		var ch := PnjUtil.make(PnjUtil.random_variant(rng, "femme", 0.0))
		if avec_anim:
			ch.set_script(ANIM)
		parent.add_child(ch)
		ch.position = Vector3((frame % 8) * 1.2 - 4.0, 0, -(frame / 8) * 1.5)
	if frame % 5 == 0 and frame > 5:
		print("image %d : %.0f ms, process %.0f ms, noeuds %d" % [frame, ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	if frame > 80:
		print("RESULTAT mesure_pnj OK")
		quit()
		return true
	return false
