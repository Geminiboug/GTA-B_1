# GTB : vehicules conduisibles faits par script (aucune marque, aucun logo) : berline compacte d'occasion, 4x4,
# minibus (type "tokpa-tokpa" de Cotonou). Un .glb par vehicule, avec roues et pivots separes pour la conduite.
# Lancement : blender -b --python blender/tools/build_vehicles.py -- <dossier_blend> <dossier_glb> [dossier_apercus]
#
# Carrosserie d'un seul tenant : une cage de sections transversales (bas de caisse, flanc bombe, ceinture, vitres
# rentrees, toit) lissee par subdivision, passages de roue decoupes (booleen), puis pare-chocs, optiques, calandre,
# retroviseurs, poignees, essuie-glaces, interieur (sieges avec appui-tete, planche de bord, volant) et roues a pneus
# profiles et jantes a rayons. Dimensions d'apres les vehicules les plus courants a Cotonou (berline compacte des
# annees 2000, 4x4 type tout-terrain, minibus a toit haut), sans en reproduire aucun.
#
# Repere : avant vers +Y Blender (= -Z Godot), origine au sol au milieu de l'empattement, conduite a gauche
# (on roule a droite au Benin). Pivots : piv_direction_avg / avd (braquage, autour de Z) > piv_roue_* (rotation des
# roues, autour de X) ; piv_roue_arg / ard ; pt_conducteur (bassin du conducteur assis) ; pt_sortie (cote gauche).
# Materiaux (noms lus par Godot) : mat_carrosserie (teinte par vehicule), mat_lampe (phares, allumes la nuit),
# mat_feu_arriere (rouge, plus vif au freinage), mat_verre_auto (vitres teintees transparentes), mat_pneu, mat_jante,
# mat_plastique_noir, mat_interieur, mat_plaque, mat_chrome.
import bpy
import bmesh
import math
import os
import sys

args = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND_DIR, OUT_GLB_DIR = args[:2]
PREVIEW_DIR = args[2] if len(args) > 2 else None


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def reset():
    bpy.ops.wm.read_homefile(use_empty=True)


def mat(name, srgb, rough=0.6, metal=0.0, alpha=1.0, emit=None):
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
        if hasattr(m, "blend_method"):
            m.blend_method = "BLEND"
    if emit:
        bsdf.inputs["Emission Color"].default_value = [to_linear(c) for c in emit] + [1.0]
        bsdf.inputs["Emission Strength"].default_value = 0.6
    m.diffuse_color = rgba[:3] + [alpha]
    return m


def coat(m, weight=0.5, rough=0.18):
    """Vernis de carrosserie (exporte en KHR_materials_clearcoat, lu par Godot : reflets nets sur la peinture)."""
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = weight
        bsdf.inputs["Coat Roughness"].default_value = rough
    return m


def mats():
    return {
        "body": coat(mat("mat_carrosserie", (0.92, 0.92, 0.9), 0.32, 0.18)),
        "glass": mat("mat_verre_auto", (0.06, 0.08, 0.1), 0.04, 0.0, alpha=0.55),
        "lamp": mat("mat_lampe", (0.95, 0.95, 0.9), 0.08),
        "tail": mat("mat_feu_arriere", (0.62, 0.04, 0.04), 0.15),
        "orange": mat("mat_clignotant", (0.95, 0.5, 0.05), 0.15),
        "tire": mat("mat_pneu", (0.055, 0.055, 0.06), 0.92),
        "rim": mat("mat_jante", (0.66, 0.67, 0.69), 0.3, 0.85),
        "black": mat("mat_plastique_noir", (0.06, 0.06, 0.065), 0.7),
        "inside": mat("mat_interieur", (0.15, 0.13, 0.12), 0.9),
        "seat": mat("mat_siege", (0.22, 0.2, 0.18), 0.95),
        "plate": mat("mat_plaque", (0.93, 0.93, 0.9), 0.5),
        "chrome": mat("mat_chrome", (0.8, 0.8, 0.82), 0.15, 1.0),
        "disc": mat("mat_disque", (0.42, 0.41, 0.4), 0.45, 0.9),
        "lens": mat("mat_glace_phare", (0.85, 0.88, 0.9), 0.02, 0.0, alpha=0.25),
        "mirror": mat("mat_miroir", (0.75, 0.78, 0.8), 0.03, 1.0),
        "rack": mat("mat_galerie", (0.2, 0.2, 0.22), 0.6, 0.6),
        "cargo": mat("mat_bache", (0.25, 0.35, 0.55), 0.9),
        "sac": mat("mat_sac", (0.55, 0.45, 0.3), 0.95),
    }


