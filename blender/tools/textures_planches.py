# GTB : textures tirees des planches de references generees (refs/generees/, voir LISEZMOI.md).
# Chaque planche est une grille de vignettes separees par du blanc, avec une legende sous chacune : les vignettes sont
# reperees par projections (bandes de lignes puis de colonnes non blanches), recadrees, rendues raccordables (chaque bord
# fondu avec le bord oppose) et enregistrees en carre.
# Lancement (WSL) : ~/.venvs/geo/bin/python blender/tools/textures_planches.py <planche.jpg> <dossier_sortie> [taille]
# Sortie : <dossier>/<planche>_<n>.png et un apercu <dossier>/<planche>_apercu.jpg (vignettes numerotees, en 2 x 2).
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

SEUIL = 28          # ecart au fond blanc pour qu'un pixel compte comme "image"
BANDE_LIGNE = 0.45  # part de pixels non blancs d'une ligne qui traverse des vignettes
BANDE_COL = 0.6     # part de pixels non blancs d'une colonne dans une bande de vignettes
MIN_COTE = 120      # px : en dessous, c'est du texte ou un trait
RETRAIT = 8         # px retires sur chaque bord (liseres, ombres)
FONDU = 0.22        # part du cote fondue avec le bord oppose


def segments(profil, seuil, min_len):
    out, debut = [], None
    for i, v in enumerate(list(profil) + [0.0]):
        if v >= seuil and debut is None:
            debut = i
        elif v < seuil and debut is not None:
            if i - debut >= min_len:
                out.append((debut, i))
            debut = None
    return out


def vignettes(im):
    ## Grille reguliere : bandes de lignes non blanches, puis colonnes de la bande la plus nette, appliquees a toutes
    ## les bandes (une vignette tres claire, proche du fond, ne casse pas la grille).
    a = np.asarray(im.convert("RGB")).astype(np.int16)
    fond = np.median(np.concatenate([a[:4].reshape(-1, 3), a[-4:].reshape(-1, 3)]), axis=0)
    masque = np.abs(a - fond).max(axis=2) > SEUIL
    bandes = segments(masque.mean(axis=1), BANDE_LIGNE * 0.5, MIN_COTE)
    # la bande la plus reguliere (largeurs de vignettes les plus egales), a nombre de colonnes egal la plus fournie
    choix = [segments(masque[y0:y1].mean(axis=0), BANDE_COL, MIN_COTE) for y0, y1 in bandes]
    choix = [c for c in choix if c]
    colonnes = min(choix, key=lambda c: (float(np.std([x1 - x0 for x0, x1 in c])) / max(np.mean([x1 - x0 for x0, x1 in c]), 1.0), -len(c)), default=[])
    return [(x0 + RETRAIT, y0 + RETRAIT, x1 - RETRAIT, y1 - RETRAIT) for y0, y1 in bandes for x0, x1 in colonnes]


def raccordable(img):
    ## Fond chaque bord avec le bord oppose (rampe lineaire) : la texture se repete sans couture visible.
    a = np.asarray(img).astype(np.float32)
    h, w, _ = a.shape
    for axe, n in ((1, w), (0, h)):
        f = int(n * FONDU)
        rampe = np.linspace(0.0, 1.0, f, dtype=np.float32)
        b = a.copy()
        if axe == 1:
            debut, fin = a[:, :f], a[:, n - f:]
            k = rampe[None, :, None]
            b[:, :f] = debut * k + fin * (1 - k)
            a = b[:, :n - f]
        else:
            debut, fin = a[:f], a[n - f:]
            k = rampe[:, None, None]
            b[:f] = debut * k + fin * (1 - k)
            a = b[:n - f]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def main():
    src, dest = sys.argv[1], sys.argv[2]
    taille = int(sys.argv[3]) if len(sys.argv) > 3 else 512
    os.makedirs(dest, exist_ok=True)
    nom = os.path.splitext(os.path.basename(src))[0]
    im = Image.open(src).convert("RGB")
    rects = vignettes(im)
    tuiles = []
    for i, (x0, y0, x1, y1) in enumerate(rects):
        c = min(x1 - x0, y1 - y0)
        cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
        carre = im.crop((cx - c // 2, cy - c // 2, cx - c // 2 + c, cy - c // 2 + c))
        t = raccordable(carre).resize((taille, taille), Image.LANCZOS)
        t.save(os.path.join(dest, "%s_%02d.png" % (nom, i + 1)))
        tuiles.append(t)
        print("%s_%02d" % (nom, i + 1), (x0, y0, x1, y1), "->", c, "px")
    # apercu : chaque texture repetee 2 x 2 (les coutures se voient si le raccord est rate)
    if tuiles:
        cote = 256
        cols = 4
        lignes = (len(tuiles) + cols - 1) // cols
        ap = Image.new("RGB", (cols * cote * 2 + cols * 8, lignes * (cote * 2 + 30)), "white")
        d = ImageDraw.Draw(ap)
        for i, t in enumerate(tuiles):
            p = t.resize((cote, cote))
            ox, oy = (i % cols) * (cote * 2 + 8), (i // cols) * (cote * 2 + 30)
            for dx in (0, 1):
                for dy in (0, 1):
                    ap.paste(p, (ox + dx * cote, oy + dy * cote))
            d.text((ox + 4, oy + cote * 2 + 6), "%02d" % (i + 1), fill="black")
        ap.save(os.path.join(dest, "%s_apercu.jpg" % nom), quality=85)


if __name__ == "__main__":
    main()
