extends CharacterBody3D
## Avion leger pilotable (demande d'Olympe du 21/10/2026 : piloter des avions, d'abord de petits appareils) : le "Gbe Aero
## Colibri C-4", monomoteur a aile haute, 4 places, train tricycle fixe (modele : blender/tools/build_avion_leger.py).
## Modele de vol simplifie mais coherent : poussee de l'helice, portance (angle d'attaque, decrochage vers 16 degres),
## trainee, poids, gouvernes qui suivent le manche ; au sol : roulage, freins, direction a la roue avant, rotation a
## ~ 30 m/s, roues qui touchent (rayons), atterrissage dur = degats, arret sur la piste = on descend.
## Commandes : A / D (ou stick) roulis et direction au sol, W / S tangage (W : piquer, S : cabrer), Q / E palonnier,
## Accelerer / Freiner : gaz, Frein a main : freins des roues, E (monter / descendre) quand l'avion est arrete.
## Compatible avec le joueur (player.gd) : memes appels que les voitures (set_rider, seat_transform, exit_transform...).

const MODELE := "res://assets/models/veh_avion_leger.glb"
const CAM := preload("res://scripts/avion_camera.gd")

signal rider_changed(has_rider: bool)

var kind := "avion"
var model_name := "avion_leger"
var has_rider := false
var epave := false
var health := 100.0
var speed := 0.0                         # m/s : vitesse air (HUD)
var altitude := 0.0                      # m au-dessus du sol sous l'avion
var en_decrochage := false
var gaz := 0.0                           # 0 a 1
@export var reservoir := 150.0           # L d'essence aviation
@export var conso_facteur := 4.0
var carburant := 110.0
@export var delai_explosion := 8.0

@export var masse := 1100.0              # kg
@export var surface := 16.2              # m2
@export var poussee_max := 3200.0        # N (statique)
@export var vitesse_helice := 85.0       # m/s : la poussee tombe a zero
@export var cl0 := 0.32
@export var cl_pente := 5.1              # par radian
@export var alpha_decrochage := 0.28     # rad (16 degres)
@export var cd0 := 0.032
@export var k_induite := 0.055
@export var v_rotation := 29.0           # m/s : l'avion peut decoller
@export var frottement_roues := 0.025
@export var freinage := 0.45             # decelaration relative des freins (x g)
@export var angle_porte := 1.1
@export var assistance_virage := 1.0     # 0 : aucune ; 1 : la portance compense l'inclinaison (virages sans perte d'altitude)

var _visual: Node3D
var _helice: Node3D
var _prof: Node3D
var _dir: Node3D
var _ail_g: Node3D
var _ail_d: Node3D
var _roues: Array = []                   # [noeud, rayon]
var _portes := {}
var _siege: Node3D
var _sortie: Node3D
var _roues_pts := [Vector3(0, 0.22, -1.55), Vector3(-1.12, 0.3, 0.05), Vector3(1.12, 0.3, 0.05)]
var _rayons_roues := [0.22, 0.3, 0.3]
var _au_sol := false
var _v := Vector3.ZERO                   # vitesse monde
var _entree_pitch := 0.0                 # commandes lissees
var _entree_roulis := 0.0
var _entree_lacet := 0.0
var _son: AudioStreamPlayer3D
var _prop_angle := 0.0
var _feu_t := 0.0
var _crash_cd := 0.0
var _spawn_xf := Transform3D()
var derniere_collision := ""
var dbg := ""


@export var auto_placer := true          # pose l'avion sur l'aire de l'aeroport (a cote de la piste) au lancement
@export var piste_t := 300.0             # m depuis le seuil 06
@export var piste_s := 90.0              # m a cote de l'axe de piste (cote aerogare)


func _placer_sur_aeroport() -> void:
	var data: Dictionary = Carte.zone().data
	var best: Array = []
	for r in data.get("runways", []):
		if r.size() > best.size():
			best = r
	if best.size() < 2:
		return
	var p0 := Vector2(float(best[0][0]), float(best[0][1]))
	var p1 := Vector2(float(best[-1][0]), float(best[-1][1]))
	if p1.x < p0.x:
		var t := p0
		p0 = p1
		p1 = t
	var u := (p1 - p0).normalized()
	var n := Vector2(-u.y, u.x)
	var p := p0 + u * piste_t + n * piste_s
	var yaw := atan2(-u.x, -u.y)
	var y := 0.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 3.0, p.y), Vector3(p.x, -10.0, p.y), 1)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		y = (h["position"] as Vector3).y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y + 0.05, p.y))
	_spawn_xf = global_transform


