# GTB : "apres" de la maquette des personnages (execute par maquette_perso.py avant le rendu). Ameliore le pilote :
# peau (diffusion sous la surface, pores), yeux brillants, cheveux crepus denses en relief, T-shirt epaissi avec plis, tissu
# chine et impression GTB moulee sur la poitrine, jean avec trame, usure et ceinture, baskets modelisees.
# Les objets crees ou remplaces portent la propriete personnalisee "apres".
import math
import os
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sc = bpy.context.scene
random.seed(5)


# ------------------------------------------------------------------ materiaux
def nouveau(nom):
    m = bpy.data.materials.new(nom)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    p = nt.nodes.new("ShaderNodeBsdfPrincipled")
    o = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(p.outputs[0], o.inputs[0])
    return m, nt, p


def entree(p, noms, valeur):
    for n in noms if isinstance(noms, (list, tuple)) else [noms]:
        if n in p.inputs:
            try:
                p.inputs[n].default_value = valeur
            except Exception:
                pass
            return


def bosse(nt, p, echelle, force, detail=8.0, kind="NOISE", coords=None):
    t = nt.nodes.new("ShaderNodeTexNoise" if kind == "NOISE" else "ShaderNodeTexVoronoi")
    t.inputs["Scale"].default_value = echelle
    if kind == "NOISE":
        t.inputs["Detail"].default_value = detail
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = force
    b.inputs["Distance"].default_value = 0.01
    if coords is not None:
        nt.links.new(coords, t.inputs["Vector"])
    nt.links.new(t.outputs[0] if kind == "NOISE" else t.outputs["Distance"], b.inputs["Height"])
    return b


def peau_apres(obj):
    m, nt, p = nouveau("apres_peau")
    entree(p, "Base Color", (0.16, 0.075, 0.045, 1))
    entree(p, "Roughness", 0.62)
    entree(p, ["Subsurface Weight", "Subsurface"], 0.12)
    entree(p, "Subsurface Radius", (0.9, 0.35, 0.2))
    entree(p, "Subsurface Scale", 0.02)
    entree(p, ["Specular IOR Level", "Specular"], 0.3)
    entree(p, "Coat Weight", 0.0)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    b1 = bosse(nt, p, 900.0, 0.12, 4.0, "VORONOI", tc.outputs["Object"])
    b2 = bosse(nt, p, 60.0, 0.08, 6.0, "NOISE", tc.outputs["Object"])
    nt.links.new(b1.outputs[0], b2.inputs["Normal"])
    nt.links.new(b2.outputs[0], p.inputs["Normal"])
    # variation de teinte : paumes, joues et dessous plus clairs/rougeatres, dessus des mains plus sombre
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    mix.inputs[0].default_value = 0.35
    nt.links.new(n.outputs["Fac"], mix.inputs[0])
    mix.inputs[6].default_value = (0.055, 0.025, 0.016, 1)
    mix.inputs[7].default_value = (0.11, 0.05, 0.03, 1)
    nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    obj.data.materials[0] = m


def yeux_apres(obj, mesures):
    """Remplace la texture des yeux (poles d'UV pinces, etoiles noires) par un shader procedural : iris, pupille, anneau
    limbique, blanc chaud ombre vers les paupieres, un seul reflet net. Coordonnees d'objet, miroir sur X : les deux yeux
    partagent le meme shader."""
    pts = [obj.data.vertices[vi].co for p in obj.data.polygons if p.material_index == 2 for vi in p.vertices]
    d = [v for v in pts if v.x > 0]
    ex = (min(v.x for v in d) + max(v.x for v in d)) / 2
    ey = (min(v.y for v in d) + max(v.y for v in d)) / 2
    ez = (min(v.z for v in d) + max(v.z for v in d)) / 2
    R = max(max(v.x for v in d) - min(v.x for v in d), max(v.z for v in d) - min(v.z for v in d)) / 2 * 1.005
    r_iris = R * 0.5
    m, nt, p = nouveau("apres_oeil")
    entree(p, "Roughness", 0.1)
    entree(p, ["Specular IOR Level", "Specular"], 0.6)
    entree(p, "Coat Weight", 0.0)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])

    def maths(op, a=None, b=None, sortie=None):
        n = nt.nodes.new("ShaderNodeMath")
        n.operation = op
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                nt.links.new(v, n.inputs[i])
        return n.outputs[0]

    dx = maths("SUBTRACT", maths("ABSOLUTE", sep.outputs["X"]), ex)
    dz = maths("SUBTRACT", sep.outputs["Z"], ez)
    r = maths("SQRT", maths("ADD", maths("MULTIPLY", dx, dx), maths("MULTIPLY", dz, dz)))
    rn = maths("DIVIDE", r, r_iris)
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ce = ramp.color_ramp
    ce.interpolation = "LINEAR"
    stops = [(0.0, (0.0, 0.0, 0.0, 1)), (0.36, (0.0, 0.0, 0.0, 1)), (0.42, (0.3, 0.115, 0.025, 1)), (0.62, (0.19, 0.07, 0.016, 1)),
             (0.88, (0.1, 0.04, 0.012, 1)), (0.97, (0.025, 0.012, 0.008, 1)), (1.03, (0.62, 0.55, 0.46, 1)), (1.5, (0.55, 0.47, 0.38, 1)), (3.0, (0.34, 0.25, 0.19, 1))]
    while len(ce.elements) < len(stops):
        ce.elements.new(0.5)
    for el, (pos, col) in zip(ce.elements, stops):
        el.position = min(pos / 3.0, 1.0)
        el.color = col
    nt.links.new(maths("DIVIDE", rn, 3.0), ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    # fibres de l'iris : bruit radial discret
    fib = nt.nodes.new("ShaderNodeTexNoise")
    fib.inputs["Scale"].default_value = 1800.0
    fib.inputs["Detail"].default_value = 3.0
    nt.links.new(tc.outputs["Object"], fib.inputs["Vector"])
    bm_ = nt.nodes.new("ShaderNodeBump")
    bm_.inputs["Strength"].default_value = 0.05
    bm_.inputs["Distance"].default_value = 0.001
    nt.links.new(fib.outputs["Fac"], bm_.inputs["Height"])
    nt.links.new(bm_.outputs[0], p.inputs["Normal"])
    for i, mat in enumerate(obj.data.materials):
        if mat and mat.name.startswith("MI_Eyes"):
            obj.data.materials[i] = m
    # globes lisses poses sur les yeux du corps : la subdivision du corps y laissait des pointes noires (poles du maillage)
    bm = bmesh.new()
    for sx in (-1, 1):
        bmesh.ops.create_uvsphere(bm, u_segments=40, v_segments=24, radius=R, matrix=Matrix.Translation((sx * ex, ey, ez)))
    for f in bm.faces:
        f.smooth = True
    msh = bpy.data.meshes.new("apres_globes")
    bm.to_mesh(msh)
    g = bpy.data.objects.new("apres_globes", msh)
    sc.collection.objects.link(g)
    g["apres"] = True
    msh.materials.append(m)


# ------------------------------------------------------------------ geometrie
def dupliquer(nom_src, nom):
    src = bpy.data.objects[nom_src]
    o = src.copy()
    o.data = src.data.copy()
    o.name = nom
    sc.collection.objects.link(o)
    o["apres"] = True
    o.hide_render = False
    return o


def evaluer(o):
    return o.evaluated_get(bpy.context.evaluated_depsgraph_get())


def ajouter_mod(o, typ, **kw):
    m = o.modifiers.new(typ.lower(), typ)
    for k, v in kw.items():
        setattr(m, k, v)
    return m


def texture_proc(nom, typ, taille, **kw):
    t = bpy.data.textures.new(nom, typ)
    for k, v in kw.items():
        setattr(t, k, v)
    return t


# ------------------------------------------------------------------ cheveux : crepus courts, denses, en relief
def cheveux_apres():
    h = dupliquer("chr_cheveux", "apres_cheveux")
    # le maillage porte les memes poids : on garde l'armature, on ajoute subdivision et relief de boucles
    ajouter_mod(h, "SUBSURF", levels=2, render_levels=2)
    tx = texture_proc("boucles", "VORONOI", 0, noise_scale=0.045, intensity=1.0)
    d = ajouter_mod(h, "DISPLACE", strength=0.0075, mid_level=0.3, texture=tx)
    h.modifiers.move(len(h.modifiers) - 1, 1)
    m, nt, p = nouveau("apres_cheveux")
    entree(p, "Base Color", (0.012, 0.01, 0.01, 1))
    entree(p, "Roughness", 0.75)
    entree(p, ["Specular IOR Level", "Specular"], 0.08)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    b1 = bosse(nt, p, 380.0, 1.2, 4.0, "VORONOI", tc.outputs["Object"])
    b2 = bosse(nt, p, 1800.0, 0.5, 4.0, "NOISE", tc.outputs["Object"])
    nt.links.new(b1.outputs[0], b2.inputs["Normal"])
    nt.links.new(b2.outputs[0], p.inputs["Normal"])
    # reflet bleute des cheveux noirs au soleil : couleur claire sur les pointes des boucles
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 380.0
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.002, 0.002, 0.002, 1)
    ramp.color_ramp.elements[1].color = (0.012, 0.011, 0.012, 1)
    nt.links.new(vor.outputs["Distance"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], p.inputs["Base Color"])
    h.data.materials.clear()
    h.data.materials.append(m)
    return h


