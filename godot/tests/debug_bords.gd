extends SceneTree
## Debug : ce qui se trouve de part et d'autre des grands axes (surfaces a eviter, couche 10).

var frame := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _hit(space: PhysicsDirectSpaceState3D, p: Vector2) -> String:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, 5, p.y), Vector3(p.x, -2, p.y))
	ray.collision_mask = 1 << 9
	var h := space.intersect_ray(ray)
	return "-" if h.is_empty() else "%s@%.2f" % [h.collider.name, h.position.y]


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame < 4:
		return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/zone_aeroport.json"))
	var space: PhysicsDirectSpaceState3D = (scene as Node3D).get_world_3d().direct_space_state
	var shown := 0
	for r in data["roads"]:
		if r["kind"] != "secondary" or shown >= 6:
			continue
		var pts: Array = r["pts"]
		var a := Vector2(pts[0][0], pts[0][1])
		var b := Vector2(pts[1][0], pts[1][1])
		var t := (b - a).normalized()
		var n := Vector2(-t.y, t.x)
		var w: float = r["width"]
		var m := a.lerp(b, 0.5)
		print("DBG route ", r["name"], " w=", w, " oneway=", r["oneway"], " centre=", _hit(space, m),
			" +", _hit(space, m + n * (w / 2.0 + 1.4)), " -", _hit(space, m - n * (w / 2.0 + 1.4)),
			" +12:", _hit(space, m + n * 12.0), " -12:", _hit(space, m - n * 12.0))
		shown += 1
	return true
