class_name PnjUtil
## Personnages (joueur et PNJ) : choix de la morphologie (homme, homme fort, femme, femme ronde, garcon, fille),
## tenues beninoises variees, coiffures, poses fixes et fusion en un seul mesh (vendeurs assis, conducteurs).
## Modeles : godot/assets/models/chr_<variante>.glb (blender/tools/build_character.py), corps anime par squelette.
## Chaque personnage porte meta "genre" (homme / femme) et "age" (adulte / enfant), lus par les dialogues et les reactions.

const VARIANTS := {"homme": "homme", "homme_fort": "homme", "femme": "femme", "femme_ronde": "femme",
	"garcon": "homme", "fille": "femme"}
const WAX := preload("res://shaders/wax.gdshader")
const KHAKI := Color(0.72, 0.62, 0.42)

# pieces optionnelles : affichees selon la tenue (le corps chr_corps est toujours visible)
const OPTIONAL := ["chr_haut", "chr_haut_long", "chr_pantalon", "chr_short", "chr_chaussures", "chr_semelle", "chr_jupe",
	"chr_pagne_long", "chr_boubou", "chr_cheveux", "chr_afro", "chr_chignon", "chr_tresse", "chr_meches", "chr_foulard",
	"chr_casquette"]

const SHIRTS := [Color(0.85, 0.15, 0.1), Color(0.1, 0.35, 0.75), Color(0.95, 0.95, 0.92), Color(0.1, 0.55, 0.3),
	Color(0.95, 0.55, 0.1), Color(0.55, 0.2, 0.6), Color(0.15, 0.15, 0.15), Color(0.9, 0.8, 0.2), Color(0.95, 0.4, 0.55),
	Color(0.3, 0.65, 0.85), Color(0.92, 0.9, 0.84)]
const PANTS := [Color(0.15, 0.18, 0.3), Color(0.1, 0.1, 0.1), Color(0.45, 0.35, 0.25), Color(0.3, 0.3, 0.32),
	Color(0.22, 0.3, 0.45), Color(0.55, 0.5, 0.42)]
const SKINS := [Color(0.36, 0.22, 0.15), Color(0.3, 0.18, 0.12), Color(0.42, 0.27, 0.18), Color(0.25, 0.15, 0.1),
	Color(0.47, 0.31, 0.21)]
const WAX_PALETTES := [
	[Color(0.85, 0.2, 0.08), Color(0.98, 0.78, 0.12), Color(0.08, 0.22, 0.55)],
	[Color(0.1, 0.45, 0.3), Color(0.98, 0.85, 0.2), Color(0.85, 0.25, 0.15)],
	[Color(0.12, 0.25, 0.6), Color(0.95, 0.55, 0.1), Color(0.95, 0.95, 0.9)],
	[Color(0.55, 0.12, 0.45), Color(0.98, 0.7, 0.2), Color(0.1, 0.5, 0.45)],
	[Color(0.95, 0.6, 0.1), Color(0.6, 0.1, 0.08), Color(0.1, 0.1, 0.12)],
	[Color(0.95, 0.92, 0.85), Color(0.1, 0.3, 0.6), Color(0.85, 0.3, 0.1)],
	[Color(0.2, 0.15, 0.4), Color(0.3, 0.75, 0.75), Color(0.98, 0.8, 0.3)],
]

static var _mat_cache := {}


static func scene_path(variant: String) -> String:
	return "res://assets/models/chr_%s.glb" % variant


static func make(variant: String) -> Node3D:
	## Instance d'une morphologie ("homme", "femme", "homme_fort", "femme_ronde", "garcon", "fille").
	if not VARIANTS.has(variant):
		variant = "homme"
	var ch := (load(scene_path(variant)) as PackedScene).instantiate() as Node3D
	ch.set_meta("genre", VARIANTS[variant])
	ch.set_meta("age", "enfant" if variant in ["garcon", "fille"] else "adulte")
	ch.set_meta("variante", variant)
	return ch


static func random_genre(rng: RandomNumberGenerator, women_share := 0.5) -> String:
	return "femme" if rng.randf() < women_share else "homme"


static func random_variant(rng: RandomNumberGenerator, genre: String, child_share := 0.0) -> String:
	if rng.randf() < child_share:
		return "fille" if genre == "femme" else "garcon"
	if genre == "femme":
		return "femme_ronde" if rng.randf() < 0.38 else "femme"
	return "homme_fort" if rng.randf() < 0.25 else "homme"


static func plain(c: Color) -> Material:
	var key := "p|" + c.to_html()
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		_mat_cache[key] = m
	return _mat_cache[key]


