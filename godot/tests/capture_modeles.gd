extends SceneTree
## Captures des modeles de vehicules (realisme, demande d'Olympe du 17/10/2026) : berline, 4x4, minibus, pick-up et zem
## alignes sur la promenade, vus de trois quarts avant et arriere, de jour puis de nuit (phares).
## Lancement (avec fenetre) : godot --path godot --resolution 1600x900 --script res://tests/capture_modeles.gd -- <dossier>

const ZEM := preload("res://scenes/zem.tscn")
var frame := 0
var scene: Node
var out := ""
var cam: Camera3D
var models := [["veh_berline", Color(0.7, 0.08, 0.06)], ["veh_4x4", Color(0.85, 0.85, 0.83)], ["veh_minibus", Color(0.95, 0.8, 0.15)],
	["veh_pickup", Color(0.15, 0.3, 0.55)], ["veh_pejo", Color(0.12, 0.14, 0.18)], ["veh_mersede", Color(0.85, 0.82, 0.7)]]
var nodes: Array[Node3D] = []
const BASE := Vector3(60, 0.2, 8)


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("capture ", name)


func _look(target: Vector3, from: Vector3) -> void:
	cam.global_position = from
	cam.look_at(target, Vector3.UP)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 20:
		scene.get_node("JourNuit").set("hour", 9.5)
		var hud := scene.get_node("HUDJeu") as CanvasLayer
		hud.visible = false
		(scene.get_node("HUD") as CanvasLayer).visible = false
		var p := scene.get_node("Player") as Node3D
		p.global_position = BASE + Vector3(0, 0, 30)
		for i in models.size():
			var v := Vehicules.create(models[i][0], models[i][1])
			v.transform = Transform3D(Basis(Vector3.UP, 0.0), BASE + Vector3(i * 4.5, 0.3, 0))
			scene.add_child(v)
			nodes.append(v)
		var z := ZEM.instantiate() as Node3D
		z.transform = Transform3D(Basis(Vector3.UP, 0.0), BASE + Vector3(models.size() * 4.5, 0.3, 0))
		scene.add_child(z)
		nodes.append(z)
		cam = Camera3D.new()
		scene.add_child(cam)
		cam.current = true
		cam.fov = 50
	if frame < 120:
		return false
	var k := (frame - 120) / 25
	if (frame - 120) % 25 == 0 and k < nodes.size() * 2:
		var n := nodes[k / 2]
		var c := n.global_position + Vector3(0, 0.7, 0)
		var d := 5.5 if k / 2 < models.size() else 3.0
		_look(c, c + (Vector3(d * 0.75, 1.0, -d * 0.8) if k % 2 == 0 else Vector3(-d * 0.8, 1.2, d * 0.75)))
	if (frame - 120) % 25 == 20 and k < nodes.size() * 2:
		_shot("modele_%d_%s" % [k / 2, "avant" if k % 2 == 0 else "arriere"])
	if frame == 120 + nodes.size() * 50:
		scene.get_node("JourNuit").set("hour", 21.0)
		for n in nodes:
			if n.has_method("set_rider"):
				n.set("speed", 0.01)
		var c := nodes[0].global_position + Vector3(0, 0.7, 0)
		_look(c, c + Vector3(3.0, 1.2, -6.5))
	if frame == 120 + nodes.size() * 50 + 60:
		_shot("modele_nuit")
		return true
	return false
