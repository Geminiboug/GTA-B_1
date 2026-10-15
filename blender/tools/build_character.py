# GTB : personnages (homme, homme fort, femme, femme ronde, garcon, fille) faits par script, sans asset externe.
# Lancement : blender -b --python blender/tools/build_character.py -- <variante> <sortie.blend> <sortie.glb> [apercu.png]
#
# Corps d'un seul tenant (modificateur Skin + subdivision : epaules, coudes, genoux sans jointure visible) anime par un
# squelette (os nommes comme les anciens pivots : piv_bassin, piv_tronc, piv_tete, piv_epaule_*, piv_coude_*,
# piv_main_*, piv_hanche_*, piv_genou_*, piv_cheville_*). Poids calcules par regions (bras, jambes, tronc, tete)
# avec des zones de fondu aux articulations. Pose de repos en "A" (bras ecartes de 12 degres).
# Tete : crane, pommettes, menton, nez et narines, oreilles, yeux avec paupieres, sourcils, levres.
# Vetements (maillages separes, memes poids que le corps : ils suivent exactement les mouvements) :
#   haut (manches courtes), haut long (manches longues), pantalon, short, chaussures, semelles (sandales),
#   jupe / pagne long / boubou (cones lestes sur le bassin et les cuisses).
# Coiffures : cheveux courts, afro, tresses, chignon, meches longues, foulard noue, casquette.
# Orientation : regarde +Y Blender (= -Z Godot). Pieds a Z = 0. Ne jamais nommer une piece *_col / -col.
import bpy
import bmesh
import math
import sys
from mathutils import Vector, kdtree

args = sys.argv[sys.argv.index("--") + 1:]
VARIANT, OUT_BLEND, OUT_GLB = args[:3]
PREVIEW = args[3] if len(args) > 3 else None

V = {
    "homme": dict(sex="m", h=1.70, g=1.0, sh=1.0, hip=1.0, bust=0.0, belly=0.0, child=False),
    "homme_fort": dict(sex="m", h=1.70, g=1.17, sh=1.05, hip=1.08, bust=0.012, belly=0.07, child=False),
    "femme": dict(sex="f", h=1.59, g=0.95, sh=0.88, hip=1.13, bust=0.038, belly=0.0, child=False),
    "femme_ronde": dict(sex="f", h=1.58, g=1.16, sh=0.93, hip=1.28, bust=0.055, belly=0.045, child=False),
    "garcon": dict(sex="m", h=1.30, g=0.86, sh=0.9, hip=0.95, bust=0.0, belly=0.01, child=True),
    "fille": dict(sex="f", h=1.27, g=0.84, sh=0.88, hip=0.98, bust=0.0, belly=0.0, child=True),
}[VARIANT]
# h = taille reelle du corps (sommet du crane), Benin : hommes ~1,70 m, femmes ~1,59 m (docs/PIPELINE.md).
# Calibration mesuree : la peau (Skin + subdivision) depasse le sommet du squelette de ~2 % (homme) / ~3,5 % (femme).
V["h"] *= {"m": 1.76 / 1.80, "f": 1.65 / 1.71}[V["sex"]] if not V["child"] else 1.0
F = V["sex"] == "f"
K = V["h"] / 1.76                      # echelle verticale du corps
HK = (V["h"] / 1.76) ** 0.45 if V["child"] else (0.95 if F else 1.0)   # tete : proportionnellement plus grosse chez l'enfant
G = V["g"]
A_POSE = math.radians(12.0)

bpy.ops.wm.read_homefile(use_empty=True)
scene = bpy.context.scene


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


MATS = {}


def material(name, srgb, rough=0.8):
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
    MATS[name] = m
    return m


SKIN = material("chr_peau", (0.36, 0.22, 0.15), 0.55)
LIPS = material("chr_levres", (0.26, 0.14, 0.12), 0.45)
EYE_W = material("chr_oeil_blanc", (0.9, 0.88, 0.84), 0.3)
EYE_I = material("chr_oeil_iris", (0.06, 0.04, 0.03), 0.15)
HAIR = material("chr_cheveux", (0.05, 0.04, 0.04), 0.9)
TOP = material("chr_chemise", (0.95, 0.75, 0.10))
PANTS = material("chr_pantalon", (0.18, 0.22, 0.30))
SHOES = material("chr_chaussures", (0.12, 0.10, 0.09), 0.6)
SOLE = material("chr_semelle", (0.1, 0.1, 0.11), 0.7)
CLOTH = material("chr_tissu", (0.8, 0.3, 0.1))
CAP = material("chr_casquette", (0.15, 0.2, 0.45))

# ------------------------------------------------------------------ squelette (positions de reference homme 1,76 m)
J = {}


def jp(name, x, y, z):
    J[name] = Vector((x, y, z))


BASE_M = dict(bz=0.95, hip=0.89, knee=0.46, ankle=0.075, tronc=1.01, sh_z=1.45, sh_x=0.212, tete=1.535, up=0.29, lo=0.25, hip_x=0.095)
BASE_F = dict(bz=0.91, hip=0.85, knee=0.435, ankle=0.072, tronc=0.97, sh_z=1.375, sh_x=0.183, tete=1.46, up=0.27, lo=0.235, hip_x=0.088)
B = dict(BASE_F if F else BASE_M)
if V["child"]:
    # enfant : corps reduit, tete proportionnellement plus grosse (le sommet tombe a la taille voulue)
    kb = (V["h"] - 0.265 * HK) / B["tete"]
    for key in B:
        B[key] *= kb
    B["sh_x"] *= 1.06
    B["hip_x"] *= 0.95
    bk_scale = kb
