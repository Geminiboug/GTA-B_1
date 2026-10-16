extends SceneTree
## Saut en courant filme image par image (toutes les 4 images de physique, de l'appel a 1 s apres la reception),
## vu de profil, avec la vitesse et le clip en cours : sert a voir la reception (glissade, pose).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_saut_seq.gd -- <dossier> [marche|trot|sprint|arret]

var frame := 0
var scene: Node
var player: CharacterBody3D
var cam: Camera3D
var out_dir := ""
var allure := "trot"
var t0 := 0
var jump_at := 90
var cycle := false        # sans saut : la foulee seule (toutes les 3 images)
var shots: Array[Image] = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0]
	if args.size() > 1:
		allure = args[1]
	if args.size() > 2 and args[2] == "cycle":
		cycle = true
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", 10.0)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		cam = Camera3D.new()
		cam.fov = 40.0
		scene.add_child(cam)
		scene.get_node("Debug").teleport(2)
		player.velocity = Vector3.ZERO
		player.cam_pivot.rotation.y = PI / 2
		player.stamina = 1.0
		t0 = frame
		if allure != "arret":
			Input.action_press("move_forward")
		if allure == "marche":
			Input.action_press("walk")
	if frame <= 30:
		return false
	var k := frame - t0
	if allure == "sprint" and k < jump_at:
		if k % 12 == 0:
			Input.action_press("sprint")
		elif k % 12 == 4:
			Input.action_release("sprint")
	if k == jump_at and not cycle:
		Input.action_press("jump")
	if k == jump_at + 2:
		Input.action_release("jump")
	var f: float = player.get("_facing")
	var side := Vector3(cos(f), 0, -sin(f))
	cam.global_position = player.global_position + side * 4.2 + Vector3(0, 1.1, 0)
	cam.look_at(player.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	cam.current = true
	if k >= jump_at and (k - jump_at) % (3 if cycle else 4) == 0 and shots.size() < 24:
		var img := root.get_viewport().get_texture().get_image()
		img.resize(img.get_width() / 3, img.get_height() / 3)
		shots.append(img)
		var tr: AnimationTree = player.anim.get("_tree")
		print("t=%.2f s  v=%.2f m/s  sol=%s  reception=%s  impulsion=%s  mode=%s" % [(k - jump_at) / 60.0,
			Vector2(player.velocity.x, player.velocity.z).length(), player.is_on_floor(),
			tr.get("parameters/reception/active"), tr.get("parameters/impulsion/active"), tr.get("parameters/mode/current_state")])
	if shots.size() == 24:
		var w := shots[0].get_width()
		var h := shots[0].get_height()
		var sheet := Image.create(w * 6, h * 4, false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % 6) * w, (i / 6) * h))
		sheet.save_png(out_dir.path_join(("cycle_%s.png" if cycle else "saut_%s.png") % allure))
		print("capture saut_%s" % allure)
		return true
	return false
