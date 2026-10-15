class_name PnjUtil
## Personnages (joueur et PNJ) : choix homme / femme, tenues beninoises variees, poses fixes, regroupement des
## pieces pour l'affichage et fusion en un seul mesh (vendeurs assis).
## Modeles : godot/assets/models/chr_homme.glb et chr_femme.glb (blender/tools/build_character.py).
## Chaque personnage porte meta "genre" = "homme" ou "femme" (lu par les dialogues et reactions des PNJ).

const SCENES := {"homme": "res://assets/models/chr_homme.glb", "femme": "res://assets/models/chr_femme.glb"}
const WAX := preload("res://shaders/wax.gdshader")

# pieces de peau (le reste du visage garde ses materiaux : yeux, levres, sourcils)
const SKIN_PREFIX := ["chr_tete", "chr_cou", "chr_nez", "chr_narine", "chr_oreille", "chr_paupiere", "chr_bras_",
	"chr_avantbras", "chr_main", "chr_pouce", "chr_pied"]
const TOP := ["chr_torse", "chr_manche_G", "chr_manche_D"]
const LEGS_UP := ["chr_bassin", "chr_cuisse_G", "chr_cuisse_D"]
const LEGS_LOW := ["chr_tibia_G", "chr_tibia_D"]
const OPTIONAL := ["chr_boubou", "chr_manche_large", "chr_casquette", "chr_chaussure", "chr_jupe", "chr_pagne_long",
	"chr_chignon", "chr_tresse", "chr_foulard", "chr_cheveux"]

# couleurs courantes : tee-shirts, chemises, pantalons, peaux, et palettes wax (fond, motif, details)
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
static var _vc_mat: StandardMaterial3D


static func make(genre: String) -> Node3D:
	var ch := (load(SCENES[genre]) as PackedScene).instantiate() as Node3D
	ch.set_meta("genre", genre)
	return ch


static func random_genre(rng: RandomNumberGenerator, women_share := 0.5) -> String:
	return "femme" if rng.randf() < women_share else "homme"


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


static func _parts(ch: Node) -> Array:
	return ch.find_children("chr_*", "MeshInstance3D", true, false)


static func _starts(n: String, prefixes: Array) -> bool:
	for p in prefixes:
		if n.begins_with(p):
			return true
	return false


static func apply(ch: Node, look: Dictionary) -> void:
	## Applique une tenue : look = {skin, top, legs_up, legs_low, cloth (materiau wax ou uni), show: [prefixes]}
	for mi in _parts(ch):
		var n := String(mi.name)
		if _starts(n, OPTIONAL):
			mi.visible = _starts(n, look["show"])
		var m: Material = null
		if _starts(n, SKIN_PREFIX):
			m = plain(look["skin"])
		elif n in TOP or n.begins_with("chr_manche_large"):
			m = look["top"]
		elif n in LEGS_UP:
			m = look["legs_up"]
		elif n in LEGS_LOW:
			m = look["legs_low"]
		elif n.begins_with("chr_boubou") or n.begins_with("chr_jupe") or n.begins_with("chr_pagne") or n.begins_with("chr_foulard"):
			m = look["cloth"]
		elif n.begins_with("chr_casquette"):
			m = look.get("cap", null)
		if m:
			mi.set_surface_override_material(0, m)
	if ch.get("femme") != null:
		ch.set("femme", ch.get_meta("genre", "homme") == "femme")


