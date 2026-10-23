extends SceneTree
## Braquage : arme en joue pres d'un lieu braquable, tenu 5 s -> butin, delit "braquage" (recherche), recharge du lieu ;
## s'eloigner pendant le braquage le fait echouer.

var frame := 0
var scene: Node
var fails := 0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame < 240:
		return false
	var partie := root.get_node("Partie")
	var br = scene.get_node("Commerce/Braquage")
	var player := scene.get_node("Player") as Node3D
	var lieu := {}
	for s in scene.get_node("Commerce").spots:
		if br.NOMS.has(s["kind"]):
			lieu = s
			break
	_check(not lieu.is_empty(), "un lieu braquable existe (%s)" % lieu.get("kind", "?"))
	if lieu.is_empty():
		quit(1)
		return true
	player.global_position = lieu["pos"] + Vector3(1.5, 0.3, 0)
	player.set("arme_feu", true)
	player.set("visee", true)
	_check(br.peut_braquer(br.lieu_proche(player.global_position)), "lieu proche et disponible")
	var argent0: int = partie.argent
	var rech0: int = partie.recherche
	br.demarrer(lieu)
	br._suivre(0.1)
	_check(partie.argent == argent0, "pas de butin avant la fin du delai")
	br._suivre(br.duree + 0.1)
	_check(partie.argent > argent0, "butin recu : %d FCFA" % (partie.argent - argent0))
	_check(partie.recherche > rech0, "recherche de police : %d -> %d" % [rech0, partie.recherche])
	_check(not br.peut_braquer(lieu), "le lieu n'est plus braquable pendant la recharge")
	# second lieu : le joueur s'eloigne
	var autre := {}
	for s in scene.get_node("Commerce").spots:
		if br.NOMS.has(s["kind"]) and br._cle(s) != br._cle(lieu):
			autre = s
			break
	if not autre.is_empty():
		var a1: int = partie.argent
		player.global_position = autre["pos"] + Vector3(1.5, 0.3, 0)
		br.demarrer(autre)
		player.global_position = autre["pos"] + Vector3(30, 0.3, 0)
		br._suivre(0.2)
		br._suivre(br.duree + 0.1)
		_check(partie.argent == a1, "s'eloigner fait echouer le braquage")
	print("RESULTAT test_braquage : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
