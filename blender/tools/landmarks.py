# GTB : reperes de la zone aeroport (blockout), dans un fichier separe de l'import OSM.
# Lancement :
#   blender -b --python blender/tools/landmarks.py -- <lib_materiaux.blend> <sortie.blend> <sortie.glb>
# Meme repere que osm_import.py : origine au centre de la zone, X = est, Y = nord, metres.
# Positions reprises d'OSM (id indique). Noms fictifs : voir docs/LEGAL.md.
# "approx" = position ou forme estimee, a corriger si besoin.
import bpy
import math
import os
import sys

args = sys.argv[sys.argv.index("--") + 1:]
MATLIB, OUT_BLEND, OUT_GLB = args[:3]

bpy.ops.wm.read_homefile(use_empty=True)
with bpy.data.libraries.load(MATLIB, link=False) as (src, dst):
    dst.materials = [m for m in src.materials if m.startswith("mat_")]
MAT = {m.name: m for m in bpy.data.materials}
for m in MAT.values():
    if m.asset_data:
        m.asset_clear()

COLS = {}


def col(name):
    if name not in COLS:
        c = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(c)
        COLS[name] = c
    return COLS[name]


def place(ob, name, mat, collection, rot_z=0.0, parent=None):
    ob.name = name
    ob.data.name = name
    if mat:
        ob.data.materials.clear()
        ob.data.materials.append(MAT[mat])
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    col(collection).objects.link(ob)
    if parent:
        ob.parent = parent
    ob.rotation_euler.z += math.radians(rot_z)
    return ob


def group(name, x, y, rot_z=0.0, collection="Reperes"):
    """Empty parent : tout le repere se deplace / tourne d'un bloc."""
    e = bpy.data.objects.new(name, None)
    e.location = (x, y, 0)
    e.rotation_euler.z = math.radians(rot_z)
    col(collection).objects.link(e)
    return e


def box(name, size, loc, mat, parent, rot_z=0.0, collision=True):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.active_object
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return place(ob, name + ("-convcol" if collision else ""), mat, parent.users_collection[0].name, rot_z, parent)


def cyl(name, r, h, loc, mat, parent, rot=(0, 0, 0), verts=16, collision=True, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc, rotation=rot)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=rot)
    ob = bpy.context.active_object
    return place(ob, name + ("-convcol" if collision else ""), mat, parent.users_collection[0].name, 0, parent)


def sign(name, text, loc, size, parent, rot_z=0.0, mat="mat_marquage_blanc"):
    """Texte en relief, debout, lisible depuis le sud quand rot_z = 0."""
    bpy.ops.object.text_add(location=loc, rotation=(math.radians(90), 0, math.radians(rot_z)))
    ob = bpy.context.active_object
    ob.data.body = text
    ob.data.size = size
    ob.data.extrude = 0.08
    ob.data.align_x = "CENTER"
    ob.data.align_y = "CENTER"
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.active_object
    return place(ob, name, mat, parent.users_collection[0].name, 0, parent)


# ---------- Aeroport International Cardinal Cotodji ----------
# Le terminal (way 273487965) a un interieur : il est construit par blender/tools/build_interieurs.py (murs sur le vrai
# contour, auvent et enseigne le long de la facade cote ville). Ici : la tour de controle seulement.

# Tour de controle : approx (position non renseignee dans OSM), cote piste du terminal.
t = group("rep_tour_controle", 318, 352)
cyl("tour_fut", 2.5, 26, (0, 0, 13), "mat_beton", t)
cyl("tour_vigie", 5, 4, (0, 0, 28), "mat_vitre", t, verts=8)
cyl("tour_toit", 5.6, 0.8, (0, 0, 30.4), "mat_metal_peint", t, verts=8)
cyl("tour_antenne", 0.15, 6, (0, 0, 33.8), "mat_metal_peint", t, verts=6, collision=False)

# ---------- Ararat Hypermarket (Erevan) : OSM node 1969918440 (617, -95) ----------
# Batiment Erevan : x 544..684, y -134..-68 (import). Totem devant la facade sud-ouest (pas de parking : maisons reelles a cet endroit).
a = group("rep_ararat", 617, -95)
box("ararat_totem", (2, 1, 14), (-75, -52, 7), "mat_metal_peint", a)
box("ararat_totem_panneau", (8, 0.6, 4), (-75, -52.2, 15), "mat_peinture_vert", a, collision=False)
sign("ararat_totem_texte", "ARARAT", (-75, -52.6, 15.4), 1.4, a)
sign("ararat_totem_texte2", "HYPERMARKET", (-75, -52.6, 14.0), 0.7, a)

