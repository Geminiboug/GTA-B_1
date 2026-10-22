# GTB : mobilier urbain et vehicules low poly faits par script (aucun asset externe, aucune marque reelle).
# Lancement : blender -b --python blender/tools/build_props.py -- <lib_materiaux.blend> <sortie.blend> <sortie.glb>
# Chaque objet : origine au sol, avant vers +Y Blender (= -Z Godot). Les materiaux viennent de la bibliotheque
# (leurs noms servent a Godot : mat_carrosserie teinte par instance, mat_lampe allumee la nuit, mat_tissu_* ...).
import bpy
import bmesh
import math
import random
import sys
from mathutils import Euler, Vector

args = sys.argv[sys.argv.index("--") + 1:]
MATLIB, OUT_BLEND, OUT_GLB = args[:3]
random.seed(11)

bpy.ops.wm.read_homefile(use_empty=True)
with bpy.data.libraries.load(MATLIB, link=False) as (src, dst):
    dst.materials = [m for m in src.materials if m.startswith("mat_")]
MAT = {m.name: m for m in bpy.data.materials}
for m in MAT.values():
    if m.asset_data:
        m.asset_clear()
    m.use_fake_user = False


class Builder:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def box(self, mat, center, size, rot=(0, 0, 0)):
        R = Euler(rot).to_matrix()
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        corners = [Vector((sx * hx, sy * hy, sz * hz)) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
        vs = [self.bm.verts.new(Vector(center) + R @ c) for c in corners]
        k = self.mi(mat)
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            self.bm.faces.new([vs[i] for i in f]).material_index = k

    def cyl(self, mat, base, r, h, segs=10, rot=(0, 0, 0), r2=None, caps=True):
        R = Euler(rot).to_matrix()
        r2 = r if r2 is None else max(r2, 0.001)
        b = Vector(base)
        bot = [self.bm.verts.new(b + R @ Vector((r * math.cos(i / segs * math.tau), r * math.sin(i / segs * math.tau), 0))) for i in range(segs)]
        top = [self.bm.verts.new(b + R @ Vector((r2 * math.cos(i / segs * math.tau), r2 * math.sin(i / segs * math.tau), h))) for i in range(segs)]
        k = self.mi(mat)
        for i in range(segs):
            j = (i + 1) % segs
            self.bm.faces.new((bot[i], bot[j], top[j], top[i])).material_index = k
        if caps:
            self.bm.faces.new(top).material_index = k
            self.bm.faces.new(bot[::-1]).material_index = k

    def blob(self, mat, center, radius, squash=0.8, subdiv=1):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=radius)
        k = self.mi(mat)
        vmap = {}
        for v in tmp.verts:
            co = v.co * (0.8 + 0.4 * random.random())
            co.z *= squash
            vmap[v] = self.bm.verts.new(co + Vector(center))
        for f in tmp.faces:
            self.bm.faces.new([vmap[v] for v in f.verts]).material_index = k
        tmp.free()

    def done(self, x_offset):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(MAT[m])
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.location.x = x_offset
        return ob


objs = []
X = [0.0]


def finish(b, spacing=6.0):
    objs.append(b.done(X[0]))
    X[0] += spacing


# ---------------- Poteau electrique en beton (reseau basse tension de Cotonou : section carree effilee, refs/rues/) ----
def poteau(name, transfo):
    b = Builder(name)
    b.cyl("mat_beton", (0, 0, 0), 0.17, 9.0, segs=4, r2=0.1, rot=(0, 0, math.radians(45)))
    b.box("mat_metal_peint", (0, 0, 8.4), (1.9, 0.1, 0.1))
    for x in (-0.75, 0.0, 0.75):
        b.cyl("mat_blanc_plastique", (x, 0, 8.45), 0.04, 0.12, segs=6)
    b.box("mat_metal_peint", (0.35, 0, 8.0), (0.06, 0.06, 0.6), rot=(0, math.radians(35), 0))
    # boitiers et fils de branchement accroches au poteau (desordre des raccordements)
    b.box("mat_blanc_plastique", (0, 0.16, 3.1), (0.22, 0.12, 0.3))
    b.box("mat_metal_peint", (0, -0.15, 2.4), (0.2, 0.1, 0.26))
    if transfo:
        b.box("mat_metal_peint", (0, 0.42, 6.4), (0.55, 0.45, 0.85))
        b.box("mat_metal_peint", (0, 0.2, 6.4), (0.1, 0.4, 0.1))
        for x in (-0.15, 0.15):
            b.cyl("mat_blanc_plastique", (x, 0.42, 6.83), 0.035, 0.15, segs=6)
    finish(b)