func _ready() -> void:
	add_to_group("vehicules")
	_visual = (load(MODELE) as PackedScene).instantiate() as Node3D
	_visual.name = "Visual"
	add_child(_visual)
	_helice = _visual.find_child("helice", true, false) as Node3D
	_prof = _visual.find_child("gouverne_prof", true, false) as Node3D
	_dir = _visual.find_child("gouverne_dir", true, false) as Node3D
	_ail_g = _visual.find_child("aileron_G", true, false) as Node3D
	_ail_d = _visual.find_child("aileron_D", true, false) as Node3D
	_siege = _visual.find_child("pt_pilote", true, false) as Node3D
	_sortie = _visual.find_child("pt_sortie", true, false) as Node3D
	for p in _visual.find_children("porte_*", "Node3D", true, false):
		_portes[String(p.name)] = {"node": p, "base": (p as Node3D).transform, "angle": 0.0, "ouverte": false}
	for n in ["roue_avant", "roue_principal_G", "roue_principal_D"]:
		var r := _visual.find_child(n, true, false) as Node3D
		if r:
			_roues.append(r)
	# collision : fuselage et ailes, au-dessus des roues (les roues sont gerees par rayons)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 1.5, 4.4)           # cabine et capot (du sol 0,65 m au toit)
	cs.shape = box
	cs.position = Vector3(0, 1.4, 0.1)
	add_child(cs)
	var cs3 := CollisionShape3D.new()
	var b3 := BoxShape3D.new()
	b3.size = Vector3(0.5, 0.45, 3.4)           # poutre de queue : bien plus haute que le sol (assiette de rotation)
	cs3.shape = b3
	cs3.position = Vector3(0, 1.75, 3.9)
	add_child(cs3)
	var cs2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	b2.size = Vector3(10.8, 0.2, 1.6)
	cs2.shape = b2
	cs2.position = Vector3(0, 2.15, 0.4)
	add_child(cs2)
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	safe_margin = 0.05
	# camera
	var rig := Node3D.new()
	rig.name = "CamRig"
	rig.set_script(CAM)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.far = 7000.0
	rig.add_child(cam)
	add_child(rig)
	_son = AudioStreamPlayer3D.new()
	_son.stream = AudioSynth.moteur(false, true, 6)
	_son.unit_size = 14.0
	_son.max_distance = 600.0
	_son.volume_db = -80.0
	_son.autoplay = true
	add_child(_son)
	if auto_placer and Carte.zone() != null:
		_placer_sur_aeroport()
	_spawn_xf = global_transform


# ------------------------------------------------------------------ interface joueur (comme les voitures)
func set_rider(value: bool) -> void:
	has_rider = value
	rider_changed.emit(value)
	if not value:
		gaz = 0.0


func seat_transform() -> Transform3D:
	return _siege.global_transform if _siege else global_transform


func entry_point() -> Vector3:
	return _sortie.global_position if _sortie else global_position


func exit_transform() -> Transform3D:
	var p := entry_point()
	return Transform3D(Basis(Vector3.UP, rotation.y), Vector3(p.x, global_position.y + 0.15, p.z))


func peut_descendre() -> bool:
	## Seulement a l'arret au sol.
	return _au_sol and _v.length() < 3.0


func a_portes() -> bool:
	return not _portes.is_empty()


func ouvrir_porte(nom: String, ouvrir: bool, duree := 0.4) -> void:
	var d: Dictionary = _portes.get(nom, {})
	if d.is_empty() or bool(d["ouverte"]) == ouvrir:
		return
	d["ouverte"] = ouvrir
	var cible := (-angle_porte if nom.begins_with("porte_g") else angle_porte) if ouvrir else 0.0
	var maj := func(a: float) -> void:
		d["angle"] = a
		(d["node"] as Node3D).transform = (d["base"] as Transform3D) * Transform3D(Basis(Vector3.UP, a), Vector3.ZERO)
	var tw := create_tween()
	tw.tween_method(maj, float(d["angle"]), cible, duree)


func portiere(_fermer: bool) -> void:
	pass


func faire_le_plein(litres: float) -> float:
	var ajoute := minf(litres, reservoir - carburant)
	carburant += ajoute
	return ajoute