class Mesh:
    """Accumule des faces (avec materiau) dans un bmesh, puis cree l'objet."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def k(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def face(self, vs, m, smooth=False):
        f = self.bm.faces.new(vs)
        f.material_index = self.k(m)
        f.smooth = smooth
        return f

    def box(self, m, c, s, rz=0.0, rx=0.0, ry=0.0, smooth=False):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        vs = []
        for z in (-hz, hz):
            for y in (-hy, hy):
                for x in (-hx, hx):
                    vs.append(self.bm.verts.new(rot((x, y, z), rx, ry, rz, c)))
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            self.face([vs[i] for i in f], m, smooth)

    def lathe_x(self, m, c, prof, seg=24, smooth=True):
        """Solide de revolution d'axe X. prof : [(x, rayon)] du flanc exterieur au flanc interieur."""
        rings = []
        for x, r in prof:
            rings.append([self.bm.verts.new((c[0] + x, c[1] + r * math.cos(i / seg * math.tau), c[2] + r * math.sin(i / seg * math.tau)))
                          for i in range(seg)])
        for a in range(len(rings) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                self.face((rings[a][i], rings[a][j], rings[a + 1][j], rings[a + 1][i]), m, smooth)
        return rings

    def lathe_y(self, m, c, prof, seg=16, cap=True):
        """Solide de revolution d'axe Y (optiques). prof : [(y, rayon)] de l'arriere vers l'avant."""
        rings = [[self.bm.verts.new((c[0] + r * math.cos(i / seg * math.tau), c[1] + y, c[2] + r * math.sin(i / seg * math.tau)))
                  for i in range(seg)] for y, r in prof]
        for a in range(len(rings) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                self.face((rings[a][i], rings[a][j], rings[a + 1][j], rings[a + 1][i]), m, True)
        if cap:
            self.face(rings[-1] if prof[-1][0] > prof[0][0] else rings[-1][::-1], m, True)

    def disc_x(self, m, c, r, seg=24, flip=False):
        vs = [self.bm.verts.new((c[0], c[1] + r * math.cos(i / seg * math.tau), c[2] + r * math.sin(i / seg * math.tau))) for i in range(seg)]
        self.face(vs[::-1] if flip else vs, m)

    def torus_x(self, m, c, R, r, seg=20, seg2=6, tilt=0.0):
        """Tore d'axe X incline de tilt autour de X (volant)."""
        rings = []
        for i in range(seg):
            a = i / seg * math.tau
            ring = []
            for j in range(seg2):
                b = j / seg2 * math.tau
                p = (r * math.sin(b), (R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a))
                ring.append(self.bm.verts.new(rot(p, tilt, 0, 0, c)))
            rings.append(ring)
        for i in range(seg):
            for j in range(seg2):
                self.face((rings[i][j], rings[(i + 1) % seg][j], rings[(i + 1) % seg][(j + 1) % seg2], rings[i][(j + 1) % seg2]), m, True)

    def obj(self, parent=None, loc=(0, 0, 0)):
        bmesh.ops.recalc_face_normals(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = parent
        ob.location = loc
        return ob


def rot(p, rx, ry, rz, c=(0, 0, 0)):
    x, y, z = p
    y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
    x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
    x, y = x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
    return (c[0] + x, c[1] + y, c[2] + z)


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.2
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    return e


def modifier(ob, kind, **kw):
    md = ob.modifiers.new(kind.lower(), kind)
    for k, v in kw.items():
        setattr(md, k, v)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier=md.name)


def bevel(ob, width=0.012, seg=2):
    modifier(ob, "BEVEL", width=width, segments=seg, limit_method="ANGLE")
    for p in ob.data.polygons:
        p.use_smooth = True
    if hasattr(ob.data, "set_sharp_from_angle"):
        ob.data.set_sharp_from_angle(angle=math.radians(40))


# ------------------------------------------------------------------ carrosserie
# Demi-section (cote droit, du dessous au toit). Rangees de faces entre deux points :
# 0 dessous, 1 bas de caisse, 2 bas de porte, 3 haut de porte, 4 epaule, 5 vitre laterale, 6 montant / gouttiere, 7 toit.
ROW_UNDER, ROW_SIDE_WIN, ROW_GUTTER, ROW_TOP = 0, 5, 6, 7


def half_section(st):
    y, zb, belt, roof, hw, rw = st["y"], st["zb"], st["belt"], st["roof"], st["hw"], st["rw"]
    cab = roof - belt > 0.12
    shoulder = hw * 0.965
    p = [(0.0, zb + 0.02),
         (hw * 0.86, zb),
         (hw * 0.985, zb + 0.09),
         (hw, zb + (belt - zb) * 0.5),
         (shoulder, belt - 0.03),
         (rw + (shoulder - rw) * (0.72 if cab else 0.55), belt + 0.015),
         (rw + 0.015 if cab else rw + (shoulder - rw) * 0.3, roof - 0.07 if cab else belt + 0.03),
         (rw - 0.1 if cab else rw * 0.8, roof - 0.005 if cab else roof),
         (0.0, roof + (0.02 if cab else 0.0))]
    return p


def body_shell(name, M, stations):
    """Cage de la carrosserie, lissee par subdivision. Chaque station : dict y, zb, belt, roof, hw, rw, et pour le
    troncon vers la station suivante : win (vitre laterale), top ('glass' pare-brise / lunette, sinon toit)."""
    me = Mesh(name)
    rings = []
    for st in stations:
        hp = half_section(st)
        full = hp + [(-x, z) for x, z in reversed(hp[1:-1])]
        rings.append([me.bm.verts.new((x, st["y"], z)) for x, z in full])
    n = len(rings[0])
    half = len(hp) - 1   # 8 rangees par cote
    for a in range(len(rings) - 1):
        st = stations[a]
        for j in range(n):
            row = j if j < half else (2 * half - 1 - j)
            m = M["body"]
            if row == ROW_UNDER:
                m = M["black"]
            elif row == ROW_SIDE_WIN and st.get("win"):
                m = M["glass"]
            elif row == ROW_TOP and st.get("top") == "glass":
                m = M["glass"]
            me.face((rings[a][j], rings[a][(j + 1) % n], rings[a + 1][(j + 1) % n], rings[a + 1][j]), m, True)
    me.face(rings[0], M["body"], True)
    me.face(rings[-1][::-1], M["body"], True)
    # plis vifs gardes par la subdivision : epaule, appui de vitre, gouttiere, bas de caisse ; montants des vitres
    cl = me.bm.edges.layers.float.get("crease_edge") or me.bm.edges.layers.float.new("crease_edge")
    crease_rows = {2: 0.55, 4: 0.75, 5: 0.9, 6: 0.85}
    for a in range(len(rings) - 1):
        for j in range(n):
            row = j if j <= half else (2 * half - j)
            if row in crease_rows:
                e = me.bm.edges.get((rings[a][j], rings[a + 1][j]))
                if e:
                    e[cl] = crease_rows[row]
    for a in range(1, len(rings) - 1):
        before, after = stations[a - 1], stations[a]
        if bool(before.get("win")) != bool(after.get("win")) or before.get("top") != after.get("top"):
            for j in range(n):
                row = j if j < half else (2 * half - 1 - j)
                if row >= ROW_SIDE_WIN:
                    e = me.bm.edges.get((rings[a][j], rings[a][(j + 1) % n]))
                    if e:
                        e[cl] = 0.8
    ob = me.obj()
    modifier(ob, "SUBSURF", levels=2, render_levels=2)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def cut_arches(ob, wheels, r, W):
    """Passages de roue : decoupe cylindrique (axe X) au droit de chaque essieu."""
    for (y, zc) in wheels:
        bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=r + 0.075, depth=W + 0.6, location=(0, y, zc), rotation=(0, math.pi / 2, 0))
        cy = bpy.context.active_object
        md = ob.modifiers.new("arche", "BOOLEAN")
        md.operation = "DIFFERENCE"
        md.object = cy
        if hasattr(md, "solver"):
            md.solver = "EXACT"
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=md.name)
        bpy.data.objects.remove(cy, do_unlink=True)