poteau("prop_poteau", False)
poteau("prop_poteau_transfo", True)

# ---------------- Lampadaire solaire (grands axes et promenade de Cotonou, refs/rues/) : mat blanc, panneau incline
# au sommet, tete LED sur un bras court vers la route (+Y), batterie sous le panneau ----------------
b = Builder("prop_lampadaire")
b.cyl("mat_peinture_blanc", (0, 0, 0), 0.1, 9.0, segs=8, r2=0.06)
b.box("mat_beton", (0, 0, 0.25), (0.45, 0.45, 0.5))
b.box("mat_metal_peint", (0, 0, 9.05), (0.06, 0.06, 0.25))
b.box("mat_vitre", (0, -0.05, 9.25), (0.75, 1.15, 0.04), rot=(math.radians(15), 0, 0))     # panneau solaire
b.box("mat_chrome", (0, -0.05, 9.23), (0.79, 1.19, 0.02), rot=(math.radians(15), 0, 0))
b.box("mat_metal_peint", (0, 0.1, 8.75), (0.28, 0.2, 0.38))                                 # batterie
b.box("mat_peinture_blanc", (0, 0.45, 8.3), (0.06, 0.8, 0.06), rot=(math.radians(-10), 0, 0))
b.box("mat_metal_peint", (0, 0.9, 8.25), (0.26, 0.5, 0.08))
b.box("mat_lampe", (0, 0.9, 8.2), (0.2, 0.42, 0.02))
finish(b)

# ---------------- Etal de kpayo (essence vendue en bouteilles) ----------------
b = Builder("prop_kpayo")
b.box("mat_bois_clair", (0, 0, 0.8), (1.1, 0.55, 0.04))
for x in (-0.5, 0.5):
    for y in (-0.22, 0.22):
        b.box("mat_bois_clair", (x, y, 0.4), (0.05, 0.05, 0.8))
for i in range(4):
    for j in range(3):
        x, y = -0.42 + i * 0.28, -0.15 + j * 0.15
        b.cyl("mat_verre_carburant", (x, y, 0.82), 0.045, 0.24, segs=8)
        b.cyl("mat_verre_carburant", (x, y, 1.06), 0.045, 0.06, segs=8, r2=0.016)
        b.cyl("mat_plastique_rouge", (x, y, 1.12), 0.018, 0.03, segs=6)
b.box("mat_peinture_jaune", (0.85, 0.05, 0.22), (0.2, 0.32, 0.44))   # bidon
b.box("mat_peinture_jaune", (0.85, 0.05, 0.47), (0.06, 0.12, 0.05))
b.cyl("mat_metal_peint", (-0.3, 0.0, 0.82), 0.08, 0.12, segs=8, r2=0.012)  # entonnoir
b.cyl("mat_plastique_bleu", (-0.85, -0.3, 0.0), 0.16, 0.42, segs=8)       # tabouret
finish(b)

