extends SceneTree
## Postures animees vues de profil : marche normale, personne agee (dos voute), porteuse (buste droit, main qui
## stabilise la charge), pieton sous l'averse (main sur la tete).
## Lancement (avec fenetre) : godot --path godot --script res://tests/capture_postures.gd -- <fichier.png>

const ANIM := preload("res://scripts/character_anim.gd")
var frame := 0
var cam: Camera3D
var chars: Array[Node3D] = []


func _initialize() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.74, 0.76)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.82)
	e.ambient_light_energy = 0.6
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(60), 0)
	root.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 32.0
	root.add_child(cam)
	cam.current = true
	var cases := [["homme", {}], ["homme_age", {"posture": 0.16}], ["femme", {"carry_head": true}], ["femme_mince", {"rain_cover": 1.0}]]
	for i in cases.size():
		var ch := PnjUtil.make(cases[i][0])
		ch.set_script(ANIM)
		root.add_child(ch)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5 + i
		PnjUtil.dress_random(ch, rng)
		ch.scale = Vector3.ONE
		ch.position = Vector3(i * 1.3 - 1.95, 0, 0)
		ch.rotation.y = -PI / 2                 # marche vers +X (profil pour la camera)
		ch.set("speed", 1.3 if cases[i][0] != "homme_age" else 1.0)
		ch.set("on_floor", true)
		for k in cases[i][1]:
			ch.set(k, cases[i][1][k])
		chars.append(ch)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 2:
		cam.position = Vector3(0, 1.0, 7.0)
		cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
		cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	if frame == 140:
		root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		print("capture postures")
		return true
	return false
