# GTB : avion de ligne biréacteur generique (classe 150-180 places, aucun modele ni aucune compagnie reels), fait par
# script. Lancement : blender -b --python blender/tools/build_avion.py -- <.blend> <.glb> [apercu.png]
#
# Repere : nez vers +Y Blender (= -Z Godot), aile droite vers +X, origine au sol sous l'essieu du train principal
# (pivot naturel au roulage et a la rotation). Dimensions : longueur 37,6 m, envergure 35,8 m (sharklets),
# hauteur 11,8 m, fuselage de 3,96 m de diametre.
# Pieces animees par godot/scripts/avion.gd (noms des noeuds) :
#   train_avant (rentre vers l'avant, autour de X) > train_avant_dir (braquage, autour de Z) > roue_avant_* ;
#   train_principal_G / _D (rentrent vers l'interieur, autour de Y) > roue_principal_* (autour de X) ;
#   volet_int_G/D, volet_ext_G/D (sortent vers l'arriere et s'abaissent, autour de leur X local) ;
#   spoiler_G/D (se levent, autour de leur X local) ; inverseur_G/D (capot qui recule) ; soufflante_G/D (tourne) ;
#   feu_* et phare_* (reperes des feux : navigation, anticollision, strobes, atterrissage, roulage).
# Materiaux : mat_avion_livree_1 / _2 (couleurs de la compagnie, changees dans Godot), mat_avion_peinture, etc.
import bpy
import bmesh
import math
import os
import sys
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, OUT_GLB = args[:2]
PREVIEW = args[2] if len(args) > 2 else None


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, srgb, rough=0.5, metal=0.0, alpha=1.0):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes"):
        m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None) or nodes.new("ShaderNodeOutputMaterial")
        m.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    rgba = [to_linear(c) for c in srgb] + [1.0]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        if hasattr(m, "surface_render_method"):
            m.surface_render_method = "BLENDED"
    m.diffuse_color = rgba[:3] + [alpha]
    return m


bpy.ops.wm.read_homefile(use_empty=True)
M = {
    "paint": mat("mat_avion_peinture", (0.95, 0.95, 0.94), 0.32, 0.05),
    "wing": mat("mat_avion_aile", (0.78, 0.79, 0.8), 0.4, 0.25),
    "liv1": mat("mat_avion_livree_1", (0.1, 0.5, 0.25), 0.35),
    "liv2": mat("mat_avion_livree_2", (0.95, 0.75, 0.1), 0.35),
    "belly": mat("mat_avion_ventre", (0.72, 0.73, 0.74), 0.4, 0.15),
    "glass": mat("mat_avion_vitre", (0.06, 0.08, 0.1), 0.05, 0.3),
    "window": mat("mat_avion_hublot", (0.1, 0.12, 0.15), 0.1, 0.2),
    "lip": mat("mat_avion_levre", (0.85, 0.86, 0.88), 0.2, 0.9),
    "fan": mat("mat_avion_soufflante", (0.16, 0.17, 0.18), 0.35, 0.8),
    "exhaust": mat("mat_avion_echappement", (0.3, 0.27, 0.24), 0.5, 0.7),
    "gear": mat("mat_avion_train", (0.72, 0.72, 0.7), 0.45, 0.4),
    "tyre": mat("mat_avion_pneu", (0.05, 0.05, 0.05), 0.9),
    "rim": mat("mat_avion_jante", (0.6, 0.6, 0.62), 0.35, 0.8),
    "seam": mat("mat_avion_joint", (0.42, 0.43, 0.45), 0.5),
    "dark": mat("mat_avion_sombre", (0.1, 0.1, 0.11), 0.6),
    "cascade": mat("mat_avion_grilles", (0.12, 0.12, 0.12), 0.7, 0.4),
}


