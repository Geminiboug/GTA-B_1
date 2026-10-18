# GTB : vegetation low poly faite par script (aucun asset externe).
# Lancement : blender -b --python blender/tools/build_vegetation.py -- <sortie.blend> <sortie.glb>
# Objets (un mesh chacun, origine au pied, Z = haut) :
#   veg_cocotier  : tronc courbe annele, 9 palmes arquees, noix de coco
#   veg_arbre     : manguier, tronc + houppier dense en volumes irreguliers
#   veg_badamier  : badamier (Terminalia catappa), branches en etages horizontaux, quelques feuilles rougies
#   veg_neem      : neem, tronc qui fourche, houppier ovale serre vert olive
#   veg_buisson   : touffe basse
import bpy
import bmesh
import math
import random
import sys
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, OUT_GLB = args[:2]
random.seed(7)

bpy.ops.wm.read_homefile(use_empty=True)


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, srgb, rough=0.85):
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
    m.diffuse_color = rgba
    m.use_backface_culling = False
    return m


BARK_PALM = material("veg_ecorce_cocotier", (0.47, 0.40, 0.31))
FROND = material("veg_palme", (0.30, 0.45, 0.14), 0.7)
FROND_DRY = material("veg_palme_seche", (0.55, 0.47, 0.25), 0.8)
COCONUT = material("veg_noix", (0.35, 0.42, 0.12), 0.6)
BARK = material("veg_ecorce", (0.30, 0.24, 0.18))
LEAVES = material("veg_feuillage", (0.20, 0.36, 0.12), 0.8)
LEAVES2 = material("veg_feuillage_clair", (0.30, 0.45, 0.16), 0.8)
BADAMIER = material("veg_feuillage_badamier", (0.27, 0.46, 0.15), 0.75)
BADAMIER_ROUGE = material("veg_feuillage_rougi", (0.5, 0.3, 0.14), 0.8)
NEEM = material("veg_feuillage_neem", (0.22, 0.37, 0.13), 0.8)
BARK_GRIS = material("veg_ecorce_grise", (0.36, 0.33, 0.29))


def new_object(name):
    me = bpy.data.meshes.new(name)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def add_material(ob, mat):
    if mat.name not in [m.name for m in ob.data.materials]:
        ob.data.materials.append(mat)
    return [m.name for m in ob.data.materials].index(mat.name)


def tube(bm, path, radii, segs, mat_index):
    """Tube le long d'une polyligne (liste de Vector), rayon par point."""
    rings = []
    for i, p in enumerate(path):
        d = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        side = d.cross(Vector((0, 0, 1)))
        if side.length < 1e-3:
            side = Vector((1, 0, 0))
        side.normalize()
        up = side.cross(d).normalized()
        ring = []
        for s in range(segs):
            a = s / segs * math.tau
            ring.append(bm.verts.new(p + (side * math.cos(a) + up * math.sin(a)) * radii[i]))
        rings.append(ring)
    for r0, r1 in zip(rings, rings[1:]):
        for s in range(segs):
            f = bm.faces.new((r0[s], r0[(s + 1) % segs], r1[(s + 1) % segs], r1[s]))
            f.material_index = mat_index
    return rings


def blob(bm, center, radius, mat_index, squash=0.75, subdiv=1):
    """Volume de feuillage irregulier (icosphere deformee)."""
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=radius)
    for v in tmp.verts:
        n = v.co.normalized()
        v.co = v.co * (0.8 + 0.4 * random.random())
        v.co.z *= squash
        v.co += center
    vmap = {}
    for v in tmp.verts:
        vmap[v] = bm.verts.new(v.co)
    for f in tmp.faces:
        nf = bm.faces.new([vmap[v] for v in f.verts])
        nf.material_index = mat_index
    tmp.free()