# ------------------------------------------------------------------ vetements
def tissu_chine(nt, p, base1, base2, echelle_trame, force):
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = 900.0
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    r = nt.nodes.new("ShaderNodeValToRGB")
    r.color_ramp.elements[0].color = base1
    r.color_ramp.elements[1].color = base2
    nt.links.new(n.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], p.inputs["Base Color"])
    wv = nt.nodes.new("ShaderNodeTexWave")
    wv.wave_type = "BANDS"
    wv.inputs["Scale"].default_value = echelle_trame
    wv.inputs["Distortion"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], wv.inputs["Vector"])
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = force
    b.inputs["Distance"].default_value = 0.004
    nt.links.new(wv.outputs["Color"], b.inputs["Height"])
    nt.links.new(b.outputs[0], p.inputs["Normal"])


def tshirt_apres():
    t = dupliquer("chr_haut", "apres_tshirt")
    ajouter_mod(t, "SUBSURF", levels=1, render_levels=1)
    tx = texture_proc("plis_tshirt", "CLOUDS", 0, noise_scale=0.11, noise_depth=3)
    ajouter_mod(t, "DISPLACE", strength=0.012, mid_level=0.5, texture=tx)
    ajouter_mod(t, "SOLIDIFY", thickness=0.0045, offset=1.0)
    m, nt, p = nouveau("apres_tshirt")
    entree(p, "Roughness", 0.85)
    tissu_chine(nt, p, (0.085, 0.085, 0.083, 1), (0.16, 0.16, 0.155, 1), 2200.0, 0.6)
    t.data.materials.clear()
    t.data.materials.append(m)
    return t