static func wax(palette: Array, motif: int) -> Material:
	var key := "w|%s|%s|%s|%d" % [palette[0].to_html(), palette[1].to_html(), palette[2].to_html(), motif]
	if not _mat_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = WAX
		m.set_shader_parameter("col_a", Vector3(palette[0].r, palette[0].g, palette[0].b))
		m.set_shader_parameter("col_b", Vector3(palette[1].r, palette[1].g, palette[1].b))
		m.set_shader_parameter("col_c", Vector3(palette[2].r, palette[2].g, palette[2].b))
		m.set_shader_parameter("motif", motif)
		_mat_cache[key] = m
	return _mat_cache[key]


static func skin_mat(c: Color) -> Material:
	var key := "s|" + c.to_html()
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.55
		m.rim_enabled = true          # leger reflet de bord : la peau parait moins "plastique"
		m.rim = 0.12
		m.rim_tint = 0.6
		_mat_cache[key] = m
	return _mat_cache[key]


# familles de pieces (tresse_0..8, foulard + haut + noeud, casquette + visiere, semelles G et D)
const GROUPS := ["chr_tresse", "chr_foulard", "chr_casquette", "chr_semelle"]


static func _starts(n: String, names: Array) -> bool:
	## La piece n fait-elle partie de la liste ? (nom exact, ou membre d'une famille de pieces)
	for e in names:
		if n == e or (e in GROUPS and n.begins_with(e + "_")):
			return true
	return false


static func apply(ch: Node, look: Dictionary) -> void:
	## look = {skin, top, legs, cloth, shoes ("chaussures" ou "sandales"), show: [prefixes de pieces], cap}
	for mi in ch.find_children("chr_*", "MeshInstance3D", true, false):
		var n := String(mi.name)
		if n == "chr_corps":
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				var m: Material = (mi as MeshInstance3D).mesh.surface_get_material(s)
				if m and m.resource_name == "chr_peau":
					(mi as MeshInstance3D).set_surface_override_material(s, skin_mat(look["skin"]))
			continue
		if _starts(n, OPTIONAL):
			mi.visible = _starts(n, look["show"])
		var mat: Material = null
		if n.begins_with("chr_haut"):
			mat = look["top"]
		elif n.begins_with("chr_pantalon") or n.begins_with("chr_short"):
			mat = look["legs"]
		elif n.begins_with("chr_boubou") or n.begins_with("chr_jupe") or n.begins_with("chr_pagne") or n.begins_with("chr_foulard"):
			mat = look["cloth"]
		elif n.begins_with("chr_casquette"):
			mat = look.get("cap", null)
		if mat:
			(mi as MeshInstance3D).set_surface_override_material(0, mat)
	if ch.get("femme") != null:
		ch.set("femme", ch.get_meta("genre", "homme") == "femme")


