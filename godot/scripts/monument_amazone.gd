extends Node3D
## Monument aux Amazones du Dahomey (esplanade des Amazones, boulevard de la Marina, Cotonou ; lat 6,3489 N, lon 2,4075 E) :
## statue monumentale en bronze d'une guerriere, un fusil dans la main levee, sur un haut socle a gradins au milieu d'une
## esplanade pavee. Monument public : il garde son vrai nom (docs/LEGAL.md 4). Forme simplifiee en volumes (cylindres, boites,
## spheres) ; proportions et pose d'apres les photos de refs/monuments/ quand elles seront fournies par Olympe.
## Eclairage du soir : projecteurs au pied du socle.

@export var hauteur_statue := 24.0        # m (la statue reelle fait une trentaine de metres socle compris)
@export var hauteur_socle := 6.0          # m
@export var rayon_esplanade := 22.0       # m

const BRONZE := Color(0.42, 0.3, 0.16)
const BRONZE_CLAIR := Color(0.55, 0.42, 0.24)
const PIERRE := Color(0.72, 0.68, 0.6)
const PAVE := Color(0.66, 0.6, 0.5)
const BORDURE := Color(0.9, 0.9, 0.88)

var _mats := {}
var _corps: StaticBody3D
var _lumieres: Array[SpotLight3D] = []
var _jour: Node
var _t := 0.0


func _ready() -> void:
	_corps = StaticBody3D.new()
	add_child(_corps)
	_esplanade()
	_socle()
	_statue()
	_projecteurs()


func _mat(c: Color, metal := 0.0, rough := 0.85) -> StandardMaterial3D:
	var cle := "%s_%s_%s" % [c.to_html(), metal, rough]
	if not _mats.has(cle):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metal
		m.roughness = rough
		_mats[cle] = m
	return _mats[cle]


