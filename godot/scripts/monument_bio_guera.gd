extends Node3D
## Bio Guera (carrefour Erevan, rond-point en (679, -30)) : cavalier a la lance sur un cheval cabre, bronze dore, pose sur un
## rocher, socle de pierre noire polie a gradins et plaque ; hauteur totale ~11 m (refs/monuments/bio_guera/). Monument
## public reproduit fidelement (decision d'Olympe du 20/10/2026, docs/LEGAL.md 4), construit en volumes simples.

const OR := Color(0.78, 0.58, 0.2)
const PIERRE_NOIRE := Color(0.035, 0.035, 0.04)

@export var inscription := "Bio Guéra\ncombattant de la liberté\net de la dignité africaines"


func _ready() -> void:
	_construire()


func _mat_metal(c: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	return m


func _membre(parent: Node3D, mat: Material, de: Vector3, vers: Vector3, rayon: float, rayon2 := -1.0) -> void:
	## Cylindre (tronc de cone) d'un point a un autre, termine par des spheres (articulations, sabots).
	var d := vers - de
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rayon if rayon2 < 0.0 else rayon2
	cm.bottom_radius = rayon
	cm.height = d.length()
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = (de + vers) * 0.5
	var y := d.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	mi.basis = Basis(x, y, x.cross(y).normalized())
	for p in [de, vers]:
		var sp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rayon if p == de else (rayon if rayon2 < 0.0 else rayon2)
		sm.height = sm.radius * 2.0
		sm.radial_segments = 10
		sm.rings = 6
		sp.mesh = sm
		sp.material_override = mat
		parent.add_child(sp)
		sp.position = p


func _ovoide(parent: Node3D, mat: Material, centre: Vector3, taille: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = centre
	mi.rotation = rot
	mi.scale = taille


func _construire() -> void:
	var corps := StaticBody3D.new()
	add_child(corps)
	var noir := _mat_metal(PIERRE_NOIRE, 0.25, 0.12)       # pierre noire polie : reflets nets
	var or_ := _mat_metal(OR, 0.9, 0.38)
	# ilot pave du rond-point
	var ilot := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 11.0
	cy.bottom_radius = 11.0
	cy.height = 0.14
	cy.radial_segments = 40
	ilot.mesh = cy
	var pave := StandardMaterial3D.new()
	pave.albedo_color = Color(0.7, 0.66, 0.6)
	pave.roughness = 0.95
	ilot.material_override = pave
	ilot.position = Vector3(0, 0.07, 0)
	add_child(ilot)
	# socle : quatre gradins de pierre noire (le plus haut porte la plaque)
	var h := 0.14
	for g in [[8.0, 0.3], [6.6, 0.45], [5.4, 2.4], [5.7, 0.2]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(g[0], g[1], g[0])
		mi.mesh = bm
		mi.material_override = noir
		mi.position = Vector3(0, h + g[1] * 0.5, 0)
		add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(g[0], g[1], g[0])
		cs.shape = bs
		cs.position = mi.position
		corps.add_child(cs)
		h += g[1]
	# plaque de bronze sur la face avant du bloc (+Z)
	var pl := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(1.5, 0.7, 0.05)
	pl.mesh = pb
	pl.material_override = or_
	pl.position = Vector3(0.9, 1.5, 2.72)
	add_child(pl)
	var tx := Label3D.new()
	tx.text = inscription
	tx.font_size = 40
	tx.pixel_size = 0.0035
	tx.modulate = Color(0.1, 0.07, 0.02)
	tx.outline_size = 0
	tx.shaded = false
	tx.position = Vector3(0.9, 1.5, 2.755)
	add_child(tx)
	# rocher de bronze (plusieurs blocs inclines), puis le cheval cabre et son cavalier
	var sculpture := Node3D.new()
	sculpture.position = Vector3(0, h, 0)
	add_child(sculpture)
	for b in [[Vector3(0.0, 0.5, 0.0), Vector3(2.8, 1.0, 2.2), 6.0], [Vector3(0.3, 1.3, -0.3), Vector3(1.9, 1.0, 1.7), 22.0],
			[Vector3(-0.4, 2.0, -0.7), Vector3(1.2, 1.0, 1.1), -16.0], [Vector3(0.9, 0.8, 0.8), Vector3(1.2, 1.4, 0.9), 35.0],
			[Vector3(-0.9, 0.9, 0.5), Vector3(1.0, 1.8, 0.9), -28.0]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = b[1]
		mi.mesh = bm
		mi.material_override = or_
		mi.position = b[0]
		mi.rotation = Vector3(deg_to_rad(float(b[2]) * 0.4), deg_to_rad(float(b[2])), deg_to_rad(float(b[2]) * 0.25))
		sculpture.add_child(mi)
	var base := 2.4        # dessus du rocher
	# cheval : corps incline (cabre), poitrail haut, croupe sur le rocher ; il regarde vers +Z
	var d_corps := Vector3(0, 0.82, 0.57)
	var centre := Vector3(0, base + 1.75, 0.3)
	_ovoide(sculpture, or_, centre, Vector3(1.25, 3.0, 1.15), Vector3(deg_to_rad(35.0), 0, 0))
	_ovoide(sculpture, or_, centre + d_corps * 1.2 + Vector3(0, 0.0, 0.1), Vector3(1.1, 1.1, 1.1))          # poitrail
	_ovoide(sculpture, or_, centre - d_corps * 1.15, Vector3(1.2, 1.2, 1.2))                                # croupe
	# encolure et tete (museau leve)
	var cou0 := centre + d_corps * 1.45
	var cou1 := cou0 + Vector3(0, 1.05, 0.95)
	_membre(sculpture, or_, cou0, cou1, 0.36, 0.26)
	var tete1 := cou1 + Vector3(0, 0.25, 0.85)
	_membre(sculpture, or_, cou1, tete1, 0.24, 0.17)
	_ovoide(sculpture, or_, tete1 + Vector3(0, 0.02, 0.08), Vector3(0.34, 0.34, 0.5))
	_membre(sculpture, or_, cou0 + Vector3(0, 0.35, -0.2), cou1 + Vector3(0, 0.3, -0.25), 0.06)           # criniere
	# pattes avant levees, repliees (cuisse vers l'avant, canon vers le bas)
	for s in [-1.0, 1.0]:
		var e0 := centre + d_corps * 1.2 + Vector3(s * 0.38, -0.2, 0.2)
		var e1 := e0 + Vector3(s * 0.1, 0.25, 0.85)
		var e2 := e1 + Vector3(s * 0.05, -0.75, 0.55)
		_membre(sculpture, or_, e0, e1, 0.17, 0.13)
		_membre(sculpture, or_, e1, e2, 0.13, 0.09)
		_ovoide(sculpture, or_, e2 + Vector3(0, -0.08, 0.02), Vector3(0.2, 0.22, 0.24))              # sabot
	# pattes arriere : sur le rocher
	for s in [-1.0, 1.0]:
		var h0 := centre - d_corps * 1.15 + Vector3(s * 0.42, -0.1, 0.0)
		var h1 := h0 + Vector3(s * 0.1, -0.7, -0.55)
		var h2 := Vector3(s * 0.45, base + 0.12, h1.z + 0.15)
		_membre(sculpture, or_, h0, h1, 0.22, 0.16)
		_membre(sculpture, or_, h1, h2, 0.15, 0.1)
		_ovoide(sculpture, or_, h2 + Vector3(0, 0.0, 0.05), Vector3(0.24, 0.18, 0.34))
	# queue qui retombe en arriere
	var q0 := centre - d_corps * 1.55 + Vector3(0, 0.1, 0)
	var q1 := q0 + Vector3(0, -0.9, -0.9)
	_membre(sculpture, or_, q0, q1, 0.14, 0.05)
	_membre(sculpture, or_, q1, q1 + Vector3(0.0, -0.9, -0.2), 0.07, 0.03)
	# cavalier : buste penche vers l'avant, tete enturbannee, bras leve tenant la lance, manteau qui flotte
	var selle := centre + d_corps * 0.55 + Vector3(0, 0.55, 0.0)
	var torse1 := selle + Vector3(0, 1.05, 0.38)
	_membre(sculpture, or_, selle, torse1, 0.3, 0.27)
	_ovoide(sculpture, or_, torse1 + Vector3(0, 0.28, 0.06), Vector3(0.38, 0.4, 0.38))                  # tete
	_ovoide(sculpture, or_, torse1 + Vector3(0, 0.42, 0.04), Vector3(0.52, 0.28, 0.5))                  # turban
	for s in [-1.0, 1.0]:
		_membre(sculpture, or_, selle + Vector3(0, 0.1, 0.0), selle + Vector3(s * 0.45, -0.7, 0.55), 0.17, 0.12)   # cuisses
		_membre(sculpture, or_, selle + Vector3(s * 0.45, -0.7, 0.55), selle + Vector3(s * 0.5, -1.5, 0.3), 0.11, 0.08)   # jambes
	var epaule := torse1 + Vector3(0.28, 0.05, 0.0)
	var main := epaule + Vector3(0.35, 0.45, 0.35)
	_membre(sculpture, or_, epaule, main, 0.1, 0.08)                                                        # bras de la lance
	_membre(sculpture, or_, torse1 + Vector3(-0.28, 0.0, 0.0), torse1 + Vector3(-0.35, -0.3, 0.6), 0.1, 0.08)   # bras des renes
	var lance0 := main + Vector3(0.0, -1.6, 0.5)
	var lance1 := main + Vector3(0.0, 2.3, -0.85)
	_membre(sculpture, or_, lance0, lance1, 0.045, 0.035)
	var pointe := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.07
	cm.height = 0.5
	pointe.mesh = cm
	pointe.material_override = or_
	sculpture.add_child(pointe)
	var axe := (lance1 - lance0).normalized()
	pointe.position = lance1 + axe * 0.22
	var x2 := axe.cross(Vector3.RIGHT).normalized()
	pointe.basis = Basis(x2, axe, x2.cross(axe).normalized())
	var manteau := MeshInstance3D.new()
	var mb := BoxMesh.new()
	mb.size = Vector3(0.9, 1.7, 0.06)
	manteau.mesh = mb
	manteau.material_override = or_
	sculpture.add_child(manteau)
	manteau.position = selle + Vector3(0, 0.55, -0.45)
	manteau.rotation = Vector3(deg_to_rad(-25.0), 0, deg_to_rad(8.0))
	# projecteurs au pied du socle (le soir)
	for s in [-1.0, 1.0]:
		var l := SpotLight3D.new()
		l.position = Vector3(s * 3.4, 0.5, 3.6)
		l.light_color = Color(1.0, 0.88, 0.65)
		l.light_energy = 6.0
		l.spot_range = 26.0
		l.spot_angle = 24.0
		add_child(l)
		l.look_at_from_position(l.position, Vector3(0, h + 3.0, 0), Vector3.UP)
