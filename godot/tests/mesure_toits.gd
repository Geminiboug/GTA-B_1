extends SceneTree
## Ecart entre la hauteur de toit des donnees (bld["h"], utilisee pour poser citernes, fers et paraboles) et le dessus reel
## du batiment (lancer de rayon vers le bas) : un ecart positif = objet qui flotte.
## Lancement : godot --headless --path godot -s res://tests/mesure_toits.gd
var frame := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 150:
		return false
	var carte := Carte.zone()
	var p: Vector3 = scene.get_node("Player").global_position
	var space := (root.get_world_3d() as World3D).direct_space_state
	var n := 0
	var ecarts: Array = []
	for b in carte.data["buildings"]:
		if String(b.get("roof", "")) != "plat":
			continue
		var h := float(b.get("h", 0.0))
		if h < 2.8 or h > 14.0:
			continue
		var pts: Array = b["pts"]
		var c := Vector2.ZERO
		for q in pts:
			c += Vector2(float(q[0]), float(q[1]))
		c /= pts.size()
		if Vector2(p.x, p.z).distance_to(c) > 250.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, 40.0, c.y), Vector3(c.x, -5.0, c.y))
		var r := space.intersect_ray(q)
		if r.is_empty():
			continue
		ecarts.append(h - float(r["position"].y))
		n += 1
		if n <= 25:
			print("batiment %s h=%.2f toit reel=%.2f ecart=%.2f" % [b.get("id", "?"), h, r["position"].y, h - r["position"].y])
	var moy := 0.0
	for e in ecarts:
		moy += e
	print("RESULTAT mesure_toits : %d toits, ecart moyen %.2f m" % [ecarts.size(), moy / maxf(ecarts.size(), 1)])
	quit()
	return true