class Mesh:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def k(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def face(self, pts, m, smooth=True):
        try:
            f = self.bm.faces.new([self.bm.verts.new(p) for p in pts])
        except ValueError:
            return None
        f.material_index = self.k(m)
        f.smooth = smooth
        return f

    def grid(self, rings, m, closed=True, smooth=True, cap0=False, cap1=False):
        """rings : liste d'anneaux de points (meme nombre) -> surface quadrillee ; anneaux fermes si closed."""
        vs = [[self.bm.verts.new(p) for p in r] for r in rings]
        n = len(rings[0])
        idx = self.k(m)
        for i in range(len(rings) - 1):
            for j in range(n if closed else n - 1):
                j2 = (j + 1) % n
                try:
                    f = self.bm.faces.new((vs[i][j], vs[i][j2], vs[i + 1][j2], vs[i + 1][j]))
                    f.material_index = idx
                    f.smooth = smooth
                except ValueError:
                    pass
        for cap, ring in ((cap0, vs[0]), (cap1, vs[-1])):
            if cap:
                c = self.bm.verts.new(sum((v.co for v in ring), Vector()) / len(ring))
                for j in range(n if closed else n - 1):
                    try:
                        f = self.bm.faces.new((ring[j], ring[(j + 1) % n], c) if cap is True else (ring[(j + 1) % n], ring[j], c))
                        f.material_index = idx
                        f.smooth = smooth
                    except ValueError:
                        pass

    def cyl(self, a, b, r, m, seg=12, r2=None, caps=True):
        a, b = Vector(a), Vector(b)
        r2 = r if r2 is None else r2
        ax = (b - a).normalized()
        t = ax.orthogonal().normalized()
        u = ax.cross(t)
        ring = lambda c, rr: [c + (t * math.cos(i / seg * math.tau) + u * math.sin(i / seg * math.tau)) * rr for i in range(seg)]
        self.grid([ring(a, r), ring(b, r2)], m, True, True, cap0=caps, cap1=caps)

    def box(self, c, s, m, rz=0.0):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        cz, sz = math.cos(rz), math.sin(rz)
        vs = []
        for z in (-hz, hz):
            for y in (-hy, hy):
                for x in (-hx, hx):
                    vs.append(self.bm.verts.new((c[0] + x * cz - y * sz, c[1] + x * sz + y * cz, c[2] + z)))
        idx = self.k(m)
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            ff = self.bm.faces.new([vs[i] for i in f])
            ff.material_index = idx
            ff.smooth = False

    def obj(self, parent=None, origin=(0, 0, 0)):
        if len(self.bm.faces) == 0:
            self.bm.free()
            return None
        bmesh.ops.translate(self.bm, verts=self.bm.verts, vec=-Vector(origin))
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.0005)
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for mm in self.mats:
            me.materials.append(mm)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = origin
        if parent:
            ob.parent = parent
            ob.location = Vector(origin) - world_loc(parent)
        return ob


def world_loc(ob):
    """Position monde d'un objet (aucune piece parente n'est tournee au moment de la construction)."""
    p = Vector(ob.location)
    while ob.parent:
        ob = ob.parent
        p += ob.location
    return p


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(e)
    if parent:
        e.parent = parent
        e.location = Vector(loc) - world_loc(parent)
    else:
        e.location = loc
    return e


# ======================================================================= fuselage
# sections : (y, demi-largeur, demi-hauteur, z du centre)
SECT = [(20.6, 0.04, 0.04, 3.27), (20.45, 0.42, 0.38, 3.22), (20.2, 0.72, 0.66, 3.22), (19.8, 1.04, 0.98, 3.27),
        (19.2, 1.38, 1.34, 3.33), (18.5, 1.66, 1.64, 3.38), (17.6, 1.86, 1.86, 3.42), (16.6, 1.96, 1.96, 3.43), (16.15, 1.97, 1.97, 3.43),
        (15.6, 1.98, 1.98, 3.43), (15.35, 1.98, 1.98, 3.43)]
y = 14.6
while y > -6.3:
    SECT.append((y, 1.98, 1.98, 3.43))
    y -= 0.25   # anneaux serres : la porte avant est decoupee dans la peau (cabine visitable)
SECT += [(-7.2, 1.95, 1.94, 3.5), (-8.2, 1.88, 1.84, 3.6), (-9.2, 1.77, 1.71, 3.73), (-10.2, 1.62, 1.55, 3.88),
         (-11.2, 1.44, 1.36, 4.04), (-12.2, 1.24, 1.16, 4.2), (-13.2, 1.03, 0.95, 4.36), (-14.2, 0.82, 0.74, 4.5),
         (-15.1, 0.6, 0.53, 4.63), (-16.0, 0.38, 0.33, 4.76), (-16.6, 0.2, 0.18, 4.85), (-17.0, 0.05, 0.05, 4.9)]
NR = 32


def sect_at(yq):
    for i in range(len(SECT) - 1):
        a, b = SECT[i], SECT[i + 1]
        if b[0] <= yq <= a[0]:
            t = (a[0] - yq) / (a[0] - b[0])
            return tuple(a[k] + (b[k] - a[k]) * t for k in range(1, 4))
    return SECT[-1][1:]


def surf(yq, th, off=0.0):
    """Point de la peau du fuselage : th en degres depuis le haut, positif vers la droite (+X)."""
    rx, rz, zc = sect_at(yq)
    a = math.radians(th)
    n = Vector((math.sin(a) / max(rx, 1e-3), 0.0, math.cos(a) / max(rz, 1e-3))).normalized()
    return Vector((rx * math.sin(a), yq, zc + rz * math.cos(a))) + n * off


fus = Mesh("avion_fuselage")
rings = []
for (yy, rx, rz, zc) in SECT:
    rings.append([(rx * math.sin(j / NR * math.tau), yy, zc + rz * math.cos(j / NR * math.tau)) for j in range(NR)])
fus.grid(rings, M["paint"], True, True, cap0=True, cap1="rev")
# ventre gris clair (bande sous la ligne de flottaison) et bande de livree sous les hublots
belly = Mesh("avion_ventre")
liv = Mesh("avion_livree")


