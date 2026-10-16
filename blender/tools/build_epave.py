# GTB : "L'Epave Volante", vieil avion de ligne abandonne sur la plage (repere OSM node 13449221482).
# D'apres l'epave reelle de la plage d'Erevan (recherche du 16/10/2026 : un trireacteur gros-porteur facon
# Lockheed L-1011 TriStar, ramene de l'aeroport vers 2015 pour un projet de restaurant jamais termine) :
# - gros-porteur de 54 m, fuselage de 6 m de diametre, envergure ~47 m (modele du jeu agrandi a ces proportions) ;
# - moteurs retires (nacelles d'aile enlevees, entree d'air du reacteur de queue vide au pied de la derive) ;
# - carlingue blanchie a la chaux (livree effacee), rouille et coulures sur le bas, hublots opaques ;
# - posee sur le sable sans train, escalier en bois bricole jusqu'a la porte avant gauche, chaises et tables autour ;
# - cabine economique 2-4-3 (deux allees), sieges rouges a l'avant, bleus a l'arriere, fond sans sieges.
# Aucun nom, immatriculation ni compagnie reels.
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
    if n.startswith(("train_", "roue_", "feu_", "phare_", "titre_", "logo_", "immatriculation_", "avion_nacelle", "inverseur_",
                     "soufflante_")) or n in ("porte_avant", "avion_cabine", "avion_livree"):
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
# blanchie a la chaux : peinture, livree et ventre deviennent un blanc mat un peu sale
for k in ("mat_avion_peinture", "mat_avion_livree_1", "mat_avion_livree_2", "mat_avion_ventre"):
    OLD[k] = ((0.9, 0.89, 0.85), 0.95, 0.0)
for k, (c, r, mt) in OLD.items():
    if k in bpy.data.materials:
        mat(k, c, r, mt)
RUST = mat("mat_epave_rouille", (0.42, 0.22, 0.12), 0.95, 0.2)
STREAK = mat("mat_epave_coulure", (0.5, 0.4, 0.3), 0.95, 0.0)
CONC = mat("mat_epave_beton", (0.6, 0.58, 0.54), 0.95)
SAND = mat("mat_epave_sable", (0.82, 0.72, 0.55), 1.0)
STEEL = mat("mat_epave_acier", (0.35, 0.3, 0.27), 0.8, 0.5)

# 2 bis. proportions du gros-porteur : fuselage x1,5 (6 m), longueur x1,44 (54 m), ailes et empennage x1,32 en envergure
SX, SY, SZ, SPAN = 1.5, 1.44, 1.5, 1.32
for ob in list(sc.objects):
    if ob.type != "MESH":
        continue
    ob.data.transform(ob.matrix_world)
    ob.matrix_world = ob.matrix_world.Identity(4)
    k = SPAN / SX if ob.name.startswith(("avion_aile", "avion_stabilisateur", "volet_", "spoiler_", "avion_karman")) else 1.0
    for v in ob.data.vertices:
        x = v.co.x
        if k != 1.0 and abs(x) > 2.0:
            x = math.copysign(2.0 + (abs(x) - 2.0) * k, x)   # l'emplanture reste collee au fuselage
        v.co = (x * SX, v.co.y * SY, v.co.z * SZ)
FLOOR_Z = 2.67 * SZ + 0.01           # plancher au ras du bas de la porte agrandie (sinon rebord de 7,5 cm infranchissable)
DOOR_Y = 15.75 * SY                  # milieu de la porte avant gauche
DOOR_X = -1.98 * SX
HALF_W = 1.89 * SX                   # demi-largeur du revetement interieur
Y_FWD, Y_AFT = 17.3 * SY, -7.9 * SY  # cloisons poste de pilotage / fond de cabine

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
root.location.z = -(1.45 * SZ - 0.9)   # bas de la carlingue a 0,9 m, sur les cales
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


Z0 = root.location.z
FLOOR = FLOOR_Z + Z0                 # plancher dans le repere pose (les objets ci-dessous ne sont pas rattaches a root)
WOOD = mat("mat_epave_bois", (0.45, 0.33, 0.22), 0.95)
RED = mat("mat_epave_siege_rouge", (0.55, 0.1, 0.1), 0.9)
BLUE = mat("mat_epave_siege_bleu", (0.12, 0.2, 0.42), 0.9)
CAB = bpy.data.materials.get("mat_avion_cabine") or mat("mat_avion_cabine", (0.86, 0.84, 0.78), 0.7)
CARPET = bpy.data.materials.get("mat_avion_moquette") or mat("mat_avion_moquette", (0.25, 0.3, 0.45), 0.95)
DARK = mat("mat_epave_noir", (0.05, 0.05, 0.05), 0.9)
PAINT = bpy.data.materials["mat_avion_peinture"]

