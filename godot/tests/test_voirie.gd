extends SceneTree
## Rien sur la chaussee : murs (OSM et concessions generees) et batiments ne mordent pas sur la route visible.
## Chaque bord est echantillonne tous les 0,5 m ; un point est en faute s'il tombe sur une surface de route
## (rayon vertical sur la couche des surfaces a eviter, collisionneurs "route_*") a plus de `tolerance` m du bord.
## Lancement : godot --headless --path godot --script res://tests/test_voirie.gd [-- liste]

const AVOID_LAYER := 1 << 9
@export var tolerance := 0.3

var frame := 0
var scene: Node
var fails := 0
var liste := false


func _initialize() -> void:
	liste = "liste" in OS.get_cmdline_user_args()
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _on_road(p: Vector2) -> String:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 5, p.y), Vector3(p.x, -2, p.y))
	q.collision_mask = AVOID_LAYER
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ""
	var n := String(hit["collider"].name)
	return n if n.begins_with("route_") and not n.contains("footway") and not n.contains("path") else ""


func _seg_faults(a: Vector2, b: Vector2) -> Array:
	## Points du segment sur la chaussee (en retrait de `tolerance` aux extremites).
	var out := []
	var l := a.distance_to(b)
	if l < 2.0 * tolerance:
		return out
	var n := int(l / 0.5) + 1
	for k in n + 1:
		var p := a.lerp(b, tolerance / l + (1.0 - 2.0 * tolerance / l) * float(k) / n)
		var r := _on_road(p)
		if r != "":
			out.append([p, r])
	return out


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 40:
		return false
	var f := FileAccess.open("res://assets/data/zone_aeroport.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var bad_walls := []
	for w in data.get("walls", []):
		var pts: Array = w["pts"] if w is Dictionary else (w as Array)
		for i in pts.size() - 1:
			var fl := _seg_faults(Vector2(pts[i][0], pts[i][1]), Vector2(pts[i + 1][0], pts[i + 1][1]))
			if fl.size() > 0:
				bad_walls.append(fl[0])
	var bad_bld := []
	for b in data["buildings"]:
		var pts: Array = b["pts"]
		var faults := 0
		var first: Array = []
		for i in pts.size():
			var j := (i + 1) % pts.size()
			var fl := _seg_faults(Vector2(pts[i][0], pts[i][1]), Vector2(pts[j][0], pts[j][1]))
			faults += fl.size()
			if first.is_empty() and fl.size() > 0:
				first = fl[0]
		if faults > 0:
			bad_bld.append(first)
	var bad_conc := []
	var conc := scene.get_node_or_null("Concessions")
	if conc:
		for r in conc.get("_rects"):
			for i in 4:
				var su := [-1, 1, 1, -1]
				var sv := [-1, -1, 1, 1]
				var a: Vector2 = conc._corner(r, su[i], sv[i])
				var b: Vector2 = conc._corner(r, su[(i + 1) % 4], sv[(i + 1) % 4])
				var fl := _seg_faults(a, b)
				if fl.size() > 0:
					bad_conc.append(fl[0])
					break
	if liste:
		for e in bad_walls + bad_bld + bad_conc:
			print("  ", e[0], "  ", e[1])
	_check(bad_walls.is_empty(), "murs OSM hors chaussee (%d en faute)" % bad_walls.size())
	_check(bad_bld.is_empty(), "batiments hors chaussee (%d en faute)" % bad_bld.size())
	_check(bad_conc.is_empty(), "concessions generees hors chaussee (%d en faute)" % bad_conc.size())
	print("RESULTAT test_voirie : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
