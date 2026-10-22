# GTB : avion leger a 4 places (type "Cessna" des aeroclubs, version parodique : "Gbe Aero Colibri C-4"), fait par
# script, aucune marque reelle. Demande d'Olympe du 21/10/2026 : piloter des avions, d'abord de petits appareils.
# Lancement : blender -b --python blender/tools/build_avion_leger.py -- <.blend> <.glb> [apercu.png]
#
# Repere : nez vers +Y Blender (= -Z Godot), aile droite vers +X, origine au sol sous l'essieu du train principal.
# Dimensions : longueur 8,3 m, envergure 11 m, hauteur 2,7 m, empattement 1,6 m (aile haute, train tricycle fixe).
# Noeuds animes par godot/scripts/avion_leger.gd : helice (tourne autour de Y), gouverne_prof, gouverne_dir,
# aileron_G / aileron_D (charnieres au bord de fuite, autour de X ou Z locaux), roue_avant, roue_principal_G / _D (autour de
# X), porte_g0 / porte_d0 (portes articulees, charniere avant), pt_pilote, pt_sortie, pt_volant, pt_pedales, feu_nav_G / D.
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
    "paint": mat("mat_avion_peinture", (0.94, 0.94, 0.92), 0.3, 0.05),
    "green": mat("mat_avion_livree_1", (0.1, 0.5, 0.25), 0.35),
    "yellow": mat("mat_avion_livree_2", (0.95, 0.75, 0.1), 0.35),
    "red": mat("mat_avion_livree_3", (0.75, 0.1, 0.1), 0.35),
    "belly": mat("mat_avion_ventre", (0.7, 0.71, 0.72), 0.45, 0.15),
    "glass": mat("mat_avion_vitre", (0.06, 0.08, 0.1), 0.05, 0.0, alpha=0.5),
    "tyre": mat("mat_avion_pneu", (0.05, 0.05, 0.05), 0.9),
    "rim": mat("mat_avion_jante", (0.6, 0.6, 0.62), 0.35, 0.8),
    "gear": mat("mat_avion_train", (0.72, 0.72, 0.7), 0.45, 0.4),
    "dark": mat("mat_avion_sombre", (0.1, 0.1, 0.11), 0.6),
    "seat": mat("mat_siege", (0.22, 0.2, 0.18), 0.95),
    "inside": mat("mat_interieur", (0.15, 0.13, 0.12), 0.9),
    "prop": mat("mat_avion_helice", (0.07, 0.07, 0.08), 0.5),
    "tip": mat("mat_avion_bout_helice", (0.95, 0.8, 0.1), 0.5),
    "wing": mat("mat_avion_aile", (0.9, 0.9, 0.9), 0.35, 0.1),
    "navr": mat("mat_avion_nav_rouge", (0.9, 0.05, 0.05), 0.2),
    "navg": mat("mat_avion_nav_vert", (0.05, 0.8, 0.2), 0.2),
}


