extends Node3D
## Repartit la vegetation sur la carte au lancement (deterministe : meme resultat a chaque partie).
## - Cocotiers en ligne le long de la plage (cote mer de la promenade), un peu irreguliers.
## - Arbres, buissons et quelques cocotiers dans les espaces libres a terre.
## Jamais sur un batiment, un mur, une route, la piste, le tarmac ou la plage pour les arbres.
## Rendu en MultiMesh (des centaines d'arbres pour un cout tres faible) + collision sur les troncs.

@export var zone_path: NodePath = ^"../zone_aeroport"
@export var models: PackedScene = preload("res://assets/models/vegetation.glb")
@export var area := Rect2(-670, -380, 1340, 760)   # x, z (Godot)
@export var grid_step := 9.0
@export var tree_chance := 0.10
@export var bush_chance := 0.10
@export var inland_palm_chance := 0.03
@export var beach_palm_spacing := 13.0
@export var seed_value := 2026

const ROAD_LAYER := 1 << 9   # couche 10 : surfaces "a eviter", jamais vues par le joueur ni les vehicules
const AVOID := ["route_", "accotement", "zone_parking", "aeroport_", "promenade", "piste_cyclable", "plage", "zone_plage", "zone_piscine", "zone_eau", "abri_toit"]

var _rng := RandomNumberGenerator.new()
var _meshes := {}
var _xforms := {"veg_cocotier": [], "veg_arbre": [], "veg_buisson": []}
var _trunks: StaticBody3D
var _temp_bodies: Array[Node] = []


func _ready() -> void:
	_rng.seed = seed_value
	var inst := models.instantiate()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		_meshes[String(mi.name)] = mi.mesh
	inst.free()
	var zone := get_node_or_null(zone_path)
	if zone == null:
		return
	# les surfaces a eviter sont creees par realism.gd (noeud Realisme) ; attendre qu'elles soient enregistrees
	await get_tree().physics_frame
	await get_tree().physics_frame
	_trunks = StaticBody3D.new()
	_trunks.name = "Troncs"
	add_child(_trunks)
	_scatter_beach_palms(zone)
	_scatter_inland()
	_build_multimeshes()
	print("Vegetation : %d cocotiers, %d arbres, %d buissons" % [_xforms["veg_cocotier"].size(), _xforms["veg_arbre"].size(), _xforms["veg_buisson"].size()])


func _build_avoid_shapes(zone: Node) -> void:
	for mi in zone.find_children("*", "MeshInstance3D", true, false):
		var n := String(mi.name).to_lower()
		for prefix in AVOID:
			if n.begins_with(prefix):
				var body := StaticBody3D.new()
				body.collision_layer = ROAD_LAYER
				body.collision_mask = 0
				var cs := CollisionShape3D.new()
				cs.shape = mi.mesh.create_trimesh_shape()
				body.add_child(cs)
				mi.add_child(body)
				_temp_bodies.append(body)
				break


func _free_spot(p: Vector3, radius: float, allow_beach := false) -> float:
	## Renvoie la hauteur du sol si l'endroit est libre, sinon NAN.
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x, 80, p.z), Vector3(p.x, -10, p.z))
	ray.collision_mask = 1
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return NAN
	var owner_name := String(hit.collider.get_parent().name).to_lower()
	if not owner_name.begins_with("sol_terre"):
		return NAN  # batiment, mur, repere...
	# routes et surfaces a eviter (plage autorisee pour les cocotiers de plage)
	var ray2 := PhysicsRayQueryParameters3D.create(Vector3(p.x, 5, p.z), Vector3(p.x, -2, p.z))
	ray2.collision_mask = ROAD_LAYER
	var hit2 := space.intersect_ray(ray2)
	if not hit2.is_empty():
		var n2 := String(hit2.collider.name).to_lower()
		if not (allow_beach and (n2.begins_with("plage") or n2.begins_with("zone_plage"))):
			return NAN
	# pas de batiment / mur dans le rayon
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, hit.position.y + radius + 0.3, p.z))
	q.collision_mask = 1
	if not space.intersect_shape(q, 1).is_empty():
		return NAN
	return hit.position.y


func _add(kind: String, p: Vector3, y: float, scale_range := Vector2(0.8, 1.2), yaw := -1.0) -> void:
	var s := _rng.randf_range(scale_range.x, scale_range.y)
	var r := yaw if yaw >= 0.0 else _rng.randf_range(0.0, TAU)
	var b := Basis(Vector3.UP, r).scaled(Vector3.ONE * s)
	_xforms[kind].append(Transform3D(b, Vector3(p.x, y, p.z)))
	if kind != "veg_buisson":
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3 * s
		cyl.height = 3.0
		cs.shape = cyl
		cs.position = Vector3(p.x, y + 1.5, p.z)
		_trunks.add_child(cs)


func _scatter_beach_palms(zone: Node) -> void:
	var prom := zone.find_child("promenade", true, false) as MeshInstance3D
	if prom == null:
		return
	var verts: PackedVector3Array = prom.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var pts: Array[Vector3] = []
	for v in verts:
		pts.append(prom.global_transform * v)
	pts.sort_custom(func(a, b): return a.x < b.x)
	var last_x := -INF
	for p in pts:
		if p.x - last_x < beach_palm_spacing:
			continue
		last_x = p.x + _rng.randf_range(-3.0, 3.0)
		# cote mer de la promenade (+Z = sud), parfois deux cocotiers ensemble
		for k in range(1 if _rng.randf() < 0.7 else 2):
			var q := p + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(6.0, 16.0))
			var y := _free_spot(q, 1.0, true)
			if is_nan(y):
				y = q.y if q.y > -0.5 else NAN
			if not is_nan(y):
				# ils penchent vers la mer (le modele penche vers +X Blender = +X Godot)
				_add("veg_cocotier", q, max(y, 0.0), Vector2(0.85, 1.25), PI / 2.0 + _rng.randf_range(-0.6, 0.6))


func _scatter_inland() -> void:
	var x := area.position.x
	while x < area.end.x:
		var z := area.position.y
		while z < area.end.y:
			var p := Vector3(x + _rng.randf_range(-3.5, 3.5), 0, z + _rng.randf_range(-3.5, 3.5))
			var roll := _rng.randf()
			if roll < tree_chance:
				var y := _free_spot(p, 2.2)
				if not is_nan(y):
					_add("veg_arbre", p, y, Vector2(0.75, 1.3))
			elif roll < tree_chance + inland_palm_chance:
				var y := _free_spot(p, 1.0)
				if not is_nan(y):
					_add("veg_cocotier", p, y, Vector2(0.8, 1.15))
			elif roll < tree_chance + inland_palm_chance + bush_chance:
				var y := _free_spot(p, 0.8)
				if not is_nan(y):
					_add("veg_buisson", p, y, Vector2(0.7, 1.4))
			z += grid_step
		x += grid_step


func _build_multimeshes() -> void:
	for kind in _xforms:
		var list: Array = _xforms[kind]
		if list.is_empty() or not _meshes.has(kind):
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[kind]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = kind
		mmi.multimesh = mm
		add_child(mmi)
