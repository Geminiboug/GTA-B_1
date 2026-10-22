extends SceneTree
## Liste les enfants directs de la scene du jeu avec leur script et le nombre de noeuds (pour trouver ce qui coute en _process).
## Lancement : godot --headless --path godot -s res://tests/liste_noeuds.gd
var frame := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 30:
		return false
	for n in scene.get_children():
		var s: Script = n.get_script()
		print("NOEUD %-22s %-40s noeuds=%d process=%s" % [n.name, s.resource_path if s else "-", n.find_children("*", "", true, false).size(), n.is_processing()])
	quit()
	return true
