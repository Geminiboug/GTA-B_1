extends SceneTree
## Mort du joueur : sante a zero -> chute (ragdoll) et ralenti, puis reveil au centre de sante avec la sante restauree.

var frame := 0
var scene: Node
var fails := 0
var t0 := 0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 150:
		return false
	var partie := root.get_node("Partie")
	var pl := scene.get_node("Player")
	if t0 == 0:
		partie.blesser(500.0)
		t0 = frame
		_check(partie.sante <= 0.0, "sante a zero")
		_check((pl.get("menus") as Dictionary).has("mort"), "plus de commandes pendant la chute")
		return false
	if frame - t0 == 30:
		var sim := false
		for n in pl.find_children("*", "PhysicalBoneSimulator3D", true, false):
			sim = true
		_check(sim or Engine.time_scale < 1.0, "chute physique ou ralenti en cours")
	if frame - t0 > 60 * 14:
		_check(partie.sante >= 99.0, "reveil avec la sante restauree (%.0f)" % partie.sante)
		_check(not (pl.get("menus") as Dictionary).has("mort"), "commandes rendues")
		_check(Engine.time_scale == 1.0, "temps normal")
		print("RESULTAT test_mort : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