class MB:
    """Accumule des faces (avec materiau) dans un bmesh."""

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

    def hexa(self, m, pts, smooth=False):
        """Hexaedre : 8 points (bas puis haut, meme ordre), faces vers l'exterieur."""
        vs = [self.bm.verts.new(p) for p in pts]
        for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.face([vs[i] for i in f], m, smooth)

    def box(self, m, c, s):
        hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
        self.hexa(m, [(c[0] - hx, c[1] - hy, c[2] - hz), (c[0] + hx, c[1] - hy, c[2] - hz), (c[0] + hx, c[1] + hy, c[2] - hz), (c[0] - hx, c[1] + hy, c[2] - hz),
                      (c[0] - hx, c[1] - hy, c[2] + hz), (c[0] + hx, c[1] - hy, c[2] + hz), (c[0] + hx, c[1] + hy, c[2] + hz), (c[0] - hx, c[1] + hy, c[2] + hz)])

    def beam(self, m, a, b, w, w2=None):
        """Barre de section carree entre deux points (mats, jambes de train)."""
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        n1 = d.cross(up).normalized()
        n2 = d.cross(n1).normalized()
        w2 = w if w2 is None else w2
        corners = []
        for p, ww in ((a, w), (b, w2)):
            for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                corners.append(p + n1 * sx * ww / 2 + n2 * sy * ww / 2)
        self.hexa(m, corners)

    def lathe_x(self, m, c, prof, seg=18):
        rings = [[self.bm.verts.new((c[0] + x, c[1] + r * math.cos(i / seg * math.tau), c[2] + r * math.sin(i / seg * math.tau))) for i in range(seg)] for x, r in prof]
        for a in range(len(rings) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                self.face((rings[a][i], rings[a][j], rings[a + 1][j], rings[a + 1][i]), m, True)

    def lathe_y(self, m, c, prof, seg=18, cap=True):
        rings = [[self.bm.verts.new((c[0] + r * math.cos(i / seg * math.tau), c[1] + y, c[2] + r * math.sin(i / seg * math.tau))) for i in range(seg)] for y, r in prof]
        for a in range(len(rings) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                self.face((rings[a][i], rings[a][j], rings[a + 1][j], rings[a + 1][i]), m, True)
        if cap and prof[-1][1] > 0.001:
            self.face(rings[-1][::-1], m, True)

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
        for p in ob.data.polygons:
            p.use_smooth = True
        return ob


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.2
    bpy.context.scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    return e


root = empty("avion_leger", (0, 0, 0))

# ------------------------------------------------------------------ fuselage (cage de sections, lissee)
# (y, bas, haut, demi-largeur)
ST = [(2.0, 0.92, 1.38, 0.30), (1.85, 0.8, 1.45, 0.42), (1.1, 0.62, 1.62, 0.55), (0.55, 0.55, 1.72, 0.58), (0.1, 0.55, 2.05, 0.58),
      (-0.8, 0.55, 2.1, 0.56), (-1.8, 0.58, 2.02, 0.5), (-2.5, 0.65, 1.82, 0.42), (-3.6, 0.82, 1.58, 0.3), (-4.8, 1.05, 1.52, 0.16),
      (-5.9, 1.22, 1.46, 0.05)]
N = 14


def ring(y, zb, zt, hw):
    zc, hh = (zb + zt) / 2, (zt - zb) / 2
    pts = []
    for i in range(N):
        a = i / N * math.tau
        c, s = math.cos(a), math.sin(a)
        pts.append((hw * math.copysign(abs(c) ** (2 / 2.7), c), y, zc + hh * math.copysign(abs(s) ** (2 / 2.7), s)))
    return pts


fus = MB("fuselage")
rings = [[fus.bm.verts.new(p) for p in ring(*s)] for s in ST]
for a in range(len(rings) - 1):
    ya, yb = ST[a][0], ST[a + 1][0]
    for j in range(N):
        v = (rings[a][j], rings[a][(j + 1) % N], rings[a + 1][(j + 1) % N], rings[a + 1][j])
        cx = sum(p.co.x for p in v) / 4
        cy = (ya + yb) / 2
        cz = sum(p.co.z for p in v) / 4
        m = M["paint"]
        if cz < 0.75:
            m = M["belly"]
        elif abs(cx) > 0.12 and 1.0 < cz < 1.12 and cy < 1.1:
            m = M["green"]                              # liseré de livree
        elif abs(cx) > 0.12 and 0.88 < cz <= 1.0 and cy < 1.1:
            m = M["yellow"]
        elif cz > 1.55 and ((cy > 0.1 and cy < 0.6) or (abs(cx) > 0.33 and -2.45 < cy < 0.35)) and cz < 2.12:
            m = M["glass"]                              # pare-brise et vitres laterales
        fus.face(v, m, True)
fus.face(rings[0], M["paint"], True)
fus.face(rings[-1][::-1], M["paint"], True)
fo = fus.obj(root)
md = fo.modifiers.new("lisse", "SUBSURF")
md.levels = 1
md.render_levels = 1
bpy.context.view_layer.objects.active = fo
bpy.ops.object.select_all(action="DESELECT")
fo.select_set(True)
bpy.ops.object.modifier_apply(modifier=md.name)


# ------------------------------------------------------------------ portes articulees (comme les voitures)
def percer_porte(side, y_front, y_rear, zlo, zhi, nom):
    hw = 0.58
    x_out, x_in = side * (hw + 0.35), side * 0.12
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=((x_out + x_in) / 2, (y_front + y_rear) / 2, (zlo + zhi) / 2))
    cut = bpy.context.active_object
    cut.scale = (abs(x_out - x_in), y_front - y_rear, zhi - zlo)
    cut.data.materials.append(M["inside"])
    bpy.context.view_layer.objects.active = cut
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    door = fo.copy()
    door.data = fo.data.copy()
    door.name = nom
    bpy.context.scene.collection.objects.link(door)
    for nm, op, target in (("porte", "INTERSECT", door), ("trou", "DIFFERENCE", fo)):
        md2 = target.modifiers.new(nm, "BOOLEAN")
        md2.operation = op
        md2.object = cut
        if hasattr(md2, "solver"):
            md2.solver = "EXACT"
        if hasattr(md2, "material_mode"):
            md2.material_mode = "TRANSFER"
        bpy.context.view_layer.objects.active = target
        bpy.ops.object.modifier_apply(modifier=md2.name)
    bm = bmesh.new()
    bm.from_mesh(door.data)
    idx = [i for i, m in enumerate(door.data.materials) if m and m.name == "mat_interieur"]
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in idx], context="FACES")
    bm.to_mesh(door.data)
    bm.free()
    bpy.data.objects.remove(cut, do_unlink=True)
    pivot = Vector((side * 0.56, y_front, (zlo + zhi) / 2))
    door.data.transform(Matrix.Translation(-pivot))
    door.location = pivot
    door.parent = root


