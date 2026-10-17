# GTB : zem (moto-taxi) fait par script. Moto generique 125 cc facon "moto chinoise" de Cotonou (aucune marque reelle) :
# cadre tubulaire, moteur monocylindre incline a ailettes (carter alu, couvercles d'embrayage et d'alternateur),
# echappement chrome avec ecran de chaleur, reservoir galbe avec genouilleres et bouchon, longue selle biplace
# surpiquee, caches lateraux, porte-bagages chrome et poignee passager, pare-moteur tubulaire, fourche telescopique
# a soufflets, phare rond cercle de chrome, compteur rond, retroviseurs ronds, clignotants, roues a 36 rayons avec
# tambours de frein, chaine et couronne, amortisseurs a ressorts, garde-boue, feu arriere et plaque, bequilles,
# reposes-pieds, kick et selecteur.
# Lancement : blender -b --python blender/tools/build_zem.py -- <sortie.blend> <sortie.glb> [dossier_apercus]
# Orientation : l'avant regarde +Y dans Blender (= -Z dans Godot). Roues posees a Z = 0. Longueur ~1,95 m.
# Pivots animes dans Godot (noms lus par scripts/zem.gd, ne pas changer) : piv_guidon (direction, porte fourche +
# roue avant), piv_roue_av, piv_roue_ar (rotation). Reperes : pt_conducteur (assise), pt_passager.
# Materiaux lus par Godot : veh_phare (phare allume la nuit, scripts/traffic.gd), veh_feu_rouge.
# Les pieces sont fusionnees par groupe articule (cadre, direction, fourche basse, roues) : peu d'appels de rendu
# pour les dizaines de zems de la circulation et des stations.
import bmesh
import bpy
import math
import os
import sys

args = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, OUT_GLB = args[:2]
PREVIEW_DIR = args[2] if len(args) > 2 else None

bpy.ops.wm.read_homefile(use_empty=True)
scene = bpy.context.scene


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, srgb, rough=0.6, metal=0.0, emit=None):
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
    if emit:
        bsdf.inputs["Emission Color"].default_value = [to_linear(c) for c in emit] + [1.0]
        bsdf.inputs["Emission Strength"].default_value = 0.5
    m.diffuse_color = rgba
    return m


PAINT = material("veh_peinture_rouge", (0.62, 0.06, 0.05), 0.28, 0.1)
BLACK = material("veh_plastique_noir", (0.05, 0.05, 0.055), 0.65)
FRAME = material("veh_cadre", (0.07, 0.07, 0.075), 0.45, 0.3)
CHROME = material("veh_chrome", (0.82, 0.82, 0.85), 0.12, 1.0)
ALU = material("veh_moteur", (0.62, 0.62, 0.6), 0.42, 0.85)
ALU_DARK = material("veh_moteur_fonce", (0.3, 0.3, 0.31), 0.55, 0.7)
TIRE = material("veh_pneu", (0.035, 0.035, 0.038), 0.92)
RUBBER = material("veh_caoutchouc", (0.07, 0.07, 0.07), 0.85)
SEAT = material("veh_selle", (0.07, 0.06, 0.055), 0.55)
SEAM = material("veh_surpiqure", (0.35, 0.33, 0.3), 0.8)
LIGHT = material("veh_phare", (1.0, 0.95, 0.8), 0.05)
REFLECT = material("veh_reflecteur", (0.9, 0.9, 0.92), 0.08, 1.0)
TAIL = material("veh_feu_rouge", (0.75, 0.04, 0.04), 0.15, emit=(0.4, 0.0, 0.0))
AMBER = material("veh_clignotant", (0.95, 0.5, 0.05), 0.15)
PLATE = material("veh_plaque", (0.93, 0.93, 0.88), 0.5)
PLATE_TXT = material("veh_plaque_texte", (0.05, 0.05, 0.05), 0.5)
DIAL = material("veh_cadran", (0.9, 0.9, 0.86), 0.3)
CHAIN = material("veh_chaine", (0.12, 0.11, 0.1), 0.5, 0.8)
STRIPE = material("veh_filet", (0.95, 0.95, 0.92), 0.3)

WHEEL_R = 0.30
RIM_R = 0.216            # jante 17 pouces
TIRE_W = 0.085
WHEELBASE = 1.25
FRONT_Y = WHEELBASE / 2
REAR_Y = -WHEELBASE / 2


