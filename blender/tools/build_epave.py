# GTB : "L'Epave Volante", vieil avion de ligne abandonne sur la plage (repere OSM node 13449221482).
# Part du modele d'avion du jeu (blender/veh/veh_avion_ligne.blend, build_avion.py) et le vieillit : train
# d'atterrissage retire, carlingue posee sur des cales en beton, moteur gauche sans capot ni soufflante, volets
# affaisses, peinture delavee par le soleil et le sel, coulures et plaques de rouille sur le bas, hublots
# opaques, sable accumule sous le ventre, escalier metallique d'acces a la porte avant. Aucune compagnie reelle.
# Lancement : blender -b --python blender/tools/build_epave.py -- <veh_avion_ligne.blend> <sortie.blend> <sortie.glb> [apercu.png]
# Repere : celui de l'avion (nez vers +Y, origine au sol sous le train principal). Pose dans le monde par landmarks.py.
import bpy
import bmesh
import math
import os
import random
import sys

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT_BLEND, OUT_GLB = args[:3]
PREVIEW = args[3] if len(args) > 3 else None
rng = random.Random(13449)

bpy.ops.wm.open_mainfile(filepath=SRC)
sc = bpy.context.scene


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, srgb, rough=0.8, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgba = [to_linear(c) for c in srgb] + [1.0]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = rgba
    return m


# 1. pieces mobiles et reperes de l'avion en service : supprimes
for ob in list(sc.objects):
    n = ob.name
    if n.startswith(("train_", "roue_", "feu_", "phare_", "titre_", "logo_", "immatriculation_")) or n in ("soufflante_G", "inverseur_G", "porte_avant"):
        bpy.data.objects.remove(ob, do_unlink=True)

# 2. materiaux vieillis : blanc jauni et farineux, livree passee, metal terni ; rouille et coulures
OLD = {
    "mat_avion_peinture": ((0.82, 0.8, 0.74), 0.85, 0.0),
    "mat_avion_aile": ((0.6, 0.6, 0.58), 0.8, 0.15),
    "mat_avion_livree_1": ((0.32, 0.5, 0.42), 0.9, 0.0),
    "mat_avion_livree_2": ((0.78, 0.66, 0.38), 0.9, 0.0),
    "mat_avion_ventre": ((0.55, 0.53, 0.5), 0.85, 0.05),
    "mat_avion_vitre": ((0.12, 0.13, 0.13), 0.6, 0.0),
    "mat_avion_hublot": ((0.16, 0.16, 0.15), 0.7, 0.0),
    "mat_avion_levre": ((0.52, 0.5, 0.47), 0.7, 0.3),
    "mat_avion_soufflante": ((0.25, 0.2, 0.17), 0.85, 0.3),
}
for k, (c, r, mt) in OLD.items():
    if k in bpy.data.materials:
        mat(k, c, r, mt)
RUST = mat("mat_epave_rouille", (0.42, 0.22, 0.12), 0.95, 0.2)
STREAK = mat("mat_epave_coulure", (0.5, 0.4, 0.3), 0.95, 0.0)
CONC = mat("mat_epave_beton", (0.6, 0.58, 0.54), 0.95)
SAND = mat("mat_epave_sable", (0.82, 0.72, 0.55), 1.0)
STEEL = mat("mat_epave_acier", (0.35, 0.3, 0.27), 0.8, 0.5)

# 3. plaques de rouille et coulures sur le bas de la carlingue, des ailes et des moteurs (faces tirees au sort)
for ob in sc.objects:
    if ob.type != "MESH":
        continue
    if ob.name.startswith("avion_cabine"):
        continue
    me = ob.data
    ri = len(me.materials)
    me.materials.append(RUST)
    me.materials.append(STREAK)
    mw = ob.matrix_world
    for p in me.polygons:
        z = (mw @ p.center).z
        base = me.materials[p.material_index].name if p.material_index < ri else ""
        if base in ("mat_avion_vitre", "mat_avion_hublot"):
            continue
        u = rng.random()
        if z < 2.0 and u < 0.35:
            p.material_index = ri
        elif z < 3.0 and u < 0.12:
            p.material_index = ri + 1
        elif u < 0.01 and z < 4.5:
            p.material_index = ri

