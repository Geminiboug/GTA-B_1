# GTB : zem (moto-taxi) low poly, fait par script. Moto generique 125 cc, sans marque reelle.
# Lancement : blender -b --python blender/tools/build_zem.py -- <sortie.blend> <sortie.glb>
# Orientation : l'avant regarde +Y dans Blender (= -Z dans Godot). Roues posees a Z = 0. Longueur ~1,95 m.
# Pivots animes dans Godot : piv_guidon (direction, porte fourche + roue avant), piv_roue_av, piv_roue_ar (rotation).
# Reperes : pt_conducteur (assise), pt_passager.
import bpy
import math
import sys

args = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, OUT_GLB = args[:2]

bpy.ops.wm.read_homefile(use_empty=True)
scene = bpy.context.scene


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, srgb, rough=0.6, metal=0.0):
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
    m.diffuse_color = rgba
    return m


PAINT = material("veh_peinture_rouge", (0.70, 0.08, 0.06), 0.35)
BLACK = material("veh_plastique_noir", (0.06, 0.06, 0.06), 0.7)
CHROME = material("veh_chrome", (0.75, 0.75, 0.78), 0.2, 1.0)
TIRE = material("veh_pneu", (0.04, 0.04, 0.04), 0.9)
SEAT = material("veh_selle", (0.10, 0.08, 0.07), 0.8)
LIGHT = material("veh_phare", (1.0, 0.95, 0.75), 0.1)
PLATE = material("veh_plaque", (0.95, 0.95, 0.9), 0.5)
ENGINE = material("veh_moteur", (0.35, 0.35, 0.37), 0.5, 0.6)

WHEEL_R = 0.30
WHEELBASE = 1.25
FRONT_Y = WHEELBASE / 2
REAR_Y = -WHEELBASE / 2