else:
    kb = V["h"] / (1.65 if F else 1.76)
    for key in ("bz", "hip", "knee", "ankle", "tronc", "sh_z", "tete", "up", "lo"):
        B[key] *= kb
    bk_scale = 1.0
bz, hip_z, knee_z, ankle_z, tronc_z = B["bz"], B["hip"], B["knee"], B["ankle"], B["tronc"]
sh_z, tete_z, up_len, lo_len = B["sh_z"], B["tete"], B["up"], B["lo"]
sh_x = B["sh_x"] * V["sh"] * G ** 0.35
hip_x = B["hip_x"] * V["hip"]

jp("bassin", 0, 0, bz)
jp("tronc", 0, 0, tronc_z)
jp("cou", 0, -0.005, sh_z + 0.03)
jp("tete", 0, -0.005, tete_z)
jp("sommet", 0, 0, tete_z + 0.27 * HK)
for s, sx in (("G", -1), ("D", 1)):
    jp("epaule_" + s, sx * sh_x, 0, sh_z)
    jp("coude_" + s, sx * (sh_x + up_len * math.sin(A_POSE)), 0.0, sh_z - up_len * math.cos(A_POSE))
    jp("poignet_" + s, sx * (sh_x + (up_len + lo_len) * math.sin(A_POSE)), 0.015, sh_z - (up_len + lo_len) * math.cos(A_POSE))
    jp("doigts_" + s, sx * (sh_x + (up_len + lo_len + 0.17 * K ** 0.6) * math.sin(A_POSE)), 0.025,
       sh_z - (up_len + lo_len + 0.17 * K ** 0.6) * math.cos(A_POSE))
    jp("hanche_" + s, sx * hip_x, 0, hip_z)
    jp("genou_" + s, sx * hip_x * 1.02, 0.012, knee_z)
    jp("cheville_" + s, sx * hip_x * 1.02, -0.012, ankle_z)
    jp("orteils_" + s, sx * hip_x * 1.05, 0.16 * K ** 0.8, 0.02)

# ------------------------------------------------------------------ corps (Skin + subdivision)
me = bpy.data.meshes.new("chr_corps")
body = bpy.data.objects.new("chr_corps", me)
scene.collection.objects.link(body)
verts, edges, radii = [], [], []


def node(p, rx, ry):
    verts.append(tuple(p))
    radii.append((rx, ry))
    return len(verts) - 1


SEGS = []   # segments du squelette de peau : (a, b, branche, cote) pour savoir d'ou vient chaque sommet


def chain(ids, label="torse", side=""):
    for a, b in zip(ids, ids[1:]):
        edges.append((a, b))
        SEGS.append((Vector(verts[a]), Vector(verts[b]), label, side))


g, hk, bk = G, V["hip"], bk_scale
pel = node(J["bassin"] + Vector((0, -0.01, -0.045 * bk)), 0.155 * hk * g * bk, 0.112 * g * bk)
waist = node(Vector((0, 0, bz + 0.13 * bk)), (0.122 if F else 0.135) * g * bk, 0.092 * g * bk)
chest_lo = node(Vector((0, 0.003, bz + 0.27 * bk)), (0.14 if F else 0.152) * g * bk, 0.104 * g * bk)
chest = node(Vector((0, 0.0, sh_z - 0.1 * bk)), (0.155 if F else 0.175) * V["sh"] * g ** 0.6 * bk, 0.112 * g * bk)
neck0 = node(Vector((0, -0.006, sh_z + 0.015)), 0.11 * V["sh"] * bk, 0.075 * bk)
neck1 = node(J["tete"] + Vector((0, 0, 0.0)), (0.046 if F else 0.056) * HK, (0.046 if F else 0.054) * HK)
neck2 = node(J["tete"] + Vector((0, 0.002, 0.05 * HK)), (0.044 if F else 0.052) * HK, (0.045 if F else 0.052) * HK)
chain([pel, waist, chest_lo, chest, neck0, neck1, neck2])
TORSO_RX = [(verts[i][2], radii[i][0]) for i in (pel, waist, chest_lo, chest, neck0)]
TORSO_RY = [(verts[i][2], radii[i][1]) for i in (pel, waist, chest_lo, chest, neck0)]
ab = 0.88 if F else 1.0
for s in ("G", "D"):
    S, E, W, D = J["epaule_" + s], J["coude_" + s], J["poignet_" + s], J["doigts_" + s]
    sho = node(S + Vector((0, 0, 0.01)), 0.058 * ab * g ** 0.5 * bk, 0.056 * ab * g ** 0.5 * bk)
    upm = node(S.lerp(E, 0.45), 0.05 * ab * g ** 0.6 * bk, 0.049 * ab * g ** 0.6 * bk)
    elb = node(E, 0.041 * ab * bk, 0.04 * ab * bk)
    ARM_R = [(S.z, 0.058 * ab * g ** 0.5 * bk), (E.z, 0.041 * ab * bk), (W.z, 0.03 * ab * bk)]
    fom = node(E.lerp(W, 0.4), 0.041 * ab * g ** 0.4 * bk, 0.037 * ab * bk)
    wri = node(W, 0.03 * ab * bk, 0.026 * ab * bk)
    palm = node(W.lerp(D, 0.38), 0.019 * ab * bk, 0.044 * ab * bk)
    fing = node(W.lerp(D, 0.75), 0.014 * ab * bk, 0.04 * ab * bk)
    tip = node(D, 0.009 * ab * bk, 0.028 * ab * bk)
    sxs = -1 if s == "G" else 1
    th1 = node(W.lerp(D, 0.3) + Vector((-sxs * 0.012, 0.03, 0.0)), 0.012 * ab * bk, 0.012 * ab * bk)
    th2 = node(W.lerp(D, 0.55) + Vector((-sxs * 0.016, 0.045, 0.0)), 0.009 * ab * bk, 0.009 * ab * bk)
    chain([neck0, sho], "epaule", s)
    chain([sho, upm, elb, fom, wri, palm, fing, tip], "bras", s)
    chain([palm, th1, th2], "bras", s)
    H, Kn, A, T = J["hanche_" + s], J["genou_" + s], J["cheville_" + s], J["orteils_" + s]
    hp = node(H + Vector((0, -0.005, 0.02)), 0.098 * hk * g * bk, 0.105 * g * bk)
    thm = node(H.lerp(Kn, 0.45), 0.082 * g * (1.05 if F else 1.0) * bk, 0.085 * g * bk)
    kn = node(Kn, 0.055 * g ** 0.6 * bk, 0.058 * g ** 0.6 * bk)
    calf = node(Kn.lerp(A, 0.3) + Vector((0, -0.012, 0)), 0.058 * g ** 0.7 * bk, 0.064 * g ** 0.7 * bk)
    shin = node(Kn.lerp(A, 0.72), 0.042 * g ** 0.5 * bk, 0.044 * g ** 0.5 * bk)
    ank = node(A, 0.036 * bk, 0.038 * bk)
    ball = node(A.lerp(T, 0.6) + Vector((0, 0, -0.025)), 0.045 * bk, 0.024 * bk)
    toe = node(T, 0.036 * bk, 0.016 * bk)
    chain([pel, hp], "hanche", s)
    chain([hp, thm, kn, calf, shin, ank, ball, toe], "jambe", s)

