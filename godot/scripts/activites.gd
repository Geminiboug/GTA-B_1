extends Node3D
## Activites secondaires (phase 20). Noms fictifs.
## - Courses de zems de nuit : de 20 h a 5 h, depart au carrefour de la Route des Filets (T sur le zem) ; 8 points de
##   passage dans les rues, deux rivaux pilotes ; 1er : 10 000 F et du respect, 2e : 3 000 F.
## - Fresques peintes : 15 enseignes peintes a la main sur les murs du quartier, a photographier (telephone, appareil
##   photo ou F12) ; recompense a chaque fois, bonus quand la collection est complete.
## - Paris sur les matchs au maquis : T au maquis, "Parier sur le match" (clubs fictifs) ; resultat a l'heure suivante.
## - Taux de completion (menu Statistiques) : missions, stationnements, proprietes, fresques, courses gagnees.

const NB_FRESQUES := 15
const TEXTES_FRESQUES := ["COIFFURE DIEU MERCI", "ATELIER LA GRACE", "VULCANISATEUR 24H/24", "PHOTO STUDIO LE MIROIR",
	"BOULANGERIE LE BON GOUT", "PHARMACIE DU LITTORAL", "COUTURE MAMAN BENIE", "TELE-REPARATION ELECTRON",
	"MAQUIS LA JOIE", "ECOLE LES PETITS GENIES", "QUINCAILLERIE L'ESPOIR", "AUTO-ECOLE LE VOLANT", "SALON AFRO STYLE",
	"PRESSING LA BLANCHEUR", "CABINE TRANSFERT RAPIDE"]
const CLUBS := ["Étoile de Gbê Town", "Racing Lagune", "Atlantique FC", "Union Sportive du Littoral", "Avenir de Cotodji"]

@export var player_path: NodePath = ^"../Player"
@export var depart_course := Vector3(-120, 0, 420)
@export var longueur_course := 1400.0          # m environ (points de passage choisis sur le reseau)
@export var prix_course := [10000, 3000]

var course: Dictionary = {}                    # {points, i, rivaux, t}
var _player: CharacterBody3D
var _hud: Node
var _day: Node
var _depart := Vector3.ZERO
var _fresques: Array = []                      # [{id, node}]
var _rng := RandomNumberGenerator.new()
var _pari_heure := -1
var _cp_marker: MeshInstance3D


func _ready() -> void:
	_rng.seed = 2026
	_player = get_node_or_null(player_path)
	_hud = get_node_or_null("../HUD")
	_day = get_node_or_null("../JourNuit")
	var com := get_node_or_null("../Commerce")
	if com:
		var paris: Array = []
		for c in CLUBS:
			paris.append(["Pari 2 000 F sur %s" % c, 2000, 0])
		com.ARTICLES["paris"] = paris
		com.NOMS["paris"] = "le maquis (paris)"
	var ph := get_node_or_null("../ModePhoto")
	if ph and ph.has_signal("photo_prise"):
		ph.photo_prise.connect(_photo)
	Partie.chantier_differe(_placer)   # etape de la mise en place etalee pendant le chargement


func _placer() -> void:
	var carte := Carte.zone()
	if carte == null:
		return
	var near: Dictionary = carte.nearest_on_network(Vector2(depart_course.x, depart_course.z))
	if not near.is_empty():
		var q: Vector2 = near["point"]
		_depart = Vector3(q.x, 0, q.y)
	# paris : un guichet a chaque maquis
	var com := get_node_or_null("../Commerce")
	if com:
		var extra: Array = []
		for s in com.spots:
			if s["kind"] == "maquis":
				extra.append({"pos": (s["pos"] as Vector3) + Vector3(1.5, 0, 0), "kind": "paris"})
		com.spots.append_array(extra)
	# fresques : sur les murs des batiments les plus proches de points de rue repartis dans le quartier
	var space := get_world_3d().direct_space_state
	var essais := 0
	while _fresques.size() < NB_FRESQUES and essais < 400:
		essais += 1
		var a := Vector2(_rng.randf_range(-600, 700), _rng.randf_range(-900, 500))
		var n: Dictionary = carte.nearest_on_network(a)
		if n.is_empty():
			continue
		var q: Vector2 = n["point"]
		var trop_pres := false
		for f in _fresques:
			if Vector2((f["node"] as Node3D).global_position.x, (f["node"] as Node3D).global_position.z).distance_to(q) < 80.0:
				trop_pres = true
		if trop_pres:
			continue
		# un mur a moins de 12 m sur le cote de la rue
		for ang in range(0, 360, 45):
			var d := Vector3(cos(deg_to_rad(ang)), 0, sin(deg_to_rad(ang)))
			var o := Vector3(q.x, 2.2, q.y)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * 12.0, 1))
			if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
				continue
			_fresque(_fresques.size(), hit["position"] + (hit["normal"] as Vector3) * 0.03, hit["normal"])
			break


