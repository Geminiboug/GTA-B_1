# GTB : diagnostic geometrique d'un .blend de personnage : objets, materiaux, sourcils, yeux, nez, mains, pieds.
# Lancement : blender -b <perso.blend> --python blender/tools/run_logged.py -- <journal.txt> blender/tools/liste_perso.py
import bpy
from mathutils import Vector

for o in bpy.context.scene.objects:
    if o.type == "MESH":
        print(o.name, len(o.data.vertices), "v", [m.name if m else None for m in o.data.materials], [m.type for m in o.modifiers])
c = bpy.data.objects["chr_corps"]
vs = [v.co.copy() for v in c.data.vertices]
print("bbox", min(v.x for v in vs), max(v.x for v in vs), "|", min(v.y for v in vs), max(v.y for v in vs), "|", min(v.z for v in vs), max(v.z for v in vs))
for i in range(len(c.data.materials)):
    idx = {vi for p in c.data.polygons if p.material_index == i for vi in p.vertices}
    pts = [vs[k] for k in idx]
    if pts:
        print("slot", i, c.data.materials[i].name, len(pts), "x", round(min(p.x for p in pts), 3), round(max(p.x for p in pts), 3), "y", round(min(p.y for p in pts), 3), round(max(p.y for p in pts), 3), "z", round(min(p.z for p in pts), 3), round(max(p.z for p in pts), 3))
# yeux : centres
idx = {vi for p in c.data.polygons if p.material_index == 2 for vi in p.vertices}
for sg in (-1, 1):
    pts = [vs[k] for k in idx if vs[k].x * sg > 0]
    if pts:
        ctr = sum(pts, Vector()) / len(pts)
        print("oeil", sg, tuple(round(x, 4) for x in ctr), "rayon", round(max((p - ctr).length for p in pts), 4))
# nez : pointe la plus avancee (y min) dans la tete
tete = [v for v in vs if v.z > 1.45 and abs(v.x) < 0.03]
nez = min(tete, key=lambda v: v.y)
print("pointe du nez", tuple(round(x, 4) for x in nez))
# mains : sommets dont |x| > 0.5 et z < 1.0
for sg in (-1, 1):
    main = [v for v in vs if v.x * sg > 0.27 and v.z < 0.92]
    if main:
        print("main", sg, len(main), "x", round(min(p.x for p in main), 3), round(max(p.x for p in main), 3), "z", round(min(p.z for p in main), 3), round(max(p.z for p in main), 3), "y", round(min(p.y for p in main), 3), round(max(p.y for p in main), 3))
# pieds
for sg in (-1, 1):
    pied = [v for v in vs if v.x * sg > 0 and v.z < 0.1]
    print("pied", sg, len(pied), "x", round(min(p.x for p in pied), 3), round(max(p.x for p in pied), 3), "y", round(min(p.y for p in pied), 3), round(max(p.y for p in pied), 3), "z", round(min(p.z for p in pied), 3), round(max(p.z for p in pied), 3))
# bassin et fesses : profil en y du dos a z = 0,85 .. 1,0
for z0 in (0.8, 0.88, 0.95, 1.02):
    r = [v for v in vs if abs(v.z - z0) < 0.02 and abs(v.x) < 0.2]
    print("dos a z", z0, "y max", round(max(v.y for v in r), 3), "y min", round(min(v.y for v in r), 3))
for o in bpy.context.scene.objects:
    if o.type == "MESH" and o.data.shape_keys:
        print("SHAPEKEYS", o.name, [k.name for k in o.data.shape_keys.key_blocks][:6], len(o.data.shape_keys.key_blocks))
