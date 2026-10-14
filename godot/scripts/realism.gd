extends Node3D
## Applique les materiaux realistes (shaders proceduraux) a la carte importee, d'apres le nom des objets.
## Garde le pipeline OSM intact : on peut reimporter la zone, les materiaux seront reappliques au lancement.
## - bld_*                         -> facade.gdshader (fenetres, portes, toits), couleur d'origine conservee
## - sol_terre                     -> terre rouge (sol.gdshader mode 0)
## - zone_plage, plage_*, fond_*   -> sable (mode 1)
## - route_*, aeroport_runway...   -> bitume (mode 2)
## - aeroport_tarmac, promenade    -> beton / paves (mode 3)
## - mer                           -> remplacee par une surface subdivisee avec mer.gdshader (vagues)

@export var zone_path: NodePath = ^"../zone_aeroport"
@export var sea_rect := Rect2(-720, 300, 1440, 520)   # x, z, largeur, profondeur (Godot)
@export var sea_level := -0.3

const FACADE := preload("res://shaders/facade.gdshader")
const SOL := preload("res://shaders/sol.gdshader")
const MER := preload("res://shaders/mer.gdshader")

var _ground_mats := {}


func _ready() -> void:
	var zone := get_node_or_null(zone_path)
	if zone == null:
		push_warning("realism.gd : zone introuvable (%s)" % zone_path)
		return
	for mi in zone.find_children("*", "MeshInstance3D", true, false):
		_apply(mi)
	_build_sea()


func _ground(mode: int) -> ShaderMaterial:
	if not _ground_mats.has(mode):
		var m := ShaderMaterial.new()
		m.shader = SOL
		m.set_shader_parameter("mode", mode)
		_ground_mats[mode] = m
	return _ground_mats[mode]


func _apply(mi: MeshInstance3D) -> void:
	var n := String(mi.name).to_lower()
	var mat: Material = null
	if n.begins_with("bld_"):
		var orig := mi.get_active_material(0)
		var m := ShaderMaterial.new()
		m.shader = FACADE
		if orig is BaseMaterial3D:
			m.set_shader_parameter("wall_color", (orig as BaseMaterial3D).albedo_color)
		mat = m
	elif n.begins_with("mur_"):
		# murs d'enceinte : enduit ciment sans fenetres, salis en bas
		var w := ShaderMaterial.new()
		w.shader = FACADE
		w.set_shader_parameter("plain_wall", true)
		w.set_shader_parameter("wall_color", Color(0.74, 0.7, 0.64))
		mat = w
	elif n.begins_with("sol_terre"):
		mat = _ground(0)
	elif n.begins_with("zone_plage") or n.begins_with("plage") or n.begins_with("fond_marin"):
		mat = _ground(1)
	elif n.begins_with("route_") or n.begins_with("zone_parking") or n in ["aeroport_runway", "aeroport_taxiway", "aeroport_stopway"]:
		mat = _ground(2)
	elif n.begins_with("aeroport_tarmac") or n.begins_with("promenade"):
		mat = _ground(3)
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
