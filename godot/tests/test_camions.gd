extends SceneTree
## Camions : presents dans la circulation (varietes de vehicules) et conduisibles par le joueur.

var frame := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 200:
		return false
	var modeles := {}
	for a in scene.get_node("Circulation")._agents:
		modeles[a["model"]] = int(modeles.get(a["model"], 0)) + 1
	print("modeles en circulation : ", modeles)
	var camions: int = modeles.get("veh_camion", 0)
	var v := Vehicules.create("veh_camion", Color(0.9, 0.9, 0.9))
	var ok: bool = camions > 0 and v != null and v.get("model_name") == "veh_camion"
	var longueur := 0.0
	if v:
		scene.add_child(v)
		for mi in v.find_children("*", "MeshInstance3D", true, false):
			longueur = maxf(longueur, (mi as MeshInstance3D).get_aabb().size.z)
	print("camions : %d, longueur du modele %.1f m, conduisible : %s" % [camions, longueur, v != null])
	print("RESULTAT test_camions : ", "OK" if ok and longueur > 6.0 else "ECHEC")
	quit(0 if ok else 1)
	return true
