extends SceneTree
var frame := 0
var scene: Node
func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 120:
		return false
	var noms := ["A (Croix)", "B (Rond)", "X (Carre)", "Y (Triangle)", "Back (Select)", "Guide", "Start", "L3", "R3", "L1", "R1", "Haut", "Bas", "Gauche", "Droite"]
	for a in InputMap.get_actions():
		var s := String(a)
		if s.begins_with("ui_") or s.begins_with("spatial_editor") or s.contains("/"):
			continue
		var joy := []
		var cl := []
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadButton:
				var b := (ev as InputEventJoypadButton).button_index
				joy.append(noms[b] if b < noms.size() else "bouton %d" % b)
			elif ev is InputEventJoypadMotion:
				joy.append("axe %d %+.0f" % [(ev as InputEventJoypadMotion).axis, (ev as InputEventJoypadMotion).axis_value])
			elif ev is InputEventKey:
				cl.append(OS.get_keycode_string((ev as InputEventKey).physical_keycode if (ev as InputEventKey).physical_keycode != 0 else (ev as InputEventKey).keycode))
		print("ACTION %-16s clavier %-12s manette %s" % [s, ",".join(cl), ",".join(joy)])
	quit()
	return true
