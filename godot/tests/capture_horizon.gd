extends SceneTree
## Captures vers les bords de la carte (ce que voit le joueur au loin) et le long de la piste.
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_horizon.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var cam: Camera3D
var out_dir := "user://"
# [nom, position camera, point vise]
var shots := [
	["nord", Vector3(0, 2.0, -360), Vector3(0, 2.0, -800)],
	["est", Vector3(650, 2.0, 0), Vector3(1200, 2.0, 0)],
	["ouest", Vector3(-650, 2.0, 0), Vector3(-1200, 2.0, 0)],
	["piste_seuil", Vector3(-640, 3.0, -40), Vector3(-224, 0.0, -386)],
	["piste_cote", Vector3(-380, 2.0, -200), Vector3(-460, 0.0, -340)],
	["aeroport_haut", Vector3(-300, 120.0, 150), Vector3(-420, 0.0, -300)],
	["plage_haut", Vector3(0, 60.0, 200), Vector3(0, 0.0, 480)],
	["plage_sol", Vector3(100, 1.7, 360), Vector3(100, 1.0, 600)],
	["plage_est", Vector3(600, 1.7, 250), Vector3(1400, 1.0, 400)],
	["piste_loin", Vector3(-560, 6.0, -120), Vector3(400, 0.0, -1000)],
	["approche_nuit", Vector3(-1500, 46.0, 575), Vector3(-619, 0.0, -89)],
	["approche_jour", Vector3(-1500, 46.0, 575), Vector3(-619, 0.0, -89)],
]
var idx := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 7000.0
	scene.add_child(cam)
	scene.get_node("JourNuit").set("hour", 10.0)


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	var local := frame - 60 - idx * 40
	if local == 0:
		var s = shots[idx]
		scene.get_node("JourNuit").set("hour", 21.0 if String(s[0]).ends_with("nuit") else 10.0)
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.current = true
		(scene.get_node("Player") as Node3D).global_position = (s[1] as Vector3) + Vector3(0, 50, 0)
	elif local == 30:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("horizon_%s.png" % shots[idx][0]))
		print("capture ", shots[idx][0])
		idx += 1
		if idx >= shots.size():
			return true
	return false
