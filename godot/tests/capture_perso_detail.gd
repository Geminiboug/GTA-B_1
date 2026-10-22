extends SceneTree
## Captures de detail du joueur : visage, pieds, dos (verification des ameliorations des personnages).
## Lancement (avec fenetre) : godot --path godot --resolution 960x540 --script res://tests/capture_perso_detail.gd -- <dossier>
var frame := 0
var scene: Node
var out_dir := "user://"
var cam: Camera3D
var player: CharacterBody3D
# angle (deg), distance, hauteur camera, hauteur visee
var vues := [[0.0, 0.7, 1.6, 1.56], [35.0, 1.1, 0.45, 0.1], [180.0, 1.5, 1.0, 0.95], [0.0, 1.3, 1.25, 1.2], [60.0, 1.3, 1.25, 1.2]]
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
		cam.fov = 40.0
		scene.add_child(cam)
	if frame > 100:
		for n in scene.get_children():
			if n is CanvasLayer:
				n.visible = false
		var v: Array = vues[mini(k, vues.size() - 1)]
		var b: Basis = player.body.global_transform.basis.orthonormalized()
		var dir := Basis(Vector3.UP, deg_to_rad(v[0])) * (-b.z)
		cam.global_position = player.global_position + dir * v[1] + Vector3(0, v[2], 0)
		cam.look_at(player.global_position + Vector3(0, v[3], 0))
		cam.current = true
	if frame >= 130 and (frame - 130) % 20 == 0 and k < vues.size():
		root.get_viewport().get_texture().get_image().save_png("%s/detail_%d.png" % [out_dir, k])
		k += 1
	if k >= vues.size():
		quit()
		return true
	return false