# ---------------- Cocotier ----------------
def build_cocotier():
    ob = new_object("veg_cocotier")
    i_bark = add_material(ob, BARK_PALM)
    i_frond = add_material(ob, FROND)
    i_dry = add_material(ob, FROND_DRY)
    i_nut = add_material(ob, COCONUT)
    bm = bmesh.new()
    height = 9.0
    lean = Vector((1.6, 0.3, 0))  # les cocotiers penchent, souvent vers la mer
    path, radii = [], []
    n = 10
    for i in range(n + 1):
        t = i / n
        p = Vector((0, 0, t * height)) + lean * (t ** 2)
        path.append(p)
        radii.append(0.22 - 0.07 * t + (0.02 if i % 2 else 0.0))  # anneaux du tronc
    tube(bm, path, radii, 8, i_bark)
    top = path[-1]
    # palmes : bandes arquees, plus larges au milieu, pointe vers le bas
    for k in range(9):
        ang = k / 9 * math.tau + random.uniform(-0.15, 0.15)
        length = random.uniform(3.6, 4.6)
        droop = random.uniform(0.6, 1.2)
        dry = k == 8
        dirv = Vector((math.cos(ang), math.sin(ang), 0))
        side = Vector((-dirv.y, dirv.x, 0))
        steps = 8
        left, right = [], []
        for s in range(steps + 1):
            t = s / steps
            p = top + dirv * length * t + Vector((0, 0, 0.9 * t - droop * 2.2 * t * t - (1.6 if dry else 0) * t))
            w = math.sin(t * math.pi) * 0.55 + 0.05
            # les folioles retombent : la bande est en V
            left.append(bm.verts.new(p + side * w + Vector((0, 0, -w * 0.4))))
            right.append(bm.verts.new(p - side * w + Vector((0, 0, -w * 0.4))))
        mid = [bm.verts.new(top + dirv * length * (s / steps) + Vector((0, 0, 0.9 * (s / steps) - droop * 2.2 * (s / steps) ** 2 - (1.6 if dry else 0) * (s / steps))))
               for s in range(steps + 1)]
        for s in range(steps):
            for a, b in ((left, mid), (mid, right)):
                f = bm.faces.new((a[s], a[s + 1], b[s + 1], b[s]))
                f.material_index = i_dry if dry else i_frond
    # noix de coco sous la couronne
    for k in range(5):
        ang = k / 5 * math.tau
        blob(bm, top + Vector((math.cos(ang) * 0.3, math.sin(ang) * 0.3, -0.35)), 0.16, i_nut, squash=1.0, subdiv=1)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


# ---------------- Arbre (neem / manguier) ----------------
def build_arbre():
    ob = new_object("veg_arbre")
    i_bark = add_material(ob, BARK)
    i_leaf = add_material(ob, LEAVES)
    i_leaf2 = add_material(ob, LEAVES2)
    bm = bmesh.new()
    trunk = [Vector((0, 0, 0)), Vector((0.1, 0, 1.5)), Vector((0.15, 0.1, 2.8))]
    tube(bm, trunk, [0.32, 0.26, 0.2], 8, i_bark)
    # branches maitresses
    for ang in (0.3, 2.4, 4.3):
        b = [trunk[-1], trunk[-1] + Vector((math.cos(ang) * 1.4, math.sin(ang) * 1.4, 1.3))]
        tube(bm, b, [0.16, 0.08], 6, i_bark)
    # houppier : grappe de volumes
    for k in range(11):
        ang = random.uniform(0, math.tau)
        r = random.uniform(0.5, 2.4)
        c = Vector((math.cos(ang) * r, math.sin(ang) * r, random.uniform(4.0, 5.6)))
        blob(bm, c, random.uniform(1.1, 1.9), i_leaf if k % 3 else i_leaf2, squash=0.7, subdiv=2)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


