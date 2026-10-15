extends SceneTree
## Test du mode debug : bascule F1 (3 etats), panneau d'infos complet, chaque teleportation (arrivee au bon endroit,
## au sol, hors des batiments et dans la carte), trace des chemins sans erreur.
## Lancement : godot --headless --path godot --script res://tests/test_debug.gd

var frame := 0
var scene: Node
var dbg: Node
var player: CharacterBody3D
var fails := 0
var tp := 0
var wait := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _press(key: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = key
	e.pressed = true
	dbg._unhandled_input(e)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		dbg = scene.get_node_or_null("Debug")
		player = scene.get_node("Player")
		_check(dbg != null, "noeud Debug present dans la scene")
		if dbg == null:
			return _end()
		_check(dbg.mode == 0, "mode debug desactive au lancement")
		_press(KEY_F1)
		_check(dbg.mode == 1, "F1 -> infos")
		var txt: String = dbg.info_text()
		for k in ["images/s", "Joueur", "Animation", "Heure", "PNJ a pied", "Teleportation"]:
			_check(txt.contains(k), "panneau : '%s' affiche" % k)
		_press(KEY_F1)
		_check(dbg.mode == 2, "F1 -> infos + chemins")
	if frame > 40 and frame % 40 == 0 and dbg:
		if tp > 0:
			var want: Vector3 = dbg.teleports[tp - 1]["pos"]
			var at := player.global_position
			var flat := Vector2(at.x - want.x, at.z - want.z).length()
			var carte := Carte.zone()
			var free := not (carte.in_bounds(Vector2(at.x, at.z)) and carte.in_building(Vector2(at.x, at.z))) or String(dbg.teleports[tp - 1]["nom"]).contains("interieur") or String(dbg.teleports[tp - 1]["nom"]).contains("hall") or String(dbg.teleports[tp - 1]["nom"]).contains("Maison")   # concession entiere dans le masque
			_check(flat < 1.0 and player.is_on_floor() and absf(at.y) < 1.5 and free,
				"teleportation %d (%s) : a %.2f m, au sol %s, y = %.2f" % [tp, dbg.teleports[tp - 1]["nom"], flat, player.is_on_floor(), at.y])
		if tp >= dbg.teleports.size():
			_check(dbg._lines.visible, "chemins affiches en mode 2")
			_press(KEY_F1)
			_check(dbg.mode == 0 and not dbg._panel.visible, "F1 -> desactive")
			return _end()
		_press(KEY_1 + tp)
		tp += 1
	return false


func _end() -> bool:
	print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
	return true
