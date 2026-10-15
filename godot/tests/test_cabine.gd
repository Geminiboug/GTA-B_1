extends SceneTree
## Entree dans les avions a pied : on monte l'escalier et on entre dans la cabine par la porte avant gauche,
## dans l'epave de la plage puis dans un avion gare au poste (escalier mobile).
## Lancement : godot --headless --path godot --script res://tests/test_cabine.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var fails := 0
var step := 0
var t0 := 0
var goal := Vector3.ZERO
var rel_xf := Transform3D.IDENTITY
var floor_y := 0.0
var label := ""


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _walk_in(bottom: Vector3, landing: Vector3, inside: float, fy: float, name: String) -> void:
	## Place le joueur au pied de l'escalier et le fait marcher vers la porte, puis dans la cabine.
	var d := (landing - bottom) * Vector3(1, 0, 1)
	d = d.normalized()
	player.global_position = bottom - d * 1.2 + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	player.cam_pivot.rotation.y = atan2(-d.x, -d.z)
	goal = landing + d * inside
	floor_y = fy
	label = name
	t0 = frame
	Input.action_press("walk")
	Input.action_press("move_forward")


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 60:
		player = scene.get_node("Player")
		var m0 := scene.find_child("escalier_marche_0", true, false) as Node3D
		var pal := scene.find_child("escalier_palier", true, false) as Node3D
		_check(m0 != null and pal != null, "epave : escalier trouve")
		if m0 == null or pal == null:
			return true
		var a := _center(m0)
		var b := _center(pal)
		_walk_in(a, b, 3.0, b.y, "epave de la plage")
		step = 1
	if step == 1 and frame - t0 == 60 * 9:
		_finish()
		# avion gare : escalier mobile a la porte L1
		var air := scene.get_node("TraficAerien")
		var plane: Node3D = null
		for s in air.stands:
			if s["plane"] != null:
				plane = s["plane"]
				break
		_check(plane != null, "un avion gare au poste")
		if plane == null:
			return true
		var xf := plane.global_transform
		rel_xf = xf
		_walk_in(xf * Vector3(-8.6, 0.1, -15.75), xf * Vector3(-2.55, 2.7, -15.75), 3.0, (xf * Vector3(0, 2.62, 0)).y, "avion au poste")
		step = 2
	if step > 0 and player:
		# vise la porte (le but) en continu, comme un joueur qui corrige sa trajectoire
		var to := goal - player.global_position
		player.cam_pivot.rotation.y = atan2(-to.x, -to.z)
	if step > 0 and (frame - t0) % 60 == 0:
		var probe := KinematicCollision3D.new()
		var fw := (goal - player.global_position) * Vector3(1, 0, 1)
		if player.test_move(player.global_transform.translated(Vector3.UP * 0.2), fw.normalized() * 0.3, probe):
			print("    devant : %s/%s point %s" % [probe.get_collider().get_parent().name, probe.get_collider().name, (rel_xf.affine_inverse() * probe.get_position()).snapped(Vector3.ONE * 0.01)])
		var c := player.get_last_slide_collision()
		print("  %s  pos %s  bloque par %s" % [label, (rel_xf.affine_inverse() * player.global_position).snapped(Vector3.ONE * 0.01), ("%s/%s point %s normale %s" % [c.get_collider().get_parent().name, c.get_collider().name, (rel_xf.affine_inverse() * c.get_position()).snapped(Vector3.ONE * 0.01), c.get_normal().snapped(Vector3.ONE * 0.01)]) if c else "-"])
	if step == 2 and frame - t0 == 60 * 9:
		_finish()
		print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
		return true
	return frame > 60 * 30


func _finish() -> void:
	Input.action_release("move_forward")
	Input.action_release("walk")
	var p := player.global_position
	var flat := Vector2(p.x - goal.x, p.z - goal.z).length()
	_check(absf(p.y - floor_y) < 0.35 and flat < 2.5, "%s : joueur dans la cabine (hauteur %.2f, plancher %.2f, a %.1f m du but)" % [label, p.y, floor_y, flat])


func _center(n: Node3D) -> Vector3:
	var mi := n as MeshInstance3D
	if mi == null:
		mi = n.find_child("*", true, false) as MeshInstance3D
	return mi.global_transform * mi.mesh.get_aabb().get_center() if mi else n.global_position
