# GTB : personnages (homme / femme) faits par script, sans asset externe.
# Lancement : blender -b --python blender/tools/build_character.py -- <homme|femme> <sortie.blend> <sortie.glb> [apercu.png]
#
# Pieces rigides arrondies (sections elliptiques lissees : torse, bassin, membres, tete avec nez, oreilles,
# yeux, sourcils, levres, mains avec pouce, pieds et semelles) accrochees a des pivots (Empties) places aux
# articulations. Les animations sont procedurales dans Godot (godot/scripts/character_anim.gd), qui tourne les
# pivots piv_* : memes noms et memes positions de reference pour les deux morphologies.
# Silhouettes differentes : homme (1,76 m, epaules larges, bassin etroit), femme (1,66 m, epaules plus
# etroites, taille marquee, hanches et poitrine, cou plus fin, mains et pieds plus petits).
# Pieces de tenue optionnelles (affichees ou non par godot/scripts/pnj_util.gd) :
#   homme : chemise / tee-shirt (torse + manches), pantalon, boubou (tunique longue + manches larges),
#           casquette, chaussures fermees ou sandales ;
#   femme : haut (torse + manches), pagne court ou long, foulard noue, chignon ou tresses, sandales.
# Orientation : le personnage regarde +Y dans Blender (= -Z, l'avant, dans Godot). Pieds a Z = 0.
# Ne jamais nommer une piece *_col / -col (Godot en ferait une collision).
import bpy
import bmesh
import math
import sys

args = sys.argv[sys.argv.index("--") + 1:]
GENRE, OUT_BLEND, OUT_GLB = args[:3]
PREVIEW = args[3] if len(args) > 3 else None
F = GENRE == "femme"

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
LIPS = material("chr_levres", (0.24, 0.13, 0.11), 0.5)
EYE_W = material("chr_oeil_blanc", (0.92, 0.9, 0.86), 0.3)
EYE_I = material("chr_oeil_iris", (0.06, 0.04, 0.03), 0.2)
HAIR = material("chr_cheveux", (0.05, 0.04, 0.04), 0.9)
SHIRT = material("chr_chemise", (0.95, 0.75, 0.10))
PANTS = material("chr_pantalon", (0.18, 0.22, 0.30))
SHOES = material("chr_chaussures", (0.12, 0.10, 0.09), 0.6)
SOLE = material("chr_semelle", (0.1, 0.1, 0.11), 0.7)
CLOTH = material("chr_tissu", (0.8, 0.3, 0.1))        # pagne / boubou / foulard (teinte et motif wax dans Godot)
CAP = material("chr_casquette", (0.15, 0.2, 0.45))