# ---------------- Etals de vendeuses sous parasol : un modele par marchandise (retour d'Olympe du 21/10/2026 : ce qui est
# vendu doit etre modelise et correspondre a ce que crie la vendeuse) ----------------
def etal_base(b, parasol):
    b.cyl("mat_metal_peint", (0, -0.2, 0), 0.025, 2.4, segs=6)
    b.cyl("mat_tissu_" + parasol, (0, -0.2, 2.0), 1.45, 0.45, segs=10, r2=0.05, caps=False)
    b.cyl("mat_tissu_" + parasol, (0, -0.2, 2.0), 1.45, 0.001, segs=10, caps=False)
    b.box("mat_bois_clair", (0, 0.35, 0.75), (1.3, 0.75, 0.05))
    for x in (-0.6, 0.6):
        for y in (0.05, 0.65):
            b.box("mat_bois_clair", (x, y, 0.37), (0.05, 0.05, 0.74))
    b.cyl("mat_plastique_bleu", (0.3, -0.45, 0), 0.17, 0.42, segs=8)  # tabouret


def etal_pain():
    b = Builder("prop_etal_pain")
    etal_base(b, "rouge")
    b.box("mat_blanc_plastique", (0, 0.35, 0.78), (1.24, 0.7, 0.01))          # nappe
    for r in range(2):                                                            # baguettes et pains en caisse vitree
        for i in range(5):
            b.box("mat_bois", (-0.45 + i * 0.22, 0.2 + r * 0.25, 0.83), (0.16, 0.62, 0.09), rot=(0, 0, random.uniform(-0.05, 0.05)))
    for i in range(3):
        b.blob("mat_bois", (-0.4 + i * 0.4, 0.62, 0.84), 0.09, squash=0.6)      # petits pains ronds
    b.box("mat_verre", (0, 0.35, 0.96), (1.1, 0.62, 0.002))
    finish(b)


def etal_fruits():
    b = Builder("prop_etal_fruits")
    etal_base(b, "jaune")
    for i in range(4):                                                            # ananas : corps jaune, panache vert
        x = -0.45 + i * 0.3
        b.cyl("mat_peinture_jaune", (x, 0.22, 0.78), 0.075, 0.2, segs=8)
        b.cyl("mat_vegetation", (x, 0.22, 0.97), 0.05, 0.12, segs=6, r2=0.005)
    for k in range(7):                                                            # oranges et bananes
        b.blob("mat_peinture_jaune" if k % 2 else "mat_peinture_rouge", (-0.45 + random.uniform(0, 0.9), 0.5 + random.uniform(-0.05, 0.1), 0.82), 0.055, squash=1.0)
    b.cyl("mat_plastique_vert", (0.4, 0.55, 0.78), 0.14, 0.08, segs=10, r2=0.18)    # bassine
    finish(b)


def etal_arachides():
    b = Builder("prop_etal_arachides")
    etal_base(b, "bleu")
    for i, x in enumerate((-0.4, 0.0, 0.4)):                                      # bassines d'arachides grillees (tas beiges)
        b.cyl("mat_plastique_rouge" if i != 1 else "mat_plastique_bleu", (x, 0.35, 0.78), 0.17, 0.1, segs=10, r2=0.22)
        for k in range(10):
            b.blob("mat_sable", (x + random.uniform(-0.1, 0.1), 0.35 + random.uniform(-0.1, 0.1), 0.9 + random.uniform(0, 0.05)), 0.045, squash=0.7)
    for i in range(4):                                                            # petits sachets plastique
        b.box("mat_blanc_plastique", (-0.5 + i * 0.07, 0.6, 0.82), (0.06, 0.04, 0.1))
    b.box("mat_metal_peint", (0.0, 0.0, 0.79), (0.14, 0.14, 0.03))              # mesure (boite de conserve)
    finish(b)


def etal_eau():
    b = Builder("prop_etal_eau")
    etal_base(b, "bleu")
    b.box("mat_blanc_plastique", (-0.3, 0.35, 0.88), (0.55, 0.45, 0.25))        # glaciere
    b.box("mat_plastique_bleu", (-0.3, 0.35, 1.02), (0.57, 0.47, 0.04))
    for r in range(3):                                                            # sachets d'eau empiles (pure water)
        for i in range(4):
            b.box("mat_vitre", (0.15 + i * 0.12, 0.2 + r * 0.02, 0.8 + r * 0.045), (0.1, 0.2, 0.035), rot=(0, 0, random.uniform(-0.1, 0.1)))
    for i in range(4):                                                            # bouteilles
        b.cyl("mat_verre", (0.2 + i * 0.1, 0.6, 0.78), 0.033, 0.22, segs=8)
        b.cyl("mat_plastique_bleu", (0.2 + i * 0.1, 0.6, 0.99), 0.017, 0.03, segs=6)
    finish(b)


