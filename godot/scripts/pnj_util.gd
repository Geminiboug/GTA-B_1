class_name PnjUtil
## Personnages (joueur et PNJ) : choix de la morphologie (homme, homme fort, femme, femme ronde, garcon, fille),
## tenues beninoises variees, coiffures, poses fixes et fusion en un seul mesh (vendeurs assis, conducteurs).
## Modeles : godot/assets/models/chr_<variante>.glb (blender/tools/build_character.py), corps anime par squelette.
## Chaque personnage porte meta "genre" (homme / femme) et "age" (adulte / enfant), lus par les dialogues et les reactions.

const VARIANTS := {"homme": "homme", "homme_fort": "homme", "femme": "femme", "femme_ronde": "femme",
	"garcon": "homme", "fille": "femme", "homme_mince": "homme", "femme_mince": "femme", "homme_age": "homme",
	"femme_agee": "femme"}
const HAIR_PARTS := ["chr_cheveux", "chr_cheveux_age", "chr_afro", "chr_chignon", "chr_tresse", "chr_vanille", "chr_meches"]
const WAX := preload("res://shaders/wax.gdshader")
const MAILLOT := preload("res://shaders/maillot.gdshader")
const TISSU := preload("res://shaders/tissu.gdshader")
const CHEVEUX := preload("res://shaders/cheveux.gdshader")
# clubs fictifs (aucun club reel) : [couleur 1, couleur 2, motif]
const CLUBS := [
	[Color(0.1, 0.5, 0.25), Color(0.98, 0.85, 0.15), 0],    # Etoile de Gbe Town
	[Color(0.85, 0.1, 0.12), Color(0.96, 0.96, 0.94), 0],    # Racing Lagune
	[Color(0.1, 0.3, 0.7), Color(0.96, 0.96, 0.94), 1],      # Atlantique FC
	[Color(0.95, 0.55, 0.08), Color(0.08, 0.08, 0.1), 2],    # Union Sportive du Littoral
	[Color(0.96, 0.96, 0.94), Color(0.1, 0.45, 0.25), 1],    # Avenir de Cotodji
	[Color(0.55, 0.1, 0.45), Color(0.98, 0.8, 0.2), 2],      # Dragons de l'Envol
]
const KHAKI := Color(0.72, 0.62, 0.42)

# pieces optionnelles : affichees selon la tenue (le corps chr_corps est toujours visible)
const OPTIONAL := ["chr_haut", "chr_haut_long", "chr_pantalon", "chr_short", "chr_chaussures", "chr_semelle", "chr_jupe",
	"chr_pagne_long", "chr_boubou", "chr_cheveux", "chr_cheveux_age", "chr_afro", "chr_chignon", "chr_tresse", "chr_vanille", "chr_meches", "chr_foulard", "chr_bonnet", "chr_casque",
	"chr_casquette"]

const SHIRTS := [Color(0.85, 0.15, 0.1), Color(0.1, 0.35, 0.75), Color(0.95, 0.95, 0.92), Color(0.1, 0.55, 0.3),
	Color(0.95, 0.55, 0.1), Color(0.55, 0.2, 0.6), Color(0.15, 0.15, 0.15), Color(0.9, 0.8, 0.2), Color(0.95, 0.4, 0.55),
	Color(0.3, 0.65, 0.85), Color(0.92, 0.9, 0.84)]
const PANTS := [Color(0.15, 0.18, 0.3), Color(0.1, 0.1, 0.1), Color(0.45, 0.35, 0.25), Color(0.3, 0.3, 0.32),
	Color(0.22, 0.3, 0.45), Color(0.55, 0.5, 0.42)]
# teintes de peau du Benin : du brun tres fonce au brun moyen (les plus frequentes en double pour le tirage)
const SKINS := [Color(0.2, 0.12, 0.08), Color(0.25, 0.15, 0.1), Color(0.25, 0.15, 0.1), Color(0.3, 0.18, 0.12),
	Color(0.3, 0.18, 0.12), Color(0.34, 0.21, 0.14), Color(0.36, 0.22, 0.15), Color(0.4, 0.26, 0.17),
	Color(0.44, 0.29, 0.2), Color(0.5, 0.34, 0.23)]
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