percer_porte(-1, 0.42, -0.45, 0.78, 1.95, "porte_g0")
percer_porte(1, 0.42, -0.45, 0.78, 1.95, "porte_d0")

# ------------------------------------------------------------------ ailes (haute, haubanee)
ail = MB("ailes")
Z0 = 2.12
for s in (-1, 1):
    # troncon interieur (volets), puis troncon exterieur (le bord de fuite est laisse a l'aileron)
    ail.hexa(M["wing"], [(s * 0.5, 0.25, Z0 - 0.1), (s * 3.0, 0.38, Z0 - 0.06), (s * 3.0, -1.3, Z0 - 0.06), (s * 0.5, -1.45, Z0 - 0.1),
                         (s * 0.5, 0.25, Z0 + 0.12), (s * 3.0, 0.38, Z0 + 0.06), (s * 3.0, -1.3, Z0 + 0.06), (s * 0.5, -1.45, Z0 + 0.12)])
    ail.hexa(M["wing"], [(s * 3.0, 0.38, Z0 - 0.06), (s * 5.5, 0.5, Z0 - 0.03), (s * 5.5, -0.78, Z0 - 0.03), (s * 3.0, -1.3, Z0 - 0.06),
                         (s * 3.0, 0.38, Z0 + 0.06), (s * 5.5, 0.5, Z0 + 0.03), (s * 5.5, -0.78, Z0 + 0.03), (s * 3.0, -1.3, Z0 + 0.06)])
    # bout d'aile
    ail.box(M["navr"] if s < 0 else M["navg"], (s * 5.55, -0.1, Z0), (0.1, 1.1, 0.07))
    # hauban : du bas du fuselage au tiers exterieur de l'aile
    ail.beam(M["gear"], (s * 0.56, -0.2, 0.78), (s * 2.9, -0.35, Z0 - 0.08), 0.07)
    ail.beam(M["gear"], (s * 0.56, -0.6, 0.78), (s * 2.9, -0.45, Z0 - 0.08), 0.04)
