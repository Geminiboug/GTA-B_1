extends SceneTree
## Mesure du chargement reel (avec fenetre) : ecran de chargement puis mise en place, jusqu'a "fini".
## Lancement : godot --path godot -s res://tests/bench_chargement.gd
var ch: Node
func _initialize() -> void:
	ch = (load("res://scenes/chargement.tscn") as PackedScene).instantiate()
	ch.set("journal_ecarts", true)
	root.add_child(ch)
	current_scene = ch
func _process(_d: float) -> bool:
	return not is_instance_valid(ch) or ch.get("etape") in ["fini", "erreur"]