def skin_band(mesh, y0, y1, th0, th1, m, off=0.006, ny=None, nth=4):
    ny = ny or max(2, int(abs(y1 - y0) / 0.5) + 1)
    rows = []
    for i in range(ny):
        yq = y0 + (y1 - y0) * i / (ny - 1)
        rows.append([surf(yq, th0 + (th1 - th0) * j / nth, off) for j in range(nth + 1)])
    mesh.grid(rows, m, closed=False, smooth=True)


for sd in (1, -1):
    skin_band(belly, 17.2, -14.0, sd * 128, sd * 180, M["belly"], 0.004, nth=6)
    for (ya, yb) in (((18.2, 16.25), (15.25, -15.4)) if sd < 0 else ((18.2, -15.4),)):
        skin_band(liv, ya, yb, sd * 98, sd * 106, M["liv1"], 0.006)
        skin_band(liv, min(ya, 18.0), max(yb, -15.0), sd * 108, sd * 111, M["liv2"], 0.006, nth=1)
# hublots passagers (ovales), portes et issues au-dessus des ailes (joints), poste de pilotage
win = Mesh("avion_hublots")
seams = Mesh("avion_joints")


def oval(mesh, yq, th, hw, hh, m, off=0.012, n=10):
    pts = []
    for k in range(n):
        a = k / n * math.tau
        pts.append(surf(yq + math.cos(a) * hw, th + math.degrees(math.sin(a) * hh / 1.98), off))
    c = surf(yq, th, off)
    for k in range(n):
        mesh.face([pts[k], pts[(k + 1) % n], c] if th > 0 else [pts[(k + 1) % n], pts[k], c], m, True)


doors = [(15.75, 0.82, 1.85), (-7.35, 0.82, 1.85), (1.15, 0.52, 1.0), (0.35, 0.52, 1.0)]
for sd in (1, -1):
    yq = 14.9
    while yq > -6.6:
        if not any(abs(yq - d[0]) < d[1] / 2 + 0.2 for d in doors):
            oval(win, yq, sd * 77.0, 0.115, 0.17, M["window"])
        yq -= 0.53
    for (dy, dw, dh) in doors:
        th0 = sd * (74.0 - (dh - 1.0) * 14.0)
        th1 = sd * (74.0 + dh * 27.0)
        for (a, b) in (((dy + dw / 2, th0), (dy - dw / 2, th0)), ((dy + dw / 2, th1), (dy - dw / 2, th1))):
            skin_band(seams, a[0], b[0], a[1] - sd * 0.4, a[1] + sd * 0.4, M["seam"], 0.008, ny=2, nth=1)
        for yy in (dy + dw / 2, dy - dw / 2):
            skin_band(seams, yy + 0.015, yy - 0.015, th0, th1, M["seam"], 0.008, ny=2, nth=4)
# pare-brise et vitres laterales du poste (6 vitres)
for sd in (1, -1):
    for (y0, y1, a0, a1) in ((19.55, 19.0, 6, 36), (18.95, 18.45, 40, 58), (18.4, 17.95, 50, 63)):
        rows = []
        for i in range(3):
            yq = y0 + (y1 - y0) * i / 2
            rows.append([surf(yq, sd * (a0 + (a1 - a0) * j / 3), 0.01) for j in range(4)])
        win.grid(rows, M["glass"], closed=False, smooth=True)
fus_ob = fus.obj()
# ======================================================================= porte avant gauche et cabine visitable
# La porte passagers avant gauche (L1) est un panneau a part (porte_avant) decoupe dans la peau : Godot la cache
# quand l'avion est au poste (porte ouverte, escalier) et le joueur entre dans la cabine.
DOOR_Y0, DOOR_Y1 = 15.35, 16.15
FLOOR_Z = 2.62                      # plancher passagers = seuil de porte (palier de l'escalier mobile a 2,66 m)
bm = bmesh.new()
bm.from_mesh(fus_ob.data)
door_faces = []
for f in bm.faces:
    c = f.calc_center_median()
    if c.x < -0.5 and DOOR_Y0 - 0.01 < c.y < DOOR_Y1 + 0.01:
        th = math.degrees(math.atan2(-c.x / 1.98, (c.z - 3.43) / 1.98))
        if 58.0 < th < 114.0:
            door_faces.append(f)
pb = bmesh.new()
vmap = {}
for f in door_faces:
    vs = []
    for v in f.verts:
        if v not in vmap:
            vmap[v] = pb.verts.new(v.co)
        vs.append(vmap[v])
    nf = pb.faces.new(vs)
    nf.smooth = True
bmesh.ops.delete(bm, geom=door_faces, context="FACES_ONLY")
bm.to_mesh(fus_ob.data)
bm.free()
pme = bpy.data.meshes.new("porte_avant")
pb.to_mesh(pme)
pb.free()
pme.materials.append(M["paint"])
pob = bpy.data.objects.new("porte_avant", pme)
bpy.context.scene.collection.objects.link(pob)
print("Porte avant :", len(door_faces), "faces decoupees")