# ---------- Ronds-points : OSM ways 241160370 (679, 30, Djomehountin) et 31814539 (517, 270) ----------
for name, x, y, r in (("rep_rondpoint_djomehountin", 679, 30, 15), ("rep_rondpoint_aeroport", 517, 270, 13)):
    rp = group(name, x, y)
    cyl(name + "_terre_plein", r, 0.5, (0, 0, 0.25), "mat_vegetation", rp, verts=32)
    cyl(name + "_bordure", r + 0.4, 0.3, (0, 0, 0.15), "mat_beton", rp, verts=32, collision=False)
    cyl(name + "_socle", 2.5, 1.5, (0, 0, 1.25), "mat_beton", rp, verts=8)
    cyl(name + "_stele", 0.8, 7, (0, 0, 5.5), "mat_peinture_blanc", rp, verts=8, r2=0.3)

# ---------- L'Epave Volante : avion sur la plage, OSM node 13449221482 (-177, -247) ----------
# Vieil avion de ligne generique (aucun modele ni compagnie reels), modele detaille et vieilli par
# blender/tools/build_epave.py (godot/assets/models/rep_epave_avion.glb) ; orientation approx. Collisions simples ici.
p = group("rep_epave_volante", -177, -247, rot_z=12)
EPAVE = os.path.join(os.path.dirname(OUT_GLB), "rep_epave_avion.glb")
if os.path.exists(EPAVE):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=EPAVE)
    for ob in set(bpy.data.objects) - before:
        if ob.parent is None:
            ob.rotation_euler.z += math.radians(-90)   # nez de l'avion (+Y) vers +X du repere
            ob.parent = p
        for c in list(ob.users_collection):
            c.objects.unlink(ob)
        col("Reperes").objects.link(ob)
        # coque, cabine, escalier et cales : collision exacte (on entre dans l'epave par la porte avant)
        if ob.type == "MESH" and ob.name.startswith(("avion_fuselage", "avion_cabine", "avion_aile", "avion_derive", "avion_nacelle", "escalier_palier", "cale", "sable")):
            ob.name = ob.name + "-col"
        elif ob.name.startswith("rampe_escalier"):
            ob.name = ob.name + "-colonly"
sign("avion_panneau", "L'EPAVE VOLANTE", (0, -30, 1.2), 0.9, p, mat="mat_peinture_ocre")
box("avion_panneau_fond", (12, 0.3, 1.6), (0, -29.7, 1.2), "mat_bois", p, collision=False)

# ---------- Sweet Dream Beach : OSM node 6392032785 (622, -292) ----------
b = group("rep_sweet_dream_beach", 622, -292)
for i, (dx, dy) in enumerate(((-12, 0), (0, 4), (12, 0), (-6, -12), (6, -12))):
    for k, (px, py) in enumerate(((-2, -2), (2, -2), (-2, 2), (2, 2))):
        cyl(f"paillote_{i}_poteau_{k}", 0.15, 2.6, (dx + px, dy + py, 1.3), "mat_bois", b, verts=6, collision=False)
    cyl(f"paillote_{i}_toit", 3.6, 1.6, (dx, dy, 3.3), "mat_peinture_ocre", b, verts=8, r2=0.2)
box("sdb_enseigne_fond", (14, 0.3, 2), (0, -18, 3), "mat_bois", b, collision=False)
sign("sdb_enseigne", "SWEET DREAM BEACH", (0, -18.2, 3), 1.1, b, mat="mat_marquage_jaune")
for k in (-6, 6):
    cyl(f"sdb_poteau_{k}", 0.15, 3, (k, -18, 1.5), "mat_bois", b, verts=6)

# ---------- Maquis La Plaja : OSM node 4203252348 (-159, -54) ----------
m = group("rep_maquis_la_plaja", -159, -54)
box("plaja_toit", (14, 9, 0.3), (0, 0, 3.2), "mat_tole_rouillee", m, collision=False)
for k, (px, py) in enumerate(((-6.5, -4), (6.5, -4), (-6.5, 4), (6.5, 4))):
    cyl(f"plaja_poteau_{k}", 0.15, 3.2, (px, py, 1.6), "mat_bois", m, verts=6)
for k in range(4):
    cyl(f"plaja_table_{k}", 0.6, 0.8, (-4.5 + k * 3, 0, 0.4), "mat_bois", m, verts=8)
box("plaja_enseigne_fond", (9, 0.2, 1.2), (0, -4.6, 3.9), "mat_peinture_vert", m, collision=False)
sign("plaja_enseigne", "MAQUIS LA PLAJA", (0, -4.75, 3.9), 0.7, m, mat="mat_marquage_jaune")

for ob in bpy.data.objects:
    ob.select_set(False)
for mm in MAT.values():
    mm.use_fake_user = False
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True)
print("Reperes :", len([o for o in bpy.data.objects if o.type == "EMPTY"]), "objets :", len(bpy.data.objects))
