extends Node3D
## Monuments publics reproduits fidelement (decision d'Olympe du 20/10/2026, docs/LEGAL.md 4) : construits ici en
## volumes simples d'apres les planches de refs/monuments/.
## - Place Calvaire de Fidjrosse (OSM node 4371709069) : place octogonale pavee de 14 m, muret et grille,
##   socle a gradins ocre, croix blanche vieillie ; hauteur totale ~5,5 m (refs/monuments/calvaire/).

@export var calvaire_pos := Vector3(-1038.4, 0.0, -912.4)   # projection osm_import.py (lat 6.3581270, lon 2.3719941)
@export var calvaire_yaw := 0.0                              # degres : ouverture des marches vers -Z (nord)
@export var bio_guera_pos := Vector3(679.0, 0.0, -30.0)    # centre du rond-point (donnees OSM)
@export var bio_guera_yaw := 180.0                           # degres : le cheval regarde vers -Z (nord)
@export var amazone_pos := Vector3(2890.0, 0.0, 109.0)     # monument aux Amazones (lat 6,3489 N, lon 2,4075 E), esplanade des Amazones
@export var amazone_yaw := 0.0                               # degres : la statue regarde vers -Z (nord, le palais de la Marina)

const BLANC_VIEILLI := Color(0.88, 0.87, 0.82)
const OCRE := Color(0.82, 0.72, 0.55)
const ENDUIT := Color(0.62, 0.6, 0.56)
const PAVE := Color(0.66, 0.55, 0.45)
const GRILLE := Color(0.12, 0.12, 0.13)

var _mats := {}


func _ready() -> void:
	_calvaire()
	_bio_guera()
	_amazone()


func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	if not _mats.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[c] = m
	return _mats[c]


func _boite(parent: Node3D, corps: StaticBody3D, c: Color, pos: Vector3, taille: Vector3, yaw := 0.0, collision := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	if collision:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		cs.position = pos
		cs.rotation.y = yaw
		corps.add_child(cs)


func _calvaire() -> void:
	var p := Node3D.new()
	p.name = "PlaceCalvaire"
	p.position = calvaire_pos
	p.rotation.y = deg_to_rad(calvaire_yaw)
	add_child(p)
	var corps := StaticBody3D.new()
	p.add_child(corps)
	# dalle pavee octogonale (14 m) et bordure peinte noir et blanc
	var dalle := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 7.0
	cy.bottom_radius = 7.0
	cy.height = 0.16
	cy.radial_segments = 8
	dalle.mesh = cy
	dalle.material_override = _mat(PAVE)
	dalle.position = Vector3(0, 0.08, 0)
	p.add_child(dalle)
	for i in 16:
		var a := TAU * (i + 0.5) / 16.0
		_boite(p, corps, Color(0.92, 0.92, 0.9) if i % 2 == 0 else Color(0.08, 0.08, 0.08),
			Vector3(sin(a), 0, cos(a)) * 6.95 + Vector3(0, 0.12, 0), Vector3(2.72, 0.24, 0.25), a, false)
	# muret octogonal (r 4,6 m) avec poteaux et grille, ouvert vers -Z pour les marches
	var r := 4.6
	for i in 8:
		var a0 := TAU * i / 8.0 + PI / 8.0
		var a1 := a0 + TAU / 8.0
		var mid := (a0 + a1) / 2.0
		if absf(wrapf(mid - PI, -PI, PI)) < 0.3:
			continue      # entree (cote -Z)
		var c := Vector3(sin(mid), 0, cos(mid)) * r * cos(PI / 8.0)
		var long := 2.0 * r * sin(PI / 8.0)
		_boite(p, corps, ENDUIT, c + Vector3(0, 0.35, 0), Vector3(long, 0.55, 0.25), mid)
		for k in 7:
			var t := (k + 0.5) / 7.0 - 0.5
			var off := Vector3(cos(mid), 0, -sin(mid)) * t * long
			_boite(p, corps, GRILLE, c + off + Vector3(0, 0.98, 0), Vector3(0.03, 0.7, 0.03), mid, false)
		_boite(p, corps, GRILLE, c + Vector3(0, 1.32, 0), Vector3(long, 0.04, 0.04), mid, false)
		_boite(p, corps, GRILLE, c + Vector3(0, 0.68, 0), Vector3(long, 0.04, 0.04), mid, false)
		_boite(p, corps, ENDUIT, Vector3(sin(a0), 0, cos(a0)) * r + Vector3(0, 0.7, 0), Vector3(0.35, 1.4, 0.35), 0.0)
	# marches d'entree
	for k in 3:
		_boite(p, corps, ENDUIT, Vector3(0, 0.08 + k * 0.12, -r + 0.3 + k * 0.3), Vector3(2.4, 0.16, 0.6))
	# socle a gradins ocre (2,1 m) puis fut, croix blanche (bras aux deux tiers)
	var h := 0.16
	for g in [[3.2, 0.55], [2.4, 0.5], [1.7, 0.5], [1.1, 0.55]]:
		_boite(p, corps, OCRE, Vector3(0, h + g[1] / 2.0, 0), Vector3(g[0], g[1], g[0]))
		h += g[1]
	_boite(p, corps, BLANC_VIEILLI, Vector3(0, h + 1.7, 0), Vector3(0.38, 3.4, 0.38))
	_boite(p, corps, BLANC_VIEILLI, Vector3(0, h + 2.45, 0), Vector3(2.0, 0.34, 0.34))
	# eclairage du soir : deux projecteurs au pied, vers la croix
	for s in [-1.0, 1.0]:
		var l := SpotLight3D.new()
		l.position = Vector3(s * 2.4, 0.3, -2.4)
		l.light_color = Color(1.0, 0.92, 0.8)
		l.light_energy = 2.0
		l.spot_range = 9.0
		l.spot_angle = 22.0
		p.add_child(l)
		l.look_at(p.global_position + Vector3(0, h + 2.0, 0) if p.is_inside_tree() else Vector3(0, h + 2.0, 0))


func _bio_guera() -> void:
	var b := Node3D.new()
	b.name = "BioGuera"
	b.set_script(preload("res://scripts/monument_bio_guera.gd"))
	b.position = bio_guera_pos
	b.rotation.y = deg_to_rad(bio_guera_yaw)
	add_child(b)


func _amazone() -> void:
	var a := Node3D.new()
	a.name = "Amazone"
	a.set_script(preload("res://scripts/monument_amazone.gd"))
	a.position = amazone_pos
	a.rotation.y = deg_to_rad(amazone_yaw)
	add_child(a)