M["cab"] = mat("mat_avion_cabine", (0.86, 0.84, 0.78), 0.7)
M["seat"] = mat("mat_avion_siege", (0.12, 0.2, 0.38), 0.85)
M["carpet"] = mat("mat_avion_moquette", (0.3, 0.3, 0.33), 0.95)
M["panel"] = mat("mat_avion_tableau", (0.15, 0.16, 0.17), 0.6)
cab = Mesh("avion_cabine")
Y_FWD, Y_AFT = 17.3, -7.9
# plancher (moquette) sur toute la largeur utile, et revetement interieur (normales vers l'interieur)
half_w = 1.98 * math.sin(math.acos((FLOOR_Z - 3.43) / 1.98)) - 0.02
cab.box((0, (Y_FWD + Y_AFT) / 2, FLOOR_Z - 0.05), (half_w * 2, Y_FWD - Y_AFT, 0.1), M["carpet"])
lin = []
yq = Y_FWD
while yq >= Y_AFT - 0.01:
    rx, rz, zc = sect_at(yq)
    ring = []
    for j in range(17):
        th = 118.0 - j * (236.0 / 16)
        a = math.radians(th)
        ring.append((-(rx - 0.09) * math.sin(a), yq, zc + (rz - 0.09) * math.cos(a)))
    lin.append(ring)
    yq -= 0.25 if DOOR_Y0 - 0.3 < yq < DOOR_Y1 + 0.3 else 0.8
lining = Mesh("avion_cabine_parois")
lining.grid(lin, M["cab"], closed=False, smooth=True)
lob = lining.obj()
# trou de porte dans le revetement
bm = bmesh.new()
bm.from_mesh(lob.data)
rm = [f for f in bm.faces if f.calc_center_median().x < -0.5 and DOOR_Y0 - 0.1 < f.calc_center_median().y < DOOR_Y1 + 0.1
      and FLOOR_Z - 0.1 < f.calc_center_median().z < FLOOR_Z + 2.3]
bmesh.ops.delete(bm, geom=rm, context="FACES_ONLY")
for f in bm.faces:
    f.normal_flip()
bm.to_mesh(lob.data)
bm.free()
# cloisons : poste de pilotage (avec porte ouverte), arriere (offices et toilettes)
for (yb, door_open) in ((17.3, True), (-7.9, False)):
    rx, rz, zc = sect_at(yb)
    if door_open:
        for sx in (-1, 1):
            cab.box((sx * (0.45 + (rx - 0.45) / 2), yb, zc - 0.2), (rx - 0.45, 0.06, 2.8), M["cab"])
        cab.box((0, yb, FLOOR_Z + 2.15), (0.9, 0.06, 0.5), M["cab"])
    else:
        cab.box((0, yb, zc - 0.2), (rx * 2 - 0.1, 0.06, 2.8), M["cab"])
# plancher du poste de pilotage (sans lui, on passait a travers jusqu'au fond de la coque)
_rx, _rz, _zc = sect_at(19.0)
_hw = _rx * math.sqrt(max(0.0, 1.0 - ((FLOOR_Z - _zc) / _rz) ** 2)) - 0.05
cab.box((0, (17.3 + 19.0) / 2, FLOOR_Z - 0.05), (_hw * 2, 1.7, 0.1), M["carpet"])
print("Plancher du poste : demi-largeur %.2f m" % _hw)
# office avant (galley) a droite de la porte L1, en face de la porte
cab.box((1.25, 15.75, FLOOR_Z + 0.5), (0.7, 1.4, 1.0), M["cab"])
cab.box((1.25, 15.75, FLOOR_Z + 1.02), (0.72, 1.42, 0.04), M["seam"])
# rangees de sieges 3 + 3 (pas de 0,79 m). Allee elargie pour le jeu : 0,73 m entre accoudoirs (vrai A320 : ~0,48 m,
# on s'y tourne de cote ; le joueur a une capsule de 0,60 m), sieges de 0,46 m resserres vers les hublots
AISLE_HALF = 0.39
row_y = 14.4
rows = 0
while row_y > -7.3:
    if abs(row_y - 1.15) < 0.45 or abs(row_y - 0.35) < 0.45:   # rangees d'issues au-dessus des ailes : plus d'espace
        row_y -= 0.25
    for sx in (-1, 1):
        for k in range(3):
            x = sx * (AISLE_HALF + 0.24 + k * 0.46)
            cab.box((x, row_y, FLOOR_Z + 0.45), (0.44, 0.48, 0.12), M["seat"])               # assise
            cab.box((x, row_y - 0.26, FLOOR_Z + 0.82), (0.44, 0.1, 0.72), M["seat"])          # dossier
            cab.box((x, row_y + 0.02, FLOOR_Z + 0.2), (0.06, 0.4, 0.4), M["panel"])           # pied
        cab.box((sx * (AISLE_HALF + 0.02), row_y - 0.02, FLOOR_Z + 0.62), (0.05, 0.42, 0.06), M["panel"])   # accoudoir d'allee
    row_y -= 0.79
    rows += 1