# cales en beton sous la carlingue et sous les ailes
for i, y in enumerate((14.0, 3.0, -9.0)):
    box(f"cale_{i}", (0, y, 0.45), (3.0, 1.6, 0.9), CONC, rng.uniform(-0.1, 0.1))
for sd in (-1, 1):
    box(f"cale_aile_{sd}", (sd * 11.0, -2.0, 0.6), (1.4, 1.2, 1.2), CONC)
# reacteur de queue (moteur retire) : entree d'air au pied de la derive (fond noir), tuyere vide au bout du cone
tail_z = 5.44 * SZ + Z0
bm = bmesh.new()
bmesh.ops.create_cone(bm, cap_ends=False, segments=20, radius1=1.15, radius2=1.0, depth=3.2)
bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=__import__("mathutils").Matrix.Rotation(math.radians(90), 3, "X"))
me = bpy.data.meshes.new("avion_entree_queue")
bm.to_mesh(me)
bm.free()
me.materials.append(PAINT)
eo = bpy.data.objects.new("avion_entree_queue", me)
sc.collection.objects.link(eo)
eo.location = (0, -10.6 * SY, tail_z + 0.6)
box("avion_entree_queue_fond", (0, -10.6 * SY - 1.0, tail_z + 0.6), (1.9, 0.1, 1.9), DARK)
box("avion_tuyere_queue", (0, -17.0 * SY + 0.5, 4.6 * SZ + Z0), (1.6, 0.2, 1.6), DARK)

# cabine 2-4-3 (deux allees de 0,75 m), plancher, cloisons ; sieges rouges devant, bleus derriere, fond vide
cabin = []
# plancher en dalles de 2 m (un seul grand triangle de 34 m fait buter la capsule du joueur dans Godot)
ny = int(math.ceil((Y_FWD - Y_AFT) / 2.0))
for i in range(ny):
    y0 = Y_AFT + (Y_FWD - Y_AFT) * i / ny
    y1 = Y_AFT + (Y_FWD - Y_AFT) * (i + 1) / ny
    cabin.append(box(f"cab_plancher_{i}", (0, (y0 + y1) / 2, FLOOR - 0.05), (HALF_W * 2 - 0.1, y1 - y0, 0.1), CARPET))
for sx in (-1, 1):
    cabin.append(box(f"cab_cloison_avant_{sx}", (sx * (0.5 + (HALF_W - 0.5) / 2), Y_FWD, FLOOR + 1.3), (HALF_W - 0.5, 0.08, 2.6), CAB))
cabin.append(box("cab_cloison_avant_haut", (0, Y_FWD, FLOOR + 2.4), (1.0, 0.08, 0.4), CAB))
cabin.append(box("cab_cloison_arriere", (0, Y_AFT, FLOOR + 1.3), (HALF_W * 2 - 0.1, 0.08, 2.6), CAB))
cabin.append(box("cab_plancher_poste", (0, (Y_FWD + 19.0 * SY) / 2, FLOOR - 0.05), (1.1 * SX * 2, 19.0 * SY - Y_FWD, 0.1), CARPET))   # poste de pilotage
cabin.append(box("cab_office", (HALF_W - 0.6, DOOR_Y, FLOOR + 0.51), (0.9, 1.8, 1.0), CAB))   # office face a la porte
AISLE = 0.65                         # allees elargies pour le jeu (capsule du joueur : 0,60 m)
SEAT = 0.44
CH = 2 * SEAT                        # demi-largeur du bloc central de 4
SHIFT = -SEAT / 2                    # 2 a gauche, 3 a droite : rangee recentree dans le fuselage
cols_x = [SHIFT - (CH + AISLE + SEAT * (k + 0.5)) for k in range(2)]
cols_x += [SHIFT - CH + SEAT * (k + 0.5) for k in range(4)]
cols_x += [SHIFT + CH + AISLE + SEAT * (k + 0.5) for k in range(3)]
row_y = DOOR_Y - 2.6
rows = 0
while row_y > Y_AFT + 8.0:          # fond de cabine sans sieges (zone fret)
    m = RED if rows < 14 else BLUE
    for x in cols_x:
        cabin.append(box(f"cab_siege_{rows}_{x:.2f}", (x, row_y, FLOOR + 0.45), (SEAT - 0.03, 0.48, 0.12), m))
        cabin.append(box(f"cab_dossier_{rows}_{x:.2f}", (x, row_y - 0.26, FLOOR + 0.82), (SEAT - 0.03, 0.1, 0.72), m))
    row_y -= 0.84
    rows += 1
