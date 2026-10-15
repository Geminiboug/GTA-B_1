# GTB : textures de detail de peau a partir des textures Quaternius (refs/ubc, CC0).
# La couleur propre de la texture est retiree (division par la teinte mediane de la peau) : il reste les variations
# (levres, ongles, ombres, plis), que Godot teinte avec nos 10 teintes de peau (pnj_util.gd, skin_mat).
# Valeur neutre = 0,75 (marge pour les zones plus claires). Lancement :
#   blender -b --python blender/tools/ubc_skin_detail.py -- <dossier_textures_ubc> <dossier_sortie>
import bpy
import numpy as np
import os
import sys

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[:2]
os.makedirs(OUT, exist_ok=True)
for src, dst in (("T_Superhero_Male_Dark.png", "peau_detail_homme.png"), ("T_Superhero_Female_Dark_BaseColor.png", "peau_detail_femme.png")):
    img = bpy.data.images.load(os.path.join(SRC, src))
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    rgb = px[:, :, :3]
    lum = rgb.mean(axis=2)
    # peau : pixels assez clairs et chauds (exclut les sous-vetements peints en gris fonce)
    skin = (lum > 0.25) & (rgb[:, :, 0] > rgb[:, :, 2] + 0.05)
    med = np.median(rgb[skin], axis=0)
    det = np.clip(rgb / med * 0.75, 0.0, 1.0)
    # sous-vetements (gris neutre fonce) : ramenes a une peau neutre (ils sont toujours sous les vetements)
    det[~skin] = 0.75
    out = np.concatenate([det, np.ones((h, w, 1), np.float32)], axis=2)
    o = bpy.data.images.new(dst, w, h)
    o.pixels[:] = out.ravel()
    o.filepath_raw = os.path.join(OUT, dst)
    o.file_format = "PNG"
    o.save()
    print("Detail peau", dst, "mediane", med)