me.from_pydata(verts, edges, [])
skin = body.modifiers.new("skin", "SKIN")
skin.use_smooth_shade = True
for i, (rx, ry) in enumerate(radii):
    sv = me.skin_vertices[0].data[i]
    sv.radius = (rx, ry)
    sv.use_root = i == pel
sub = body.modifiers.new("sub", "SUBSURF")
sub.levels = 1
sub.render_levels = 1
bpy.context.view_layer.objects.active = body
body.select_set(True)
bpy.ops.object.modifier_apply(modifier="skin")
bpy.ops.object.modifier_apply(modifier="sub")
me = body.data


def gauss(p, c, r):
    return math.exp(-((p - c).length / r) ** 2)


def shape_offset(p):
    """Deplacement doux des formes (poitrine, fesses, ventre), applique au corps et aux vetements."""
    d = Vector((0, 0, 0))
    if V["bust"] > 0:
        for sx in (-1, 1):
            c = Vector((sx * 0.085 * V["sh"], 0.08, sh_z - 0.13))
            d.y += V["bust"] * gauss(p, c, 0.075) * (1.0 if p.y > 0 else 0.0)
    if F or V["hip"] > 1.05:
        c = Vector((0, -0.09, bz - 0.06))
        d.y -= 0.03 * (V["hip"] - 0.9) * gauss(p, c, 0.13) * (1.0 if p.y < 0 else 0.0)
    if V["belly"] > 0:
        c = Vector((0, 0.1, bz + 0.17 * bk))
        d.y += V["belly"] * gauss(p, c, 0.16) * (1.0 if p.y > 0 else 0.0)
    return d


for v in me.vertices:
    v.co = v.co + shape_offset(v.co)
for poly in me.polygons:
    poly.use_smooth = True
me.materials.append(SKIN)


# ------------------------------------------------------------------ tete
def loft(name, rings, mat, axis="Z", seg=16, caps=(True, True), center=Vector((0, 0, 0))):
    bm = bmesh.new()
    vr = []
    for ring in rings:
        t, rx, rr = ring[:3]
        c1, c2 = (list(ring[3:]) + [0.0, 0.0])[:2]
        row = []
        for i in range(seg):
            a = i / seg * math.tau
            u, w = c1 + rx * math.cos(a), c2 + rr * math.sin(a)
            co = Vector((u, w, t)) if axis == "Z" else Vector((u, t, w))
            row.append(bm.verts.new(co + center))
        vr.append(row)
    for r0, r1 in zip(vr, vr[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    if caps[0]:
        bm.faces.new(list(reversed(vr[0])))
    if caps[1]:
        bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = True
    m = bpy.data.meshes.new(name)
    bm.to_mesh(m)
    bm.free()
    ob = bpy.data.objects.new(name, m)
    scene.collection.objects.link(ob)
    m.materials.append(mat)
    return ob


def blob(name, size, loc, mat, seg=12, rings=8):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])) + Vector(loc)
    for f in bm.faces:
        f.smooth = True
    m = bpy.data.meshes.new(name)
    bm.to_mesh(m)
    bm.free()
    ob = bpy.data.objects.new(name, m)
    scene.collection.objects.link(ob)
    m.materials.append(mat)
    return ob


