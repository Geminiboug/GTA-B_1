extends SceneTree
## Test de l'animation du joueur (anim_ctrl.gd) sur la plage : patinage des pieds a la marche, au trot et au sprint
## (pendant l'appui, le pied pose ne doit presque pas glisser), etats (sol, assis ; pas de pose de chute pour un saut ordinaire), reception apres un saut.
## Lancement : godot --headless --path godot --script res://tests/test_animation.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var skel: Skeleton3D
var fails := 0
var step := 0
var t0 := 0
var prev := {}
var slip := 0.0
var slip_n := 0
var ground := INF
# marche captee (Mixamo) : le pied deroule fortement du talon a la pointe, compte comme un leger glissement
const PHASES := [["marche", "walk", 0.3], ["trot", "", 0.18], ["sprint", "sprint_tap", 0.25]]


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _start() -> void:
	for a in ["move_forward", "sprint", "walk", "jump"]:
		Input.action_release(a)
	scene.get_node("Debug").teleport(2)
	player.velocity = Vector3.ZERO
	player.cam_pivot.rotation.y = PI / 2
	player._facing = PI / 2      # deja tourne vers la course : on mesure la foulee, pas le pas tourne (test_virage)
	player.sprint_level = 0.0
	player.stamina = 1.0
	t0 = frame
	prev = {}
	slip = 0.0
	slip_n = 0
	ground = INF
	if step < PHASES.size():
		if PHASES[step][1] == "walk":
			Input.action_press("walk")
		Input.action_press("move_forward")


func _foot(n: String) -> Vector3:
	var i := skel.find_bone(n)
	return skel.global_transform * skel.get_bone_global_pose(i).origin


func _physics_process(delta: float) -> bool:
	frame += 1
	if frame == 30:
		player = scene.get_node("Player")
		skel = Squelette.find(player.get_node("Body/Model"))
		_check(player.anim != null and player.anim.get_script().resource_path.ends_with("anim_ctrl.gd"), "joueur anime par les clips (anim_ctrl.gd)")
		_start()
		return false
	if frame < 30:
		return false
	var k := frame - t0
	if step < PHASES.size():
		if PHASES[step][1] == "sprint_tap":
			if k % 12 == 0:
				Input.action_press("sprint")
			elif k % 12 == 4:
				Input.action_release("sprint")
		# apres 1,5 s (vitesse etablie) : vitesse horizontale du pied le plus bas pendant l'appui
		if k > 90:
			# point de contact : le plus bas de la cheville et des orteils ; appui = proche du sol et quasi immobile
			# verticalement (sinon on compterait le pied qui frole le sol en revenant vers l'avant)
			for side in ["Left", "Right"]:
				var a := _foot(side + "Foot")
				var b := _foot(side + "Toes")
				var p := a if a.y < b.y else b
				ground = minf(ground, p.y)
				if prev.has(side):
					var q: Vector3 = prev[side]
					var vy := absf(p.y - q.y) / delta
					if p.y < ground + 0.05 and vy < 0.4 + 0.1 * Vector2(player.velocity.x, player.velocity.z).length():
						slip += Vector2(p.x - q.x, p.z - q.z).length() / delta
						slip_n += 1
				prev[side] = p
		if k == 239:
			var ac: Node = player.anim
			print("  motion_scale %.3f  naturel marche %.2f trot %.2f sprint %.2f  position %.2f  echelle %.2f" % [skel.motion_scale, ac._natural.get(ac.loco_clips[1], 0), ac._natural.get(ac.loco_clips[2], 0), ac._natural.get(ac.loco_clips[3], 0), ac._tree.get("parameters/loco/blend_position"), ac._tree.get("parameters/echelle/scale")])
		if k == 240:
			var body := Vector2(player.velocity.x, player.velocity.z).length()
			var s := slip / maxf(slip_n, 1)
			_check(s < body * PHASES[step][2] + 0.15, "%s a %.1f m/s : glissement du pied d'appui %.2f m/s" % [PHASES[step][0], body, s])
			step += 1
			_start()
	elif step == PHASES.size():
		if k == 5:
			Input.action_press("jump")
		if k == 8:
			Input.action_release("jump")
			# saut ordinaire : pas de pose de chute (reservee aux chutes de plus de 0,75 s), les jambes gardent l'allure
			_check(not player.is_on_floor() and player.anim._tree.get("parameters/mode/current_state") != "air", "saut : en l'air sans pose de chute")
		if k == 120:
			_check(player.is_on_floor() and player.anim._tree.get("parameters/mode/current_state") == "sol", "reception : retour a l'etat 'sol'")
			player.anim.seated = true
		if k == 140:
			_check(player.anim._tree.get("parameters/mode/current_state") == "assis", "assis (vehicule) : etat 'assis'")
			player.anim.seated = false
			print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
			return true
	return false