def pivot(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.04
    scene.collection.objects.link(e)
    if parent:
        e.parent = parent
    e.location = loc
    return e


def _obj(name, bm, mat, parent, loc=(0, 0, 0)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    me.materials.append(mat)
    ob.parent = parent
    ob.location = loc
    return ob


def shell(name, rings, mat, parent, offset, keep, seg=16):
    """Coque epousant une forme (cheveux, foulard, casquette) : la forme des sections est gonflee de 'offset'
    le long des normales, puis on ne garde que les faces ou keep(centre) est vrai (ligne d'implantation)."""
    bm = bmesh.new()
    vr = []
    for ring in rings:
        t, rx, rr = ring[:3]
        c1, c2 = (list(ring[3:]) + [0.0, 0.0])[:2]
        vr.append([bm.verts.new((c1 + rx * math.cos(i / seg * math.tau), c2 + rr * math.sin(i / seg * math.tau), t))
                   for i in range(seg)])
    for r0, r1 in zip(vr, vr[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    bm.faces.new(vr[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep(f.calc_center_median())], context="FACES")
    for f in bm.faces:
        f.smooth = True
    return _obj(name, bm, mat, parent)


def loft(name, rings, mat, parent, axis="Z", seg=14, caps=(True, True), loc=(0, 0, 0)):
    """Volume lisse a partir de sections elliptiques.
    rings : (t, rx, rr, c1, c2) ; axe Z : ellipse dans le plan XY (rx en X, rr en Y, centre (c1, c2)) a Z = t ;
    axe Y : ellipse dans le plan XZ (rx en X, rr en Z, centre (c1, c2)) a Y = t."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vr = []
    for ring in rings:
        t, rx, rr = ring[:3]
        c1, c2 = (list(ring[3:]) + [0.0, 0.0])[:2]
        row = []
        for i in range(seg):
            a = i / seg * math.tau
            u, v = c1 + rx * math.cos(a), c2 + rr * math.sin(a)
            row.append(bm.verts.new((u, v, t) if axis == "Z" else (u, t, v)))
        vr.append(row)
    for r0, r1 in zip(vr, vr[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    capf = []
    if caps[0]:
        capf.append(bm.faces.new(list(reversed(vr[0]))))
    if caps[1]:
        capf.append(bm.faces.new(vr[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = f not in capf
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    me.materials.append(mat)
    ob.parent = parent
    ob.location = loc
    return ob


def blob(name, size, loc, mat, parent, seg=12, rings=8):
    """Ellipsoide (yeux, oreilles, chignon...)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = (v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    me.materials.append(mat)
    ob.parent = parent
    ob.location = loc
    return ob


def box(name, size, loc, mat, parent, bevel=0.004):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = (v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])
    if bevel:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect="EDGES")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    me.materials.append(mat)
    ob.parent = parent
    ob.location = loc
    return ob


def scaled(rings, k, kz=1.0):
    return [(r[0] * kz, r[1] * k, r[2] * k) + tuple(x * k for x in r[3:]) for r in rings]


# ------------------------------------------------------------------ proportions
if F:
    P = dict(bassin=0.91, hanche_x=0.088, hanche_z=-0.06, cuisse=0.415, tibia=0.435, tronc=0.06, epaule_x=0.183,
             epaule_z=0.405, coude=0.27, tete=0.49, bras_k=0.86, jambe_k=0.95, tete_k=0.95, main_k=0.88, pied_k=0.88)
else:
    P = dict(bassin=0.95, hanche_x=0.095, hanche_z=-0.06, cuisse=0.43, tibia=0.46, tronc=0.06, epaule_x=0.212,
             epaule_z=0.44, coude=0.29, tete=0.525, bras_k=1.0, jambe_k=1.0, tete_k=1.0, main_k=1.0, pied_k=1.0)

root = pivot("chr_racine", (0, 0, 0))
hips = pivot("piv_bassin", (0, 0, P["bassin"]), root)
spine = pivot("piv_tronc", (0, 0, P["tronc"]), hips)
head = pivot("piv_tete", (0, 0, P["tete"]), spine)

# ------------------------------------------------------------------ bassin et torse
if F:
    loft("chr_bassin", [(-0.14, 0.185, 0.118, 0, -0.012), (-0.07, 0.19, 0.118, 0, -0.01), (0.0, 0.178, 0.11),
                         (0.06, 0.155, 0.1), (0.1, 0.138, 0.094)], PANTS, hips)
    torso = [(-0.04, 0.138, 0.093), (0.06, 0.128, 0.088), (0.15, 0.14, 0.098), (0.22, 0.155, 0.118, 0, 0.012),
             (0.28, 0.162, 0.128, 0, 0.022), (0.33, 0.165, 0.112, 0, 0.012), (0.38, 0.17, 0.098), (0.42, 0.15, 0.085),
             (0.455, 0.075, 0.062)]
else:
    loft("chr_bassin", [(-0.13, 0.162, 0.104), (-0.06, 0.168, 0.106), (0.02, 0.163, 0.102), (0.1, 0.156, 0.1)], PANTS, hips)
    torso = [(-0.04, 0.155, 0.1), (0.08, 0.158, 0.104), (0.2, 0.172, 0.112), (0.3, 0.192, 0.122, 0, 0.006),
             (0.38, 0.203, 0.118), (0.43, 0.19, 0.105), (0.47, 0.15, 0.09), (0.5, 0.08, 0.066)]
loft("chr_torse", torso, SHIRT, spine)
neck_r = 0.046 if F else 0.056
loft("chr_cou", [(torso[-2][0], neck_r * 1.15, neck_r * 1.1), (P["tete"] + 0.02, neck_r, neck_r * 0.95, 0, -0.005),
                 (P["tete"] + 0.06, neck_r * 0.95, neck_r * 0.9, 0, -0.008)], SKIN, spine)

# ------------------------------------------------------------------ tete
k = P["tete_k"]
if F:
    skull = [(0.0, 0.045, 0.05, 0, -0.005), (0.035, 0.06, 0.072, 0, 0.012), (0.07, 0.074, 0.09, 0, 0.012),
             (0.12, 0.084, 0.1, 0, 0.006), (0.17, 0.087, 0.102), (0.21, 0.081, 0.095, 0, -0.005),
             (0.245, 0.062, 0.074, 0, -0.008), (0.266, 0.03, 0.036, 0, -0.01)]
else:
    skull = [(0.0, 0.05, 0.055, 0, -0.005), (0.035, 0.072, 0.082, 0, 0.012), (0.07, 0.081, 0.096, 0, 0.012),
             (0.12, 0.088, 0.103, 0, 0.005), (0.17, 0.09, 0.104), (0.21, 0.083, 0.095, 0, -0.005),
             (0.245, 0.062, 0.072, 0, -0.008), (0.265, 0.03, 0.035, 0, -0.01)]
loft("chr_tete", scaled(skull, k, k), SKIN, head, seg=16)
fy = 0.098 * k  # avant du visage
loft("chr_nez", [(fy - 0.012, 0.015 * k, 0.026 * k, 0, 0.116 * k), (fy + 0.008 * k, 0.019 * k, 0.019 * k, 0, 0.1 * k),
                 (fy + 0.018 * k, 0.024 * k, 0.013 * k, 0, 0.093 * k), (fy + 0.024 * k, 0.014 * k, 0.008 * k, 0, 0.092 * k)],
     SKIN, head, axis="Y", seg=10)
for side, sx in (("G", -1), ("D", 1)):
    blob(f"chr_narine_{side}", (0.011 * k, 0.012 * k, 0.009 * k), (sx * 0.016 * k, fy + 0.012 * k, 0.091 * k), SKIN, head, 8, 6)
    blob(f"chr_oreille_{side}", (0.012 * k, 0.024 * k, 0.034 * k), (sx * 0.086 * k, -0.008 * k, 0.13 * k), SKIN, head, 8, 6)
    blob(f"chr_oeil_{side}", (0.0145 * k, 0.007 * k, 0.0075 * k), (sx * 0.034 * k, fy - 0.001, 0.147 * k), EYE_W, head, 10, 6)
    blob(f"chr_iris_{side}", (0.0072 * k, 0.004 * k, 0.0072 * k), (sx * 0.034 * k, fy + 0.0045, 0.147 * k), EYE_I, head, 8, 6)
    # paupiere superieure : regard calme, pas de "grands yeux ronds"
    blob(f"chr_paupiere_{side}", (0.016 * k, 0.0075 * k, 0.005 * k), (sx * 0.034 * k, fy + 0.0005, 0.153 * k), SKIN, head, 10, 6)
    box(f"chr_sourcil_{side}", (0.032 * k, 0.008, 0.0055), (sx * 0.036 * k, fy + 0.002, 0.169 * k), HAIR, head, 0.002)
lip_k = 1.15 if F else 1.0
blob("chr_levre_haut", (0.024 * k, 0.008 * k, 0.0065 * k * lip_k), (0, fy + 0.007 * k, 0.068 * k), LIPS, head, 12, 6)
blob("chr_levre_bas", (0.022 * k, 0.009 * k, 0.0075 * k * lip_k), (0, fy + 0.006 * k, 0.057 * k), LIPS, head, 12, 6)
# cheveux : coque sur le crane, ligne d'implantation haute sur le front, basse sur la nuque, au-dessus des oreilles
sk = scaled(skull, k, k)
shell("chr_cheveux", sk, HAIR, head, 0.006, lambda c: c.z > (0.135 + 0.65 * c.y) * k)
if F:
    # chignon, tresses, foulard noue (au choix dans Godot)
    blob("chr_chignon", (0.055, 0.05, 0.05), (0, -0.085 * k, 0.215 * k), HAIR, head)
    for i in range(7):
        a = math.radians(-70 + i * 23)
        x, y = 0.08 * math.sin(a) * k, (-0.078 * math.cos(a) - 0.012) * k
        loft(f"chr_tresse_{i}", [(0.17 * k, 0.011, 0.011, x, y), (0.06, 0.011, 0.011, x * 1.06, y * 1.15),
                                 (-0.05, 0.009, 0.009, x * 1.06, y * 1.25)], HAIR, head, seg=6)
    shell("chr_foulard", sk, CLOTH, head, 0.018, lambda c: c.z > (0.17 + 0.45 * c.y) * k)
    blob("chr_foulard_haut", (0.098, 0.112, 0.07), (0, -0.018, 0.265 * k), CLOTH, head, 14, 8)
    blob("chr_foulard_noeud", (0.05, 0.03, 0.035), (0, 0.06 * k, 0.29 * k), CLOTH, head, 10, 6)
else:
    shell("chr_casquette", sk, CAP, head, 0.011, lambda c: c.z > 0.165 + 0.2 * c.y)
    loft("chr_casquette_visiere", [(0.075, 0.072, 0.005, 0, 0.17), (0.15, 0.07, 0.005, 0, 0.162), (0.17, 0.05, 0.004, 0, 0.158)],
         CAP, head, axis="Y", seg=8)

# ------------------------------------------------------------------ bras
bk = P["bras_k"]
for side, sx in (("G", -1), ("D", 1)):
    sh = pivot(f"piv_epaule_{side}", (sx * P["epaule_x"], 0, P["epaule_z"]), spine)
    up = P["coude"]
    loft(f"chr_bras_{side}", [(0.02, 0.052 * bk, 0.05 * bk), (-0.1, 0.047 * bk, 0.045 * bk), (-0.2, 0.042 * bk, 0.04 * bk),
                              (-up, 0.037 * bk, 0.036 * bk)], SKIN, sh)
    # manche courte : arrondie a l'epaule (se fond dans le torse), legerement evasee en bas
    loft(f"chr_manche_{side}", [(0.072, 0.02 * bk, 0.02 * bk, -sx * 0.012), (0.06, 0.045 * bk, 0.045 * bk, -sx * 0.008),
                                (0.03, 0.06 * bk, 0.058 * bk, -sx * 0.003), (-0.04, 0.06 * bk, 0.057 * bk),
                                (-0.13, 0.058 * bk, 0.055 * bk)], SHIRT, sh)
    if not F:
        # manche large du boubou (jusqu'au coude)
        loft(f"chr_manche_large_{side}", [(0.04, 0.07, 0.07), (-0.12, 0.085, 0.085), (-0.27, 0.105, 0.1)], CLOTH, sh,
             caps=(True, False))
    el = pivot(f"piv_coude_{side}", (0, 0, -up), sh)
    loft(f"chr_avantbras_{side}", [(0.025, 0.039 * bk, 0.037 * bk), (-0.08, 0.04 * bk, 0.036 * bk), (-0.23 * bk, 0.029 * bk, 0.025 * bk)],
         SKIN, el)
    mk = P["main_k"]
    w0 = -0.235 * bk
    loft(f"chr_main_{side}", [(w0, 0.017 * mk, 0.03 * mk), (w0 - 0.03 * mk, 0.02 * mk, 0.045 * mk), (w0 - 0.085 * mk, 0.016 * mk, 0.043 * mk),
                              (w0 - 0.15 * mk, 0.012 * mk, 0.036 * mk), (w0 - 0.17 * mk, 0.007 * mk, 0.02 * mk)], SKIN, el, seg=10)
    loft(f"chr_pouce_{side}", [(w0 - 0.02 * mk, 0.011 * mk, 0.011 * mk, -sx * 0.006, 0.035 * mk),
                               (w0 - 0.06 * mk, 0.009 * mk, 0.009 * mk, -sx * 0.012, 0.05 * mk),
                               (w0 - 0.085 * mk, 0.006 * mk, 0.006 * mk, -sx * 0.014, 0.052 * mk)], SKIN, el, seg=8)

# ------------------------------------------------------------------ jambes
jk = P["jambe_k"]
for side, sx in (("G", -1), ("D", 1)):
    hp = pivot(f"piv_hanche_{side}", (sx * P["hanche_x"], 0, P["hanche_z"]), hips)
    th = P["cuisse"]
    thigh = [(0.05, 0.09 * jk, 0.09 * jk), (-0.05, 0.088 * jk, 0.088 * jk), (-0.2, 0.075 * jk, 0.076 * jk),
             (-0.36 * th / 0.43, 0.06 * jk, 0.062 * jk), (-th, 0.055 * jk, 0.058 * jk)]
    loft(f"chr_cuisse_{side}", thigh, PANTS, hp)
    kn = pivot(f"piv_genou_{side}", (0, 0, -th), hp)
    tb = P["tibia"]
    shin = [(0.025, 0.056 * jk, 0.058 * jk), (-0.1, 0.059 * jk, 0.064 * jk, 0, -0.008), (-0.25, 0.049 * jk, 0.052 * jk),
            (-(tb - 0.075), 0.039 * jk, 0.041 * jk), (-(tb - 0.055), 0.037 * jk, 0.039 * jk)]
    loft(f"chr_tibia_{side}", shin, PANTS, kn)
    # pied nu (visible avec des sandales) + semelle ; chaussure fermee par-dessus pour l'homme
    pk = P["pied_k"]
    zc = -(tb - 0.035)
    foot = [(-0.05 * pk, 0.032 * pk, 0.03, 0, zc + 0.008), (0.0, 0.042 * pk, 0.034, 0, zc + 0.004), (0.07 * pk, 0.045 * pk, 0.024, 0, zc - 0.006),
            (0.14 * pk, 0.04 * pk, 0.014, 0, zc - 0.014), (0.165 * pk, 0.026 * pk, 0.01, 0, zc - 0.018)]
    loft(f"chr_pied_{side}", foot, SKIN, kn, axis="Y", seg=10)
    box(f"chr_semelle_{side}", (0.1 * pk, 0.255 * pk, 0.016), (0, 0.055 * pk, -tb + 0.008), SOLE, kn, 0.005)
    if not F:
        loft(f"chr_chaussure_{side}", [(-0.062, 0.042, 0.04, 0, zc + 0.006), (0.0, 0.05, 0.042, 0, zc + 0.002),
                                       (0.08, 0.052, 0.032, 0, zc - 0.006), (0.15, 0.046, 0.022, 0, zc - 0.012),
                                       (0.175, 0.03, 0.014, 0, zc - 0.016)], SHOES, kn, axis="Y", seg=12)

# ------------------------------------------------------------------ vetements longs
if F:
    loft("chr_jupe", [(0.1, 0.142, 0.098), (0.0, 0.195, 0.125, 0, -0.008), (-0.12, 0.215, 0.15, 0, -0.005),
                      (-0.3, 0.232, 0.2), (-0.43, 0.24, 0.215)], CLOTH, hips, seg=18)
    loft("chr_pagne_long", [(0.1, 0.142, 0.098), (0.0, 0.195, 0.125, 0, -0.008), (-0.12, 0.215, 0.15, 0, -0.005),
                            (-0.3, 0.232, 0.2), (-0.48, 0.235, 0.22), (-0.66, 0.225, 0.215)], CLOTH, hips, seg=18)
else:
    loft("chr_boubou", [(0.13, 0.168, 0.112), (0.0, 0.2, 0.135), (-0.18, 0.245, 0.17), (-0.42, 0.275, 0.2),
                        (-0.62, 0.29, 0.215)], CLOTH, hips, seg=18)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True)
print("Personnage", GENRE, ":", len([o for o in bpy.data.objects if o.type == "MESH"]), "pieces,",
      len([o for o in bpy.data.objects if o.type == "EMPTY"]), "pivots,",
      sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH"), "faces")

# ------------------------------------------------------------------ apercu (tenue type)
if PREVIEW:
    hide = ["chr_casquette", "chr_casquette_visiere", "chr_boubou", "chr_manche_large", "chr_chaussure", "chr_jupe",
            "chr_chignon", "chr_tresse", "chr_cheveux"] if F else ["chr_boubou", "chr_manche_large", "chr_casquette"]
    for o in bpy.data.objects:
        if o.type == "MESH" and any(o.name.startswith(h) for h in hide):
            o.hide_render = True
        if F and o.type == "MESH" and (o.name.startswith("chr_tibia") or o.name.startswith("chr_cuisse")):
            o.data.materials[0] = SKIN
        if o.type == "EMPTY" and o.name.startswith("piv_epaule"):
            o.rotation_euler[1] = math.radians(8 if o.name.endswith("D") else -8)
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
    for name, loc, rot in (("face", (0.0, 3.4, 0.9), (88, 0, 180)), ("trois_quart", (2.4, 2.6, 1.05), (86, 0, 137)),
                           ("visage", (0.25, 0.85, 1.62), (88, 0, 163))):
        c = bpy.data.cameras.new(name)
        c.lens = 50 if name != "visage" else 85
        o = bpy.data.objects.new(name, c)
        scene.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = [math.radians(a) for a in rot]
        scene.camera = o
        scene.render.filepath = PREVIEW.replace(".png", f"_{name}.png")
        bpy.ops.render.render(write_still=True)