const PNJ_LAYER := 1 << 4   # couche 5 : corps des personnages (le joueur les heurte, pas les vehicules)


static func make(variant: String, corps := true) -> Node3D:
	## Instance d'une morphologie ("homme", "femme", "homme_fort", "femme_ronde", "garcon", "fille").
	## corps : capsule de collision (couche PNJ_LAYER) : on ne traverse aucun personnage (pas pour le joueur).
	if not VARIANTS.has(variant):
		variant = "homme"
	var ch := (load(scene_path(variant)) as PackedScene).instantiate() as Node3D
	ch.set_meta("genre", VARIANTS[variant])
	ch.set_meta("age", "enfant" if variant in ["garcon", "fille"] else "adulte")
	ch.set_meta("variante", variant)
	# squelette standard : le modele regarde +Z (glTF) ; le jeu suppose -Z (avant du personnage) : demi-tour
	var arm := ch.get_node_or_null("chr_squelette") as Node3D
	if arm and Squelette.find(ch) and Squelette.find(ch).find_bone("Hips") >= 0:
		arm.rotation.y = PI
	ch.set_meta("vieux", variant in ["homme_age", "femme_agee"])
	if corps:
		ajouter_corps(ch)
	return ch


static func ajouter_corps(ch: Node3D) -> void:
	if ch.has_node("Corps"):
		return
	var body := AnimatableBody3D.new()
	body.name = "Corps"
	body.sync_to_physics = false
	body.collision_layer = PNJ_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var enfant: bool = ch.get_meta("age", "adulte") == "enfant"
	cap.radius = 0.2 if enfant else 0.24
	cap.height = 1.2 if enfant else 1.6
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5 + 0.02, 0)
	body.add_child(cs)
	ch.add_child(body)


static func random_genre(rng: RandomNumberGenerator, women_share := 0.5) -> String:
	return "femme" if rng.randf() < women_share else "homme"


static func random_variant(rng: RandomNumberGenerator, genre: String, child_share := 0.0) -> String:
	if rng.randf() < child_share:
		return "fille" if genre == "femme" else "garcon"
	# Cotonou : population jeune (~5 % de plus de 60 ans), beaucoup de silhouettes minces chez les jeunes adultes
	var r := rng.randf()
	if genre == "femme":
		return "femme_agee" if r < 0.07 else ("femme_ronde" if r < 0.4 else ("femme_mince" if r < 0.62 else "femme"))
	return "homme_age" if r < 0.07 else ("homme_fort" if r < 0.27 else ("homme_mince" if r < 0.55 else "homme"))


static func jersey(club: int, scale := 1.0) -> Material:
	## scale : taille du porteur / taille d'un adulte (enfant ~0,76) pour placer bande et epaules.
	var key := "club_%d_%.2f" % [club, scale]
	if not _mat_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = MAILLOT
		var cl: Array = CLUBS[club % CLUBS.size()]
		m.set_shader_parameter("c1", cl[0])
		m.set_shader_parameter("c2", cl[1])
		m.set_shader_parameter("motif", cl[2])
		m.set_shader_parameter("echelle", scale)
		_mat_cache[key] = m
	return _mat_cache[key]


static func uniform_look(kind: String, genre: String, rng: RandomNumberGenerator) -> Dictionary:
	## Uniformes : police fictive (chemise bleu ciel, pantalon et casquette bleu nuit), agent de l'aeroport
	## (gilet jaune fluo, pantalon noir). Visage et peau tires au hasard.
	var skin: Color = SKINS[rng.randi() % SKINS.size()]
	var look := {"skin": skin, "face": random_face(rng)}
	match kind:
		"police":
			var navy := plain(Color(0.08, 0.1, 0.2))
			look.merge({"top": plain(Color(0.55, 0.68, 0.85)), "legs": navy, "cloth": navy, "cap": navy,
				"show": ["chr_haut", "chr_pantalon", "chr_chaussures", "chr_casquette"] + (["chr_cheveux", "chr_chignon"] if genre == "femme" else [])})
		"agent_aeroport":
			var black := plain(Color(0.07, 0.07, 0.08))
			look.merge({"top": plain(Color(0.85, 0.95, 0.12)), "legs": black, "cloth": black,
				"show": ["chr_haut_long", "chr_pantalon", "chr_chaussures", "chr_cheveux"] + (["chr_chignon"] if genre == "femme" else [])})
	return look


