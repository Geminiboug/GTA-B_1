extends SceneTree
## Captures de la tenue de depart du joueur (face, profil, dos) pour la comparer a la planche de reference.
## Lancement (avec fenetre) : godot --path godot --resolution 960x540 --script res://tests/capture_tenue.gd -- <dossier>
var frame := 0
var scene: Node
var out_dir := "user://"
var cam: Camera3D
var player: CharacterBody3D
var angles := [0.0, 90.0, 180.0]
var k := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _physics_process(_d: float) -> bool:
	frame += 1
	if frame == 100:
		player = scene.get_node("Player")
		cam = Camera3D.new()
		scene.add_child(cam)
	if frame > 100:
		for n in scene.get_children():
			if n is CanvasLayer:
				n.visible = false
		var b: Basis = player.body.global_transform.basis.orthonormalized()
		var dir := Basis(Vector3.UP, deg_to_rad(angles[mini(k, 2)])) * (-b.z)
		cam.global_position = player.global_position + dir * 2.4 + Vector3(0, 1.1, 0)
		cam.look_at(player.global_position + Vector3(0, 0.95, 0))
		cam.current = true
	if frame >= 130 and (frame - 130) % 20 == 0 and k < 3:
		root.get_viewport().get_texture().get_image().save_png("%s/tenue_%d.png" % [out_dir, k])
		k += 1
	if k >= 3:
		quit()
		return true
	return false