wo = ail.obj(root)

# ailerons : charniere au bord de fuite de l'aile exterieure
for s in (-1, 1):
    m = MB("aileron_" + ("G" if s < 0 else "D"))
    x0, x1 = (3.1, 5.4)
    m.hexa(M["wing"], [(s * x0, 0.0, -0.025), (s * x1, 0.0, -0.025), (s * x1, -0.38, -0.025), (s * x0, -0.4, -0.025),
                       (s * x0, 0.0, 0.035), (s * x1, 0.0, 0.035), (s * x1, -0.38, 0.035), (s * x0, -0.4, 0.035)])
    ob = m.obj(root, (0, -1.28, Z0 - 0.01))
    ob.location = (0, -1.28, Z0 - 0.01)
    # charniere : l'origine reste sur l'axe X de l'aileron, donc la rotation autour de X local fonctionne

# ------------------------------------------------------------------ empennage
emp = MB("empennage")
emp.hexa(M["paint"], [(-0.1, -4.35, 1.4), (0.1, -4.35, 1.4), (0.07, -5.35, 1.45), (-0.07, -5.35, 1.45),
                      (-0.04, -5.0, 2.95), (0.04, -5.0, 2.95), (0.04, -5.55, 3.0), (-0.04, -5.55, 3.0)])
emp.box(M["green"], (0, -5.1, 2.7), (0.11, 0.55, 0.28))
for s in (-1, 1):
    emp.hexa(M["paint"], [(s * 0.1, -4.5, 1.62), (s * 1.75, -5.15, 1.62), (s * 1.75, -5.55, 1.62), (s * 0.1, -5.55, 1.62),
                          (s * 0.1, -4.5, 1.7), (s * 1.75, -5.15, 1.7), (s * 1.75, -5.55, 1.7), (s * 0.1, -5.55, 1.7)] if s > 0 else
             [(s * 0.1, -4.5, 1.62), (s * 0.1, -5.55, 1.62), (s * 1.75, -5.55, 1.62), (s * 1.75, -5.15, 1.62),
              (s * 0.1, -4.5, 1.7), (s * 0.1, -5.55, 1.7), (s * 1.75, -5.55, 1.7), (s * 1.75, -5.15, 1.7)])
eo = emp.obj(root)

gp = MB("gouverne_prof")
gp.box(M["paint"], (0, -0.2, 0), (3.2, 0.4, 0.07))
go = gp.obj(root, (0, -5.55, 1.66))
gd = MB("gouverne_dir")
gd.hexa(M["paint"], [(-0.035, 0.0, -0.75), (0.035, 0.0, -0.75), (0.035, -0.4, -0.7), (-0.035, -0.4, -0.7),
                     (-0.035, 0.0, 0.7), (0.035, 0.0, 0.7), (0.035, -0.3, 0.65), (-0.035, -0.3, 0.65)])
gdo = gd.obj(root, (0, -5.5, 2.2))

# ------------------------------------------------------------------ capot moteur, helice, train
cap = MB("capot")
cap.lathe_y(M["paint"], (0, 0, 1.15), [(1.85, 0.42), (2.05, 0.2), (2.25, 0.07), (2.3, 0.0)], 20)
cap.box(M["dark"], (0, 1.84, 1.0), (0.4, 0.05, 0.16))                 # entree d'air
co = cap.obj(root)
hel = empty("helice", (0, 2.3, 1.15), root)
hb = MB("pales")
hb.box(M["prop"], (0, 0.0, 0.0), (0.11, 0.025, 2.0))
hb.box(M["tip"], (0, 0.0, 0.94), (0.11, 0.03, 0.12))
hb.box(M["tip"], (0, 0.0, -0.94), (0.11, 0.03, 0.12))
hb.obj(hel)

