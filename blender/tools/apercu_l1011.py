# GTB : apercu du modele de reference L-1011 (refs/modeles/l1011_cotty, CC-BY-4.0, voir docs/LEGAL.md) : trois vues rendues
# en PNG, dimensions et pieces. Reference de forme seulement : le modele du jeu est refait dans build_epave.py.
# Lancement : blender -b --python blender/tools/run_logged.py -- <journal.txt> blender/tools/apercu_l1011.py <gltf> <dossier_sortie>
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
os.makedirs(out, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
# bornes globales
mn = Vector((1e9, 1e9, 1e9))
mx = Vector((-1e9, -1e9, -1e9))
for o in objs:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mn = Vector(min(a, b) for a, b in zip(mn, w))
        mx = Vector(max(a, b) for a, b in zip(mx, w))
print("bornes", tuple(round(v, 2) for v in mn), tuple(round(v, 2) for v in mx), "taille", tuple(round(v, 2) for v in (mx - mn)))
print("objets", len(objs))
ctr = (mn + mx) / 2
size = max(mx - mn)
sc = bpy.context.scene
sc.render.resolution_x, sc.render.resolution_y = 1100, 620
sc.render.engine = "BLENDER_EEVEE"
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.82, 0.92, 1)
sc.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
sun.data.energy = 3.5
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.clip_end = size * 10
cam.data.clip_start = size * 0.01
vues = {"cote": (1, 0, 0.15), "face": (0, -1, 0.2), "trois_quarts": (0.8, -0.8, 0.5), "dessus": (0, 0.01, 1)}
for nom, d in vues.items():
    d = Vector(d).normalized()
    cam.location = ctr + d * size * 1.5
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(out, "l1011_%s.png" % nom)
    bpy.ops.render.render(write_still=True)
    print("vue", nom)