def cut_bed(ob, M, y0, y1, hw, floor_z):
    """Plateau ouvert du pick-up : on evide le dessus de la caisse arriere (parois de 5 cm, plancher a floor_z) ;
    les faces de la decoupe prennent le revetement noir du plateau."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, (y0 + y1) / 2, floor_z + 0.6))
    cb = bpy.context.active_object
    cb.scale = (2 * (hw - 0.05), y1 - y0, 1.2)
    cb.data.materials.append(M["black"])
    bpy.context.view_layer.objects.active = cb
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    md = ob.modifiers.new("plateau", "BOOLEAN")
    md.operation = "DIFFERENCE"
    md.object = cb
    if hasattr(md, "solver"):
        md.solver = "EXACT"
    if hasattr(md, "material_mode"):
        md.material_mode = "TRANSFER"
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.data.objects.remove(cb, do_unlink=True)


def sedan_stations(sp):
    return sp["stations"]


def wheel(M, name, piv, r, w, side, spokes=5):
    m = Mesh(name)
    s = side
    # pneu : flanc arrondi, bande de roulement legerement bombee
    prof = [(s * w * 0.5, r * 0.66), (s * w * 0.53, r * 0.8), (s * w * 0.5, r * 0.94), (s * w * 0.4, r * 0.995), (s * w * 0.15, r),
            (-s * w * 0.15, r), (-s * w * 0.4, r * 0.995), (-s * w * 0.5, r * 0.94), (-s * w * 0.53, r * 0.8), (-s * w * 0.5, r * 0.66)]
    m.lathe_x(M["tire"], (0, 0, 0), prof, 28)
    # jante : cuvette, rebord, moyeu, rayons
    m.lathe_x(M["rim"], (0, 0, 0), [(s * w * 0.46, r * 0.67), (s * w * 0.4, r * 0.63), (s * w * 0.1, r * 0.6), (-s * w * 0.4, r * 0.62)], 24)
    m.disc_x(M["black"], (-s * w * 0.1, 0, 0), r * 0.6, 24, flip=s > 0)
    m.lathe_x(M["chrome"], (0, 0, 0), [(s * w * 0.2, r * 0.2), (s * w * 0.4, r * 0.17), (s * w * 0.44, r * 0.1), (s * w * 0.45, 0.001)], 12)
    for i in range(spokes):
        a = i / spokes * math.tau
        m.box(M["rim"], (s * w * 0.33, math.cos(a) * r * 0.39, math.sin(a) * r * 0.39), (0.04, 0.07, r * 0.42), rx=a + math.pi / 2)
        m.box(M["rim"], (s * w * 0.3, math.cos(a + 0.3) * r * 0.42, math.sin(a + 0.3) * r * 0.42), (0.03, 0.035, r * 0.36), rx=a + 0.3 + math.pi / 2)
    # disque de frein ventile derriere les branches, ecrous de roue
    m.lathe_x(M["disc"], (0, 0, 0), [(-s * w * 0.05, r * 0.2), (-s * w * 0.05, r * 0.52), (-s * w * 0.2, r * 0.52), (-s * w * 0.2, r * 0.2)], 24)
    for i in range(4):
        a = i / 4 * math.tau + 0.4
        m.lathe_x(M["chrome"], (s * w * 0.4, math.cos(a) * r * 0.13, math.sin(a) * r * 0.13), [(0.0, 0.012), (s * 0.02, 0.012), (s * 0.025, 0.0)], 6)
    ob = m.obj(piv)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def badge(me, M, c, r, front=True):
    """Ecusson parodique (marque inventee, docs/LEGAL.md 6 bis) : ovale chrome horizontal et une vague au milieu."""
    d = 1 if front else -1
    n = 20
    for i in range(n):
        a = i / n * math.tau
        me.box(M["chrome"], (c[0] + math.cos(a) * r * 1.45, c[1], c[2] + math.sin(a) * r), (r * 0.5, 0.012, r * 0.16),
               ry=-a + math.pi / 2)
    for i in range(7):
        t = i / 6
        x = (t - 0.5) * r * 2.2
        me.box(M["chrome"], (c[0] + x, c[1] + d * 0.003, c[2] + math.sin(t * math.tau) * r * 0.32), (r * 0.42, 0.012, r * 0.14),
               ry=-math.cos(t * math.tau) * 0.6)


def lettrage(parent, M, texte, loc, h):
    """Nom en relief chrome (texte Blender converti en maillage), sur la face arriere (regarde -Y)."""
    cu = bpy.data.curves.new("txt_" + texte, "FONT")
    cu.body = texte
    cu.size = h
    cu.extrude = 0.002
    cu.align_x = "CENTER"
    ob = bpy.data.objects.new("txt_" + texte, cu)
    bpy.context.scene.collection.objects.link(ob)
    ob.rotation_euler = (math.pi / 2, 0, 0)
    ob.location = loc
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(ob, do_unlink=True)
    me.materials.clear()
    me.materials.append(M["chrome"])
    mo = bpy.data.objects.new("lettrage_" + texte, me)
    bpy.context.scene.collection.objects.link(mo)
    mo.rotation_euler = (math.pi / 2, 0, 0)
    mo.location = loc
    mo.parent = parent
    return mo


def seat(me, M, x, y, z, w, front=True):
    """Siege : assise inclinee, dossier, appui-tete (avant)."""
    me.box(M["seat"], (x, y, z), (w, 0.5, 0.13), rx=0.06)
    me.box(M["seat"], (x, y - 0.27, z + 0.34), (w, 0.13, 0.62), rx=-0.2)
    if front:
        me.box(M["seat"], (x, y - 0.34, z + 0.74), (w * 0.55, 0.1, 0.18), rx=-0.2)


def vehicle(name, sp):
    reset()
    M = mats()
    root = empty(name, (0, 0, 0))
    L, W, wb, r = sp["L"], sp["W"], sp["wb"], sp["r"]
    hw = W / 2
    st = sp["stations"]
    shell = body_shell(name + "_caisse", M, st)
    cut_arches(shell, [(wb / 2, r), (-wb / 2, r)], r, W)
    if sp.get("bed"):
        cut_bed(shell, M, sp["bed"][0], sp["bed"][1], hw, sp["bed"][2])
    shell.parent = root

    det = Mesh(name + "_details")
    yf = st[-1]["y"]
    yr = st[0]["y"]

    def belt_at(y):
        for a, b in zip(st, st[1:]):
            if a["y"] <= y <= b["y"]:
                t = (y - a["y"]) / max(b["y"] - a["y"], 1e-4)
                return {k: a[k] + (b[k] - a[k]) * t for k in ("zb", "belt", "roof", "hw", "rw")}
        return st[-1] if y > yf else st[0]

    # doublures des passages de roue (noir, epousent la roue)
    for y in (wb / 2, -wb / 2):
        for s in (-1, 1):
            for i in range(12):
                a = math.pi * (i + 0.5) / 12
                det.box(M["black"], (s * (hw - 0.19), y + math.cos(a) * (r + 0.07), r + math.sin(a) * (r + 0.07)), (0.32, (r + 0.07) * 0.28, 0.02), rx=a - math.pi / 2)
        # elargisseurs d'aile (4x4) : jonc noir autour de l'arche
        if sp.get("flares"):
            for s in (-1, 1):
                for i in range(9):
                    a = math.pi * (0.06 + i / 8 * 0.88)
                    det.box(M["black"], (s * (hw + 0.015), y + math.cos(a) * (r + 0.1), r + math.sin(a) * (r + 0.1)), (0.05, 0.16, 0.07), rx=a + math.pi / 2)
    # pare-chocs enveloppants (avant et arriere) : lame + retours sur les cotes
    bz = sp["bumper_z"]
    for y0, dirn in ((yf, 1), (yr, -1)):
        c = belt_at(y0 - dirn * 0.25)
        bw = c["hw"] * 2 + 0.02
        det.box(M[sp.get("bumper_mat", "body")], (0, y0 - dirn * 0.02, bz), (bw - 0.18, 0.2, sp["bumper_h"]), smooth=True)
        for s in (-1, 1):
            det.box(M[sp.get("bumper_mat", "body")], (s * (bw / 2 - 0.16), y0 - dirn * 0.12, bz), (0.14, 0.26, sp["bumper_h"] * 0.96), rz=s * dirn * 0.5, smooth=True)
        det.box(M["black"], (0, y0 + dirn * 0.1, bz - sp["bumper_h"] * 0.32), (bw - 0.4, 0.05, 0.06))
    # avant : calandre (style propre au modele), phares, clignotants ; ecusson parodique ; plaque
    fz = sp["lamp_z"]
    cf = belt_at(yf - 0.05)
    gh = sp["grille_h"]
    gw = sp.get("grille_w", cf["hw"] * 0.85)
    style = sp.get("grille", "bars")
    det.box(M["black"], (0, yf + 0.0, fz - 0.02), (gw, 0.06, gh))
    if style == "oval":
        # petite calandre ovale entre les phares (berline japonaise des annees 1990), deux lames fines
        for k in range(2):
            det.box(M["chrome"], (0, yf + 0.03, fz - 0.02 - gh * 0.18 + k * gh * 0.36), (gw * 0.9, 0.02, 0.01))
        det.box(M["chrome"], (0, yf + 0.03, fz - 0.02 + gh * 0.5), (gw, 0.022, 0.016))
    elif style == "vertical":
        # grande calandre chromee a barreaux verticaux, cadre epais (4x4)
        n = 11
        for k in range(n):
            det.box(M["chrome"], (-gw / 2 + 0.03 + k * (gw - 0.06) / (n - 1), yf + 0.03, fz - 0.02), (0.018, 0.02, gh * 0.9))
        for z in (gh / 2, -gh / 2):
            det.box(M["chrome"], (0, yf + 0.035, fz - 0.02 + z), (gw + 0.04, 0.025, 0.03))
    elif style == "wide":
        # calandre chromee pleine largeur, trois lames horizontales epaisses (pick-up)
        for k in range(3):
            det.box(M["chrome"], (0, yf + 0.035, fz - 0.02 - gh * 0.33 + k * gh * 0.33), (gw, 0.025, 0.035))
        for s in (-1, 1):
            det.box(M["chrome"], (s * gw / 2, yf + 0.035, fz - 0.02), (0.03, 0.025, gh))
    else:
        for k in range(4):
            det.box(M["chrome"], (0, yf + 0.03, fz - 0.02 - gh * 0.4 + k * gh * 0.27), (gw * 0.97, 0.02, 0.012))
    badge(det, M, (0, yf + 0.06, fz - 0.02 + sp.get("badge_dz", 0.0)), sp.get("badge_r", 0.055), front=True)
    lw = sp.get("lamp_w", 0.34)
    sweep = sp.get("lamp_sweep", 0.12)
    for s in (-1, 1):
        lx = s * (gw / 2 + lw / 2 + 0.02) if sp.get("lamp_hug") else s * (cf["hw"] - 0.25)
        lh = sp["lamp_h"]
        det.box(M["black"], (lx, yf - 0.025, fz), (lw + 0.03, 0.1, lh + 0.04), rz=-s * sweep)
        det.box(M["lamp"], (lx, yf + 0.024, fz), (lw, 0.012, lh * 0.92), rz=-s * sweep)     # glace (s'allume la nuit)
        det.box(M["chrome"], (lx, yf + 0.03, fz + lh * 0.5), (lw + 0.01, 0.014, 0.012), rz=-s * sweep)
        det.box(M["chrome"], (lx, yf + 0.03, fz - lh * 0.5), (lw + 0.01, 0.014, 0.012), rz=-s * sweep)
        det.box(M["lamp"], (lx + s * lw * 0.44, yf - 0.02, fz - lh * 0.3), (0.05, 0.01, 0.015), rz=-s * sweep)
        if sp.get("lamp_twin"):
            # deux optiques rondes par bloc (4x4 ancien) sous la glace
            for k in (-1, 1):
                det.lathe_y(M["chrome"], (lx + k * lw * 0.24, yf + 0.03, fz), [(0.0, lh * 0.42), (0.01, lh * 0.38)], 16)
        det.box(M["orange"], (s * (cf["hw"] - 0.05), yf - 0.12, fz - 0.01), (0.07, 0.14, sp["lamp_h"] * 0.6), rz=-s * 0.5)
        # antibrouillard dans le pare-chocs
        det.box(M["lamp"], (s * (cf["hw"] - 0.3), yf + 0.12, bz - 0.02), (0.12, 0.02, 0.06))
    det.box(M["plate"], (0, yf + 0.13, bz + 0.01), (0.44, 0.02, 0.11))
    # arriere : blocs de feux sur les ailes, plaque sur le hayon / coffre, pot d'echappement
    tz = sp["tail_z"]
    cr = belt_at(yr + 0.05)
    for s in (-1, 1):
        det.box(M["black"], (s * (cr["hw"] - 0.17), yr + 0.012, tz), (0.33, 0.07, sp["tail_h"] + 0.03), rz=s * 0.1)
        for k in (-1, 1):                                                       # cloisons du bloc optique
            det.box(M["black"], (s * (cr["hw"] - 0.17) + k * 0.075, yr - 0.016, tz), (0.008, 0.012, sp["tail_h"]), rz=s * 0.1)
        det.box(M["tail"], (s * (cr["hw"] - 0.17), yr - 0.0, tz), (0.3, 0.07, sp["tail_h"]), rz=s * 0.1)
        det.box(M["orange"], (s * (cr["hw"] - 0.17), yr - 0.01, tz - sp["tail_h"] * 0.38), (0.28, 0.07, sp["tail_h"] * 0.25), rz=s * 0.1)
        det.box(M["lamp"], (s * (cr["hw"] - 0.17), yr - 0.012, tz + sp["tail_h"] * 0.32), (0.12, 0.06, sp["tail_h"] * 0.2), rz=s * 0.1)
    if sp.get("tail_bar"):
        # bandeau rouge sombre entre les feux, sur le coffre (berlines des annees 1990)
        det.box(M["tail"], (0, yr - 0.03, tz), (cr["hw"] * 2 - 0.62, 0.06, sp["tail_h"] * 0.55))
    det.box(M["plate"], (0, yr - 0.03, sp["rear_plate_z"]), (0.44, 0.02, 0.11))
    # ecusson et noms parodiques en relief a l'arriere (marque a gauche, modele a droite)
    bz_ = sp.get("badge_rear_z", sp["rear_plate_z"] + 0.2)
    badge(det, M, (0, yr - 0.06, bz_), sp.get("badge_r", 0.055) * 0.9, front=False)
    if sp.get("brand"):
        lettrage(root, M, sp["brand"], (-cr["hw"] * 0.45, yr - 0.07, bz_ - 0.02), 0.045)
        lettrage(root, M, sp["model"], (cr["hw"] * 0.45, yr - 0.07, bz_ - 0.02), 0.045)
    det.box(M["chrome"], (0, yr - 0.02, sp["rear_plate_z"] + 0.1), (0.3, 0.02, 0.03))
    det.lathe_y(M["chrome"], (hw * 0.55, yr + 0.05, st[0]["zb"] + 0.02), [(0.25, 0.024), (-0.12, 0.032), (-0.14, 0.03)], 12, cap=False)
    det.lathe_y(M["black"], (hw * 0.55, yr + 0.05, st[0]["zb"] + 0.02), [(-0.13, 0.026), (-0.125, 0.0)], 12)
    for k, x in enumerate((-0.13, -0.08, -0.03, 0.02, 0.07, 0.12)):        # numero fictif sur la plaque arriere
        det.box(M["black"], (x, yr - 0.042, sp["rear_plate_z"] + (0.01 if k % 2 else -0.01)), (0.03, 0.004, 0.06))
    # retroviseurs (coque couleur caisse sur un bras noir), poignees, encadrements de vitres, essuie-glaces
    my = sp["mirror_y"]
    cm = belt_at(my)
    for s in (-1, 1):
        sill = cm["rw"] + (cm["hw"] * 0.965 - cm["rw"]) * 0.72      # appui de vitre (voir half_section)
        det.box(M["black"], (s * (sill + 0.01), my - 0.02, cm["belt"] + 0.05), (0.04, 0.16, 0.09))   # embase triangulaire
        det.box(M["black"], (s * (sill + 0.06), my - 0.03, cm["belt"] + 0.07), (0.08, 0.04, 0.03))
        det.box(M["body"], (s * (sill + 0.13), my - 0.04, cm["belt"] + 0.09), (0.13, 0.08, 0.1), rz=s * 0.12, smooth=True)
        det.box(M["mirror"], (s * (sill + 0.13), my - 0.083, cm["belt"] + 0.09), (0.11, 0.008, 0.08), rz=s * 0.12)
        for y in sp["doors"]:
            c = belt_at(y)
            det.box(M["black"], (s * (c["hw"] * 0.985 + 0.01), y, c["belt"] - 0.12), (0.025, 0.15, 0.035))
        # joints de portes : fentes fines sur la carrosserie
        for y in sp["door_lines"]:
            c = belt_at(y)
            z0, z1 = c["zb"] + 0.12, c["belt"] - 0.02
            det.box(M["black"], (s * (c["hw"] + 0.002), y, (z0 + z1) / 2), (0.008, 0.01, z1 - z0))
        # baguette de protection laterale
        det.box(M["black"], (s * (hw * 1.0 + 0.004), (sp["door_lines"][0] + sp["door_lines"][-1]) / 2, sp["strip_z"]),
                (0.012, abs(sp["door_lines"][0] - sp["door_lines"][-1]) + 0.2, 0.04))
    cfuel = belt_at(-wb / 2 + 0.05)
    det.box(M["black"], (cfuel["hw"] + 0.003, -wb / 2 + 0.05, cfuel["belt"] - 0.13), (0.006, 0.17, 0.12))
    for yl, dirn in ((sp["wiper_y"] + 0.05, 1), (st[2]["y"] if not sp.get("rack") else None, -1)):
        if yl is None:
            continue
        c = belt_at(yl)
        det.box(M["black"], (0, yl, c["belt"] + 0.012), (c["hw"] * 1.6, 0.006, 0.006))
    wy = sp["wiper_y"]
    cw = belt_at(wy)
    for s in (-0.35, 0.25):
        det.box(M["black"], (s, wy, cw["belt"] + 0.05), (0.5, 0.02, 0.015), rz=0.25, rx=-0.5)
    # options : galerie de toit chargee (minibus), roue de secours au hayon (4x4), antenne
    rz = max(x["roof"] for x in st)
    if sp.get("rack"):
        y0, y1 = sp["rack"]
        for s in (-1, 1):
            det.box(M["rack"], (s * (hw - 0.22), (y0 + y1) / 2, rz + 0.14), (0.04, y1 - y0, 0.04))
            for y in (y0 + 0.1, y1 - 0.1, (y0 + y1) / 2):
                det.box(M["rack"], (s * (hw - 0.22), y, rz + 0.07), (0.04, 0.04, 0.12))
        for k in range(6):
            det.box(M["rack"], (0, y0 + 0.1 + k * (y1 - y0 - 0.2) / 5, rz + 0.14), (W - 0.44, 0.04, 0.04))
        det.box(M["cargo"], (0.1, (y0 + y1) / 2 - 0.3, rz + 0.24), (1.1, 1.3, 0.2), smooth=True)
        det.box(M["sac"], (-0.45, (y0 + y1) / 2 + 0.75, rz + 0.24), (0.5, 0.6, 0.2), smooth=True)
        det.box(M["sac"], (0.35, (y0 + y1) / 2 + 0.8, rz + 0.23), (0.55, 0.45, 0.18), smooth=True)
    if sp.get("bed"):
        y0, y1, fz = sp["bed"]
        cb = belt_at((y0 + y1) / 2)
        for s in (-1, 1):
            det.box(M["black"], (s * (cb["hw"] - 0.035), (y0 + y1) / 2, cb["belt"] + 0.01), (0.07, y1 - y0 + 0.08, 0.025))   # rebord des ridelles
            for k in range(3):                                                                                          # anneaux d'arrimage
                det.box(M["chrome"], (s * (cb["hw"] - 0.09), y0 + 0.25 + k * (y1 - y0 - 0.5) / 2, fz + 0.12), (0.02, 0.06, 0.04))
        det.box(M["black"], (0, yr - 0.02, sp["tail_z"] + 0.08), (0.22, 0.02, 0.05))                                     # poignee du hayon
        for k in range(5):                                                                                              # nervures du plancher
            det.box(M["rack"], (-0.6 + k * 0.3, (y0 + y1) / 2, fz + 0.012), (0.05, y1 - y0 - 0.1, 0.02))
    if sp.get("spare"):
        sp_mesh = Mesh("roue_secours")
        sp_mesh.lathe_x(M["tire"], (0, 0, 0), [(0.13, r * 0.6), (0.14, r * 0.9), (0.1, r), (-0.1, r), (-0.12, r * 0.9), (-0.11, r * 0.6)], 24)
        sp_mesh.disc_x(M["black"], (0.12, 0, 0), r * 0.62, 24)
        so = sp_mesh.obj(root)
        so.rotation_euler = (0, 0, math.pi / 2)
        so.location = (0, yr - 0.15, sp["tail_z"] + 0.05)
        for p in so.data.polygons:
            p.use_smooth = True
    do = det.obj(root)
    for p in do.data.polygons:
        if p.material_index < len(do.data.materials) and do.data.materials[p.material_index].name in ("mat_carrosserie",):
            p.use_smooth = True

    # interieur : sieges, planche de bord, volant a gauche, console, ciel de toit
    inner = Mesh(name + "_interieur")
    sz = sp["seat_z"]
    rows = sp["seat_rows"]
    for i, ry in enumerate(rows):
        if i == 0:
            for s in (-1, 1):
                seat(inner, M, s * hw * 0.42, ry, sz, 0.5)
        else:
            seat(inner, M, 0, ry, sz, W - 0.42, front=False)
    dy = sp["dash_y"]
    cd = belt_at(dy)
    inner.box(M["inside"], (0, dy, cd["belt"] - 0.06), (W - 0.28, 0.45, 0.24), smooth=True)
    inner.box(M["black"], (0, dy - 0.12, cd["belt"] + 0.05), (W - 0.4, 0.2, 0.04))
    inner.box(M["inside"], (0, (rows[0] + dy) / 2 - 0.05, sz - 0.05), (0.2, dy - rows[0], 0.22))
    inner.box(M["inside"], (0, 0, st[0]["zb"] + 0.04), (W - 0.2, L * 0.6, 0.04))
    inner.torus_x(M["black"], (-hw * 0.42, dy - 0.3, cd["belt"] + 0.06), 0.18, 0.018, 22, 6, tilt=-0.45)
    inner.box(M["black"], (-hw * 0.42, dy - 0.2, cd["belt"] + 0.02), (0.05, 0.25, 0.05), rx=-0.45)
    io = inner.obj(root)
    for p in io.data.polygons:
        p.use_smooth = True

    # roues (pivots separes)
    tw = sp["track"] / 2
    for tag, y in (("av", wb / 2), ("ar", -wb / 2)):
        for side, sx in (("g", -1), ("d", 1)):
            if tag == "av":
                stp = empty(f"piv_direction_{tag}{side}", (sx * tw, y, r), root)
                rp = empty(f"piv_roue_{tag}{side}", (0, 0, 0), stp)
            else:
                rp = empty(f"piv_roue_{tag}{side}", (sx * tw, y, r), root)
            wheel(M, f"{name}_roue_{tag}{side}", rp, r, sp["tire_w"], sx, sp.get("spokes", 5))
    # bassin du conducteur assis : au-dessus de l'assise, un peu en arriere de son milieu
    empty("pt_conducteur", (-hw * 0.42, rows[0] - 0.1, sz + 0.08), root)
    empty("pt_sortie", (-hw - 0.75, rows[0] + 0.1, 0.0), root)
    # cibles des mains (centre du volant) et des pieds (pedales) pour la pose du conducteur (IK dans Godot)
    empty("pt_volant", (-hw * 0.42, dy - 0.3, cd["belt"] + 0.06), root)
    empty("pt_pedales", (-hw * 0.42, dy - 0.05, st[0]["zb"] + 0.12), root)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_BLEND_DIR, name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_GLB_DIR, name + ".glb"), export_format="GLB",
                              export_apply=True, export_yup=True)
    faces = sum(len(o.data.polygons) for o in bpy.data.objects if o.type == "MESH")
    print("Vehicule", name, ":", faces, "faces")
    if PREVIEW_DIR:
        preview(name, L)


def preview(name, L):
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w")
    w.color = (0.75, 0.8, 0.85)
    sc.world = w
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_shadows = True
    sc.render.resolution_x = 1000
    sc.render.resolution_y = 650
    bpy.data.materials["mat_carrosserie"].diffuse_color = [to_linear(c) for c in (0.75, 0.12, 0.1)] + [1.0]
    for nm, loc, rot_ in (("trois_quart", (L * 1.1, L * 1.2, 1.9), (78, 0, 137)), ("arriere", (-L * 0.95, -L * 1.25, 1.8), (80, 0, -37)),
                          ("profil", (-L * 1.75, 0, 1.0), (88, 0, -90))):
        c = bpy.data.cameras.new(nm)
        c.lens = 40
        o = bpy.data.objects.new(nm, c)
        sc.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = [math.radians(a) for a in rot_]
        sc.camera = o
        sc.render.filepath = os.path.join(PREVIEW_DIR, f"{name}_{nm}.png")
        bpy.ops.render.render(write_still=True)


def S(y, zb, belt, roof, hw, rw, win=False, top=None):
    return {"y": y, "zb": zb, "belt": belt, "roof": roof, "hw": hw, "rw": rw, "win": win, "top": top}


# Berline compacte (4,30 x 1,70 x 1,42 m, empattement 2,50 m) : capot plongeant, pare-brise incline, malle courte.
SEDAN = dict(L=4.3, W=1.7, wb=2.5, r=0.3, track=1.46, tire_w=0.19, spokes=6, stations=[
    S(-2.15, 0.36, 0.8, 0.84, 0.74, 0.58),
    S(-2.08, 0.3, 0.9, 0.93, 0.82, 0.66),
    S(-1.85, 0.27, 0.95, 0.98, 0.845, 0.68),
    S(-1.5, 0.26, 0.97, 1.0, 0.85, 0.68, top="glass"),          # bas de lunette
    S(-0.95, 0.25, 0.97, 1.39, 0.85, 0.63, win=True),            # haut de lunette, montant C
    S(-0.4, 0.25, 0.97, 1.42, 0.85, 0.63),                       # montant B
    S(-0.3, 0.25, 0.97, 1.42, 0.85, 0.63, win=True),
    S(0.3, 0.25, 0.96, 1.41, 0.85, 0.63, win=True, top="glass"),  # haut du pare-brise
    S(1.05, 0.26, 0.93, 0.96, 0.845, 0.7),                       # bas du pare-brise
    S(1.6, 0.27, 0.86, 0.88, 0.83, 0.68),
    S(1.98, 0.3, 0.76, 0.77, 0.78, 0.6),
    S(2.15, 0.38, 0.66, 0.67, 0.68, 0.5),
], bumper_z=0.43, bumper_h=0.2, lamp_z=0.66, lamp_h=0.11, grille_h=0.12, tail_z=0.8, tail_h=0.16, rear_plate_z=0.62,
    mirror_y=0.95, wiper_y=1.0, doors=[0.15, -0.65], door_lines=[1.0, -0.33, -1.1], strip_z=0.55,
    seat_rows=[-0.05, -0.95], seat_z=0.47, dash_y=0.72,
    grille="oval", grille_w=0.52, lamp_hug=True, lamp_w=0.4, lamp_sweep=0.2, tail_bar=True, brand="TOYODA", model="KORALO")

# 4x4 tout-terrain (4,80 x 1,88 x 1,85 m, empattement 2,80 m) : caisse haute et carree, hayon vertical,
# roue de secours au hayon, elargisseurs d'ailes noirs, pare-chocs gris.
SUV = dict(L=4.8, W=1.88, wb=2.8, r=0.38, track=1.58, tire_w=0.26, spokes=6, flares=True, spare=True, bumper_mat="black", stations=[
    S(-2.25, 0.42, 1.12, 1.15, 0.9, 0.78),
    S(-2.2, 0.38, 1.16, 1.8, 0.93, 0.8, win=True, top=None),
    S(-1.9, 0.37, 1.16, 1.84, 0.94, 0.81),                        # montant D
    S(-1.75, 0.37, 1.16, 1.84, 0.94, 0.81, win=True),
    S(-0.55, 0.37, 1.16, 1.85, 0.94, 0.81),                       # montant B
    S(-0.45, 0.37, 1.16, 1.85, 0.94, 0.81, win=True),
    S(0.6, 0.37, 1.15, 1.84, 0.94, 0.81, win=True, top="glass"),
    S(1.3, 0.38, 1.12, 1.15, 0.935, 0.84),
    S(1.95, 0.4, 1.13, 1.15, 0.93, 0.84),
    S(2.2, 0.45, 1.1, 1.12, 0.91, 0.8),
    S(2.28, 0.52, 1.04, 1.05, 0.88, 0.76),
], bumper_z=0.58, bumper_h=0.24, lamp_z=0.92, lamp_h=0.14, grille_h=0.2, tail_z=1.0, tail_h=0.24, rear_plate_z=0.78,
    mirror_y=1.12, wiper_y=1.2, doors=[0.2, -0.85], door_lines=[1.2, -0.5, -1.65], strip_z=0.72,
    seat_rows=[-0.05, -1.05], seat_z=0.62, dash_y=0.9,
    grille="vertical", grille_w=0.92, lamp_hug=True, lamp_w=0.3, lamp_sweep=0.0, badge_r=0.065, brand="TOYODA", model="LANDA")

# Minibus a toit haut (4,85 x 1,88 x 2,25 m, empattement 2,57 m), cabine avancee, porte laterale coulissante,
# galerie chargee : le transport en commun de Cotonou.
MINIBUS = dict(L=4.85, W=1.88, wb=2.57, r=0.33, track=1.62, tire_w=0.21, spokes=5, rack=(-2.1, 1.7), stations=[
    S(-2.42, 0.36, 1.05, 2.15, 0.92, 0.84, top=None),
    S(-2.36, 0.33, 1.08, 2.22, 0.94, 0.86, win=True),
    # vitres laterales nombreuses et montants fins (facon taxi-brousse : une vitre par rangee de sieges)
    S(-1.78, 0.32, 1.08, 2.24, 0.94, 0.86),
    S(-1.7, 0.32, 1.08, 2.24, 0.94, 0.86, win=True),
    S(-1.02, 0.32, 1.08, 2.24, 0.94, 0.86),
    S(-0.94, 0.32, 1.08, 2.24, 0.94, 0.86, win=True),
    S(-0.3, 0.32, 1.08, 2.24, 0.94, 0.86),
    S(-0.22, 0.32, 1.08, 2.24, 0.94, 0.86, win=True),
    S(0.42, 0.32, 1.08, 2.24, 0.94, 0.86),
    S(0.5, 0.32, 1.08, 2.24, 0.94, 0.86, win=True),
    S(1.17, 0.32, 1.08, 2.24, 0.94, 0.86),
    S(1.27, 0.32, 1.08, 2.24, 0.94, 0.86, win=True),
    S(1.85, 0.32, 1.08, 2.22, 0.94, 0.86, win=True, top="glass"),
    S(2.3, 0.33, 1.02, 1.12, 0.93, 0.84),
    S(2.43, 0.38, 0.9, 0.92, 0.88, 0.76),
], bumper_z=0.45, bumper_h=0.2, lamp_z=0.8, lamp_h=0.13, grille_h=0.14, tail_z=0.95, tail_h=0.3, rear_plate_z=0.7,
    mirror_y=1.9, wiper_y=2.05, doors=[1.55, 0.35], door_lines=[2.05, 1.2, -0.3], strip_z=0.6,
    seat_rows=[1.45, 0.45, -0.45, -1.4], seat_z=0.6, dash_y=2.05,
    grille="bars", grille_w=0.62, lamp_hug=True, lamp_w=0.42, lamp_sweep=0.05, brand="TOYODA", model="HAISSE")

# Pick-up simple cabine (5,30 x 1,85 x 1,80 m, empattement 3,08 m) : cabine courte, long plateau ouvert (benne evidee,
# plancher noir), tres courant a Cotonou pour les livraisons (phase 9).
PICKUP = dict(L=5.3, W=1.85, wb=3.08, r=0.36, track=1.54, tire_w=0.24, spokes=6, bumper_mat="black", stations=[
    S(-2.62, 0.45, 1.0, 1.03, 0.88, 0.78),
    S(-2.55, 0.42, 1.02, 1.06, 0.9, 0.82),
    S(-0.85, 0.42, 1.02, 1.06, 0.9, 0.82),
    S(-0.78, 0.42, 1.08, 1.78, 0.92, 0.8, win=True),             # arriere de la cabine (lunette)
    S(-0.15, 0.42, 1.08, 1.8, 0.92, 0.8),                        # montant B
    S(-0.05, 0.42, 1.08, 1.8, 0.92, 0.8, win=True),
    S(0.7, 0.42, 1.07, 1.78, 0.92, 0.8, win=True, top="glass"),  # haut du pare-brise
    S(1.4, 0.43, 1.05, 1.1, 0.92, 0.82),                         # bas du pare-brise
    S(2.15, 0.45, 1.0, 1.04, 0.9, 0.8),
    S(2.45, 0.5, 1.0, 1.02, 0.88, 0.76),
    S(2.6, 0.56, 0.95, 0.96, 0.84, 0.72),
], bumper_z=0.55, bumper_h=0.22, lamp_z=0.88, lamp_h=0.13, grille_h=0.18, tail_z=0.9, tail_h=0.24, rear_plate_z=0.72,
    mirror_y=1.3, wiper_y=1.36, doors=[0.35], door_lines=[1.3, -0.72], strip_z=0.7,
    seat_rows=[0.1], seat_z=0.64, dash_y=1.05, bed=(-2.5, -0.9, 0.82),
    grille="wide", grille_w=0.86, lamp_hug=True, lamp_w=0.36, lamp_sweep=0.25, badge_r=0.065, brand="TOYODA", model="HAILUX")

for nm, sp in (("veh_berline", SEDAN), ("veh_4x4", SUV), ("veh_minibus", MINIBUS), ("veh_pickup", PICKUP)):
    vehicle(nm, sp)