def shell(name, rings, mat, offset, keep, center, seg=20, bumps=0.0):
    """Coque epousant le crane (cheveux, foulard, casquette), decoupee selon keep(point local)."""
    bm = bmesh.new()
    vr = []
    for ring in rings:
        t, rx, rr = ring[:3]
        c1, c2 = (list(ring[3:]) + [0.0, 0.0])[:2]
        vr.append([bm.verts.new((c1 + rx * math.cos(i / seg * math.tau), c2 + rr * math.sin(i / seg * math.tau), t)) for i in range(seg)])
    for r0, r1 in zip(vr, vr[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    for v in bm.verts:
        n = v.normal.copy()
        o = offset + (bumps * (0.5 + 0.5 * math.sin(v.co.x * 90) * math.sin(v.co.y * 80) * math.sin(v.co.z * 85)) if bumps else 0.0)
        v.co += n * o
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep(f.calc_center_median())], context="FACES")
    for v in bm.verts:
        v.co += center
    for f in bm.faces:
        f.smooth = True
    m = bpy.data.meshes.new(name)
    bm.to_mesh(m)
    bm.free()
    ob = bpy.data.objects.new(name, m)
    scene.collection.objects.link(ob)
    m.materials.append(mat)
    return ob


k = HK
hc = J["tete"]  # base du crane
if F:
    skull = [(0.0, 0.045, 0.05, 0, -0.005), (0.03, 0.058, 0.07, 0, 0.012), (0.06, 0.07, 0.088, 0, 0.014),
             (0.095, 0.08, 0.098, 0, 0.01), (0.13, 0.086, 0.102, 0, 0.005), (0.17, 0.088, 0.103), (0.21, 0.082, 0.096, 0, -0.006),
             (0.245, 0.063, 0.075, 0, -0.01), (0.266, 0.03, 0.036, 0, -0.012)]
else:
    skull = [(0.0, 0.05, 0.055, 0, -0.005), (0.03, 0.068, 0.078, 0, 0.012), (0.06, 0.079, 0.094, 0, 0.015),
             (0.095, 0.087, 0.1, 0, 0.011), (0.13, 0.091, 0.104, 0, 0.005), (0.17, 0.092, 0.105), (0.21, 0.085, 0.096, 0, -0.006),
             (0.245, 0.064, 0.074, 0, -0.01), (0.265, 0.03, 0.035, 0, -0.012)]
sk = [(r[0] * k, r[1] * k, r[2] * k) + tuple(x * k for x in r[3:]) for r in skull]
head_parts = [loft("h_crane", sk, SKIN, seg=20, center=hc)]
fy = 0.099 * k
head_parts.append(loft("h_nez", [(fy - 0.012, 0.015 * k, 0.026 * k, 0, 0.118 * k), (fy + 0.008 * k, 0.019 * k, 0.019 * k, 0, 0.101 * k),
                                 (fy + 0.019 * k, 0.025 * k, 0.013 * k, 0, 0.093 * k), (fy + 0.025 * k, 0.014 * k, 0.008 * k, 0, 0.092 * k)],
                       SKIN, axis="Y", seg=10, center=hc))
for sx in (-1, 1):
    head_parts.append(blob("h_narine", (0.012 * k, 0.012 * k, 0.009 * k), hc + Vector((sx * 0.017 * k, fy + 0.012 * k, 0.091 * k)), SKIN, 8, 6))
    head_parts.append(blob("h_oreille", (0.012 * k, 0.024 * k, 0.034 * k), hc + Vector((sx * 0.088 * k, -0.008 * k, 0.13 * k)), SKIN, 8, 6))
    head_parts.append(blob("h_oeil", (0.0145 * k, 0.007 * k, 0.0078 * k), hc + Vector((sx * 0.034 * k, fy - 0.001, 0.147 * k)), EYE_W, 10, 6))
    head_parts.append(blob("h_iris", (0.0072 * k, 0.004 * k, 0.0072 * k), hc + Vector((sx * 0.034 * k, fy + 0.0045, 0.147 * k)), EYE_I, 8, 6))
    head_parts.append(blob("h_paupiere", (0.0165 * k, 0.0078 * k, 0.0052 * k), hc + Vector((sx * 0.034 * k, fy + 0.0006, 0.1535 * k)), SKIN, 10, 6))
    head_parts.append(blob("h_sourcil", (0.017 * k, 0.005 * k, 0.0035 * k), hc + Vector((sx * 0.036 * k, fy + 0.003, 0.1695 * k)), HAIR, 8, 4))
lip_k = 1.15 if F else 1.0
head_parts.append(blob("h_levre_haut", (0.024 * k, 0.008 * k, 0.0066 * k * lip_k), hc + Vector((0, fy + 0.007 * k, 0.068 * k)), LIPS, 12, 6))
head_parts.append(blob("h_levre_bas", (0.022 * k, 0.009 * k, 0.0076 * k * lip_k), hc + Vector((0, fy + 0.006 * k, 0.057 * k)), LIPS, 12, 6))

# ------------------------------------------------------------------ poids
BONES = ["piv_bassin", "piv_tronc", "piv_tete"] + [f"piv_{n}_{s}" for s in ("G", "D") for n in
                                                    ("epaule", "coude", "main", "hanche", "genou", "cheville")]


def ss(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0))) if e1 != e0 else (1.0 if x >= e1 else 0.0)
    return t * t * (3 - 2 * t)


def interp(table, z):
    """Interpolation lineaire d'une table [(z, valeur)] triee par z croissant."""
    table = sorted(table)
    if z <= table[0][0]:
        return table[0][1]
    for (z0, a), (z1, b) in zip(table, table[1:]):
        if z <= z1:
            return a + (b - a) * (z - z0) / ((z1 - z0) or 1.0)
    return table[-1][1]


def nearest_branch(p):
    best, bd = None, 1e9
    for a, b, label, side in SEGS:
        ab = b - a
        t = max(0.0, min(1.0, (p - a).dot(ab) / (ab.length_squared or 1e-9)))
        d = (a + ab * t - p).length
        if d < bd:
            bd, best = d, (label, side, t)
    return best