def etal_legumes():
    b = Builder("prop_etal_legumes")
    etal_base(b, "rouge")
    for i, (x, m) in enumerate(((-0.42, "mat_peinture_rouge"), (0.0, "mat_vegetation"), (0.42, "mat_peinture_ocre"))):
        b.cyl("mat_plastique_vert" if i != 1 else "mat_plastique_rouge", (x, 0.35, 0.78), 0.17, 0.1, segs=10, r2=0.22)   # tomates, piments, oignons
        for k in range(9):
            b.blob(m, (x + random.uniform(-0.11, 0.11), 0.35 + random.uniform(-0.11, 0.11), 0.9 + random.uniform(0, 0.04)), 0.05, squash=1.0)
    finish(b)


for f in (etal_pain, etal_fruits, etal_arachides, etal_eau, etal_legumes):
    f()

# ---------------- Tas d'ordures ----------------
b = Builder("prop_ordures")
for k in range(9):
    b.blob(random.choice(["mat_ordures", "mat_ordures", "mat_citerne", "mat_plastique_bleu", "mat_blanc_plastique"]),
           (random.uniform(-1.1, 1.1), random.uniform(-0.8, 0.8), 0.15), random.uniform(0.25, 0.55), squash=0.5)
finish(b)

# ---------------- Pile de pneus (vulcanisateur) ----------------
b = Builder("prop_pneus")
for k in range(4):
    b.cyl("mat_pneu", (0, 0, k * 0.2), 0.34, 0.19, segs=12)
b.cyl("mat_pneu", (0.8, 0, 0.0), 0.32, 0.2, segs=12, rot=(math.radians(80), 0, 0))
b.box("mat_bois", (-0.7, 0.2, 0.6), (0.06, 0.06, 1.2))
b.box("mat_peinture_blanc", (-0.7, 0.2, 1.25), (0.7, 0.04, 0.35))
finish(b)

# ---------------- Table de maquis + chaises plastique ----------------
b = Builder("prop_maquis")
b.box("mat_blanc_plastique", (0, 0, 0.72), (0.9, 0.9, 0.04))
for x in (-0.38, 0.38):
    for y in (-0.38, 0.38):
        b.box("mat_blanc_plastique", (x, y, 0.36), (0.04, 0.04, 0.72))
for ang in (0, 90, 180, 270):
    a = math.radians(ang)
    cx, cy = math.sin(a) * 0.85, math.cos(a) * 0.85
    b.box("mat_blanc_plastique", (cx, cy, 0.44), (0.45, 0.45, 0.04), rot=(0, 0, -a))
    b.box("mat_blanc_plastique", (cx + math.sin(a) * 0.22, cy + math.cos(a) * 0.22, 0.7), (0.45, 0.04, 0.5), rot=(0, 0, -a))
    for lx in (-0.18, 0.18):
        for ly in (-0.18, 0.18):
            px = cx + lx * math.cos(a) + ly * math.sin(a)
            py = cy - lx * math.sin(a) + ly * math.cos(a)
            b.box("mat_blanc_plastique", (px, py, 0.21), (0.035, 0.035, 0.42))
for k in range(3):
    b.cyl("mat_verre", (random.uniform(-0.25, 0.25), random.uniform(-0.25, 0.25), 0.74), 0.035, 0.24, segs=6)
finish(b)

