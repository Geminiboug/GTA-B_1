extends SceneTree
## Captures des lieux a interieur : maison du joueur (cour, salon, chambre, la nuit), Ararat Hypermarket (facade,
## entree, rayon) et terminal de l'aeroport (facade, hall, comptoirs).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_lieux.gd -- <dossier_sortie>

var frame := 0
var scene: Node
var player: CharacterBody3D
var day: Node
var cam: Camera3D
var out_dir := "user://"
var step := 0
var shots := ["maison_cour", "maison_salon", "maison_chambre", "maison_nuit", "ararat_facade", "ararat_entree",
	"ararat_rayon", "ararat_caisses", "terminal_facade", "terminal_hall", "terminal_comptoirs"]
const PER_SHOT := 110


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	day = scene.get_node("JourNuit")
	cam = Camera3D.new()
	cam.fov = 62.0
	scene.add_child(cam)


func _marker(lieu: String, n: String) -> Node3D:
	return scene.get_node("Lieux/Lieu_" + lieu).find_child(n, true, false) as Node3D


func _house(bx: float, by: float, bz: float) -> Vector3:
	## Point du repere Blender de la maison (x, y, z) -> monde Godot.
	var r := _marker("maison", "maison_racine")
	return r.global_transform * Vector3(bx, bz, -by)


func _shoot(from: Vector3, to: Vector3, player_at: Vector3) -> void:
	player.global_position = player_at + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	cam.global_position = from
	cam.look_at(to, Vector3.UP)
	cam.current = true


func _door_frame(lieu: String) -> Array:
	## Milieu de la porte automatique, direction vers l'exterieur (vers l'enseigne), direction le long de la facade.
	var g := _marker(lieu, "porte_coulissante_%s_g" % lieu).global_position
	var d := _marker(lieu, "porte_coulissante_%s_d" % lieu).global_position
	var mid := (g + d) * 0.5
	var sign_pos := _marker(lieu, "texte_%s_enseigne" % lieu).global_position
	var out := Vector3(sign_pos.x - mid.x, 0, sign_pos.z - mid.z).normalized()
	return [mid, out, (d - g).normalized()]


func _setup_shot(name: String) -> void:
	day.set("hour", 21.5 if name == "maison_nuit" else 10.5)
	var by0 := 0.3
	var by1 := 7.9
	match name:
		"maison_cour":
			_shoot(_house(-2.2, -7.6, 1.8), _house(0.5, by0 + 1.0, 1.6), _house(-1.0, -6.0, 0.1))
		"maison_salon":
			_shoot(_house(0.5, by0 + 0.8, 1.65), _house(-4.0, by1 - 1.0, 0.7), _house(-1.5, by0 + 1.5, 0.1))
		"maison_chambre":
			_shoot(_house(3.9, by0 + 3.95, 1.75), _house(2.3, by1 - 1.0, 0.45), _house(4.4, by0 + 2.9, 0.1))
		"maison_nuit":
			_shoot(_house(-2.2, -7.6, 1.8), _house(0.5, by0 + 1.0, 1.6), _house(-1.0, -6.0, 0.1))
		"ararat_facade", "terminal_facade":
			var lieu := name.split("_")[0]
			var f := _door_frame(lieu)
			var mid: Vector3 = f[0]
			var out: Vector3 = f[1]
			var along: Vector3 = f[2]
			_shoot(mid + out * 16.0 + along * 6.0 + Vector3(0, 2.0, 0), mid + Vector3(0, 4.0, 0), mid + out * 2.0)
		"ararat_entree", "terminal_hall":
			var lieu := name.split("_")[0]
			var f := _door_frame(lieu)
			var mid: Vector3 = f[0]
			var out: Vector3 = f[1]
			var along: Vector3 = f[2]
			_shoot(mid - out * 2.5 + along * 3.0 + Vector3(0, 2.3, 0), mid - out * 22.0 - along * 4.0 + Vector3(0, 1.2, 0), mid - out * 1.0 + along * 4.5)
		"ararat_rayon":
			var lieu := _marker("ararat", "pnj_vigile_entree").get_parent()
			var a: Node3D = null
			var b: Node3D = null
			for row in range(6, 30):
				a = lieu.find_child("pnj_chemin_%d_11" % row, true, false)
				b = lieu.find_child("pnj_chemin_%d_22" % row, true, false)
				if a and b:
					break
			if a and b:
				var back := (a.global_position - b.global_position).normalized()
				_shoot(a.global_position + Vector3(0, 1.65, 0) + back * 0.8, b.global_position + Vector3(0, 1.0, 0), a.global_position + back * 1.8)
		"ararat_caisses":
			var f := _door_frame("ararat")
			var out: Vector3 = f[1]
			var along: Vector3 = f[2]
			var cs := _marker("ararat", "pnj_caisse_2")
			var fl := _marker("ararat", "pnj_file_2")
			if cs and fl:
				_shoot(fl.global_position - out * 4.0 + along * 2.0 + Vector3(0, 2.0, 0), cs.global_position + Vector3(0, 1.0, 0),
					fl.global_position - out * 5.5 + along * 2.0)
		"terminal_comptoirs":
			var c0 := _marker("terminal", "pnj_comptoir_0")
			var f := _door_frame("terminal")
			var out: Vector3 = f[1]
			var along: Vector3 = f[2]
			if c0:
				var p := c0.global_position
				_shoot(p + out * 9.0 + along * 7.0 + Vector3(0, 2.0, 0), p + Vector3(0, 1.2, 0), p + out * 6.0)


func _physics_process(_delta: float) -> bool:
	frame += 1
	if frame < 60:
		return false
	var local := frame - 60 - step * PER_SHOT
	if local == 0:
		_setup_shot(shots[step])
	elif local == PER_SHOT - 10:
		root.get_viewport().get_texture().get_image().save_png(out_dir.path_join("lieu_%s.png" % shots[step]))
		print("capture ", shots[step])
		step += 1
		if step >= shots.size():
			return true
	return false
