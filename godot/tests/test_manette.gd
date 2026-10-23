extends SceneTree
## Manette : disposition PlayStation par defaut. Chaque action du jeu a un bouton (sauf le mode photo : Share + Options, gere
## par mode_photo.gd), et deux actions d'un meme contexte (a pied, en vehicule, en avion) n'ont jamais le meme bouton.

var frame := 0
var scene: Node
var fails := 0
const CONTEXTES := {
	"a pied": ["move_forward", "move_back", "move_left", "move_right", "look_left", "look_right", "look_up", "look_down", "sprint", "jump",
		"attaque", "interact", "garde", "arme_suivante", "recharger", "crouch", "parler", "inventaire", "telephone", "camera_vue", "map",
		"map_pin_hors", "pause", "heler", "torche"],
	"en vehicule": ["move_left", "move_right", "accelerate", "brake", "handbrake", "horn", "limiteur", "interact", "parler", "camera_vue", "map", "pause",
		"look_left", "look_right", "look_up", "look_down"],
	"en avion": ["accelerate", "brake", "handbrake", "lacet_g", "lacet_d", "interact", "camera_vue", "map", "pause", "move_forward", "move_back",
		"move_left", "move_right"],
}
const SANS_MANETTE := ["photo", "walk"]   # photo : Share + Options (mode_photo.gd) ; marche lente : inclinaison du stick


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _boutons(a: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(a):
		if ev is InputEventJoypadButton:
			out.append("b%d" % (ev as InputEventJoypadButton).button_index)
		elif ev is InputEventJoypadMotion:
			out.append("a%d%+.0f" % [(ev as InputEventJoypadMotion).axis, (ev as InputEventJoypadMotion).axis_value])
	return out


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 120:
		return false
	var sans := []
	for a in InputMap.get_actions():
		var s := String(a)
		if s.begins_with("ui_") or s.begins_with("spatial_editor") or s.contains("/") or s in SANS_MANETTE:
			continue
		if _boutons(s).is_empty():
			sans.append(s)
	_check(sans.is_empty(), "toutes les actions ont un bouton de manette (sans : %s)" % ",".join(sans))
	for ctx in CONTEXTES:
		var vus := {}
		var conflits := []
		for a in CONTEXTES[ctx]:
			if not InputMap.has_action(a):
				continue
			for b in _boutons(a):
				if vus.has(b) and vus[b] != a:
					conflits.append("%s/%s (%s)" % [vus[b], a, b])
				vus[b] = a
		_check(conflits.is_empty(), "%s : aucun bouton partage (%s)" % [ctx, ",".join(conflits)])
	var ps := _boutons("sprint") == ["b0"] and _boutons("jump") == ["b2"] and _boutons("interact") == ["b3"]
	_check(ps, "disposition PlayStation : Croix courir, Carre sauter, Triangle monter")
	print("RESULTAT test_manette : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
