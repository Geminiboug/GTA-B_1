extends Node3D
## Occultation (optimisation) : chaque batiment plein (hors lieux visitables : maison, Ararat, aerogare) cache ce qu'il
## y a derriere lui. Une boite d'occultation legerement retrecie par batiment (de 6 m de haut et 40 m2 au moins) ;
## Godot ne dessine plus ce qu'elles masquent entierement (rendering/occlusion_culling).

@export var hauteur_min := 5.5
@export var aire_min := 40.0
@export var retrait := 0.6          # m : boite un peu plus petite que le batiment (pas de faux masquage)

var count := 0


func _ready() -> void:
	var data: Dictionary = Carte.zone().data   # lu une seule fois pour tout le jeu
	for b in data["buildings"]:
		var style := String(b.get("style", ""))
		var h := float(b.get("h", 0.0))
		if style.begins_with("lieu_") or style in ["terminal", "hangar"] or h < hauteur_min:
			continue
		var pts: Array = b["pts"]
		# rectangle oriente sur le plus long cote, ramene a l'interieur de l'emprise
		var best := 0.0
		var u := Vector2.RIGHT
		for i in pts.size():
			var a := Vector2(pts[i][0], pts[i][1])
			var c := Vector2(pts[(i + 1) % pts.size()][0], pts[(i + 1) % pts.size()][1])
			if a.distance_to(c) > best:
				best = a.distance_to(c)
				u = (c - a).normalized()
		var v := Vector2(-u.y, u.x)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in pts:
			var q := Vector2(p[0], p[1])
			lo = Vector2(minf(lo.x, q.dot(u)), minf(lo.y, q.dot(v)))
			hi = Vector2(maxf(hi.x, q.dot(u)), maxf(hi.y, q.dot(v)))
		var size := hi - lo - Vector2(retrait, retrait) * 2.0
		if size.x * size.y < aire_min or size.x < 3.0 or size.y < 3.0:
			continue
		var mid := (lo + hi) * 0.5
		var c2 := u * mid.x + v * mid.y
		var occ := OccluderInstance3D.new()
		var box := BoxOccluder3D.new()
		box.size = Vector3(size.x, h - 0.5, size.y)
		occ.occluder = box
		add_child(occ)
		occ.global_transform = Transform3D(Basis(Vector3.UP, atan2(-u.y, u.x)), Vector3(c2.x, (h - 0.5) * 0.5, c2.y))
		count += 1
