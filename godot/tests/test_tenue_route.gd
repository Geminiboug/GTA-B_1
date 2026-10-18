extends SceneTree
## Tenue de route au clavier (signalement d'Olympe du 18/10/2026 : les vehicules a 4 roues derapent trop vite) :
## sur la piste, pour chaque modele, comme un joueur au clavier (commandes tout ou rien) :
## 1) virage plein braquage a fond a 60 km/h, 2) lever de pied en plein virage, 3) slalom a 70 km/h.
## La voiture doit rester controlable : derive de la caisse sous 0,3 rad (~17 deg) sans frein a main, pas de tete-a-queue.

const MODELES := ["veh_berline", "veh_4x4", "veh_minibus", "veh_pickup"]
const DERIVE_MAX := 0.3

var frame := 0
var scene: Node
var car: Node3D
var fails := 0
var idx := 0
var t := 0.0
var phase := ""
var max_derive := 0.0
var max_lat := 0.0
var cap0 := 0.0


func _check(ok: bool, msg: String) -> void:
	print(("ok   " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)


func _cmd(gauche: bool, droite: bool, gaz: bool) -> void:
	for a in [["move_left", gauche], ["move_right", droite], ["accelerate", gaz]]:
		if a[1]:
			Input.action_press(a[0])
		else:
			Input.action_release(a[0])


func _spawn() -> void:
	if car:
		car.queue_free()
	var rw: Array = Carte.zone().data["runways"][0]
	var a := Vector2(float(rw[1][0]), float(rw[1][1]))
	var b := Vector2(float(rw[2][0]), float(rw[2][1]))
	var dir := (b - a).normalized()
	car = Vehicules.create(MODELES[idx], Color(0.7, 0.7, 0.7))
	car.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(a.x, 0.3, a.y))
	scene.add_child(car)
	car.call("set_rider", true)
	phase = "elan"
	t = 0.0
	max_derive = 0.0


func _physics_process(d: float) -> bool:
	frame += 1
	if frame == 60:
		scene.get_node("Player").global_position = Vector3(0, -50, 0)
		scene.get_node("Player").set_physics_process(false)
		_spawn()
	if car == null or frame < 62:
		return false
	t += d
	var kmh: float = float(car.get("speed")) * 3.6
	if phase != "elan":
		max_derive = maxf(max_derive, absf(float(car.get("derive"))))
	match phase:
		"elan":
			_cmd(false, false, true)
			if kmh >= 60.0:
				phase = "virage"
				t = 0.0
		"virage":
			_cmd(true, false, true)
			max_lat = maxf(max_lat, absf(float(car.get("_a_lat"))) / 9.8)
			if t > 2.0:
				_check(max_lat > 0.55, "%s : le virage tient encore fort (%.2f g)" % [MODELES[idx], max_lat])
				max_lat = 0.0
				phase = "lever"
				t = 0.0
		"lever":
			_cmd(true, false, false)
			if t > 1.5:
				_check(max_derive < DERIVE_MAX, "%s : virage a fond puis lever de pied, derive max %.2f rad" % [MODELES[idx], max_derive])
				phase = "relance"
				t = 0.0
				max_derive = 0.0
		"relance":
			_cmd(false, false, true)
			max_derive = 0.0
			if kmh >= 70.0 or t > 12.0:
				phase = "slalom"
				t = 0.0
		"slalom":
			var g := int(t / 0.8) % 2 == 0
			_cmd(g, not g, true)
			if t > 4.8:
				_check(max_derive < DERIVE_MAX, "%s : slalom a %.0f km/h, derive max %.2f rad" % [MODELES[idx], kmh, max_derive])
				_cmd(false, false, false)
				idx += 1
				if idx >= MODELES.size():
					print("RESULTAT test_tenue_route : %s" % ("OK" if fails == 0 else "%d ECHEC(S)" % fails))
					quit(1 if fails else 0)
					return true
				_spawn()
	return false