static func random_look(genre: String, rng: RandomNumberGenerator, kind := "") -> Dictionary:
	## Tenue au hasard, realiste pour Cotonou. kind force un style : "zem" (chemise jaune des zemidjans).
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	var pal: Array = WAX_PALETTES[rng.randi() % WAX_PALETTES.size()]
	var cloth := wax(pal, rng.randi() % 4)
	var shirt := plain(SHIRTS[rng.randi() % SHIRTS.size()])
	var pants := plain(PANTS[rng.randi() % PANTS.size()])
	var look := {"skin": skin, "top": shirt, "legs_up": pants, "legs_low": pants, "cloth": cloth, "show": ["chr_cheveux"],
		"cap": plain(SHIRTS[rng.randi() % SHIRTS.size()].darkened(0.2))}
	if genre == "homme":
		var r := rng.randf()
		if kind == "zem":
			look["top"] = plain(Color(0.95, 0.78, 0.1))
			look["show"].append("chr_chaussure")
			if rng.randf() < 0.3:
				look["show"].append("chr_casquette")
		elif r < 0.2:
			# boubou (tunique longue en wax ou en bazin uni) et pantalon assorti
			var tissue := cloth if rng.randf() < 0.6 else plain(SHIRTS[rng.randi() % SHIRTS.size()])
			look["top"] = tissue
			look["cloth"] = tissue
			look["legs_up"] = tissue
			look["legs_low"] = tissue
			look["show"] += ["chr_boubou", "chr_manche_large"]
		elif r < 0.35:
			# chemise en wax
			look["top"] = cloth
			look["show"].append("chr_chaussure")
		elif r < 0.5:
			# short et sandales
			look["legs_low"] = plain(skin)
		else:
			look["show"].append("chr_chaussure")
		if kind != "zem" and rng.randf() < 0.2:
			look["show"].append("chr_casquette")
	else:
		look["legs_up"] = plain(skin)
		look["legs_low"] = plain(skin)
		var r := rng.randf()
		if r < 0.45:
			# pagne + haut uni, foulard du meme wax
			look["show"].append("chr_pagne_long" if rng.randf() < 0.6 else "chr_jupe")
		elif r < 0.8:
			# robe ou ensemble entier en wax
			look["top"] = cloth
			look["show"].append("chr_pagne_long")
		else:
			# jean / pantalon et haut
			look["legs_up"] = pants
			look["legs_low"] = pants
		var h := rng.randf()
		if h < 0.45:
			look["show"] += ["chr_foulard"]
		elif h < 0.7:
			look["show"] += ["chr_chignon"]
		elif h < 0.9:
			look["show"] += ["chr_tresse"]
	return look


static func dress_random(ch: Node, rng: RandomNumberGenerator, kind := "") -> void:
	apply(ch, random_look(ch.get_meta("genre", "homme"), rng, kind))
	var s := rng.randf_range(0.95, 1.05)
	(ch as Node3D).scale = Vector3.ONE * s


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


static func _vertex_color_material() -> StandardMaterial3D:
	if _vc_mat == null:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.vertex_color_is_srgb = true
		_vc_mat.roughness = 0.8
	return _vc_mat


static func _albedo(mat: Material) -> Color:
	if mat is BaseMaterial3D:
		return (mat as BaseMaterial3D).albedo_color
	return Color(0.5, 0.5, 0.5)


static func bake_groups(ch: Node3D) -> void:
	## Regroupe les pieces visibles de chaque pivot en un seul mesh (couleurs dans les sommets, + une surface par
	## tissu wax) : ~12 objets a dessiner par personnage au lieu de ~45, l'animation des pivots reste intacte.
	for piv in [ch] + ch.find_children("*", "Node3D", true, false):
		if piv is MeshInstance3D:
			continue
		var plain_st: SurfaceTool = null
		var special := {}   # materiau shader -> SurfaceTool
		var done: Array = []
		for c in piv.get_children():
			var mi := c as MeshInstance3D
			if mi == null or not String(mi.name).begins_with("chr_"):
				continue
			done.append(mi)
			if not mi.visible:
				continue
			var mat: Material = mi.get_surface_override_material(0)
			if mat == null:
				mat = mi.mesh.surface_get_material(0)
			var arrays := mi.mesh.surface_get_arrays(0)
			var st: SurfaceTool
			if mat is ShaderMaterial:
				if not special.has(mat):
					special[mat] = SurfaceTool.new()
					(special[mat] as SurfaceTool).begin(Mesh.PRIMITIVE_TRIANGLES)
				st = special[mat]
			else:
				if plain_st == null:
					plain_st = SurfaceTool.new()
					plain_st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st = plain_st
				var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var cols := PackedColorArray()
				cols.resize(n)
				cols.fill(_albedo(mat))
				arrays[Mesh.ARRAY_COLOR] = cols
			var tmp := ArrayMesh.new()
			tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			st.append_from(tmp, 0, mi.transform)
		if done.is_empty():
			continue
		var out := ArrayMesh.new()
		if plain_st:
			plain_st.set_material(_vertex_color_material())
			plain_st.commit(out)
		for m in special:
			(special[m] as SurfaceTool).set_material(m)
			(special[m] as SurfaceTool).commit(out)
		for mi in done:
			piv.remove_child(mi)
			mi.queue_free()
		if out.get_surface_count() > 0:
			var lot := MeshInstance3D.new()
			lot.name = "lot_" + String(piv.name)
			lot.mesh = out
			piv.add_child(lot)


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