func _fresque(i: int, p: Vector3, nrm: Vector3) -> void:
	var l := Label3D.new()
	l.name = "Fresque_%d" % i
	l.text = TEXTES_FRESQUES[i % TEXTES_FRESQUES.size()]
	l.font_size = 72
	l.pixel_size = 0.008
	l.outline_size = 0
	l.modulate = [Color(0.9, 0.2, 0.15), Color(0.1, 0.35, 0.8), Color(0.1, 0.55, 0.25), Color(0.95, 0.7, 0.1)][i % 4]
	l.double_sided = false
	l.shaded = true
	add_child(l)
	l.global_position = p
	l.look_at(p + nrm, Vector3.UP)
	l.rotate_object_local(Vector3.UP, PI)
	l.add_to_group("fresque")
	# fond de peinture claire derriere les lettres (enseigne peinte a la main)
	var fond := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(l.text.length() * l.font_size * 0.56 * l.pixel_size + 0.6, l.font_size * l.pixel_size * 1.6)
	var m := StandardMaterial3D.new()
	m.albedo_color = [Color(0.95, 0.92, 0.8), Color(0.98, 0.85, 0.25), Color(0.85, 0.93, 0.97), Color(0.97, 0.97, 0.95)][(i + 1) % 4]
	m.roughness = 0.95
	q.material = m
	fond.mesh = q
	fond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.add_child(fond)
	fond.position = Vector3(0, 0, -0.01)
	_fresques.append({"id": i, "node": l})


func fresques_trouvees() -> Array:
	return Partie.drapeaux.get("fresques", [])


func _photo(cam: Camera3D) -> void:
	## Photo prise : chaque fresque bien cadree (a moins de 30 m, dans le champ, visible) compte une fois.
	if cam == null:
		return
	var deja: Array = fresques_trouvees()
	var space := get_world_3d().direct_space_state
	for f in _fresques:
		var n: Node3D = f["node"]
		var p := n.global_position
		if deja.has(f["id"]) or cam.global_position.distance_to(p) > 30.0 or not cam.is_position_in_frustum(p):
			continue
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cam.global_position, p + (p - cam.global_position).normalized() * -0.2, 1))
		if not hit.is_empty() and (hit["position"] as Vector3).distance_to(p) > 0.6:
			continue
		deja.append(f["id"])
		Partie.drapeaux["fresques"] = deja
		Partie.gagner(1000, "Fresque photographiée")
		Partie.notifier(tr("Fresque photographiée : %d / %d") % [deja.size(), NB_FRESQUES])
		if deja.size() == NB_FRESQUES:
			Partie.gagner(25000, "Collection de fresques complète")
			Partie.notifier(tr("Toutes les fresques du quartier ! Bonus de 25 000 F."))


# ------------------------------------------------------------------ course de zems de nuit
func _nuit() -> bool:
	var h := float(_day.get("hour")) if _day else 12.0
	return h >= 20.0 or h < 5.0


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_paris()
	if not course.is_empty():
		_course_maj(delta)
		return
	var v: Node3D = _player.get("vehicle")
	if v == null or v.get("kind") == "voiture" or not _nuit() or _depart == Vector3.ZERO:
		return
	if v.global_position.distance_to(_depart) < 10.0:
		if _hud and _hud.has_method("show_hint"):
			_hud.show_hint(tr("T : course de zems de nuit (1er : %s)") % Partie.fcfa(prix_course[0]))
		if Input.is_action_just_pressed("parler"):
			lancer_course()


func lancer_course() -> void:
	var carte := Carte.zone()
	var pts: Array = []
	var p := Vector2(_depart.x, _depart.z)
	var dir := Vector2(1, 0)
	var total := 0.0
	while pts.size() < 8:
		var cible := p + dir.rotated(_rng.randf_range(-0.9, 0.9)) * (longueur_course / 8.0)
		var n: Dictionary = carte.nearest_on_network(cible)
		if n.is_empty():
			break
		var q: Vector2 = n["point"]
		if q.distance_to(p) < 40.0:
			dir = dir.rotated(PI * 0.5)
			continue
		total += q.distance_to(p)
		dir = (q - p).normalized()
		p = q
		pts.append(Vector3(q.x, 0, q.y))
	var rivaux: Array = []
	var zs := load("res://scenes/zem.tscn") as PackedScene
	for k in 2:
		var z := zs.instantiate() as Node3D
		get_parent().add_child(z)
		z.global_position = _depart + Vector3(0, 0.3, 2.5 + 2.0 * k)
		z.set("ai", true)
		rivaux.append({"zem": z, "i": 0, "fini": -1.0})
	course = {"points": pts, "i": 0, "rivaux": rivaux, "t": 0.0, "fini": -1.0}
	_cp(pts[0])
	Partie.notifier(tr("Course lancée : %d points de passage, %.1f km !") % [pts.size(), total / 1000.0])


func _cp(p: Vector3) -> void:
	if _cp_marker == null:
		_cp_marker = MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 3.0
		c.bottom_radius = 3.0
		c.height = 4.0
		c.cap_top = false
		c.cap_bottom = false
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.2, 0.9, 1.0, 0.3)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		c.material = m
		_cp_marker.mesh = c
		add_child(_cp_marker)
	_cp_marker.visible = true
	_cp_marker.global_position = p + Vector3(0, 2.0, 0)
	var hc := get_node_or_null("../HUD")
	if hc and "waypoint" in hc:
		hc.set("waypoint", Vector2(p.x, p.z))
		hc.set("has_waypoint", true)


