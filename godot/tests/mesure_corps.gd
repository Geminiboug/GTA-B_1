extends SceneTree
## Mensurations du corps (chr_corps, pose de repos) : tours de poitrine, taille, hanches, bras, cuisse, mollet,
## largeur d'epaules. Compare aux valeurs reelles d'adultes (docs/PIPELINE.md, "Reference d'echelle").
## Lancement : godot --headless --path godot --script res://tests/mesure_corps.gd [-- chr_homme chr_femme ...]


func _slice(pts: PackedVector3Array, y: float, xmin: float, xmax: float) -> Array:
	## Points du maillage dans une tranche horizontale (|y - h| < 1,5 cm, x dans [xmin, xmax]).
	## Intersection exacte des triangles avec le plan horizontal y (pts = sommets des triangles, par trois).
	var out: Array = []
	for i in range(0, pts.size(), 3):
		for e in [[0, 1], [1, 2], [2, 0]]:
			var a: Vector3 = pts[i + e[0]]
			var b: Vector3 = pts[i + e[1]]
			if (a.y - y) * (b.y - y) < 0.0:
				var p := a.lerp(b, (y - a.y) / (b.y - a.y))
				if p.x >= xmin and p.x <= xmax:
					out.append(p)
	return out


func _girth(sl: Array) -> float:
	## Tour approche par l'ellipse englobante (Ramanujan).
	if sl.size() < 4:
		return 0.0
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for p: Vector3 in sl:
		lo = Vector3(minf(lo.x, p.x), 0, minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), 0, maxf(hi.z, p.z))
	var a := (hi.x - lo.x) * 0.5
	var b := (hi.z - lo.z) * 0.5
	return PI * (3.0 * (a + b) - sqrt((3.0 * a + b) * (a + 3.0 * b)))


func _initialize() -> void:
	var names := OS.get_cmdline_user_args()
	if names.is_empty():
		names = PackedStringArray(["chr_homme", "chr_femme"])
	for f in names:
		var m: Node = (load("res://assets/models/%s.glb" % f) as PackedScene).instantiate()
		var body := m.find_child("chr_corps", true, false) as MeshInstance3D
		var pts := PackedVector3Array()
		for v in body.mesh.get_faces():
			pts.append(v)
		var top := 0.0
		for p in pts:
			top = maxf(top, p.y)
		var k := top / 1.71            # hauteurs relatives a un homme de 1,71 m
		# epaules : largeur maximale du tronc + bras entre 76 % et 84 % de la taille
		var sw := 0.0
		for p in pts:
			if p.y > 1.30 * k and p.y < 1.44 * k:
				sw = maxf(sw, absf(p.x) * 2.0)
		var torso_x := 0.17 * k
		print("## %s (%.2f m)" % [f, top])
		print("  largeur aux epaules (bras compris) %.2f m" % sw)
		print("  tour de poitrine  %.2f m" % _girth(_slice(pts, 1.25 * k, -torso_x, torso_x)))
		print("  tour de taille    %.2f m" % _girth(_slice(pts, 1.03 * k, -0.16 * k, 0.16 * k)))
		print("  tour de hanches   %.2f m" % _girth(_slice(pts, 0.88 * k, -0.2 * k, 0.2 * k)))
		print("  tour de bras      %.2f m" % _girth(_slice(pts, 1.22 * k, 0.19 * k, 0.4 * k)))
		print("  tour de cuisse    %.2f m" % _girth(_slice(pts, 0.68 * k, 0.0, 0.25 * k)))
		print("  tour de mollet    %.2f m" % _girth(_slice(pts, 0.33 * k, 0.0, 0.25 * k)))
	quit()
