extends Node3D
class_name Signalisation
## Feux tricolores et STOP des carrefours du reseau de rues (graphe de scripts/carte.gd), lus par la circulation
## (scripts/traffic.gd) :
## - feux : carrefours ou se croisent au moins 3 voies principales, ou 4 branches dont 2 principales ; deux axes
##   (est-ouest / nord-sud) en alternance : vert, orange, rouge de degagement ;
## - STOP : branche secondaire qui debouche sur une voie principale, sans feu ;
## - le reste (carrefours entre petites rues) garde le systeme de priorite du premier arrive (traffic.gd _locks).
## Un poteau a tete coloree est pose a droite de chaque branche qui arrive sur un feu ; un panneau rouge pour un STOP.
## Les emplacements viennent du reseau, pas du hasard ; a verifier a l'oeil sur la carte (docs/benin-gta-roadmap.md).

@export var vert := 14.0          # s de vert par axe
@export var orange := 3.0
@export var degagement := 2.0     # s de rouge pour les deux axes entre deux phases
@export var portee_visuelle := 220.0

var _carte: Carte
var _feux := {}          # noeud -> decalage de phase (s)
var _stops := {}         # noeud -> {arete: true}
var _tetes: MultiMeshInstance3D
var _tete_noeud := PackedInt32Array()   # instance -> noeud
var _tete_axe := PackedInt32Array()     # instance -> axe (0 est-ouest, 1 nord-sud)
var _t := 0.0
var _maj_t := 0.0
const COUL := [Color(0.1, 1.0, 0.25), Color(1.0, 0.65, 0.05), Color(1.0, 0.1, 0.08)]


func monter(carte: Carte) -> void:
	_carte = carte
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var periode := 2.0 * (vert + orange + degagement)
	for n in carte.nodes.size():
		var d := carte.node_degree(n)
		if d < 3:
			continue
		var m := 0
		for e in carte.node_edges[n]:
			if carte.edges[e]["major"]:
				m += 1
		if m >= 3 or (d >= 4 and m >= 2):
			_feux[n] = rng.randf() * periode
		elif m >= 1 and m < d:
			var mineures := {}
			for e in carte.node_edges[n]:
				if not carte.edges[e]["major"] and carte.edges[e]["kind"] != "track":
					mineures[e] = true
			if not mineures.is_empty():
				_stops[n] = mineures
	_construire()
	print("Signalisation : %d feux, %d STOP" % [_feux.size(), _stops.size()])


func _process(delta: float) -> void:
	_t += delta
	_maj_t -= delta
	if _maj_t <= 0.0 and _tetes:
		_maj_t = 0.4
		_colorier()
	_txt_t -= delta
	if _txt_t <= 0.0:
		_txt_t = 0.5
		_maj_textes()


func _axe(dir: Vector2) -> int:
	return 0 if absf(dir.x) > absf(dir.y) else 1


func etat(n: int, dir: Vector2) -> int:
	## 0 vert, 1 orange, 2 rouge pour un vehicule qui arrive au noeud n en roulant dans la direction dir (-1 : pas de feu).
	if not _feux.has(n):
		return -1
	return _etat_axe(n, _axe(dir))


func _etat_axe(n: int, axe: int) -> int:
	var demi := vert + orange + degagement
	var t := fmod(_t + float(_feux[n]), 2.0 * demi)
	if axe == 1:
		t = fmod(t + demi, 2.0 * demi)
	if t < vert:
		return 0
	if t < vert + orange:
		return 1
	return 2


func est_stop(n: int, arete: int) -> bool:
	return _stops.has(n) and (_stops[n] as Dictionary).has(arete)


func _arrive(e: int, n: int) -> bool:
	## Un vehicule peut-il arriver au noeud n par l'arete e ? (les sorties de rues a sens unique n'ont ni feu ni STOP)
	return _carte.can_drive(e, _carte.other_end(e, n))


