extends SceneTree
## Captures de profil, de dessus et de face d'un motard PNJ (circulation) et du joueur sur un zem, pour verifier mains au
## guidon, pieds sur les repose-pieds, assise. Lancement (avec fenetre) :
## godot --path godot --resolution 1280x720 --script res://tests/capture_motard.gd -- <dossier>

var frame := 0
var scene: Node
var cam: Camera3D
var out_dir := "user://"
var cible: Dictionary = {}
var n := 0
const VUES := [["profil", Vector3(3.2, 1.2, 0.0)], ["face", Vector3(0.0, 1.3, -6.0)], ["trois_quarts", Vector3(2.4, 1.5, -5.0)], ["dessus", Vector3(0.2, 3.4, 0.4)]]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out_dir = a[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	scene.get_node("JourNuit").set("hour", float(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else 11.0)
	cam = Camera3D.new()
	cam.fov = 45.0
	scene.add_child(cam)


func _process(_d: float) -> bool:
	frame += 1
	if frame < 150:
		return false
	var traf := scene.get_node("Circulation")
	if cible.is_empty():
		for a in traf._agents:
			if a["kind"] == (OS.get_cmdline_user_args()[2] if OS.get_cmdline_user_args().size() > 2 else "zem"):
				cible = a
				break
		for b in traf._agents:
			b["active"] = false
		cible["active"] = true
		cible["speed"] = 0.0
		var pl := scene.get_node("Player") as Node3D
		var p: Vector3 = cible["vis_pos"]
		pl.global_position = Vector3(p.x, 1.0, p.z + 12.0)
		return false
	var k := (frame - 150) % 90
	var i := (frame - 150) / 90
	if i >= VUES.size():
		return true
	var body: Node3D = cible["body"]
	cible["speed"] = 0.0
	cible["stunned"] = 100.0
	if k == 60:
		var v: Vector3 = VUES[i][1]
		var centre := body.global_position + Vector3(0, 0.9, 0)
		cam.global_position = body.global_position + body.global_transform.basis * v
		cam.look_at(centre, Vector3.UP)
		cam.current = true
	elif k == 80:
		root.get_viewport().get_texture().get_image().save_png("%s/motard_%s.png" % [out_dir, VUES[i][0]])
	return false