# ---------------- Badamier (refs : arbres d'ombre des rues et des cours, branches en etages) ----------------
def build_badamier():
    ob = new_object("veg_badamier")
    i_bark = add_material(ob, BARK_GRIS)
    i_leaf = add_material(ob, BADAMIER)
    i_red = add_material(ob, BADAMIER_ROUGE)
    bm = bmesh.new()
    trunk = [Vector((0, 0, 0)), Vector((0.05, 0, 2.5)), Vector((0.08, 0.04, 5.2)), Vector((0.1, 0.05, 6.6))]
    tube(bm, trunk, [0.3, 0.24, 0.16, 0.08], 8, i_bark)
    # etages : branches presque horizontales en verticille, feuillage en plateaux aplatis au bout
    tiers = [(2.9, 3.8, 6), (4.0, 3.1, 6), (5.1, 2.3, 5), (6.1, 1.4, 4)]
    for ti, (z, reach, nb) in enumerate(tiers):
        off = random.uniform(0, math.tau)
        for k in range(nb):
            ang = off + k / nb * math.tau + random.uniform(-0.2, 0.2)
            d = Vector((math.cos(ang), math.sin(ang), 0))
            a = Vector((0.05, 0, z))
            b = a + d * reach + Vector((0, 0, 0.35))
            tube(bm, [a, a + d * reach * 0.5 + Vector((0, 0, 0.12)), b], [0.09 - ti * 0.015, 0.06 - ti * 0.01, 0.03], 5, i_bark)
            for j in range(3):
                c = a + d * reach * (0.4 + 0.3 * j) + Vector((0, 0, 0.4 + 0.05 * j))
                mat = i_red if random.random() < 0.06 else i_leaf
                blob(bm, c, random.uniform(1.15, 1.5) * (1.0 - ti * 0.12), mat, squash=0.3, subdiv=1)
    blob(bm, Vector((0.1, 0.05, 6.8)), 0.8, i_leaf, squash=0.5, subdiv=1)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


# ---------------- Neem (le long des rues, dans les cours) ----------------
def build_neem():
    ob = new_object("veg_neem")
    i_bark = add_material(ob, BARK)
    i_leaf = add_material(ob, NEEM)
    i_leaf2 = add_material(ob, LEAVES)
    bm = bmesh.new()
    trunk = [Vector((0, 0, 0)), Vector((0.05, 0.02, 1.2)), Vector((0.1, 0.05, 2.2))]
    tube(bm, trunk, [0.28, 0.24, 0.2], 8, i_bark)
    for ang in (0.6, 2.7, 4.6):
        d = Vector((math.cos(ang), math.sin(ang), 0))
        b = [trunk[-1], trunk[-1] + d * 0.8 + Vector((0, 0, 1.6)), trunk[-1] + d * 1.3 + Vector((0, 0, 3.2))]
        tube(bm, b, [0.14, 0.09, 0.04], 6, i_bark)
    # houppier ovale, plus haut que large, feuillage fin et serre
    for k in range(16):
        u = random.uniform(0, math.tau)
        v = random.uniform(-0.9, 0.9)
        c = Vector((math.cos(u) * 1.9 * math.sqrt(1 - v * v), math.sin(u) * 1.9 * math.sqrt(1 - v * v), 5.2 + v * 1.7))
        blob(bm, c, random.uniform(0.9, 1.3), i_leaf if k % 4 else i_leaf2, squash=0.85, subdiv=1)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


# ---------------- Buisson ----------------
def build_buisson():
    ob = new_object("veg_buisson")
    i_leaf = add_material(ob, LEAVES2)
    bm = bmesh.new()
    for k in range(4):
        ang = k * 1.7
        blob(bm, Vector((math.cos(ang) * 0.4, math.sin(ang) * 0.4, 0.45)), random.uniform(0.5, 0.75), i_leaf, squash=0.75)
    bm.to_mesh(ob.data)
    bm.free()
    return ob


objs = [build_cocotier(), build_arbre(), build_buisson(), build_badamier(), build_neem()]
for i, ob in enumerate(objs):
    ob.location.x = i * 8  # juste pour la vue dans Blender ; Godot repositionne
    for p in ob.data.polygons:
        p.use_smooth = False
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True)
print("Vegetation :", [(o.name, len(o.data.polygons)) for o in objs])
