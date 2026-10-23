extends SceneTree
## Plan d'eau : Carte.dans_eau reconnait les bassins / piscines et rejette la terre ferme.

func _init() -> void:
	var c := Carte.zone()
	var n := 0
	var ok := true
	for zn in c.data.get("zones", []):
		if zn["kind"] == "zone_eau" or zn["kind"] == "zone_piscine":
			n += 1
			var cx := 0.0
			var cz := 0.0
			for q in zn["pts"]:
				cx += float(q[0])
				cz += float(q[1])
			cx /= zn["pts"].size()
			cz /= zn["pts"].size()
			var poly := PackedVector2Array()
			for q in zn["pts"]:
				poly.append(Vector2(float(q[0]), float(q[1])))
			if Geometry2D.is_point_in_polygon(Vector2(cx, cz), poly) and not c.dans_eau(cx, cz):
				ok = false
	print("plans d'eau : ", n)
	var sec := not c.dans_eau(100000.0, 100000.0)
	print("hors zone : ", "ok" if sec else "ECHEC")
	print("RESULTAT test_eau : ", "OK" if ok and sec and n > 0 else "ECHEC")
	quit(0 if ok and sec and n > 0 else 1)