static func random_look(ch: Node, rng: RandomNumberGenerator, kind := "") -> Dictionary:
	## Tenue au hasard, realiste pour Cotonou. kind : "zem" (chemise jaune des zemidjans), "ecole" (uniforme kaki).
	var genre: String = ch.get_meta("genre", "homme")
	var enfant: bool = ch.get_meta("age", "adulte") == "enfant"
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	var pal: Array = WAX_PALETTES[rng.randi() % WAX_PALETTES.size()]
	var cloth := wax(pal, rng.randi() % 4)
	var shirt := plain(SHIRTS[rng.randi() % SHIRTS.size()])
	var pants := plain(PANTS[rng.randi() % PANTS.size()])
	var look := {"skin": skin, "top": shirt, "legs": pants, "cloth": cloth, "show": [],
		"cap": plain(SHIRTS[rng.randi() % SHIRTS.size()].darkened(0.2))}
	var show: Array = look["show"]
	if enfant and (kind == "ecole" or rng.randf() < 0.55):
		# uniforme scolaire kaki des ecoles publiques beninoises
		look["top"] = plain(KHAKI)
		look["legs"] = plain(KHAKI.darkened(0.08))
		look["cloth"] = plain(KHAKI.darkened(0.08))
		show.append_array(["chr_haut", "chr_semelle"])
		show.append("chr_short" if genre == "homme" else "chr_jupe")
		show.append_array(["chr_cheveux"] if genre == "homme" or rng.randf() < 0.5 else ["chr_cheveux", "chr_tresse"])   # tresses : nattes collees sur le crane + meches
		return look
	if genre == "homme":
		var r := rng.randf()
		if kind == "zem":
			look["top"] = plain(Color(0.95, 0.78, 0.1))
			show.append_array(["chr_haut", "chr_pantalon", "chr_chaussures"])
			if rng.randf() < 0.3:
				show.append("chr_casquette")
		elif r < 0.18 and not enfant:
			# boubou (tunique longue en wax ou en bazin uni), pantalon assorti, manches longues
			var tissue := cloth if rng.randf() < 0.6 else plain(SHIRTS[rng.randi() % SHIRTS.size()])
			look["top"] = tissue
			look["cloth"] = tissue
			look["legs"] = tissue
			show.append_array(["chr_boubou", "chr_haut_long", "chr_pantalon", "chr_semelle"])
		elif r < 0.33:
			look["top"] = cloth   # chemise en wax
			show.append_array(["chr_haut_long" if rng.randf() < 0.5 else "chr_haut", "chr_pantalon", "chr_chaussures"])
		elif r < 0.5:
			show.append_array(["chr_haut", "chr_short", "chr_semelle"])
		else:
			show.append_array(["chr_haut" if rng.randf() < 0.7 else "chr_haut_long", "chr_pantalon",
				"chr_chaussures" if rng.randf() < 0.65 else "chr_semelle"])
		var h := rng.randf()
		if h < 0.6:
			show.append("chr_cheveux")
		elif h < 0.8:
			show.append("chr_afro")
		# sinon crane rase
		if kind != "zem" and rng.randf() < 0.18 and not show.has("chr_boubou"):
			show.append("chr_casquette")
	else:
		var r := rng.randf()
		if r < 0.42:
			# pagne et haut uni (ou blouse en wax), foulard souvent assorti
			look["top"] = shirt if rng.randf() < 0.6 else cloth
			show.append_array(["chr_haut", "chr_pagne_long" if rng.randf() < 0.65 else "chr_jupe"])
		elif r < 0.75:
			# ensemble complet en wax (robe)
			look["top"] = cloth
			show.append_array(["chr_haut_long" if rng.randf() < 0.4 else "chr_haut", "chr_pagne_long"])
		else:
			# jean / pantalon et haut
			show.append_array(["chr_haut", "chr_pantalon"])
		show.append("chr_semelle" if rng.randf() < 0.8 else "chr_chaussures")
		var h := rng.randf()
		if h < 0.38:
			show.append_array(["chr_foulard"])
		elif h < 0.55:
			show.append_array(["chr_cheveux", "chr_chignon"])
		elif h < 0.75:
			show.append_array(["chr_cheveux", "chr_tresse"])   # nattes collees sur le crane, pas de crane chauve
		elif h < 0.9:
			show.append_array(["chr_meches"])
		else:
			show.append_array(["chr_afro"])
	return look


static func dress_random(ch: Node, rng: RandomNumberGenerator, kind := "") -> void:
	apply(ch, random_look(ch, rng, kind))
	(ch as Node3D).scale = Vector3.ONE * rng.randf_range(0.97, 1.03)


const SEATED := {"piv_hanche_G": 1.35, "piv_hanche_D": 1.35, "piv_genou_G": -1.45, "piv_genou_D": -1.45,
	"piv_epaule_G": 0.95, "piv_epaule_D": 0.95, "piv_coude_G": 0.45, "piv_coude_D": 0.45, "piv_tronc": -0.25, "piv_tete": 0.12}


static func pose_seated(character: Node) -> void:
	## Pose assise (meme pose que character_anim.gd en mode seated) : moto, tabouret, chaise.
	Squelette.pose(character, SEATED)


static func pose_vendor(character: Node, rng: RandomNumberGenerator) -> void:
	## Assise sur un tabouret, mains sur les genoux, buste un peu penche.
	var a := SEATED.duplicate()
	var arms := rng.randf_range(0.3, 0.9)
	a["piv_epaule_G"] = arms
	a["piv_epaule_D"] = arms
	a["piv_coude_G"] = 0.6
	a["piv_coude_D"] = 0.6
	Squelette.pose(character, a)


static func bake_groups(_ch: Node3D) -> void:
	## Ancien regroupement des pieces rigides : inutile avec un corps a squelette (une piece par vetement).
	pass


static func merge(root: Node3D) -> ArrayMesh:
	## Fusionne tous les MeshInstance3D sous 'root' (deja dans l'arbre) en un seul ArrayMesh, une surface par
	## materiau (materiaux surcharges compris). Les personnages a squelette sont figes dans leur pose actuelle.
	var tools := {}
	var order: Array = []
	for skel in root.find_children("*", "Skeleton3D", true, false):
		(skel as Skeleton3D).force_update_all_bone_transforms()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var mesh: Mesh = mi.mesh
		# sans rendu (tests sans fenetre) le figeage n'est pas possible : pose de repos
		if (mi as MeshInstance3D).skin != null and DisplayServer.get_name() != "headless":
			var baked: Mesh = (mi as MeshInstance3D).bake_mesh_from_current_skeleton_pose()
			if baked:
				mesh = baked
		var xf: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
		for s in mesh.get_surface_count():
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
			(tools[key] as SurfaceTool).append_from(mesh, s, xf)
	var out := ArrayMesh.new()
	for key in order:
		(tools[key] as SurfaceTool).commit(out)
	return out