# 4. pose sur la plage : plus de train, la carlingue (bas a ~1,3 m) descend sur des cales, legere gite
root = bpy.data.objects.new("epave_volante", None)
sc.collection.objects.link(root)
for ob in list(sc.objects):
    if ob.parent is None and ob != root:
        ob.parent = root
root.location.z = -0.75
root.rotation_euler = (0, 0, 0)   # pas de gite : la porte reste alignee sur l'escalier


def box(name, c, s, m, rz=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= s[0]
        v.co.y *= s[1]
        v.co.z *= s[2]
        x, y = v.co.x, v.co.y
        v.co.x = x * math.cos(rz) - y * math.sin(rz)
        v.co.y = x * math.sin(rz) + y * math.cos(rz)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    sc.collection.objects.link(ob)
    ob.location = c          # origine au centre : les rotations se font sur place
    return ob


# cales en beton sous la carlingue et sous les ailes, moteur droit pose sur un fut
for i, y in enumerate((9.0, 2.0, -6.0)):
    box(f"cale_{i}", (0, y, 0.3), (2.2, 1.2, 0.6), CONC, rng.uniform(-0.1, 0.1))
for sd in (-1, 1):
    box(f"cale_aile_{sd}", (sd * 8.0, -1.5, 0.62), (1.2, 1.0, 1.24), CONC)
# sable amasse par le vent contre la carlingue (dunes basses)
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=8, radius=1.0)
for v in bm.verts:
    v.co.x *= 3.2
    v.co.y *= 16.0
    v.co.z = max(v.co.z, 0.0) * 0.55 - 0.05
me = bpy.data.meshes.new("sable_epave")
bm.to_mesh(me)
bm.free()
me.materials.append(SAND)
for p in me.polygons:
    p.use_smooth = True
so = bpy.data.objects.new("sable_epave", me)
sc.collection.objects.link(so)
so.location = (0.4, 1.0, 0)
# escalier metallique (rouille) vers la porte avant gauche
for k in range(8):
    box(f"escalier_marche_{k}", (-4.35 + k * 0.28, 15.75, 0.22 + k * 0.24), (0.3, 1.0, 0.05), STEEL)
# rampe invisible sous les marches : le personnage monte l'escalier sans buter sur chaque marche
ramp = box("rampe_escalier", (-3.55, 15.75, 0.95), (2.9, 1.0, 0.05), STEEL)
ramp.rotation_euler.y = -math.atan2(1.9, 2.1)
box("escalier_palier", (-2.15, 15.75, 1.88), (0.7, 1.0, 0.05), STEEL)
seuil = box("escalier_palier_seuil", (-1.85, 15.75, 1.915), (0.8, 0.8, 0.04), STEEL)   # rampe du palier au plancher
seuil.rotation_euler.y = -0.13
for sy in (-0.5, 0.5):
    st = box(f"escalier_limon_{sy}", (-3.4, 15.75 + sy, 1.05), (3.0, 0.06, 0.16), STEEL)
    st.rotation_euler.y = math.radians(-44)
    st.location = (-3.4, 15.75 + sy, 1.05)
    box(f"escalier_pied_{sy}", (-2.4, 15.75 + sy, 0.95), (0.06, 0.06, 1.9), STEEL)

faces = sum(len(o.data.polygons) for o in sc.objects if o.type == "MESH")
print("Epave :", faces, "faces")
os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True, export_texcoords=False)

if PREVIEW:
    w = bpy.data.worlds.new("w")
    w.color = (0.7, 0.75, 0.8)
    sc.world = w
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.display.shading.color_type = "MATERIAL"
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    cam = bpy.data.cameras.new("c")
    cam.lens = 35
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    for nm, loc, rot in (("trois_quart", (-26, 30, 8), (80, 0, -140)), ("profil", (40, 2, 3), (88, 0, 90))):
        co.location = loc
        co.rotation_euler = [math.radians(a) for a in rot]
        sc.render.filepath = PREVIEW.replace(".png", f"_{nm}.png")
        bpy.ops.render.render(write_still=True)
