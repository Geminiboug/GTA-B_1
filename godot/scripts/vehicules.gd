class_name Vehicules
## Fabrique des vehicules : voitures conduisibles (voiture.gd) et zems (scenes/zem.tscn), et versions fusionnees
## en un seul mesh (circulation, voitures garees en MultiMesh). Modeles : blender/tools/build_vehicles.py.

const MODELS := {"veh_berline": "res://assets/models/veh_berline.glb", "veh_4x4": "res://assets/models/veh_4x4.glb",
	"veh_minibus": "res://assets/models/veh_minibus.glb", "veh_pickup": "res://assets/models/veh_pickup.glb",
	"veh_pejo": "res://assets/models/veh_pejo.glb", "veh_mersede": "res://assets/models/veh_mersede.glb"}
## Berlines (memes reglages de camera, de son et d usure que la berline d origine) : Toyoda Koralo, Pejo 460, Mersede 109
const BERLINES := ["veh_berline", "veh_pejo", "veh_mersede"]


static func berline(r: float) -> String:
	## Berline tiree au sort (r entre 0 et 1) : la Koralo domine a Cotonou, puis les vieilles Pejo et Mersede.
	return "veh_berline" if r < 0.55 else ("veh_pejo" if r < 0.8 else "veh_mersede")
const ZEM_SCENE := "res://scenes/zem.tscn"
const CAR_SCRIPT := preload("res://scripts/voiture.gd")
const CAM_SCRIPT := preload("res://scripts/zem_camera.gd")
# reglages par modele (ordres de grandeur des vehicules d'occasion courants a Cotonou) : vitesse max (m/s), adherence,
# roulis, masse (kg), moteur (couple max en N.m, regime du couple max, regime max), boite (rapports, pont), traction
# (part du poids sur les roues motrices), surface de trainee (m2)
const TUNING := {
	"veh_berline": {"max_speed": 46.0, "grip": 0.95, "roll_factor": 0.011, "masse": 1150.0, "couple_max": 140.0,
		"regime_couple": 4000.0, "regime_max": 6200.0, "rapports": [3.45, 1.94, 1.31, 1.03, 0.84], "pont": 4.1,
		"part_motrice": 0.6, "trainee": 0.62, "repartition_avant": 0.61, "hauteur_cg": 0.55},
	"veh_4x4": {"max_speed": 42.0, "grip": 0.85, "roll_factor": 0.016, "masse": 1950.0, "couple_max": 300.0,
		"regime_couple": 2200.0, "regime_max": 4300.0, "rapports": [4.3, 2.4, 1.48, 1.0, 0.79], "pont": 3.9,
		"part_motrice": 1.0, "trainee": 1.05, "repartition_avant": 0.55, "hauteur_cg": 0.78,
		"rigidite_avant": 9.5, "rigidite_arriere": 11.0},
	"veh_minibus": {"max_speed": 33.0, "grip": 0.78, "roll_factor": 0.02, "masse": 1800.0, "couple_max": 210.0,
		"regime_couple": 2400.0, "regime_max": 4500.0, "rapports": [4.5, 2.5, 1.5, 1.0, 0.82], "pont": 4.3,
		"part_motrice": 0.55, "trainee": 1.25, "repartition_avant": 0.5, "hauteur_cg": 0.95,
		"rigidite_avant": 9.0, "rigidite_arriere": 11.0},
	"veh_pickup": {"max_speed": 40.0, "grip": 0.82, "roll_factor": 0.015, "masse": 1650.0, "couple_max": 240.0,
		"regime_couple": 2300.0, "regime_max": 4500.0, "rapports": [4.3, 2.35, 1.45, 1.0, 0.82], "pont": 4.1,
		"part_motrice": 0.45, "trainee": 0.95, "repartition_avant": 0.58, "hauteur_cg": 0.72,
		"rigidite_avant": 10.0, "rigidite_arriere": 11.0},
	"veh_pejo": {"max_speed": 50.0, "grip": 0.97, "roll_factor": 0.011, "masse": 1300.0, "couple_max": 170.0,
		"regime_couple": 4200.0, "regime_max": 6300.0, "rapports": [3.42, 1.81, 1.28, 0.98, 0.77], "pont": 4.06,
		"part_motrice": 0.6, "trainee": 0.65, "repartition_avant": 0.62, "hauteur_cg": 0.55},
	"veh_mersede": {"max_speed": 44.0, "grip": 0.93, "roll_factor": 0.012, "masse": 1250.0, "couple_max": 125.0,
		"regime_couple": 2800.0, "regime_max": 4800.0, "rapports": [3.87, 2.25, 1.44, 1.0, 0.78], "pont": 3.46,
		"part_motrice": 0.47, "trainee": 0.66, "repartition_avant": 0.52, "hauteur_cg": 0.55},
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
	rig.set("follow_height", 1.9 if model_id in BERLINES else 2.4)
	rig.set("base_distance", 6.0 if model_id in BERLINES else 7.0)
	var arm := SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = 6.0
	arm.margin = 0.3
	rig.add_child(arm)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.far = 7000.0
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
