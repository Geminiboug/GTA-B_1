extends Node3D
## Applique les materiaux realistes (shaders proceduraux) a la carte importee, d'apres le nom des objets.
## Garde le pipeline OSM intact : on peut reimporter la zone, les materiaux seront reappliques au lancement.
## - bld_*                         -> facade.gdshader (habitat), bld_terminal (mur-rideau), bld_hangar (bardage)
## - pignon_*, mur_*, parapet...   -> facade.gdshader sans ouvertures ; toit_tole / abri_toit -> tole
## - sol_terre                     -> laterite (sol.gdshader mode 0)
## - zone_plage, plage_*, fond_*   -> sable (mode 1)
## - route_*_bitume, piste...      -> bitume (mode 2) ; route_*_paves (4) ; route_*_terre, accotement (5)
## - aeroport_tarmac (6), promenade (3), marquage / piste cyclable (7), herbe / terre-plein (8), bassins (9)
## - mer                           -> remplacee par une surface subdivisee avec mer.gdshader (vagues)
## Cree aussi les "surfaces a eviter" (couche 10, invisibles pour le joueur) utilisees par la vegetation et
## le mobilier pour ne rien poser sur les routes, la piste, le tarmac, les piscines...

@export var zone_path: NodePath = ^"../zone_aeroport"
@export var sea_rect := Rect2(-720, 300, 1440, 520)   # x, z, largeur, profondeur (Godot)
@export var sea_level := -0.3

const FACADE := preload("res://shaders/facade.gdshader")
const SOL := preload("res://shaders/sol.gdshader")
const MER := preload("res://shaders/mer.gdshader")
const AVOID_LAYER := 1 << 9
const AVOID := ["route_", "accotement", "zone_parking", "aeroport_", "promenade", "piste_cyclable", "plage",
	"zone_plage", "zone_piscine", "zone_eau", "abri_toit"]

var _ground_mats := {}
var _facade_cache := {}


func _ready() -> void:
	var zone := get_node_or_null(zone_path)
	if zone == null:
		push_warning("realism.gd : zone introuvable (%s)" % zone_path)
		return
	var avoid := Node3D.new()
	avoid.name = "SurfacesEvitement"
	add_child(avoid)
	# par paquets de meshes : etapes de la mise en place etalee pendant le chargement (Partie.chantier)
	var meshes := zone.find_children("*", "MeshInstance3D", true, false)
	for debut in range(0, meshes.size(), 40):
		Partie.chantier(func() -> void:
			for mi in meshes.slice(debut, debut + 40):
				_apply(mi)
				_add_avoid(mi, avoid)
				_sol_plage(mi))
	Partie.chantier(_build_sea)


func _add_avoid(mi: MeshInstance3D, parent: Node3D) -> void:
	var n := String(mi.name).to_lower()
	for prefix in AVOID:
		if n.begins_with(prefix):
			var body := StaticBody3D.new()
			body.name = n
			body.collision_layer = AVOID_LAYER
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			cs.shape = mi.mesh.create_trimesh_shape()
			body.add_child(cs)
			body.transform = mi.global_transform
			parent.add_child(body)
			return


func _ground(mode: int, tint := Color(1, 1, 1)) -> ShaderMaterial:
	var key := "%d|%s" % [mode, tint.to_html()]
	if not _ground_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = SOL
		m.set_shader_parameter("mode", mode)
		m.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
		_ground_mats[key] = m
	return _ground_mats[key]


func _orig_color(mi: MeshInstance3D, fallback: Color) -> Color:
	var orig := mi.get_active_material(0)
	return (orig as BaseMaterial3D).albedo_color if orig is BaseMaterial3D else fallback


func _teinte_cotonou(c: Color, n: String) -> Color:
	## Palette des facades d'apres les photos des rues de Cotonou (refs/rues/) : surtout enduit gris, creme, beige ou
	## blanc ; les facades peintes de couleurs vives existent mais restent minoritaires et fanees par le soleil.
	if c.s < 0.22:
		return c
	var h := absi(hash(n))
	if h % 10 < 6:
		var enduits := [Color(0.88, 0.85, 0.78), Color(0.78, 0.78, 0.76), Color(0.84, 0.78, 0.66), Color(0.92, 0.91, 0.88),
			Color(0.7, 0.7, 0.68)]
		return enduits[(h / 10) % enduits.size()]
	return c.lerp(Color(c.v, c.v, c.v), 0.3)


func _facade(color: Color, plain: bool, roof: int, style := 0) -> ShaderMaterial:
	var key := "%s|%s|%d|%d" % [color.to_html(), plain, roof, style]
	if not _facade_cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = FACADE
		m.set_shader_parameter("wall_color", Vector3(color.r, color.g, color.b))
		m.set_shader_parameter("plain_wall", plain)
		m.set_shader_parameter("roof_force", roof)
		m.set_shader_parameter("style", style)
		_facade_cache[key] = m
	return _facade_cache[key]


