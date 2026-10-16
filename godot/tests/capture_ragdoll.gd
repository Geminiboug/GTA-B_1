extends SceneTree
## Chute physique (ragdoll) d'un pieton percute par un vehicule, vue de profil, puis releve (LayToIdle).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_ragdoll.gd -- <fichier.png>

var frame := 0
var scene: Node
var cam: Camera3D
var out := "user://ragdoll.png"
var w: Dictionary
var t0 := 0
var shots: Array[Image] = []
const AT := [10, 30, 90, 330]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 10.0)
	cam = Camera3D.new()
	cam.fov = 45.0
	scene.add_child(cam)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 120:
		var peds := scene.get_node("Pietons")
		w = peds._new_walker("homme", Vector2(0, 330))
		w["yaw"] = 0.0
		peds._knock_down(w, Vector2(0, 9.0), "resume")
		t0 = frame
		var p: Vector3 = w["pos"]
		cam.global_position = p + Vector3(7.5, 1.4, 2.8)
		cam.look_at(p + Vector3(0, 0.5, 2.8), Vector3.UP)
		cam.current = true
	if t0 > 0 and (frame - t0) in AT:
		shots.append(root.get_viewport().get_texture().get_image())
		if shots.size() == AT.size():
			var wd := shots[0].get_width()
			var ht := shots[0].get_height()
			var sheet := Image.create(wd * 4, ht, false, shots[0].get_format())
			for i in 4:
				sheet.blit_rect(shots[i], Rect2i(0, 0, wd, ht), Vector2i(wd * i, 0))
			sheet.resize(wd * 2, ht / 2)
			sheet.save_png(out)
			print("capture ragdoll ", w.has("ragdoll"))
			return true
	return frame > 1200