func _construire() -> void:
	# poteau gris fonce, boitier noir a trois feux (rouge en haut, orange, vert en bas) tournes vers les vehicules qui arrivent
	var poteau := CylinderMesh.new()
	poteau.top_radius = 0.06
	poteau.bottom_radius = 0.085
	poteau.height = 1.0
	poteau.radial_segments = 8
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.2, 0.21, 0.23)
	pm.roughness = 0.7
	poteau.material = pm
	var boitier := BoxMesh.new()
	boitier.size = Vector3(0.38, 1.08, 0.3)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.05, 0.05, 0.06)
	bm.roughness = 0.5
	boitier.material = bm
	var visiere := BoxMesh.new()                 # petit auvent au-dessus de chaque feu
	visiere.size = Vector3(0.3, 0.03, 0.14)
	visiere.material = bm
	var lentille := CylinderMesh.new()
	lentille.top_radius = 0.13
	lentille.bottom_radius = 0.13
	lentille.height = 0.04
	lentille.radial_segments = 14
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lentille.material = lm
	var panneau := CylinderMesh.new()
	panneau.top_radius = 0.38
	panneau.bottom_radius = 0.38
	panneau.height = 0.05
	panneau.radial_segments = 8
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.75, 0.05, 0.05)
	sm.emission_enabled = true
	sm.emission = Color(0.5, 0.02, 0.02)
	panneau.material = sm
	var feux := []        # [position (Vector2), dir d'arrivee, noeud, axe, hauteur du poteau]
	var stops := []       # [position, noeud]
	var approches := []
	for n in _feux.keys():
		var c: Vector2 = _carte.nodes[n]
		for e in _carte.node_edges[n]:
			if not _arrive(e, n):
				continue
			var p2 := _carte.edge_pts_from(e, n)
			if p2.size() < 2:
				continue
			var dir := -(p2[1] - p2[0]).normalized()       # sens de l'arrivee au carrefour
			var droite := Vector2(-dir.y, dir.x)
			var larg: float = float(_carte.edges[e]["width"])
			var lat := larg * 0.5 + 1.0                     # sur le trottoir, a droite de la voie qui arrive
			# feu de la ligne d'arret (a droite, du cote du conducteur) et feu de l'autre cote du carrefour (visible de loin)
			feux.append([c - dir * (ligne(larg) + 0.6) + droite * lat, dir, n, _axe(dir), 3.6])
			feux.append([c + dir * (larg * 0.5 + 2.0) + droite * lat, dir, n, _axe(dir), 4.6])
			approches.append([n, dir, larg])
	for n in _stops.keys():
		var c: Vector2 = _carte.nodes[n]
		for e in (_stops[n] as Dictionary).keys():
			if not _arrive(e, n):
				continue
			var p2 := _carte.edge_pts_from(e, n)
			if p2.size() < 2:
				continue
			var dir := -(p2[1] - p2[0]).normalized()
			var droite := Vector2(-dir.y, dir.x)
			var larg: float = float(_carte.edges[e]["width"])
			stops.append([c - dir * (ligne(larg) + 0.6) + droite * (larg * 0.5 + 1.0), dir])
			approches.append([n, dir, larg])
	_marquages(approches)
	_panneaux()
	var nf := feux.size()
	var mp := MultiMesh.new()
	mp.transform_format = MultiMesh.TRANSFORM_3D
	mp.mesh = poteau
	mp.instance_count = nf + stops.size()
	var mb := MultiMesh.new()
	mb.transform_format = MultiMesh.TRANSFORM_3D
	mb.mesh = boitier
	mb.instance_count = nf
	var mv := MultiMesh.new()
	mv.transform_format = MultiMesh.TRANSFORM_3D
	mv.mesh = visiere
	mv.instance_count = nf * 3
	var ml := MultiMesh.new()
	ml.transform_format = MultiMesh.TRANSFORM_3D
	ml.use_colors = true
	ml.mesh = lentille
	ml.instance_count = nf * 3
	var ms := MultiMesh.new()
	ms.transform_format = MultiMesh.TRANSFORM_3D
	ms.mesh = panneau
	ms.instance_count = stops.size()
	_tete_noeud.resize(nf)
	_tete_axe.resize(nf)
	for i in nf:
		var f: Array = feux[i]
		var q: Vector2 = f[0]
		var dir: Vector2 = f[1]
		var h: float = f[4]
		var yaw := atan2(-dir.x, -dir.y)              # +Z local du boitier = vers les vehicules qui arrivent
		var base := Basis(Vector3.UP, yaw)
		var haut := h - 0.15                           # le boitier est pose sur le poteau
		mp.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, haut, 1)), Vector3(q.x, haut * 0.5, q.y)))
		var centre := Vector3(q.x, haut + 0.54, q.y)
		mb.set_instance_transform(i, Transform3D(base, centre))
		for k in 3:
			var dy := 0.34 - k * 0.34                  # rouge en haut, orange, vert en bas
			var p := centre + base * Vector3(0, dy, 0.16)
			ml.set_instance_transform(i * 3 + k, Transform3D(base * Basis(Vector3.RIGHT, PI / 2.0), p))
			mv.set_instance_transform(i * 3 + k, Transform3D(base, p + base * Vector3(0, 0.15, 0.04)))
		_tete_noeud[i] = f[2]
		_tete_axe[i] = f[3]
	for j in stops.size():
		var q: Vector2 = stops[j][0]
		var dir: Vector2 = stops[j][1]
		mp.set_instance_transform(nf + j, Transform3D(Basis.from_scale(Vector3(1, 2.3, 1)), Vector3(q.x, 1.15, q.y)))
		var yaw := atan2(-dir.x, -dir.y)
		# panneau octogonal face aux vehicules : le cylindre (axe Y) est couche sur +Z puis tourne vers le conducteur
		ms.set_instance_transform(j, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0), Vector3(q.x, 2.5, q.y) + Vector3(sin(yaw), 0, cos(yaw)) * 0.06))
	for mm in [mp, mb, mv, ml, ms]:
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		if mm == ml:
			_tetes = inst
	_colorier()


