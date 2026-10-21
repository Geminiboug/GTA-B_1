extends SceneTree
## Commandes reaffectables (Options > Commandes) : une touche du clavier ou un bouton de souris remplace l'ancienne,
## une touche deja prise est echangee (jamais deux commandes sur la meme touche), le choix est garde dans les options
## et "Touches par defaut" remet tout. Les nouvelles actions (inventaire, telephone, torche, photo) existent.
var frame := 0
var scene: Node
var fails := 0
var P: Node      # autoload Partie (pas d identifiant global dans un script de SceneTree)


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	P = root.get_node("Partie")
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _touche(action: String) -> Variant:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			return P.code_touche(ev)
	return null


func _appuyer(menus: Node, ev: InputEvent) -> void:
	ev.pressed = true
	menus.call("_input", ev)


func _process(_d: float) -> bool:
	frame += 1
	if frame != 30:
		return false
	var partie: Node = root.get_node("Partie")
	var menus: Node = scene.get_node("Menus")
	for a in ["inventaire", "telephone", "torche", "photo", "garde", "arme_suivante"]:
		_check(InputMap.has_action(a), "action %s (%s)" % [a, P.nom_touche(a)])
	var saut_avant: Variant = _touche("jump")
	# sauter -> U
	menus.set("_attente_touche", "jump")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_U
	_appuyer(menus, k)
	_check(_touche("jump") == KEY_U, "sauter sur U")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_U
	ev.pressed = true
	_check(ev.is_action("jump"), "la touche U declenche bien l'action")
	# courir -> U : sauter recupere l'ancienne touche de courir
	var courir_avant: Variant = _touche("sprint")
	menus.set("_attente_touche", "sprint")
	_appuyer(menus, k.duplicate())
	_check(_touche("sprint") == KEY_U and _touche("jump") == courir_avant, "echange : courir sur U, sauter sur l'ancienne touche de courir")
	# frapper -> bouton du milieu de la souris
	menus.set("_attente_touche", "attaque")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	_appuyer(menus, mb)
	_check(_touche("attaque") == "souris:%d" % MOUSE_BUTTON_MIDDLE, "frapper sur le clic du milieu (%s)" % P.nom_touche("attaque"))
	# Echap annule
	menus.set("_attente_touche", "map")
	var avant_carte: Variant = _touche("map")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	_appuyer(menus, esc)
	_check(_touche("map") == avant_carte and String(menus.get("_attente_touche")) == "", "Echap annule sans rien changer")
	# garde dans les options (fichier) et rechargee
	var c := ConfigFile.new()
	c.load(P.OPTIONS)
	var t: Dictionary = c.get_value("options", "touches", {})
	_check(int(t.get("sprint", 0)) == KEY_U, "choix enregistre dans les options")
	# aide a l'ecran a jour
	var aide: String = scene.get_node("HUDJeu").call("texte_aide", "pied", false)
	_check(aide.contains("U : "), "l'aide a l'ecran montre la nouvelle touche")
	# touches par defaut
	partie.call("touches_par_defaut")
	_check(_touche("jump") == saut_avant and _touche("sprint") == courir_avant, "touches d'origine remises")
	print("RESULTAT test_commandes : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
	quit(1 if fails else 0)
	return true
