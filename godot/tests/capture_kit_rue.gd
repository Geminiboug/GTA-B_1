extends SceneTree
## Captures de controle de la suite de l'audit Cotonou : kit d'objets de rue devant une boutique, chantier (sable et
## parpaings), bordures peintes d'un terre-plein, rue tertiaire pavee, arbres (badamier, neem), toits a creneaux.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_kit_rue.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var out_dir := "user://"
var shots: Array = []    # [nom, position du joueur, rotation de la camera (x, y), zoom]
var idx := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")


func _premier(props: Node, kind: String, n := 0) -> Vector3:
	for key in props.get("_chunks"):
		var ch: Dictionary = props.get("_chunks")[key]
		if ch["kind"] == kind and ch["xf"].size() > n:
			return (ch["xf"][n] as Transform3D).origin
	return Vector3.INF


func _preparer() -> void:
	var props := scene.get_node("Props")
	var data: Dictionary = Carte.zone().data
	for k in [["parasol", "rue_parasol", 0], ["gaz", "rue_gaz", 0], ["chantier", "rue_sable", 0], ["banc", "rue_banc", 0]]:
		var p := _premier(props, k[1], k[2])
		if p != Vector3.INF:
			shots.append([k[0], p + Vector3(2.0, 1, 2.0), Vector2(-0.6, PI / 4.0), 6.0])
	var med: Array = data.get("medians", [])
	if not med.is_empty():
		var m: Array = med[0][med[0].size() / 2]
		shots.append(["terre_plein", Vector3(float(m[0]) + 4.0, 1, float(m[1]) + 4.0), Vector2(-0.3, PI / 4.0), 5.0])
	for r in data["roads"]:
		if r["kind"] == "tertiary" and r["surface"] == "paves":
			var q: Array = r["pts"][r["pts"].size() / 2]
			shots.append(["tertiaire_pavee", Vector3(float(q[0]), 1, float(q[1])), Vector2(-0.15, 0.8), 7.0])
			break
	var veg := scene.get_node_or_null("Vegetation")
	if veg:
		for kind in ["veg_badamier", "veg_neem"]:
			var l: Array = veg.get("_xforms")[kind]
			if l.size() > 5:
				var o: Vector3 = (l[5] as Transform3D).origin
				shots.append([kind, o + Vector3(9, 1, 9), Vector2(-0.05, PI / 4.0), 6.0])
	shots.append(["toits", Vector3(300, 1, 120), Vector2(-0.6, 2.4), 30.0])


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame < 30:
		return false
	if frame == 30:
		_preparer()
		print("vues : ", shots.map(func(s): return s[0]))
	var local := frame - 31 - idx * 160
	if idx >= shots.size():
		return true
	var s = shots[idx]
	if local == 0:
		player.global_position = s[1]
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(s[2].x, s[2].y, 0)
		player.spring_arm.spring_length = s[3]
		(player.get_node("Body") as Node3D).visible = false   # le joueur cachait les petits objets
	elif local == 150:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("kit_%s.png" % s[0]))
		print("capture ", s[0])
		idx += 1
	return false
