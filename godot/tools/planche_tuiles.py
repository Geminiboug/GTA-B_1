# GTB : assemble les vues du dessus de tests/capture_carte_tuiles.gd en planches (3 x 2 tuiles par image) pour la revue de la
# carte. Lancement (venv geo, WSL) : ~/.venvs/geo/bin/python godot/tools/planche_tuiles.py <dossier_des_png> <dossier_sortie>
import glob
import os
import sys

from PIL import Image, ImageDraw

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
fichiers = sorted(glob.glob(os.path.join(src, "tuile_*.png")))
col, lig = 3, 2
for k in range(0, len(fichiers), col * lig):
    lot = fichiers[k:k + col * lig]
    ims = [Image.open(f).convert("RGB").resize((640, 360)) for f in lot]
    planche = Image.new("RGB", (640 * col, 360 * lig), (20, 20, 20))
    d = ImageDraw.Draw(planche)
    for n, (f, im) in enumerate(zip(lot, ims)):
        x, y = (n % col) * 640, (n // col) * 360
        planche.paste(im, (x, y))
        d.text((x + 6, y + 4), os.path.basename(f).replace("tuile_", "").replace(".png", ""), fill=(255, 255, 0))
    planche.save(os.path.join(dst, "planche_%02d.png" % (k // (col * lig))))
print(len(fichiers), "vues,", (len(fichiers) + col * lig - 1) // (col * lig), "planches")
