# GTB : vehicules conduisibles faits par script (aucune marque, aucun logo) : berline, 4x4, minibus (type
# "tokpa-tokpa" de Cotonou). Un .glb par vehicule, avec roues et pivots separes pour la conduite dans Godot.
# Lancement : blender -b --python blender/tools/build_vehicles.py -- <dossier_blend> <dossier_glb> [dossier_apercus]
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


MATS = {}


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


def mats():
    return {
        "body": mat("mat_carrosserie", (0.92, 0.92, 0.9), 0.48, 0.08),
        "glass": mat("mat_verre_auto", (0.08, 0.1, 0.12), 0.05, 0.0, alpha=0.62),
        "lamp": mat("mat_lampe", (0.95, 0.95, 0.88), 0.1),
        "tail": mat("mat_feu_arriere", (0.65, 0.05, 0.04), 0.2),
        "orange": mat("mat_clignotant", (0.95, 0.5, 0.05), 0.2),
        "tire": mat("mat_pneu", (0.06, 0.06, 0.065), 0.9),
        "rim": mat("mat_jante", (0.7, 0.71, 0.72), 0.3, 0.8),
        "black": mat("mat_plastique_noir", (0.07, 0.07, 0.075), 0.7),
        "inside": mat("mat_interieur", (0.16, 0.14, 0.13), 0.9),
        "plate": mat("mat_plaque", (0.93, 0.93, 0.9), 0.5),
        "chrome": mat("mat_chrome", (0.8, 0.8, 0.82), 0.15, 1.0),
        "rack": mat("mat_galerie", (0.2, 0.2, 0.22), 0.6, 0.6),
        "cargo": mat("mat_bache", (0.25, 0.35, 0.55), 0.9),
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

    def box(self, m, c, s, rz=0.0, rx=0.0):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        cz, sz = math.cos(rz), math.sin(rz)
        cx, sx = math.cos(rx), math.sin(rx)
        vs = []
        for z in (-hz, hz):
            for y in (-hy, hy):
                for x in (-hx, hx):
                    y2, z2 = y * cx - z * sx, y * sx + z * cx
                    x3, y3 = x * cz - y2 * sz, x * sz + y2 * cz
                    vs.append(self.bm.verts.new((c[0] + x3, c[1] + y3, c[2] + z2)))
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            self.face([vs[i] for i in f], m)

    def cyl_x(self, m, c, r, w, seg=16, smooth=True, r_in=None):
        """Cylindre d'axe X (roues). r_in : anneau (pneu) au lieu d'un disque plein."""
        rings = []
        for x in (-w / 2, w / 2):
            rings.append([self.bm.verts.new((c[0] + x, c[1] + r * math.cos(i / seg * math.tau), c[2] + r * math.sin(i / seg * math.tau)))
                          for i in range(seg)])
        for i in range(seg):
            j = (i + 1) % seg
            self.face((rings[0][i], rings[0][j], rings[1][j], rings[1][i]), m, smooth)
        if r_in is None:
            self.face(rings[1], m)
            self.face(rings[0][::-1], m)
        else:
            for side, ring in ((1, rings[1]), (0, rings[0])):
                x = c[0] + (w / 2 if side else -w / 2)
                inner = [self.bm.verts.new((x, c[1] + r_in * math.cos(i / seg * math.tau), c[2] + r_in * math.sin(i / seg * math.tau)))
                         for i in range(seg)]
                for i in range(seg):
                    j = (i + 1) % seg
                    q = (ring[i], ring[j], inner[j], inner[i]) if side else (ring[j], ring[i], inner[i], inner[j])
                    self.face(q, m)

    def loft_y(self, m, stations, profile, smooth=True, cap=True, mat_fn=None):
        """Volume le long de Y. stations : (y, z_bas, z_haut, demi_largeur_bas, demi_largeur_haut).
        profile : liste de (u, v) en [0,1] decrivant la demi-section (bas -> haut cote droit), symetrisee."""
        rings = []
        for y, zb, zt, hb, ht in stations:
            pts = []
            for u, v in profile:
                z = zb + (zt - zb) * v
                hw = hb + (ht - hb) * v
                pts.append((hw * u, z))
            full = pts + [(-x, z) for x, z in reversed(pts)]
            rings.append([self.bm.verts.new((x, y, z)) for x, z in full])
        n = len(rings[0])
        for a in range(len(rings) - 1):
            for i in range(n):
                j = (i + 1) % n
                mm = mat_fn(a, i) if mat_fn else m
                self.face((rings[a][i], rings[a][j], rings[a + 1][j], rings[a + 1][i]), mm, smooth)
        if cap:
            self.face(rings[0], m)
            self.face(rings[-1][::-1], m)

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


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.2
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    return e


# demi-section de caisse : bas de caisse arrondi, flanc legerement bombe, epaule arrondie
BODY_PROFILE = [(0.9, 0.0), (0.98, 0.12), (1.0, 0.35), (1.0, 0.6), (0.98, 0.82), (0.9, 0.95), (0.75, 1.0)]
CABIN_PROFILE = [(1.0, 0.0), (0.99, 0.5), (0.95, 0.9), (0.85, 1.0)]


def wheel(M, name, piv, r, w, side):
    m = Mesh(name)
    m.cyl_x(M["tire"], (0, 0, 0), r, w, 18, True, r_in=r * 0.68)
    m.cyl_x(M["rim"], (side * 0.01, 0, 0), r * 0.68, w * 0.8, 12, False)
    m.cyl_x(M["chrome"], (side * w * 0.42, 0, 0), r * 0.22, 0.03, 8, False)
    # rayons de jante
    for i in range(5):
        a = i / 5 * math.tau
        m.box(M["rim"], (side * w * 0.38, math.cos(a) * r * 0.42, math.sin(a) * r * 0.42), (0.03, 0.05, r * 0.5), rx=a + math.pi / 2)
    return m.obj(piv)


def vehicle(name, spec):
    reset()
    M = mats()
    root = empty(name, (0, 0, 0))
    L, W, wb, r = spec["L"], spec["W"], spec["wb"], spec["r"]
    hw = W / 2
    body = Mesh(name + "_caisse")
    # --- caisse basse avec passages de roue (bas de caisse releve au droit des roues) ---
    ys = sorted(set([-L / 2, -L / 2 + 0.12] + [a + d for a in (-wb / 2, wb / 2) for d in (-r - 0.16, -r * 0.75, 0.0, r * 0.75, r + 0.16)] +
                    [L / 2 - 0.12, L / 2]))
    zb0 = spec["ground"]

    def z_bottom(y):
        for a in (-wb / 2, wb / 2):
            d = abs(y - a)
            if d < r + 0.16:
                return zb0 + (r * 2 + 0.06 - zb0) * math.sqrt(max(0.0, 1 - (d / (r + 0.16)) ** 2))
        return zb0

    def z_top(y):
        return spec["belt"](y)

    stations = []
    for y in ys:
        t = 1.0 - min(1.0, (abs(y) - (L / 2 - 0.12)) / 0.12) * 0.12 if abs(y) > L / 2 - 0.12 else 1.0
        stations.append((y, z_bottom(y), z_top(y), hw * t * 0.97, hw * t * 0.93))
    body.loft_y(M["body"], stations, BODY_PROFILE)
    # fond des passages de roue (noir, au-dessus de la roue) et dessous de caisse
    for a in (-wb / 2, wb / 2):
        for s in (-1, 1):
            body.box(M["black"], (s * (hw - 0.2), a, 2 * r + 0.06), (0.3, 2 * r + 0.25, 0.05))
    body.box(M["black"], (0, 0, zb0 + 0.04), (W - 0.25, L - 0.6, 0.08))
    # --- habitacle : vitres (tour complet), toit et montants couleur caisse ---
    cab = Mesh(name + "_vitres")
    cab.loft_y(M["glass"], spec["cabin"], CABIN_PROFILE, smooth=False)
    ry0, ry1 = spec["roof_y"]
    rz = spec["roof_z"]
    roof = spec["cabin"][1][4] * 1.02
    body.box(M["body"], (0, (ry0 + ry1) / 2, rz + 0.03), (roof * 2 + 0.04, ry1 - ry0 + 0.1, 0.06))
    for (y_lo, z_lo, y_hi, z_hi) in spec["pillars"]:
        for s in (-1, 1):
            dy, dz = y_hi - y_lo, z_hi - z_lo
            ln = math.hypot(dy, dz)
            ang = math.atan2(dz, dy)
            x = s * (roof + 0.035)
            body.box(M["body"], (x, (y_lo + y_hi) / 2, (z_lo + z_hi) / 2), (0.07, ln, 0.08), rx=ang)
    # --- avant : calandre, phares, pare-chocs, plaque ; arriere : feux, pare-chocs, plaque ---
    yf, yr = L / 2, -L / 2
    fz = spec["lamp_z"]
    body.box(M["black"], (0, yf + 0.005, fz - 0.03), (W * 0.42, 0.04, 0.16))
    for s in (-1, 1):
        body.box(M["lamp"], (s * (hw - 0.22), yf - 0.01, fz), (0.3, 0.06, 0.13))
        body.box(M["orange"], (s * (hw - 0.06), yf - 0.04, fz - 0.02), (0.06, 0.05, 0.08))
        body.box(M["tail"], (s * (hw - 0.2), yr + 0.01, spec["tail_z"]), (0.32, 0.06, 0.16))
        # retroviseurs
        body.box(M["black"], (s * (hw + 0.07), spec["mirror_y"], spec["belt"](spec["mirror_y"]) + 0.08), (0.12, 0.08, 0.1))
        # poignees de portes
        for y in spec["doors"]:
            body.box(M["chrome"], (s * (hw * 0.97 + 0.005), y, spec["belt"](y) - 0.1), (0.02, 0.14, 0.03))
    for y, h in ((yf + 0.02, spec["bumper_z"]), (yr - 0.02, spec["bumper_z"])):
        body.box(M["black"], (0, y, h), (W - 0.02, 0.16, 0.18))
    body.box(M["plate"], (0, yf + 0.11, spec["bumper_z"] + 0.02), (0.44, 0.02, 0.11))
    body.box(M["plate"], (0, yr - 0.11, spec["bumper_z"] + 0.14), (0.44, 0.02, 0.11))
    # lignes de portes (fentes sombres)
    for y in spec["door_lines"]:
        z0, z1 = z_bottom(y) + 0.05, spec["belt"](y) - 0.04
        for s in (-1, 1):
            body.box(M["black"], (s * (hw * 0.97 + 0.003), y, (z0 + z1) / 2), (0.012, 0.012, z1 - z0))
    # options : galerie de toit chargee (minibus), porte laterale coulissante
    if spec.get("rack"):
        y0, y1 = spec["roof_y"]
        for s in (-1, 1):
            body.box(M["rack"], (s * (roof - 0.05), (y0 + y1) / 2, rz + 0.14), (0.04, y1 - y0 - 0.2, 0.04))
        for k in range(5):
            body.box(M["rack"], (0, y0 + 0.2 + k * (y1 - y0 - 0.4) / 4, rz + 0.1), (roof * 2 - 0.1, 0.04, 0.04))
        body.box(M["cargo"], (0.1, (y0 + y1) / 2 - 0.3, rz + 0.32), (1.2, 1.4, 0.36))
        body.box(M["rack"], (-0.4, (y0 + y1) / 2 + 0.8, rz + 0.28), (0.5, 0.6, 0.3))
    body.obj(root)
    cab.obj(root)
    # --- interieur : sieges, tableau de bord, volant (a gauche) ---
    inner = Mesh(name + "_interieur")
    sz = spec["seat_z"]
    for row_y in spec["seat_rows"]:
        for s in ((-1, 1) if row_y == spec["seat_rows"][0] else (0,)):
            wseat = 0.5 if s else (W - 0.4)
            x = s * hw * 0.42
            inner.box(M["inside"], (x, row_y, sz), (wseat, 0.5, 0.14))
            inner.box(M["inside"], (x, row_y - 0.27, sz + 0.33), (wseat, 0.12, 0.6), rx=-0.15)
    dy = spec["dash_y"]
    inner.box(M["inside"], (0, dy, spec["belt"](dy) - 0.04), (W - 0.3, 0.35, 0.2))
    inner.cyl_x(M["black"], (0, 0, 0), 0.18, 0.03, 14, False)  # volant (pose apres)
    inner.obj(root)
    vol = bpy.data.objects[name + "_interieur"]
    # le volant est le dernier cylindre ajoute : on le place en le deplacant dans le mesh
    me = vol.data
    nv = len(me.vertices)
    for v in me.vertices[nv - 14 * 2:]:
        x, y, z = v.co.x, v.co.y, v.co.z
        # disque d'axe X -> incline vers le conducteur (axe Y, penche de 60 degres)
        a = math.radians(60)
        ny, nz = x * math.cos(a), x * math.sin(a)
        v.co = (-hw * 0.42 + y, dy - 0.25 + ny, spec["belt"](dy) + 0.02 + z * 0.9 + nz)
    # --- roues (pivots separes) ---
    tw = spec["track"] / 2
    for tag, y in (("av", wb / 2), ("ar", -wb / 2)):
        for side, sx in (("g", -1), ("d", 1)):
            if tag == "av":
                st = empty(f"piv_direction_{tag}{side}", (sx * tw, y, r), root)
                rp = empty(f"piv_roue_{tag}{side}", (0, 0, 0), st)
            else:
                rp = empty(f"piv_roue_{tag}{side}", (sx * tw, y, r), root)
            wheel(M, f"{name}_roue_{tag}{side}", rp, r, spec["tire_w"], sx)
    empty("pt_conducteur", (-hw * 0.42, spec["seat_rows"][0] - 0.05, sz + 0.07), root)
    empty("pt_sortie", (-hw - 0.75, spec["seat_rows"][0] + 0.1, 0.0), root)
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
    for nm, loc, rot in (("trois_quart", (L * 1.35, L * 1.45, 2.2), (78, 0, 137)), ("arriere", (-L * 1.1, -L * 1.5, 1.9), (80, 0, -35))):
        c = bpy.data.cameras.new(nm)
        c.lens = 40
        o = bpy.data.objects.new(nm, c)
        sc.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = [math.radians(a) for a in rot]
        sc.camera = o
        sc.render.filepath = os.path.join(PREVIEW_DIR, f"{name}_{nm}.png")
        bpy.ops.render.render(write_still=True)


def belt_sedan(y):
    # capot plus bas a l'avant, coffre a l'arriere
    if y > 1.0:
        return 0.92 - (y - 1.0) * 0.12
    if y < -1.5:
        return 0.95 - (-1.5 - y) * 0.1
    return 0.95


SEDAN = dict(L=4.45, W=1.76, wb=2.6, r=0.31, track=1.5, tire_w=0.2, ground=0.24, belt=belt_sedan,
             cabin=[(-1.45, 0.94, 0.96, 0.84, 0.8), (-0.9, 0.94, 1.42, 0.84, 0.66), (0.35, 0.94, 1.44, 0.84, 0.66),
                    (1.05, 0.93, 0.95, 0.84, 0.8)],
             roof_y=(-0.92, 0.38), roof_z=1.42, pillars=[(-1.45, 0.95, -0.9, 1.42), (0.35, 1.44, 1.05, 0.95), (-0.25, 0.95, -0.25, 1.43)],
             lamp_z=0.72, tail_z=0.82, bumper_z=0.42, mirror_y=0.95, doors=[0.2, -0.65], door_lines=[0.95, -0.25, -1.15],
             seat_rows=[-0.1, -0.95], seat_z=0.48, dash_y=0.75)


def belt_4x4(y):
    if y > 1.1:
        return 1.12 - (y - 1.1) * 0.08
    return 1.14


SUV = dict(L=4.75, W=1.9, wb=2.75, r=0.38, track=1.6, tire_w=0.26, ground=0.38, belt=belt_4x4,
           cabin=[(-2.32, 1.13, 1.15, 0.92, 0.86), (-2.22, 1.13, 1.82, 0.92, 0.8), (0.55, 1.13, 1.84, 0.92, 0.8),
                  (1.2, 1.12, 1.15, 0.92, 0.86)],
           roof_y=(-2.25, 0.6), roof_z=1.82, pillars=[(-2.25, 1.14, -2.2, 1.82), (0.55, 1.84, 1.2, 1.14), (-0.3, 1.14, -0.3, 1.83),
                                                     (-1.3, 1.14, -1.3, 1.83)],
           lamp_z=0.95, tail_z=1.0, bumper_z=0.55, mirror_y=1.05, doors=[0.25, -0.75], door_lines=[1.05, -0.3, -1.3],
           seat_rows=[-0.1, -1.0], seat_z=0.65, dash_y=0.85)


def belt_bus(y):
    if y > 2.05:
        return 1.05 - (y - 2.05) * 0.4
    return 1.08


MINIBUS = dict(L=4.85, W=1.88, wb=2.6, r=0.34, track=1.6, tire_w=0.22, ground=0.3, belt=belt_bus,
               cabin=[(-2.38, 1.07, 1.1, 0.92, 0.9), (-2.36, 1.07, 2.05, 0.92, 0.88), (1.9, 1.07, 2.07, 0.92, 0.88),
                      (2.3, 1.06, 1.1, 0.92, 0.9)],
               roof_y=(-2.38, 2.0), roof_z=2.05, pillars=[(1.9, 2.07, 2.3, 1.1), (1.2, 1.08, 1.2, 2.05), (-0.2, 1.08, -0.2, 2.05),
                                                         (-1.4, 1.08, -1.4, 2.05)],
               lamp_z=0.8, tail_z=0.95, bumper_z=0.45, mirror_y=1.95, doors=[1.6, 0.3], door_lines=[1.95, 1.25, -0.35],
               seat_rows=[1.25, 0.2, -0.75, -1.65], seat_z=0.62, dash_y=2.0, rack=True)

for nm, sp in (("veh_berline", SEDAN), ("veh_4x4", SUV), ("veh_minibus", MINIBUS)):
    vehicle(nm, sp)
