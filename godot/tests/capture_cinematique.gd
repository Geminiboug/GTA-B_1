extends SceneTree
## Capture : premiere conversation avec tante Mireille en cinematique (plan par-dessus l'epaule, bandes, sous-titre).
var frame := 0
var scene: Node
var out := ""
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		root.get_node("Partie").nouvelle_partie()
		scene.get_node("JourNuit").set("hour", 9.0)
	if frame == 150:
		var pl: Node3D = scene.get_node("Player")
		var peds := scene.get_node("Pietons")
		var w: Dictionary = peds._walkers[0]
		var n: Node3D = w["node"]
		w["pos"] = pl.global_position + Vector3(0, 0, -1.6)
		w["state"] = "angry"
		w["state_t"] = 0.0
		n.global_position = w["pos"]
		var ci := scene.get_node("Cinematique")
		ci.cadrer(n, pl)
		ci.sous_titre("Tante Mireille", "Ah, te voilà enfin ! Va me chercher du pain chez la vendeuse, devant le portail.", 5.0)
	if frame == 220:
		root.get_viewport().get_texture().get_image().save_png(out.path_join("cinematique.png"))
		quit()
		return true
	return false