def weights_for(p):
    """Poids (dict os -> poids) d'un point du corps au repos, selon la branche du squelette la plus proche."""
    head_t = ss(J["tete"].z - 0.03, J["tete"].z + 0.02, p.z)
    if head_t > 0.99:
        return {"piv_tete": 1.0}
    label, side, t = nearest_branch(p)
    w = {}
    if label == "bras" and p.z < J["epaule_" + side].z - 0.03:
        # dans le volume du torse (bras colle au corps, personne forte) : c'est le flanc, pas le bras
        rx, ry = interp(TORSO_RX, p.z), interp(TORSO_RY, p.z)
        if (p.x / rx) ** 2 + (p.y / ry) ** 2 < 1.12:
            label = "torse"
    if label == "bras":
        S, E, W = J["epaule_" + side], J["coude_" + side], J["poignet_" + side]
        sh_mix = ss(S.z - 0.09 * bk, S.z + 0.02, p.z)          # haut de l'epaule : suit aussi le tronc
        u = 1.0 - ss(E.z - 0.035, E.z + 0.035, p.z)            # 1 sous le coude
        hnd = 1.0 - ss(W.z - 0.03, W.z + 0.02, p.z)            # 1 sous le poignet
        wu = 1 - u
        w["piv_epaule_" + side] = wu * (1 - sh_mix * 0.5)
        w["piv_coude_" + side] = u * (1 - hnd)
        w["piv_main_" + side] = u * hnd
        w["piv_tronc"] = wu * sh_mix * 0.5
        return w
    if label == "epaule":
        k2 = ss(0.25, 1.0, t)
        w["piv_tronc"] = (1.0 - 0.5 * k2) * (1 - head_t)
        w["piv_epaule_" + side] = 0.5 * k2 * (1 - head_t)
        w["piv_tete"] = head_t
        return w
    if label == "jambe":
        Hh, Kn, A = J["hanche_" + side], J["genou_" + side], J["cheville_" + side]
        top = ss(Hh.z - 0.07 * bk, Hh.z + 0.03, p.z)          # haut de la cuisse : suit aussi le bassin
        kk = 1.0 - ss(Kn.z - 0.035, Kn.z + 0.035, p.z)         # 1 sous le genou
        ff = 1.0 - ss(A.z - 0.01, A.z + 0.04, p.z)             # 1 sous la cheville
        w["piv_hanche_" + side] = (1 - kk) * (1 - top * 0.5)
        w["piv_genou_" + side] = kk * (1 - ff)
        w["piv_cheville_" + side] = kk * ff
        w["piv_bassin"] = (1 - kk) * top * 0.5
        return w
    if label == "hanche":
        k2 = ss(0.2, 1.0, t)
        w["piv_bassin"] = 1.0 - 0.6 * k2
        w["piv_hanche_" + side] = 0.6 * k2
        return w
    # tronc : bassin en bas, tronc en haut, tete au cou
    t2 = ss(bz + 0.0, bz + 0.18 * bk, p.z)
    w["piv_bassin"] = (1 - t2) * (1 - head_t)
    w["piv_tronc"] = t2 * (1 - head_t)
    w["piv_tete"] = head_t
    return w


def assign(ob, fixed=None):
    groups = {b: ob.vertex_groups.get(b) or ob.vertex_groups.new(name=b) for b in BONES}
    mw = ob.matrix_world
    for v in ob.data.vertices:
        wd = fixed if fixed else weights_for(mw @ v.co)
        tot = sum(wd.values()) or 1.0
        for b, val in wd.items():
            if val > 1e-4:
                groups[b].add([v.index], val / tot, "REPLACE")


assign(body)
for hp in head_parts:
    assign(hp, {"piv_tete": 1.0})
# la tete fait partie du corps (un seul mesh, plusieurs materiaux)
bpy.ops.object.select_all(action="DESELECT")
for hp in head_parts:
    hp.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "chr_corps"
body.data.name = "chr_corps"


# ------------------------------------------------------------------ vetements derives du corps
def region_of(p):
    w = weights_for(p)
    return max(w, key=w.get)


def derive(name, mat, offset, keep_face, hems=()):
    """Copie des faces du corps choisies par keep_face(centre, os dominant), gonflee de 'offset' (memes poids).
    hems : hauteurs d'ourlet ; les sommets du bord proches d'un ourlet y sont alignes (bord droit, pas en dents de scie)."""
    ob = body.copy()
    ob.data = body.data.copy()
    ob.name = name
    ob.data.name = name
    scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    deform = bm.verts.layers.deform.active
    skin_idx = [i for i, m in enumerate(ob.data.materials) if m == SKIN]
    kill = []
    for f in bm.faces:
        c = f.calc_center_median()
        if f.material_index not in skin_idx or c.z > J["tete"].z + 0.01 or not keep_face(c, region_of(c)):
            kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset
    # ourlets : tout ce qui descend sous la ligne d'ourlet y est ramene (bord net et horizontal)
    for v in bm.verts:
        for hz, xmin in hems:
            if v.co.z < hz and abs(v.co.x) >= xmin:
                v.co.z = hz
    for f in bm.faces:
        f.material_index = 0
        f.smooth = True
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    return ob


ARM = ("piv_epaule", "piv_coude", "piv_main")
LEG = ("piv_hanche", "piv_genou", "piv_cheville")
torso_top = sh_z + 0.01


def is_torso(c, r):
    return r in ("piv_bassin", "piv_tronc") and c.z > bz - 0.05 * bk and c.z < torso_top + 0.04


def tube_rings(bm, rings):
    """rings : liste de listes de points 3D (meme nombre) -> faces entre anneaux successifs."""
    rows = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(rows[0])
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    return rows


