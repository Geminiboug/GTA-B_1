extends SceneTree
## Captures : voiture conduite (vue de conduite), circulation, conduite de nuit (phares), passant renverse + bulle.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_vehicules.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var car: Node3D
var out_dir := "user://"
var step := 0
var t0 := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")


func _shot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("veh_%s.png" % name))
	print("capture ", name)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		# berline rouge sur la Route des Peches, le joueur au volant
		car = Vehicules.create("veh_berline", Color(0.75, 0.1, 0.08))
		car.transform = Transform3D(Basis(Vector3.UP, PI / 2.0 + 0.12), Vector3(60, 0.15, 14))
		scene.add_child(car)
		player.enter_vehicle(car)
		Input.action_press("accelerate")
	elif frame == 200:
		Input.action_release("accelerate")
		_shot("conduite")
	elif frame == 230:
		# vue d'une rue avec la circulation (camera du joueur a pied)
		player.exit_vehicle()
		player.global_position = Vector3(420, 1, -20)
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(-0.08, 0.6, 0)
		player.spring_arm.spring_length = 3.0
	elif frame == 330:
		_shot("circulation")
		# un minibus garde de pres
		var bus := Vehicules.create("veh_minibus", Color(0.93, 0.93, 0.9))
		bus.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(425, 0.15, -26))
		scene.add_child(bus)
	elif frame == 420:
		_shot("minibus")
		# nuit : conduite phares allumes
		scene.get_node("JourNuit").hour = 21.0
		player.enter_vehicle(car)
		Input.action_press("accelerate")
	elif frame == 520:
		Input.action_release("accelerate")
	elif frame == 560:
		_shot("nuit")
		scene.get_node("JourNuit").hour = 15.0
		player.exit_vehicle()
		# un passant renverse et en colere
		var peds := scene.get_node("Pietons")
		var w: Dictionary = peds._walkers[2]
		player.global_position = (w["pos"] as Vector3) + Vector3(2.5, 1, 2.5)
		player.reset_physics_interpolation()
		player.cam_pivot.rotation = Vector3(-0.2, PI / 4.0, 0)
		player.spring_arm.spring_length = 2.5
		peds._knock_down(w, Vector2(1.5, 0), "angry")
		w["line_after"] = "renverse"
		w["lie"] = 1.0
		Bulle.say(w["node"], Dialogues.pick("renverse", RandomNumberGenerator.new()), 4.0, 0.7)
	elif frame == 600:
		_shot("renverse")
	elif frame == 700:
		_shot("dispute")
		return true
	return false