# ---------------- Cabine de transfert d'argent / credit ----------------
b = Builder("prop_cabine")
b.box("mat_peinture_bleu", (0, 0, 1.1), (1.6, 1.3, 2.2))
b.box("mat_citerne", (0, 0.66, 1.25), (1.2, 0.04, 0.7))      # guichet
b.box("mat_bois_clair", (0, 0.8, 0.95), (1.3, 0.3, 0.05))     # tablette
b.box("mat_tole_rouillee", (0, 0.2, 2.28), (2.0, 1.9, 0.06))
b.box("mat_peinture_jaune", (0, 0.67, 1.85), (1.5, 0.03, 0.35))  # bandeau (texte ajoute dans Godot)
finish(b)

# ---------------- Panneau publicitaire ----------------
b = Builder("prop_panneau_pub")
for x in (-2.0, 2.0):
    b.box("mat_metal_peint", (x, 0, 2.8), (0.25, 0.25, 5.6))
b.box("mat_metal_peint", (0, -0.12, 5.5), (6.4, 0.1, 3.2))
b.box("mat_blanc_plastique", (0, 0.0, 5.5), (6.0, 0.06, 2.9))   # affiche (texte / couleurs dans Godot)
b.box("mat_metal_peint", (0, 0.5, 3.75), (6.2, 0.9, 0.06))      # passerelle
finish(b, 9.0)


# ---------------- Voitures ----------------
def wheel(b, x, y, r=0.31):
    b.cyl("mat_pneu", (x - 0.11, y, r), r, 0.22, segs=12, rot=(0, math.radians(90), 0))
    b.cyl("mat_chrome", (x + (0.12 if x > 0 else -0.12) - 0.01, y, r), r * 0.55, 0.02, segs=10, rot=(0, math.radians(90), 0))


def voiture(name, L, W, H, cab_l, cab_h, ground=0.22, cab_off=-0.1):
    b = Builder(name)
    body_h = H - cab_h - ground
    b.box("mat_carrosserie", (0, 0, ground + body_h / 2), (W, L, body_h))
    b.box("mat_verre", (0, cab_off, ground + body_h + cab_h / 2 - 0.02), (W - 0.12, cab_l, cab_h - 0.04))
    b.box("mat_carrosserie", (0, cab_off, H - 0.03), (W - 0.1, cab_l - 0.25, 0.06))
    for sx in (-1, 1):  # montants
        for y in (cab_off - cab_l / 2 + 0.06, cab_off + cab_l / 2 - 0.06):
            b.box("mat_carrosserie", (sx * (W / 2 - 0.07), y, ground + body_h + cab_h / 2), (0.06, 0.1, cab_h))
    b.box("mat_citerne", (0, L / 2 + 0.02, ground + 0.18), (W - 0.05, 0.08, 0.2))     # pare-chocs
    b.box("mat_citerne", (0, -L / 2 - 0.02, ground + 0.18), (W - 0.05, 0.08, 0.2))
    for sx in (-1, 1):
        b.box("mat_lampe", (sx * (W / 2 - 0.25), L / 2 + 0.01, ground + body_h - 0.15), (0.3, 0.04, 0.12))
        b.box("mat_feu_arriere" if "mat_feu_arriere" in MAT else "mat_plastique_rouge", (sx * (W / 2 - 0.22), -L / 2 - 0.01, ground + body_h - 0.15), (0.28, 0.04, 0.12))
        b.box("mat_citerne", (sx * (W / 2 + 0.06), cab_off + cab_l / 2 - 0.1, ground + body_h + 0.1), (0.08, 0.12, 0.08))  # retros
    for sx in (-1, 1):
        for sy in (-1, 1):
            wheel(b, sx * (W / 2 - 0.12), sy * (L / 2 - 0.85))
    b.box("mat_blanc_plastique", (0, -L / 2 - 0.04, ground + 0.32), (0.5, 0.02, 0.12))  # plaque
    finish(b)


voiture("veh_berline", 4.45, 1.76, 1.45, 2.1, 0.55)
voiture("veh_4x4", 4.7, 1.88, 1.85, 2.7, 0.72, ground=0.3, cab_off=-0.25)


bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True)
print("Props :", [(o.name, len(o.data.polygons)) for o in objs])
