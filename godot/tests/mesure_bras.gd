extends SceneTree
## Ecart des bras par rapport au corps, a l'arret et en marche : angle entre le bras (epaule -> coude) et la verticale du corps.
var frame := 0
var scene: Node
var pl: Node


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _angles() -> String:
	var sk := Squelette.find(pl.get_node("Body/Model")) as Skeleton3D
	var out := ""
	for cote in ["l", "r"]:
		var up := sk.find_bone("upperarm_" + cote)
		var lo := sk.find_bone("lowerarm_" + cote)
		if up < 0 or lo < 0:
			up = sk.find_bone("mixamorig_Arm" if cote == "l" else "mixamorig_RightArm")
		var a := (sk.global_transform * sk.get_bone_global_pose(up)).origin
		var b := (sk.global_transform * sk.get_bone_global_pose(lo)).origin
		var d := (b - a).normalized()
		var lat := (pl.get_node("Body") as Node3D).global_transform.basis.x * (1.0 if cote == "r" else -1.0)
		var ecart := rad_to_deg(acos(clampf(-d.y, -1.0, 1.0)))
		var lateral := rad_to_deg(asin(clampf(d.dot(lat), -1.0, 1.0)))
		out += " %s : bras a %.0f deg de la verticale (%.0f deg vers l'exterieur)" % [cote, ecart, lateral]
	return out


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	if pl == null:
		pl = scene.get_node("Player")
		pl.set("attente_geste", Vector2(999.0, 999.0))
	if frame == 120:
		print("ARRET :", _angles())
		Input.action_press("move_forward")
	if frame == 220:
		print("MARCHE :", _angles())
		Input.action_press("sprint")
	if frame == 330:
		print("COURSE :", _angles())
		quit()
		return true
	return false
