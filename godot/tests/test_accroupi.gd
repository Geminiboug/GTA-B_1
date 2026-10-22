extends SceneTree
## Accroupi et escalade facon GTA V :
## - C (manette R3) accroupit : capsule basse, allure lente ; on ne se releve pas sous un plafond bas ;
## - saut devant un muret de 1,2 m : le joueur l'escalade (clip ClimbUp_1m) et se retrouve debout dessus ;
## - devant un mur de 3,4 m : pas d'escalade (simple saut) ; jusqu'a 2,8 m on se hisse (plus haut que le personnage).
## Lancement : godot --headless --path godot --script res://tests/test_accroupi.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var ground := 0.0
var fwd := Vector3(-1, 0, 0)
var ceiling: StaticBody3D
var wall: StaticBody3D
var start := Vector3.ZERO
var climb_seen := false
var crouch_speed := 0.0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _box(center: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	scene.add_child(b)
	b.global_position = center
	return b


func _face() -> void:
	player.cam_pivot.rotation.y = PI / 2
	player.set("_facing", PI / 2)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		scene.get_node("Debug").teleport(2)
		_face()
	if frame < 60:
		return false
	if frame == 60:
		ground = player.global_position.y
		start = player.global_position
		Input.action_press("crouch")
	if frame == 62:
		Input.action_release("crouch")
		var cap := player.get_node("Collision").shape as CapsuleShape3D
		_check(player.crouched and cap.height < 1.4, "accroupi : capsule %.2f m" % cap.height)
		# plafond bas (1,45 m) au-dessus du joueur accroupi
		ceiling = _box(player.global_position + Vector3.UP * 1.6, Vector3(2, 0.3, 2))
		Input.action_press("move_forward")
	if frame == 120:
		Input.action_release("move_forward")
		crouch_speed = player.get("velocity").length()
	if frame == 125:
		_check(crouch_speed > 0.6 and crouch_speed < 1.5, "allure accroupi %.2f m/s" % crouch_speed)
		ceiling.global_position = player.global_position + Vector3.UP * 1.6
		Input.action_press("crouch")
	if frame == 127:
		Input.action_release("crouch")
		_check(player.crouched, "reste accroupi sous un plafond de 1,45 m")
		ceiling.queue_free()
	if frame == 130:
		Input.action_press("crouch")
	if frame == 132:
		Input.action_release("crouch")
		_check(not player.crouched, "se releve une fois degage")
		# muret de 1,2 m, 2 m de profondeur, face a 0,55 m du centre du joueur
		start = player.global_position
		wall = _box(start + fwd * 1.55 + Vector3.UP * 0.6, Vector3(2.0, 1.2, 3.0))
		_face()
	if frame == 140:
		Input.action_press("jump")
	if frame == 142:
		Input.action_release("jump")
	if frame > 140 and frame < 260 and not (player.get("_climb") as Dictionary).is_empty():
		climb_seen = true
	if frame == 260:
		var h := player.global_position.y - ground
		_check(climb_seen, "escalade declenchee devant le muret")
		_check(absf(h - 1.2) < 0.12 and player.is_on_floor(), "debout sur le muret (%.2f m)" % h)
		var adv := (player.global_position - start).dot(fwd)
		_check(adv > 0.7 and adv < 2.6, "avance sur le muret %.2f m" % adv)
		# mur de 3,4 m : on ne l'escalade pas
		wall.queue_free()
		player.global_position = start
		player.reset_physics_interpolation()
		wall = _box(start + fwd * 1.55 + Vector3.UP * 1.7, Vector3(2.0, 3.4, 3.0))
		climb_seen = false
	if frame == 280:
		Input.action_press("jump")
	if frame == 282:
		Input.action_release("jump")
	if frame > 280 and frame < 330 and not (player.get("_climb") as Dictionary).is_empty():
		climb_seen = true
	if frame == 360:
		_check(not climb_seen and player.global_position.y - ground < 0.3, "mur de 3,4 m : pas d'escalade")
		print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
		return true
	return frame > 900
