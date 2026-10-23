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


func _construire() -> void:
	var poteau := CylinderMesh.new()
	poteau.top_radius = 0.07
	poteau.bottom_radius = 0.09
	poteau.height = 4.2
	poteau.radial_segments = 6
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.18, 0.18, 0.2)
	poteau.material = pm
	var tete := BoxMesh.new()
	tete.size = Vector3(0.45, 0.45, 0.3)
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.vertex_color_use_as_albedo = true
	tete.material = tm
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
	var poses := []     # [type, position, noeud, axe]
	var approches := []
	for n in _feux.keys():
		for e in _carte.node_edges[n]:
			var p2 := _carte.edge_pts_from(e, n)
			if p2.size() < 2:
				continue
			var dir := -(p2[1] - p2[0]).normalized()       # sens de l'arrivee au carrefour
			var droite := Vector2(-dir.y, dir.x)
			var larg: float = float(_carte.edges[e]["width"])
			var c: Vector2 = _carte.nodes[n]
			var pos := c - dir * (ligne(larg) + 0.5) + droite * (larg * 0.5 + 0.8)
			poses.append(["feu", pos, n, _axe(dir)])
			approches.append([n, dir, larg])
	for n in _stops.keys():
		for e in (_stops[n] as Dictionary).keys():
			var p2 := _carte.edge_pts_from(e, n)
			if p2.size() < 2:
				continue
			var dir := -(p2[1] - p2[0]).normalized()
			var droite := Vector2(-dir.y, dir.x)
			var larg: float = float(_carte.edges[e]["width"])
			var c: Vector2 = _carte.nodes[n]
			poses.append(["stop", c - dir * (ligne(larg) + 0.5) + droite * (larg * 0.5 + 0.8), n, _axe(dir)])
			approches.append([n, dir, larg])
	_marquages(approches)
	var nf := 0
	var ns := 0
	for p in poses:
		if p[0] == "feu":
			nf += 1
		else:
			ns += 1
	var mp := MultiMesh.new()
	mp.transform_format = MultiMesh.TRANSFORM_3D
	mp.mesh = poteau
	mp.instance_count = poses.size()
	var mt := MultiMesh.new()
	mt.transform_format = MultiMesh.TRANSFORM_3D
	mt.use_colors = true
	mt.mesh = tete
	mt.instance_count = nf
	var ms := MultiMesh.new()
	ms.transform_format = MultiMesh.TRANSFORM_3D
	ms.mesh = panneau
	ms.instance_count = ns
	var i := 0
	var it := 0
	var isn := 0
	_tete_noeud.resize(nf)
	_tete_axe.resize(nf)
	for p in poses:
		var q: Vector2 = p[1]
		mp.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(q.x, 2.1, q.y)))
		i += 1
		if p[0] == "feu":
			mt.set_instance_transform(it, Transform3D(Basis.IDENTITY, Vector3(q.x, 4.4, q.y)))
			_tete_noeud[it] = p[2]
			_tete_axe[it] = p[3]
			it += 1
		else:
			ms.set_instance_transform(isn, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(q.x, 2.6, q.y)))
			isn += 1
	for mm in [mp, mt, ms]:
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
		if mm == mt:
			_tetes = inst
	_colorier()


func _colorier() -> void:
	if _tetes == null:
		return
	var mm := _tetes.multimesh
	for k in mm.instance_count:
		mm.set_instance_color(k, COUL[_etat_axe(_tete_noeud[k], _tete_axe[k])])


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
