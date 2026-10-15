# GTB : apercus d'un personnage genere (.blend de build_character.py) : de face, trois quarts, visage, buste.
# Le personnage regarde -Y. Lancement : blender -b <perso.blend> --python apercu_perso.py -- <prefixe_png> [pieces visibles...]
import bpy
import math
import sys

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
show = set(args[1:]) or {"chr_corps", "chr_haut", "chr_pantalon", "chr_chaussures", "chr_cheveux"}
sc = bpy.context.scene
for o in sc.objects:
    if o.type == "MESH":
        o.hide_render = o.name not in show
top = max((o.matrix_world @ v.co).z for o in sc.objects if o.type == "MESH" and o.name == "chr_corps" for v in o.data.vertices)
w = bpy.data.worlds.new("w")
w.color = (0.75, 0.8, 0.85)
sc.world = w
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.color_type = "TEXTURE"
sc.display.shading.light = "STUDIO"
sc.render.resolution_x = sc.render.resolution_y = 800
for name, loc, rot, lens in (("face", (0, -3.8, top * 0.52), (90, 0, 0), 50), ("trois_quart", (-2.6, -2.8, top * 0.6), (88, 0, -42), 50),
                             ("visage", (-0.15, -0.75, top - 0.12), (90, 0, -11), 85), ("buste", (-0.9, -1.6, top * 0.6), (88, 0, -30), 60)):
    c = bpy.data.cameras.new(name)
    c.lens = lens
    o = bpy.data.objects.new(name, c)
    sc.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    sc.camera = o
    sc.render.filepath = f"{OUT}_{name}.png"
    bpy.ops.render.render(write_still=True)