# ------------------------------------------------------------------ outils de maillage
def v_add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def v_sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def v_mul(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def v_len(a):
    return math.sqrt(a[0] ** 2 + a[1] ** 2 + a[2] ** 2)


def v_norm(a):
    n = v_len(a) or 1.0
    return (a[0] / n, a[1] / n, a[2] / n)


def v_cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def v_dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def rot(p, rx, ry, rz, c=(0, 0, 0)):
    x, y, z = p
    y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
    x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
    x, y = x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
    return (c[0] + x, c[1] + y, c[2] + z)


class Mesh:
    """Accumule des faces (avec materiau) dans un bmesh, puis cree un seul objet."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def k(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def face(self, vs, m, smooth=True):
        f = self.bm.faces.new(vs)
        f.material_index = self.k(m)
        f.smooth = smooth
        return f

    def box(self, m, c, s, rx=0.0, ry=0.0, rz=0.0, smooth=False):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        vs = []
        for z in (-hz, hz):
            for y in (-hy, hy):
                for x in (-hx, hx):
                    vs.append(self.bm.verts.new(rot((x, y, z), rx, ry, rz, c)))
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            self.face([vs[i] for i in f], m, smooth)

    def rings(self, rs, m, cap0=True, cap1=True, closed=False):
        n = len(rs[0])
        last = len(rs) if closed else len(rs) - 1
        for a in range(last):
            b = (a + 1) % len(rs)
            for i in range(n):
                j = (i + 1) % n
                self.face((rs[a][i], rs[a][j], rs[b][j], rs[b][i]), m)
        if cap0 and not closed:
            self.face(rs[0][::-1], m)
        if cap1 and not closed:
            self.face(rs[-1], m)

    def tube(self, m, pts, r, seg=10, caps=True, radii=None, closed=False):
        """Tube le long d'une polyligne (reperes transportes : pas de torsion). radii : rayon par point."""
        rs = []
        n = len(pts)
        prev_u = None
        for i, p in enumerate(pts):
            if closed:
                t = v_norm(v_sub(pts[(i + 1) % n], pts[i - 1]))
            else:
                t = v_norm(v_sub(pts[min(i + 1, n - 1)], pts[max(i - 1, 0)]))
            if prev_u is None:
                ref = (0, 0, 1) if abs(t[2]) < 0.9 else (1, 0, 0)
                u = v_norm(v_cross(t, ref))
            else:
                u = v_norm(v_sub(prev_u, v_mul(t, v_dot(prev_u, t))))
            w = v_cross(t, u)
            prev_u = u
            rr = radii[i] if radii else r
            rs.append([self.bm.verts.new(v_add(p, v_add(v_mul(u, rr * math.cos(a)), v_mul(w, rr * math.sin(a)))))
                       for a in (k / seg * math.tau for k in range(seg))])
        self.rings(rs, m, caps, caps, closed)

    def lathe_x(self, m, c, prof, seg=24):
        """Solide de revolution d'axe X. prof : [(x, rayon)]."""
        rs = [[self.bm.verts.new((c[0] + x, c[1] + r * math.cos(i / seg * math.tau), c[2] + r * math.sin(i / seg * math.tau)))
               for i in range(seg)] for x, r in prof]
        self.rings(rs, m, False, False)

    def lathe(self, m, c, axis, prof, seg=20, caps=True):
        """Solide de revolution d'axe quelconque (rx, rz : orientation de l'axe Y local). prof : [(t, rayon)]."""
        rx, rz = axis
        rs = [[self.bm.verts.new(rot((r * math.cos(i / seg * math.tau), t, r * math.sin(i / seg * math.tau)), rx, 0, rz, c))
               for i in range(seg)] for t, r in prof]
        self.rings(rs, m, caps, caps)

    def disc_x(self, m, c, r, seg=24, flip=False):
        vs = [self.bm.verts.new((c[0], c[1] + r * math.cos(i / seg * math.tau), c[2] + r * math.sin(i / seg * math.tau))) for i in range(seg)]
        self.face(vs[::-1] if flip else vs, m)

    def loft(self, m, sections, seg=16, expo=2.6, caps=True):
        """Volume galbe : sections super-ellipse dans le plan XZ. sections : [(y, cx, cz, demi-largeur, demi-hauteur)]."""
        rs = []
        for y, cx, cz, hw, hh in sections:
            ring = []
            for i in range(seg):
                a = i / seg * math.tau
                ca, sa = math.cos(a), math.sin(a)
                x = hw * math.copysign(abs(ca) ** (2 / expo), ca)
                z = hh * math.copysign(abs(sa) ** (2 / expo), sa)
                ring.append(self.bm.verts.new((cx + x, y, cz + z)))
            rs.append(ring)
        self.rings(rs, m, caps, caps)

    def obj(self, parent=None, loc=(0, 0, 0), rotation=(0, 0, 0)):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for mt in self.mats:
            me.materials.append(mt)
        ob = bpy.data.objects.new(self.name, me)
        scene.collection.objects.link(ob)
        ob.parent = parent
        ob.location = loc
        ob.rotation_euler = rotation
        if hasattr(me, "set_sharp_from_angle"):
            me.set_sharp_from_angle(angle=math.radians(50))
        return ob


def empty(name, loc, parent=None, rotation=(0, 0, 0)):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.05
    scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    e.rotation_euler = rotation
    return e


def arc(c, r, a0, a1, n, plane="yz", x=0.0):
    """Points d'un arc de cercle (plan YZ par defaut, a l'abscisse x)."""
    out = []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        out.append((x, c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
    return out


# ------------------------------------------------------------------ roue a rayons
def wheel(name, parent, drum_r, sprocket=False):
    m = Mesh(name)
    w = TIRE_W
    # pneu : flancs arrondis, bande de roulement a crampons legers
    prof = [(w * 0.42, RIM_R + 0.004), (w * 0.52, RIM_R + 0.03), (w * 0.53, 0.262), (w * 0.47, 0.29), (w * 0.25, WHEEL_R),
            (-w * 0.25, WHEEL_R), (-w * 0.47, 0.29), (-w * 0.53, 0.262), (-w * 0.52, RIM_R + 0.03), (-w * 0.42, RIM_R + 0.004)]
    m.lathe_x(TIRE, (0, 0, 0), prof, 36)
    for i in range(36):
        a = i / 36 * math.tau
        m.box(TIRE, (0, math.cos(a) * (WHEEL_R + 0.002), math.sin(a) * (WHEEL_R + 0.002)), (w * 0.62, 0.022, 0.006), rx=a + math.pi / 2)
    # jante chromee (profil en U)
    m.lathe_x(CHROME, (0, 0, 0), [(w * 0.42, RIM_R + 0.012), (w * 0.4, RIM_R - 0.004), (w * 0.15, RIM_R - 0.016),
                                  (-w * 0.15, RIM_R - 0.016), (-w * 0.4, RIM_R - 0.004), (-w * 0.42, RIM_R + 0.012)], 36)
    # moyeu a tambour (flasque de frein noire d'un cote)
    m.lathe_x(ALU, (0, 0, 0), [(0.06, 0.012), (0.06, drum_r * 0.55), (0.045, drum_r), (-0.04, drum_r), (-0.055, drum_r * 0.6), (-0.06, 0.012)], 18)
    m.disc_x(ALU_DARK, (0.061, 0, 0), drum_r * 0.98, 18)
    m.lathe_x(CHROME, (0, 0, 0), [(0.075, 0.016), (0.075, 0.004)], 8)
    # 36 rayons croises : des deux flasques vers la jante
    for i in range(36):
        side = 1 if i % 2 else -1
        a0 = i / 36 * math.tau
        a1 = a0 + side * 0.32
        p0 = (side * 0.04, math.cos(a0) * drum_r * 0.8, math.sin(a0) * drum_r * 0.8)
        p1 = (side * 0.008, math.cos(a1) * (RIM_R - 0.012), math.sin(a1) * (RIM_R - 0.012))
        m.tube(CHROME, [p0, p1], 0.0022, seg=4, caps=False)
    if sprocket:
        # couronne de transmission (cote gauche) et dents
        m.lathe_x(ALU_DARK, (0, 0, 0), [(-0.07, 0.03), (-0.07, 0.092), (-0.074, 0.092), (-0.074, 0.03)], 32)
        for i in range(32):
            a = i / 32 * math.tau
            m.box(ALU_DARK, (-0.072, math.cos(a) * 0.097, math.sin(a) * 0.097), (0.004, 0.009, 0.012), rx=a)
    ob = m.obj(parent)
    return ob


# ------------------------------------------------------------------ groupes
root = empty("veh_zem", (0, 0, 0))
chassis = empty("piv_chassis", (0, 0, 0), root)
CH = Mesh("zem_cadre")

# --- cadre tubulaire : colonne, poutre, berceau, boucle arriere ---
HEAD_TOP = (0, FRONT_Y - 0.165, 0.97)
HEAD_BOT = (0, FRONT_Y - 0.09, 0.81)
CH.tube(FRAME, [HEAD_BOT, HEAD_TOP], 0.034, 14)                       # colonne de direction
CH.tube(FRAME, [(0, 0.45, 0.93), (0, 0.28, 0.82), (0, 0.06, 0.74), (0, -0.12, 0.72)], 0.028, 10)  # poutre centrale
CH.tube(FRAME, [(0, 0.5, 0.82), (0, 0.38, 0.56), (0, 0.27, 0.3), (0, 0.18, 0.2)], 0.022, 10)      # berceau avant
for s in (-1, 1):
    CH.tube(FRAME, [(s * 0.05, -0.12, 0.72), (s * 0.11, -0.3, 0.76), (s * 0.12, -0.72, 0.82)], 0.015, 8)     # rails de selle
    CH.tube(FRAME, [(s * 0.06, -0.06, 0.32), (s * 0.1, -0.3, 0.5), (s * 0.115, -0.55, 0.78)], 0.014, 8)    # jambes de force
CH.tube(FRAME, [(-0.12, -0.72, 0.82), (0, -0.76, 0.83), (0.12, -0.72, 0.82)], 0.015, 8)
CH.box(FRAME, (0, -0.1, 0.33), (0.2, 0.08, 0.1))                    # axe de bras oscillant

# --- bras oscillant et amortisseurs a ressort ---
for s in (-1, 1):
    CH.tube(FRAME, [(s * 0.075, -0.1, 0.33), (s * 0.08, REAR_Y, WHEEL_R)], 0.02, 8)
    CH.box(FRAME, (s * 0.08, REAR_Y + 0.02, WHEEL_R), (0.022, 0.08, 0.05))
    lo = (s * 0.1, REAR_Y + 0.06, WHEEL_R + 0.04)
    hi = (s * 0.115, -0.47, 0.78)
    CH.tube(CHROME, [lo, hi], 0.012, 8)
    CH.tube(ALU_DARK, [v_add(lo, v_mul(v_sub(hi, lo), 0.0)), v_add(lo, v_mul(v_sub(hi, lo), 0.32))], 0.024, 12)
    CH.tube(CHROME, [v_add(lo, v_mul(v_sub(hi, lo), 0.78)), hi], 0.026, 12)
    # ressort en helice
    d = v_sub(hi, lo)
    t = v_norm(d)
    u = v_norm(v_cross(t, (1, 0, 0)))
    wv = v_cross(t, u)
    helix = []
    for k in range(97):
        a = k / 96 * 9 * math.tau
        f = 0.34 + 0.42 * k / 96
        helix.append(v_add(v_add(lo, v_mul(d, f)), v_add(v_mul(u, 0.03 * math.cos(a)), v_mul(wv, 0.03 * math.sin(a)))))
    CH.tube(CHROME, helix, 0.005, 5)

# --- moteur : carter, couvercles, cylindre incline a ailettes, culasse ---
CH.loft(ALU, [(0.2, 0, 0.34, 0.1, 0.08), (0.14, 0, 0.32, 0.12, 0.12), (-0.06, 0, 0.32, 0.12, 0.13), (-0.13, 0, 0.36, 0.1, 0.09)], 18, 3.0)
CH.lathe(ALU, (0.115, 0.05, 0.31), (0, -math.pi / 2), [(0.0, 0.0), (0.0, 0.115), (0.035, 0.112), (0.05, 0.09), (0.055, 0.0)], 24)   # embrayage (droite)
CH.lathe(ALU, (-0.115, 0.02, 0.33), (0, math.pi / 2), [(0.0, 0.0), (0.0, 0.1), (0.04, 0.097), (0.055, 0.075), (0.06, 0.0)], 24)    # alternateur (gauche)
CH.lathe(CHROME, (0.17, 0.05, 0.31), (0, -math.pi / 2), [(0.0, 0.035), (0.008, 0.032), (0.01, 0.0)], 12)
base = (0, 0.17, 0.4)
CYL = math.radians(70)                # cylindre presque droit, incline vers l'avant
axis_dir = (0, math.cos(CYL), math.sin(CYL))
for k in range(9):                    # ailettes de refroidissement
    c = v_add(base, v_mul(axis_dir, 0.03 + k * 0.022))
    CH.box(ALU, c, (0.17 - (0.02 if k > 6 else 0), 0.008, 0.15), rx=CYL)
CH.tube(ALU_DARK, [base, v_add(base, v_mul(axis_dir, 0.2))], 0.045, 12)
head = v_add(base, v_mul(axis_dir, 0.24))
CH.box(ALU, head, (0.15, 0.08, 0.13), rx=CYL, smooth=True)
CH.box(ALU_DARK, v_add(head, v_mul(axis_dir, 0.05)), (0.12, 0.03, 0.1), rx=CYL)
CH.tube(RUBBER, [v_add(head, (0, -0.02, 0.06)), v_add(head, (0.03, -0.06, 0.13)), (0.05, 0.12, 0.66)], 0.008, 6, caps=False)   # fil de bougie
CH.tube(BLACK, [(0.03, 0.12, 0.7), (0.03, 0.06, 0.71)], 0.018, 8)                                                               # bobine (sous le reservoir)
# carburateur, filtre a air, pignon de sortie
CH.lathe(ALU, (0, 0.1, 0.55), (0, 0), [(-0.07, 0.0), (-0.07, 0.03), (0.0, 0.03), (0.0, 0.0)], 10)
CH.loft(BLACK, [(-0.02, 0, 0.56, 0.06, 0.05), (-0.18, 0, 0.6, 0.09, 0.08), (-0.3, 0, 0.62, 0.08, 0.06)], 12, 3.0)
CH.lathe(ALU_DARK, (-0.075, -0.07, 0.31), (0, math.pi / 2), [(0.0, 0.0), (0.0, 0.035), (0.01, 0.035), (0.01, 0.0)], 14)
# chaine (boucle entre pignon et couronne) et carter de chaine
chain = []
for a in range(0, 181, 15):
    t = math.radians(90 - a)          # par l'avant du pignon
    chain.append((-0.072, -0.07 + 0.038 * math.cos(t), 0.31 + 0.038 * math.sin(t)))
for a in range(0, 181, 15):
    t = math.radians(-90 - a)         # par l'arriere de la couronne
    chain.append((-0.072, REAR_Y + 0.095 * math.cos(t), WHEEL_R + 0.095 * math.sin(t)))
CH.tube(CHAIN, chain, 0.006, 5, caps=False, closed=True)
CH.loft(BLACK, [(-0.02, -0.085, 0.345, 0.008, 0.035), (-0.3, -0.085, 0.34, 0.008, 0.06), (-0.58, -0.085, 0.335, 0.008, 0.07)], 10, 4.0)

# --- echappement : collecteur chrome, silencieux avec ecran de chaleur ---
hdr = [v_add(head, v_mul(axis_dir, 0.02)), (0.03, 0.35, 0.4), (0.07, 0.34, 0.24), (0.12, 0.22, 0.2), (0.15, 0.0, 0.24), (0.16, -0.18, 0.28)]
hdr[0] = (0.0, hdr[0][1] + 0.05, hdr[0][2] - 0.04)
CH.tube(CHROME, hdr, 0.019, 12, caps=False)
muff = [(0.16, -0.18 - i * 0.08, 0.28 + i * 0.025) for i in range(8)]
CH.tube(CHROME, muff, 0.05, 16, radii=[0.03, 0.045, 0.052, 0.053, 0.053, 0.052, 0.05, 0.044])
CH.tube(CHROME, [(0.16, -0.74, 0.455), (0.16, -0.78, 0.465)], 0.016, 10)
CH.loft(BLACK, [(-0.24, 0.2, 0.33, 0.012, 0.035), (-0.44, 0.214, 0.38, 0.012, 0.045), (-0.56, 0.215, 0.41, 0.012, 0.04)], 10, 4.0)

# --- reservoir galbe, genouilleres, bouchon, filet decoratif ---
TANK = [(0.47, 0, 0.9, 0.06, 0.04), (0.44, 0, 0.92, 0.13, 0.07), (0.36, 0, 0.93, 0.155, 0.1), (0.24, 0, 0.92, 0.16, 0.11),
        (0.12, 0, 0.88, 0.14, 0.1), (0.04, 0, 0.84, 0.11, 0.07), (0.0, 0, 0.82, 0.08, 0.04)]
CH.loft(PAINT, TANK, 20, 2.4)
for s in (-1, 1):
    CH.loft(RUBBER, [(0.18, s * 0.152, 0.88, 0.006, 0.035), (0.1, s * 0.137, 0.86, 0.006, 0.045), (0.03, s * 0.112, 0.835, 0.006, 0.035)], 8, 3.0)
    CH.loft(STRIPE, [(0.42, s * 0.12, 0.925, 0.003, 0.006), (0.3, s * 0.152, 0.93, 0.003, 0.007), (0.16, s * 0.15, 0.905, 0.003, 0.006)], 6, 2.0, caps=False)
CH.lathe(CHROME, (0, 0.3, 1.03), (math.pi / 2, 0), [(0.0, 0.0), (0.0, 0.04), (0.012, 0.038), (0.016, 0.0)], 16)

# --- selle biplace surpiquee, caches lateraux, garde-boue et feu arriere, porte-bagages ---
SEAT_S = [(0.04, 0, 0.84, 0.1, 0.035), (0.0, 0, 0.865, 0.14, 0.05), (-0.18, 0, 0.87, 0.15, 0.055), (-0.32, 0, 0.885, 0.145, 0.06),
          (-0.5, 0, 0.9, 0.135, 0.055), (-0.64, 0, 0.9, 0.12, 0.045), (-0.68, 0, 0.88, 0.09, 0.03)]
CH.loft(SEAT, SEAT_S, 20, 3.4)
CH.loft(SEAM, [(-0.3, 0, 0.947, 0.13, 0.002), (-0.33, 0, 0.948, 0.13, 0.002)], 16, 3.4)
CH.box(RUBBER, (0, -0.22, 0.81), (0.25, 0.85, 0.02))
for s in (-1, 1):
    CH.loft(PAINT, [(-0.02, s * 0.13, 0.66, 0.01, 0.06), (-0.14, s * 0.15, 0.7, 0.012, 0.1), (-0.3, s * 0.14, 0.73, 0.01, 0.07)], 10, 3.2)
rear_fender = arc((REAR_Y, WHEEL_R), 0.345, math.radians(45), math.radians(165), 12)
for i in range(len(rear_fender) - 1):
    p0, p1 = rear_fender[i], rear_fender[i + 1]
    c = v_mul(v_add(p0, p1), 0.5)
    a = math.atan2(c[2] - WHEEL_R, c[1] - REAR_Y)
    CH.box(BLACK, c, (0.13, v_len(v_sub(p1, p0)) + 0.004, 0.006), rx=a + math.pi / 2, smooth=True)
CH.loft(PAINT, [(-0.82, 0, 0.84, 0.07, 0.04), (-0.92, 0, 0.82, 0.08, 0.05), (-0.95, 0, 0.8, 0.07, 0.045)], 12, 3.0)
CH.box(CHROME, (0, -0.955, 0.81), (0.13, 0.012, 0.07))
CH.box(TAIL, (0, -0.962, 0.81), (0.11, 0.012, 0.055))
CH.box(BLACK, (0, -0.93, 0.7), (0.05, 0.04, 0.16))
CH.box(PLATE, (0, -0.965, 0.66), (0.2, 0.008, 0.13))
for k, x in enumerate((-0.07, -0.035, 0.0, 0.035, 0.07)):     # numero fictif (traits)
    CH.box(PLATE_TXT, (x, -0.97, 0.66 + (0.02 if k % 2 else -0.01)), (0.018, 0.004, 0.05))
for s in (-1, 1):
    CH.tube(BLACK, [(s * 0.06, -0.9, 0.8), (s * 0.15, -0.9, 0.8)], 0.007, 6)
    CH.lathe(AMBER, (s * 0.17, -0.9, 0.8), (0, -s * math.pi / 2), [(0.0, 0.0), (0.0, 0.02), (0.03, 0.022), (0.05, 0.0)], 10)
# porte-bagages chrome (cadre + barreaux) et poignee passager
rack = [(-0.12, -0.6, 0.93), (-0.12, -0.92, 0.93), (0.12, -0.92, 0.93), (0.12, -0.6, 0.93)]
CH.tube(CHROME, rack + [(-0.12, -0.6, 0.93)], 0.011, 8)
for y in (-0.68, -0.76, -0.84):
    CH.tube(CHROME, [(-0.12, y, 0.93), (0.12, y, 0.93)], 0.008, 6)
for s in (-1, 1):
    CH.tube(CHROME, [(s * 0.12, -0.62, 0.93), (s * 0.14, -0.5, 0.92), (s * 0.13, -0.38, 0.9)], 0.011, 8)
    CH.tube(CHROME, [(s * 0.12, -0.88, 0.93), (s * 0.12, -0.84, 0.82)], 0.009, 6)

# --- reposes-pieds, kick, selecteur, frein, bequilles, pare-moteur ---
for s in (-1, 1):
    CH.tube(RUBBER, [(s * 0.13, 0.0, 0.3), (s * 0.26, 0.0, 0.3)], 0.017, 8)
    CH.tube(CHROME, [(s * 0.09, -0.3, 0.42), (s * 0.13, -0.36, 0.38), (s * 0.24, -0.36, 0.38)], 0.009, 6)
    CH.tube(RUBBER, [(s * 0.15, -0.36, 0.38), (s * 0.24, -0.36, 0.38)], 0.015, 8)
CH.tube(CHROME, [(-0.13, 0.04, 0.33), (-0.17, 0.1, 0.36), (-0.2, 0.17, 0.37)], 0.008, 6)        # selecteur
CH.tube(CHROME, [(0.13, -0.02, 0.27), (0.2, 0.1, 0.28), (0.21, 0.16, 0.29)], 0.009, 6)           # pedale de frein
CH.tube(CHROME, [(0.17, -0.05, 0.4), (0.21, -0.1, 0.48), (0.23, -0.18, 0.5)], 0.01, 6)           # kick
CH.tube(FRAME, [(-0.1, -0.1, 0.26), (-0.12, -0.15, 0.12), (-0.12, -0.12, 0.02)], 0.012, 6)      # bequille centrale
CH.tube(FRAME, [(0.1, -0.1, 0.26), (0.12, -0.15, 0.12), (0.12, -0.12, 0.02)], 0.012, 6)
CH.tube(FRAME, [(-0.12, -0.12, 0.02), (0.12, -0.12, 0.02)], 0.012, 6)
CH.tube(FRAME, [(-0.1, 0.05, 0.26), (-0.22, 0.12, 0.12)], 0.009, 6)                              # bequille laterale
for s in (-1, 1):                                                                                   # pare-moteur tubulaire
    CH.tube(CHROME, [(0, 0.5, 0.74), (s * 0.12, 0.47, 0.62), (s * 0.28, 0.33, 0.48), (s * 0.27, 0.22, 0.34), (s * 0.12, 0.2, 0.22)], 0.014, 8)
CH.obj(chassis)

# --- roue arriere ---
rr = empty("piv_roue_ar", (0, REAR_Y, WHEEL_R), chassis)
wheel("zem_roue_ar", rr, 0.075, sprocket=True)

# --- direction (tout tourne autour de l'axe de colonne) ---
STEER_TILT = math.radians(25)
steer_base = empty("piv_colonne", (0, FRONT_Y - 0.18, 0.95), chassis, rotation=(STEER_TILT, 0, 0))   # chasse
steer = empty("piv_guidon", (0, 0, 0), steer_base)
fork_len = 0.95 - WHEEL_R
wheel_local = (0, 0, -fork_len / math.cos(STEER_TILT))
ST = Mesh("zem_direction")
# te de fourche haut et bas, tubes chromes, fourreaux alu, soufflets
for z in (0.035, -0.12):
    ST.loft(FRAME, [(-0.04, 0, z, 0.1, 0.018), (0.04, 0, z, 0.1, 0.018)], 12, 3.0)
for s in (-1, 1):
    ST.tube(CHROME, [(s * 0.075, 0, 0.06), (s * 0.075, 0, -0.33)], 0.017, 12)
    gaiter = [(s * 0.075, 0, -0.27 - k * 0.012) for k in range(13)]
    ST.tube(RUBBER, gaiter, 0.024, 12, radii=[0.022 if k % 2 else 0.026 for k in range(13)])
    ST.tube(ALU, [(s * 0.075, 0, -0.42), (s * 0.075, 0, wheel_local[2] + 0.03)], 0.026, 12)
# phare rond (coquille, cerclage chrome, glace), compteur rond, clignotants
lamp_c = (0, 0.12, -0.04)
ST.lathe(BLACK, lamp_c, (-STEER_TILT, 0), [(-0.08, 0.0), (-0.08, 0.06), (-0.04, 0.09), (0.0, 0.098), (0.03, 0.098)], 22, caps=True)
ST.lathe(CHROME, lamp_c, (-STEER_TILT, 0), [(0.025, 0.1), (0.04, 0.104), (0.045, 0.094), (0.04, 0.086)], 22, caps=False)
ST.lathe(REFLECT, lamp_c, (-STEER_TILT, 0), [(0.0, 0.0), (0.03, 0.086)], 22, caps=False)
ST.lathe(LIGHT, lamp_c, (-STEER_TILT, 0), [(0.042, 0.088), (0.05, 0.06), (0.053, 0.0)], 22, caps=False)
for s in (-1, 1):
    ST.tube(BLACK, [(s * 0.06, 0.08, -0.06), (s * 0.15, 0.1, -0.06)], 0.007, 6)
    ST.lathe(AMBER, (s * 0.17, 0.1, -0.06), (0, -s * math.pi / 2), [(0.0, 0.0), (0.0, 0.02), (0.03, 0.022), (0.05, 0.0)], 10)
ST.lathe(BLACK, (0, -0.02, 0.12), (math.radians(105), 0), [(0.0, 0.0), (0.0, 0.05), (0.04, 0.052), (0.045, 0.0)], 18)
ST.lathe(DIAL, (0, -0.02, 0.12), (math.radians(105), 0), [(0.046, 0.044), (0.047, 0.0)], 18, caps=False)
# guidon cintre (releve et recule), poignees, leviers, retroviseurs ronds
bar = [(-0.36, -0.12, 0.2), (-0.3, -0.1, 0.19), (-0.18, -0.03, 0.15), (-0.06, 0.0, 0.1), (0.06, 0.0, 0.1), (0.18, -0.03, 0.15), (0.3, -0.1, 0.19), (0.36, -0.12, 0.2)]
ST.tube(CHROME, bar, 0.011, 10)
ST.box(FRAME, (0, -0.005, 0.085), (0.12, 0.05, 0.035))
for s in (-1, 1):
    ST.tube(RUBBER, [(s * 0.28, -0.095, 0.188), (s * 0.4, -0.13, 0.205)], 0.017, 12)
    ST.tube(ALU, [(s * 0.22, -0.05, 0.17), (s * 0.3, -0.03, 0.19), (s * 0.38, -0.07, 0.2)], 0.006, 6)       # levier
    ST.box(BLACK, (s * 0.21, -0.07, 0.17), (0.05, 0.05, 0.04), rz=s * 0.3)                               # commodo
    ST.tube(CHROME, [(s * 0.2, -0.05, 0.18), (s * 0.24, -0.045, 0.26), (s * 0.28, -0.04, 0.32)], 0.005, 6)
    ST.lathe(BLACK, (s * 0.29, -0.04, 0.345), (0, 0), [(0.0, 0.0), (0.0, 0.045), (0.015, 0.047), (0.02, 0.0)], 14)
    ST.lathe(REFLECT, (s * 0.29, -0.042, 0.345), (0, 0), [(0.0, 0.0), (-0.002, 0.04)], 14, caps=False)
ST.obj(steer)

fr = empty("piv_roue_av_axe", wheel_local, steer, rotation=(-STEER_TILT, 0, 0))   # la roue reste verticale
AX = Mesh("zem_garde_boue_av")
fender = arc((0, 0), 0.34, math.radians(25), math.radians(155), 12)
for i in range(len(fender) - 1):
    p0, p1 = fender[i], fender[i + 1]
    c = v_mul(v_add(p0, p1), 0.5)
    a = math.atan2(c[2], c[1])
    AX.box(PAINT, c, (0.11, v_len(v_sub(p1, p0)) + 0.004, 0.006), rx=a + math.pi / 2, smooth=True)
for s in (-1, 1):
    AX.tube(CHROME, [(s * 0.06, -0.05, 0.3), (s * 0.075, 0.0, 0.06)], 0.006, 6)
    AX.box(ALU, (s * 0.075, 0, 0), (0.03, 0.05, 0.05))
AX.obj(fr)
wf = empty("piv_roue_av", (0, 0, 0), fr)
wheel("zem_roue_av", wf, 0.06)

# reperes de position pour le conducteur et le passager (hanches)
empty("pt_conducteur", (0, -0.12, 0.87), root)
empty("pt_passager", (0, -0.45, 0.9), root)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True)
faces = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
print("Zem :", len([o for o in bpy.data.objects if o.type == "MESH"]), "objets,", faces, "faces")

if PREVIEW_DIR:
    w = bpy.data.worlds.new("w")
    w.color = (0.75, 0.8, 0.85)
    scene.world = w
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 700
    for nm, loc, rot_ in (("trois_quart", (2.2, 2.0, 1.45), (72, 0, 132)), ("profil_droit", (3.0, 0, 0.7), (88, 0, 90)),
                          ("arriere", (-1.6, -2.4, 1.4), (70, 0, -33))):
        c = bpy.data.cameras.new(nm)
        c.lens = 45
        o = bpy.data.objects.new(nm, c)
        scene.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = [math.radians(a) for a in rot_]
        scene.camera = o
        scene.render.filepath = os.path.join(PREVIEW_DIR, "zem_%s.png" % nm)
        bpy.ops.render.render(write_still=True)