# train tricycle fixe : jambe avant, deux jambes principales a lames, roues (pivots separes pour les faire tourner)
tr = MB("train")
tr.beam(M["gear"], (0, 1.45, 0.78), (0, 1.55, 0.3), 0.07)
for s in (-1, 1):
    tr.beam(M["gear"], (s * 0.5, 0.02, 0.8), (s * 1.12, -0.05, 0.34), 0.08, 0.06)
    tr.box(M["paint"], (s * 1.12, -0.05, 0.36), (0.06, 0.62, 0.34))       # carenage de roue
tro = tr.obj(root)


def roue(nom, loc, r, w):
    piv = empty(nom, loc, root)
    m = MB(nom + "_mesh")
    m.lathe_x(M["tyre"], (0, 0, 0), [(w * 0.5, r * 0.7), (w * 0.5, r * 0.97), (w * 0.2, r), (-w * 0.2, r), (-w * 0.5, r * 0.97), (-w * 0.5, r * 0.7)], 16)
    m.lathe_x(M["rim"], (0, 0, 0), [(w * 0.51, r * 0.4), (w * 0.51, r * 0.69), (-w * 0.51, r * 0.69), (-w * 0.51, r * 0.4)], 12)
    m.obj(piv)


roue("roue_avant", (0, 1.55, 0.22), 0.22, 0.12)
roue("roue_principal_G", (-1.12, -0.05, 0.3), 0.3, 0.16)
roue("roue_principal_D", (1.12, -0.05, 0.3), 0.3, 0.16)

# ------------------------------------------------------------------ cabine
cab = MB("interieur")
for x in (-0.3, 0.3):
    cab.box(M["seat"], (x, -0.5, 0.95), (0.42, 0.45, 0.12))
    cab.box(M["seat"], (x, -0.78, 1.3), (0.42, 0.1, 0.65))
cab.box(M["seat"], (0, -1.55, 0.95), (1.0, 0.45, 0.12))
cab.box(M["seat"], (0, -1.82, 1.3), (1.0, 0.1, 0.65))
cab.box(M["dark"], (0, 0.42, 1.42), (1.0, 0.3, 0.3))                 # planche de bord
cab.box(M["inside"], (0, -0.4, 0.74), (0.9, 2.4, 0.04))               # plancher
for x in (-0.3, 0.3):
    cab.box(M["dark"], (x, 0.12, 1.12), (0.04, 0.04, 0.4))           # manche
    cab.box(M["dark"], (x, 0.05, 1.32), (0.26, 0.04, 0.05))          # volant (mancheron)
cab.box(M["dark"], (0, 0.15, 0.7), (0.5, 0.35, 0.08))                # pedales
cab.obj(root)

# feux de navigation (reperes pour Godot) et phare d'atterrissage
empty("feu_nav_G", (-5.55, -0.1, Z0), root)
empty("feu_nav_D", (5.55, -0.1, Z0), root)
empty("feu_queue", (0, -5.95, 1.46), root)
empty("phare_atterrissage", (0, 1.9, 0.95), root)
empty("pt_pilote", (-0.3, -0.5, 1.02), root)
empty("pt_sortie", (-1.25, -0.4, 0.0), root)
empty("pt_volant", (-0.3, 0.05, 1.32), root)
empty("pt_pedales", (-0.3, 0.2, 0.7), root)
empty("pt_passager_d", (0.3, -0.5, 1.02), root)

faces = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
print("Avion leger :", faces, "faces,", len([o for o in bpy.context.scene.objects if o.type == "MESH"]), "objets")
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
    sc.render.resolution_x, sc.render.resolution_y = 1200, 800
    cam = bpy.data.cameras.new("c")
    cam.lens = 32
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    for nm, loc, rot in (("trois_quart", (11, 9, 4.2), (76, 0, 130)), ("profil", (-13, 0, 2.2), (88, 0, -90)), ("dessus", (0, -2, 15), (10, 0, 0))):
        co.location = loc
        co.rotation_euler = [math.radians(a) for a in rot]
        sc.render.filepath = PREVIEW.replace(".png", f"_{nm}.png")
        bpy.ops.render.render(write_still=True)