func damage(amount: float) -> void:
	if epave:
		return
	health = maxf(0.0, health - amount)
	if health < 30.0 and get_node_or_null("FeuVehicule") == null:
		var fl := FeuVehicule.flammes_moto(Vector3(0, 1.1, -1.8))
		add_child(fl[0])
		add_child(fl[1])
		FeuVehicule.allumer(self, fl[0], fl[1], delai_explosion)
	if health <= 0.0 and not epave:
		# destruction immediate : explosion au bout de quelques secondes
		pass


func conseil() -> String:
	## Aide de l'ecole de pilotage : une ligne selon la phase du vol (affichee par le HUD tant qu'on pilote).
	var kmh := _v.length() * 3.6
	if carburant <= 0.0:
		return tr("Panne d'essence : plane vers la piste, nez légèrement bas.")
	if _au_sol and kmh < 8.0 and gaz < 0.05:
		return tr("Gaz à fond : %s (maintenir). Reste sur l'axe de la piste avec A / D.") % Partie.nom_touche("accelerate")
	if _au_sol and kmh < 105.0 and gaz > 0.5:
		return tr("Accélère... à 105 km/h, tire doucement le manche : %s.") % Partie.nom_touche("move_back")
	if _au_sol and kmh >= 105.0 and gaz > 0.5:
		return tr("Cabre maintenant : %s (nez à 8 ou 10 degrés).") % Partie.nom_touche("move_back")
	if not _au_sol and altitude < 120.0 and _v.y > 1.0:
		return tr("Monte à plat : relâche le manche, garde les gaz. Vire avec %s / %s.") % [Partie.nom_touche("move_left"), Partie.nom_touche("move_right")]
	if not _au_sol and altitude < 60.0 and _v.y < -0.5 and gaz < 0.3:
		return tr("Approche : garde 100 à 120 km/h, pique un peu (%s), arrondi juste avant le sol (%s).") % [Partie.nom_touche("move_forward"), Partie.nom_touche("move_back")]
	if _au_sol and kmh > 20.0 and gaz < 0.1:
		return tr("Freins de roues : %s ; arrête-toi pour descendre.") % Partie.nom_touche("handbrake")
	if not _au_sol:
		return tr("Gaz %s / %s, vue cockpit %s.") % [Partie.nom_touche("accelerate"), Partie.nom_touche("brake"), Partie.nom_touche("camera_vue")]
	return ""


func info_hud() -> String:
	var pc := roundi(100.0 * carburant / maxf(reservoir, 1.0))
	return tr("Alt %d m   %d km/h   Gaz %d %%   Essence %d %%") % [roundi(altitude), roundi(_v.length() * 3.6), roundi(gaz * 100.0), pc] + ("   " + tr("DÉCROCHAGE !") if en_decrochage else "")


# ------------------------------------------------------------------ physique
func _hauteur_sol(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 3000.0, 1, [get_rid()])
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	return (h["position"] as Vector3).y if not h.is_empty() else -1000.0


