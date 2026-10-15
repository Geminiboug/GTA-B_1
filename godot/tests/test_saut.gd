extends SceneTree
## Saut realiste (gravite terrestre 9,81 m/s2) : hauteur d'environ 0,5 m, temps en l'air d'environ 0,6 s,
## et pas de longue glissade a la reception : on lache la direction en l'air, l'arret doit etre net.
## Lancement : godot --headless --path godot --script res://tests/test_saut.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var t_jump := 0
var y0 := 0.0
var top := 0.0
var air := 0
var land_pos := Vector3.INF
var landed_at := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		scene.get_node("Debug").teleport(2)
		player.cam_pivot.rotation.y = PI / 2
		Input.action_press("move_forward")
	if frame < 30:
		return false
	if frame == 150:
		# en pleine course (trot, 4,2 m/s) : saut
		y0 = player.global_position.y
		Input.action_press("jump")
		t_jump = frame
	if frame == 153:
		Input.action_release("jump")
	if t_jump > 0 and land_pos == Vector3.INF and frame > t_jump + 1:
		if not player.is_on_floor():
			air += 1
			top = maxf(top, player.global_position.y - y0)
			Input.action_release("move_forward")   # on lache la direction en l'air
		elif air > 3:
			land_pos = player.global_position
			landed_at = frame
	if landed_at > 0 and frame == landed_at + 60:
		var slide := Vector2(player.global_position.x - land_pos.x, player.global_position.z - land_pos.z).length()
		_check(top > 0.35 and top < 0.65, "hauteur du saut %.2f m (humain : 0,4 a 0,6 m)" % top)
		_check(air / 60.0 > 0.45 and air / 60.0 < 0.8, "temps en l'air %.2f s" % (air / 60.0))
		_check(slide < 0.6, "glissade apres la reception %.2f m" % slide)
		print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
		return true
	return frame > 900