def impression(tshirt):
    """Logo GTB noir de la planche d'Olympe, imprime sur la poitrine (projection dans le shader, face avant seulement)."""
    m = tshirt.data.materials[0]
    nt = m.node_tree
    p = [n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"][0]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    # coordonnees objet : x lateral, z hauteur ; image de 0,2 m de large centree sur la poitrine
    mp.inputs["Location"].default_value = (0.5, 0.5, 0.0)
    mp.inputs["Scale"].default_value = (5.0, 5.0, 5.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(mp.outputs[0], sep.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(sep.outputs["X"], comb.inputs["X"])
    off = nt.nodes.new("ShaderNodeMath")
    off.operation = "ADD"
    off.inputs[1].default_value = -5.85       # decale en hauteur : centre du logo a z = 1,17 m environ
    nt.links.new(sep.outputs["Z"], off.inputs[0])
    nt.links.new(off.outputs[0], comb.inputs["Y"])
    img = nt.nodes.new("ShaderNodeTexImage")
    img.image = bpy.data.images.load(os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "godot", "assets", "textures", "logo_tshirt_gtb.png")))
    img.extension = "CLIP"
    nt.links.new(comb.outputs[0], img.inputs["Vector"])
    # face avant : normale objet y < 0
    nrm = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Normal"], nrm.inputs[0])
    avant = nt.nodes.new("ShaderNodeMath")
    avant.operation = "LESS_THAN"
    avant.inputs[1].default_value = -0.25
    nt.links.new(nrm.outputs["Y"], avant.inputs[0])
    masque = nt.nodes.new("ShaderNodeMath")
    masque.operation = "MULTIPLY"
    nt.links.new(img.outputs["Alpha"], masque.inputs[0])
    nt.links.new(avant.outputs[0], masque.inputs[1])
    # couleur actuelle du tissu -> melangee avec le noir du logo
    liens = [l for l in nt.links if l.to_socket == p.inputs["Base Color"]]
    src = liens[0].from_socket
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    nt.links.new(masque.outputs[0], mx.inputs[0])
    nt.links.new(src, mx.inputs[6])
    mx.inputs[7].default_value = (0.012, 0.012, 0.012, 1)
    nt.links.new(mx.outputs[2], p.inputs["Base Color"])


def col_cotes(tshirt_src, filtre=None, rayon=(0.0075, 0.0055), nom="apres_col", couleur=(0.07, 0.07, 0.068, 1)):
    """Bord d'encolure irregulier : un tube de cote (rib) suit la boucle de sommets du col."""
    src = bpy.data.objects[tshirt_src]
    me = src.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.edges.ensure_lookup_table()
    filtre = filtre or (lambda v: v.co.z > 1.38)
    aretes = [e for e in bm.edges if e.is_boundary and all(filtre(v) for v in e.verts)]
    nv = bmesh.new()
    corr = {}
    for e in aretes:
        vs = []
        for v in e.verts:
            if v.index not in corr:
                corr[v.index] = nv.verts.new(v.co + Vector((0, -0.004, 0.0)))
            vs.append(corr[v.index])
        try:
            nv.edges.new(vs)
        except ValueError:
            pass
    msh = bpy.data.meshes.new(nom)
    nv.to_mesh(msh)
    o = bpy.data.objects.new(nom, msh)
    sc.collection.objects.link(o)
    o["apres"] = True
    sk = o.modifiers.new("tube", "SKIN")
    o.modifiers.new("lisse", "SUBSURF").levels = 1
    for v in msh.skin_vertices[0].data:
        v.radius = rayon
    mc, nt, p = nouveau(nom)
    entree(p, "Base Color", couleur)
    entree(p, "Roughness", 0.9)
    msh.materials.append(mc)
    return o


def jean_apres():
    j = dupliquer("chr_pantalon", "apres_jean")
    vg = j.vertex_groups.new(name="serre")
    for v in j.data.vertices:
        w = max(0.0, min(1.0, (v.co.z - 0.5) / 0.3))
        vg.add([v.index], w, "REPLACE")
    sw = j.modifiers.new("serre", "SHRINKWRAP")
    sw.target = bpy.data.objects["chr_corps"]
    sw.wrap_method = "NEAREST_SURFACEPOINT"
    sw.wrap_mode = "OUTSIDE_SURFACE"
    sw.offset = 0.007
    sw.vertex_group = "serre"
    ajouter_mod(j, "SUBSURF", levels=1, render_levels=1)
    tx = texture_proc("plis_jean", "CLOUDS", 0, noise_scale=0.09, noise_depth=4)
    ajouter_mod(j, "DISPLACE", strength=0.018, mid_level=0.5, texture=tx)
    ajouter_mod(j, "SOLIDIFY", thickness=0.006, offset=1.0)
    m, nt, p = nouveau("apres_jean")
    entree(p, "Roughness", 0.85)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    # fil de chaine et de trame (deux bandes croisees) et delavage aux genoux et aux cuisses
    w1 = nt.nodes.new("ShaderNodeTexWave")
    w1.inputs["Scale"].default_value = 1500.0
    w1.inputs["Distortion"].default_value = 1.0
    nt.links.new(tc.outputs["Object"], w1.inputs["Vector"])
    w2 = nt.nodes.new("ShaderNodeTexWave")
    w2.inputs["Scale"].default_value = 1400.0
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Rotation"].default_value = (math.radians(90), 0, 0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs[0], w2.inputs["Vector"])
    ad = nt.nodes.new("ShaderNodeMath")
    ad.operation = "ADD"
    nt.links.new(w1.outputs["Fac"], ad.inputs[0])
    nt.links.new(w2.outputs["Fac"], ad.inputs[1])
    b = nt.nodes.new("ShaderNodeBump")
    b.inputs["Strength"].default_value = 0.12
    b.inputs["Distance"].default_value = 0.001
    nt.links.new(ad.outputs[0], b.inputs["Height"])
    nt.links.new(b.outputs[0], p.inputs["Normal"])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = 9.0
    nt.links.new(tc.outputs["Object"], n.inputs["Vector"])
    # delavage : plus clair entre z 0,35 et 0,6 (genoux) et 0,75 a 1,0 (cuisses), modulee par le bruit
    r1 = nt.nodes.new("ShaderNodeMapRange")
    r1.inputs["From Min"].default_value = 0.25
    r1.inputs["From Max"].default_value = 0.5
    nt.links.new(sep.outputs["Z"], r1.inputs["Value"])
    mult = nt.nodes.new("ShaderNodeMath")
    mult.operation = "MULTIPLY"
    nt.links.new(r1.outputs[0], mult.inputs[0])
    nt.links.new(n.outputs["Fac"], mult.inputs[1])
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.inputs[6].default_value = (0.012, 0.022, 0.05, 1)
    mx.inputs[7].default_value = (0.045, 0.075, 0.13, 1)
    nt.links.new(mult.outputs[0], mx.inputs[0])
    nt.links.new(mx.outputs[2], p.inputs["Base Color"])
    j.data.materials.clear()
    j.data.materials.append(m)
    return j


def ceinture(jean):
    ev = evaluer(jean)
    mn, mx = Vector((1e9, 1e9, 1e9)), Vector((-1e9, -1e9, -1e9))
    zs = sorted(v.co.z for v in ev.data.vertices)
    ztop = zs[-1]
    # ellipse de la taille mesuree sur les sommets les plus hauts
    haut = [v.co for v in ev.data.vertices if v.co.z > ztop - 0.02]
    cx = sum(v.x for v in haut) / len(haut)
    cy = sum(v.y for v in haut) / len(haut)
    rx = max(abs(v.x - cx) for v in haut) + 0.004
    ry = max(abs(v.y - cy) for v in haut) + 0.004
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=48, radius1=1.0, radius2=1.0, depth=0.036)
    for v in bm.verts:
        v.co.x *= rx
        v.co.y *= ry
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.003)
    msh = bpy.data.meshes.new("apres_ceinture")
    bm.to_mesh(msh)
    o = bpy.data.objects.new("apres_ceinture", msh)
    sc.collection.objects.link(o)
    o["apres"] = True
    o.location = (cx, cy, ztop - 0.02)
    m, nt, p = nouveau("apres_cuir")
    entree(p, "Base Color", (0.05, 0.025, 0.012, 1))
    entree(p, "Roughness", 0.5)
    msh.materials.append(m)
    # boucle
    bk = bpy.data.objects.new("apres_boucle", bpy.data.meshes.new("apres_boucle"))
    b2 = bmesh.new()
    bmesh.ops.create_cube(b2, size=1.0)
    for v in b2.verts:
        v.co = Vector((v.co.x * 0.045, v.co.y * 0.006, v.co.z * 0.036))
    b2.to_mesh(bk.data)
    sc.collection.objects.link(bk)
    bk["apres"] = True
    bk.location = (cx, cy - ry - 0.003, ztop - 0.02)
    m2, nt2, p2 = nouveau("apres_metal")
    entree(p2, "Base Color", (0.6, 0.55, 0.45, 1))
    entree(p2, "Metallic", 0.6)
    entree(p2, "Roughness", 0.5)
    bk.data.materials.append(m2)
    return o, bk


