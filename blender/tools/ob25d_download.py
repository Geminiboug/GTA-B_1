# GTB : hauteurs reelles des batiments, Google Open Buildings 2.5D Temporal (CC BY 4.0), sans Earth Engine.
# Lit seulement la fenetre de la zone dans la tuile GeoTIFF (lecture HTTP partielle).
# Lancement (WSL) : ~/.venvs/geo/bin/python blender/tools/ob25d_download.py <manifeste.json>... <sortie.tif>
#   Variable GTB_BBOX=lon0,lat0,lon1,lat1 pour une autre emprise (extension de la carte).
#   manifestes : https://storage.googleapis.com/open-buildings-temporal-data/v1/manifests/<11|13>_EPSG_32631_2023_06_30.json
import json
import sys
import pyproj
import rasterio
from rasterio.merge import merge

import os
BBOX = (2.370, 6.343, 2.392, 6.364)       # lon/lat de la zone (identique a l'export Overture) ; nord etendu (phase 9)
if os.environ.get("GTB_BBOX"):
    BBOX = tuple(float(v) for v in os.environ["GTB_BBOX"].split(","))
*MANIFESTS, OUT = sys.argv[1:]
tr = pyproj.Transformer.from_crs(4326, 32631, always_xy=True)
x0, y0 = tr.transform(BBOX[0], BBOX[1])
x1, y1 = tr.transform(BBOX[2], BBOX[3])
x0, x1, y0, y1 = min(x0, x1) - 50, max(x0, x1) + 50, min(y0, y1) - 50, max(y0, y1) + 50
print("zone UTM 31N :", round(x0), round(y0), round(x1), round(y1))
urls = []
for mf in MANIFESTS:
    m = json.load(open(mf))
    pre = m["uriPrefix"].replace("gs://", "https://storage.googleapis.com/")
    for ts in m["tilesets"]:
        for s in ts["sources"]:
            a, d = s["affineTransform"], s["dimensions"]
            tx0, ty1 = a["translateX"], a["translateY"]
            tx1, ty0 = tx0 + d["width"] * a["scaleX"], ty1 + d["height"] * a["scaleY"]
            if tx0 < x1 and tx1 > x0 and ty0 < y1 and ty1 > y0:      # la zone peut etre a cheval sur plusieurs tuiles
                urls.append("/vsicurl/" + pre + s["uris"][0])
if not urls:
    print("aucune tuile ne couvre la zone")
    sys.exit(1)
srcs = [rasterio.open(u) for u in urls]
print("tuiles :", urls)
print("bandes :", srcs[0].count, srcs[0].descriptions, srcs[0].dtypes, srcs[0].res)
data, transform = merge(srcs, bounds=(x0, y0, x1, y1))
prof = srcs[0].profile.copy()
prof.update(width=data.shape[2], height=data.shape[1], transform=transform, driver="GTiff", compress="deflate", tiled=False)
prof.pop("blockxsize", None)
prof.pop("blockysize", None)
with rasterio.open(OUT, "w", **prof) as dst:
    dst.write(data)
    dst.descriptions = srcs[0].descriptions
print("ecrit :", OUT, data.shape)
