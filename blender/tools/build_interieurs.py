# GTB : lieux dans lesquels on entre : maison du joueur, Ararat Hypermarket (nom fictif), terminal de l'aeroport.
# Lancement : blender -b --python blender/tools/build_interieurs.py -- <zone.json> <dossier_blend> <dossier_glb> [apercus]
#
# Emprises reelles lues dans le JSON de la zone (osm_import.py, cle "lieux") : murs le long du vrai contour,
# ouvertures pour les portes, toit, interieur amenage. Coordonnees : directement celles du monde (Blender X = Godot X,
# Blender Y = -Godot Z), sauf la maison construite dans son repere puis placee sur son terrain.
# Conventions lues par godot/scripts/lieux.gd :
#   *-col                 : collision (murs, sols, meubles) ;
#   porte_battante_*      : porte sur gonds (origine = gond, s'ouvre en tournant) ;
#   porte_coulissante_*_g / _d : vantail coulissant (glisse vers la gauche / la droite de la porte) ;
#   lumiere_<type>_*      : point lumineux (plafonnier, neon, ampoule) ;
#   zone_interieur_*      : boite invisible = volume interieur (eclairage d'interieur, nom du lieu) ;
#   pnj_chemin_* / pnj_caisse_* / pnj_assis_* / pnj_comptoir_* / pnj_vigile_* : places et chemins des PNJ ;
#   texte_<cle>_*         : emplacement d'un texte (enseignes, rayons, tableau des departs) ;
#   action_lit, spawn_joueur, place_zem : interactions et points de depart.
# Aucune marque reelle : enseignes et produits generiques.
import bpy
import bmesh
import json
import math
import os
import random
import sys
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
ZONE, OUT_BLEND, OUT_GLB = args[:3]
PREVIEW = args[3] if len(args) > 3 else None
LIEUX = json.load(open(ZONE, encoding="utf-8"))["lieux"]
random.seed(7)


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def reset():
    bpy.ops.wm.read_homefile(use_empty=True)


def mat(name, srgb, rough=0.7, metal=0.0, alpha=1.0, emit=0.0):
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
    if emit > 0.0:
        bsdf.inputs["Emission Color"].default_value = rgba
        bsdf.inputs["Emission Strength"].default_value = emit
    m.diffuse_color = rgba[:3] + [alpha]
    return m


class Mesh:
    """Accumulateur de geometrie (faces avec materiaux) -> un objet."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def k(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def face(self, pts, m, smooth=False):
        vs = [self.bm.verts.new(p) for p in pts]
        f = self.bm.faces.new(vs)
        f.material_index = self.k(m)
        f.smooth = smooth
        return f

    def box(self, c, s, m, rz=0.0, bottom=True):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        cz, sz = math.cos(rz), math.sin(rz)
        vs = []
        for z in (-hz, hz):
            for y in (-hy, hy):
                for x in (-hx, hx):
                    vs.append(self.bm.verts.new((c[0] + x * cz - y * sz, c[1] + x * sz + y * cz, c[2] + z)))
        idx = self.k(m)
        for f in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5))[0 if bottom else 1:]:
            self.bm.faces.new([vs[i] for i in f]).material_index = idx

    def rbox(self, c, s, m, rz=0.0, rx=0.0, bevel=0.02, seg=2, soft=False):
        """Boite aux aretes arrondies (meubles, coussins, appareils), inclinable autour de son axe X local (dossiers).
        soft : tout est lisse (coussins rebondis) ; sinon les grandes faces restent planes et seules les aretes s'arrondissent."""
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co = Vector((v.co.x * s[0], v.co.y * s[1], v.co.z * s[2]))
        b = min(bevel, min(s) * 0.45)
        if b > 0.0005:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=b, segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
        tmp.normal_update()
        mtx = Matrix.Translation(Vector(c)) @ Matrix.Rotation(rz, 4, "Z") @ Matrix.Rotation(rx, 4, "X")
        idx = self.k(m)
        vm = {}
        for v in tmp.verts:
            vm[v] = self.bm.verts.new(mtx @ v.co)
        for f in tmp.faces:
            nf = self.bm.faces.new([vm[v] for v in f.verts])
            nf.material_index = idx
            n = f.normal
            nf.smooth = soft or max(abs(n.x), abs(n.y), abs(n.z)) < 0.999
        tmp.free()

    def cyl(self, c, r, h, m, seg=12, r2=None, smooth=True, bottom=True):
        r2 = r if r2 is None else r2
        bot = [self.bm.verts.new((c[0] + r * math.cos(i / seg * math.tau), c[1] + r * math.sin(i / seg * math.tau), c[2])) for i in range(seg)]
        top = [self.bm.verts.new((c[0] + r2 * math.cos(i / seg * math.tau), c[1] + r2 * math.sin(i / seg * math.tau), c[2] + h)) for i in range(seg)]
        idx = self.k(m)
        for i in range(seg):
            j = (i + 1) % seg
            f = self.bm.faces.new((bot[i], bot[j], top[j], top[i]))
            f.material_index = idx
            f.smooth = smooth
        self.bm.faces.new(top).material_index = idx
        if bottom:
            self.bm.faces.new(bot[::-1]).material_index = idx

    def sphere(self, c, r, m, seg=8, squash=1.0):
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=seg, v_segments=max(4, seg // 2), radius=r)
        idx = self.k(m)
        vm = {}
        for v in tmp.verts:
            vm[v] = self.bm.verts.new((c[0] + v.co.x, c[1] + v.co.y, c[2] + v.co.z * squash))
        for f in tmp.faces:
            nf = self.bm.faces.new([vm[v] for v in f.verts])
            nf.material_index = idx
            nf.smooth = True
        tmp.free()

    def polygon(self, pts2, z, m, up=True):
        from mathutils.geometry import tessellate_polygon
        tris = tessellate_polygon([[Vector((p[0], p[1], 0.0)) for p in pts2]])
        idx = self.k(m)
        vs = [self.bm.verts.new((p[0], p[1], z)) for p in pts2]
        for t in tris:
            a, b, c = (pts2[i] for i in t)
            ccw = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) > 0
            order = t if ccw == up else t[::-1]
            try:
                self.bm.faces.new([vs[i] for i in order]).material_index = idx
            except ValueError:
                pass

    def empty_ok(self):
        return len(self.bm.faces) == 0

    def obj(self, parent=None):
        if self.empty_ok():
            self.bm.free()
            return None
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for mm in self.mats:
            me.materials.append(mm)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        if parent:
            ob.parent = parent
        return ob


def empty(name, loc, parent=None, rz=0.0):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.3
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    e.rotation_euler = (0, 0, rz)
    if parent:
        e.parent = parent
    return e


def save(name):
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_BLEND, name + ".blend"))
    # aucun materiau texture (sols proceduraux en coordonnees monde dans Godot) : pas d'UV, fichiers deux fois plus legers
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_GLB, name + ".glb"), export_format="GLB", export_apply=True,
                              export_yup=True, export_texcoords=False)
    faces = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print("Lieu", name, ":", faces, "faces,", len([o for o in bpy.context.scene.objects if o.type == "EMPTY"]), "reperes")


def preview(name, shots):
    if not PREVIEW:
        return
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w")
    w.color = (0.75, 0.8, 0.85)
    sc.world = w
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.light = "STUDIO"
    sc.display.shading.show_shadows = True
    sc.render.resolution_x = 1100
    sc.render.resolution_y = 700
    for o in sc.objects:
        if o.name.startswith("zone_interieur") or o.name.startswith("toit_masque"):
            o.hide_render = True
    for nm, loc, rot, lens in shots:
        c = bpy.data.cameras.new(nm)
        c.lens = lens
        c.clip_end = 2000
        o = bpy.data.objects.new(nm, c)
        sc.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = [math.radians(a) for a in rot]
        sc.camera = o
        sc.render.filepath = os.path.join(PREVIEW, f"{name}_{nm}.png")
        bpy.ops.render.render(write_still=True)


# ======================================================================= meubles
def local(cx, cy, rz):
    """Repere local d'un meuble : (x, y) -> monde, tourne de rz autour de (cx, cy)."""
    c, s = math.cos(rz), math.sin(rz)
    return lambda x, y: (cx + x * c - y * s, cy + x * s + y * c)


def sofa(hard, soft, cx, cy, rz, seats, fabric, cushion, legs_m, zf=0.0):
    """Canape (fauteuil si seats = 1), dossier vers +Y local : caisse sur pieds, accoudoirs, coussins d'assise et de dos."""
    L = local(cx, cy, rz)
    W = 0.72 * seats + 0.32
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = L(sx * (W / 2 - 0.08), sy * 0.36)
            soft.cyl((p[0], p[1], zf), 0.025, 0.09, legs_m, 8)
    p = L(0, 0.0)
    hard.rbox((p[0], p[1], zf + 0.23), (W, 0.88, 0.28), fabric, rz, bevel=0.03)
    p = L(0, 0.35)
    hard.rbox((p[0], p[1], zf + 0.62), (W - 0.2, 0.18, 0.52), fabric, rz, bevel=0.05)
    for sx in (-1, 1):
        p = L(sx * (W / 2 - 0.08), 0.0)
        hard.rbox((p[0], p[1], zf + 0.37), (0.16, 0.88, 0.56), fabric, rz, bevel=0.06, seg=3)
    for i in range(seats):
        x = -0.36 * (seats - 1) + i * 0.72
        p = L(x, -0.06)
        soft.rbox((p[0], p[1], zf + 0.44), (0.7, 0.7, 0.14), cushion, rz, bevel=0.05, seg=3, soft=True)
        p = L(x, 0.19)
        soft.rbox((p[0], p[1], zf + 0.72), (0.68, 0.16, 0.44), cushion, rz, rx=-0.2, bevel=0.06, seg=3, soft=True)


def chair_monobloc(mesh, cx, cy, rz, m):
    """Chaise en plastique moule (la chaise de toutes les cours et de tous les maquis) : dossier vers +Y local."""
    L = local(cx, cy, rz)
    p = L(0, 0)
    mesh.rbox((p[0], p[1], 0.43), (0.46, 0.44, 0.035), m, rz, bevel=0.015)
    p = L(0, 0.24)
    mesh.rbox((p[0], p[1], 0.7), (0.44, 0.035, 0.5), m, rz, rx=-0.18, bevel=0.015)
    for sx in (-1, 1):
        p = L(sx * 0.225, 0.02)
        mesh.rbox((p[0], p[1], 0.62), (0.035, 0.42, 0.03), m, rz, bevel=0.012)
        p = L(sx * 0.225, -0.18)
        mesh.cyl((p[0], p[1], 0.43), 0.015, 0.19, m, 6)
        for sy in (-1, 1):
            p = L(sx * 0.2, sy * 0.19)
            mesh.cyl((p[0], p[1], 0.0), 0.022, 0.42, m, 8, 0.017)


