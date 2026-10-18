extends SceneTree
## Virages sur place : a l'arret, demander une direction a 90 ou 180 degres joue le pas tourne capte (MX_Tourne_*,
## MX_DemiTour_Marche), le joueur ne glisse pas pendant le pas et finit tourne vers la direction demandee.
var frame := 0
var scene: Node
var fails := 0
var pl: Node
var p0 := Vector3.ZERO
var vu := {}
var derive := 0.0
var etape := 0
const ESSAIS := [["move_left", "MX_Tourne_G90"], ["move_right", "MX_Tourne_D90"], ["move_back", "MX_DemiTour_Marche"]]
func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
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
	var an: Node = pl.get("anim")
	var k := (frame - 60) % 120
	var i := (frame - 60) / 120
	if i >= ESSAIS.size():
		_check(derive < 0.25, "pas de glissade pendant les virages (%.2f m au plus)" % derive)
		print("RESULTAT test_virage : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	var e: Array = ESSAIS[i]
	if k == 0:
		# la camera regarde comme le joueur : gauche / droite / arriere = 90 / 90 / 180 degres
		(pl.get("cam_pivot") as Node3D).rotation.y = float(pl.get("_facing"))
		p0 = (pl as Node3D).global_position
		Input.action_press(e[0])
	if k > 0 and k < 60:
		if an.call("clip_position", e[1]) >= 0.0:
			vu[e[1]] = true
		var p := (pl as Node3D).global_position
		derive = maxf(derive, Vector2(p.x - p0.x, p.z - p0.z).length())
	if k == 12:
		Input.action_release(e[0])     # on lache : le pas tourne va au bout
	if k == 100:
		var cam: float = (pl.get("cam_pivot") as Node3D).rotation.y
		var voulu: float = cam + {"move_left": PI / 2.0, "move_right": -PI / 2.0, "move_back": PI}[e[0]]
		var ecart := rad_to_deg(absf(angle_difference(float(pl.get("_facing")), voulu)))
		_check(vu.has(e[1]), "%s joue %s" % [e[0], e[1]])
		_check(ecart < 12.0, "%s : tourne vers la direction demandee (ecart %.0f degres)" % [e[0], ecart])
	return false