def empty(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.05
    scene.collection.objects.link(e)
    e.parent = parent
    e.location = loc
    return e


def finish(ob, name, mat, parent, loc):
    ob.name = name
    ob.data.name = name
    ob.data.materials.append(mat)
    ob.parent = parent
    ob.location = loc
    return ob


def box(name, size, loc, mat, parent, rot=(0, 0, 0), bevel=0.01):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob = bpy.context.active_object
    ob.scale = size
    ob.rotation_euler = rot
    bpy.ops.object.transform_apply(scale=True, rotation=True)
    if bevel:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return finish(ob, name, mat, parent, loc)


def cyl(name, r, depth, loc, mat, parent, rot=(0, math.radians(90), 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, rotation=rot)
    ob = bpy.context.active_object
    bpy.ops.object.transform_apply(rotation=True)
    return finish(ob, name, mat, parent, loc)


def wheel(prefix, parent):
    cyl(prefix + "_pneu", WHEEL_R, 0.09, (0, 0, 0), TIRE, parent, verts=20)
    cyl(prefix + "_jante", WHEEL_R * 0.62, 0.095, (0, 0, 0), CHROME, parent, verts=20)
    cyl(prefix + "_moyeu", 0.06, 0.14, (0, 0, 0), CHROME, parent, verts=10)
    # rayons visibles pour voir la roue tourner
    for i in range(3):
        box(f"{prefix}_rayon_{i}", (0.1, 0.02, WHEEL_R * 1.2), (0, 0, 0), CHROME, parent,
            rot=(math.radians(60 * i), 0, 0), bevel=0)


root = empty("veh_zem", (0, 0, 0))
chassis = empty("piv_chassis", (0, 0, 0), root)

# Roue arriere
rr = empty("piv_roue_ar", (0, REAR_Y, WHEEL_R), chassis)
wheel("roue_ar", rr)
# Bras oscillant, amortisseurs, garde-boue arriere
box("bras_oscillant", (0.06, 0.6, 0.06), (0.08, REAR_Y + 0.3, WHEEL_R + 0.02), BLACK, chassis)
box("bras_oscillant_2", (0.06, 0.6, 0.06), (-0.08, REAR_Y + 0.3, WHEEL_R + 0.02), BLACK, chassis)
for sx in (-1, 1):
    box(f"amortisseur_{sx}", (0.04, 0.04, 0.42), (sx * 0.1, REAR_Y + 0.08, 0.5), CHROME, chassis,
        rot=(math.radians(-20), 0, 0))
box("gardeboue_ar", (0.14, 0.45, 0.03), (0, REAR_Y - 0.05, WHEEL_R + 0.34), PAINT, chassis, rot=(math.radians(-12), 0, 0))
box("feu_arriere", (0.1, 0.04, 0.05), (0, REAR_Y - 0.28, 0.72), material("veh_feu_rouge", (0.8, 0.05, 0.05), 0.2), chassis)
box("plaque", (0.18, 0.01, 0.1), (0, REAR_Y - 0.29, 0.6), PLATE, chassis)

# Cadre, moteur, reservoir, selle, caches lateraux
box("cadre_bas", (0.08, 0.7, 0.06), (0, 0.05, 0.36), BLACK, chassis, rot=(math.radians(8), 0, 0))
box("cadre_haut", (0.07, 0.75, 0.06), (0, 0.18, 0.78), BLACK, chassis, rot=(math.radians(-18), 0, 0))
box("moteur", (0.24, 0.34, 0.26), (0, 0.02, 0.36), ENGINE, chassis)
cyl("moteur_cylindre", 0.08, 0.22, (0, 0.2, 0.48), ENGINE, chassis, rot=(math.radians(-30), 0, 0), verts=10)
box("echappement", (0.07, 0.62, 0.07), (0.15, -0.22, 0.28), CHROME, chassis, rot=(math.radians(-6), 0, 0))
box("reservoir", (0.26, 0.42, 0.18), (0, 0.24, 0.84), PAINT, chassis, rot=(math.radians(-8), 0, 0), bevel=0.04)
box("selle", (0.27, 0.72, 0.09), (0, -0.22, 0.83), SEAT, chassis, bevel=0.03)
box("cache_lateral", (0.3, 0.3, 0.16), (0, -0.12, 0.68), PAINT, chassis, bevel=0.02)
box("porte_bagage", (0.24, 0.3, 0.02), (0, REAR_Y + 0.05, 0.85), CHROME, chassis, bevel=0)
for sx in (-1, 1):
    box(f"cale_pied_{sx}", (0.12, 0.05, 0.03), (sx * 0.2, 0.0, 0.3), CHROME, chassis, bevel=0)
    box(f"cale_pied_passager_{sx}", (0.1, 0.05, 0.03), (sx * 0.2, -0.35, 0.36), CHROME, chassis, bevel=0)

# Direction : guidon, fourche, roue avant, phare (tout tourne autour de l'axe de colonne)
STEER_TILT = math.radians(25)
steer_base = empty("piv_colonne", (0, FRONT_Y - 0.18, 0.95), chassis)
steer_base.rotation_euler = (STEER_TILT, 0, 0)  # haut de colonne incline vers l arriere (chasse)
steer = empty("piv_guidon", (0, 0, 0), steer_base)
# position de la roue avant dans le repere incline de la colonne
fork_len = 0.95 - WHEEL_R
wheel_local = (0, 0, -fork_len / math.cos(STEER_TILT))  # le long de la fourche
for sx in (-1, 1):
    box(f"fourche_{sx}", (0.04, 0.04, abs(wheel_local[2])), (sx * 0.07, 0, wheel_local[2] / 2), CHROME, steer, bevel=0)
fr = empty("piv_roue_av_axe", wheel_local, steer)
fr.rotation_euler = (-STEER_TILT, 0, 0)  # la roue reste verticale
wf = empty("piv_roue_av", (0, 0, 0), fr)
wheel("roue_av", wf)
box("gardeboue_av", (0.12, 0.38, 0.03), (0, 0.0, WHEEL_R + 0.06), PAINT, fr, bevel=0.01)
box("guidon", (0.72, 0.035, 0.035), (0, -0.05, 0.12), CHROME, steer, bevel=0)
for sx in (-1, 1):
    box(f"poignee_{sx}", (0.12, 0.045, 0.045), (sx * 0.34, -0.05, 0.12), BLACK, steer, bevel=0)
    box(f"retro_tige_{sx}", (0.015, 0.015, 0.22), (sx * 0.24, -0.04, 0.24), CHROME, steer, bevel=0)
    box(f"retro_{sx}", (0.1, 0.02, 0.07), (sx * 0.26, -0.04, 0.36), BLACK, steer, bevel=0)
box("tete_fourche", (0.24, 0.16, 0.18), (0, 0.04, 0.02), PAINT, steer, bevel=0.03)
cyl("phare", 0.085, 0.06, (0, 0.13, 0.0), LIGHT, steer, rot=(math.radians(90), 0, 0), verts=14)
box("compteur", (0.12, 0.05, 0.07), (0, -0.02, 0.17), BLACK, steer, bevel=0)

# Reperes de position pour le conducteur et le passager (hanches)
empty("pt_conducteur", (0, -0.12, 0.87), root)
empty("pt_passager", (0, -0.45, 0.9), root)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True)
print("Zem :", len([o for o in bpy.data.objects if o.type == "MESH"]), "pieces")