def table_ronde(mesh, cx, cy, r, h, m, legs_m=None):
    mesh.cyl((cx, cy, h - 0.03), r, 0.03, m, 24)
    for k in range(4):
        a = k / 4 * math.tau + math.pi / 4
        mesh.cyl((cx + math.cos(a) * r * 0.68, cy + math.sin(a) * r * 0.68, 0.0), 0.022, h - 0.03, legs_m or m, 8, 0.018)


def table_rect(mesh, legs, cx, cy, rz, w, d, h, top_m, leg_m, zf=0.0):
    L = local(cx, cy, rz)
    mesh.rbox((cx, cy, zf + h - 0.02), (w, d, 0.04), top_m, rz, bevel=0.008)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = L(sx * (w / 2 - 0.05), sy * (d / 2 - 0.05))
            legs.box((p[0], p[1], zf + (h - 0.04) / 2), (0.04, 0.04, h - 0.04), leg_m, rz)


def chair_wood(mesh, cx, cy, rz, m, zf=0.0):
    L = local(cx, cy, rz)
    p = L(0, 0)
    mesh.rbox((p[0], p[1], zf + 0.45), (0.42, 0.42, 0.03), m, rz, bevel=0.006)
    p = L(0, 0.2)
    mesh.rbox((p[0], p[1], zf + 0.72), (0.4, 0.025, 0.3), m, rz, rx=-0.08, bevel=0.006)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = L(sx * 0.18, sy * 0.18)
            hh = 0.88 if sy > 0 else 0.44
            mesh.box((p[0], p[1], zf + hh / 2), (0.03, 0.03, hh), m, rz)


# ======================================================================= outils de construction
def wall_with_openings(col, vis, a, b, z0, z1, thick, m, openings=(), glass=None, glass_band=None):
    """Mur droit de a a b (2D) ; openings : [(t_centre en m depuis a, largeur, hauteur)] ; glass_band : (z_bas, z_haut)
    -> bande vitree (pleine hauteur de vitrine) au lieu du mur, sauf aux ouvertures."""
    ax, ay = b[0] - a[0], b[1] - a[1]
    L = math.hypot(ax, ay)
    if L < 0.05:
        return
    ux, uy = ax / L, ay / L
    ang = math.atan2(uy, ux)
    cuts = sorted([(max(0.0, t - w / 2), min(L, t + w / 2), h) for t, w, h in openings])
    segs = []
    pos = 0.0
    for s0, s1, h in cuts:
        if s0 > pos:
            segs.append((pos, s0, None))
        segs.append((s0, s1, h))
        pos = s1
    if pos < L:
        segs.append((pos, L, None))
    for s0, s1, h in segs:
        mid = (s0 + s1) / 2
        cx, cy = a[0] + ux * mid, a[1] + uy * mid
        ln = s1 - s0
        if h is None:
            if glass_band:
                gz0, gz1 = glass_band
                col.box((cx, cy, (z0 + gz0) / 2), (ln, thick, gz0 - z0), m, ang)
                col.box((cx, cy, (gz1 + z1) / 2), (ln, thick, z1 - gz1), m, ang)
                if glass is not None:
                    glass.box((cx, cy, (gz0 + gz1) / 2), (ln, 0.04, gz1 - gz0), glass[1] if isinstance(glass, tuple) else GLASS, ang)
                # montants de la vitrine tous les 2 m
                n = max(1, int(ln / 2.0))
                for k in range(n + 1):
                    t = s0 + ln * k / n
                    vis.box((a[0] + ux * t, a[1] + uy * t, (gz0 + gz1) / 2), (0.08, thick + 0.02, gz1 - gz0), ALU, ang)
            else:
                col.box((cx, cy, (z0 + z1) / 2), (ln, thick, z1 - z0), m, ang)
        else:
            col.box((cx, cy, (z0 + h + z1) / 2), (ln, thick, z1 - z0 - h), m, ang)  # linteau au-dessus de l'ouverture


def oriented_rect(poly):
    """Rectangle d'aire minimale : centre, axe u, axe v, demi-longueurs (hu >= hv)."""
    best = None
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        c, s = math.cos(ang), math.sin(ang)
        xs = [p[0] * c + p[1] * s for p in poly]
        ys = [-p[0] * s + p[1] * c for p in poly]
        ar = (max(xs) - min(xs)) * (max(ys) - min(ys))
        if best is None or ar < best[0]:
            best = (ar, c, s, min(xs), max(xs), min(ys), max(ys))
    _, c, s, x0, x1, y0, y1 = best
    cu, cv = (x0 + x1) / 2, (y0 + y1) / 2
    center = (cu * c - cv * s, cu * s + cv * c)
    u, v, hu, hv = (c, s), (-s, c), (x1 - x0) / 2, (y1 - y0) / 2
    if hv > hu:
        u, v, hu, hv = v, (-u[0], -u[1]), hv, hu
    return center, u, v, hu, hv


def point_in_poly(p, poly):
    x, y = p
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            inside = not inside
    return inside


def dist_to_poly_edges(p, poly):
    best = 1e9
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        l2 = dx * dx + dy * dy or 1e-9
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2))
        best = min(best, math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy))
    return best


def rect_inside(poly, c, u, v, hu, hv, margin):
    for a, b in ((-1, -1), (1, -1), (1, 1), (-1, 1), (0, 0)):
        q = (c[0] + u[0] * a * hu + v[0] * b * hv, c[1] + u[1] * a * hu + v[1] * b * hv)
        if not point_in_poly(q, poly) or (a or b) and dist_to_poly_edges(q, poly) < margin:
            return False
    return True


def bl(p):
    """Godot (x, z) -> Blender (x, y)."""
    return (p[0], -p[1])


def mats_common():
    global GLASS, ALU
    GLASS = mat("mat_vitre_interieur", (0.6, 0.7, 0.75), 0.05, 0.0, alpha=0.28)
    ALU = mat("mat_alu", (0.72, 0.73, 0.75), 0.35, 0.8)
    return {
        "glass": GLASS, "alu": ALU,
        "plaster_ext": mat("mat_enduit_ext", (0.9, 0.86, 0.76), 0.85),
        "plaster_int": mat("mat_enduit_int", (0.94, 0.93, 0.9), 0.8),
        "tiles": mat("mat_carrelage", (0.86, 0.84, 0.8), 0.25),
        "terrazzo": mat("mat_terrazzo", (0.78, 0.76, 0.72), 0.2),
        "concrete": mat("mat_beton_lisse", (0.62, 0.62, 0.6), 0.8),
        "wood": mat("mat_bois_porte", (0.45, 0.28, 0.16), 0.6),
        "wood_light": mat("mat_bois_clair", (0.68, 0.5, 0.32), 0.6),
        "metal_blue": mat("mat_metal_bleu", (0.12, 0.3, 0.6), 0.5, 0.4),
        "metal_dark": mat("mat_metal_sombre", (0.18, 0.18, 0.2), 0.5, 0.6),
        "steel": mat("mat_inox", (0.75, 0.76, 0.78), 0.25, 0.9),
        "black": mat("mat_noir", (0.05, 0.05, 0.06), 0.4),
        "screen": mat("mat_ecran", (0.05, 0.12, 0.25), 0.1, emit=0.8),
        "light_panel": mat("mat_neon", (0.98, 0.98, 0.95), 0.2, emit=3.0),
        "ceiling": mat("mat_plafond", (0.92, 0.92, 0.9), 0.9),
        "tin": mat("mat_tole_toit", (0.6, 0.6, 0.62), 0.5, 0.6),
        "sand": mat("mat_sable_cour", (0.8, 0.68, 0.5), 1.0),
        "fabric_red": mat("mat_tissu_rouge", (0.55, 0.12, 0.1), 0.95),
        "fabric_brown": mat("mat_tissu_brun", (0.42, 0.28, 0.18), 0.95),
        "fabric_blue": mat("mat_tissu_bleu", (0.15, 0.3, 0.55), 0.95),
        "white_plastic": mat("mat_plastique_blanc", (0.93, 0.93, 0.9), 0.5),
        "red_plastic": mat("mat_plastique_rouge", (0.8, 0.1, 0.08), 0.5),
        "blue_plastic": mat("mat_plastique_bleu", (0.1, 0.35, 0.75), 0.5),
        "green_plastic": mat("mat_plastique_vert", (0.1, 0.5, 0.25), 0.5),
        "yellow_plastic": mat("mat_plastique_jaune", (0.95, 0.75, 0.1), 0.5),
        "faience": mat("mat_faience", (0.75, 0.86, 0.9), 0.15),
        "mattress": mat("mat_drap", (0.92, 0.9, 0.85), 0.9),
        "net": mat("mat_moustiquaire", (0.95, 0.95, 0.95), 0.9, alpha=0.25),
        "sign_red": mat("mat_panneau_rouge", (0.75, 0.08, 0.08), 0.5),
        "sign_green": mat("mat_panneau_vert", (0.05, 0.45, 0.25), 0.5),
        "sign_blue": mat("mat_panneau_bleu", (0.05, 0.22, 0.5), 0.5),
        "conveyor": mat("mat_tapis", (0.08, 0.08, 0.08), 0.8),
        "seat_blue": mat("mat_siege_bleu", (0.1, 0.25, 0.55), 0.6),
        "shelf": mat("mat_etagere", (0.8, 0.8, 0.78), 0.5, 0.3),
        "fridge_light": mat("mat_frigo_lumiere", (0.95, 0.97, 1.0), 0.2, emit=1.6),
        "bread": mat("mat_pain", (0.82, 0.6, 0.3), 0.8),
        "earth": mat("mat_terre_pot", (0.45, 0.28, 0.18), 1.0),
        "leaf": mat("mat_feuille", (0.2, 0.45, 0.18), 0.8),
        "gas": mat("mat_bouteille_gaz", (0.15, 0.4, 0.7), 0.5, 0.3),
        "products": [mat("mat_produit_%d" % i, c, 0.5) for i, c in enumerate([
            (0.85, 0.15, 0.1), (0.95, 0.75, 0.1), (0.1, 0.4, 0.75), (0.95, 0.95, 0.92), (0.1, 0.55, 0.3),
            (0.95, 0.5, 0.1), (0.55, 0.2, 0.6), (0.3, 0.7, 0.9)])],
        "fruits": [mat("mat_fruit_%d" % i, c, 0.6) for i, c in enumerate([
            (0.95, 0.6, 0.05), (0.95, 0.85, 0.2), (0.2, 0.55, 0.15), (0.85, 0.2, 0.1), (0.6, 0.4, 0.15)])],
    }