func _boite(c: Color, pos: Vector3, taille: Vector3, yaw := 0.0, collision := true, metal := 0.0, rough := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = _mat(c, metal, rough)
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	if collision:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		cs.position = pos
		cs.rotation.y = yaw
		_corps.add_child(cs)
	return mi


func _cyl(c: Color, bas: Vector3, haut: Vector3, r_bas: float, r_haut: float, seg := 14, metal := 0.75, rough := 0.4) -> void:
	## Cylindre (ou tronc de cone) entre deux points.
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	var d := haut - bas
	cm.height = d.length()
	cm.bottom_radius = r_bas
	cm.top_radius = r_haut
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = _mat(c, metal, rough)
	add_child(mi)
	mi.position = (bas + haut) / 2.0
	if d.length() > 0.001:
		var axe := d.normalized()
		var rot_axis := Vector3.UP.cross(axe)
		if rot_axis.length() > 0.001:
			mi.basis = Basis(rot_axis.normalized(), Vector3.UP.angle_to(axe))


func _sphere(c: Color, pos: Vector3, r: float, ecrase := 1.0) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = 2.0 * r * ecrase
	mi.mesh = sm
	mi.material_override = _mat(c, 0.75, 0.4)
	mi.position = pos
	add_child(mi)


func _esplanade() -> void:
	# grande dalle pavee ronde avec bordure blanche, legerement surelevee
	var dalle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rayon_esplanade
	cm.bottom_radius = rayon_esplanade
	cm.height = 0.3
	cm.radial_segments = 48
	dalle.mesh = cm
	dalle.material_override = _mat(PAVE, 0.0, 0.9)
	dalle.position = Vector3(0, 0.1, 0)
	add_child(dalle)
	for i in 36:
		var a := TAU * (i + 0.5) / 36.0
		_boite(BORDURE if i % 2 == 0 else Color(0.08, 0.08, 0.08), Vector3(sin(a), 0, cos(a)) * (rayon_esplanade - 0.2) + Vector3(0, 0.3, 0),
			Vector3(3.8, 0.3, 0.4), a, false)


func _socle() -> void:
	# socle a gradins : 4 niveaux de pierre, escalier face au nord (-Z)
	var h := 0.25
	var niveaux := [[13.0, 0.9], [11.0, 0.9], [8.6, 1.2], [6.4, hauteur_socle - 3.0 - 0.25]]
	for n in niveaux:
		_boite(PIERRE, Vector3(0, h + n[1] / 2.0, 0), Vector3(n[0], n[1], n[0]), 0.0, true, 0.0, 0.8)
		h += n[1]
	# marches d'acces
	for k in 4:
		_boite(PIERRE, Vector3(0, 0.25 + k * 0.22, -7.0 - (3 - k) * 0.9), Vector3(7.0, 0.22, 0.9), 0.0, true)
	# plaque
	_boite(Color(0.12, 0.12, 0.12), Vector3(0, hauteur_socle - 1.6, -3.25), Vector3(3.0, 1.0, 0.05), 0.0, false, 0.4, 0.5)


func _statue() -> void:
	var b := hauteur_socle                       # pieds
	var H := hauteur_statue
	# jambes (jupe-pagne ceinte par une etoffe) : deux jambes legerement ecartees, pied avance
	_cyl(BRONZE, Vector3(-1.2, b, -0.6), Vector3(-1.0, b + 0.46 * H, 0.0), 0.55, 0.85)
	_cyl(BRONZE, Vector3(1.2, b, 0.8), Vector3(1.0, b + 0.46 * H, 0.0), 0.55, 0.85)
	_boite(BRONZE, Vector3(-1.2, b + 0.1, -0.9), Vector3(1.1, 0.3, 2.0), 0.0, false, 0.75, 0.4)             # pieds
	_boite(BRONZE, Vector3(1.2, b + 0.1, 0.6), Vector3(1.1, 0.3, 2.0), 0.0, false, 0.75, 0.4)
	# pagne : tronc de cone du bassin aux genoux
	_cyl(BRONZE_CLAIR, Vector3(0, b + 0.3 * H, 0), Vector3(0, b + 0.5 * H, 0), 2.4, 1.6)
	# torse : bassin, taille, poitrine
	_cyl(BRONZE, Vector3(0, b + 0.5 * H, 0), Vector3(0, b + 0.62 * H, 0), 1.45, 1.25)
	_cyl(BRONZE, Vector3(0, b + 0.62 * H, 0), Vector3(0, b + 0.76 * H, 0), 1.25, 1.75)
	_boite(BRONZE, Vector3(0, b + 0.79 * H, 0), Vector3(3.9, 0.9, 1.5), 0.0, false, 0.75, 0.4)               # epaules
	# cou et tete (bandeau)
	_cyl(BRONZE, Vector3(0, b + 0.8 * H, 0), Vector3(0, b + 0.85 * H, 0), 0.5, 0.45)
	_sphere(BRONZE, Vector3(0, b + 0.89 * H, 0), 1.0, 1.15)
	_cyl(BRONZE_CLAIR, Vector3(0, b + 0.9 * H, 0), Vector3(0, b + 0.93 * H, 0), 1.05, 1.0)                  # bandeau / coiffe
	# bras gauche le long du corps, avant-bras vers l'avant
	_cyl(BRONZE, Vector3(-2.0, b + 0.78 * H, 0), Vector3(-2.4, b + 0.62 * H, -0.2), 0.5, 0.42)
	_cyl(BRONZE, Vector3(-2.4, b + 0.62 * H, -0.2), Vector3(-1.8, b + 0.58 * H, -1.4), 0.42, 0.34)
	# bras droit leve, le fusil brandi en diagonale
	var epaule_d := Vector3(2.0, b + 0.78 * H, 0)
	var coude_d := Vector3(3.3, b + 0.88 * H, -0.3)
	var main_d := Vector3(3.9, b + 0.97 * H, -0.6)
	_cyl(BRONZE, epaule_d, coude_d, 0.5, 0.42)
	_cyl(BRONZE, coude_d, main_d, 0.42, 0.34)
	_sphere(BRONZE, main_d, 0.38)
	# fusil : canon long incline, crosse
	_cyl(Color(0.18, 0.15, 0.12), main_d + Vector3(-2.2, -1.4, 0.2), main_d + Vector3(5.4, 3.5, -0.4), 0.16, 0.12, 8, 0.7, 0.45)
	_cyl(Color(0.3, 0.2, 0.1), main_d + Vector3(-2.2, -1.4, 0.2), main_d + Vector3(-3.4, -2.3, 0.3), 0.3, 0.2, 8, 0.2, 0.7)
	# collision du fut (jambes et pagne) pour qu'on ne traverse pas la statue
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.4
	shape.height = 0.5 * H
	cs.shape = shape
	cs.position = Vector3(0, b + 0.25 * H, 0)
	_corps.add_child(cs)


func _projecteurs() -> void:
	# deux projecteurs au pied du socle, vers la statue (eclairage du soir)
	for s in [-1.0, 1.0]:
		var l := SpotLight3D.new()
		l.position = Vector3(s * 9.0, 0.6, -10.0)
		l.light_color = Color(1.0, 0.9, 0.72)
		l.light_energy = 14.0
		l.spot_range = 60.0
		l.spot_angle = 24.0
		l.shadow_enabled = false
		add_child(l)
		_lumieres.append(l)
		l.look_at_from_position(l.position, Vector3(0, hauteur_socle + 0.55 * hauteur_statue, 0), Vector3.UP)


func _process(delta: float) -> void:
	## Les projecteurs ne s'allument que la nuit (et pendant les delestages ils s'eteignent).
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	if _jour == null:
		_jour = get_tree().root.find_child("JourNuit", true, false)
	var on := 0.0
	if _jour:
		on = float(_jour.get("night")) * float(_jour.get("power"))
	for l in _lumieres:
		l.visible = on > 0.05
		l.light_energy = 14.0 * on