func _colorier() -> void:
	## Un seul feu allume par boitier ; les deux autres restent sombres.
	if _tetes == null:
		return
	var mm := _tetes.multimesh
	var eteint := [Color(0.08, 0.0, 0.0), Color(0.07, 0.04, 0.0), Color(0.0, 0.07, 0.01)]
	for i in mm.instance_count / 3:
		var s := _etat_axe(_tete_noeud[i], _tete_axe[i])        # 0 vert, 1 orange, 2 rouge
		var allume := 2 - s                                      # position du feu allume : 0 haut (rouge), 1 orange, 2 vert
		for k in 3:
			var couleur_allumee: Color = COUL[2 - k]
			mm.set_instance_color(i * 3 + k, couleur_allumee if k == allume else eteint[k])


static func ligne(largeur: float) -> float:
	## Distance de la ligne d'arret au centre du carrefour (m) : demi-largeur de la chaussee + passage pieton.
	return largeur * 0.5 + 3.5


func _marquages(approches: Array) -> void:
	## Passages pietons (bandes blanches) et lignes d'arret sur chaque branche qui arrive a un feu ou a un STOP.
	## approches : [noeud, dir (Vector2, sens d'arrivee), largeur].
	var bande := BoxMesh.new()
	bande.size = Vector3(0.45, 0.02, 2.4)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.92, 0.9)
	m.roughness = 0.9
	bande.material = m
	var stripes := []
	for ap in approches:
		var c: Vector2 = _carte.nodes[ap[0]]
		var dir: Vector2 = ap[1]
		var larg: float = ap[2]
		var yaw := atan2(-dir.x, -dir.y)
		var base := Basis(Vector3.UP, yaw)
		var droite := Vector2(-dir.y, dir.x)
		var l := ligne(larg)
		var zebra := c - dir * (l - 1.6)            # entre la ligne d'arret et le carrefour
		var n := int(floor((larg - 1.0) / 0.9))
		for k in n:
			var off := (k - (n - 1) * 0.5) * 0.9
			var q := zebra + droite * off
			stripes.append(Transform3D(base, Vector3(q.x, 0.05, q.y)))
		# ligne d'arret : une barre sur la voie d'arrivee (moitie droite de la chaussee)
		var lq := c - dir * l + droite * (larg * 0.25)
		stripes.append(Transform3D(base * Basis.from_scale(Vector3(larg, 1.0, 0.18)), Vector3(lq.x, 0.05, lq.y)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bande
	mm.instance_count = stripes.size()
	for i in stripes.size():
		mm.set_instance_transform(i, stripes[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


# ------------------------------------------------------------ panneaux (limitation, sens interdit, stationnement)
@export var limite_kmh := 50                 # voies principales (les petites rues : 30, sans panneau)
@export var pool_textes := 24
@export var portee_textes := 70.0
var _panneaux_liste: Array = []       # [texte, position Vector3, yaw] : chiffres posés par un pool de Label3D
var _pool_labels: Array[Label3D] = []
var _txt_t := 0.0


func limite_ms(principale: bool) -> float:
	## Vitesse maximale (m/s) que respectent les vehicules : 50 km/h sur les voies principales, 30 dans les petites rues.
	return (limite_kmh if principale else 30) / 3.6 * 1.06


func _panneaux() -> void:
	var items := []        # [type, position (Vector2), dir (sens des vehicules concernes)]
	for e in _carte.edges.size():
		var ed: Dictionary = _carte.edges[e]
		if ed["kind"] == "track":
			continue
		var larg: float = float(ed["width"])
		var L: float = float(ed["len"])
		if ed["major"] and L > 70.0:
			for depuis in [ed["a"], ed["b"]]:
				if not _carte.can_drive(e, depuis):
					continue
				var p2 := _carte.edge_pts_from(e, depuis)
				if p2.size() < 2:
					continue
				var dir := (p2[1] - p2[0]).normalized()
				items.append(["limite", p2[0] + dir * (ligne(larg) + 12.0) + Vector2(-dir.y, dir.x) * (larg * 0.5 + 0.9), dir])
		if ed["oneway"] and L > 25.0 and larg >= 4.0:
			var sortie: int = ed["b"]                       # bout par lequel on ne peut pas entrer
			if _carte.node_degree(sortie) >= 3:
				var p2 := _carte.edge_pts_from(e, sortie)
				if p2.size() >= 2:
					var dir := (p2[1] - p2[0]).normalized()     # sens de celui qui s'engagerait a contresens
					items.append(["sens_interdit", p2[0] + dir * (larg * 0.5 + 3.0) + Vector2(-dir.y, dir.x) * (larg * 0.5 + 0.9), dir])
	for n in _feux.keys():
		for e in _carte.node_edges[n]:
			if not _arrive(e, n):
				continue
			var p2 := _carte.edge_pts_from(e, n)
			if p2.size() < 2:
				continue
			var dir := -(p2[1] - p2[0]).normalized()
			var larg: float = float(_carte.edges[e]["width"])
			var c: Vector2 = _carte.nodes[n]
			items.append(["stationnement", c - dir * (ligne(larg) + 9.0) + Vector2(-dir.y, dir.x) * (larg * 0.5 + 0.9), dir])
	var poteau := CylinderMesh.new()
	poteau.top_radius = 0.035
	poteau.bottom_radius = 0.045
	poteau.height = 1.0
	poteau.radial_segments = 6
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.5, 0.5, 0.52)
	poteau.material = pm
	var disque := CylinderMesh.new()
	disque.top_radius = 0.34
	disque.bottom_radius = 0.34
	disque.height = 0.03
	disque.radial_segments = 20
	var dm := StandardMaterial3D.new()
	dm.vertex_color_use_as_albedo = true
	dm.roughness = 0.5
	disque.material = dm
	var barre := BoxMesh.new()
	barre.size = Vector3(0.5, 0.02, 0.11)
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.roughness = 0.5
	barre.material = bm
	var nit := items.size()
	var mp := MultiMesh.new()
	mp.transform_format = MultiMesh.TRANSFORM_3D
	mp.mesh = poteau
	mp.instance_count = nit
	var md := MultiMesh.new()
	md.transform_format = MultiMesh.TRANSFORM_3D
	md.use_colors = true
	md.mesh = disque
	md.instance_count = nit * 2                   # bord colore + fond
	var nb := 0
	for it in items:
		if it[0] == "sens_interdit" or it[0] == "stationnement":
			nb += 1
	var mb := MultiMesh.new()
	mb.transform_format = MultiMesh.TRANSFORM_3D
	mb.use_colors = true
	mb.mesh = barre
	mb.instance_count = nb
	var ib := 0
	for i in nit:
		var it: Array = items[i]
		var q: Vector2 = it[1]
		var dir: Vector2 = it[2]
		var yaw := atan2(-dir.x, -dir.y)
		var base := Basis(Vector3.UP, yaw)
		var face := base * Vector3(0, 0, 1)
		var haut := 2.3
		mp.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, haut, 1)), Vector3(q.x, haut * 0.5, q.y)))
		var centre := Vector3(q.x, haut + 0.2, q.y) + face * 0.05
		var plat := base * Basis(Vector3.RIGHT, PI / 2.0)       # cylindre couche : la face regarde les vehicules
		var bord := Color(0.85, 0.05, 0.05)
		var fond := Color(0.97, 0.97, 0.95)
		match it[0]:
			"limite":
				_panneaux_liste.append([str(limite_kmh), centre + face * 0.035, yaw])
			"sens_interdit":
				bord = Color(0.8, 0.04, 0.04)
				fond = bord
			"stationnement":
				bord = Color(0.8, 0.04, 0.04)
				fond = Color(0.1, 0.3, 0.8)
				_panneaux_liste.append(["P", centre + face * 0.035, yaw])
		md.set_instance_transform(i * 2, Transform3D(plat, centre))
		md.set_instance_color(i * 2, bord)
		md.set_instance_transform(i * 2 + 1, Transform3D(plat.scaled_local(Vector3(0.78, 1.0, 0.78)), centre + face * 0.012))
		md.set_instance_color(i * 2 + 1, fond)
		if it[0] == "sens_interdit":
			mb.set_instance_transform(ib, Transform3D(base * Basis(Vector3.RIGHT, PI / 2.0), centre + face * 0.03))
			mb.set_instance_color(ib, Color(1, 1, 1))
			ib += 1
		elif it[0] == "stationnement":
			mb.set_instance_transform(ib, Transform3D(base * Basis(Vector3(0, 0, 1), PI / 4.0) * Basis(Vector3.RIGHT, PI / 2.0), centre + face * 0.03))
			mb.set_instance_color(ib, Color(0.85, 0.05, 0.05))
			ib += 1
	for mm in [mp, md, mb]:
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
	for i in pool_textes:
		var l := Label3D.new()
		l.font_size = 72
		l.pixel_size = 0.004
		l.modulate = Color(0.05, 0.05, 0.05)
		l.outline_size = 0
		l.no_depth_test = false
		l.visible = false
		add_child(l)
		_pool_labels.append(l)


func _maj_textes() -> void:
	## Pose les chiffres (50, P) des panneaux les plus proches de la camera.
	var cam := get_viewport().get_camera_3d()
	if cam == null or _pool_labels.is_empty():
		return
	var c := cam.global_position
	var proches := []
	for p in _panneaux_liste:
		var d := c.distance_squared_to(p[1])
		if d < portee_textes * portee_textes:
			proches.append([d, p])
	proches.sort_custom(func(x, y): return x[0] < y[0])
	for i in _pool_labels.size():
		var l := _pool_labels[i]
		if i < proches.size():
			var p: Array = proches[i][1]
			l.text = p[0]
			l.global_transform = Transform3D(Basis(Vector3.UP, float(p[2])), p[1])
			l.visible = true
		else:
			l.visible = false