print("Cabine :", rows, "rangees de 6")
# coffres a bagages au-dessus des sieges, rampe de plafonnier
for sx in (-1, 1):
    cab.box((sx * 1.3, (14.8 + -7.3) / 2, 3.43 + 1.05), (0.75, 22.1, 0.45), M["cab"])
cab.box((0, (14.8 + -7.3) / 2, 3.43 + 1.82), (1.2, 22.1, 0.05), M["lip"])
# poste de pilotage : deux sieges, pylone central, tableau de bord sous le pare-brise
for sx in (-1, 1):
    cab.box((sx * 0.55, 18.15, FLOOR_Z + 0.5), (0.5, 0.5, 0.15), M["panel"])
    cab.box((sx * 0.55, 17.88, FLOOR_Z + 0.95), (0.5, 0.1, 0.8), M["panel"])
cab.box((0, 18.4, FLOOR_Z + 0.45), (0.35, 0.9, 0.6), M["panel"])
cab.box((0, 18.95, FLOOR_Z + 1.05), (2.0, 0.35, 0.35), M["panel"])
cab.box((0, 18.85, FLOOR_Z + 1.25), (1.9, 0.25, 0.04), M["glass"])
cab.obj()
belly.obj()
liv.obj()
win.obj()
seams.obj()


# ======================================================================= ailes et empennages
def airfoil(t, n=9):
    """Profil (s de 0 = bord d'attaque a 1 = bord de fuite, demi-epaisseur) facon NACA 4 chiffres, extrados plus bombe."""
    ss = [0.0, 0.015, 0.05, 0.12, 0.22, 0.35, 0.5, 0.65, 0.8, 0.92, 1.0]
    up, lo = [], []
    for s in ss:
        yt = 5 * t * (0.2969 * math.sqrt(s) - 0.126 * s - 0.3516 * s * s + 0.2843 * s ** 3 - 0.1036 * s ** 4)
        up.append((s, yt * 1.15 + 0.004))
        lo.append((s, -yt * 0.85 - 0.004))
    return up, lo


def section(x, y_le, chord, z, t, bank=0.0, side=1, twist=0.0):
    """Anneau du profil a l'envergure x : extrados du bord de fuite au bord d'attaque puis intrados."""
    up, lo = airfoil(t)
    nrm = Vector((-math.sin(bank) * side, 0.0, math.cos(bank)))
    pts = []
    for (s, h) in list(reversed(up)) + lo[1:-1]:
        yy = y_le - s * chord
        zz = z + (yy - y_le) * math.tan(twist)
        pts.append(Vector((x * side, yy, zz)) + nrm * h * chord)
    return pts


def wing_mesh(name, stations, m, side):
    """stations : [(x, y_le, corde, z, epaisseur relative, inclinaison laterale)]."""
    mesh = Mesh(name)
    rings = [section(x, yl, c, z, t, bk, side) for (x, yl, c, z, t, bk) in stations]
    mesh.grid(rings, m, True, True, cap0=False, cap1=(True if side > 0 else "rev"))
    return mesh


DIH = math.tan(math.radians(5.1))


def wing_z(x):
    return 2.15 + (x - 1.6) * DIH


def wing_le(x):
    return 4.6 - (x - 1.6) * math.tan(math.radians(27.0)) if x < 6.3 else 2.205 - (x - 6.3) * math.tan(math.radians(26.0))


def wing_te(x):
    return -1.6 if x < 6.3 else -1.6 - (x - 6.3) * (4.63 - 1.6) / (17.05 - 6.3)


for sd, sn in ((1, "D"), (-1, "G")):
    st = []
    for x in (1.6, 3.5, 6.3, 9.0, 12.0, 14.5, 17.05):
        st.append((x, wing_le(x), wing_le(x) - wing_te(x), wing_z(x), 0.14 - (x - 1.6) / 15.45 * 0.04, 0.0))
    # sharklet : se releve en se vrillant vers la verticale
    st.append((17.35, -3.28, 1.45, wing_z(17.05) + 0.22, 0.1, math.radians(40)))
    st.append((17.55, -3.75, 1.15, wing_z(17.05) + 0.85, 0.1, math.radians(75)))
    st.append((17.62, -4.4, 0.62, wing_z(17.05) + 2.3, 0.1, math.radians(84)))
    wing_mesh(f"avion_aile_{sn}", st, M["wing"], sd).obj()
    # carenage voilure / fuselage (karman)
    kar = Mesh(f"avion_karman_{sn}")
    kar.grid([[surf(yq, sd * a, 0.025) + Vector((sd * 0.05 * math.sin(math.radians(a)), 0, 0)) for a in (95, 110, 125, 140, 155)]
              for yq in (5.6, 4.6, 2.0, -0.5, -2.4, -3.4)], M["belly"], closed=False, smooth=True)
    kar.obj()
    # empennage horizontal
    hs = [(0.3, -11.0, 3.7, 4.25, 0.1, 0.0), (3.0, -11.0 - 2.7 * math.tan(math.radians(32)), 2.6, 4.25 + 2.7 * 0.105, 0.1, 0.0),
          (6.2, -11.0 - 5.9 * math.tan(math.radians(32)), 1.4, 4.25 + 5.9 * 0.105, 0.09, 0.0)]
    wing_mesh(f"avion_stabilisateur_{sn}", hs, M["paint"], sd).obj()

