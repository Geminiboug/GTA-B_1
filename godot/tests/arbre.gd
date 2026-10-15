extends SceneTree
## Affiche l'arbre des noeuds d'une scene importee (chemins relatifs a la racine), pour regler les imports.


func _walk(n: Node, root: Node, depth: int) -> void:
	if depth > 3:
		return
	print("  ", root.get_path_to(n), " [", n.get_class(), "]")
	for c in n.get_children():
		_walk(c, root, depth + 1)


func _initialize() -> void:
	for f in OS.get_cmdline_user_args():
		var s: Node = (load(f) as PackedScene).instantiate()
		print("## ", f)
		for c in s.get_children():
			_walk(c, s, 1)
	quit()
