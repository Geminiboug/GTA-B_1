extends SceneTree
## Planche : escalade d'un muret de 1,2 m (3 temps), joueur accroupi, et PNJ sur les clips captes avec leurs postures
## (personne agee voutee, charge sur la tete, main sur la tete sous la pluie, dispute).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_escalade.gd -- <fichier.png>

var frame := 0
var scene: Node
var player: CharacterBody3D
var cam: Camera3D
var out := "user://escalade.png"
var shots: Array[Image] = []
var fwd := Vector3(-1, 0, 0)
var t0 := 0
var p0 := Vector3.ZERO
var pnj: Array[Node3D] = []
var setups_v: Array = []


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


func _box(center: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	b.add_child(m)
	scene.add_child(b)
	b.global_position = center


func _shot() -> void:
	shots.append(root.get_viewport().get_texture().get_image())


func _side(p: Vector3) -> void:
	cam.global_position = p + Vector3(-0.6, 1.2, 4.2)
	cam.look_at(p + Vector3(-0.6, 0.9, 0), Vector3.UP)
	cam.current = true


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		scene.get_node("Debug").teleport(2)
		player.cam_pivot.rotation.y = PI / 2
		player.set("_facing", PI / 2)
	if frame == 60:
		p0 = player.global_position
		_box(p0 + fwd * 1.55 + Vector3.UP * 0.6, Vector3(2.0, 1.2, 3.0))
		_side(p0)
	if frame == 66:
		Input.action_press("jump")
		t0 = frame
	if frame == 68:
		Input.action_release("jump")
	if t0 > 0 and frame - t0 in [8, 22, 40]:
		_side(p0)
		_shot()
	if frame == 130:
		Input.action_press("crouch")
	if frame == 132:
		Input.action_release("crouch")
	if frame == 160:
		_side(player.global_position)
		_shot()
		# PNJ sur les clips : agee voutee, charge sur la tete, pluie, dispute
		# (crees a part : le script des pietons ecraserait ces reglages a chaque image)
		setups_v = [{"posture": 0.16}, {"carry_head": true}, {"rain_cover": 1.0}, {"gesture": 1.0}]
		var rng := RandomNumberGenerator.new()
		for v in ["homme_age", "femme", "femme_mince", "homme"]:
			var ch := PnjUtil.make(v)
			ch.set_script(load("res://scripts/anim_ctrl.gd"))
			scene.add_child(ch)
			PnjUtil.dress_random(ch, rng)
			pnj.append(ch)
	if frame > 160 and frame < 260:
		for i in pnj.size():
			pnj[i].global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(p0.x + i * 1.3 - 2.0, p0.y, p0.z - 6.0))
			for k in setups_v[i]:
				pnj[i].set(k, setups_v[i][k])
	if frame == 250:
		player.visible = false
		cam.global_position = p0 + Vector3(0, 1.2, -2.0)
		cam.look_at(p0 + Vector3(0, 0.9, -6.0), Vector3.UP)
	if frame == 255:
		_shot()
		var wd := shots[0].get_width()
		var ht := shots[0].get_height()
		var sheet := Image.create(wd * 3, ht * 2, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, wd, ht), Vector2i(wd * (i % 3), ht * (i / 3)))
		sheet.resize(wd * 3 / 2, ht)
		sheet.save_png(out)
		shots[shots.size() - 1].save_png(out.get_basename() + "_pnj.png")
		print("capture escalade")
		return true
	return frame > 1200