def ring_around(center, axis, r1, r2, seg, ref=Vector((1, 0, 0))):
    axis = axis.normalized()
    u = (ref - axis * ref.dot(axis)).normalized()
    v = axis.cross(u)
    return [center + u * (r1 * math.cos(i / seg * math.tau)) + v * (r2 * math.sin(i / seg * math.tau)) for i in range(seg)]


def make_top(name, long_sleeves, pad):
    """Haut (tee-shirt, chemise, haut de boubou) : tube qui suit le torse (formes comprises) et manches qui suivent
    les bras ; ourlets droits. Poids : torse pour le corps du vetement, bras pour les manches."""
    seg = 28
    bm = bmesh.new()
    torso_rings = []
    z0, z1 = bz - 0.05 * bk, sh_z - 0.005
    for i in range(12):
        z = z0 + (z1 - z0) * i / 11
        # anneaux de depart a l'interieur du corps : le point de surface le plus proche est alors celui du torse
        rx = max(interp(TORSO_RX, z), sh_x * 0.8 * ss(sh_z - 0.15 * bk, sh_z, z)) * 0.6
        ry = interp(TORSO_RY, z) * 0.6
        torso_rings.append([Vector((rx * math.cos(k / seg * math.tau), ry * math.sin(k / seg * math.tau), z)) for k in range(seg)])
    # epaules puis encolure (se resserre vers le cou)
    nrx, nry = (0.046 if F else 0.056) * HK, (0.046 if F else 0.054) * HK
    for z, rx, ry in ((sh_z + 0.015 * bk, sh_x * 0.75, interp(TORSO_RY, sh_z) * 0.6),
                      (sh_z + 0.035 * bk, nrx * 1.6, nry * 1.2), (sh_z + 0.055 * bk, nrx * 0.7, nry * 0.7)):
        torso_rings.append([Vector((rx * math.cos(k / seg * math.tau), ry * math.sin(k / seg * math.tau) - 0.005, z)) for k in range(seg)])
    rows = tube_rings(bm, torso_rings)
    torso_verts = set(v for r in rows for v in r)
    sleeves = {}
    for side in ("G", "D"):
        S, E, W = J["epaule_" + side], J["coude_" + side], J["poignet_" + side]
        ax = (E - S).normalized()
        out = Vector((1 if side == "D" else -1, 0, 0))
        ar0 = 0.058 * ab * g ** 0.5 * bk
        pts = [S - out * 0.015, S + ax * 0.02, S + ax * 0.07 * bk, S + ax * 0.14 * bk]
        rad = [ar0 * 0.5, ar0 * 0.5, ar0 * 0.5, ar0 * 0.5]
        if long_sleeves:
            pts = pts[:3] + [S.lerp(E, 0.7), E, E.lerp(W, 0.5), W - (W - E).normalized() * 0.02]
            rad = rad[:3] + [0.046 * ab * bk * 0.5, 0.043 * ab * bk * 0.5, 0.04 * ab * bk * 0.5, 0.034 * ab * bk * 0.5]
        rings = []
        for k in range(len(pts)):
            a = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)])
            rings.append(ring_around(pts[k], a, rad[k], rad[k], 16))
        sleeves[side] = set(v for r in tube_rings(bm, rings) for v in r)
    # normales deja tournees vers l'exterieur par construction (ne pas recalculer : un tube ouvert serait retourne)
    for f in bm.faces:
        f.smooth = True
    m = bpy.data.meshes.new(name)
    bm.to_mesh(m)
    bm.free()
    ob = bpy.data.objects.new(name, m)
    scene.collection.objects.link(ob)
    m.materials.append(TOP)
    # le vetement epouse la surface du corps (epaules, aisselles, poitrine, ventre) : rayon lance depuis l'axe du
    # torse (ou du bras pour les manches) vers l'exterieur, le point se pose sur la premiere surface touchee + pad
    from mathutils.bvhtree import BVHTree
    deps = bpy.context.evaluated_depsgraph_get()
    tree = BVHTree.FromObject(body, deps)
    n_torso_v = len(torso_verts)
    for v in m.vertices:
        p = v.co.copy()
        if v.index < n_torso_v:
            origin = Vector((0.0, p.y * 0.2, p.z))
        else:
            sd = "G" if p.x < 0 else "D"
            S2, E2, W2 = J["epaule_" + sd], J["coude_" + sd], J["poignet_" + sd]
            best = None
            for a2, b2 in ((S2, E2), (E2, W2)):
                ab2 = b2 - a2
                t2 = max(0.0, min(1.0, (p - a2).dot(ab2) / ab2.length_squared))
                q = a2 + ab2 * t2
                if best is None or (q - p).length < (best - p).length:
                    best = q
            origin = best
        d = p - origin
        if d.length < 1e-5:
            continue
        d.normalize()
        hit = tree.ray_cast(origin, d, 1.0)
        if hit[0] is not None:
            v.co = hit[0] + d * pad
    # poids par construction : manches -> bras, reste -> torse (+ epaules qui suivent un peu les bras)
    groups = {b: ob.vertex_groups.new(name=b) for b in BONES}
    n_torso = len(torso_verts)
    for v in m.vertices:
        p = v.co
        if v.index < n_torso:
            t2 = ss(bz + 0.0, bz + 0.18 * bk, p.z)
            wd = {"piv_bassin": 1 - t2, "piv_tronc": t2}
            if p.z > sh_z - 0.06 * bk and abs(p.x) > sh_x * 0.55:
                sd = "G" if p.x < 0 else "D"
                k3 = ss(sh_x * 0.55, sh_x * 0.95, abs(p.x)) * 0.4
                wd = {"piv_tronc": 1 - k3, "piv_epaule_" + sd: k3}
        else:
            sd = "G" if p.x < 0 else "D"
            Ez, Wz, Sz = J["coude_" + sd].z, J["poignet_" + sd].z, J["epaule_" + sd].z
            u = 1.0 - ss(Ez - 0.035, Ez + 0.035, p.z)
            sh_mix = ss(Sz - 0.06 * bk, Sz + 0.03, p.z)
            wd = {"piv_epaule_" + sd: (1 - u) * (1 - 0.5 * sh_mix), "piv_coude_" + sd: u, "piv_tronc": (1 - u) * 0.5 * sh_mix}
        tot = sum(wd.values()) or 1.0
        for bname, val in wd.items():
            if val > 1e-4:
                groups[bname].add([v.index], val / tot, "REPLACE")
    return ob