func _course_maj(delta: float) -> void:
	course["t"] = float(course["t"]) + delta
	var pts: Array = course["points"]
	var v: Node3D = _player.get("vehicle")
	var pp: Vector3 = v.global_position if v else _player.global_position
	if v == null and float(course["t"]) > 3.0:
		_fin_course(3, "Tu es descendu du zem : course abandonnée.")
		return
	if int(course["i"]) < pts.size() and pp.distance_to(pts[course["i"]]) < 9.0:
		course["i"] = int(course["i"]) + 1
		if int(course["i"]) < pts.size():
			_cp(pts[course["i"]])
	# rivaux : pilotes vers leur prochain point (meme commande que la police, scripts/zem.gd ai_input)
	var place := 1
	for r in course["rivaux"]:
		var z: Node3D = r["zem"]
		if not is_instance_valid(z):
			continue
		if int(r["i"]) >= pts.size():
			if float(r["fini"]) < 0.0:
				r["fini"] = course["t"]
			place += 1
			z.set("ai_input", Vector3(0, 1, 0))
			continue
		var cible: Vector3 = pts[r["i"]]
		if z.global_position.distance_to(cible) < 9.0:
			r["i"] = int(r["i"]) + 1
			continue
		var to := cible - z.global_position
		var yaw := float(z.get("_yaw"))
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var t2 := Vector2(to.x, to.z).normalized()
		var ang := atan2(fwd.cross(t2), fwd.dot(t2))
		var vit := absf(float(z.get("speed")))
		var but := lerpf(19.0, 7.0, clampf(absf(ang) / 1.2, 0.0, 1.0)) * _rng.randf_range(0.97, 1.0)
		z.set("ai_input", Vector3(1.0 if vit < but else 0.0, 1.0 if vit > but + 3.0 else 0.0, clampf(-ang * 2.0, -1.0, 1.0)))
	if int(course["i"]) >= pts.size():
		_fin_course(place, "")


func _fin_course(place: int, msg: String) -> void:
	for r in course.get("rivaux", []):
		if is_instance_valid(r["zem"]):
			(r["zem"] as Node).queue_free()
	if _cp_marker:
		_cp_marker.visible = false
	course = {}
	if msg != "":
		Partie.notifier(tr(msg))
		return
	if place <= 2:
		Partie.gagner(prix_course[place - 1], "Course de zems")
	if place == 1:
		Partie.drapeaux["courses_gagnees"] = int(Partie.drapeaux.get("courses_gagnees", 0)) + 1
		var st := get_node_or_null("../Stats")
		if st:
			st.ajouter("respect", 3.0)
	Partie.notifier(tr("Arrivée : %s !") % ["", "1er", "2e", "3e"][clampi(place, 1, 3)])


# ------------------------------------------------------------------ paris au maquis
func _paris() -> void:
	## Paris places (Partie.drapeaux["paris"] : [{club, mise}]) : resultat a l'heure de jeu suivante (cote 3 contre 1).
	if _day == null:
		return
	var h := int(float(_day.get("hour")))
	if _pari_heure < 0:
		_pari_heure = h
	if h == _pari_heure:
		return
	_pari_heure = h
	var l: Array = Partie.drapeaux.get("paris", [])
	if l.is_empty():
		return
	var gagnant: String = CLUBS[_rng.randi() % CLUBS.size()]
	for p in l:
		if p["club"] == gagnant:
			Partie.gagner(int(p["mise"]) * 3, "Pari gagné")
	Partie.notifier(tr("Match terminé : victoire de %s.") % gagnant)
	Partie.drapeaux["paris"] = []


func parier(i: int) -> void:
	var l: Array = Partie.drapeaux.get("paris", [])
	l.append({"club": CLUBS[i], "mise": 2000})
	Partie.drapeaux["paris"] = l
	Partie.notifier(tr("Pari enregistré sur %s : résultat dans l'heure.") % CLUBS[i])


# ------------------------------------------------------------------ completion
func completion() -> float:
	## Pourcentage de completion : missions de l'histoire, stationnements, proprietes, fresques, courses gagnees.
	var h := get_node_or_null("../Histoire")
	var nm: int = (h.get("missions") as Array).size() if h else 10
	var parts := [
		[float(Partie.missions_faites.size()), float(nm), 40.0],
		[float((get_node("../Territoires").tenus() as Array).size()) if get_node_or_null("../Territoires") else 0.0, 6.0, 20.0],
		[float((Partie.drapeaux.get("proprietes", []) as Array).size()), 2.0, 10.0],
		[float(fresques_trouvees().size()), float(NB_FRESQUES), 20.0],
		[minf(float(Partie.drapeaux.get("courses_gagnees", 0)), 3.0), 3.0, 10.0],
	]
	var total := 0.0
	for p in parts:
		total += minf(p[0] / maxf(p[1], 1.0), 1.0) * p[2]
	return total
