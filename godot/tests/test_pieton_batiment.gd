extends SceneTree
## Un passant poussé dans un batiment (fuite, chute, attroupement...) est ramene a sa position precedente.

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
	var c := Carte.zone()
	var w: Dictionary = {}
	for k in peds._walkers:
		if k["state"] == "walk" and not k.get("far", false):
			w = k
			break
	var dedans := Vector2.ZERO
	var dehors := Vector2.ZERO
	var trouve := false
	var base: Vector3 = w["pos"]
	for dz in range(-40, 41):
		for dx in range(-40, 41):
			var p := Vector2(base.x + dx, base.z + dz)
			if c.in_building(p) and not c.in_building(p + Vector2(-1, 0)) and c.in_bounds(p + Vector2(-1, 0)):
				dedans = p
				dehors = p + Vector2(-1, 0)
				trouve = true
				break
		if trouve:
			break
	if not trouve:
		print("RESULTAT test_pieton_batiment : ECHEC (pas de batiment proche)")
		quit(1)
		return true
	var avant := Vector3(dehors.x, base.y, dehors.y)
	w["pos"] = Vector3(dedans.x, base.y, dedans.y)
	peds._eviter(w, avant)
	var p2: Vector3 = w["pos"]
	var ok := not c.in_building(Vector2(p2.x, p2.z))
	print("position finale dans un batiment : ", not ok)
	print("RESULTAT test_pieton_batiment : ", "OK" if ok else "ECHEC")
	quit(0 if ok else 1)
	return true