# ------------------------------------------------------------------ baskets modelisees
def section(bm, y, demi, haut, z0, n=6):
    """Anneau de n sommets en forme de rectangle arrondi (section de la basket) : retourne la liste des sommets."""
    pts = [(-demi, z0), (-demi * 0.92, z0 + haut * 0.7), (-demi * 0.5, z0 + haut), (demi * 0.5, z0 + haut), (demi * 0.92, z0 + haut * 0.7), (demi, z0)]
    return [bm.verts.new(Vector((x, y, z))) for x, z in pts]


def basket(cote, cx, y0, long, mats):
    mb, ms, ml = mats
    bm = bmesh.new()
    # stations le long du pied (y de 0 = talon a 1 = bout) : (position, demi-largeur, hauteur de la tige)
    st = [(0.0, 0.046, 0.095), (0.06, 0.054, 0.125), (0.16, 0.058, 0.15), (0.3, 0.06, 0.135), (0.45, 0.06, 0.1), (0.62, 0.06, 0.08),
          (0.8, 0.054, 0.058), (0.93, 0.04, 0.038), (1.0, 0.018, 0.016)]
    anneaux = [section(bm, y0 - t * long, w, h, 0.028) for t, w, h in st]
    for a_, b_ in zip(anneaux[:-1], anneaux[1:]):
        for i in range(len(a_) - 1):
            bm.faces.new((a_[i], a_[i + 1], b_[i + 1], b_[i]))
        bm.faces.new((a_[-1], a_[0], b_[0], b_[-1]))
    bm.faces.new(anneaux[0])
    bm.faces.new(list(reversed(anneaux[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    msh = bpy.data.meshes.new("apres_tige_" + cote)
    bm.to_mesh(msh)
    to = bpy.data.objects.new("apres_tige_" + cote, msh)
    to.location = (cx, 0, 0)
    sc.collection.objects.link(to)
    to["apres"] = True
    ajouter_mod(to, "SUBSURF", levels=2, render_levels=2)
    msh.materials.append(mb)
    # semelle : plaque lobee (talon plus etroit, bout arrondi), bord releve
    bm = bmesh.new()
    sem = [(0.0, 0.036), (0.1, 0.05), (0.3, 0.056), (0.55, 0.06), (0.8, 0.057), (0.95, 0.04), (1.0, 0.014)]
    cont = [(-w, y0 - t * long) for t, w in sem] + [(w, y0 - t * long) for t, w in reversed(sem)]
    bas = [bm.verts.new(Vector((x, y, 0.0))) for x, y in cont]
    haut = [bm.verts.new(Vector((x, y, 0.03))) for x, y in cont]
    bm.faces.new(list(reversed(bas)))
    bm.faces.new(haut)
    n = len(cont)
    for i in range(n):
        bm.faces.new((bas[i], bas[(i + 1) % n], haut[(i + 1) % n], haut[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.004, segments=2, affect="EDGES")
    msh2 = bpy.data.meshes.new("apres_semelle_" + cote)
    bm.to_mesh(msh2)
    so = bpy.data.objects.new("apres_semelle_" + cote, msh2)
    so.location = (cx, 0, 0)
    sc.collection.objects.link(so)
    so["apres"] = True
    msh2.materials.append(ms)
    # cinq lacets en travers de l'empeigne
    for k in range(5):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * 0.075, v.co.y * 0.009, v.co.z * 0.007))
        msh3 = bpy.data.meshes.new("apres_lacet")
        bm.to_mesh(msh3)
        lo = bpy.data.objects.new("apres_lacet", msh3)
        t = 0.26 + k * 0.075
        lo.location = (cx, y0 - t * long, 0.028 + 0.0 + 0.118 * (1.0 - 0.9 * (t - 0.16)) * 0.95)
        lo.rotation_euler = (math.radians(-20), 0, 0)
        sc.collection.objects.link(lo)
        lo["apres"] = True
        msh3.materials.append(ml)
    # languette et collet : coussin sombre dans l'ouverture
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.035, v.co.y * 0.05, v.co.z * 0.025))
    msh4 = bpy.data.meshes.new("apres_languette")
    bm.to_mesh(msh4)
    lg = bpy.data.objects.new("apres_languette", msh4)
    lg.location = (cx, y0 - 0.22 * long, 0.15)
    sc.collection.objects.link(lg)
    lg["apres"] = True
    msh4.materials.append(mb)


def baskets():
    ch = bpy.data.objects["chr_chaussures"]
    ev = evaluer(ch)
    cotes = {"G": [], "D": []}
    for v in ev.data.vertices:
        cotes["G" if v.co.x < 0 else "D"].append(v.co)
    mb, _, pb = nouveau("apres_basket")
    entree(pb, "Base Color", (0.62, 0.6, 0.55, 1))
    entree(pb, "Roughness", 0.6)
    ms, _, ps = nouveau("apres_semelle")
    entree(ps, "Base Color", (0.8, 0.78, 0.72, 1))
    entree(ps, "Roughness", 0.8)
    ml, _, pl = nouveau("apres_lacets")
    entree(pl, "Base Color", (0.7, 0.7, 0.68, 1))
    entree(pl, "Roughness", 0.85)
    for cote, pts in cotes.items():
        xs = [p.x for p in pts]
        ys = [p.y for p in pts]
        cx = (min(xs) + max(xs)) / 2
        y1 = max(ys)
        y0 = min(ys)
        long = max(y1 - y0, 0.27)
        basket(cote, cx, y1, long, (mb, ms, ml))




# ====================================================================== passe 2 : tete, mains, pieds, fesses
def masque_ellipsoide(nt, coord, centre, rayons, nom="m"):
    """Masque lisse (1 au centre, 0 a l'exterieur) dans l'espace objet : ellipsoide de centre et rayons donnes."""
    sub = nt.nodes.new("ShaderNodeVectorMath")
    sub.operation = "SUBTRACT"
    sub.inputs[1].default_value = centre
    nt.links.new(coord, sub.inputs[0])
    dv = nt.nodes.new("ShaderNodeVectorMath")
    dv.operation = "DIVIDE"
    dv.inputs[1].default_value = rayons
    nt.links.new(sub.outputs[0], dv.inputs[0])
    ln = nt.nodes.new("ShaderNodeVectorMath")
    ln.operation = "LENGTH"
    nt.links.new(dv.outputs[0], ln.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = 0.0
    mr.inputs["From Max"].default_value = 1.0
    mr.inputs["To Min"].default_value = 1.0
    mr.inputs["To Max"].default_value = 0.0
    nt.links.new(ln.outputs["Value"], mr.inputs["Value"])
    return mr.outputs[0]


def melanger(nt, couleur, b, fac, mode="MIX"):
    mx = nt.nodes.new("ShaderNodeMix")
    mx.data_type = "RGBA"
    mx.blend_type = mode
    nt.links.new(fac, mx.inputs[0])
    nt.links.new(couleur, mx.inputs[6])
    mx.inputs[7].default_value = b
    return mx.outputs[2]


def peau_detaillee(obj, mesures):
    """Peau : teinte variable, ombre de barbe, levres, orbites, paumes claires, plis des doigts, pores."""
    m, nt, p = nouveau("apres_peau")
    entree(p, "Roughness", 0.62)
    entree(p, ["Subsurface Weight", "Subsurface"], 0.12)
    entree(p, "Subsurface Radius", (0.9, 0.35, 0.2))
    entree(p, "Subsurface Scale", 0.02)
    entree(p, ["Specular IOR Level", "Specular"], 0.3)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    obj_c = tc.outputs["Object"]
    # teinte de base : deux bruns, melanges par un bruit lent
    n = nt.nodes.new("ShaderNodeTexNoise")
    n.inputs["Scale"].default_value = 5.0
    nt.links.new(obj_c, n.inputs["Vector"])
    base = melanger(nt, nt.nodes.new("ShaderNodeRGB").outputs[0], (0.11, 0.05, 0.03, 1), n.outputs["Fac"])
    # le premier noeud RGB sert de couleur de depart
    rgb = base.node.inputs[6].links[0].from_node
    rgb.outputs[0].default_value = (0.05, 0.022, 0.014, 1)
    col = base
    # joues et nez un peu plus chauds, front et pommettes plus clairs
    ox, oy, oz = mesures["oeil"]
    col = melanger(nt, col, (0.2, 0.085, 0.05, 1), masque_ellipsoide(nt, obj_c, (0.0, oy - 0.03, oz - 0.03), (0.07, 0.03, 0.045)), "MIX")
    # orbites : plus sombres sous les yeux
    for sg in (-1, 1):
        col = melanger(nt, col, (0.02, 0.008, 0.006, 1), masque_ellipsoide(nt, obj_c, (sg * ox, oy - 0.006, oz - 0.004), (0.03, 0.03, 0.022)), "MULTIPLY")
    # ombre de barbe sur le menton et la machoire : points fins
    nz = mesures["nez"]
    barbe_zone = masque_ellipsoide(nt, obj_c, (0.0, nz[1] + 0.035, nz[2] - 0.065), (0.075, 0.07, 0.055))
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 650.0
    nt.links.new(obj_c, vor.inputs["Vector"])
    seuil = nt.nodes.new("ShaderNodeMath")
    seuil.operation = "LESS_THAN"
    seuil.inputs[1].default_value = 0.22
    nt.links.new(vor.outputs["Distance"], seuil.inputs[0])
    barbe = nt.nodes.new("ShaderNodeMath")
    barbe.operation = "MULTIPLY"
    nt.links.new(seuil.outputs[0], barbe.inputs[0])
    nt.links.new(barbe_zone, barbe.inputs[1])
    col = melanger(nt, col, (0.008, 0.005, 0.005, 1), barbe.outputs[0])
    # levres : un peu plus roses et plus sombres que la peau
    bouche = (0.0, nz[1] + 0.012, nz[2] - 0.038)
    col = melanger(nt, col, (0.20, 0.07, 0.065, 1), masque_ellipsoide(nt, obj_c, bouche, (0.021, 0.02, 0.0075)))
    # mains : paume claire, dos plus fonce ; seulement dans la zone des mains (|x| > 0,27 et z < 0,92)
    sepo = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(obj_c, sepo.inputs[0])
    absx = nt.nodes.new("ShaderNodeMath")
    absx.operation = "ABSOLUTE"
    nt.links.new(sepo.outputs["X"], absx.inputs[0])
    zone_x = nt.nodes.new("ShaderNodeMath")
    zone_x.operation = "GREATER_THAN"
    zone_x.inputs[1].default_value = 0.27
    nt.links.new(absx.outputs[0], zone_x.inputs[0])
    zone_z = nt.nodes.new("ShaderNodeMath")
    zone_z.operation = "LESS_THAN"
    zone_z.inputs[1].default_value = 0.84
    nt.links.new(sepo.outputs["Z"], zone_z.inputs[0])
    main_m = nt.nodes.new("ShaderNodeMath")
    main_m.operation = "MULTIPLY"
    nt.links.new(zone_x.outputs[0], main_m.inputs[0])
    nt.links.new(zone_z.outputs[0], main_m.inputs[1])
    # paume : normale tournee vers le corps (x * signe(x) < 0)
    nrm = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Normal"], nrm.inputs[0])
    sg = nt.nodes.new("ShaderNodeMath")
    sg.operation = "SIGN"
    nt.links.new(sepo.outputs["X"], sg.inputs[0])
    pm = nt.nodes.new("ShaderNodeMath")
    pm.operation = "MULTIPLY"
    nt.links.new(nrm.outputs["X"], pm.inputs[0])
    nt.links.new(sg.outputs[0], pm.inputs[1])
    palm = nt.nodes.new("ShaderNodeMath")
    palm.operation = "LESS_THAN"
    palm.inputs[1].default_value = -0.35
    nt.links.new(pm.outputs[0], palm.inputs[0])
    palm_m = nt.nodes.new("ShaderNodeMath")
    palm_m.operation = "MULTIPLY"
    nt.links.new(palm.outputs[0], palm_m.inputs[0])
    nt.links.new(main_m.outputs[0], palm_m.inputs[1])
    col = melanger(nt, col, (0.2, 0.1, 0.065, 1), palm_m.outputs[0])
    nt.links.new(col, p.inputs["Base Color"])
    # relief : pores partout, plis fins des doigts (bandes autour de l'axe z) dans la zone des mains, rides du front
    b1 = bosse(nt, p, 900.0, 0.12, 4.0, "VORONOI", obj_c)
    wv = nt.nodes.new("ShaderNodeTexWave")
    wv.wave_type = "BANDS"
    wv.bands_direction = "Z"
    wv.inputs["Scale"].default_value = 150.0
    wv.inputs["Distortion"].default_value = 3.0
    nt.links.new(obj_c, wv.inputs["Vector"])
    mp = nt.nodes.new("ShaderNodeMath")
    mp.operation = "MULTIPLY"
    nt.links.new(wv.outputs["Fac"], mp.inputs[0])
    doigts = nt.nodes.new("ShaderNodeMath")
    doigts.operation = "LESS_THAN"
    doigts.inputs[1].default_value = 0.77
    nt.links.new(sepo.outputs["Z"], doigts.inputs[0])
    dm = nt.nodes.new("ShaderNodeMath")
    dm.operation = "MULTIPLY"
    nt.links.new(zone_x.outputs[0], dm.inputs[0])
    nt.links.new(doigts.outputs[0], dm.inputs[1])
    nt.links.new(dm.outputs[0], mp.inputs[1])
    b2 = nt.nodes.new("ShaderNodeBump")
    b2.inputs["Strength"].default_value = 0.18
    b2.inputs["Distance"].default_value = 0.001
    nt.links.new(mp.outputs[0], b2.inputs["Height"])
    nt.links.new(b1.outputs[0], b2.inputs["Normal"])
    b3 = bosse(nt, p, 60.0, 0.08, 6.0, "NOISE", obj_c)
    nt.links.new(b2.outputs[0], b3.inputs["Normal"])
    nt.links.new(b3.outputs[0], p.inputs["Normal"])
    obj.data.materials[0] = m


def mesures_visage(corps):
    vs = [v.co.copy() for v in corps.data.vertices]
    idx = {vi for p in corps.data.polygons if p.material_index == 2 for vi in p.vertices}
    pts = [vs[k] for k in idx if vs[k].x > 0]
    ctr = sum(pts, Vector()) / len(pts)
    tete = [v for v in vs if v.z > 1.45 and abs(v.x) < 0.03]
    nez = min(tete, key=lambda v: v.y)
    return {"oeil": (abs(ctr.x), ctr.y, ctr.z), "nez": (nez.x, nez.y, nez.z)}


def brins(nom, graines, direction, longueur, largeur, mat, n_par_graine=3, seed=1):
    """Brins de poils (sourcils, cils) : fines lames triangulaires partant de points de graine, orientees dans une direction."""
    random.seed(seed)
    bm = bmesh.new()
    for g, d in zip(graines, direction):
        for _ in range(n_par_graine):
            j = Vector((random.uniform(-1, 1), random.uniform(-0.3, 0.3), random.uniform(-1, 1))) * 0.0014
            base = g + j
            dd = (d + Vector((random.uniform(-0.25, 0.25), 0, random.uniform(-0.25, 0.25)))).normalized()
            L = longueur * random.uniform(0.7, 1.2)
            lat = dd.cross(Vector((0, -1, 0)))
            if lat.length < 1e-4:
                lat = Vector((1, 0, 0))
            lat.normalize()
            courbe = Vector((0, -0.2, -0.1)) * L * 0.4
            v0 = bm.verts.new(base - lat * largeur / 2)
            v1 = bm.verts.new(base + lat * largeur / 2)
            v2 = bm.verts.new(base + dd * L + courbe)
            bm.faces.new((v0, v1, v2))
    msh = bpy.data.meshes.new(nom)
    bm.to_mesh(msh)
    o = bpy.data.objects.new(nom, msh)
    sc.collection.objects.link(o)
    o["apres"] = True
    msh.materials.append(mat)
    return o


def sourcils_et_cils(corps, mesures):
    vs = [v.co.copy() for v in corps.data.vertices]
    idx = {vi for p in corps.data.polygons if p.material_index == 1 for vi in p.vertices}
    mb, nt, pb = nouveau("apres_poils")
    entree(pb, "Base Color", (0.007, 0.005, 0.005, 1))
    entree(pb, "Roughness", 0.6)
    ox, oy, oz = mesures["oeil"]
    zsep = oz + 0.02
    brow, lash = [], []
    for k in idx:
        v = vs[k]
        (brow if v.z > zsep else lash).append(v)
    gr, di = [], []
    for v in brow:
        sg = 1.0 if v.x > 0 else -1.0
        t = (abs(v.x) - 0.02) / 0.06                  # 0 a l'interieur, 1 vers la tempe
        gr.append(v)
        di.append(Vector((sg * (0.35 + 0.65 * t), -0.1, 0.65 - 0.5 * t)))
    brins("apres_sourcils", gr, di, 0.0072, 0.0009, mb, 2, 3)
    gl, dl = [], []
    for v in lash:
        sg = 1.0 if v.x > 0 else -1.0
        gl.append(v)
        dl.append(Vector((sg * 0.25, -0.55, 0.8)))
    brins("apres_cils", gl, dl, 0.0065, 0.0007, mb, 2, 4)
    # la matiere des facettes d'origine (sourcils et cils peints) devient une base sombre peu brillante
    mbase, nt2, pb2 = nouveau("apres_base_sourcils")
    entree(pb2, "Base Color", (0.012, 0.007, 0.006, 1))
    entree(pb2, "Roughness", 0.85)
    corps.data.materials[1] = mbase


def fesses_et_hanches(objs, amp, sigma_z=0.085, sigma_x=0.055, centre_z=0.9, ecart=0.095, releve=0.25, z_fondu=None):
    """Arrondit les fesses : deux bosses gaussiennes dans le dos (y > 0), un peu relevees. S'applique a la peau et aux vetements
    (et a toutes les cles de forme du corps, sinon la base de la cle ecraserait la modification)."""
    def deplacer(c):
        if c.y < 0.0 or c.z < 0.65 or c.z > 1.2:
            return
        w = 0.0
        for sx in (-1, 1):
            w += math.exp(-((c.z - centre_z) / sigma_z) ** 2 - ((c.x - sx * ecart) / sigma_x) ** 2)
        w = min(w, 1.0)
        if z_fondu:
            w *= min(max((z_fondu[0] - c.z) / z_fondu[1], 0.0), 1.0)
        c.y += amp * w * (0.6 + 0.8 * min(max(c.y, 0.0) / 0.09, 1.0))
        c.z += amp * releve * w
    for o in objs:
        for v in o.data.vertices:
            deplacer(v.co)
        if o.data.shape_keys:
            for kb in o.data.shape_keys.key_blocks:
                for pt in kb.data:
                    deplacer(pt.co)


def ongles(corps):
    """Ongles : petites lames bombees brillantes au bout de chaque doigt (bouts detectes par regroupement des sommets bas de la main)."""
    mn, nt, pn = nouveau("apres_ongle")
    entree(pn, "Base Color", (0.30, 0.15, 0.12, 1))
    entree(pn, "Roughness", 0.25)
    entree(pn, "Coat Weight", 0.6)
    for sg in (-1, 1):
        pts = [v.co.copy() for v in corps.data.vertices if v.co.x * sg > 0.27 and v.co.z < 0.92]
        zmin = min(p.z for p in pts)
        bas = [p for p in pts if p.z < zmin + 0.115]
        clusters = []
        for p in bas:
            for c in clusters:
                if any((p - q).length < 0.0105 for q in c):
                    c.append(p)
                    break
            else:
                clusters.append([p])
        # fusion des groupes qui se touchent par transitivite
        fusion = True
        while fusion:
            fusion = False
            for i in range(len(clusters)):
                for j in range(i + 1, len(clusters)):
                    if any((a - b).length < 0.0105 for a in clusters[i] for b in clusters[j]):
                        clusters[i] += clusters[j]
                        del clusters[j]
                        fusion = True
                        break
                if fusion:
                    break
        for c in clusters:
            bas_c = min(c, key=lambda q: q.z)
            if len(c) < 4:
                continue
            ymoy = sum(q.y for q in c) / len(c)
            pouce = all(ymoy <= sum(q.y for q in k) / len(k) for k in clusters)
            if bas_c.z > zmin + 0.045 and not pouce:
                continue
            bout = [q for q in c if q.z < bas_c.z + 0.011]
            cx = sum(q.x for q in bout) / len(bout)
            cy = sum(q.y for q in bout) / len(bout)
            xext = max(abs(q.x) for q in bout)
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=1.0)
            for v in bm.verts:
                v.co = Vector((v.co.x * 0.0014, v.co.y * 0.0042, v.co.z * 0.0062))
            msh = bpy.data.meshes.new("apres_ongle")
            bm.to_mesh(msh)
            o = bpy.data.objects.new("apres_ongle", msh)
            o.location = Vector((sg * (xext + 0.0002), cy, bas_c.z + 0.0058))
            sc.collection.objects.link(o)
            o["apres"] = True
            msh.materials.append(mn)


def pied_profil(corps, sg):
    """Mesure du pied du cote sg : stations (y, x centre, demi-largeur, z du dessus) du talon vers le bout."""
    pied = [v.co.copy() for v in corps.data.vertices if v.co.x * sg > 0.0 and v.co.z < 0.095]
    y_talon = max(p.y for p in pied)
    y_bout = min(p.y for p in pied)
    out = []
    n = 14
    for i in range(n):
        t = i / (n - 1)
        y = y_talon - t * (y_talon - y_bout)
        pts = [p for p in pied if abs(p.y - y) < 0.016]
        if not pts:
            continue
        xs = [p.x for p in pts]
        out.append((t, y, (max(xs) + min(xs)) / 2, (max(xs) - min(xs)) / 2, max(p.z for p in pts)))
    return out, y_talon, y_bout


def stations_pied(prof, y_talon, y_bout):
    """Stations de la tige et de la semelle : le pied mesure, un talon arrondi en arriere et un bout arrondi en avant.
    Chaque station : (t, y, x centre, demi-largeur, z du dessus, echelle d'arrondi)."""
    st = []
    t, y, cx, demi, zt = prof[0]
    st.append((-0.05, y_talon + 0.013, cx, demi, zt, 0.55))
    st.append((-0.02, y_talon + 0.007, cx, demi, zt, 0.86))
    st.extend((t, y, cx, demi, zt, 1.0) for t, y, cx, demi, zt in prof)
    t, y, cx, demi, zt = prof[-1]
    for ds, s in ((0.010, 0.99), (0.021, 0.96), (0.031, 0.88), (0.039, 0.7), (0.044, 0.38), (0.046, 0.12)):
        st.append((1.0 + ds * 3.0, y - ds, cx, demi, zt, s))
    return st


def lofter(bm, anneaux, mat_de=None):
    """Relie des anneaux successifs (listes de sommets, ouverts en bas) en un tube ferme aux deux bouts."""
    for k, (a_, b_) in enumerate(zip(anneaux[:-1], anneaux[1:])):
        for i in range(len(a_) - 1):
            f = bm.faces.new((a_[i], a_[i + 1], b_[i + 1], b_[i]))
            if mat_de:
                f.material_index = mat_de(k, i)
        bm.faces.new((a_[-1], a_[0], b_[0], b_[-1]))
    bm.faces.new(anneaux[0])
    bm.faces.new(list(reversed(anneaux[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])


def baskets_pied(corps):
    mb, nb, pb = nouveau("apres_basket")
    entree(pb, "Base Color", (0.3, 0.29, 0.27, 1))
    entree(pb, "Roughness", 0.6)
    tcb = nb.nodes.new("ShaderNodeTexCoord")
    bb = bosse(nb, pb, 700.0, 0.12, 5.0, "NOISE", tcb.outputs["Object"])
    nb.links.new(bb.outputs[0], pb.inputs["Normal"])
    ma, _, pa = nouveau("apres_basket_accent")
    entree(pa, "Base Color", (0.3, 0.07, 0.035, 1))
    entree(pa, "Roughness", 0.55)
    ms, nts, ps = nouveau("apres_semelle")
    entree(ps, "Base Color", (0.42, 0.4, 0.35, 1))
    entree(ps, "Roughness", 0.7)
    mo, nto, po = nouveau("apres_semelle_dessous")
    entree(po, "Base Color", (0.06, 0.055, 0.05, 1))
    entree(po, "Roughness", 0.9)
    tc = nto.nodes.new("ShaderNodeTexCoord")
    bsem = bosse(nto, po, 400.0, 0.3, 4.0, "VORONOI", tc.outputs["Object"])
    nto.links.new(bsem.outputs[0], po.inputs["Normal"])
    ml, _, pl = nouveau("apres_lacets")
    entree(pl, "Base Color", (0.38, 0.38, 0.36, 1))
    entree(pl, "Roughness", 0.85)
    mc, ncs, pc = nouveau("apres_chaussette")
    entree(pc, "Base Color", (0.36, 0.36, 0.34, 1))
    entree(pc, "Roughness", 0.95)
    vag = ncs.nodes.new("ShaderNodeTexWave")
    vag.wave_type = "BANDS"
    vag.bands_direction = "Z"
    vag.inputs["Scale"].default_value = 260.0
    tcc = ncs.nodes.new("ShaderNodeTexCoord")
    ncs.links.new(tcc.outputs["Object"], vag.inputs["Vector"])
    bc = ncs.nodes.new("ShaderNodeBump")
    bc.inputs["Strength"].default_value = 0.5
    bc.inputs["Distance"].default_value = 0.004
    ncs.links.new(vag.outputs["Fac"], bc.inputs["Height"])
    ncs.links.new(bc.outputs[0], pc.inputs["Normal"])
    for sg, cote in ((-1, "G"), (1, "D")):
        prof, y_talon, y_bout = pied_profil(corps, sg)
        st = stations_pied(prof, y_talon, y_bout)

        def ressort(t):
            return 0.014 * max(0.0, (t - 0.78) / 0.4) ** 1.6

        # tige : demi-section en arc, plus haute sur le cou-de-pied, bout arrondi bombe, bande laterale rouge
        bm = bmesh.new()
        anneaux = []
        for t, y, cx, demi, ztop, s in st:
            d = (demi + 0.009 + 0.007 * max(0.0, (t - 0.5) / 0.5)) * s
            hz = max(ztop + 0.011, 0.045) if t < 0.88 else max(ztop + 0.012, 0.042)
            z0 = 0.002 + ressort(t) * 0.7
            haut = z0 + (hz - z0) * s ** 0.8
            pts = []
            for i in range(9):
                a = math.pi * (1.0 - i / 8.0)
                pts.append((cx + d * math.cos(a), z0 + (haut - z0) * max(math.sin(a), 0.0) ** 0.65))
            anneaux.append([bm.verts.new(Vector((x, y, z))) for x, z in pts])
        lofter(bm, anneaux, lambda k, i: 1 if (i in (2, 5) and 0.3 <= st[k][0] <= 0.62) else 0)
        msh = bpy.data.meshes.new("apres_tige_" + cote)
        bm.to_mesh(msh)
        to = bpy.data.objects.new("apres_tige_" + cote, msh)
        sc.collection.objects.link(to)
        to["apres"] = True
        ajouter_mod(to, "SUBSURF", levels=2, render_levels=2)
        msh.materials.append(mb)
        msh.materials.append(ma)
        # semelle : intercalaire creme et dessous sombre crante, bout releve
        bm = bmesh.new()
        anneaux = []
        for t, y, cx, demi, ztop, s in st:
            w = (demi + 0.012 + 0.006 * max(0.0, (t - 0.5) / 0.5)) * s
            zb = -0.012 + ressort(t)
            zt = 0.021 + ressort(t) * 0.7
            zm = zb + 0.009
            pts = [(-w, zt), (-w, zm), (-w * 0.97, zb + 0.002), (-w * 0.9, zb), (w * 0.9, zb), (w * 0.97, zb + 0.002), (w, zm), (w, zt)]
            anneaux.append([bm.verts.new(Vector((cx + x, y, z))) for x, z in pts])
        lofter(bm, anneaux, lambda k, i: 1 if i in (1, 2, 3, 4, 5) else 0)
        msh2 = bpy.data.meshes.new("apres_semelle_" + cote)
        bm.to_mesh(msh2)
        so = bpy.data.objects.new("apres_semelle_" + cote, msh2)
        sc.collection.objects.link(so)
        so["apres"] = True
        ajouter_mod(so, "SUBSURF", levels=1, render_levels=1)
        msh2.materials.append(ms)
        msh2.materials.append(mo)
        # languette et lacets croises sur le cou-de-pied
        ref = {round(t, 3): (y, cx, demi, ztop) for t, y, cx, demi, ztop, s in st if s == 1.0}
        t_l = min(ref, key=lambda k: abs(k - 0.24))
        y_l, cx_l, demi_l, zt_l = ref[t_l]
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * (demi_l * 1.5), v.co.y * 0.06, v.co.z * 0.008))
        mt = bpy.data.meshes.new("apres_languette")
        bm.to_mesh(mt)
        lg = bpy.data.objects.new("apres_languette_" + cote, mt)
        lg.location = (cx_l, y_l - 0.004, zt_l + 0.017)
        lg.rotation_euler = (0.42, 0.0, 0.0)
        sc.collection.objects.link(lg)
        lg["apres"] = True
        ajouter_mod(lg, "SUBSURF", levels=1, render_levels=1)
        mt.materials.append(mb)
        for k in range(5):
            tt = 0.34 + k * 0.095
            t_k = min(ref, key=lambda q: abs(q - tt))
            y_k, cx_k, demi_k, zt_k = ref[t_k]
            larg = (demi_k + 0.009) * 0.95
            for sens in (1, -1):
                bm = bmesh.new()
                bmesh.ops.create_cube(bm, size=1.0)
                for v in bm.verts:
                    v.co = Vector((v.co.x * larg, v.co.y * 0.0042, v.co.z * 0.0036))
                msh3 = bpy.data.meshes.new("apres_lacet")
                bm.to_mesh(msh3)
                lo = bpy.data.objects.new("apres_lacet", msh3)
                lo.location = (cx_k, y_k, max(zt_k + 0.011, 0.045) - 0.001)
                lo.rotation_euler = (0.0, 0.0, sens * 0.5)
                sc.collection.objects.link(lo)
                lo["apres"] = True
                msh3.materials.append(ml)
        # collet rembourre autour de la cheville
        t, y, cx, demi, ztop = prof[1]
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=False, segments=24, radius1=demi + 0.011, radius2=demi + 0.009, depth=0.05)
        msh5 = bpy.data.meshes.new("apres_collet")
        bm.to_mesh(msh5)
        co = bpy.data.objects.new("apres_collet_" + cote, msh5)
        co.location = (cx, y + 0.012, 0.082)
        co.scale = (1.0, 1.12, 1.0)
        sc.collection.objects.link(co)
        co["apres"] = True
        ajouter_mod(co, "SOLIDIFY", thickness=0.006, offset=1.0)
        ajouter_mod(co, "SUBSURF", levels=1, render_levels=1)
        msh5.materials.append(mb)
        # chaussette cotelee entre le collet et l'ourlet du jean
        cheville = [v.co for v in corps.data.vertices if v.co.x * sg > 0.0 and 0.09 < v.co.z < 0.11]
        if cheville:
            xs = [p.x for p in cheville]
            ys = [p.y for p in cheville]
            rx = (max(xs) - min(xs)) / 2 + 0.006
            ry = (max(ys) - min(ys)) / 2 + 0.006
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=False, segments=28, radius1=1.0, radius2=1.0, depth=0.1)
            for v in bm.verts:
                v.co.x *= rx
                v.co.y *= ry
            ms_ = bpy.data.meshes.new("apres_chaussette")
            bm.to_mesh(ms_)
            so_ = bpy.data.objects.new("apres_chaussette_" + cote, ms_)
            so_.location = ((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, 0.12)
            sc.collection.objects.link(so_)
            so_["apres"] = True
            ajouter_mod(so_, "SOLIDIFY", thickness=0.004, offset=1.0)
            ms_.materials.append(mc)


# ------------------------------------------------------------------ execution
corps = bpy.data.objects["chr_corps"]
corps["apres"] = True
mes = mesures_visage(corps)
fesses_et_hanches([corps], 0.05, centre_z=0.84, sigma_z=0.1, sigma_x=0.06)
fesses_et_hanches([bpy.data.objects["chr_pantalon"]], 0.06, centre_z=0.84, sigma_z=0.1, sigma_x=0.06, releve=0.0, z_fondu=(1.0, 0.2))
fesses_et_hanches([bpy.data.objects["chr_haut"]], 0.1, centre_z=0.84, sigma_z=0.1, sigma_x=0.06, releve=0.0, z_fondu=(1.05, 0.12))
peau_detaillee(corps, mes)
yeux_apres(corps, mes)
cheveux_apres()
sourcils_et_cils(corps, mes)
ajouter_mod(corps, "SUBSURF", levels=1, render_levels=2)
tsh = tshirt_apres()
impression(tsh)
col_cotes("chr_haut")
col_cotes("chr_haut", lambda v: v.co.z < 1.0 and abs(v.co.x) < 0.3, (0.007, 0.007), "apres_ourlet", (0.14, 0.14, 0.135, 1))
col_cotes("chr_haut", lambda v: abs(v.co.x) > 0.2 and 1.0 < v.co.z < 1.5, (0.005, 0.005), "apres_manche", (0.14, 0.14, 0.135, 1))
jean_apres()
bpy.context.view_layer.update()
baskets_pied(corps)
ongles(corps)
print("apres : objets", len([o for o in sc.objects if o.get("apres")]))
