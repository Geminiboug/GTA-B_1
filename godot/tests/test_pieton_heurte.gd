extends SceneTree
## Un vehicule de la circulation qui roule sur un passant le renverse et lui retire des points de vie.

var frame := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 180:
		return false
	var peds := scene.get_node("Pietons")
	var traf := scene.get_node("Circulation")
	var player := scene.get_node("Player") as Node3D
	var w: Dictionary = {}
	for c in peds._walkers:
		if c["state"] == "walk" and not c.get("far", false) and not c.has("chaise"):
			w = c
			break
	var car: Dictionary = {}
	for a in traf._agents:
		if a["kind"] == "voiture":
			car = a
			break
	if w.is_empty() or car.is_empty():
		print("ECHEC pas de passant ou de voiture")
		print("RESULTAT test_pieton_heurte : ECHEC")
		quit(1)
		return true
	var me: Vector3 = w["pos"]
	player.global_position = me + Vector3(5, 0.5, 0)
	car["vis_pos"] = me + Vector3(0, 0, 1.5)   # le passant est 1,5 m devant le pare-chocs (la voiture regarde -Z)
	car["vis_yaw"] = 0.0
	car["speed"] = 8.0
	var pv0: float = w["pv"]
	peds._trafic_heurte(player.global_position)
	var ok: bool = w["state"] == "down" and float(w["pv"]) < pv0
	print("etat %s, pv %.0f -> %.0f, vitesse voiture %.1f" % [w["state"], pv0, w["pv"], car["speed"]])
	print("RESULTAT test_pieton_heurte : ", "OK" if ok else "ECHEC")
	quit(0 if ok else 1)
	return true