static func plain(c: Color, armure := 0, use := 0.0) -> Material:
	## Tissu uni (shaders/tissu.gdshader) : couleur, plis, trame (0 toile de coton, 1 serge de jean, 2 maille), usure.
	var key := "p|%s|%d|%.2f" % [c.to_html(), armure, use]
	if not _mat_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = TISSU
		m.set_shader_parameter("couleur", c)
		m.set_shader_parameter("armure", armure)
		m.set_shader_parameter("use", use)
		_mat_cache[key] = m
	return _mat_cache[key]


static func jean(c: Color) -> Material:
	## Jean : serge diagonale, delave aux cuisses et aux genoux.
	return plain(c, 1, 0.6)


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


static var _face_deltas := {}


static func _deltas(src: ArrayMesh) -> Array:
	## Par surface et par trait : sommets deplaces et deplacements (positions, normales), calcules une fois par modele.
	var key := src.get_rid()
	if _face_deltas.has(key):
		return _face_deltas[key]
	var relative := src.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE
	var per_surface := []
	for sidx in src.get_surface_count():
		var arr := src.surface_get_arrays(sidx)
		var base_v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var base_n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var shapes := src.surface_get_blend_shape_arrays(sidx)
		var per_shape := []
		for b in shapes.size():
			var sv: PackedVector3Array = shapes[b][Mesh.ARRAY_VERTEX]
			var sn: PackedVector3Array = shapes[b][Mesh.ARRAY_NORMAL]
			var idx := PackedInt32Array()
			var dv := PackedVector3Array()
			var dn := PackedVector3Array()
			for i in base_v.size():
				var d: Vector3 = sv[i] if relative else sv[i] - base_v[i]
				if d.length_squared() > 1e-10:
					idx.append(i)
					dv.append(d)
					dn.append((sn[i] if relative else sn[i] - base_n[i]) if sn.size() == base_n.size() else Vector3.ZERO)
			per_shape.append([idx, dv, dn])
		per_surface.append(per_shape)
	_face_deltas[key] = per_surface
	return per_surface