# ======================================================================= maison du joueur
def build_maison(info):
    reset()
    M = mats_common()
    W, D = info["w"], info["d"]
    cx, cy = bl(info["center"])
    fdx, fdy = info["front_dir"][0], -info["front_dir"][1]       # direction de la rue (Blender)
    theta = math.atan2(fdx, -fdy)                                 # le -Y local regarde la rue
    root = empty("maison_racine", (cx, cy, 0), None, theta)
    col = Mesh("maison_structure-col")
    vis = Mesh("maison_details")
    fur = Mesh("maison_meubles-col")
    deco = Mesh("maison_deco")
    glass = Mesh("maison_vitres")
    hx, hy = W / 2, D / 2
    # --- sols : cour en sable, dallage devant la maison, carrelage a l'interieur ---
    col.box((0, 0, 0.012), (W - 0.2, D - 0.2, 0.024), M["sand"])
    # mur d'enceinte (2,2 m) avec portail (3,2 m) et portillon cote rue
    wall_h, t = 2.2, 0.2
    front = [(-hx, -hy), (hx, -hy)]
    wall_with_openings(col, vis, front[0], front[1], 0, wall_h, t, M["plaster_ext"], openings=[(W / 2 - 2.0, 3.2, 2.2), (W / 2 + 2.6, 1.0, 2.2)])
    for a, b in (((hx, -hy), (hx, hy)), ((hx, hy), (-hx, hy)), ((-hx, hy), (-hx, -hy))):
        wall_with_openings(col, vis, a, b, 0, wall_h, t, M["plaster_ext"])
    # chaperon du mur et tessons
    for a, b in (((-hx, -hy), (hx, -hy)), ((hx, -hy), (hx, hy)), ((hx, hy), (-hx, hy)), ((-hx, hy), (-hx, -hy))):
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        vis.box((mx, my, wall_h + 0.03), (L + 0.1, t + 0.08, 0.06), M["concrete"], ang)
    # portail metallique bleu (2 vantaux) + portillon : portes battantes animees dans Godot
    gx = -2.0
    for side, sgn in (("g", -1), ("d", 1)):
        hinge = (gx + sgn * 1.6, -hy)
        e = empty(f"porte_battante_portail_{side}", (hinge[0], hinge[1], 0), root)
        leaf = Mesh(f"porte_battante_portail_{side}_vantail")
        w2 = 1.58
        leaf.box((-sgn * w2 / 2, 0, 1.05), (w2, 0.06, 1.9), M["metal_blue"])
        for k in range(6):
            leaf.box((-sgn * (0.12 + k * 0.27), -0.04, 1.05), (0.04, 0.03, 1.85), M["metal_dark"])
        o = leaf.obj(e)
        e.name = f"porte_battante_portail_{side}"
    e = empty("porte_battante_portillon", (2.6 - 0.5, -hy, 0), root)
    leaf = Mesh("porte_battante_portillon_vantail")
    leaf.box((0.48, 0, 1.0), (0.96, 0.05, 1.95), M["metal_blue"])
    leaf.obj(e)
    # --- maison (12 x 8 m) au fond de la cour, veranda devant ---
    bw, bd, bh = 12.0, 7.6, 3.2
    by0 = hy - 0.6 - bd          # facade avant de la maison
    by1 = hy - 0.6
    bx0, bx1 = -bw / 2, bw / 2
    col.box((0, (by0 + by1) / 2, 0.04), (bw, bd, 0.08), M["tiles"])                 # dalle interieure (carrelage)
    col.box((0, by0 - 1.25, 0.025), (bw, 2.5, 0.05), M["tiles"])                    # veranda carrelee (marches de 3 cm)
    # facade avant avec porte d'entree (1,4 m) et deux fenetres (salon, cuisine)
    z0 = 0.08
    wall_with_openings(col, vis, (bx0, by0), (bx1, by0), z0, bh, 0.2, M["plaster_ext"],
                       openings=[(bw / 2, 1.4, 2.2), (2.0, 1.4, 2.05), (bw - 2.0, 1.4, 2.05)])
    for fx in (bx0 + 2.0, bx1 - 2.0):
        col.box((fx, by0, z0 + 0.47), (1.4, 0.2, 0.94), M["plaster_ext"])           # allege sous la fenetre
    # cote droit : fenetre de cuisine ; arriere : douche (petite, haute), chambre, salon ; cote gauche : salon
    wall_with_openings(col, vis, (bx1, by0), (bx1, by1), z0, bh, 0.2, M["plaster_ext"], openings=[(1.8, 1.2, 2.05)])
    col.box((bx1, by0 + 1.8, z0 + 0.47), (0.2, 1.2, 0.94), M["plaster_ext"])
    wall_with_openings(col, vis, (bx1, by1), (bx0, by1), z0, bh, 0.2, M["plaster_ext"],
                       openings=[(1.0, 0.6, 2.05), (3.6, 1.2, 2.05), (8.5, 1.2, 2.05)])
    col.box((bx1 - 1.0, by1, z0 + 0.77), (0.6, 0.2, 1.54), M["plaster_ext"])
    col.box((bx1 - 3.6, by1, z0 + 0.47), (1.2, 0.2, 0.94), M["plaster_ext"])
    col.box((bx1 - 8.5, by1, z0 + 0.47), (1.2, 0.2, 0.94), M["plaster_ext"])
    wall_with_openings(col, vis, (bx0, by1), (bx0, by0), z0, bh, 0.2, M["plaster_ext"], openings=[(3.8, 1.2, 2.05)])
    col.box((bx0, by1 - 3.8, z0 + 0.47), (0.2, 1.2, 0.94), M["plaster_ext"])
    # fenetres : persiennes en verre (naco) + grilles de securite
    for (px, py, ang, w2, zb) in ((bx0 + 2.0, by0, 0, 1.4, 1.02), (bx1 - 2.0, by0, 0, 1.4, 1.02), (bx1, by0 + 1.8, math.pi / 2, 1.2, 1.02),
                                  (bx0, by1 - 3.8, math.pi / 2, 1.2, 1.02), (bx1 - 3.6, by1, 0, 1.2, 1.02), (bx1 - 8.5, by1, 0, 1.2, 1.02),
                                  (bx1 - 1.0, by1, 0, 0.6, 1.62)):
        for k in range(8 if zb < 1.5 else 4):
            glass.box((px, py, zb + 0.08 + k * 0.13), (w2 - 0.06, 0.012, 0.1), GLASS, ang)
        for k in range(int(w2 / 0.15)):
            off = -w2 / 2 + 0.075 + k * 0.15
            vis.box((px + math.cos(ang) * off, py + math.sin(ang) * off, zb + (2.13 - zb) / 2), (0.018, 0.25, 2.13 - zb), M["metal_dark"], ang)
    # cloisons : salon (gauche) ; cuisine (avant droite) ; chambre (arriere) avec douche-WC attenante (arriere droite)
    zt = z0
    wall_with_openings(col, vis, (1.0, by0), (1.0, by1), zt, bh, 0.12, M["plaster_int"], openings=[(1.8, 0.9, 2.05), (5.6, 0.9, 2.05)])
    wall_with_openings(col, vis, (1.0, by0 + 3.6), (bx1, by0 + 3.6), zt, bh, 0.12, M["plaster_int"])
    wall_with_openings(col, vis, (4.2, by0 + 3.6), (4.2, by1), zt, bh, 0.12, M["plaster_int"], openings=[(2.0, 0.8, 2.05)])
    # plafond et toit-terrasse avec parapet et citerne noire (comme les voisins)
    col.box((0, (by0 + by1) / 2, bh + 0.1), (bw + 0.3, bd + 0.3, 0.2), M["concrete"])
    deco.box((0, (by0 + by1) / 2, bh - 0.005), (bw - 0.2, bd - 0.2, 0.01), M["ceiling"])
    for a, b in (((bx0, by0), (bx1, by0)), ((bx1, by0), (bx1, by1)), ((bx1, by1), (bx0, by1)), ((bx0, by1), (bx0, by0))):
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        col.box((mx, my, bh + 0.6), (L + 0.3, 0.18, 0.8), M["plaster_ext"], math.atan2(b[1] - a[1], b[0] - a[0]))
    vis.cyl((bx1 - 2.0, by1 - 1.6, bh + 0.2), 0.75, 1.5, M["black"], 16)
    # veranda : auvent en tole sur poteaux
    for px in (bx0 + 0.3, -1.9, 1.9, bx1 - 0.3):           # jamais de poteau dans l axe de la porte
        col.box((px, by0 - 2.3, 1.45), (0.18, 0.18, 2.9), M["plaster_ext"])
    vis.box((0, by0 - 1.25, 2.95), (bw + 0.4, 2.8, 0.06), M["tin"])
    # porte d'entree (double, bois)
    for side, sgn in (("g", -1), ("d", 1)):
        e = empty(f"porte_battante_entree_{side}", (sgn * 0.7, by0, 0.12), root)
        leaf = Mesh(f"porte_battante_entree_{side}_vantail")
        leaf.box((-sgn * 0.345, 0, 1.05), (0.69, 0.05, 2.10), M["wood"])
        leaf.box((-sgn * 0.6, -0.04, 1.05), (0.03, 0.04, 0.12), M["steel"])
        leaf.obj(e)
    # --- meubles ---
    # salon (x de -6 a 1) : canape + 2 fauteuils, table basse, meuble tele et tele, buffet, ventilateur au plafond
    sx0, sy0 = bx0 + 0.3, by0 + 0.4
    z0 = 0.08
    # canape trois places contre le mur du fond, deux fauteuils contre le mur de gauche (tissu et coussins assortis)
    cush_brown = mat("mat_coussin_brun", (0.5, 0.34, 0.22), 0.95)
    cush_red = mat("mat_coussin_rouge", (0.62, 0.16, 0.12), 0.95)
    sofa(fur, deco, sx0 + 2.6, by1 - 0.55, 0.0, 3, M["fabric_brown"], cush_brown, M["wood"], z0)
    for fy in (by0 + 2.4, by0 + 4.5):
        sofa(fur, deco, sx0 + 0.38, fy, math.pi / 2, 1, M["fabric_red"], cush_red, M["wood"], z0)
    # table basse : plateau de verre sur cadre en bois, napperon
    fur.rbox((sx0 + 2.6, by0 + 3.6, z0 + 0.4), (1.2, 0.65, 0.012), GLASS, 0.0, bevel=0.004)
    vis.rbox((sx0 + 2.6, by0 + 3.6, z0 + 0.375), (1.16, 0.61, 0.04), M["wood"], 0.0, bevel=0.006)
    for dx, dy in ((-0.55, -0.28), (0.55, -0.28), (-0.55, 0.28), (0.55, 0.28)):
        vis.box((sx0 + 2.6 + dx, by0 + 3.6 + dy, z0 + 0.18), (0.045, 0.045, 0.36), M["wood"])
    deco.rbox((sx0 + 2.6, by0 + 3.6, z0 + 0.41), (0.5, 0.3, 0.004), M["mattress"], 0.0, bevel=0.002)
    # meuble tele (deux portes, plateau) et ecran plat sur pied
    fur.rbox((sx0 + 2.6, by0 + 0.4, z0 + 0.27), (1.8, 0.45, 0.54), M["wood"], 0.0, bevel=0.012)
    for dx in (-0.45, 0.45):
        vis.box((sx0 + 2.6 + dx, by0 + 0.625, z0 + 0.27), (0.86, 0.006, 0.48), M["wood_light"])
        vis.box((sx0 + 2.6 + dx * 0.2, by0 + 0.635, z0 + 0.3), (0.012, 0.012, 0.12), M["steel"])
    deco.box((sx0 + 2.6, by0 + 0.38, z0 + 0.56), (0.32, 0.2, 0.02), M["black"])
    deco.box((sx0 + 2.6, by0 + 0.36, z0 + 0.63), (0.05, 0.03, 0.14), M["black"])
    deco.rbox((sx0 + 2.6, by0 + 0.36, z0 + 0.97), (1.12, 0.05, 0.66), M["black"], 0.0, bevel=0.01)
    deco.box((sx0 + 2.6, by0 + 0.385, z0 + 0.97), (1.06, 0.004, 0.6), M["screen"])
    # buffet vitre avec vaisselle et bibelots : contre le mur du fond, a droite du canape (jamais devant la porte d'entree)
    bfx, bfy = sx0 + 5.3, by1 - 0.33
    fur.rbox((bfx, bfy, z0 + 0.55), (1.2, 0.42, 1.1), M["wood_light"], 0.0, bevel=0.012)
    vis.box((bfx, bfy - 0.215, z0 + 0.8), (1.1, 0.006, 0.5), GLASS)
    vis.box((bfx, bfy - 0.215, z0 + 0.3), (1.1, 0.006, 0.45), M["wood"])
    for k in range(4):
        deco.cyl((bfx - 0.38 + k * 0.25, bfy - 0.05, z0 + 0.62), 0.05, 0.05, M["white_plastic"], 10)     # assiettes
    for k in range(3):
        deco.cyl((bfx - 0.4 + k * 0.4, bfy, z0 + 1.1), 0.045, 0.22, M["products"][k], 8, 0.03)    # bibelots / bouteilles
    # tapis au sol
    deco.box((sx0 + 2.6, by0 + 3.4, z0 + 0.004), (2.6, 1.8, 0.006), mat("mat_tapis_salon", (0.55, 0.22, 0.15), 0.95))
    deco.cyl((sx0 + 2.6, by0 + 3.6, bh - 0.45), 0.08, 0.45, M["white_plastic"], 8)              # ventilateur
    for k in range(3):
        a = k / 3 * math.tau
        deco.box((sx0 + 2.6 + math.cos(a) * 0.45, by0 + 3.6 + math.sin(a) * 0.45, bh - 0.5), (0.85, 0.12, 0.015), M["white_plastic"], a)
    empty("lumiere_ampoule_salon", (sx0 + 2.6, by0 + 2.0, bh - 0.3), root)
    # rideaux aux fenetres du salon
    deco.box((bx0 + 2.0, by0 + 0.14, 1.7), (1.8, 0.03, 1.4), M["fabric_blue"])
    # chambre (x de 1 a 4,2, arriere) : lit double + moustiquaire contre le mur du fond, armoire
    bxc = 2.65
    pagne = mat("mat_pagne_lit", (0.75, 0.35, 0.1), 0.9)
    fur.rbox((bxc, by1 - 1.15, z0 + 0.24), (1.5, 2.0, 0.2), M["wood"], 0.0, bevel=0.015)        # cadre du lit
    for sx in (-1, 1):
        for sy in (-1, 1):
            vis.box((bxc + sx * 0.7, by1 - 1.15 + sy * 0.95, z0 + 0.07), (0.07, 0.07, 0.14), M["wood"])
    fur.rbox((bxc, by1 - 1.15, z0 + 0.43), (1.42, 1.92, 0.2), M["mattress"], 0.0, bevel=0.06, seg=3, soft=True)
    deco.rbox((bxc, by1 - 1.5, z0 + 0.535), (1.48, 1.3, 0.025), pagne, 0.0, bevel=0.01, soft=True)   # pagne en couvre-lit
    fur.rbox((bxc, by1 - 0.15, z0 + 0.6), (1.6, 0.06, 1.0), M["wood"], 0.0, bevel=0.02)           # tete de lit
    for sx in (-0.36, 0.36):
        deco.rbox((bxc + sx, by1 - 0.42, z0 + 0.6), (0.6, 0.34, 0.13), M["mattress"], 0.0, bevel=0.06, seg=3, soft=True)   # oreillers
    net = Mesh("maison_moustiquaire")
    # moustiquaire en tente : du cadre du lit (bord arriere contre le mur) jusqu'a l'anneau suspendu au plafond
    lo = [(bxc - 0.8, by1 - 2.18), (bxc + 0.8, by1 - 2.18), (bxc + 0.8, by1 - 0.12), (bxc - 0.8, by1 - 0.12)]
    hi = [(bxc - 0.22, by1 - 0.95), (bxc + 0.22, by1 - 0.95), (bxc + 0.22, by1 - 0.5), (bxc - 0.22, by1 - 0.5)]
    zl, zh = z0 + 0.25, bh - 0.55
    for i in range(4):
        j = (i + 1) % 4
        net.face([(lo[i][0], lo[i][1], zl), (lo[j][0], lo[j][1], zl), (hi[j][0], hi[j][1], zh), (hi[i][0], hi[i][1], zh)], M["net"])
    net.face([(p[0], p[1], zh) for p in hi], M["net"])
    deco.box((bxc, by1 - 0.72, (zh + bh) / 2), (0.01, 0.01, bh - zh), M["white_plastic"])          # cordon
    net.obj(root)
    empty("action_lit", (bxc, by1 - 2.45, 0.1), root)
    fur.rbox((1.42, by0 + 4.35, z0 + 1.0), (0.58, 1.2, 2.0), M["wood_light"], 0.0, bevel=0.015)   # armoire deux portes
    vis.box((1.715, by0 + 4.35, z0 + 1.0), (0.008, 0.012, 1.9), M["wood"])
    for dy in (-0.06, 0.06):
        vis.box((1.725, by0 + 4.35 + dy, z0 + 1.05), (0.02, 0.015, 0.2), M["steel"])
    vis.box((1.42, by0 + 4.35, z0 + 2.04), (0.62, 1.24, 0.06), M["wood"])
    empty("lumiere_ampoule_chambre", (bxc, by0 + 5.6, bh - 0.3), root)
    # douche-WC (x de 4,2 a 6, arriere) : faience, cuvette, seau, pommeau
    for a, b in (((4.3, by1 - 0.12), (5.9, by1 - 0.12)), ((5.88, by0 + 3.7), (5.88, by1 - 0.1))):
        L2 = math.hypot(b[0] - a[0], b[1] - a[1])
        deco.box(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, z0 + 0.8), (L2, 0.01, 1.6), M["faience"], math.atan2(b[1] - a[1], b[0] - a[0]))
    fur.box((5.5, by1 - 0.55, z0 + 0.22), (0.45, 0.6, 0.44), M["white_plastic"])               # cuvette
    deco.cyl((4.65, by1 - 0.45, z0), 0.18, 0.3, M["blue_plastic"], 12)                          # seau
    deco.cyl((5.7, by0 + 4.3, z0 + 1.9), 0.06, 0.04, M["steel"], 8)                             # pommeau
    empty("lumiere_ampoule_douche", (5.1, by0 + 5.6, bh - 0.2), root)
    # cuisine (x de 1 a 6, avant) : plan de travail + rechaud + bouteille de gaz, frigo, bidons d'eau
    kx0 = 3.9
    fur.rbox((kx0 + 1.05, by0 + 3.2, z0 + 0.43), (1.9, 0.58, 0.86), M["wood_light"], 0.0, bevel=0.01)   # placards
    deco.rbox((kx0 + 1.05, by0 + 3.18, z0 + 0.88), (1.96, 0.64, 0.04), mat("mat_granit", (0.22, 0.2, 0.2), 0.3), 0.0, bevel=0.006)
    for k in range(3):
        vis.box((kx0 + 0.42 + k * 0.63, by0 + 2.905, z0 + 0.43), (0.6, 0.006, 0.78), M["wood"])
        vis.box((kx0 + 0.42 + k * 0.63, by0 + 2.895, z0 + 0.72), (0.12, 0.012, 0.012), M["steel"])
    deco.rbox((kx0 + 1.05, by0 + 3.47, z0 + 1.2), (1.9, 0.02, 0.6), M["faience"], 0.0, bevel=0.004)      # credence
    deco.box((kx0 + 0.6, by0 + 3.2, z0 + 0.93), (0.55, 0.45, 0.06), M["steel"])                 # rechaud 2 feux
    deco.cyl((kx0 + 0.15, by0 + 2.75, z0), 0.16, 0.55, M["gas"], 12)                            # bouteille de gaz
    deco.cyl((kx0 + 1.5, by0 + 3.2, z0 + 0.93), 0.13, 0.18, M["steel"], 12)                     # marmite
    fur.rbox((kx0 + 1.75, by0 + 0.5, z0 + 0.85), (0.6, 0.62, 1.7), M["white_plastic"], 0.0, bevel=0.03)   # frigo
    vis.box((kx0 + 1.75, by0 + 0.815, z0 + 1.22), (0.58, 0.006, 0.01), M["metal_dark"])
    for zh in (0.95, 1.45):
        vis.box((kx0 + 1.98, by0 + 0.83, z0 + zh), (0.025, 0.025, 0.3), M["steel"])
    for k in range(3):
        deco.cyl((1.5 + k * 0.38, by0 + 0.4, z0), 0.15, 0.45, M["yellow_plastic"], 10)          # bidons d'eau
    table_rect(fur, vis, 2.3, by0 + 2.0, 0.0, 1.0, 0.7, 0.76, M["wood_light"], M["wood"], z0)         # table et chaises
    deco.box((2.3, by0 + 2.0, z0 + 0.762), (0.9, 0.6, 0.004), mat("mat_toile_ciree", (0.85, 0.75, 0.3), 0.4))
    for cyy, crz in ((by0 + 1.35, math.pi), (by0 + 2.65, 0.0)):
        chair_wood(fur, 2.3, cyy, crz, M["wood"], z0)
    empty("lumiere_neon_cuisine", (3.2, by0 + 1.8, bh - 0.2), root)
    empty("lumiere_ampoule_veranda", (0, by0 - 1.2, 2.85), root)
    # cour : chaises et table en plastique, fil a linge, compteur electrique, manguier (en pot... non : en terre)
    for cxp, crz in ((-4.6, 0.25), (-3.4, -0.2)):
        chair_monobloc(fur, cxp, by0 - 4.15, crz, M["white_plastic"])
    chair_monobloc(fur, -5.2, by0 - 5.3, math.pi / 2 + 0.3, M["white_plastic"])
    table_ronde(fur, -4.0, by0 - 5.0, 0.45, 0.72, M["white_plastic"])
    for px in (hx - 0.5, hx - 6.5):
        vis.box((px, -hy + 4.0, 0.9), (0.06, 0.06, 1.8), M["metal_dark"])
    vis.box((hx - 3.5, -hy + 4.0, 1.75), (6.0, 0.01, 0.01), M["metal_dark"])
    for k in range(4):
        deco.box((hx - 1.3 - k * 1.3, -hy + 4.0, 1.4), (0.9, 0.02, 0.7), M["products"][k + 1])   # linge qui seche
    vis.box((hx - 0.2, -hy + 1.0, 1.5), (0.1, 0.3, 0.4), M["white_plastic"])                   # compteur
    tree = Mesh("maison_manguier-col")
    tree.cyl((hx - 3.0, by0 - 3.2, 0.0), 0.22, 2.4, M["wood"], 10, 0.16)
    tree.obj(root)
    crown = Mesh("maison_manguier_feuillage")
    for k in range(7):
        a = k / 7 * math.tau
        crown.sphere((hx - 3.0 + math.cos(a) * 1.2, by0 - 3.2 + math.sin(a) * 1.2, 3.2 + (k % 2) * 0.4), 1.1, M["leaf"], 8, 0.8)
    crown.sphere((hx - 3.0, by0 - 3.2, 3.9), 1.3, M["leaf"], 8, 0.8)
    crown.obj(root)
    empty("place_zem", (-3.6, -hy + 3.0, 0.0), root, math.pi / 2)
    empty("spawn_joueur", (0.0, by0 - 2.2, 0.15), root, 0.0)
    # volume interieur (eclairage d'interieur) et nom du lieu
    zi = Mesh("zone_interieur_maison")
    zi.box((0, (by0 + by1) / 2, bh / 2), (bw - 0.3, bd - 0.3, bh - 0.1), M["plaster_int"])
    zi.obj(root)
    for o in (col, vis, fur, deco, glass):
        o.obj(root)
    save("lieu_maison")
    preview("lieu_maison", [("dessus", (cx, cy - 2, 32), (0, 0, math.degrees(theta)), 30),
                            ("cour", (cx + math.sin(theta) * 9 + math.cos(theta) * 6, cy - math.cos(theta) * 9 + math.sin(theta) * 6, 2.6),
                             (80, 0, math.degrees(theta) + 30), 24)])


