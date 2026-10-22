class_name AubeCotonou
extends Control
## "Aube sur Cotonou" (maquette validee par Olympe le 22/10/2026, proposition A) : ouverture du jeu et ecran de chargement.
## Aube de harmattan sur la lagune : soleil rouge qui se leve a l'est, ville basse en beton (5 etages au plus, pas de
## gratte-ciel), citernes, paraboles, linge, toles rouillees, une Etoile Rouge, une eglise a bandes rouges et blanches, un
## minaret, pont qui traverse la lagune, pirogues a la perche, statue de l'Amazone, cocotiers, poteaux et fils, tourterelles,
## avion de ligne en croisiere vers Cadjehoun, logo GTB. Tout est dessine en code (aucune photo, noms et enseignes inventes).
## Les trois plans de ville et l'avant-plan sont rendus une fois dans des SubViewport puis defilent en parallaxe.
## Coordonnees de dessin : 1280 x 720, mises a l'echelle pour couvrir le controle.

const W := 1280.0
const H := 720.0
const LW := 2600
const BRUME := Color("#e8b78a")
const FACADES := [Color("#d9b27c"), Color("#e8dcc0"), Color("#b9c9a8"), Color("#8fa8c4"), Color("#e0a58a"), Color("#b9b2a6"),
	Color("#d8c36a"), Color("#c98f6a"), Color("#9fb3b0")]
const LOGO := "res://assets/ui/logo_gtb.png"

@export var logo_apres := 3.0            # s avant l'apparition du logo
@export var duree_lever := 4.6           # s : le soleil monte puis reste en haut
@export var avec_logo := true
@export var logo_y := 0.44               # position verticale du logo (part de la hauteur)
@export var logo_echelle := 1.0

var t := 0.0
var _calques: Array = []                 # textures : loin, moyen, proche, avant-plan
var _vps: Array = []
var _pret := false
var _images := 0
var _bloom: GradientTexture2D
var _vignette: GradientTexture2D
var _logo: Texture2D


# ------------------------------------------------------------------ utilitaires
static func rnd(n: float) -> float:
	var s := sin(n * 127.1) * 43758.5453
	return s - floor(s)