# derive (profil vertical) : sections le long de z, epaisseur selon x
fin = Mesh("avion_derive")
rings = []
for (z, yl, c, t) in ((4.9, -7.9, 6.6, 0.11), (5.4, -8.35, 6.0, 0.11), (7.5, -9.95, 4.6, 0.105), (9.6, -11.6, 3.2, 0.1),
                      (11.6, -13.25, 2.0, 0.1)):
    up, lo = airfoil(t)
    ring = []
    for (s, h) in list(reversed(up)) + lo[1:-1]:
        ring.append((h * c, yl - s * c, z))
    rings.append(ring)
fin.grid(rings, M["liv2"], True, True, cap1="rev")
fin.obj()

# ======================================================================= volets, spoilers (pieces mobiles)
for sd, sn in ((1, "D"), (-1, "G")):
    for nm, x0, x1 in (("int", 2.05, 6.2), ("ext", 6.45, 13.6)):
        # volet range sous le bord de fuite : de 72 % a 98 % de la corde, epaisseur 10 cm
        y0a, y0b = wing_le(x0) - 0.72 * (wing_le(x0) - wing_te(x0)), wing_le(x1) - 0.72 * (wing_le(x1) - wing_te(x1))
        y1a, y1b = wing_le(x0) - 0.98 * (wing_le(x0) - wing_te(x0)), wing_le(x1) - 0.98 * (wing_le(x1) - wing_te(x1))
        za, zb = wing_z(x0) - 0.02, wing_z(x1) - 0.02
        fl = Mesh(f"volet_{nm}_{sn}")
        rows = []
        for (xx, yh, yt, zz) in ((x0, y0a, y1a, za), (x1, y0b, y1b, zb)):
            rows.append([(xx * sd, yh, zz + 0.05), (xx * sd, yh - (yh - yt) * 0.3, zz + 0.06), (xx * sd, yt, zz),
                         (xx * sd, yh - (yh - yt) * 0.3, zz - 0.05), (xx * sd, yh, zz - 0.04)])
        fl.grid(rows, M["wing"], True, False, cap0=True, cap1="rev")
        # origine sur la charniere (bord avant du volet), axe X local le long du bord
        hinge = Vector(((x0 + x1) / 2 * sd, (y0a + y0b) / 2, (za + zb) / 2))
        ob = fl.obj(origin=hinge)
        ang = math.atan2(y0b - y0a, (x1 - x0) * sd)
        # le maillage est deja place ; on tourne l'objet pour aligner son X local sur la charniere (sans bouger la geometrie)
        me = ob.data
        rot = Matrix.Rotation(-ang, 4, "Z")
        me.transform(rot)
        ob.rotation_euler = (0, 0, ang)
    # spoilers : panneaux sur l'extrados, devant les volets (de 3 a 12 m d'envergure)
    xa, xb = 3.2, 12.2
    sp = Mesh(f"spoiler_{sn}")
    pa = [(xa * sd, wing_le(xa) - 0.58 * (wing_le(xa) - wing_te(xa)), wing_z(xa) + 0.07 * (wing_le(xa) - wing_te(xa)) * 0.6),
          (xb * sd, wing_le(xb) - 0.58 * (wing_le(xb) - wing_te(xb)), wing_z(xb) + 0.07 * (wing_le(xb) - wing_te(xb)) * 0.6)]
    pb = [(xa * sd, wing_le(xa) - 0.72 * (wing_le(xa) - wing_te(xa)), wing_z(xa) + 0.045 * (wing_le(xa) - wing_te(xa)) * 0.6),
          (xb * sd, wing_le(xb) - 0.72 * (wing_le(xb) - wing_te(xb)), wing_z(xb) + 0.045 * (wing_le(xb) - wing_te(xb)) * 0.6)]
    sp.grid([[Vector(pa[0]) + Vector((0, 0, 0.02)), Vector(pb[0]) + Vector((0, 0, 0.02)), Vector(pb[0]) + Vector((0, 0, -0.01)), Vector(pa[0]) + Vector((0, 0, -0.01))],
             [Vector(pa[1]) + Vector((0, 0, 0.02)), Vector(pb[1]) + Vector((0, 0, 0.02)), Vector(pb[1]) + Vector((0, 0, -0.01)), Vector(pa[1]) + Vector((0, 0, -0.01))]],
            M["wing"], True, False, cap0=True, cap1="rev")
    hinge = (Vector(pa[0]) + Vector(pa[1])) / 2
    ob = sp.obj(origin=hinge)
    ang = math.atan2(pa[1][1] - pa[0][1], pa[1][0] - pa[0][0]) if sd > 0 else math.atan2(pa[0][1] - pa[1][1], pa[0][0] - pa[1][0])
    ob.data.transform(Matrix.Rotation(-ang, 4, "Z"))
    ob.rotation_euler = (0, 0, ang)

