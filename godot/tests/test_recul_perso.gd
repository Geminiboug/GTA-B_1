extends SceneTree
## Marche en retrait : Alt + arriere / gauche / droite deplace le personnage sans le retourner
## (cap conserve), dans la bonne direction, a vitesse de marche reduite.

var frame := 0
var scene: Node
var fails := 0
var pl: Node
var p0 := Vector3.ZERO
var cap0 := 0.0
const ESSAIS := [["move_back", "arriere"], ["move_left", "gauche"], ["move_right", "droite"]]


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	if pl == null:
		pl = scene.get_node("Player")
		pl.set("attente_geste", Vector2(999.0, 999.0))
	var i := (frame - 60) / 150
	var k := (frame - 60) % 150
	if i >= ESSAIS.size():
		print("RESULTAT test_recul_perso : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	var e: Array = ESSAIS[i]
	if k == 0:
		(pl.get("cam_pivot") as Node3D).rotation.y = float(pl.get("_facing"))
		p0 = (pl as Node3D).global_position
		cap0 = float(pl.get("_facing"))
		Input.action_press("walk")
		Input.action_press(e[0])
	if k == 100:
		var p := (pl as Node3D).global_position
		var d := Vector2(p.x - p0.x, p.z - p0.z)
		var fwd := Vector2(-sin(cap0), -cos(cap0))
		var droite := Vector2(-fwd.y, fwd.x)     # droite du personnage (comme la voie de droite d une rue)
		var ecart := rad_to_deg(absf(angle_difference(cap0, float(pl.get("_facing")))))
		_check(ecart < 6.0, "%s : le personnage ne se retourne pas (%.1f degres)" % [e[1], ecart])
		_check(d.length() > 0.8, "%s : il avance (%.1f m en 1,7 s)" % [e[1], d.length()])
		match e[1]:
			"arriere":
				_check(d.dot(fwd) < -0.8, "arriere : le deplacement va vers l'arriere (%.1f m)" % d.dot(fwd))
			"gauche":
				_check(d.dot(droite) < -0.8, "gauche : le deplacement va a gauche (%.1f m)" % d.dot(droite))
			"droite":
				_check(d.dot(droite) > 0.8, "droite : le deplacement va a droite (%.1f m)" % d.dot(droite))
		Input.action_release(e[0])
		Input.action_release("walk")
	return false