static func ease_(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func ell(c: CanvasItem, ctr: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	c.draw_colored_polygon(pts, col)


static func bez(p0: Vector2, p1: Vector2, p2: Vector2, n := 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		out.append(p0 * (1 - u) * (1 - u) + p1 * 2 * u * (1 - u) + p2 * u * u)
	return out


static func poly(c: CanvasItem, pts: Array, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array(pts), col)


static func quad_grad(c: CanvasItem, r: Rect2, haut: Color, bas: Color) -> void:
	c.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([haut, haut, bas, bas]))


# ------------------------------------------------------------------ elements de la ville (couches pre-rendues)
static func bloc(c: CanvasItem, x: float, base: float, w: float, h: float, seed: float, hz: float, detail: bool) -> void:
	var col: Color = FACADES[int(rnd(seed * 1.9) * FACADES.size())]
	var f := col.lerp(BRUME, hz)
	var ombre := Color("#3a2a24").lerp(BRUME, hz + 0.1)
	c.draw_rect(Rect2(x, base - h, w, h), f)
	c.draw_rect(Rect2(x, base - h - 3, w, 3), Color("#2a1f1a").lerp(BRUME, hz + 0.05))
	c.draw_polygon(PackedVector2Array([Vector2(x, base - h), Vector2(x + w, base - h), Vector2(x + w, base), Vector2(x, base)]),
		PackedColorArray([Color(1, 0.86, 0.67, 0.28), Color(0.16, 0.08, 0.08, 0.28), Color(0.16, 0.08, 0.08, 0.28), Color(1, 0.86, 0.67, 0.28)]))
	if not detail:
		return
	var nl := maxi(1, int(h / 15.0))
	var nc := maxi(1, int(w / 11.0))
	for r in nl:
		for k in nc:
			var wx := x + 3.0 + k * (w - 6.0) / nc
			var wy := base - h + 6.0 + r * 15.0
			var allume := rnd(seed * 11.0 + r * 5.0 + k * 3.0) > 0.82
			c.draw_rect(Rect2(wx, wy, 5, 7), Color(1, 0.8, 0.47, 0.9) if allume else Color("#241a1a").lerp(BRUME, hz))
			if r > 0 and rnd(seed + r * 2.0 + k) > 0.6:
				c.draw_rect(Rect2(wx - 2, wy + 7, 9, 1.5), ombre)
	if rnd(seed * 4.4) > 0.5:
		c.draw_rect(Rect2(x + 4, base - h - 13, 9, 10), Color("#15100f").lerp(BRUME, hz))
		c.draw_rect(Rect2(x + 8, base - h - 15, 1.5, 3), Color("#15100f").lerp(BRUME, hz))
	if rnd(seed * 6.6) > 0.7:
		c.draw_arc(Vector2(x + w - 8, base - h - 8), 5.0, 0.0, PI, 8, ombre, 1.0)
	if rnd(seed * 8.8) > 0.75:
		c.draw_line(Vector2(x + 6, base - h - 6), Vector2(x + w - 6, base - h - 6), Color("#c85a3a").lerp(BRUME, hz), 1.2)
		c.draw_rect(Rect2(x + 12, base - h - 6, 4, 6), Color("#e8d8b0").lerp(BRUME, hz))
		c.draw_rect(Rect2(x + 22, base - h - 6, 4, 5), Color("#e8d8b0").lerp(BRUME, hz))
	if rnd(seed * 2.2) > 0.55:
		c.draw_rect(Rect2(x, base - h - 8, w * 0.6, 5), Color("#6a3d28").lerp(BRUME, hz))


static func maison_basse(c: CanvasItem, x: float, base: float, w: float, h: float, seed: float, hz: float) -> void:
	c.draw_rect(Rect2(x, base - h, w, h), (FACADES[int(rnd(seed) * FACADES.size())] as Color).lerp(BRUME, hz))
	var toit := [Color("#7a4a34"), Color("#8a8a86"), Color("#5e4636")][int(rnd(seed * 2.0) * 3.0)] as Color
	poly(c, [Vector2(x - 3, base - h), Vector2(x + w * 0.15, base - h - 9), Vector2(x + w * 0.85, base - h - 9), Vector2(x + w + 3, base - h)], toit.lerp(BRUME, hz))
	var l := 0.0
	while l < w / 3.0:
		c.draw_rect(Rect2(x + l * 3.0, base - h - 8, 1, 8), Color(0, 0, 0, 0.12))
		l += 3.0
	c.draw_rect(Rect2(x + w * 0.4, base - h * 0.55, w * 0.2, h * 0.55), Color("#2a1c18").lerp(BRUME, hz))


static func etoile(c: CanvasItem, x: float, base: float, s: float, col: Color) -> void:
	poly(c, [Vector2(x - 6 * s, base), Vector2(x - 2.5 * s, base - 150 * s), Vector2(x + 2.5 * s, base - 150 * s), Vector2(x + 6 * s, base)], col)
	c.draw_rect(Rect2(x - 15 * s, base - 8 * s, 30 * s, 8 * s), col)
	c.draw_rect(Rect2(x - 10 * s, base - 16 * s, 20 * s, 8 * s), col)
	var pts := PackedVector2Array()
	for k in 10:
		var r := (6.0 if k % 2 == 1 else 16.0) * s
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(Vector2(x + cos(a) * r, base - 166 * s + sin(a) * r))
	c.draw_colored_polygon(pts, Color("#9a1d2b"))


static func eglise(c: CanvasItem, x: float, base: float, s: float, hz: float) -> void:
	var bd := [Color("#a43d2e"), Color("#eadfca")]
	for i in 12:
		c.draw_rect(Rect2(x, base - (i + 1) * 12 * s, 36 * s, 12 * s), (bd[i % 2] as Color).lerp(BRUME, hz))
	poly(c, [Vector2(x - 3 * s, base - 144 * s), Vector2(x + 18 * s, base - 186 * s), Vector2(x + 39 * s, base - 144 * s)], Color("#7a2c22").lerp(BRUME, hz))
	c.draw_rect(Rect2(x + 17 * s, base - 210 * s, 2 * s, 26 * s), Color("#7a2c22").lerp(BRUME, hz))
	c.draw_rect(Rect2(x + 11 * s, base - 202 * s, 14 * s, 2 * s), Color("#7a2c22").lerp(BRUME, hz))
	for j in 5:
		c.draw_rect(Rect2(x - 80 * s, base - (j + 1) * 12 * s, 80 * s, 12 * s), (bd[j % 2] as Color).lerp(BRUME, hz))
	c.draw_rect(Rect2(x - 60 * s, base - 30 * s, 10 * s, 30 * s), Color("#3a2418").lerp(BRUME, hz))


static func minaret(c: CanvasItem, x: float, base: float, s: float, hz: float) -> void:
	var col := Color("#e6dcc4").lerp(BRUME, hz)
	c.draw_rect(Rect2(x - 5 * s, base - 130 * s, 10 * s, 130 * s), col)
	c.draw_rect(Rect2(x - 8 * s, base - 100 * s, 16 * s, 4 * s), col)
	var dome := bez(Vector2(x - 6 * s, base - 130 * s), Vector2(x, base - 156 * s), Vector2(x + 6 * s, base - 130 * s))
	c.draw_colored_polygon(dome, col)
	c.draw_rect(Rect2(x - 0.7 * s, base - 168 * s, 1.4 * s, 14 * s), col)


static func palmier(c: CanvasItem, x: float, y: float, s: float) -> void:
	c.draw_polyline(bez(Vector2(x, y), Vector2(x + 10 * s, y - 60 * s), Vector2(x + 4 * s, y - 112 * s)), Color("#3a2a1c"), 7 * s, true)
	for r in 9:
		c.draw_line(Vector2(x - 3 * s + r * 0.2, y - r * 12 * s), Vector2(x + 4 * s, y - r * 12 * s - 3 * s), Color("#4a3624"), 2 * s)
	var tx := x + 4 * s
	var ty := y - 112 * s
	for k in 11:
		var a0 := -PI * 0.95 + k * (PI * 0.95 / 5.2)
		var L := (62.0 + (k % 3) * 8.0) * s
		var ex := tx + cos(a0) * L
		var ey := ty + sin(a0) * L * 0.55 + L * 0.42
		c.draw_polyline(bez(Vector2(tx, ty), Vector2(tx + cos(a0) * L * 0.6, ty + sin(a0) * L * 0.75), Vector2(ex, ey), 8), Color("#1f3a1c"), 2.4 * s, true)
		for f in range(1, 9):
			var u2 := f / 9.0
			var px := tx + (ex - tx) * u2
			var py := ty + (ey - ty) * u2 - sin(u2 * PI) * L * 0.18
			var dx := sin(a0 + 1.4) * 15.0 * s * (1.0 - u2 * 0.5)
			var dy := 11.0 * s * (1.0 - u2 * 0.4)
			c.draw_line(Vector2(px, py), Vector2(px + dx, py + dy), Color("#2c4a24"), 1.1 * s)
			c.draw_line(Vector2(px, py), Vector2(px - dx, py + dy), Color("#2c4a24"), 1.1 * s)
	ell(c, Vector2(tx - 3 * s, ty + 4 * s), 4 * s, 4 * s, Color("#5a3d22"))
	ell(c, Vector2(tx + 4 * s, ty + 6 * s), 4 * s, 4 * s, Color("#5a3d22"))


static func statue_amazone(c: CanvasItem, x: float, y: float, s: float) -> void:
	## Statue de l'Amazone (guerriere du Dahomey) sur son socle, face a l'eau ; bronze sombre, eclaire par l'est.
	var bronze := Color("#7a4e2a")
	c.draw_rect(Rect2(x - 26 * s, y - 14 * s, 52 * s, 14 * s), Color("#c9b79a"))
	c.draw_rect(Rect2(x - 20 * s, y - 40 * s, 40 * s, 26 * s), Color("#c9b79a"))
	c.draw_rect(Rect2(x - 24 * s, y - 16 * s, 48 * s, 3 * s), Color("#a89678"))
	c.draw_rect(Rect2(x - 18 * s, y - 42 * s, 36 * s, 3 * s), Color("#a89678"))
	poly(c, [Vector2(x - 9 * s, y - 42 * s), Vector2(x - 13 * s, y - 62 * s), Vector2(x - 5 * s, y - 62 * s), Vector2(x - 1 * s, y - 50 * s),
		Vector2(x + 5 * s, y - 62 * s), Vector2(x + 12 * s, y - 62 * s), Vector2(x + 8 * s, y - 42 * s)], bronze)
	poly(c, [Vector2(x - 12 * s, y - 62 * s), Vector2(x - 9 * s, y - 92 * s), Vector2(x + 9 * s, y - 92 * s), Vector2(x + 13 * s, y - 62 * s)], bronze)
	ell(c, Vector2(x, y - 98 * s), 6 * s, 6 * s, bronze)
	c.draw_rect(Rect2(x - 6 * s, y - 106 * s, 12 * s, 4 * s), bronze)
	c.draw_line(Vector2(x + 8 * s, y - 88 * s), Vector2(x + 20 * s, y - 108 * s), bronze, 4 * s)
	c.draw_line(Vector2(x + 20 * s, y - 108 * s), Vector2(x + 30 * s, y - 132 * s), bronze, 2.2 * s)
	c.draw_polyline(PackedVector2Array([Vector2(x - 8 * s, y - 86 * s), Vector2(x - 22 * s, y - 80 * s), Vector2(x - 28 * s, y - 100 * s)]), bronze, 2.2 * s)
	c.draw_line(Vector2(x - 38 * s, y - 70 * s), Vector2(x - 18 * s, y - 104 * s), bronze, 3 * s)
	var clair := Color(1, 0.78, 0.51, 0.55)
	c.draw_line(Vector2(x + 9 * s, y - 92 * s), Vector2(x + 13 * s, y - 62 * s), clair, 1.6 * s)
	c.draw_line(Vector2(x + 20 * s, y - 108 * s), Vector2(x + 30 * s, y - 132 * s), clair, 1.6 * s)


## Noeud qui dessine une couche une seule fois (dans un SubViewport).
class Couche extends Node2D:
	var genre := 0

	func _draw() -> void:
		match genre:
			0:
				var x := 0.0
				var i := 0
				while x < AubeCotonou.LW:
					var bw := 18.0 + AubeCotonou.rnd(i * 3.1) * 30.0
					var bh := 14.0 + AubeCotonou.rnd(i * 5.7) * 40.0
					AubeCotonou.bloc(self, x, 260.0, bw, bh, i, 0.72, false)
					x += bw + 1.0
					i += 1
				AubeCotonou.minaret(self, 1700.0, 260.0, 0.9, 0.72)
			1:
				var x := 0.0
				var i := 100
				while x < AubeCotonou.LW:
					var bw := 26.0 + AubeCotonou.rnd(i * 3.1) * 40.0
					var bh := 22.0 + AubeCotonou.rnd(i * 5.7) * 50.0
					if i % 4 == 0:
						AubeCotonou.maison_basse(self, x, 300.0, bw, 26.0 + AubeCotonou.rnd(i) * 16.0, i, 0.5)
					else:
						AubeCotonou.bloc(self, x, 300.0, bw, bh, i, 0.5, true)
					x += bw + 2.0
					i += 1
				AubeCotonou.etoile(self, 620.0, 300.0, 1.1, Color("#3a1f20").lerp(AubeCotonou.BRUME, 0.45))
				AubeCotonou.eglise(self, 1500.0, 300.0, 1.0, 0.45)
			2:
				var x := 0.0
				var i := 300
				while x < AubeCotonou.LW:
					var bw := 40.0 + AubeCotonou.rnd(i * 3.1) * 50.0
					var bh := 28.0 + AubeCotonou.rnd(i * 5.7) * 54.0
					if i % 3 == 0:
						AubeCotonou.maison_basse(self, x, 260.0, bw, 34.0 + AubeCotonou.rnd(i) * 20.0, i, 0.2)
					else:
						AubeCotonou.bloc(self, x, 260.0, bw, bh, i, 0.2, true)
					x += bw + 3.0
					i += 1
			3:
				AubeCotonou.avant_plan(self)


## Avant-plan (pont, berge, roseaux, cocotiers, statue, poteaux et fils), 1280 x 720, fond transparent.
static func avant_plan(c: CanvasItem) -> void:
	var py := 556.0
	c.draw_rect(Rect2(-20, py, W + 40, 5), Color("#3a2a24"))
	for q in 16:
		c.draw_rect(Rect2(q * 90 - 4, py + 5, 7, 32), Color("#4a3830"))
	c.draw_line(Vector2(-20, py - 14), Vector2(W + 20, py - 14), Color("#4a3830"), 1.5)
	for h2 in 76:
		var tx := -20.0 + h2 * 17.5
		c.draw_polyline(PackedVector2Array([Vector2(tx, py), Vector2(tx + 9, py - 14), Vector2(tx + 17.5, py)]), Color("#4a3830"), 1.5)
	var rive := PackedVector2Array([Vector2(0, H), Vector2(0, 650)])
	var rx := 0.0
	while rx <= W:
		rive.append(Vector2(rx, 648.0 + sin(rx * 0.05) * 4.0 + rnd(rx) * 4.0))
		rx += 20.0
	rive.append(Vector2(W, 650))
	rive.append(Vector2(W, H))
	var cols := PackedColorArray()
	for p in rive:
		cols.append(Color("#a47c52") if p.y < 700.0 else Color("#5a3f2a"))
	c.draw_polygon(rive, cols)
	for rs in 70:
		var rxx := rnd(rs * 4.1) * W
		var rh := 14.0 + rnd(rs * 2.3) * 26.0
		c.draw_polyline(bez(Vector2(rxx, 656), Vector2(rxx + 4, 656 - rh * 0.6), Vector2(rxx + 7, 656 - rh), 5), Color("#9aa05a"), 1.6, true)
	statue_amazone(c, 560.0, 664.0, 1.0)
	palmier(c, 150.0, 664.0, 1.3)
	palmier(c, 1110.0, 662.0, 1.5)
	palmier(c, 1225.0, 672.0, 1.0)
	var pot := [-20.0, 404.0, 1010.0, 1330.0]
	for px in pot:
		c.draw_rect(Rect2(px - 2, 430, 5, 240), Color("#3a2a22"))
		c.draw_rect(Rect2(px - 20, 446, 42, 4), Color("#3a2a22"))
		c.draw_rect(Rect2(px - 14, 464, 30, 3), Color("#3a2a22"))
	for w2 in 4:
		var hy := 448.0 + w2 * 6.0 + (10.0 if w2 > 1 else 0.0)
		for sg in pot.size() - 1:
			var xa: float = pot[sg]
			var xb: float = pot[sg + 1]
			var fl := 10.0 + (xb - xa) * 0.045 + w2 * 3.0
			c.draw_polyline(bez(Vector2(xa, hy), Vector2((xa + xb) / 2.0, hy + fl * 2.0), Vector2(xb, hy), 16), Color(0.157, 0.11, 0.094, 0.75), 1.1, true)


# ------------------------------------------------------------------ elements animes
func _pirogue(x: float, y: float, s: float, tt: float) -> void:
	## Pirogue de lagune creusee dans un tronc : coque longue et basse aux bouts releves, bande peinte, pecheur debout a l'arriere
	## qui pousse a la perche, filet en tas.
	var col := Color("#1c120e")
	var L := 70.0 * s
	var coque := bez(Vector2(x - L, y - 11 * s), Vector2(x - L * 0.55, y + 3 * s), Vector2(x, y + 4 * s))
	coque.append_array(bez(Vector2(x, y + 4 * s), Vector2(x + L * 0.6, y + 3 * s), Vector2(x + L, y - 9 * s)))
	coque.append(Vector2(x + L * 0.94, y - 5 * s))
	coque.append_array(bez(Vector2(x + L * 0.94, y - 5 * s), Vector2(x + L * 0.5, y - 2 * s), Vector2(x, y - 1 * s)))
	coque.append_array(bez(Vector2(x, y - 1 * s), Vector2(x - L * 0.5, y - 2 * s), Vector2(x - L * 0.94, y - 6 * s)))
	draw_colored_polygon(coque, col)
	draw_rect(Rect2(x - L * 0.6, y - 1.5 * s, L * 1.1, 1.8 * s), Color("#c8452a"))
	draw_rect(Rect2(x - L * 0.2, y - 3 * s, L * 0.5, 1.4 * s), Color("#e8dcc0"))
	var px := x - L * 0.55
	var sw := sin(tt * 1.3) * 3.0 * s
	draw_rect(Rect2(px - 2.5 * s, y - 26 * s, 5 * s, 17 * s), col)
	ell(self, Vector2(px, y - 30 * s), 3.4 * s, 3.4 * s, col)
	draw_line(Vector2(px + 1 * s, y - 20 * s), Vector2(px + 10 * s, y - 24 * s), col, 1.6 * s)
	draw_line(Vector2(px + 10 * s + sw, y - 50 * s), Vector2(px + 22 * s - sw, y + 6 * s), col, 1.3 * s)
	ell(self, Vector2(x + L * 0.15, y - 6 * s), 15 * s, 5 * s, col)


func _avion(x: float, y: float, s: float, ang: float) -> void:
	## Avion de ligne bimoteur en croisiere (train rentre), nez vers la gauche, eclaire par le soleil de l'est ; livree inventee.
	draw_set_transform_matrix(_base_xf * Transform2D(ang, Vector2(-s, s), 0.0, Vector2(x, y)))
	poly(self, [Vector2(-50, -2), Vector2(-66, -9), Vector2(-60, -9), Vector2(-40, -2)], Color("#b7b2ac"))
	poly(self, [Vector2(-52, -7), Vector2(-67, -33), Vector2(-55, -33), Vector2(-36, -8)], Color("#efe8da"))
	poly(self, [Vector2(-60, -22), Vector2(-67, -33), Vector2(-59, -33), Vector2(-54, -22)], Color("#c0572a"))
	var corps := bez(Vector2(-72, -8), Vector2(-60, -10), Vector2(-46, -10), 6)
	corps.append(Vector2(44, -10))
	corps.append_array(bez(Vector2(44, -10), Vector2(62, -9), Vector2(70, 0), 6))
	corps.append_array(bez(Vector2(70, 0), Vector2(62, 7), Vector2(44, 8), 6))
	corps.append(Vector2(-30, 8))
	corps.append_array(bez(Vector2(-30, 8), Vector2(-56, 4), Vector2(-72, -8), 6))
	draw_polygon(corps, _degrade_corps(corps))
	draw_rect(Rect2(-34, 2, 82, 1.6), Color("#c0572a"))
	for k in 22:
		draw_rect(Rect2(-36 + k * 3.6, -5, 1.7, 2.2), Color("#26303f"))
	poly(self, [Vector2(58, -6), Vector2(67, -2), Vector2(60, -2)], Color("#26303f"))
	poly(self, [Vector2(14, 3), Vector2(-24, 22), Vector2(-33, 22), Vector2(-6, 3)], Color("#d6d0c4"))
	poly(self, [Vector2(-24, 22), Vector2(-30, 17), Vector2(-33, 22)], Color("#9c978e"))
	draw_rect(Rect2(-9, 4, 3, 5), Color("#a6a095"))
	ell(self, Vector2(-5, 12), 11, 4.6, Color("#b5afa4"))
	ell(self, Vector2(4.5, 12), 1.8, 3.6, Color("#2b2b30"))
	draw_rect(Rect2(8, -9, 36, 1.4), Color(1, 0.78, 0.47, 0.6))
	draw_set_transform_matrix(_base_xf)


func _degrade_corps(pts: PackedVector2Array) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in pts:
		var u := clampf((p.y + 10.0) / 19.0, 0.0, 1.0)
		cols.append(Color("#fbf4e6").lerp(Color("#e4ddd0"), minf(u * 1.8, 1.0)).lerp(Color("#9e98a0"), maxf(u - 0.55, 0.0) * 2.2))
	return cols


func _aile(ox: float, oy: float, ang: float, L: float, s: float, col: Color, col2: Color) -> void:
	var tx := ox - cos(ang) * 4 * s
	var ty := oy - sin(ang) * L
	var sgn := 1.0 if ty - oy >= 0.0 else -1.0
	var pts := bez(Vector2(ox + 5 * s, oy), Vector2(ox + 4 * s, oy + (ty - oy) * 0.55), Vector2(tx - 3 * s, ty), 8)
	pts.append(Vector2(tx + 3 * s, ty - 4 * s * sgn))
	pts.append(Vector2(ox - 9 * s, oy + (ty - oy) * 0.3))
	pts.append(Vector2(ox - 7 * s, oy))
	draw_colored_polygon(pts, col)
	for f in 5:
		var u2 := 0.5 + f * 0.11
		var px := ox + (tx - ox) * u2
		var py := oy + (ty - oy) * u2
		poly(self, [Vector2(px - 2 * s, py), Vector2(px - 7 * s + f * 0.6 * s, py - (ty - oy) * 0.02 + 3 * s), Vector2(px + 2 * s, py + 1 * s)], col2)


func _tourterelle(x: float, y: float, s: float, ph: float) -> void:
	## Tourterelle (pigeon) en vol vers la droite : corps en goutte, petite tete, collier sombre, queue en eventail a bout clair,
	## deux ailes a plumes primaires qui battent (la lointaine est plus sombre).
	draw_set_transform_matrix(_base_xf * Transform2D(0.0, Vector2.ONE, 0.0, Vector2(x, y)))
	var th := sin(ph)
	var ang := th * 0.95
	_aile(-1 * s, -14 * s, -ang * 0.8 + 0.15, 24 * s, s, Color("#6b5d4c"), Color("#4e4234"))
	poly(self, [Vector2(-8 * s, -14 * s), Vector2(-27 * s, -19 * s + th * 2 * s), Vector2(-27 * s, -10 * s + th * 2 * s)], Color("#bfae94"))
	poly(self, [Vector2(-23 * s, -18.5 * s + th * 2 * s), Vector2(-27 * s, -19 * s + th * 2 * s), Vector2(-27 * s, -10 * s + th * 2 * s), Vector2(-24 * s, -11.5 * s + th * 2 * s)], Color("#e8dcc6"))
	var corps := bez(Vector2(-9 * s, -14 * s), Vector2(-4 * s, -21 * s), Vector2(8 * s, -19 * s), 6)
	corps.append_array(bez(Vector2(8 * s, -19 * s), Vector2(14 * s, -16 * s), Vector2(12 * s, -12 * s), 6))
	corps.append_array(bez(Vector2(12 * s, -12 * s), Vector2(2 * s, -6 * s), Vector2(-9 * s, -14 * s), 6))
	draw_colored_polygon(corps, Color("#d6c8ae"))
	ell(self, Vector2(13 * s, -17 * s), 4.2 * s, 4.2 * s, Color("#d4c3a8"))
	ell(self, Vector2(11 * s, -15.6 * s), 2.4 * s, 2.4 * s, Color("#6e4a52"))
	draw_rect(Rect2(10.5 * s, -16.2 * s, 5 * s, 1.3 * s), Color("#2b2420"))
	ell(self, Vector2(14.6 * s, -17.6 * s), 0.8 * s, 0.8 * s, Color("#1a1412"))
	poly(self, [Vector2(16.8 * s, -17.5 * s), Vector2(20.5 * s, -16.8 * s), Vector2(16.8 * s, -16 * s)], Color("#4a4036"))
	_aile(2 * s, -15 * s, ang + 0.05, 27 * s, s, Color("#7d6c58"), Color("#554838"))
	draw_set_transform_matrix(_base_xf)


# ------------------------------------------------------------------ cycle de vie
var _base_xf := Transform2D.IDENTITY


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_logo = load(LOGO) as Texture2D if avec_logo and ResourceLoader.exists(LOGO) else null
	var tailles := [Vector2i(LW, 260), Vector2i(LW, 300), Vector2i(LW, 260), Vector2i(1280, 720)]
	for i in 4:
		var vp := SubViewport.new()
		vp.size = tailles[i]
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(vp)
		var cch := Couche.new()
		cch.genre = i
		vp.add_child(cch)
		_vps.append(vp)
	_bloom = _radial([0.0, 0.35, 1.0], [Color(1, 0.78, 0.47, 1.0), Color(1, 0.59, 0.31, 0.28), Color(1, 0.59, 0.27, 0.0)])
	_vignette = _radial([0.0, 0.39, 1.0], [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.5)])


func _radial(offs: Array, cols: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	return gt


func rejouer() -> void:
	t = 0.0


func _process(delta: float) -> void:
	t += minf(delta, 1.0 / 20.0)      # une etape lente du chargement ne fait pas sauter l'animation
	_images += 1
	if not _pret and _images > 3:
		for vp in _vps:
			_calques.append((vp as SubViewport).get_texture())
		_pret = true
	queue_redraw()


func _draw() -> void:
	if not _pret:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#17140f"))
		return
	var f := maxf(size.x / W, size.y / H)
	var dec := (size - Vector2(W, H) * f) * 0.5
	_base_xf = Transform2D(0.0, Vector2(f, f), 0.0, dec)
	draw_set_transform_matrix(_base_xf)
	var u := ease_(t / duree_lever)
	var cam := t * 16.0
	# ciel : harmattan (haut bleu poussiereux, horizon orange)
	var c0 := Color("#0d1430").lerp(Color("#5f7aa8"), u)
	var c1 := Color("#35264a").lerp(Color("#d9a58f"), u)
	var c2 := Color("#5a2e2e").lerp(Color("#f2bd84"), u)
	var c3 := Color("#6a3a30").lerp(Color("#f7cf94"), u)
	quad_grad(self, Rect2(0, 0, W, 240), c0, c1)
	quad_grad(self, Rect2(0, 240, W, 168), c1, c2)
	quad_grad(self, Rect2(0, 408, W, 72), c2, c3)
	var sx := 820.0
	var sy := 508.0 - u * 165.0
	draw_texture_rect(_bloom, Rect2(sx - 460, sy - 460, 920, 920), false, Color(1, 1, 1, 0.22 + 0.4 * u))
	ell(self, Vector2(sx, sy), 40, 40, Color("#c8452a").lerp(Color("#fff0c0"), u))
	# avion de ligne qui traverse vers Cadjehoun
	_avion(1380.0 - t * 85.0, 130.0 + t * 85.0 * 0.05, 0.9, -0.05)
	# trois plans de ville
	_plan(0, 0.18, 480.0, cam)
	_plan(1, 0.4, 486.0, cam)
	_plan(2, 0.85, 494.0, cam)
	# lagune
	var l0 := Color("#3a2a32").lerp(Color("#e0a26a"), u)
	var l1 := Color("#201620").lerp(Color("#a8704f"), u)
	var l2 := Color("#0e0a0e").lerp(Color("#3a2724"), u)
	quad_grad(self, Rect2(0, 490, W, 0.35 * (H - 490)), l0, l1)
	quad_grad(self, Rect2(0, 490 + 0.35 * (H - 490), W, 0.65 * (H - 490)), l1, l2)
	# reflet de la ville dans l'eau (tranches decalees : vaguelettes)
	var pro: Texture2D = _calques[2]
	for s in 60:
		var wob := sin(t * 2.0 + s * 0.5) * (1.0 + s * 0.05)
		draw_texture_rect_region(pro, Rect2(wob, 494 + s * 2.0, 1300, 2), Rect2(0, 259.0 - s * 1.6, 1300, 1.6), Color(1, 1, 1, 0.28))
	for k in 46:
		var yy := 496.0 + k * 5.0 + k * k * 0.07
		var ww := (34.0 - k * 0.6) * (1.0 + 0.5 * sin(t * 2.4 + k * 0.8))
		var a := (0.6 - k * 0.012) * u
		if a > 0.0 and ww > 0.0:
			draw_rect(Rect2(sx - ww * 2.2, yy, ww * 4.4, 2), Color(1, 0.86, 0.59, a))
	_pirogue(820.0 + sin(t * 0.8) * 4.0, 606.0, 1.0, t)
	_pirogue(1080.0 - sin(t * 0.7) * 3.0, 630.0, 0.75, t + 2.0)
	# avant-plan (pont, berge, roseaux, statue, cocotiers, poteaux, fils) : sombre au debut, lumineux a la fin
	var lum := lerpf(0.4, 1.0, u)
	draw_texture_rect(_calques[3], Rect2(0, 0, W, H), false, Color(lum, lum * 0.95, lum * 0.92, 1.0))
	# tourterelles
	for i in 5:
		var bx := fposmod(t * 70.0 + i * 95.0, W + 160.0) - 80.0
		var by := 240.0 + (i % 3) * 22.0 - i * 5.0 + sin(t * 1.1 + i) * 6.0
		_tourterelle(bx, by, 0.95 - (i % 2) * 0.1, t * 10.0 + i * 1.9)
	# reflets d'objectif, vignette
	for fl in [[0.35, 26.0, 0.14], [0.6, 14.0, 0.1], [1.2, 40.0, 0.08]]:
		var fx: float = sx + (W / 2.0 - sx) * float(fl[0]) * 1.6
		var fy: float = sy + (H / 2.0 - sy) * float(fl[0]) * 1.6
		var r: float = fl[1]
		draw_texture_rect(_bloom, Rect2(fx - r, fy - r, r * 2.0, r * 2.0), false, Color(1, 1, 1, float(fl[2]) * u * 3.0))
	draw_texture_rect(_vignette, Rect2(-100, -60, W + 200, H + 120), false)
	# logo
	if _logo != null:
		var l := ease_((t - logo_apres) / 1.6)
		if l > 0.0:
			var lw := W * 0.34 * logo_echelle
			var lh := lw * float(_logo.get_height()) / float(_logo.get_width())
			var sc := 0.92 + 0.08 * l
			var ctr := Vector2(W * 0.5, H * logo_y)
			var halo := 26.0 * (1.0 - absf(l - 0.5) * 2.0) + 10.0
			draw_texture_rect(_bloom, Rect2(ctr.x - lw * sc * 0.75 - halo, ctr.y - lh * sc * 0.9 - halo, lw * sc * 1.5 + halo * 2.0, lh * sc * 1.8 + halo * 2.0), false, Color(1, 1, 1, 0.45 * l))
			draw_texture_rect(_logo, Rect2(ctr.x - lw * sc * 0.5 + 0.0, ctr.y - lh * sc * 0.5 + 3.0, lw * sc, lh * sc), false, Color(0, 0, 0, 0.45 * l))
			draw_texture_rect(_logo, Rect2(ctr.x - lw * sc * 0.5, ctr.y - lh * sc * 0.5, lw * sc, lh * sc), false, Color(1, 1, 1, l))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _plan(i: int, par: float, base: float, cam: float) -> void:
	var tex: Texture2D = _calques[i]
	var off := fposmod(cam * par, float(LW))
	draw_texture(tex, Vector2(-off, base - tex.get_height()))
	draw_texture(tex, Vector2(LW - off, base - tex.get_height()))
