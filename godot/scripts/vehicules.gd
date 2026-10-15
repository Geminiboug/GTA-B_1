class_name Vehicules
## Fabrique des vehicules : voitures conduisibles (voiture.gd) et zems (scenes/zem.tscn), et versions fusionnees
## en un seul mesh (circulation, voitures garees en MultiMesh). Modeles : blender/tools/build_vehicles.py.

const MODELS := {"veh_berline": "res://assets/models/veh_berline.glb", "veh_4x4": "res://assets/models/veh_4x4.glb",
	"veh_minibus": "res://assets/models/veh_minibus.glb"}
const ZEM_SCENE := "res://scenes/zem.tscn"
const CAR_SCRIPT := preload("res://scripts/voiture.gd")
const CAM_SCRIPT := preload("res://scripts/zem_camera.gd")
# reglages par modele : vitesse max (m/s), acceleration, adherence, roulis
const TUNING := {
	"veh_berline": {"max_speed": 46.0, "engine_accel": 4.3, "grip": 0.95, "roll_factor": 0.011},
	"veh_4x4": {"max_speed": 42.0, "engine_accel": 4.2, "grip": 0.85, "roll_factor": 0.016},
	"veh_minibus": {"max_speed": 33.0, "engine_accel": 3.0, "grip": 0.78, "roll_factor": 0.02},
}

static var _merged := {}


static func create(model_id: String, color: Color) -> Node3D:
	## Vehicule conduisible pret a placer (pas encore dans l'arbre).
	if model_id == "zem":
		return (load(ZEM_SCENE) as PackedScene).instantiate()
	var car := CharacterBody3D.new()
	car.set_script(CAR_SCRIPT)
	car.name = "Voiture"
	car.add_to_group("vehicules")
	car.floor_snap_length = 0.5
	car.safe_margin = 0.02
	var model := (load(MODELS[model_id]) as PackedScene).instantiate() as Node3D
	var aabb := _model_aabb(model)
	car.setup(model, model_id, color)
	for k in TUNING[model_id]:
		car.set(k, TUNING[model_id][k])
	# collision : du sol (les roues portent la voiture) au toit, sans les retroviseurs
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(aabb.size.x - 0.2, aabb.size.y - 0.04, aabb.size.z - 0.1)
	cs.shape = box
	cs.position = Vector3(0, aabb.position.y + 0.02 + box.size.y / 2.0, aabb.get_center().z)
	car.add_child(cs)
	# camera de conduite (meme que le zem), plus haute et plus loin
	var rig := Node3D.new()
	rig.name = "CamRig"
	rig.set_script(CAM_SCRIPT)
	rig.set("follow_height", 1.9 if model_id == "veh_berline" else 2.4)
	rig.set("base_distance", 6.0 if model_id == "veh_berline" else 7.0)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 6.0
	arm.margin = 0.3
	rig.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.far = 3000.0
	arm.add_child(cam)
	car.add_child(rig)
	return car


static func _model_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var xf := _rel(n, mi)
		var a: AABB = xf * (mi as MeshInstance3D).mesh.get_aabb()
		out = a if first else out.merge(a)
		first = false
	return out


static func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != root and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func merged(model_id: String) -> ArrayMesh:
	## Le vehicule entier fusionne en un mesh (une surface par materiau), pour les MultiMesh et la circulation.
	if _merged.has(model_id):
		return _merged[model_id]
	var root := (load(MODELS[model_id]) as PackedScene).instantiate() as Node3D
	var tools := {}
	var order: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var xf := _rel(root, mi)
		for s in (mi as MeshInstance3D).mesh.get_surface_count():
			var m: Material = (mi as MeshInstance3D).mesh.surface_get_material(s)
			var key := m.resource_name if m else "aucun"
			if not tools.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				st.set_material(m)
				tools[key] = st
				order.append(key)
			(tools[key] as SurfaceTool).append_from((mi as MeshInstance3D).mesh, s, xf)
	var out := ArrayMesh.new()
	for key in order:
		(tools[key] as SurfaceTool).commit(out)
	root.free()
	_merged[model_id] = out
	return out
