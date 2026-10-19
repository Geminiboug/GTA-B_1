extends SceneTree
## Captures du trafic aerien : avions gares, repoussage, roulage, alignement, rotation, envol (train qui rentre),
## approche, arrondi, toucher, inverseurs, arrivee au poste.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_avion.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var air: Node
var cam: Camera3D
var out_dir := "user://"
var done := {}
var stage := 0
var hold := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	air = scene.get_node("TraficAerien")
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 7000.0
	scene.add_child(cam)
	scene.get_node("JourNuit").set("hour", 9.5)
	if args.size() > 1 and args[1] == "arrivee":
		stage = 3


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("avion_%s.png" % name))
	print("capture ", name)
	done[name] = true


func _look(p: Node3D, local_cam: Vector3, local_target := Vector3(0, 3, 0)) -> void:
	var xf := p.global_transform
	var flat := Transform3D(Basis(Vector3.UP, xf.basis.get_euler().y), xf.origin)
	cam.global_position = flat * local_cam
	cam.look_at(flat * local_target, Vector3.UP)
	cam.current = true


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 40:
		return false
	var mv: Dictionary = air.mv
	match stage:
		0:
			# avions gares : vue de l'aire de stationnement
			var st: Dictionary = air.stands[0]
			var at: Vector2 = st["pos"]
			cam.global_position = Vector3(at.x, 0, at.y) + Vector3(-60, 14, -35)
			cam.look_at(Vector3(at.x, 2, at.y), Vector3.UP)
			cam.current = true
			hold += 1
			if hold == 30:
				_shot("gares")
				var k := -1
				for i in air.stands.size():
					if air.stands[i]["plane"] != null:
						k = i
				air.start_departure(k, "06")
				stage = 1
				hold = 0
		1:
			var p: Node3D = mv.get("plane")
			if p == null:
				return false
			var ph: String = mv["phase"]
			Engine.time_scale = 1.0 if (ph == "repoussage" and mv["t"] > 20.0 and not done.has("repoussage")) else 6.0
			if ph == "repoussage" and mv["t"] > 22.0 and not done.has("repoussage"):
				_look(p, Vector3(-22, 4, -26))
				hold += 1
				if hold > 4:
					_shot("repoussage")
					hold = 0
			elif ph == "roulage" and not done.has("roulage") and (air.to_rw(mv["pos"]) as Vector2).x < 640.0 and (air.to_rw(mv["pos"]) as Vector2).y < 40.0:
				Engine.time_scale = 1.0
				_look(p, Vector3(45, 6, -20))
				hold += 1
				if hold > 4:
					_shot("roulage")
					hold = 0
			elif ph == "alignement" and mv["t"] > 6.0 and not done.has("alignement"):
				Engine.time_scale = 1.0
				_look(p, Vector3(-30, 4, 45), Vector3(0, 3, -10))
				hold += 1
				if hold > 4:
					_shot("alignement")
					hold = 0
			elif ph == "course" and mv["speed"] > 71.0 and not done.has("rotation"):
				Engine.time_scale = 1.0
				_look(p, Vector3(-70, 3, -10))
				hold += 1
				if hold > 2:
					_shot("rotation")
					hold = 0
			elif ph == "envol" and mv["h"] > 25.0 and not done.has("envol"):
				Engine.time_scale = 1.0
				_look(p, Vector3(-70, -12, -40), Vector3(0, 2, 0))
				hold += 1
				if hold > 2:
					_shot("envol")
					hold = 0
		2:
			var p2: Node3D = mv.get("plane")
			if p2 == null:
				return false
			var ph2: String = mv["phase"]
			Engine.time_scale = 6.0
			if ph2 == "approche" and mv["h"] < 70.0 and not done.has("approche"):
				Engine.time_scale = 1.0
				_look(p2, Vector3(-40, -15, -120), Vector3(0, 2, 0))
				hold += 1
				if hold > 2:
					_shot("approche")
					hold = 0
			elif ph2 == "arrondi" and mv["h"] < 4.0 and not done.has("arrondi"):
				Engine.time_scale = 1.0
				_look(p2, Vector3(-55, 1.5, -20))
				hold += 1
				if hold > 8:
					_shot("arrondi")
					hold = 0
			elif ph2 == "roulement" and mv["t"] > 4.0 and not done.has("inverseurs"):
				Engine.time_scale = 1.0
				_look(p2, Vector3(-16, 3, 4), Vector3(-5.75, 1.5, 0))
				hold += 1
				if hold > 8:
					_shot("inverseurs")
					hold = 0
			elif ph2 == "arret" and not done.has("poste"):
				Engine.time_scale = 1.0
				_look(p2, Vector3(-35, 8, -40))
				hold += 1
				if hold > 4:
					_shot("poste")
					hold = 0
	if stage == 3 and frame > 60:
		air.start_arrival("06")
		stage = 2
	if stage == 1 and mv.is_empty() and done.has("envol"):
		air.start_arrival("06")
		stage = 2
	if stage == 2 and done.has("poste"):
		Engine.time_scale = 1.0
		return true
	if frame > 60 * 60 * 25:
		print("delai depasse")
		Engine.time_scale = 1.0
		return true
	return false
