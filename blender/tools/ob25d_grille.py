# GTB : grille des hauteurs de batiments (Open Buildings 2.5D, CC BY 4.0) dans le repere du jeu, pour osm_import.py.
# Repere identique a osm_import.py : origine au centre des bounds OSM, X = est, Y = nord, 1 m par cellule.
# Lancement (WSL) : ~/.venvs/geo/bin/python blender/tools/ob25d_grille.py refs/osm/zone-aeroport.osm \
#                   refs/open_buildings/hauteurs_2023.tif refs/open_buildings/hauteurs_locales.npz
import math
import sys
import xml.etree.ElementTree as ET
import numpy as np
import pyproj
import rasterio

OSM, TIF, OUT = sys.argv[1:4]
b = ET.parse(OSM).getroot().find("bounds")
minlat, minlon, maxlat, maxlon = (float(b.get(k)) for k in ("minlat", "minlon", "maxlat", "maxlon"))
# origine figee au centre de la premiere zone (aeroport, bounds 6.34638-6.353365 / 2.375259-2.3875) : agrandir la
# zone (phase 9, Cadjehoun - Haie Vive au nord) ne deplace rien de ce qui existe deja dans le jeu
lat0, lon0 = 6.3498725, 2.3813795
KX = 111320.0 * math.cos(math.radians(lat0))
KY = 110540.0
MARGIN = 700.0                     # la zone OSM est plus petite que l'emprise Overture : on couvre large
x0, x1 = (minlon - lon0) * KX - MARGIN, (maxlon - lon0) * KX + MARGIN
y0, y1 = (minlat - lat0) * KY - MARGIN, (maxlat - lat0) * KY + MARGIN
xs = np.arange(math.floor(x0), math.ceil(x1)) + 0.5
ys = np.arange(math.floor(y0), math.ceil(y1)) + 0.5
gx, gy = np.meshgrid(xs, ys)
lon = gx / KX + lon0
lat = gy / KY + lat0
tr = pyproj.Transformer.from_crs(4326, 32631, always_xy=True)
ux, uy = tr.transform(lon, lat)
with rasterio.open(TIF) as src:
    names = list(src.descriptions)
    data = src.read()
    inv = ~src.transform
    col, row = inv * (ux, uy)
    col = np.floor(col).astype(int)
    row = np.floor(row).astype(int)
    ok = (col >= 0) & (col < src.width) & (row >= 0) & (row < src.height)
    col = np.clip(col, 0, src.width - 1)
    row = np.clip(row, 0, src.height - 1)
    h = np.where(ok, data[names.index("building_height")][row, col], 0.0).astype(np.float32)
    p = np.where(ok, data[names.index("building_presence")][row, col], 0.0).astype(np.float32)
np.savez_compressed(OUT, height=h, presence=p, x0=float(xs[0] - 0.5), y0=float(ys[0] - 0.5), res=1.0)
print("grille", h.shape, "origine", xs[0] - 0.5, ys[0] - 0.5,
      "hauteur max %.1f m, mediane batie %.1f m" % (h.max(), float(np.median(h[p > 0.5])) if (p > 0.5).any() else 0))
