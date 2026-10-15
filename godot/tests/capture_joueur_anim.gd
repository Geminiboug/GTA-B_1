extends SceneTree
## Joueur anime par les clips (anim_ctrl.gd) sur la plage, vu de profil : marche, trot, sprint, saut.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_joueur_anim.gd -- <dossier>

var frame := 0
var scene: Node
var player: CharacterBody3D
var cam: Camera3D
var out_dir := ""
var step := 0
var t0 := 0
var shots: Array[Image] = []
const PHASES := [["walk", 90], ["", 110], ["sprint_tap", 130], ["jump", 22]]


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
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
		_start()
	if frame <= 30 or step >= PHASES.size():
		return step >= PHASES.size()
	var k := frame - t0
	var ph: String = PHASES[step][0]
	if ph == "sprint_tap":
		if k % 12 == 0:
			Input.action_press("sprint")
		elif k % 12 == 4:
			Input.action_release("sprint")
	if ph == "jump" and k == 1:
		Input.action_press("jump")
	if ph == "jump" and k == 3:
		Input.action_release("jump")
	# camera de profil qui suit
	var f: float = player.get("_facing")
	var side := Vector3(cos(f), 0, -sin(f))
	cam.global_position = player.global_position + side * 4.2 + Vector3(0, 1.1, 0)
	cam.look_at(player.global_position + Vector3(0, 0.9, 0), Vector3.UP)
	cam.current = true
	if k == PHASES[step][1]:
		shots.append(root.get_viewport().get_texture().get_image())
		print("phase %s : %.2f m/s, au sol %s" % [ph if ph != "" else "trot", Vector2(player.velocity.x, player.velocity.z).length(), player.is_on_floor()])
		step += 1
		if step < PHASES.size():
			_start()
		else:
			var w := shots[0].get_width()
			var h := shots[0].get_height()
			var sheet := Image.create(w * shots.size(), h, false, shots[0].get_format())
			for i in shots.size():
				sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
			sheet.save_png(out_dir.path_join("joueur_anim.png"))
			print("capture joueur_anim")
	return false


func _start() -> void:
	for a in ["move_forward", "sprint", "walk", "jump"]:
		Input.action_release(a)
	scene.get_node("Debug").teleport(2)
	player.velocity = Vector3.ZERO
	player.cam_pivot.rotation.y = PI / 2
	player.sprint_level = 0.0
	player.stamina = 1.0
	t0 = frame
	var ph: String = PHASES[step][0]
	if ph == "walk":
		Input.action_press("walk")
	if ph != "jump" or true:
		Input.action_press("move_forward")