# ======================================================================= batiment a interieur sur emprise reelle
def shell(poly_b, h_shell, h_int, entrance_edges, M, wall_m, door_w, glass_front=False, name="lieu", door_h=2.5):
    """Murs le long du vrai contour (ouvertures sur les aretes d'entree), sol, plafond interieur, toit."""
    col = Mesh(name + "_structure-col")
    vis = Mesh(name + "_details")
    glass = Mesh(name + "_vitres")
    n = len(poly_b)
    doors = []
    for i in range(n):
        a, b = poly_b[i], poly_b[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        openings = []
        if i in entrance_edges and L > door_w + 2:
            openings = [(L / 2, door_w, door_h)]
            ux, uy = (b[0] - a[0]) / L, (b[1] - a[1]) / L
            doors.append(((a[0] + ux * L / 2, a[1] + uy * L / 2), (ux, uy)))
        band = (0.45, 4.2) if (glass_front and i in entrance_edges) else None
        wall_with_openings(col, vis, a, b, 0.0, h_shell, 0.3, wall_m, openings=openings, glass=glass if band else None, glass_band=band)
    col.polygon(poly_b, 0.03, M["terrazzo"], up=True)
    col.polygon(poly_b, h_int, M["ceiling"], up=False)        # plafond interieur (face vers le bas)
    col.polygon(poly_b, h_shell, M["concrete"], up=True)      # toit-terrasse
    for i in range(n):
        a, b = poly_b[i], poly_b[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        vis.box(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, h_shell + 0.5), (L + 0.3, 0.25, 1.0), wall_m, math.atan2(b[1] - a[1], b[0] - a[0]))
    return col, vis, glass, doors


def sliding_door(name, mid, u, width, height, M):
    """Porte automatique vitree a deux vantaux (s'ouvrent quand quelqu'un approche, dans Godot)."""
    ang = math.atan2(u[1], u[0])
    for side, sgn in (("g", -1), ("d", 1)):
        c = (mid[0] + u[0] * sgn * width / 4, mid[1] + u[1] * sgn * width / 4)
        e = empty(f"porte_coulissante_{name}_{side}", (c[0], c[1], 0.0), None, ang)
        leaf = Mesh(f"porte_coulissante_{name}_{side}_vantail")
        leaf.box((0, 0, height / 2 + 0.03), (width / 2 - 0.04, 0.04, height - 0.06), GLASS)
        leaf.box((0, 0, height - 0.06), (width / 2, 0.08, 0.1), ALU)
        leaf.box((0, 0, 0.06), (width / 2, 0.08, 0.1), ALU)
        for k in (-1, 1):
            leaf.box((k * (width / 4 - 0.03), 0, height / 2), (0.06, 0.08, height), ALU)
        leaf.obj(e)


def inward(poly_b, mid, u):
    n = (-u[1], u[0])
    test = (mid[0] + n[0] * 1.0, mid[1] + n[1] * 1.0)
    return n if point_in_poly(test, poly_b) else (-n[0], -n[1])


def label(name, p, rz, z):
    empty(name, (p[0], p[1], z), None, rz)


def pick_entrance(poly_b, target_b, count=1):
    """Aretes les plus longues tournees vers le point 'target' (rue, parvis)."""
    n = len(poly_b)
    scored = []
    for i in range(n):
        a, b = poly_b[i], poly_b[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        d = math.hypot(mid[0] - target_b[0], mid[1] - target_b[1])
        scored.append((d - L * 0.3, i))
    scored.sort()
    return [i for _, i in scored[:count]]


# ======================================================================= Ararat Hypermarket
def build_ararat(info, road_target):
    reset()
    M = mats_common()
    poly = [bl(p) for p in info["pts"]]
    if sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly))) < 0:
        poly = poly[::-1]
    entr = pick_entrance(poly, road_target)
    col, vis, glass, doors = shell(poly, 9.0, 5.5, entr, M, M["plaster_ext"], 2.8, glass_front=True, name="ararat", door_h=2.5)
    fur = Mesh("ararat_mobilier-col")
    goods = Mesh("ararat_produits")
    price_strip = mat("mat_porte_etiquette", (0.95, 0.85, 0.2), 0.5)
    deco = Mesh("ararat_deco")
    (dmid, du) = doors[0]
    dn = inward(poly, dmid, du)
    sliding_door("ararat", dmid, du, 2.8, 2.5, M)
    # enseigne au-dessus de l'entree (texte pose par Godot)
    ang = math.atan2(du[1], du[0])
    out = (-dn[0], -dn[1])
    vis.box((dmid[0] + out[0] * 0.3, dmid[1] + out[1] * 0.3, 6.6), (22.0, 0.3, 2.4), M["sign_green"], ang)
    label("texte_ararat_enseigne", (dmid[0] + out[0] * 0.5, dmid[1] + out[1] * 0.5), ang + math.pi, 6.9)
    label("texte_ararat_slogan", (dmid[0] + out[0] * 0.5, dmid[1] + out[1] * 0.5), ang + math.pi, 5.95)
    # repere du magasin : X le long de la facade d'entree, Y vers l'interieur
    def P(x, y):
        return (dmid[0] + du[0] * x + dn[0] * y, dmid[1] + du[1] * x + dn[1] * y)

    def inside(x, y, m=1.2):
        q = P(x, y)
        return point_in_poly(q, poly) and dist_to_poly_edges(q, poly) > m

    # vigile a l'entree, caisses a 7 m de l'entree
    empty("pnj_vigile_entree", (P(4.2, 2.0)[0], P(4.2, 2.0)[1], 0.03), None, ang + math.pi)
    tills = 0
    for k in range(-5, 6):
        x = k * 3.2
        if not inside(x, 8.0, 2.0) or abs(x) < 1.5:
            continue
        # meuble de caisse : caissiere cote -X, client cote +X ; tapis (fond du magasin) -> scanner -> zone d'emballage
        c = P(x, 8.0)
        fur.rbox((c[0], c[1], 0.41), (0.75, 2.6, 0.82), M["white_plastic"], ang, bevel=0.015)
        vis.box((c[0], c[1], 0.04), (0.77, 2.62, 0.08), M["sign_green"], ang)
        q = P(x + 0.05, 8.65)
        deco.box((q[0], q[1], 0.832), (0.45, 1.3, 0.025), M["conveyor"], ang)
        for sx in (-0.26, 0.29):
            q = P(x + sx, 8.65)
            deco.box((q[0], q[1], 0.85), (0.025, 1.3, 0.06), M["steel"], ang)
        q = P(x + 0.05, 7.85)
        deco.box((q[0], q[1], 0.822), (0.36, 0.3, 0.006), M["black"], ang)                     # scanner
        q = P(x + 0.05, 7.1)
        deco.box((q[0], q[1], 0.825), (0.62, 0.72, 0.012), M["steel"], ang)                    # emballage
        q = P(x - 0.25, 8.0)
        deco.box((q[0], q[1], 0.97), (0.04, 0.04, 0.3), M["metal_dark"], ang)
        deco.rbox((q[0], q[1], 1.2), (0.035, 0.34, 0.25), M["black"], ang, bevel=0.008)        # ecran caissiere
        q = P(x - 0.27, 8.0)
        deco.box((q[0], q[1], 1.2), (0.004, 0.3, 0.21), M["screen"], ang)
        q = P(x + 0.3, 7.7)
        deco.box((q[0], q[1], 0.9), (0.03, 0.03, 0.14), M["metal_dark"], ang)
        deco.rbox((q[0], q[1], 1.0), (0.09, 0.07, 0.15), M["black"], ang, bevel=0.01)         # terminal de paiement
        r = P(x - 0.75, 8.2)
        empty(f"pnj_caisse_{tills}", (r[0], r[1], 0.03), None, ang - math.pi / 2)
        sgn = P(x, 8.0)
        deco.box((sgn[0], sgn[1], 2.0), (0.05, 0.05, 2.36), M["metal_dark"], ang)
        deco.box((sgn[0], sgn[1], 3.2), (0.5, 0.06, 0.35), M["sign_green"], ang)
        label(f"texte_ararat_caisse_{tills}", (sgn[0] + out[0] * 0.04, sgn[1] + out[1] * 0.04), ang + math.pi, 3.2)
        empty(f"pnj_file_{tills}", (P(x + 0.8, 10.0)[0], P(x + 0.8, 10.0)[1], 0.03), None, ang + math.pi)   # file cote rayons
        tills += 1
    # rayons (gondoles) perpendiculaires a la facade, de y = 12 a y = 12 + 9 m, tous les 3,2 m
    aisle_names = ["epicerie", "boissons", "hygiene", "entretien", "laitiers", "conserves", "bebe", "riz", "huile", "sucre", "the", "biscuits"]
    rows = 0
    ai = 0
    for band in range(3):
        y0 = 12.0 + band * 11.5
        for k in range(-14, 15):
            x = k * 3.2
            if not (inside(x, y0, 1.6) and inside(x, y0 + 9.0, 1.6)):
                continue
            if band == 0 and (-5 <= k <= -3 or 3 <= k <= 4):
                continue      # espaces fruits et legumes (gauche) et boulangerie (droite)
            # gondole : socle, panneau central, etageres (porte-etiquettes jaunes), joues aux deux bouts
            c = P(x, y0 + 4.5)
            fur.box((c[0], c[1], 0.06), (0.92, 9.0, 0.12), M["metal_dark"], ang)
            fur.box((c[0], c[1], 0.98), (0.06, 9.0, 1.72), M["shelf"], ang)
            for e2 in (-1, 1):
                q = P(x, y0 + 4.5 + e2 * 4.52)
                fur.rbox((q[0], q[1], 0.95), (0.95, 0.04, 1.9), M["shelf"], ang, bevel=0.01)
            for side in (-1, 1):
                for lvl in range(4):
                    z = 0.12 + lvl * 0.42
                    if lvl > 0:
                        q = P(x + side * 0.255, y0 + 4.5)
                        fur.box((q[0], q[1], z - 0.0125), (0.42, 9.0, 0.025), M["shelf"], ang)
                    q = P(x + side * 0.468, y0 + 4.5)
                    deco.box((q[0], q[1], z - 0.022), (0.008, 9.0, 0.045), price_strip, ang)
                    # facings : chaque produit occupe plusieurs places cote a cote (comme en vrai rayon) ;
                    # cartons d'un meme produit jointifs -> un seul bloc (etiquette en facade une fois sur deux) ;
                    # bouteilles une par une au premier rang, le reste de la profondeur rempli
                    yy = 0.0
                    while yy < 8.7:
                        mm = random.choice(M["products"])
                        h2 = random.uniform(0.14, 0.34)
                        if random.random() < 0.2:
                            n = random.randint(3, 6)
                            y_start = yy
                            for b2 in range(n):
                                if yy + 0.11 > 8.8:
                                    break
                                q = P(x + side * 0.365, y0 + 0.1 + yy + 0.055)
                                goods.cyl((q[0], q[1], z), 0.045, h2, mm, 8, bottom=False)
                                yy += 0.11
                            if yy > y_start:
                                q = P(x + side * 0.18, y0 + 0.1 + (y_start + yy) / 2)
                                goods.box((q[0], q[1], z + h2 * 0.45), (0.25, yy - y_start - 0.02, h2 * 0.9), mm, ang, bottom=False)
                        else:
                            w2 = random.uniform(0.1, 0.26)
                            n = random.randint(3, 8)
                            gw = min(n * w2, 8.8 - yy)
                            q = P(x + side * 0.23, y0 + 0.1 + yy + gw / 2)
                            goods.box((q[0], q[1], z + h2 / 2), (0.36, gw - 0.02, h2), mm, ang, bottom=False)
                            yy += gw
                        yy += 0.02
            if k % 3 == 0:
                s = P(x, y0 + 4.5)
                deco.box((s[0], s[1], 4.25), (0.03, 0.03, 2.5), M["metal_dark"], ang)
                deco.box((s[0], s[1], 2.8), (1.8, 0.06, 0.45), M["sign_blue"], ang + math.pi / 2)
                label(f"texte_ararat_rayon_{aisle_names[ai % len(aisle_names)]}_{ai}", (s[0] + du[0] * 0.04, s[1] + du[1] * 0.04), ang + math.pi / 2, 2.8)
                ai += 1
            for wy in (y0 - 1.0, y0 + 4.5, y0 + 10.0):
                if inside(x + 1.6, wy, 1.0):
                    q = P(x + 1.6, wy)
                    empty(f"pnj_chemin_{rows}_{int(wy)}", (q[0], q[1], 0.03))
            rows += 1
    # gros conditionnement (fond du magasin) : palettes de sacs de riz, bidons d'huile, packs d'eau, casiers de boissons
    rice = mat("mat_sac_riz", (0.93, 0.9, 0.82), 0.9)
    oil = mat("mat_bidon_huile", (0.95, 0.78, 0.15), 0.4)
    water = mat("mat_pack_eau", (0.55, 0.75, 0.9), 0.2)
    crate_b = mat("mat_casier_biere", (0.12, 0.35, 0.18), 0.6)
    pallet_m = mat("mat_palette", (0.7, 0.58, 0.4), 0.9)
    bulk_col = Mesh("ararat_vrac-colonly")
    yv = 12.0 + 3 * 11.5
    for k in range(-14, 15):
        x = k * 3.2
        for row, py in enumerate((yv + 1.6, yv + 4.1, yv + 6.6)):
            if not inside(x, py, 1.6):
                continue
            c = P(x, py)
            kind = (k + row * 2) % 4
            hgt = (1.15, 0.95, 1.05, 1.2)[kind]
            bulk_col.box((c[0], c[1], 0.07 + hgt / 2), (1.2, 1.0, 0.14 + hgt), pallet_m, ang)   # emprise (collision seule)
            goods.box((c[0], c[1], 0.07), (1.2, 1.0, 0.14), pallet_m, ang, bottom=False)        # palette
            for lyr in range(int(hgt / (0.16, 0.3, 0.26, 0.28)[kind])):
                z = 0.14 + lyr * (0.16, 0.3, 0.26, 0.28)[kind]
                for gx in range(2 if kind == 0 else 3):
                    for gy in range(2 if kind == 0 else 3):
                        if kind == 0:     # sacs de riz de 25 kg, croises d'une couche a l'autre
                            sx, sy = (0.58, 0.46) if lyr % 2 == 0 else (0.46, 0.58)
                            q = P(x - 0.3 + gx * 0.6, py - 0.24 + gy * 0.48)
                            goods.rbox((q[0], q[1], z + 0.075), (sx, sy, 0.15), rice, ang + (0.0 if lyr % 2 == 0 else 0.03), bevel=0.04, seg=1, soft=True)
                        else:
                            m3 = (oil, water, crate_b)[kind - 1]
                            hh = (0.3, 0.26, 0.28)[kind - 1] - 0.01
                            q = P(x - 0.4 + gx * 0.4, py - 0.32 + gy * 0.32)
                            goods.box((q[0], q[1], z + hh / 2), (0.38, 0.3, hh), m3, ang, bottom=False)
        for wy in (yv + 0.3, yv + 2.85, yv + 5.35, yv + 7.9):
            if inside(x + 1.6, wy, 1.0):
                q = P(x + 1.6, wy)
                empty(f"pnj_chemin_vrac_{k}_{int(wy * 10)}", (q[0], q[1], 0.03))
    if inside(0.0, yv - 0.2, 1.0):
        q = P(0.0, yv - 0.2)
        label("texte_ararat_rayon_vrac_x", q, ang + math.pi, 2.8)
        deco.box((q[0] + dn[0] * 0.04, q[1] + dn[1] * 0.04, 2.8), (2.6, 0.06, 0.5), M["sign_blue"], ang)
        for sx in (-1.1, 1.1):
            q2 = P(sx, yv - 0.16)
            deco.box((q2[0], q2[1], 4.15), (0.02, 0.02, 2.7), M["metal_dark"], ang)
    # chemins le long de la facade (zone des caisses) et de la grande allee
    for k in range(-14, 15):
        for y in (3.5, 10.5):
            if inside(k * 3.2, y, 1.2):
                q = P(k * 3.2, y)
                empty(f"pnj_chemin_allee_{k}_{int(y)}", (q[0], q[1], 0.03))
    # fruits et legumes (cote gauche, a la place des premieres gondoles) : etals a gradins, cagettes de fruits
    crate_m = mat("mat_cagette", (0.62, 0.48, 0.3), 0.85)
    produce = [((0.95, 0.55, 0.05), 0.07, 1.0), ((0.92, 0.82, 0.2), 0.05, 2.2), ((0.8, 0.12, 0.08), 0.055, 0.95),
               ((0.22, 0.32, 0.12), 0.065, 1.2), ((0.62, 0.42, 0.25), 0.055, 0.9), ((0.35, 0.6, 0.2), 0.07, 1.0),
               ((0.9, 0.75, 0.55), 0.05, 1.0), ((0.55, 0.15, 0.4), 0.06, 1.0)]
    pmats = [mat("mat_primeur_%d" % i, c, 0.55) for i, (c, _, _) in enumerate(produce)]
    np_ = 0
    for sx in (-15.0, -11.4):
        for sy in (13.2, 16.4, 19.6):
            if not inside(sx, sy, 1.4):
                continue
            c = P(sx, sy)
            fur.rbox((c[0], c[1], 0.3), (1.8, 1.2, 0.6), M["wood_light"], ang, bevel=0.01)
            q = P(sx, sy + 0.3)
            fur.box((q[0], q[1], 0.69), (1.8, 0.6, 0.18), M["wood_light"], ang)               # gradin arriere
            for row, (dy, zc) in enumerate(((-0.3, 0.6), (0.3, 0.78))):
                for col_ in range(3):
                    cx_, cy_ = sx - 0.58 + col_ * 0.58, sy + dy
                    q = P(cx_, cy_)
                    deco.rbox((q[0], q[1], zc + 0.07), (0.54, 0.54, 0.14), crate_m, ang, bevel=0.01)
                    pi = (np_ + row * 3 + col_) % len(produce)
                    _, r, sq = produce[pi]
                    nn = max(2, int(0.46 / (2 * r)))
                    for fx in range(nn):
                        for fy2 in range(nn):
                            q = P(cx_ - 0.23 + r + fx * 2 * r * 1.02, cy_ - 0.23 + r + fy2 * 2 * r * 1.02)
                            goods.sphere((q[0], q[1], zc + 0.14 + r * 0.5), r, pmats[pi], 6, 1.0 / sq if sq > 1.5 else 1.0)
                    for fx in range(nn - 1):
                        for fy2 in range(nn - 1):
                            q = P(cx_ - 0.23 + 2 * r + fx * 2 * r, cy_ - 0.23 + 2 * r + fy2 * 2 * r)
                            goods.sphere((q[0], q[1], zc + 0.14 + r * 1.4), r, pmats[pi], 6, 1.0 / sq if sq > 1.5 else 1.0)
            np_ += 1
        for sy in (13.2, 16.4, 19.6):
            if inside(-13.2, sy, 1.0):
                q = P(-13.2, sy)
                empty(f"pnj_chemin_primeurs_{int(sy * 10)}", (q[0], q[1], 0.03))
    label("texte_ararat_rayon_fruits_x", P(-13.2, 11.2), ang + math.pi, 2.6)
    q = P(-13.2, 11.2)
    deco.box((q[0] + dn[0] * 0.04, q[1] + dn[1] * 0.04, 4.15), (0.03, 0.03, 2.7), M["metal_dark"], ang)
    deco.box((q[0] + dn[0] * 0.04, q[1] + dn[1] * 0.04, 2.6), (1.8, 0.06, 0.45), M["sign_green"], ang)
    # frigos vitres eclaires le long du mur du fond (le plus loin de l'entree, dans le repere)
    fy = 12.0 + 4 * 11.5 + 1.0
    nf = 0
    for k in range(-14, 15):
        x = k * 2.0
        if not inside(x, fy, 1.0):
            continue
        c = P(x, fy)
        fur.box((c[0], c[1], 1.05), (1.9, 0.8, 2.1), M["steel"], ang)
        q = P(x, fy - 0.42)
        deco.box((q[0], q[1], 1.05), (1.7, 0.02, 1.8), M["fridge_light"], ang)
        for lvl in range(4):
            for b in range(8):
                q = P(x - 0.75 + b * 0.21, fy - 0.3)
                goods.cyl((q[0], q[1], 0.3 + lvl * 0.45), 0.04, 0.25, M["products"][(b + lvl) % 8], 6, bottom=False)
        q = P(x, fy - 0.47)
        glass.box((q[0], q[1], 1.05), (1.8, 0.02, 1.9), GLASS, ang)
        nf += 1
    # boulangerie : comptoir avec pains (cote droit)
    bx = 10.0
    if inside(bx, 13.0, 2.0):
        c = P(bx, 13.0)
        fur.rbox((c[0], c[1], 0.5), (4.0, 0.9, 1.0), M["wood_light"], ang, bevel=0.015)
        q = P(bx, 12.98)
        deco.box((q[0], q[1], 1.15), (3.9, 0.7, 0.3), GLASS, ang)                          # vitrine
        for b in range(10):
            q = P(bx - 1.7 + b * 0.38, 13.0)
            goods.cyl((q[0], q[1], 1.02), 0.04, 0.5, M["bread"], 8, 0.035)
        for lvl in range(4):
            q = P(bx, 15.6)
            fur.box((q[0], q[1], 0.5 + lvl * 0.42), (4.0, 0.45, 0.025), M["wood_light"], ang)
            for b in range(12):
                q = P(bx - 1.8 + b * 0.33, 15.6)
                goods.sphere((q[0], q[1], 0.58 + lvl * 0.42), 0.09, M["bread"], 6, 0.6)
        q = P(bx, 15.85)
        fur.box((q[0], q[1], 1.15), (4.0, 0.05, 2.3), M["wood_light"], ang)
        label("texte_ararat_rayon_boulangerie_x", P(bx, 13.6), ang + math.pi, 2.6)
        q = P(bx, 13.6)
        deco.box((q[0] + dn[0] * 0.04, q[1] + dn[1] * 0.04, 2.6), (2.2, 0.06, 0.45), M["sign_red"], ang)
        for sx in (-0.9, 0.9):
            q = P(bx + sx, 13.64)
            deco.box((q[0], q[1], 4.15), (0.02, 0.02, 2.7), M["metal_dark"], ang)
        empty("pnj_caisse_boulangerie", (P(bx, 14.0)[0], P(bx, 14.0)[1], 0.03), None, ang + math.pi)
    # chariots et paniers pres de l'entree
    for k in range(4):
        q = P(-4.5 - k * 0.7, 2.0)
        deco.box((q[0], q[1], 0.55), (0.55, 0.9, 0.5), M["steel"], ang)
    # eclairage : panneaux lumineux au plafond (visuels) + quelques points lumineux
    li = 0
    for gx in range(-12, 13, 4):
        for gy in range(2, 60, 6):
            if inside(gx * 2.0, gy, 1.0):
                q = P(gx * 2.0, gy)
                deco.box((q[0], q[1], 5.47), (1.2, 0.6, 0.04), M["light_panel"], ang)
                if gx % 8 == 0 and gy % 12 == 2:
                    empty(f"lumiere_neon_{li}", (q[0], q[1], 5.2))
                    li += 1
    # volume interieur (pour l'eclairage d'interieur)
    zi = Mesh("zone_interieur_ararat")
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    zi.box(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 2.75), (max(xs) - min(xs), max(ys) - min(ys), 5.4), M["plaster_int"])
    zi.obj()
    for o in (col, vis, glass, fur, goods, deco, bulk_col):
        o.obj()
    save("lieu_ararat")
    cxm, cym = sum(xs) / len(xs), sum(ys) / len(ys)
    preview("lieu_ararat", [("dessus", (cxm, cym, 110), (0, 0, 0), 30),
                            ("facade", (dmid[0] + out[0] * 30, dmid[1] + out[1] * 30, 8), (80, 0, math.degrees(ang) + 180), 30)])


