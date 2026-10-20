extends SceneTree
## Test des vehicules conduisibles et des reactions des passants.
## 1) berline : 0-100 km/h, freinage, virage (acceleration laterale), frein a main (derapage), choc contre un mur ;
## 2) prendre un vehicule de la circulation (conducteur ejecte) ; prendre une voiture garee ;
## 3) pieton renverse par la voiture du joueur ; coup de poing du joueur.
## Lancement : godot --headless --path godot --script res://tests/test_vehicules.gd

var frame := 0
var scene: Node
var player: CharacterBody3D
var traffic: Node
var peds: Node
var props: Node
var car: Node3D
var fails := 0
var t0 := 0
var mark := {}
var step := 0


func _initialize() -> void:
	scene = load("res://scenes/zone_aeroport.tscn").instantiate()
	root.add_child(scene)
	player = scene.get_node("Player")
	traffic = scene.get_node("Circulation")
	peds = scene.get_node("Pietons")
	props = scene.get_node("Props")


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "ECHEC ") + msg)
	if not ok:
		fails += 1


func _release_all() -> void:
	for a in ["accelerate", "brake", "move_left", "move_right", "handbrake"]:
		Input.action_release(a)


func _kmh() -> float:
	return absf(float(car.get("speed"))) * 3.6


func _physics_process(delta: float) -> bool:
	frame += 1
	if frame > 60 * 160:
		print("ECHEC delai depasse (etape %d)" % step)
		return true
	if frame == 60:
		# piste d'essai : la piste de l'aeroport (longue, droite, degagee)
		var rw: Array = Carte.zone().data["runways"][0]
		var a := Vector2(float(rw[1][0]), float(rw[1][1]))
		var b := Vector2(float(rw[2][0]), float(rw[2][1]))
		var dir := (b - a).normalized()
		car = Vehicules.create("veh_berline", Color(0.8, 0.1, 0.1))
		car.transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.y)), Vector3(a.x, 0.3, a.y))
		scene.add_child(car)
		player.global_position = car.global_position + Vector3(0, 0, 4)
		player.enter_vehicle(car)
		mark["start"] = car.global_position
		Input.action_press("accelerate")
		t0 = frame
	elif step == 0 and frame > 60:
		if _kmh() >= 100.0 or frame - t0 > 60 * 25:
			_check(_kmh() >= 100.0 and (frame - t0) / 60.0 < 16.0, "berline 0-100 km/h en %.1f s" % ((frame - t0) / 60.0))
			Input.action_release("accelerate")
			Input.action_press("brake")
			mark["brake_pos"] = car.global_position
			t0 = frame
			step = 1
	elif step == 1:
		if _kmh() < 1.0 or frame - t0 > 600:
			var d: float = (car.global_position - mark["brake_pos"]).length()
			_check(d > 25.0 and d < 70.0, "freinage 100-0 km/h : %.0f m" % d)
			Input.action_release("brake")
			Input.action_press("accelerate")
			t0 = frame
			step = 2
	elif step == 2:
		if _kmh() > 60.0:
			Input.action_press("move_left")
			mark["yaw"] = car.rotation.y
			t0 = frame
			step = 3
	elif step == 3 and frame - t0 == 90:
		var lat: float = float(car.get("speed")) * float(car.get("_yaw_rate"))
		_check(absf(lat) > 4.0 and absf(lat) < 11.0, "virage a %.0f km/h : acceleration laterale %.1f m/s2 (limite des pneus ~9)" % [_kmh(), absf(lat)])
		Input.action_press("handbrake")
		t0 = frame
		step = 4
	elif step == 4 and frame - t0 == 45:
		var v: Vector2 = car.get("_vel")
		var fwd := Vector2(-sin(car.rotation.y), -cos(car.rotation.y))
		var slip := rad_to_deg(absf(fwd.angle_to(v))) if v.length() > 1.0 else 0.0
		_check(slip > 8.0, "frein a main en virage : derapage de %.0f degres" % slip)
		_release_all()
		step = 5
		t0 = frame
	elif step == 5 and frame - t0 == 120:
		# choc : on lance la voiture contre un batiment
		# batiment fixe (way OSM 418164975) : l'ordre de la liste change quand la zone est reimportee
		var bld: Array = Carte.zone().data["buildings"][0]["pts"]
		for bb in Carte.zone().data["buildings"]:
			if String(bb.get("id", "")) == "418164975":
				bld = bb["pts"]
		var c := Vector2.ZERO
		for q in bld:
			c += Vector2(float(q[0]), float(q[1]))
		c /= bld.size()
		var p0 := c + Vector2(0, 25)
		while Carte.zone().in_building(p0):
			p0.y += 5.0
		car.global_transform = Transform3D(Basis(Vector3.UP, atan2(-(c - p0).x, -(c - p0).y)), Vector3(p0.x, 0.3, p0.y))
		car.set("_yaw", car.rotation.y)
		car.set("_vel", (c - p0).normalized() * 14.0)
		mark["health"] = car.get("health")
		t0 = frame
		step = 6
	elif step == 6 and frame - t0 == 150:
		_check(car.get("health") < mark["health"] and _kmh() < 20.0, "choc a 50 km/h : degats %.0f %%, vitesse apres %.0f km/h" % [mark["health"] - car.get("health"), _kmh()])
		player.exit_vehicle()
		step = 7
		t0 = frame
	elif step == 7 and frame - t0 == 30:
		# prendre un vehicule de la circulation
		var idx := -1
		for a in traffic._agents:
			if a["kind"] == "voiture" and a.get("active", true):
				idx = a["id"]
				break
		var a: Dictionary = traffic._agents[idx]
		a["stunned"] = 30.0
		a["speed"] = 0.0
		var body: Node3D = a["body"]
		player.global_position = body.global_position - body.global_transform.basis.x * 1.4 + Vector3(0, 0.5, 0)
		player.reset_physics_interpolation()
		mark["walkers"] = peds._walkers.size()
		mark["idx"] = idx
		t0 = frame
		step = 8
	elif step == 8 and frame - t0 == 20:
		var v: Node3D = player._nearest_vehicle()
		if v:
			player.enter_vehicle(v)
		var a: Dictionary = traffic._agents[mark["idx"]]
		_check(player.vehicle != null and not a.get("active", true), "vehicule de la circulation pris : %s" % (player.vehicle.get("model_name") if player.vehicle else "aucun"))
		_check(peds._walkers.size() > mark["walkers"] and peds._walkers[-1].get("carjacked", false), "conducteur ejecte (%s, etat %s)" % [peds._walkers[-1]["node"].get_meta("genre"), peds._walkers[-1]["state"]])
		step = 9
		t0 = frame
	elif step == 9 and frame - t0 == 60:
		player.exit_vehicle()
		# voiture garee
		# voiture garee la plus proche (decor par tuile : la premiere de la liste peut etre a l'autre bout de la carte)
		var pk: Dictionary = {}
		var bd := INF
		for i in props.parked.size():
			var d: float = (props.parked[i]["xf"] as Transform3D).origin.distance_to(player.global_position)
			if props.parked[i]["model"] != "zem" and d < bd:
				bd = d
				pk = props.parked[i]
				mark["pk"] = i
		if pk.is_empty():
			t0 += 1      # decor des tuiles encore en file de fond : voitures garees pas encore posees, on attend
			return false
		var xf: Transform3D = pk["xf"]
		player.global_position = xf.origin - xf.basis.x * 1.3 + Vector3(0, 0.5, 0)
		player.reset_physics_interpolation()
		step = 10
		t0 = frame
	elif step == 10 and frame - t0 == 20:
		var v: Node3D = player._nearest_vehicle()
		if v:
			player.enter_vehicle(v)
		_check(player.vehicle != null and props.parked[mark["pk"]].get("taken", false), "voiture garee prise : %s" % (player.vehicle.get("model_name") if player.vehicle else "aucune"))
		# un pieton devant la voiture
		var w: Dictionary = peds._walkers[0]
		var vv: Node3D = player.vehicle
		var front: Vector3 = vv.global_position - vv.global_transform.basis.z * 9.0
		w["pos"] = Vector3(front.x, 0.02, front.z)
		w["state"] = "gather"   # reste plante la (il regarde quelque chose)
		w["state_t"] = 0.0
		w["target"] = Vector2(front.x, front.z) + Vector2(0, 5)
		w["ring"] = Vector2(0, -5)
		w["gather_time"] = 60.0
		mark["w"] = w
		Input.action_press("accelerate")
		step = 11
		t0 = frame
	elif step == 11 and (frame - t0) % 60 == 1:
		var vv: CharacterBody3D = player.vehicle
		var cols := []
		for i in vv.get_slide_collision_count():
			cols.append(String(vv.get_slide_collision(i).get_collider().name) if vv.get_slide_collision(i).get_collider() else "?")
		print("      t=%d vitesse %.1f pos %s sol %s chocs %s rider %s" % [frame - t0, vv.get("speed"), vv.global_position, vv.is_on_floor(), cols, vv.get("has_rider")])
	if step == 11 and (mark["w"]["state"] == "down" or frame - t0 > 300):
		_release_all()
		_check(mark["w"]["state"] == "down", "pieton renverse par la voiture (a %.0f km/h)" % _kmh())
		step = 12
		t0 = frame
	elif step == 12 and frame - t0 == 120:
		var gathered := 0
		for w in peds._walkers:
			if w["state"] == "gather":
				gathered += 1
		print("      attroupement : %d passants viennent voir" % gathered)
		player.exit_vehicle()
		# coup de poing
		var w: Dictionary = peds._walkers[1]
		w["state"] = "gather"
		w["state_t"] = 0.0
		w["target"] = Vector2(w["pos"].x, w["pos"].z) + Vector2(0, -5)
		w["ring"] = Vector2(0, 5)
		w["gather_time"] = 60.0
		player.global_position = (w["pos"] as Vector3) + Vector3(0, 0.5, 1.0)
		player.reset_physics_interpolation()
		player._facing = 0.0
		step = 13
		t0 = frame
	elif step == 13 and frame - t0 == 20:
		var hit: bool = peds.player_attack(player.global_position, Vector3(0, 0, -1))
		var touched := ""
		for w in peds._walkers:
			if (w["pos"] as Vector3).distance_to(player.global_position) < 2.0 and w["state"] in ["down", "stagger"]:
				touched = w["state"]
		_check(hit and touched != "", "coup de poing : le passant touche reagit (%s)" % touched)
		step = 14
		t0 = frame
	elif step == 14 and frame - t0 == 200:
		print("      apres le coup : etat %s" % peds._walkers[1]["state"])
		print("RESULTAT : %s" % ("tout fonctionne" if fails == 0 else "%d echec(s)" % fails))
		return true
	return false
