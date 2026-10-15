extends SceneTree
## Captures du joueur assis, vu de profil : zem, berline, 4x4, minibus (mains au guidon / volant, pieds en place).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_assis.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var cam: Camera3D
var out_dir := "user://"
var models := ["zem", "veh_berline", "veh_4x4", "veh_minibus"]
var idx := 0
var v: Node3D


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 10.0)
	cam = Camera3D.new()
	cam.fov = 40.0
	scene.add_child(cam)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	player = scene.get_node("Player")
	var k := (frame - 60) % 80
	if k == 0:
		if idx >= models.size():
			return true
		if player.vehicle:
			player.exit_vehicle()
		if v:
			v.queue_free()
		v = Vehicules.create(models[idx], Color(0.75, 0.15, 0.1))
		v.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 320))
		scene.add_child(v)
	elif k == 20:
		player.enter_vehicle(v)
	elif k == 60:
		var c := v.global_position + Vector3(0, 0.9, 0)
		cam.global_position = c + Vector3(-5.5 if models[idx] != "zem" else -3.2, 0.4, 0)
		cam.look_at(c, Vector3.UP)
		cam.current = true
	elif k == 75:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("assis_%s.png" % models[idx]))
		print("capture ", models[idx])
		idx += 1
	return false