# ======================================================================= reacteurs
ENG_X, ENG_Z, ENG_Y = 5.75, 1.52, 5.0     # axe de la nacelle, entree d'air a y = ENG_Y


def lathe(mesh, prof, cx, cz, m, seg=28, smooth=True, cap_end=False):
    rings = []
    for (dy, r) in prof:
        rings.append([(cx + r * math.cos(j / seg * math.tau), ENG_Y - dy, cz + r * math.sin(j / seg * math.tau)) for j in range(seg)])
    mesh.grid(rings, m, True, smooth, cap1=cap_end)


for sd, sn in ((1, "D"), (-1, "G")):
    cx = ENG_X * sd
    nac = Mesh(f"avion_nacelle_{sn}")
    lathe(nac, [(0.0, 0.9), (0.03, 0.97), (0.12, 1.01), (0.35, 1.03)], cx, ENG_Z, M["lip"])
    lathe(nac, [(0.35, 1.03), (1.4, 1.03), (2.45, 0.99)], cx, ENG_Z, M["liv1"])
    lathe(nac, [(0.0, 0.9), (0.12, 0.85), (0.55, 0.84)], cx, ENG_Z, M["fan"])
    # grilles de l'inverseur (visibles quand le capot recule)
    lathe(nac, [(2.4, 0.97), (3.05, 0.9)], cx, ENG_Z, M["cascade"])
    # tuyere et cone d'echappement
    lathe(nac, [(3.85, 0.68), (4.2, 0.6), (4.55, 0.52)], cx, ENG_Z, M["exhaust"])
    lathe(nac, [(3.9, 0.4), (4.55, 0.33), (5.0, 0.18), (5.3, 0.03)], cx, ENG_Z, M["exhaust"], cap_end=True)
    # mat (pylone) entre la nacelle et l'aile
    nac.box((cx, ENG_Y - 2.6, ENG_Z + 1.0), (0.32, 3.6, 0.5), M["paint"])
    nac.box((cx, ENG_Y - 4.6, ENG_Z + 0.95), (0.26, 1.6, 0.42), M["paint"])
    nac.obj()
    # capot de l'inverseur (recule de 0,6 m en poussee inverse)
    inv = Mesh(f"inverseur_{sn}")
    lathe(inv, [(2.4, 1.0), (3.2, 0.92), (3.9, 0.72)], cx, ENG_Z, M["liv1"])
    lathe(inv, [(3.9, 0.72), (3.9, 0.64)], cx, ENG_Z, M["exhaust"])
    inv.obj(origin=(cx, ENG_Y - 3.0, ENG_Z))
    # soufflante : moyeu + 22 pales (tourne autour de l'axe de la nacelle)
    fan = Mesh(f"soufflante_{sn}")
    fy = ENG_Y - 0.6
    fan.cyl((cx, fy + 0.25, ENG_Z), (cx, fy - 0.15, ENG_Z), 0.02, M["lip"], 16, 0.32, caps=False)
    fan.cyl((cx, fy - 0.15, ENG_Z), (cx, fy - 0.3, ENG_Z), 0.32, M["fan"], 16)
    for b in range(22):
        a = b / 22 * math.tau
        da = 0.12
        p = []
        for (r, dd, dyy) in ((0.3, -da, 0.08), (0.82, -da * 0.4, 0.04), (0.82, da * 0.4, -0.04), (0.3, da, -0.08)):
            p.append((cx + r * math.cos(a + dd), fy + dyy, ENG_Z + r * math.sin(a + dd)))
        fan.face(p, M["fan"], False)
        fan.face(list(reversed(p)), M["fan"], False)
    fan.obj(origin=(cx, fy, ENG_Z))