func _physics_process(delta: float) -> void:
	if epave:
		velocity = Vector3.ZERO
		return
	_crash_cd = maxf(0.0, _crash_cd - delta)
	var in_pitch := 0.0
	var in_roll := 0.0
	var in_yaw := 0.0
	var frein := false
	if has_rider:
		in_pitch = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")      # S : cabrer
		in_roll = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		in_yaw = Input.get_action_strength("lacet_d") - Input.get_action_strength("lacet_g")
		gaz = clampf(gaz + (Input.get_action_strength("accelerate") - Input.get_action_strength("brake")) * 0.5 * delta, 0.0, 1.0)
		frein = Input.is_action_pressed("handbrake") or (Input.get_action_strength("brake") > 0.2 and gaz <= 0.01)
	if carburant <= 0.0:
		gaz = 0.0
	# commandes lissees
	_entree_pitch = move_toward(_entree_pitch, in_pitch, delta * 3.0)
	_entree_roulis = move_toward(_entree_roulis, in_roll, delta * 3.5)
	_entree_lacet = move_toward(_entree_lacet, in_yaw, delta * 3.0)
	var b := global_transform.basis.orthonormalized()
	var avant := -b.z
	var droite := b.x
	var haut := b.y
	var vit := _v.length()
	var v_loc := b.inverse() * _v
	var air := clampf(vit / v_rotation, 0.0, 1.4)                  # autorite des gouvernes
	var alpha := atan2(-v_loc.y, maxf(-v_loc.z, 0.5)) if vit > 1.0 else 0.0
	# --- forces ---
	var q := 0.5 * 1.225 * vit * vit
	var cl := cl0 + cl_pente * alpha
	en_decrochage = false
	if absf(alpha) > alpha_decrochage:
		en_decrochage = vit > 12.0
		var excès := absf(alpha) - alpha_decrochage
		cl = (cl0 + cl_pente * alpha_decrochage * signf(alpha)) * maxf(0.35, 1.0 - 2.8 * excès)
	if not _au_sol:
		var inclin := atan2(droite.y, haut.y)
		cl *= 1.0 + assistance_virage * (1.0 / maxf(cos(inclin), 0.3) - 1.0)
	dbg = "alpha %.1f cl %.2f vy %.1f pitch %.1f" % [rad_to_deg(alpha), cl, _v.y, rad_to_deg(asin(clampf(avant.y, -1.0, 1.0)))]
	var vdir := _v.normalized() if vit > 0.5 else avant
	var lift_dir := droite.cross(vdir).normalized()
	var f := Vector3.DOWN * masse * 9.81
	f += lift_dir * q * surface * cl
	f -= vdir * q * surface * (cd0 + k_induite * cl * cl)
	var poussee := gaz * poussee_max * clampf(1.0 - vit / vitesse_helice, 0.0, 1.0) if carburant > 0.0 else 0.0
	f += avant * poussee
	# --- sol : roues (rayons), freins, roulement ---
	_au_sol = false
	var pente := Vector3.UP
	var pen_max := 0.0
	var haut_sol := -1000.0
	for i in 3:
		var wp: Vector3 = global_transform * (_roues_pts[i] as Vector3)
		var gy := _hauteur_sol(wp)
		haut_sol = maxf(haut_sol, gy)
		var pen := gy - (wp.y - float(_rayons_roues[i]))
		if pen > 0.0:
			pen_max = maxf(pen_max, pen)
	altitude = maxf(0.0, global_position.y - maxf(haut_sol, -50.0))
	var normal_force := 0.0
	if pen_max > 0.0 and _v.y <= 3.0:
		_au_sol = true
		# atterrissage dur : vitesse verticale a l'impact
		if _v.y < -3.5 and _crash_cd <= 0.0:
			_crash_cd = 1.0
			damage((absf(_v.y) - 3.5) * 14.0)
			shake_joueur(clampf(absf(_v.y) / 8.0, 0.2, 1.0))
		global_position.y += pen_max
		if _v.y < 0.0:
			_v.y = 0.0
		normal_force = masse * 9.81
	# --- vitesse ---
	var acc := f / masse
	_v += acc * delta
	if _au_sol:
		var vh := Vector3(_v.x, 0.0, _v.z)
		var fric := frottement_roues + (freinage if frein else 0.0)
		var dv := fric * 9.81 * delta
		if vh.length() <= dv:
			vh = Vector3.ZERO
		else:
			vh -= vh.normalized() * dv
		# les roues ne glissent pas de cote : la vitesse laterale est annulee
		var lat := droite * vh.dot(droite)
		vh -= lat * clampf(delta * 12.0, 0.0, 1.0)
		_v = Vector3(vh.x, _v.y, vh.z)
	# --- orientation ---
	var rot := Basis.IDENTITY
	var pitch_rate := _entree_pitch * 0.5 * air
	var roll_rate := -_entree_roulis * 1.2 * air
	var yaw_rate := -_entree_lacet * 0.4 * air
	if _au_sol:
		roll_rate = 0.0
		var vit_sol := _v.length()
		# direction a la roue avant : palonnier ou A / D, efficace des 3 m/s
		var braq := clampf(_entree_lacet + _entree_roulis, -1.0, 1.0)
		yaw_rate = -braq * 0.55 * clampf(vit_sol / 4.0, 0.0, 1.0)
		# au sol : le nez ne se leve qu'a la vitesse de rotation ; sinon l'avion reste sur ses trois roues
		var pitch_actuel := asin(clampf(avant.y, -1.0, 1.0))
		if vit_sol < v_rotation * 0.85:
			pitch_rate = clampf((0.0 - pitch_actuel) * 3.0, -0.6, 0.6)
		else:
			pitch_rate = clampf(pitch_rate, -0.2, 0.4)
		# a plat : le roulis revient a zero
		var roulis_actuel := atan2(droite.y, haut.y)
		roll_rate = clampf(-roulis_actuel * 3.0, -0.8, 0.8)
	else:
		# inclinaison limitee a 60 degres (confort de pilotage) ; le roulis revient doucement a plat sans action
		var roulis := atan2(droite.y, haut.y)
		var limite := deg_to_rad(60.0)
		if absf(roulis) > limite:
			if signf(roll_rate) == signf(roulis):
				roll_rate = 0.0
			roll_rate += clampf(-(roulis - signf(roulis) * limite) * 4.0, -0.6, 0.6)
		if absf(_entree_roulis) < 0.05:
			roll_rate += clampf(-roulis * 0.25, -0.2, 0.2)
	# application dans le repere de l'avion (tangage X, roulis -Z, lacet Y)
	var nb := b
	nb = nb.rotated(b.x, pitch_rate * delta)
	nb = nb.rotated(b.y, yaw_rate * delta)
	nb = nb.rotated(b.z, roll_rate * delta)
	# stabilite (compensation automatique) : le nez revient vers l'incidence qui donne la portance du vol en palier a cette
	# vitesse ; le pilote qui tire ou pique garde la main (sinon l'avion prendrait une pente descendante des qu'on lache le manche)
	if not _au_sol and vit > 8.0:
		var q2 := 0.5 * 1.225 * vit * vit
		var a_trim := clampf((masse * 9.81 / maxf(q2 * surface, 1.0) - cl0) / cl_pente, -0.05, 0.22)
		var ecart := nb.orthonormalized() * Vector3.FORWARD
		var objectif := vdir.rotated(nb.orthonormalized().x, a_trim)
		var angle_e := ecart.angle_to(objectif)
		if angle_e > 0.0001:
			var axe := ecart.cross(objectif).normalized()
			var pas := minf(angle_e, 0.9 * clampf(vit / 40.0, 0.2, 1.0) * (0.0 if absf(_entree_pitch) > 0.05 else (0.3 if absf(_entree_lacet) > 0.05 else 1.0)) * delta)
			nb = nb.rotated(axe, pas)
	global_transform.basis = nb.orthonormalized()
	# --- deplacement avec collisions (murs, batiments) ---
	var c := move_and_collide(_v * delta)
	if c:
		derniere_collision = "%s n=%s v=%.1f pos=%s forme=%d y_av=%.2f" % [(c.get_collider() as Node).get_path() if c.get_collider() is Node else "?", c.get_normal(), _v.length(), c.get_position(), c.get_local_shape().get_instance_id() % 100 if c.get_local_shape() else -1, global_position.y]
		var n := c.get_normal()
		var impact := -_v.dot(n)
		if impact > 4.0:
			if _crash_cd <= 0.0:
				_crash_cd = 1.0
				damage(clampf((impact - 4.0) * 10.0, 0.0, 120.0))
				shake_joueur(1.0)
		_v = _v.slide(n) * 0.5
	# --- carburant, helice, gouvernes, son ---
	if has_rider and carburant > 0.0:
		carburant = maxf(0.0, carburant - (0.0016 + gaz * 0.006) * conso_facteur * delta)
	speed = _v.dot(avant)
	_prop_angle += delta * (6.0 + gaz * 70.0 if carburant > 0.0 and has_rider else 3.0)
	if _helice:
		_helice.rotation.z = _prop_angle
	if _prof:
		_prof.rotation.x = _entree_pitch * 0.45
	if _dir:
		_dir.rotation.y = -_entree_lacet * 0.45
	if _ail_g:
		_ail_g.rotation.x = -_entree_roulis * 0.4
	if _ail_d:
		_ail_d.rotation.x = _entree_roulis * 0.4
	var moteur_actif := has_rider and carburant > 0.0 and not epave
	_son.volume_db = (-8.0 + 8.0 * gaz) if moteur_actif else -80.0
	_son.pitch_scale = 0.55 + gaz * 1.1
	for r in _roues:
		if _au_sol:
			(r as Node3D).rotation.x -= speed / 0.28 * delta
		elif absf(_entree_roulis) > 5.0:
			pass


func shake_joueur(amount: float) -> void:
	var pl := get_parent().get_node_or_null("Player")
	if pl and pl.has_method("shake") and pl.get("vehicle") == self:
		pl.call("shake", amount)