# ======================================================================= terminal de l'aeroport
def build_terminal(info, landside_target):
    reset()
    M = mats_common()
    poly = [bl(p) for p in info["pts"]]
    if sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly))) < 0:
        poly = poly[::-1]
    entr = pick_entrance(poly, landside_target)
    col, vis, glass, doors = shell(poly, 15.0, 9.0, entr, M, mat("mat_facade_terminal", (0.86, 0.87, 0.88), 0.4, 0.2), 3.0, glass_front=True,
                                   name="terminal", door_h=2.6)
    fur = Mesh("terminal_mobilier-col")
    deco = Mesh("terminal_deco")
    (dmid, du) = doors[0]
    dn = inward(poly, dmid, du)
    ang = math.atan2(du[1], du[0])
    sliding_door("terminal", dmid, du, 3.0, 2.6, M)
    out = (-dn[0], -dn[1])
    # enseigne du terminal sur la facade cote ville, au-dessus de l'entree (le grand auvent est celui d'OSM)
    vis.box((dmid[0] + out[0] * 0.3, dmid[1] + out[1] * 0.3, 11.0), (66.0, 0.4, 3.2), M["sign_blue"], ang)
    label("texte_terminal_enseigne", (dmid[0] + out[0] * 0.55, dmid[1] + out[1] * 0.55), ang + math.pi, 11.0)

    def P(x, y):
        return (dmid[0] + du[0] * x + dn[0] * y, dmid[1] + du[1] * x + dn[1] * y)

    def inside(x, y, m=1.5):
        q = P(x, y)
        return point_in_poly(q, poly) and dist_to_poly_edges(q, poly) > m

    # comptoirs d'enregistrement (rangee a 14 m), tapis bagages, panneaux des compagnies (textes Godot)
    nc = 0
    for k in range(-9, 10):
        x = k * 3.6
        if not inside(x, 14.0, 2.5) or abs(x) < 2:
            continue
        # comptoir : caisson clair, bandeau a la couleur de la compagnie cote voyageurs, tablette en bois,
        # ecran de l'agent ; a droite, la balance a bagages puis le tapis qui part derriere le comptoir
        c = P(x, 14.0)
        fur.rbox((c[0], c[1], 0.53), (2.2, 0.75, 1.06), M["white_plastic"], ang, bevel=0.02)
        q = P(x, 13.62)
        vis.box((q[0], q[1], 0.6), (2.0, 0.01, 0.5), M["sign_blue"], ang)
        q = P(x, 13.72)
        deco.rbox((q[0], q[1], 1.08), (2.3, 0.4, 0.04), M["wood_light"], ang, bevel=0.01)
        q = P(x - 0.3, 14.15)
        deco.rbox((q[0], q[1], 1.22), (0.5, 0.04, 0.32), M["black"], ang, rx=0.2, bevel=0.008)
        deco.box((q[0], q[1], 1.12), (0.12, 0.12, 0.04), M["black"], ang)
        q = P(x + 1.45, 13.9)
        fur.rbox((q[0], q[1], 0.16), (0.65, 0.9, 0.32), M["steel"], ang, bevel=0.01)
        deco.box((q[0], q[1], 0.325), (0.55, 0.8, 0.012), M["conveyor"], ang)
        q = P(x + 1.45, 14.75)
        deco.box((q[0], q[1], 0.3), (0.6, 0.8, 0.03), M["conveyor"], ang)
        q = P(x + 1.45, 13.42)
        deco.box((q[0], q[1], 0.75), (0.04, 0.04, 0.5), M["metal_dark"], ang)
        deco.box((q[0], q[1], 1.02), (0.22, 0.03, 0.12), M["black"], ang)
        s = P(x, 14.6)
        deco.box((s[0], s[1], 2.6), (2.0, 0.08, 0.6), M["sign_blue"], ang)
        for sx in (-0.85, 0.85):
            q = P(x + sx, 14.66)
            fur.box((q[0], q[1], 1.45), (0.05, 0.05, 2.9), M["metal_dark"], ang)      # montants du panneau
        label(f"texte_terminal_comptoir_{nc}", (s[0] - dn[0] * 0.05, s[1] - dn[1] * 0.05), ang + math.pi, 2.6)
        a2 = P(x - 0.4, 15.1)
        empty(f"pnj_comptoir_{nc}", (a2[0], a2[1], 0.03), None, ang + math.pi)
        for j in range(3):
            f2 = P(x, 12.4 - j * 1.0)
            empty(f"pnj_file_{nc}_{j}", (f2[0], f2[1], 0.03), None, ang)
        # files d'attente : poteaux et sangles
        for j in range(4):
            p2 = P(x - 1.2, 12.8 - j * 1.1)
            p3 = P(x + 1.2, 12.8 - j * 1.1)
            for pp in (p2, p3):
                deco.cyl((pp[0], pp[1], 0.03), 0.04, 1.0, M["steel"], 8)
            mid = ((p2[0] + p3[0]) / 2, (p2[1] + p3[1]) / 2)
            deco.box((mid[0], mid[1], 0.95), (2.4, 0.02, 0.06), M["sign_red"], ang)
        nc += 1
    # tableau des departs (grand ecran) face a l'entree
    tb = P(0.0, 9.0)
    fur.box((tb[0], tb[1], 1.5), (0.3, 0.3, 3.0), M["metal_dark"], ang)
    deco.box((tb[0], tb[1], 4.0), (6.0, 0.25, 2.6), M["black"], ang)
    deco.box((tb[0] - dn[0] * 0.13, tb[1] - dn[1] * 0.13, 4.0), (5.8, 0.01, 2.4), M["screen"], ang)
    label("texte_terminal_departs", (tb[0] - dn[0] * 0.16, tb[1] - dn[1] * 0.16), ang + math.pi, 5.05)
    # rangees de sieges (attente)
    ns = 0
    for row in range(4):
        for k in range(-5, 6):
            x, y = k * 4.0, 20.0 + row * 2.4
            if not inside(x, y, 2.0) or abs(x) < 3:
                continue
            # banquette de 4 coques sur poutre et pieds en acier, accoudoirs entre les sieges
            for j in range(4):
                q = P(x - 1.2 + j * 0.8, y)
                fur.rbox((q[0], q[1], 0.44), (0.56, 0.5, 0.05), M["seat_blue"], ang, bevel=0.02)
                q2 = P(x - 1.2 + j * 0.8, y + 0.27)
                fur.rbox((q2[0], q2[1], 0.74), (0.56, 0.05, 0.56), M["seat_blue"], ang, rx=-0.14, bevel=0.02)
                if (j + row + k) % 3 == 0:
                    empty(f"pnj_assis_{ns}", (q[0], q[1], 0.0), None, ang + math.pi)
                    ns += 1
            for j in range(5):
                q = P(x - 1.6 + j * 0.8, y + 0.02)
                deco.box((q[0], q[1], 0.58), (0.04, 0.42, 0.03), M["steel"], ang)
                deco.box((q[0], q[1], 0.5), (0.03, 0.03, 0.14), M["steel"], ang)
            leg = P(x, y)
            deco.box((leg[0], leg[1], 0.38), (3.3, 0.08, 0.06), M["steel"], ang)
            for lx in (-1.3, 1.3):
                lp = P(x + lx, y)
                deco.box((lp[0], lp[1], 0.19), (0.06, 0.06, 0.38), M["steel"], ang)
                deco.box((lp[0], lp[1], 0.01), (0.08, 0.45, 0.02), M["steel"], ang)
    # controle de securite : portiques et tables a rayons X, au fond
    sy = 32.0
    for k in (-3, 3):
        if not inside(k * 1.0, sy, 2.0):
            continue
        g1 = P(k * 1.0 - 0.5, sy)
        g2 = P(k * 1.0 + 0.5, sy)
        for gp in (g1, g2):
            fur.box((gp[0], gp[1], 1.05), (0.15, 0.6, 2.1), M["white_plastic"], ang)
        top = P(k * 1.0, sy)
        deco.box((top[0], top[1], 2.15), (1.15, 0.6, 0.15), M["white_plastic"], ang)
        xr = P(k * 1.0 + 2.0, sy)
        fur.box((xr[0], xr[1], 0.6), (0.9, 2.4, 1.2), M["steel"], ang)
        empty(f"pnj_vigile_controle_{k}", (P(k * 1.0 + 1.0, sy + 1.2)[0], P(k * 1.0 + 1.0, sy + 1.2)[1], 0.03), None, ang + math.pi)
    label("texte_terminal_embarquement", P(0.0, sy + 3.0), ang + math.pi, 3.6)
    q = P(0.0, sy + 3.04)
    deco.box((q[0], q[1], 3.6), (6.4, 0.06, 0.9), M["sign_blue"], ang)
    for sx in (-2.8, 2.8):
        q = P(sx, sy + 3.04)
        deco.box((q[0], q[1], 6.5), (0.03, 0.03, 5.0), M["metal_dark"], ang)
    # cloison vitree derriere le controle (zone d'embarquement fermee)
    for k in range(-20, 21):
        x = k * 2.0
        if inside(x, sy + 4.0, 0.5):
            c = P(x, sy + 4.0)
            fur.box((c[0], c[1], 0.05), (2.0, 0.08, 0.1), ALU, ang)
            fur.box((c[0], c[1], 1.6), (2.0, 0.06, 3.2), M["glass"], ang)
    # cafe et librairie (kiosques) pres de l'entree
    for (kx, nm) in ((-14.0, "cafe"), (14.0, "librairie")):
        if inside(kx, 6.0, 2.5):
            c = P(kx, 6.0)
            fur.box((c[0], c[1], 0.55), (4.0, 1.6, 1.1), M["wood_light"], ang)
            deco.box((c[0], c[1], 2.4), (4.2, 1.8, 0.1), M["sign_red"], ang)
            for px in (-1.95, 1.95):
                for py in (-0.75, 0.75):
                    q = P(kx + px, 6.0 + py)
                    fur.box((q[0], q[1], 1.75), (0.06, 0.06, 1.3), M["steel"], ang)      # poteaux du kiosque
            q = P(kx, 5.14)
            deco.box((q[0], q[1], 2.62), (4.2, 0.06, 0.45), M["sign_red"], ang)         # bandeau du nom
            label(f"texte_terminal_{nm}", P(kx, 5.1), ang + math.pi, 2.62)
            empty(f"pnj_caisse_{nm}", (P(kx, 6.9)[0], P(kx, 6.9)[1], 0.03), None, ang + math.pi)
            if nm == "cafe":
                for t2 in range(3):
                    tp = P(kx - 2.5 + t2 * 2.5, 9.5)
                    fur.cyl((tp[0], tp[1], 0.0), 0.35, 0.74, M["white_plastic"], 12)
    # chemins des voyageurs
    for k in range(-12, 13):
        for y in (4.0, 10.5, 18.0, 29.0):
            if inside(k * 3.0, y, 1.5):
                q = P(k * 3.0, y)
                empty(f"pnj_chemin_{k}_{int(y)}", (q[0], q[1], 0.03))
    # eclairage
    li = 0
    for gx in range(-10, 11, 3):
        for gy in range(3, 40, 6):
            if inside(gx * 3.0, gy, 1.0):
                q = P(gx * 3.0, gy)
                deco.box((q[0], q[1], 8.97), (2.0, 0.6, 0.04), M["light_panel"], ang)
                if gx % 6 == 0 and gy % 12 == 3:
                    empty(f"lumiere_neon_{li}", (q[0], q[1], 8.5))
                    li += 1
    zi = Mesh("zone_interieur_terminal")
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    zi.box(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, 4.5), (max(xs) - min(xs), max(ys) - min(ys), 8.9), M["plaster_int"])
    zi.obj()
    for o in (col, vis, glass, fur, deco):
        o.obj()
    save("lieu_terminal")
    cxm, cym = sum(xs) / len(xs), sum(ys) / len(ys)
    preview("lieu_terminal", [("dessus", (cxm, cym, 140), (0, 0, 0), 30),
                              ("hall", (P(-18, 3)[0], P(-18, 3)[1], 4.5), (78, 0, math.degrees(ang) - 35), 22)])


if "maison" in LIEUX:
    build_maison(LIEUX["maison"])
if "ararat" in LIEUX:
    build_ararat(LIEUX["ararat"], bl((620.0, 20.0)))          # entree face au parking (grande facade nord)
if "terminal" in LIEUX:
    build_terminal(LIEUX["terminal"], bl((397.0, -300.0)))    # cote ville (parvis et auvent)