# ======================================================================= trains d'atterrissage
MAIN_X, MAIN_TOP, MAIN_R = 3.8, 2.35, 0.57
for sd, sn in ((1, "D"), (-1, "G")):
    cx = MAIN_X * sd
    leg = Mesh(f"train_principal_{sn}")
    leg.cyl((cx, 0.0, MAIN_TOP), (cx, 0.0, 0.95), 0.14, M["gear"], 12)
    leg.cyl((cx, 0.0, 0.98), (cx, 0.0, MAIN_R), 0.1, M["rim"], 12)
    leg.cyl((cx - 0.5, 0.0, MAIN_R), (cx + 0.5, 0.0, MAIN_R), 0.07, M["gear"], 10)
    leg.cyl((cx, 0.05, 1.6), (cx - sd * 1.55, 0.35, MAIN_TOP - 0.05), 0.06, M["gear"], 8)          # contrefiche
    leg.box((cx, 0.22, 1.05), (0.06, 0.32, 0.3), M["gear"])                                       # compas
    leg.box((cx + sd * 0.0, -0.05, 1.75), (0.5, 0.06, 1.0), M["belly"])                            # trappe de jambe
    top = (cx, 0.0, MAIN_TOP)
    gob = leg.obj(origin=top)
    for k, dx in enumerate((-0.42, 0.42)):
        w = Mesh(f"roue_principal_{sn}_{k}")
        w.cyl((cx + dx - 0.18, 0, MAIN_R), (cx + dx + 0.18, 0, MAIN_R), MAIN_R, M["tyre"], 20)
        w.cyl((cx + dx - 0.185, 0, MAIN_R), (cx + dx + 0.185, 0, MAIN_R), 0.33, M["rim"], 16)            # jantes
        w.obj(parent=gob, origin=(cx + dx, 0, MAIN_R))

NOSE_Y, NOSE_TOP, NOSE_R = 12.6, 2.05, 0.38
nose = Mesh("train_avant")
nose.cyl((0, NOSE_Y, NOSE_TOP), (0, NOSE_Y, 0.9), 0.11, M["gear"], 12)
nose.cyl((0, NOSE_Y + 0.05, 1.5), (0, NOSE_Y + 1.1, NOSE_TOP - 0.05), 0.05, M["gear"], 8)
nob = nose.obj(origin=(0, NOSE_Y, NOSE_TOP))
steer = Mesh("train_avant_dir")
steer.cyl((0, NOSE_Y, 0.95), (0, NOSE_Y - 0.12, NOSE_R), 0.08, M["rim"], 10)
steer.cyl((-0.32, NOSE_Y - 0.12, NOSE_R), (0.32, NOSE_Y - 0.12, NOSE_R), 0.05, M["gear"], 8)
sob = steer.obj(parent=nob, origin=(0, NOSE_Y, 0.95))
for k, dx in enumerate((-0.2, 0.2)):
    w = Mesh(f"roue_avant_{k}")
    w.cyl((dx - 0.11, NOSE_Y - 0.12, NOSE_R), (dx + 0.11, NOSE_Y - 0.12, NOSE_R), NOSE_R, M["tyre"], 18)
    w.cyl((dx - 0.115, NOSE_Y - 0.12, NOSE_R), (dx + 0.115, NOSE_Y - 0.12, NOSE_R), 0.2, M["rim"], 12)
    w.obj(parent=sob, origin=(dx, NOSE_Y - 0.12, NOSE_R))
empty("phare_roulage", (0, NOSE_Y + 0.15, 1.2), nob)

# ======================================================================= feux et reperes
tip_z = wing_z(17.05)
empty("feu_nav_G", (-17.2, -3.3, tip_z + 0.05))
empty("feu_nav_D", (17.2, -3.3, tip_z + 0.05))
empty("feu_strobe_G", (-17.3, -3.6, tip_z + 0.05))
empty("feu_strobe_D", (17.3, -3.6, tip_z + 0.05))
empty("feu_queue", (0, -17.05, 4.9))
empty("feu_anticollision_haut", (0, -1.0, 5.43))
empty("feu_anticollision_bas", (0, 1.5, 1.44))
empty("phare_atterrissage_G", (-3.2, 3.9, 1.95))
empty("phare_atterrissage_D", (3.2, 3.9, 1.95))
empty("roue_contact_G", (-MAIN_X, 0, 0.0))
empty("roue_contact_D", (MAIN_X, 0, 0.0))
empty("titre_G", (-1.99, 6.0, 4.1))
empty("titre_D", (1.99, 6.0, 4.1))
empty("logo_derive", (0, -10.6, 8.2))
empty("immatriculation_G", (-1.5, -12.6, 4.6))
empty("immatriculation_D", (1.5, -12.6, 4.6))

faces = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
print("Avion :", faces, "faces,", len([o for o in bpy.context.scene.objects if o.type == "MESH"]), "objets")
os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True, export_texcoords=False)

if PREVIEW:
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w")
    w.color = (0.7, 0.75, 0.8)
    sc.world = w
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.color_type = "MATERIAL"
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    cam = bpy.data.cameras.new("c")
    cam.lens = 35
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    for nm, loc, rot in (("trois_quart", (26, 30, 9), (78, 0, 140)), ("dessous", (14, 6, -1.5), (95, 0, 115)),
                         ("face", (0, 46, 4), (88, 0, 180))):
        co.location = loc
        co.rotation_euler = [math.radians(a) for a in rot]
        sc.render.filepath = PREVIEW.replace(".png", f"_{nm}.png")
        bpy.ops.render.render(write_still=True)