func _apply(mi: MeshInstance3D) -> void:
	var n := String(mi.name).to_lower()
	var mat: Material = null
	if n.begins_with("bld_terminal"):
		mat = _facade(Color(0.85, 0.85, 0.85), false, 2, 1)
	elif n.begins_with("bld_hangar"):
		mat = _facade(Color(0.72, 0.74, 0.76), false, 1, 2)
	elif n.begins_with("bld_"):
		mat = _facade(_teinte_cotonou(_orig_color(mi, Color(0.85, 0.82, 0.76)), n), false, 0)
	elif n.begins_with("pignon_"):
		mat = _facade(_teinte_cotonou(_orig_color(mi, Color(0.85, 0.82, 0.76)), n), true, 0)
	elif n.begins_with("mur_") or n.begins_with("parapet") or n.begins_with("poteau_attente"):
		# murs d'enceinte, parapets, poteaux : enduit ou parpaings, sans fenetres
		mat = _facade(Color(0.74, 0.7, 0.64), true, 0)
	elif n.begins_with("bandeau") or n.begins_with("balcon"):
		# moulures, dalles et garde-corps de balcon : enduit clair sans ouvertures
		mat = _facade(Color(0.88, 0.87, 0.84), true, 0)
	elif n.begins_with("auvent_console"):
		mat = _facade(Color(0.2, 0.21, 0.23), true, 0)
	elif n.begins_with("toit_tole") or n.begins_with("abri_toit") or n.begins_with("auvent"):
		mat = _facade(Color(0.5, 0.48, 0.46), true, 1)
	elif n.begins_with("sol_terre"):
		mat = _ground(0)
	elif n.begins_with("zone_plage") or n.begins_with("plage") or n.begins_with("fond_marin"):
		mat = _ground(1)
	elif n.begins_with("route_") and n.ends_with("_paves"):
		mat = _ground(4)
	elif (n.begins_with("route_") and n.ends_with("_terre")) or n.begins_with("accotement"):
		mat = _ground(5)
	elif n.begins_with("route_") or n.begins_with("zone_parking") or n in ["aeroport_runway", "aeroport_taxiway", "aeroport_stopway"]:
		mat = _ground(2)
	elif n.begins_with("aeroport_tarmac"):
		mat = _ground(6)
	elif n.begins_with("promenade"):
		mat = _ground(3)
	elif n.begins_with("marquage_taxiway"):
		mat = _ground(7, Color(0.95, 0.75, 0.12))
	elif n.begins_with("marquage_"):
		mat = _ground(7, Color(0.93, 0.93, 0.9))
	elif n.begins_with("piste_cyclable"):
		mat = _ground(7, Color(0.27, 0.5, 0.32))
	elif n.begins_with("terre_plein"):
		# bordures des terre-pleins peintes rouge et blanc (Voie de Fidjrosse, refs/rues/), herbe dessus
		if not _ground_mats.has("terre_plein"):
			_ground_mats["terre_plein"] = _ground(8).duplicate()
			(_ground_mats["terre_plein"] as ShaderMaterial).set_shader_parameter("bordure_peinte", true)
		mat = _ground_mats["terre_plein"]
	elif n.begins_with("zone_herbe") or n.begins_with("zone_humide"):
		mat = _ground(8)
	elif n.begins_with("zone_piscine"):
		mat = _ground(9, Color(0.3, 0.68, 0.78))
	elif n.begins_with("zone_eau"):
		mat = _ground(9, Color(0.3, 0.4, 0.38))
	elif n == "mer":
		mi.visible = false
		return
	if mat:
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, mat)


func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = sea_rect.size
	# ~2 m entre les sommets : assez pour la houle, raisonnable pour le GPU
	plane.subdivide_width = int(sea_rect.size.x / 2.0)
	plane.subdivide_depth = int(sea_rect.size.y / 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = MER
	var sea := MeshInstance3D.new()
	sea.name = "MerAnimee"
	sea.mesh = plane
	sea.material_override = mat
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.position = Vector3(sea_rect.position.x + sea_rect.size.x / 2.0, sea_level, sea_rect.position.y + sea_rect.size.y / 2.0)
	add_child(sea)


func _sol_plage(mi: MeshInstance3D) -> void:
	## Sable de plage sans collision dans l'import (seul l'estran a son -col) : on lui en donne une, sinon joueur et
	## vehicules passent au travers jusqu'au fond marin (Limites, -1,2 m) et butent contre le bord de l'estran.
	if not String(mi.name).to_lower().begins_with("plage") or mi.find_children("*", "StaticBody3D", false, false).size() > 0:
		return
	var body := StaticBody3D.new()
	body.name = "SolPlage"
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	body.add_child(cs)
	mi.add_child(body)
