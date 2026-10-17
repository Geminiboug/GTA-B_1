extends SceneTree
## Progression du personnage (phase 15) : courir fait monter l'endurance et baisser le poids, manger fait grossir, la
## salle de sport muscle, le corps change de silhouette au seuil, les statistiques sont sauvegardees, ecran de
## statistiques dans le menu pause, competences qui changent la conduite et le tir.

var frame := 0
var scene: Node
var player: CharacterBody3D
var st: Node
var fails := 0
var mark := {}


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	var P := root.get_node("Partie")
	if frame == 30:
		player = scene.get_node("Player")
		st = scene.get_node("Stats")
		P.save_path = "user://test_stats.json"     # jamais la vraie sauvegarde
		P.nouvelle_partie()
		st._ready()
		P.argent = 50000
		mark["end"] = st.v("endurance")
		mark["gr"] = st.v("graisse")
		# footing : on court tout droit 10 s
		player.global_position = Vector3(300, 0.5, 120)
		Input.action_press("move_forward")
		Input.action_press("sprint")
	if frame == 30 + 600:
		Input.action_release("move_forward")
		Input.action_release("sprint")
		_check(st.v("endurance") > float(mark["end"]) + 0.15, "footing : endurance %.1f -> %.1f" % [mark["end"], st.v("endurance")])
		_check(st.v("graisse") < float(mark["gr"]), "footing : poids %.1f -> %.1f" % [mark["gr"], st.v("graisse")])
		var com := scene.get_node("Commerce")
		var g0: float = st.v("graisse")
		com.buy("maquis", 0)
		_check(st.v("graisse") > g0 + 1.0, "repas au maquis : poids %.1f -> %.1f" % [g0, st.v("graisse")])
		var m0: float = st.v("muscles")
		_check(com.buy("salle", 0) and st.v("muscles") >= m0 + 3.0, "seance a Gbekpo Fitness : muscles %.0f -> %.0f" % [m0, st.v("muscles")])
		var salle := false
		for s in com.spots:
			salle = salle or s["kind"] == "salle"
		_check(salle, "la salle de sport est placee dans le quartier")
		var d0: float = float(player.get("stamina_drain"))
		P.perso["endurance"] = 90.0
		st.appliquer()
		_check(float(player.get("stamina_drain")) < d0 * 0.8, "endurance haute : sprint plus long (%.3f -> %.3f)" % [d0, player.get("stamina_drain")])
		# silhouette
		P.perso["graisse"] = 80.0
		st.appliquer()
	if frame == 30 + 610:
		var m: Node = player.get_node("Body/Model")
		_check(String(m.get_meta("variante", "")) == "homme_fort", "poids 80 : silhouette forte (%s)" % m.get_meta("variante", ""))
		P.perso["graisse"] = 10.0
		P.perso["muscles"] = 20.0
		st.appliquer()
	if frame == 30 + 620:
		var m: Node = player.get_node("Body/Model")
		_check(String(m.get_meta("variante", "")) == "homme_mince", "poids 10 : silhouette mince (%s)" % m.get_meta("variante", ""))
		# sauvegarde
		P.perso["tir"] = 55.0
		var ok: bool = P.sauver(scene)
		P.perso = {}
		P.charger(scene)
		_check(ok and is_equal_approx(float(P.perso.get("tir", 0.0)), 55.0), "statistiques sauvegardees et rechargees (tir %.0f)" % float(P.perso.get("tir", 0.0)))
		st.appliquer()
		_check(float(scene.get_node("Armes").get("precision")) < 1.1, "tir 55 : visee plus precise (dispersion x%.2f)" % scene.get_node("Armes").get("precision"))
		var menus := scene.get_node_or_null("Menus")
		if menus:
			menus.call("_show_stats")
			_check(String(menus.get("_page")) == "stats", "ecran des statistiques dans le menu pause")
		print("RESULTAT test_stats : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
		quit(1 if fails else 0)
		return true
	return false
