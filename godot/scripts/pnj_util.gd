class_name PnjUtil
## Outils pour les personnages non joueurs : poses fixes, tenues variees, fusion en un seul mesh (rapide a afficher).

const CHAR_SCENE := "res://assets/models/chr_joueur.glb"
const SHIRT_PARTS := ["chr_torse", "chr_manche_G", "chr_manche_D"]
const PANTS_PARTS := ["chr_bassin", "chr_cuisse_G", "chr_cuisse_D", "chr_tibia_G", "chr_tibia_D"]
const SKIN_PARTS := ["chr_tete", "chr_cou", "chr_nez", "chr_bras_G", "chr_bras_D", "chr_avantbras_G", "chr_avantbras_D", "chr_main_G", "chr_main_D"]

# couleurs de tenues courantes (pagnes wax vifs, chemises, tee-shirts)
const SHIRTS := [Color(0.85, 0.15, 0.1), Color(0.1, 0.35, 0.75), Color(0.95, 0.95, 0.92), Color(0.1, 0.55, 0.3),
	Color(0.95, 0.55, 0.1), Color(0.55, 0.2, 0.6), Color(0.15, 0.15, 0.15), Color(0.9, 0.8, 0.2), Color(0.95, 0.4, 0.55),
	Color(0.3, 0.65, 0.85)]
const PANTS := [Color(0.15, 0.18, 0.3), Color(0.1, 0.1, 0.1), Color(0.45, 0.35, 0.25), Color(0.3, 0.3, 0.32),
	Color(0.85, 0.15, 0.1), Color(0.1, 0.35, 0.75), Color(0.95, 0.55, 0.1)]
const SKINS := [Color(0.36, 0.22, 0.15), Color(0.3, 0.18, 0.12), Color(0.42, 0.27, 0.18), Color(0.25, 0.15, 0.1)]

static var _mat_cache := {}


static func colored(base: Material, c: Color) -> Material:
	var key := "%d|%s" % [base.get_instance_id() if base else 0, c.to_html()]
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		m.resource_name = (base.resource_name if base else "pnj") + "_" + c.to_html()
		_mat_cache[key] = m
	return _mat_cache[key]


static func dress(character: Node, shirt: Color, pants: Color, skin: Color) -> void:
	for mi in character.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		var c := Color(-1, 0, 0)
		if n in SHIRT_PARTS:
			c = shirt
		elif n in PANTS_PARTS:
			c = pants
		elif n in SKIN_PARTS:
			c = skin
		if c.r >= 0.0:
			mi.set_surface_override_material(0, colored(mi.mesh.surface_get_material(0), c))


static func random_outfit(character: Node, rng: RandomNumberGenerator) -> void:
	dress(character, SHIRTS[rng.randi() % SHIRTS.size()], PANTS[rng.randi() % PANTS.size()], SKINS[rng.randi() % SKINS.size()])


static func pose_seated(character: Node) -> void:
	## Pose assise (meme pose que character_anim.gd en mode seated) : moto, tabouret, chaise.
	var rot := {"piv_hanche_G": 1.35, "piv_hanche_D": 1.35, "piv_genou_G": -1.45, "piv_genou_D": -1.45,
		"piv_epaule_G": 0.95, "piv_epaule_D": 0.95, "piv_coude_G": 0.45, "piv_coude_D": 0.45, "piv_tronc": -0.25, "piv_tete": 0.12}
	for k in rot:
		var p := character.find_child(k, true, false) as Node3D
		if p:
			p.rotation.x = rot[k]


static func pose_vendor(character: Node, rng: RandomNumberGenerator) -> void:
	## Assis sur un tabouret, mains sur les genoux ou bras croises, tete legerement tournee.
	pose_seated(character)
	var arms := rng.randf_range(0.3, 0.9)
	for k in ["piv_epaule_G", "piv_epaule_D"]:
		(character.find_child(k, true, false) as Node3D).rotation.x = arms
	(character.find_child("piv_tete", true, false) as Node3D).rotation.y = rng.randf_range(-0.6, 0.6)


static func merge(root: Node3D) -> ArrayMesh:
	## Fusionne tous les MeshInstance3D sous 'root' (deja dans l'arbre) en un seul ArrayMesh,
	## une surface par materiau (en tenant compte des materiaux surcharges).
	var tools := {}
	var order: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible:
			continue
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			var key := str(mat.get_instance_id()) if mat else "aucun"
			if not tools.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(mat)
				tools[key] = st
				order.append(key)
			(tools[key] as SurfaceTool).append_from(mi.mesh, s, xf)
	var out := ArrayMesh.new()
	for key in order:
		(tools[key] as SurfaceTool).commit(out)
	return out