print("Cabine :", rows, "rangees 2-4-3")
bpy.ops.object.select_all(action="DESELECT")
for o in cabin:
    o.select_set(True)
bpy.context.view_layer.objects.active = cabin[0]
bpy.ops.object.join()
cabin[0].name = "avion_cabine"

# sable amasse par le vent contre la carlingue (dunes basses)
bm = bmesh.new()
bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=8, radius=1.0)
for v in bm.verts:
    v.co.x *= 4.6
    v.co.y *= 23.0
    v.co.z = max(v.co.z, 0.0) * 0.6 - 0.05
me = bpy.data.meshes.new("sable_epave")
bm.to_mesh(me)
bm.free()
me.materials.append(SAND)
for p in me.polygons:
    p.use_smooth = True
so = bpy.data.objects.new("sable_epave", me)
sc.collection.objects.link(so)
so.location = (0.4, 1.0, 0)

# escalier en bois bricole jusqu'a la porte avant gauche (marches de ~0,24 m, giron 0,28 m), vers -X
n = max(2, round(FLOOR / 0.24))
rise = FLOOR / n
land_x = DOOR_X - 0.5                # milieu du palier, contre la porte
foot_x = land_x - 0.5                # haut de la volee
run = (n - 1) * 0.28
for k in range(n - 1):
    box(f"escalier_marche_{k}", (foot_x - (n - 1 - k) * 0.28 + 0.14, DOOR_Y, rise * (k + 1) - 0.03), (0.3, 1.1, 0.05), WOOD)
ramp = box("rampe_escalier", (foot_x - run / 2, DOOR_Y, FLOOR / 2 - 0.08), (math.hypot(run, FLOOR), 1.1, 0.05), WOOD)
ramp.rotation_euler.y = -math.atan2(FLOOR, run)    # monte vers +X (la porte)
box("escalier_palier", (land_x, DOOR_Y, FLOOR - 0.03), (1.0, 1.2, 0.06), WOOD)
box("escalier_palier_seuil", (DOOR_X - 0.02, DOOR_Y, FLOOR - 0.025), (0.5, 0.9, 0.04), WOOD)   # sans chevaucher le plancher (couture)
for sy in (-0.6, 0.6):
    for k in range(3):
        h = FLOOR * (k + 1) / 3
        box(f"escalier_pied_{sy}_{k}", (foot_x - run * (1 - (k + 1) / 3), DOOR_Y + sy, h / 2), (0.1, 0.1, h), WOOD)
    st = box(f"escalier_garde_corps_{sy}", (foot_x - run / 2, DOOR_Y + sy, FLOOR / 2 + 0.9), (math.hypot(run, FLOOR), 0.05, 0.05), WOOD)
    st.rotation_euler.y = -math.atan2(FLOOR, run)
# chaises et tables en plastique dans le sable (projet de buvette), tabouret du gardien au pied de l'escalier
PLAST = mat("mat_epave_plastique", (0.85, 0.85, 0.82), 0.6)
for i in range(6):
    tx, ty = -10.0 - (i % 3) * 3.2, DOOR_Y - 7.0 - (i // 3) * 4.0
    box(f"table_{i}", (tx, ty, 0.72), (0.8, 0.8, 0.04), PLAST)
    box(f"table_pied_{i}", (tx, ty, 0.36), (0.08, 0.08, 0.72), PLAST)
    for a in range(2):
        cx = tx + (0.75 if a else -0.75)
        box(f"chaise_{i}_{a}", (cx, ty, 0.44), (0.42, 0.42, 0.04), PLAST)
        box(f"chaise_dos_{i}_{a}", (cx + (0.2 if a else -0.2), ty, 0.7), (0.04, 0.42, 0.5), PLAST)
box("tabouret_gardien", (foot_x - run - 0.8, DOOR_Y + 1.2, 0.22), (0.35, 0.35, 0.44), WOOD)

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