make_top("chr_haut", False, 0.016)
make_top("chr_haut_long", True, 0.018)
derive("chr_pantalon", PANTS, 0.006, lambda c, r: (r == "piv_bassin" and c.z < bz - 0.02 * bk) or
       (r.startswith(LEG) and c.z > J["cheville_G"].z + 0.035), ((J["cheville_G"].z + 0.035, 0.0),))
derive("chr_short", PANTS, 0.006, lambda c, r: (r == "piv_bassin" and c.z < bz - 0.02 * bk) or
       (r.startswith("piv_hanche") and c.z > J["genou_G"].z + 0.09 * bk), ((J["genou_G"].z + 0.09 * bk, 0.0),))
derive("chr_chaussures", SHOES, 0.012, lambda c, r: r.startswith("piv_cheville") or (r.startswith("piv_genou") and c.z < J["cheville_G"].z + 0.06))


# semelles (sandales) et vetements longs (cones lestes : haut sur le bassin, bas suit un peu les cuisses)
def sole(side):
    A, T = J["cheville_" + side], J["orteils_" + side]
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    L = (T - A).length + 0.09 * bk
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.1 * bk, v.co.y * L, v.co.z * 0.016)) + Vector((A.x, (A.y + T.y) / 2.0 - 0.01, 0.008))
    m = bpy.data.meshes.new("chr_semelle_" + side)
    bm.to_mesh(m)
    bm.free()
    ob = bpy.data.objects.new("chr_semelle_" + side, m)
    scene.collection.objects.link(ob)
    m.materials.append(SOLE)
    assign(ob, {"piv_cheville_" + side: 1.0})
    return ob


sole("G")
sole("D")


def skirt(name, rings, mat):
    ob = loft(name, rings, mat, seg=24, caps=(False, False), center=Vector((0, 0, bz)))
    top_z = bz + rings[0][0]
    hem_z = bz + rings[-1][0]
    groups = {b: ob.vertex_groups.new(name=b) for b in BONES}
    for v in ob.data.vertices:
        p = v.co
        t = ss(top_z, hem_z, p.z) if hem_z < top_z else 0.0
        t = 1.0 - ss(hem_z, top_z, p.z)
        side = "G" if p.x < 0 else "D"
        lat = min(1.0, abs(p.x) / 0.08)
        wl = t * 0.55 * lat
        groups["piv_bassin"].add([v.index], 1.0 - wl, "REPLACE")
        if wl > 0:
            groups["piv_hanche_" + side].add([v.index], wl, "REPLACE")
    return ob


hb = 0.195 * V["hip"] * g * bk
wt = interp(TORSO_RX, bz + 0.1 * bk) + 0.03
skirt("chr_jupe", [(0.1 * bk, wt, wt * 0.72), (0.0, hb, hb * 0.66, 0, -0.008), (-0.12 * bk, hb * 1.08, hb * 0.78),
                   (-0.3 * bk, hb * 1.16, hb * 1.0), (-0.43 * bk, hb * 1.2, hb * 1.08)], CLOTH)
skirt("chr_pagne_long", [(0.1 * bk, wt, wt * 0.72), (0.0, hb, hb * 0.66, 0, -0.008), (-0.12 * bk, hb * 1.08, hb * 0.78),
                         (-0.3 * bk, hb * 1.16, hb * 1.0), (-0.5 * bk, hb * 1.18, hb * 1.1), (bz * -1 + 0.24 * bk, hb * 1.13, hb * 1.08)], CLOTH)
if not F:
    skirt("chr_boubou", [(0.12 * bk, 0.172 * g * bk, 0.115 * g * bk), (0.0, 0.205 * g * bk, 0.14 * g * bk), (-0.18 * bk, 0.25 * g * bk, 0.175 * g * bk),
                         (-0.42 * bk, 0.28 * g * bk, 0.205 * g * bk), (bz * -1 + 0.28 * bk, 0.295 * g * bk, 0.215 * g * bk)], CLOTH)

