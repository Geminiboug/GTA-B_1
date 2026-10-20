extends SceneTree
## Mesure du debut de partie reel (avec fenetre) : ecran de chargement, ecran titre quelques secondes, "Nouvelle
## partie", puis 30 s de jeu ; Partie journalise les images trop longues (saccades) apres l'ecran titre.
## Avec l'argument "coupable" : ensuite, chaque systeme de la zone est mis en pause 4 s a tour de role et on compte les
## images de plus de 80 ms (le systeme qui fait disparaitre les saccades est le coupable).
## Lancement : godot --path godot -s res://tests/bench_debut_partie.gd [-- coupable]
var ch: Node
var t_fini := -1.0
var t := 0.0
var lance := false
var coupable := false
var enfants: Array = []
var ei := -1
var t_e := 0.0
var lentes := 0
var base := -1


var g_som := 0.0
var g_n := 0


func _gpu(d: float) -> bool:
	## Juste apres "Nouvelle partie" : chaque systeme est cache 1 s a tour de role (une seconde de reference entre deux),
	## temps GPU moyen de chaque seconde.
	if not lance or t < t_fini + 4.5:
		return false
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	if ei == -1:
		for n in root.get_children():
			if n.has_node("Player"):
				enfants = n.get_children().filter(func(c): return c is Node3D)
		ei = 0
		t_e = 0.0
	t_e += d
	g_som += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	g_n += 1
	if t_e > 1.0:
		var k := ei / 2
		var nom := "reference" if ei % 2 == 0 else "sans " + String(enfants[k].name)
		print("  %s : gpu %.0f ms" % [nom, g_som / g_n])
		if ei % 2 == 1:
			(enfants[k] as Node3D).visible = true
		ei += 1
		if ei / 2 >= enfants.size():
			return true
		if ei % 2 == 1:
			(enfants[ei / 2] as Node3D).visible = false
		t_e = 0.0
		g_som = 0.0
		g_n = 0
	return false


func _initialize() -> void:
	coupable = "coupable" in OS.get_cmdline_user_args()
	ch = (load("res://scenes/chargement.tscn") as PackedScene).instantiate()
	root.add_child(ch)
	current_scene = ch


func _process(d: float) -> bool:
	t += d
	if t_fini < 0.0:
		if not is_instance_valid(ch) or ch.get("etape") in ["fini", "erreur"]:
			t_fini = t
		return t > 300.0
	if not lance and t > t_fini + 4.0:
		lance = true
		for m in root.find_children("*", "", true, false):
			if m.get_script() and (m.get_script() as Script).resource_path.ends_with("menus.gd") and m.call("is_open"):
				m.call("_nouvelle_partie")
				print("Nouvelle partie lancee")
				break
	if "gpu" in OS.get_cmdline_user_args():
		return _gpu(d)
	if not coupable:
		return lance and t > t_fini + 55.0
	if not lance or t < t_fini + 40.0:
		return false
	if ei == -1:
		var zone: Node = current_scene
		for n in root.get_children():
			if n.has_node("Player"):
				zone = n
		enfants = zone.get_children().filter(func(n): return n.has_method("_process") or n.has_method("_physics_process") or n.get_child_count() > 0)
		ei = 0
		t_e = 0.0
		lentes = 0
		return false
	t_e += d
	if d > 0.08:
		lentes += 1
	if t_e > 4.0:
		var nom := "aucun (reference)" if base < 0 else String(enfants[ei].name)
		print("  sans %s : %d images > 80 ms" % [nom, lentes])
		if base < 0:
			base = lentes
		else:
			enfants[ei].process_mode = Node.PROCESS_MODE_INHERIT
			ei += 1
		if ei >= enfants.size():
			return true
		enfants[ei].process_mode = Node.PROCESS_MODE_DISABLED
		t_e = 0.0
		lentes = 0
	return false
