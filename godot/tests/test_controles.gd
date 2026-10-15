extends SceneTree
## Test des controles facon GTA V (sur la plage, course le long du rivage) : marche lente, sprint maintenu (sprint
## moyen), sprint en tapotant (plus rapide), endurance a vide (plus de sprint), recentrage de la camera, changement
## de vue (V).
## Lancement : godot --headless --path godot --script res://tests/test_controles.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var step := 0
var t0 := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _reset() -> void:
	## Retour au point de depart sur la plage, a l'arret, camera vers l'ouest (le long du rivage).
	scene.get_node("Debug").teleport(2)
	player.velocity = Vector3.ZERO
	player.sprint_level = 0.0
	player.stamina = 1.0
	player.cam_pivot.rotation.y = PI / 2
	for a in ["move_forward", "sprint", "walk"]:
		Input.action_release(a)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		_reset()
		Input.action_press("walk")
		Input.action_press("move_forward")
		t0 = frame
		step = 1
	elif step == 1 and frame - t0 == 120:
		_check(absf(_speed() - player.walk_speed) < 0.3, "marche lente (Alt / Ctrl) : %.2f m/s (attendu %.1f)" % [_speed(), player.walk_speed])
		_reset()
		Input.action_press("move_forward")
		Input.action_press("sprint")
		t0 = frame
		step = 2
	elif step == 2 and frame - t0 == 150:
		var v := _speed()
		_check(v > player.jog_speed + 0.8 and v < player.sprint_speed - 0.4, "sprint maintenu = sprint moyen : %.2f m/s" % v)
		_reset()
		Input.action_press("move_forward")
		t0 = frame
		step = 3
	elif step == 3:
		# tapoter le sprint toutes les 0,2 s
		var k := frame - t0
		if k % 12 == 0:
			Input.action_press("sprint")
		elif k % 12 == 4:
			Input.action_release("sprint")
		if k == 150:
			var v := _speed()
			_check(v > player.sprint_speed - 0.5, "sprint en tapotant : %.2f m/s (maximum %.1f)" % [v, player.sprint_speed])
			_check(player.stamina < 1.0, "l'endurance baisse au sprint : %.2f" % player.stamina)
			player.stamina = 0.05
		if k == 270:
			var v := _speed()
			_check(v < player.jog_speed + 0.3, "endurance a vide : plus de sprint (%.2f m/s)" % v)
			var diff := absf(angle_difference(player.cam_pivot.rotation.y, player.get("_facing")))
			_check(diff < 0.25, "camera recentree derriere le joueur (ecart %.2f rad)" % diff)
			Input.action_release("sprint")
			Input.action_release("move_forward")
			var e := InputEventAction.new()
			e.action = "camera_vue"
			e.pressed = true
			var before: float = player.spring_arm.spring_length
			player._unhandled_input(e)
			_check(player.spring_arm.spring_length != before, "changement de vue (V) : %.1f -> %.1f m" % [before, player.spring_arm.spring_length])
			print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
			return true
	return false