# ------------------------------------------------------------------ coiffures et couvre-chefs (os de la tete)
hair_objs = []
hair_objs.append(shell("chr_cheveux", sk, HAIR, 0.006 * k, lambda c: c.z > (0.135 + 0.65 * c.y) * k, hc))
hair_objs.append(shell("chr_afro", sk, HAIR, 0.028 * k, lambda c: c.z > (0.12 + 0.6 * c.y) * k, hc, bumps=0.008 * k))
if F:
    hair_objs.append(blob("chr_chignon", (0.055 * k, 0.05 * k, 0.05 * k), hc + Vector((0, -0.085 * k, 0.215 * k)), HAIR))
    for i in range(9):
        a = math.radians(-80 + i * 20)
        x, y = 0.082 * math.sin(a) * k, (-0.08 * math.cos(a) - 0.012) * k
        hair_objs.append(loft(f"chr_tresse_{i}", [(0.17 * k, 0.011 * k, 0.011 * k, x, y), (0.05, 0.011 * k, 0.011 * k, x * 1.07, y * 1.18),
                                                  (-0.07, 0.009 * k, 0.009 * k, x * 1.07, y * 1.28)], HAIR, seg=6, center=hc))
    hair_objs.append(shell("chr_meches", [(-0.07 * k, 0.1 * k, 0.1 * k, 0, -0.03 * k)] + sk[2:], HAIR, 0.012 * k,
                           lambda c: c.z > (0.15 + 0.5 * c.y) * k or (c.y < 0.02 * k and c.z > -0.07 * k), hc))
    hair_objs.append(shell("chr_foulard", sk, CLOTH, 0.018 * k, lambda c: c.z > (0.17 + 0.45 * c.y) * k, hc))
    hair_objs.append(blob("chr_foulard_haut", (0.098 * k, 0.112 * k, 0.07 * k), hc + Vector((0, -0.018 * k, 0.265 * k)), CLOTH, 14, 8))
    hair_objs.append(blob("chr_foulard_noeud", (0.05 * k, 0.03 * k, 0.035 * k), hc + Vector((0, 0.06 * k, 0.29 * k)), CLOTH, 10, 6))
else:
    hair_objs.append(shell("chr_casquette", sk, CAP, 0.012 * k, lambda c: c.z > 0.165 * k + 0.2 * c.y, hc))
    hair_objs.append(loft("chr_casquette_visiere", [(0.075 * k, 0.072 * k, 0.005, 0, 0.17 * k), (0.15 * k, 0.07 * k, 0.005, 0, 0.162 * k),
                                                   (0.17 * k, 0.05 * k, 0.004, 0, 0.158 * k)], CAP, axis="Y", seg=8, center=hc))
for o in hair_objs:
    assign(o, {"piv_tete": 1.0})

# ------------------------------------------------------------------ armature
arm_data = bpy.data.armatures.new("chr_squelette")
arm = bpy.data.objects.new("chr_squelette", arm_data)
scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
eb = arm_data.edit_bones


def bone(name, head, tail, parent=None):
    b = eb.new(name)
    b.head = head
    b.tail = tail
    b.roll = 0.0
    if parent:
        b.parent = eb[parent]
        b.use_connect = False
    return b


bone("piv_bassin", J["bassin"], J["bassin"] + Vector((0, 0, 0.1)))
bone("piv_tronc", J["tronc"], J["cou"], "piv_bassin")
bone("piv_tete", J["tete"], J["sommet"], "piv_tronc")
for s in ("G", "D"):
    bone("piv_epaule_" + s, J["epaule_" + s], J["coude_" + s], "piv_tronc")
    bone("piv_coude_" + s, J["coude_" + s], J["poignet_" + s], "piv_epaule_" + s)
    bone("piv_main_" + s, J["poignet_" + s], J["doigts_" + s], "piv_coude_" + s)
    bone("piv_hanche_" + s, J["hanche_" + s], J["genou_" + s], "piv_bassin")
    bone("piv_genou_" + s, J["genou_" + s], J["cheville_" + s], "piv_hanche_" + s)
    bone("piv_cheville_" + s, J["cheville_" + s], J["orteils_" + s], "piv_genou_" + s)
bpy.ops.object.mode_set(mode="OBJECT")
for ob in list(scene.collection.objects):
    if ob.type == "MESH":
        ob.parent = arm
        mod = ob.modifiers.new("squelette", "ARMATURE")
        mod.object = arm

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_yup=True, export_skins=True,
                          export_animations=False, export_apply=False)
nfaces = sum(len(o.data.polygons) for o in scene.objects if o.type == "MESH")
print("Personnage", VARIANT, ":", len([o for o in scene.objects if o.type == "MESH"]), "maillages,", len(BONES), "os,", nfaces, "faces")

# ------------------------------------------------------------------ apercu
if PREVIEW:
    show = {"chr_corps", "chr_haut", "chr_pantalon", "chr_chaussures", "chr_cheveux"}
    if F:
        show = {"chr_corps", "chr_haut", "chr_pagne_long", "chr_semelle_G", "chr_semelle_D", "chr_foulard", "chr_foulard_haut", "chr_foulard_noeud"}
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = o.name not in show
    MATS["chr_tissu"].diffuse_color = [to_linear(c) for c in (0.85, 0.25, 0.12)] + [1.0]
    w = bpy.data.worlds.new("w")
    w.color = (0.75, 0.8, 0.85)
    scene.world = w
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.show_shadows = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    top = J["sommet"].z
    for name, loc, rot, lens in (("face", (0.0, 3.6, top * 0.52), (90, 0, 180), 50),
                                 ("trois_quart", (2.5, 2.8, top * 0.6), (88, 0, 138), 50),
                                 ("visage", (0.22, 0.9, J["tete"].z + 0.13 * k), (90, 0, 166), 85),
                                 ("buste", (0.9, 1.6, bz + 0.25), (88, 0, 150), 60)):
        c = bpy.data.cameras.new(name)
        c.lens = lens
        o = bpy.data.objects.new(name, c)
        scene.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = [math.radians(a) for a in rot]
        scene.camera = o
        scene.render.filepath = PREVIEW.replace(".png", f"_{name}.png")
        bpy.ops.render.render(write_still=True)
