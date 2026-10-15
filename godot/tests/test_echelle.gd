extends SceneTree
## Test d'echelle : chaque modele a la taille reelle (reference : docs/PIPELINE.md, "Reference d'echelle").
## Personnages (corps seul, sans coiffure), vehicules, avion, mobilier urbain, portes des lieux, joueur.
## Lancement : godot --headless --path godot --script res://tests/test_echelle.gd

var fails := 0


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _aabb(n: Node, xf: Transform3D, only: String = "") -> Variant:
	## Boite englobante (repere du modele) des maillages, ou du seul maillage nomme `only`.
	var t := xf * (n as Node3D).transform if n is Node3D else xf
	var acc: Variant = null
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (only == "" or n.name == only):
		acc = t * (n as MeshInstance3D).mesh.get_aabb()
	for c in n.get_children():
		var a: Variant = _aabb(c, t, only)
		if a != null:
			acc = a if acc == null else (acc as AABB).merge(a)
	return acc


func _model(f: String) -> Node:
	return (load("res://assets/models/%s.glb" % f) as PackedScene).instantiate()


func _range(v: float, lo: float, hi: float, what: String) -> void:
	_check(v >= lo and v <= hi, "%s : %.2f m (attendu %.2f a %.2f)" % [what, v, lo, hi])


func _initialize() -> void:
	# --- personnes : sommet du corps (pieds a 0)
	for e in [["chr_homme", 1.66, 1.74], ["chr_homme_fort", 1.66, 1.74], ["chr_femme", 1.55, 1.64],
			["chr_femme_ronde", 1.54, 1.63], ["chr_garcon", 1.25, 1.38], ["chr_fille", 1.22, 1.36]]:
		var b: Variant = _aabb(_model(e[0]), Transform3D(), "chr_corps")
		_range((b as AABB).end.y, e[1], e[2], "taille %s" % e[0])
	# --- vehicules : longueur (Z), hauteur (Y), largeur de caisse (sans retroviseurs)
	for e in [["veh_zem", "", 1.85, 2.10, 1.0, 1.35], ["veh_berline", "veh_berline_caisse", 4.4, 4.75, 1.40, 1.52],
			["veh_4x4", "veh_4x4_caisse", 4.5, 5.0, 1.68, 1.92], ["veh_minibus", "veh_minibus_caisse", 4.7, 5.4, 1.95, 2.60]]:
		var m := _model(e[0])
		var all: AABB = _aabb(m, Transform3D())
		_range(all.size.z, e[2], e[3], "longueur %s" % e[0])
		_range(all.size.y, e[4], e[5], "hauteur %s" % e[0])
	var plane: AABB = _aabb(_model("veh_avion_ligne"), Transform3D())
	_range(plane.size.x, 34.0, 36.5, "envergure avion de ligne")
	_range(plane.size.z, 36.5, 38.5, "longueur avion de ligne")
	_range(plane.size.y, 11.0, 12.5, "hauteur avion de ligne")
	# --- mobilier urbain
	var props := _model("props")
	for e in [["prop_poteau", 8.5, 11.5], ["prop_lampadaire", 7.5, 10.5], ["prop_cabine", 2.0, 2.6]]:
		var n := props.find_child(e[0], true, false)
		_check(n != null, "modele %s present" % e[0])
		if n:
			_range((_aabb(n, Transform3D()) as AABB).size.y, e[1], e[2], "hauteur %s" % e[0])
	# --- portes des lieux (hauteur du vantail, largeur de l'ouverture)
	var maison := _model("lieu_maison")
	var leaf: AABB = _aabb(maison.find_child("porte_battante_entree_g_vantail", true, false), Transform3D())
	_range(leaf.size.y, 2.0, 2.15, "hauteur porte d'entree de maison")
	_range(leaf.size.x + leaf.size.z - 0.05, 0.6, 0.95, "largeur d'un vantail de porte d'entree")
	# passage libre : couloir de 1,2 m de large de la veranda (2,8 m devant) au salon (1,3 m derriere la porte), 0,1 a 1,8 m
	var blocked := 0
	var bg := maison.find_child("porte_battante_entree_g", true, false) as Node3D
	var bd := maison.find_child("porte_battante_entree_d", true, false) as Node3D
	var mid := (bg.position + bd.position) * 0.5
	for n in maison.find_children("*", "MeshInstance3D", true, false):
		var nm := String(n.name)
		if nm.begins_with("porte_") or nm.begins_with("zone_"):
			continue
		var mi := n as MeshInstance3D
		var xf := mi.transform
		var p := mi.get_parent()
		while p != bg.get_parent() and p != maison and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var corridor := AABB(Vector3(-0.6, 0.1, -1.3), Vector3(1.2, 1.7, 4.1))
		var f := mi.mesh.get_faces()
		for i in range(0, f.size(), 3):
			var tri := AABB(xf * f[i] - mid, Vector3.ZERO).expand(xf * f[i + 1] - mid).expand(xf * f[i + 2] - mid)
			if tri.intersects(corridor):
				blocked += 1
	_check(blocked == 0, "passage libre devant et derriere la porte d'entree de la maison (%d triangles genants)" % blocked)
	for e in [["lieu_ararat", "ararat", 2.2, 2.6, 1.8, 3.0], ["lieu_terminal", "terminal", 2.2, 2.7, 2.0, 3.2]]:
		var lieu := _model(e[0])
		var g: AABB = _aabb(lieu.find_child("porte_coulissante_%s_g_vantail" % e[1], true, false), Transform3D())
		var d: AABB = _aabb(lieu.find_child("porte_coulissante_%s_d_vantail" % e[1], true, false), Transform3D())
		_range(g.size.y, e[2], e[3], "hauteur porte automatique %s" % e[1])
		var w := Vector2(g.size.x, g.size.z).length() + Vector2(d.size.x, d.size.z).length() - 0.2
		_range(w, e[4], e[5], "largeur porte automatique %s" % e[1])
	# --- joueur : modele homme, sans mise a l'echelle
	var player: Node = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	var body: Variant = _aabb(player, Transform3D(), "chr_corps")
	_check(body != null, "joueur : corps trouve")
	if body != null:
		_range((body as AABB).end.y - player.get_node(".").get("position").y, 1.66, 1.76, "taille du joueur")
	print("RESULTAT : %s" % ("tout est a l'echelle" if fails == 0 else "%d echec(s)" % fails))
	quit()
