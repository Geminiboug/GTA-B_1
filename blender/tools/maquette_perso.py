# GTB : maquette de l'amelioration des personnages. Rend le personnage "homme" dans un studio identique avant et apres :
#   avant : le modele du jeu tel quel ; apres : peau, yeux, cheveux, vetements et chaussures ameliores (maquette_perso_apres.py).
# Lancement : blender -b blender/chr/chr_homme.blend --python blender/tools/run_logged.py -- <journal> blender/tools/maquette_perso.py <avant|apres> <dossier_sortie> [vues separees par des virgules]
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
MODE, OUT = args[0], args[1]
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene

if MODE == "apres":
    import runpy
    runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "maquette_perso_apres.py"), init_globals={"bpy": bpy})

# pieces visibles : tenue du pilote (T-shirt, pantalon, chaussures, cheveux courts)
SHOW = {"chr_corps", "chr_haut", "chr_pantalon", "chr_cheveux", "chr_chaussures"}
if MODE == "apres":
    SHOW = {o.name for o in sc.objects if o.type == "MESH" and o.get("apres")} | {"chr_corps"}
for o in sc.objects:
    if o.type == "MESH":
        o.hide_render = o.name not in SHOW
        o.hide_viewport = o.hide_render

# studio : ciel clair, soleil chaud de cote, rebond de sol (lumiere tropicale)
w = bpy.data.worlds.new("w")
w.use_nodes = True
nt = w.node_tree
for n in list(nt.nodes):
    nt.nodes.remove(n)
bg = nt.nodes.new("ShaderNodeBackground")
sortie = nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(bg.outputs[0], sortie.inputs[0])
bg.inputs[0].default_value = (0.55, 0.68, 0.85, 1)
bg.inputs[1].default_value = 0.9
sc.world = w
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 4.5
sun.data.color = (1.0, 0.92, 0.78)
sun.data.angle = math.radians(4)
sun.rotation_euler = (math.radians(55), math.radians(15), math.radians(35))
sc.collection.objects.link(sun)
fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "AREA"))
fill.data.energy = 120
fill.data.size = 3
fill.data.color = (0.75, 0.85, 1.0)
fill.location = (-2.5, 2.5, 1.2)
fill.rotation_euler = (math.radians(80), 0, math.radians(-135))
sc.collection.objects.link(fill)
sol = bpy.data.objects.new("sol", bpy.data.meshes.new("sol"))
import bmesh
bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6)
bm.to_mesh(sol.data)
sc.collection.objects.link(sol)
sm = bpy.data.materials.new("sol")
sm.use_nodes = True
for n in list(sm.node_tree.nodes):
    sm.node_tree.nodes.remove(n)
_p = sm.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
_o = sm.node_tree.nodes.new("ShaderNodeOutputMaterial")
sm.node_tree.links.new(_p.outputs[0], _o.inputs[0])
_p.inputs["Base Color"].default_value = (0.62, 0.5, 0.38, 1)
_p.inputs["Roughness"].default_value = 0.95
sol.data.materials.append(sm)

sc.render.engine = "BLENDER_EEVEE"
sc.eevee.taa_render_samples = 64
sc.render.film_transparent = False
sc.view_settings.view_transform = "AgX"
sc.view_settings.look = "AgX - Medium High Contrast"

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
VUES = {
    "face": ((0.0, -4.2, 1.0), (0.0, 0.0, 0.9), 40, (900, 1200)),
    "trois_quarts": ((2.3, -3.4, 1.05), (0.0, 0.0, 0.88), 40, (900, 1200)),
    "profil": ((4.2, 0.0, 1.0), (0.0, 0.0, 0.9), 40, (900, 1200)),
    "dos": ((0.0, 4.2, 1.0), (0.0, 0.0, 0.9), 40, (900, 1200)),
    "visage": ((0.42, -0.72, 1.56), (0.0, 0.0, 1.52), 50, (1000, 1000)),
    "buste": ((0.5, -1.7, 1.35), (0.0, 0.0, 1.25), 50, (1000, 1000)),
    "bas": ((0.8, -1.7, 0.45), (0.0, 0.0, 0.38), 50, (1000, 1000)),
    "main": ((0.75, -0.55, 0.82), (0.31, -0.03, 0.78), 22, (1000, 1000)),
    "pied": ((0.5, -0.7, 0.22), (0.1, -0.05, 0.05), 40, (1000, 1000)),
    "fesses": ((0.0, 1.7, 0.85), (0.0, 0.05, 0.85), 32, (1000, 1000)),
    "face_visage": ((0.0, -0.8, 1.56), (0.0, 0.0, 1.55), 40, (1000, 1000)),
    "oeil": ((0.05, -0.4, 1.574), (0.05, 0.0, 1.574), 22, (1000, 700)),
}
CHOIX = args[2].split(",") if len(args) > 2 else list(VUES)
for nom, (p, t, fov, res) in VUES.items():
    if nom not in CHOIX:
        continue
    cam.location = Vector(p)
    cam.rotation_euler = (Vector(t) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.sensor_width = 36
    cam.data.lens = 36 / (2 * math.tan(math.radians(fov) / 2))
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.filepath = os.path.join(OUT, "%s_%s.png" % (MODE, nom))
    bpy.ops.render.render(write_still=True)
    print("rendu", nom)
