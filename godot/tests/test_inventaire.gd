extends SceneTree
## Inventaire du joueur : torche et smartphone au depart (et ajoutes aux anciennes sauvegardes), liste ouverte avec
## I, torche allumee (lumiere + lampe dans la main), manger un aliment, telephone (messages, zem a la demande qui
## deplace le joueur et fait payer la course + l'appel, contacts).

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var argent0 := 0
var pos0 := Vector3.ZERO


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "ECHEC ") + what)
	if not ok:
		fails += 1


func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()   # tout de suite, meme si le jeu rame


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	var partie := root.get_node("Partie")
	var inv := scene.get_node("Inventaire")
	var tel := scene.get_node("Telephone")
	if frame == 30:
		player = scene.get_node("Player")
		partie.nouvelle_partie()
		_check(partie.a("Smartphone") and partie.a("Torche"), "torche et smartphone au depart")
		var old := {"version": 2, "inventaire": {"Pain": 1}, "argent": 100}
		var conv: Dictionary = partie.convertir_sauvegarde(old)
		_check(int(conv["version"]) == partie.SAVE_VERSION and conv["inventaire"].has("Torche") and conv["inventaire"].has("Smartphone") and conv["inventaire"].has("Pain"),
			"ancienne sauvegarde : torche et smartphone ajoutes, le reste garde")
	if frame == 40:
		_key(KEY_I)
	if frame == 45:
		_check(inv.ouvert, "I ouvre l'inventaire")
		_check(inv.liste().slice(0, 2) == ["Smartphone", "Torche"], "smartphone et torche en tete de liste")
		_key(KEY_DOWN)
		_key(KEY_ENTER)
	if frame == 50:
		_check(inv.torche_allumee, "Entree sur la torche : allumee")
		var spot := player.get_node_or_null("Torche") as SpotLight3D
		_check(spot != null and spot.visible and spot.spot_range > 10.0, "faisceau de la torche")
		_check(player.find_child("MainTorche", true, false) != null, "lampe dans la main droite")
		_key(KEY_L)
	if frame == 55:
		_check(not inv.torche_allumee, "L eteint la torche")
		partie.ajouter("Pain")
		partie.blesser(30.0)
		var s0: float = partie.sante
		inv.utiliser("Pain")
		_check(not partie.a("Pain") and partie.sante > s0, "manger le pain : sante %.0f -> %.0f" % [s0, partie.sante])
		inv.ouvrir(false)
		_key(KEY_P)
	if frame == 60:
		_check(tel.ouvert, "P ouvre le telephone")
		tel.app("Messages")
		_check(tel.get("_list").get_child_count() >= 1, "application Messages")
		tel.app("Contacts")
		tel.choisir(0)
		_check(not tel.ouvert, "appel d'un contact")
		tel.app("Zem")
		argent0 = partie.argent + 20000
		partie.gagner(20000)
		pos0 = player.global_position
		var prix: int = scene.get_node("Taxi").prix(1) + tel.frais_appel_zem
		tel.set("_sel", 1)
		tel.choisir(1)
		argent0 -= prix
	if frame == 260:
		_check(player.global_position.distance_to(pos0) > 100.0, "zem a la demande : deplace (%.0f m)" % player.global_position.distance_to(pos0))
		_check(partie.argent == argent0, "course + appel payes (%d F, attendu %d F)" % [partie.argent, argent0])
		print("RESULTAT test_inventaire : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