static func bake_face(mi: MeshInstance3D, face: Dictionary) -> void:
	## Traits du visage cuits une fois dans un maillage propre au PNJ (sans morph targets) : aucun cout par image
	## (les morph targets d'un maillage anime sont recalcules a chaque image : -10 images/s dans l'hypermarche).
	var src := mi.mesh as ArrayMesh
	if src == null or src.get_blend_shape_count() == 0:
		return
	var deltas := _deltas(src)
	var out := ArrayMesh.new()
	for sidx in src.get_surface_count():
		var arr := src.surface_get_arrays(sidx)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for b in src.get_blend_shape_count():
			var w := float(face.get(String(src.get_blend_shape_name(b)), 0.0))
			if w <= 0.0:
				continue
			var e: Array = deltas[sidx][b]
			var idx: PackedInt32Array = e[0]
			var dv: PackedVector3Array = e[1]
			var dn: PackedVector3Array = e[2]
			for j in idx.size():
				v[idx[j]] += dv[j] * w
				n[idx[j]] = (n[idx[j]] + dn[j] * w).normalized()
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		# canaux personnalises (attributs en plus du corps sculpte) : inutiles en jeu, leur format n'est pas recopie
		for ci in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[ci] = null
		out.add_surface_from_arrays(src.surface_get_primitive_type(sidx), arr, [], {},
			src.surface_get_format(sidx) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(sidx, src.surface_get_material(sidx))
		out.surface_set_name(sidx, src.surface_get_name(sidx))
	mi.mesh = out


static func random_face(rng: RandomNumberGenerator) -> Dictionary:
	## Traits du visage au hasard (0..1 par morph target) : deux PNJ voisins ne se ressemblent pas.
	var f := {}
	var nose := rng.randf_range(-1.0, 1.0)
	f["nez_large"] = maxf(nose, 0.0)
	f["nez_fin"] = maxf(-nose, 0.0) * 0.8
	for key in ["levres_pleines", "machoire_large", "pommettes", "visage_long", "yeux_grands"]:
		f[key] = clampf(rng.randfn(0.4, 0.3), 0.0, 1.0)
	return f


static func hair_mat(white := 0.0) -> Material:
	## Cheveux noirs ou poivre et sel (white 0..1), relies a gtb_wet (mouilles et brillants sous la pluie).
	var key := "hr_%.2f" % white
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = CHEVEUX
	m.set_shader_parameter("white_share", white)
	_mat_cache[key] = m
	return m


static func salt_pepper(white: float) -> Material:
	return hair_mat(white)


static func skin_mat(c: Color, genre := "homme") -> Material:
	## Peau : texture de detail Quaternius (traits, levres, ongles, ombres ; neutre a 0,75) teintee par la couleur c.
	var key := "s|" + c.to_html() + genre
	if not _mat_cache.has(key):
		var m := StandardMaterial3D.new()
		var tex_path := "res://assets/textures/personnages/peau_detail_%s.png" % ("femme" if genre == "femme" else "homme")
		if ResourceLoader.exists(tex_path):
			m.albedo_texture = load(tex_path)
			m.albedo_color = Color(minf(c.r / 0.75, 1.0), minf(c.g / 0.75, 1.0), minf(c.b / 0.75, 1.0))
		else:
			m.albedo_color = c
		m.roughness = 0.6
		m.metallic_specular = 0.35
		m.rim_enabled = true          # leger reflet de bord : la peau parait moins "plastique"
		m.rim = 0.12
		m.rim_tint = 0.6
		# pas de diffusion sous la peau (subsurf_scatter) : -9 images/s dans l'hypermarche pour un effet invisible a distance
		m.clearcoat_enabled = true                # fine pellicule de transpiration (chaleur), sans effet "plastique"
		m.clearcoat = 0.06
		m.clearcoat_roughness = 0.6
		_mat_cache[key] = m
	return _mat_cache[key]


# familles de pieces (tresse_0..8, foulard + haut + noeud, casquette + visiere, semelles G et D)
const GROUPS := ["chr_tresse", "chr_vanille", "chr_foulard", "chr_casquette", "chr_casque", "chr_bonnet", "chr_semelle"]


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
			# visage : morph targets (build_character.py, FACE_KEYS)
			var face: Dictionary = look.get("face", {})
			if not face.is_empty():
				bake_face(mi as MeshInstance3D, face)
			for s in (mi as MeshInstance3D).mesh.get_surface_count():
				var m: Material = (mi as MeshInstance3D).mesh.surface_get_material(s)
				if m and m.resource_name == "chr_peau":
					(mi as MeshInstance3D).set_surface_override_material(s, skin_mat(look["skin"], String(ch.get_meta("genre", "homme"))))
				elif m and m.resource_name == "chr_cheveux":
					(mi as MeshInstance3D).set_surface_override_material(s, look.get("hair", hair_mat()))
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
		elif n.begins_with("chr_chaussures"):
			mat = look.get("shoes_mat", null)
		elif n == "chr_casque" or n.begins_with("chr_casque_"):
			mat = look.get("helmet", null)
		elif n.begins_with("chr_casquette") or n.begins_with("chr_bonnet"):
			mat = look.get("cap", null)
		elif _starts(n, HAIR_PARTS):
			mat = look.get("hair", hair_mat())
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
	var pc: Color = PANTS[rng.randi() % PANTS.size()]
	var pants := jean(pc) if pc.b > pc.r + 0.08 and rng.randf() < 0.7 else plain(pc)   # bleus : souvent des jeans
	var look := {"skin": skin, "top": shirt, "legs": pants, "cloth": cloth, "show": [],
		"cap": plain(SHIRTS[rng.randi() % SHIRTS.size()].darkened(0.2))}
	var show: Array = look["show"]
	look["face"] = random_face(rng)
	if ch.get_meta("vieux", false):
		look["hair"] = salt_pepper(rng.randf_range(0.35, 0.8))   # poivre et sel, plus ou moins blanchi
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
			if rng.randf() < 0.7:
				# casque jet (obligatoire, porte par la plupart des zemidjans) : blanc, noir, rouge ou bleu
				show.append("chr_casque")
				var hc: Color = [Color(0.92, 0.92, 0.9), Color(0.08, 0.08, 0.09), Color(0.75, 0.1, 0.1), Color(0.1, 0.25, 0.6)][rng.randi() % 4]
				var hm := StandardMaterial3D.new()
				hm.albedo_color = hc
				hm.roughness = 0.25
				look["helmet"] = hm
			elif rng.randf() < 0.4:
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
			if rng.randf() < 0.45:
				look["top"] = jersey(rng.randi() % CLUBS.size(), 0.76 if enfant else 1.0)   # maillot de club (fictif)
		else:
			show.append_array(["chr_haut" if rng.randf() < 0.7 else "chr_haut_long", "chr_pantalon",
				"chr_chaussures" if rng.randf() < 0.65 else "chr_semelle"])
			if show.has("chr_haut") and rng.randf() < 0.12:
				look["top"] = jersey(rng.randi() % CLUBS.size(), 0.76 if enfant else 1.0)
		var h := rng.randf()
		if ch.get_meta("vieux", false):
			# homme age : couronne degarnie (golfes, dessus clairseme), crane rase, ou casquette
			if h < 0.5:
				show.append("chr_cheveux_age")
			elif h > 0.8:
				show.append_array(["chr_cheveux_age", "chr_casquette"])
		elif h < 0.6:
			show.append("chr_cheveux")
		elif h < 0.8:
			show.append("chr_afro")
		# sinon crane rase
		var hat := rng.randf()
		if kind != "zem" and hat < 0.18 and not show.has("chr_boubou"):
			show.append("chr_casquette")
		elif kind != "zem" and hat < 0.23:
			show.append("chr_bonnet")     # bonnet de laine (matins frais, harmattan)
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
		elif h < 0.67:
			show.append_array(["chr_cheveux", "chr_tresse"])   # nattes collees sur le crane, pas de crane chauve
		elif h < 0.79:
			show.append_array(["chr_cheveux", "chr_vanille"])  # vanilles (vrilles torsadees)
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


const PASSENGER := {"piv_hanche_G": 1.35, "piv_hanche_D": 1.35, "piv_genou_G": -1.45, "piv_genou_D": -1.45,
	"piv_epaule_G": 0.3, "piv_epaule_D": 0.3, "piv_coude_G": 1.0, "piv_coude_D": 1.0, "piv_tronc": -0.1, "piv_tete": 0.05}


static func pose_passenger(character: Node) -> void:
	## Passager de zem : assis, mains posees sur les cuisses (jamais les bras a travers le conducteur).
	Squelette.pose(character, PASSENGER)


const DRIVING := {"piv_hanche_G": 1.8, "piv_hanche_D": 1.8, "piv_genou_G": -1.0, "piv_genou_D": -1.0,
	"piv_epaule_G": 0.75, "piv_epaule_D": 0.75, "piv_coude_G": 0.9, "piv_coude_D": 0.9, "piv_tronc": 0.12, "piv_tete": -0.05}


static func pose_driving(character: Node) -> void:
	## Conducteur de voiture : assis bas, cuisses relevees, jambes vers les pedales, mains vers le volant, dossier incline.
	Squelette.pose(character, DRIVING)


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
